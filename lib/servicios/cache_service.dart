import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  // Claves
  static const String _keyTasas = 'cache_tasas';
  static const String _keyTasasTs = 'cache_tasas_ts';
  static const String _keySaldos = 'cache_saldos';
  static const String _keySaldosTs = 'cache_saldos_ts';
  static const String _keyTrabajadorPrefix = 'cache_trabajador_';
  static const String _keyCuentas = 'cache_cuentas';

  // Tiempo de "frescura" en SEGUNDOS
  static const int _segundosFrescura = 30;

  // ============================================================
  // TASAS
  // ============================================================

  static Future<void> guardarTasas(Map<String, dynamic> tasas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTasas, jsonEncode(tasas));
    await prefs.setInt(_keyTasasTs, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<Map<String, dynamic>?> leerTasas() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyTasas);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> tasasFrescas() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_keyTasasTs);
    if (ts == null) return false;
    final diff = DateTime.now().millisecondsSinceEpoch - ts;
    return diff < _segundosFrescura * 1000;
  }

  // ============================================================
  // SALDOS
  // ============================================================

  static Future<void> guardarSaldos(Map<String, dynamic> saldos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySaldos, jsonEncode(saldos));
    await prefs.setInt(_keySaldosTs, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<Map<String, dynamic>?> leerSaldos() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keySaldos);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> saldosFrescos() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_keySaldosTs);
    if (ts == null) return false;
    final diff = DateTime.now().millisecondsSinceEpoch - ts;
    return diff < _segundosFrescura * 1000;
  }

  // Marcar saldos como viejos para forzar refresh en próximo GET
  static Future<void> marcarSaldosViejos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySaldosTs, 0);
    if (kDebugMode) print('CACHE: saldos marcados como viejos');
  }

  static Future<void> marcarTasasViejas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTasasTs, 0);
    if (kDebugMode) print('CACHE: tasas marcadas como viejas');
  }

  // ============================================================
  // TRABAJADOR POR CÉDULA
  // ============================================================

  static Future<void> guardarTrabajador(
      String cedula, Map<String, dynamic> datos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyTrabajadorPrefix$cedula', jsonEncode(datos));
  }

  static Future<Map<String, dynamic>?> leerTrabajador(String cedula) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_keyTrabajadorPrefix$cedula');
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> eliminarTrabajador(String cedula) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyTrabajadorPrefix$cedula');
  }

  // ============================================================
  // LISTA DE CUENTAS
  // ============================================================

  static Future<void> guardarCuentas(List<String> cuentas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCuentas, cuentas);
  }

  static Future<List<String>> leerCuentas() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyCuentas) ?? [];
  }

  // ============================================================
  // LIMPIAR COMPLETAMENTE (útil para debug)
  // ============================================================

  static Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<void> guardarBannerIgnorado(String fecha) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('banner_ignorado_fecha', fecha);
  }

  static Future<String?> leerBannerIgnorado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('banner_ignorado_fecha');
  }
}
