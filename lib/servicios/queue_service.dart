import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QueueService {
  static const String _key = 'queue_operaciones';
  static const int _maxIntentos = 5;

  static Timer? _timer;
  static VoidCallback? _onQueueChanged;

  // ============================================================
  // CALLBACK PARA ACTUALIZAR LA UI
  // ============================================================

  static void setOnQueueChanged(VoidCallback callback) {
    _onQueueChanged = callback;
  }

  static void _notificar() {
    if (_onQueueChanged != null) _onQueueChanged!();
  }

  // ============================================================
  // AGREGAR OPERACIÓN A LA COLA
  // ============================================================

  static Future<void> agregar({
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cola = await leerCola();

    final item = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
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
    _notificar();
  }

  // ============================================================
  // LEER COLA
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
  // CONTADORES
  // ============================================================

  static Future<int> contarPendientes() async {
    final cola = await leerCola();
    return cola.where((e) => e['estado'] == 'pendiente').length;
  }

  static Future<int> contarErrores() async {
    final cola = await leerCola();
    return cola.where((e) => e['estado'] == 'error').length;
  }

  static Future<int> contarTotal() async {
    final cola = await leerCola();
    return cola.length;
  }

  // ============================================================
  // ELIMINAR
  // ============================================================

  static Future<void> eliminar(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final cola = await leerCola();
    cola.removeWhere((e) => e['id'] == id);
    await prefs.setString(_key, jsonEncode(cola));
    if (kDebugMode) print('QUEUE: eliminado $id');
    _notificar();
  }

  // ============================================================
  // ACTUALIZAR ITEM
  // ============================================================

  static Future<void> actualizarItem(
      String id, Map<String, dynamic> updates) async {
    final prefs = await SharedPreferences.getInstance();
    final cola = await leerCola();
    for (var i = 0; i < cola.length; i++) {
      if (cola[i]['id'] == id) {
        cola[i] = {...cola[i], ...updates};
        break;
      }
    }
    await prefs.setString(_key, jsonEncode(cola));
    _notificar();
  }

  // ============================================================
  // REINTENTAR UN ITEM EN ERROR
  // ============================================================

  static Future<void> reintentar(String id) async {
    await actualizarItem(id, {
      'estado': 'pendiente',
      'intentos': 0,
      'ultimoError': null,
    });
  }

  // ============================================================
  // LIMPIAR COMPLETAMENTE
  // ============================================================

  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _notificar();
  }

  // ============================================================
  // ELIMINAR SOLO LOS QUE ESTÁN EN ERROR
  // ============================================================

  static Future<void> limpiarErrores() async {
    final prefs = await SharedPreferences.getInstance();
    final cola = await leerCola();
    cola.removeWhere((e) => e['estado'] == 'error');
    await prefs.setString(_key, jsonEncode(cola));
    _notificar();
  }

  // ============================================================
  // TIMER AUTOMÁTICO (cada 1 minuto)
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
    if (kDebugMode) print('QUEUE: timer iniciado (cada 1 minuto)');
  }

  static void detenerSync() {
    _timer?.cancel();
    _timer = null;
    if (kDebugMode) print('QUEUE: timer detenido');
  }

  static int get maxIntentos => _maxIntentos;
}
