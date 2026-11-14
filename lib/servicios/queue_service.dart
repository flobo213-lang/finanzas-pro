import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';

class QueueService {
  static const String _key = 'queue_operaciones';
  static const int _maxIntentos = 5;

  // B12 fix: lock reentrante para mutaciones concurrentes.
  // Reentrante para permitir reintentar → actualizarItem sin deadlock.
  static final Lock _lock = Lock(reentrant: true);
  static const Uuid _uuid = Uuid();

  static Timer? _timer;
  static VoidCallback? _onQueueChanged;

  static void setOnQueueChanged(VoidCallback callback) {
    _onQueueChanged = callback;
  }

  static void _notificar() {
    if (_onQueueChanged != null) _onQueueChanged!();
  }

  // ============================================================
  // AGREGAR OPERACIÓN A LA COLA (B12 + B13 fix)
  // ============================================================
  static Future<void> agregar({
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    await _lock.synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final cola = await leerCola();

      final item = {
        'id': _uuid.v4(),                    // B13: UUID en vez de timestamp
        'action': action,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
        'intentos': 0,
        'estado': 'pendiente',
        'ultimoError': null,
      };

      cola.add(item);
      await prefs.setString(_key, jsonEncode(cola));
      if (kDebugMode) print('QUEUE: agregado $action con id ${item['id']}');
    });
    _notificar();
  }

  // ============================================================
  // LEER COLA (no muta, no necesita lock)
  // ============================================================
  static Future<List<Map<String, dynamic>>> leerCola() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('QUEUE: error decodificando → $e');
    }
    return [];
  }

  // ============================================================
  // CONTADORES (no mutan)
  // ============================================================
  static Future<int> contarPendientes() async {
    final cola = await leerCola();
    return cola.where((e) => e['estado'] == 'pendiente').length;
  }

  static Future<int> contarErrores() async {
    final cola = await leerCola();
    return cola.where((e) => e['estado'] == 'error').length;
  }

  static Future<int> contarTotal() async => (await leerCola()).length;

  // ============================================================
  // ELIMINAR (B12 fix)
  // ============================================================
  static Future<void> eliminar(String id) async {
    await _lock.synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final cola = await leerCola();
      cola.removeWhere((e) => e['id'] == id);
      await prefs.setString(_key, jsonEncode(cola));
      if (kDebugMode) print('QUEUE: eliminado $id');
    });
    _notificar();
  }

  // ============================================================
  // ACTUALIZAR ITEM (B12 fix)
  // ============================================================
  static Future<void> actualizarItem(
      String id, Map<String, dynamic> updates) async {
    await _lock.synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final cola = await leerCola();
      for (var i = 0; i < cola.length; i++) {
        if (cola[i]['id'] == id) {
          cola[i] = {...cola[i], ...updates};
          break;
        }
      }
      await prefs.setString(_key, jsonEncode(cola));
    });
    _notificar();
  }

  // ============================================================
  // REINTENTAR UN ITEM EN ERROR
  // (usa _lock reentrante → llama a actualizarItem sin deadlock)
  // ============================================================
  static Future<void> reintentar(String id) async {
    await actualizarItem(id, {
      'estado': 'pendiente',
      'intentos': 0,
      'ultimoError': null,
    });
  }

  // ============================================================
  // LIMPIAR COMPLETAMENTE (B12 fix)
  // ============================================================
  static Future<void> limpiar() async {
    await _lock.synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    });
    _notificar();
  }

  // ============================================================
  // LIMPIAR SOLO ERRORES (B12 fix)
  // ============================================================
  static Future<void> limpiarErrores() async {
    await _lock.synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final cola = await leerCola();
      cola.removeWhere((e) => e['estado'] == 'error');
      await prefs.setString(_key, jsonEncode(cola));
    });
    _notificar();
  }

  // ============================================================
  // TIMER AUTOMÁTICO (B14 fix: log corregido)
  // ============================================================
  static void iniciarSyncAutomatico(Future<void> Function() syncCallback) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        await syncCallback();
      } catch (e) {
        if (kDebugMode) print('QUEUE: sync automático falló → $e');
      }
    });
    if (kDebugMode) print('QUEUE: timer iniciado (cada 5 minutos)');
  }

  static void detenerSync() {
    _timer?.cancel();
    _timer = null;
    if (kDebugMode) print('QUEUE: timer detenido');
  }

  static int get maxIntentos => _maxIntentos;
}
