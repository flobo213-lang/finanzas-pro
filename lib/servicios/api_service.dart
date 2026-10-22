import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cache_service.dart';
import 'queue_service.dart';

class ApiService {
  static const String urlAppScript =
      "https://script.google.com/macros/s/AKfycbzRs6qTqsJN9yFS239aAM9LSYv6WPDqe_ZhjaYpw4Em-EgHuS9CtqHKBBJxMd16cQVVwg/exec";

  static const Map<String, String> _headersCORS = {
    'Content-Type': 'text/plain;charset=utf-8',
  };

  // ==========================================================================
  // POST CON MANEJO DE 302 Y COLA DE PENDIENTES
  // ==========================================================================
  static Future<Map<String, dynamic>> _postConManejoRedirect(
    String action,
    Map<String, dynamic> payload, {
    bool permitirCola = true,
  }) async {
    try {
      // Clave única por operación para evitar duplicados
      payload['idempotenciaKey'] ??=
          DateTime.now().millisecondsSinceEpoch.toString() +
              "-" +
              action.hashCode.toString();
      final payloadJson = jsonEncode(payload);
      final encodedPayload = Uri.encodeComponent(payloadJson);
      final url = "$urlAppScript?action=$action&payload=$encodedPayload";

      if (kDebugMode) print("=== ENVIANDO GET-POST $action ===");

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'text/plain;charset=utf-8'},
      ).timeout(const Duration(seconds: 120));

      if (kDebugMode) {
        print("=== RESPUESTA $action (${response.statusCode}) ===");
      }

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            if (decoded['status'] == 'ERROR') {
              return decoded;
            }
            await _aplicarEfectosLocales(action, payload);
            await CacheService.marcarSaldosViejos();
            return decoded;
          }
        } catch (e) {
          if (kDebugMode) print("Error decodificando JSON: $e");
        }
      }

      if (permitirCola) {
        await _encolarOperacion(action, payload);
        return {
          'status': 'PENDIENTE',
          'exito': true,
          'pendiente': true,
          'mensaje':
              'Guardado localmente. Se sincronizará automáticamente en 1 minuto.',
        };
      }

      return {
        "status": "ERROR",
        "mensaje": "Servidor respondió con código ${response.statusCode}"
      };
    } catch (e) {
      if (kDebugMode) print("Error POST $action: $e");

      if (permitirCola) {
        await _encolarOperacion(action, payload);
        return {
          'status': 'PENDIENTE',
          'exito': true,
          'pendiente': true,
          'mensaje':
              'Guardado localmente. Se sincronizará automáticamente en 1 minuto.',
        };
      }

      return {"status": "ERROR", "mensaje": "Error de red: $e"};
    }
  }

  // ==========================================================================
  // ENCOLAR OPERACIÓN Y APLICAR EFECTOS LOCALES
  // ==========================================================================
  static Future<void> _encolarOperacion(
      String action, Map<String, dynamic> payload) async {
    await QueueService.agregar(action: action, payload: payload);
    await _aplicarEfectosLocales(action, payload);
  }

  static Future<void> _aplicarEfectosLocales(
      String action, Map<String, dynamic> payload) async {
    final cache = await CacheService.leerSaldos();
    if (cache == null) return;

    Map<String, double> saldos = {};
    if (cache.containsKey('saldos') && cache['saldos'] is Map) {
      final s = cache['saldos'] as Map;
      s.forEach((k, v) {
        if (v is num) saldos[k.toString()] = v.toDouble();
      });
    } else if (cache.containsKey('saldosMap') && cache['saldosMap'] is Map) {
      final s = cache['saldosMap'] as Map;
      s.forEach((k, v) {
        if (v is num) saldos[k.toString()] = v.toDouble();
      });
    } else {
      cache.forEach((k, v) {
        if (v is num && k != 'status' && k != 'exito') {
          saldos[k.toString()] = v.toDouble();
        }
      });
    }

    if (saldos.isEmpty) return;

    if (action == 'registrarOperacion') {
      if (payload['cuentasDesglose'] is List) {
        for (var it in payload['cuentasDesglose']) {
          final cta = it['cuenta']?.toString() ?? '';
          final monto = (it['monto'] as num?)?.toDouble() ?? 0;
          if (saldos.containsKey(cta)) {
            saldos[cta] = saldos[cta]! - monto;
          }
        }
      } else {
        final cta = payload['cuentaSalida']?.toString() ?? '';
        final monto = (payload['montoBsPagado'] as num?)?.toDouble() ?? 0;
        if (saldos.containsKey(cta)) {
          saldos[cta] = saldos[cta]! - monto;
        }
      }
    } else if (action == 'registrarTraspaso') {
      final origen = payload['cuentaOrigen']?.toString() ?? '';
      final destino = payload['cuentaDestino']?.toString() ?? '';
      final monto = (payload['monto'] as num?)?.toDouble() ?? 0;
      final tipo = payload['tipoTraspaso']?.toString() ?? '';
      final comision = tipo == 'OTRO_BANCO' ? monto * 0.003 : 0;
      if (saldos.containsKey(origen)) {
        saldos[origen] = saldos[origen]! - monto - comision;
      }
      if (saldos.containsKey(destino)) {
        saldos[destino] = saldos[destino]! + monto;
      }
    } else if (action == 'registrarCompraDivisa') {
      final origen = payload['cuentaOrigen']?.toString() ?? '';
      final destino = payload['cuentaDestino']?.toString() ?? '';
      final montoBs = (payload['montoBs'] as num?)?.toDouble() ?? 0;
      final montoDiv = (payload['montoDivisa'] as num?)?.toDouble() ?? 0;
      if (saldos.containsKey(origen)) {
        saldos[origen] = saldos[origen]! - montoBs;
      }
      if (saldos.containsKey(destino)) {
        saldos[destino] = saldos[destino]! + montoDiv;
      }
    } else if (action == 'procesarOperacionTrabajador') {
      final cta = payload['cuentaSalida']?.toString() ?? '';
      final monto = (payload['montoBsCalculado'] as num?)?.toDouble() ?? 0;
      if (saldos.containsKey(cta)) {
        saldos[cta] = saldos[cta]! - monto;
      }
    } else if (action == 'registrarCierreJornada') {
      if (payload['desglose'] is Map) {
        final desglose = Map<String, dynamic>.from(payload['desglose']);
        desglose.forEach((cta, val) {
          final punto = (val['punto'] as num?)?.toDouble() ?? 0;
          final pm = (val['pagoMovil'] as num?)?.toDouble() ?? 0;
          if (saldos.containsKey(cta)) {
            saldos[cta] = saldos[cta]! + punto + pm;
          }
        });
      }
    }

    await CacheService.guardarSaldos({'saldos': saldos});
  }

  // ==========================================================================
  // SINCRONIZAR UN ITEM PENDIENTE
  // ==========================================================================
  static Future<Map<String, dynamic>> sincronizarItem(
      String action, Map<String, dynamic> payload) async {
    return await _postConManejoRedirect(
      action,
      payload,
      permitirCola: false,
    );
  }

  // ==========================================================================
  // GETS
  // ==========================================================================

  static Future<Map<String, dynamic>> obtenerTasas() async {
    if (await CacheService.tasasFrescas()) {
      final cache = await CacheService.leerTasas();
      if (cache != null) return cache;
    }
    try {
      final response = await http
          .get(
            Uri.parse("$urlAppScript?action=obtenerTasas"),
            headers: _headersCORS,
          )
          .timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          await CacheService.guardarTasas(decoded);
          return decoded;
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error obtenerTasas: $e");
    }
    final cacheViejo = await CacheService.leerTasas();
    if (cacheViejo != null) return cacheViejo;
    return {
      "status": "SUCCESS",
      "tasaUSD": 827.74,
      "tasaUSDT": 965.00,
    };
  }

  static Future<Map<String, dynamic>> obtenerSaldos() async {
    if (await CacheService.saldosFrescos()) {
      final cache = await CacheService.leerSaldos();
      if (cache != null) return cache;
    }
    try {
      final response = await http
          .get(
            Uri.parse("$urlAppScript?action=obtenerSaldos"),
            headers: _headersCORS,
          )
          .timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          await CacheService.guardarSaldos(decoded);
          return decoded;
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error obtenerSaldos: $e");
    }
    final cacheViejo = await CacheService.leerSaldos();
    if (cacheViejo != null) return cacheViejo;
    return {};
  }

  static Future<Map<String, dynamic>> verificarEstadoDelDia() async {
    try {
      final response = await http
          .get(
            Uri.parse("$urlAppScript?action=verificarEstadoDelDia"),
            headers: _headersCORS,
          )
          .timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error verificarEstadoDelDia: $e");
    }
    return {
      "status": "ERROR",
      "tasasCargadas": true,
      "esFinDeSemana": false,
    };
  }

  static Future<Map<String, dynamic>> buscarTrabajadorCompleto(
      String cedula) async {
    final cache = await CacheService.leerTrabajador(cedula);
    if (cache != null && cache['encontrado'] == true) {
      _refrescarTrabajadorBackground(cedula);
      return cache;
    }
    return await _buscarTrabajadorServidor(cedula);
  }

  static Future<Map<String, dynamic>> _buscarTrabajadorServidor(
      String cedula) async {
    try {
      final response = await http
          .get(
            Uri.parse("$urlAppScript?action=buscarTrabajador&cedula=$cedula"),
            headers: _headersCORS,
          )
          .timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          await CacheService.guardarTrabajador(cedula, decoded);
          return decoded;
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error buscarTrabajadorCompleto: $e");
    }
    return {"encontrado": false, "debug": "No se pudo conectar al servidor"};
  }

  static void _refrescarTrabajadorBackground(String cedula) {
    Future(() async {
      try {
        await _buscarTrabajadorServidor(cedula);
      } catch (_) {}
    });
  }

  static final Map<String, Map<String, dynamic>> _cacheConsultas = {};

  static Future<Map<String, dynamic>> obtenerConsultasConFecha(
      String fechaDesde,
      {String? fechaHasta}) async {
    Future<Map<String, dynamic>> obtenerResumenGerencial(String fecha) async {
      try {
        final response = await http
            .get(
              Uri.parse(
                  "$urlAppScript?action=obtenerResumenGerencial&fecha=$fecha"),
              headers: _headersCORS,
            )
            .timeout(const Duration(seconds: 120));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      } catch (e) {
        if (kDebugMode) print("Error obtenerResumenGerencial: $e");
      }
      return {
        "status": "ERROR",
        "fecha": fecha,
        "ventas": {"pos": 0, "pm": 0, "efectivo": 0, "divisas": 0},
        "saldos": [],
        "resumen": {
          "ingresos": 0,
          "egresos": 0,
          "comisiones": 0,
          "ganancia": 0,
          "margen": 0
        },
        "categorias": []
      };
    }

    final fh = fechaHasta ?? fechaDesde;
    final key = "$fechaDesde|$fh";

    if (_cacheConsultas.containsKey(key)) {
      if (kDebugMode) print("CONSULTAS: cache $key");
      return _cacheConsultas[key]!;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
                "$urlAppScript?action=obtenerConsultasConFecha&fechaDesde=$fechaDesde&fechaHasta=$fh"),
            headers: _headersCORS,
          )
          .timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          _cacheConsultas[key] = decoded;
          return decoded;
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error obtenerConsultasConFecha: $e");
    }
    return {
      "status": "ERROR",
      "movimientos": [],
      "totalEgresos": 0.0,
      "totalNomina": 0.0,
      "totalVentas": 0.0
    };
  }

  static void limpiarCacheConsultas() {
    _cacheConsultas.clear();
  }

  static Future<Map<String, dynamic>> obtenerPendientes(
      {bool todos = false}) async {
    try {
      final url = "$urlAppScript?action=obtenerPendientes&todos=$todos";
      final response = await http
          .get(Uri.parse(url), headers: _headersCORS)
          .timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error obtenerPendientes: $e");
    }
    return {"status": "ERROR", "pendientes": [], "totalPorPagar": 0.0};
  }

  static Future<Map<String, dynamic>> registrarPendiente(
      Map<String, dynamic> payload) async {
    return await _postConManejoRedirect("registrarPendiente", payload);
  }

  static Future<Map<String, dynamic>> marcarPendientePagado(
      Map<String, dynamic> payload) async {
    return await _postConManejoRedirect("marcarPendientePagado", payload);
  }

  static Future<Map<String, dynamic>> obtenerResumenGerencial(
      String fecha) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                "$urlAppScript?action=obtenerResumenGerencial&fecha=$fecha"),
            headers: _headersCORS,
          )
          .timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error obtenerResumenGerencial: $e");
    }
    return {
      "status": "ERROR",
      "fecha": fecha,
      "ventas": {"pos": 0, "pm": 0, "efectivo": 0, "divisas": 0},
      "saldos": [],
      "resumen": {
        "ingresos": 0,
        "egresos": 0,
        "comisiones": 0,
        "ganancia": 0,
        "margen": 0
      },
      "categorias": []
    };
  }

  // ==========================================================================
  // POSTS PÚBLICOS
  // ==========================================================================

  static Future<Map<String, dynamic>> registrarAccionConRespuesta(
      String action, Map<String, dynamic> payload) async {
    return await _postConManejoRedirect(action, payload);
  }

  static Future<Map<String, dynamic>> registrarCierrePos({
    required double montoBrutoBs,
    required String bancoPOS,
    required String cuentaDestino,
  }) async {
    return await _postConManejoRedirect("registrarCierrePos", {
      "montoBrutoBs": montoBrutoBs,
      "bancoPOS": bancoPOS,
      "cuentaDestino": cuentaDestino,
    });
  }

  static Future<Map<String, dynamic>> registrarCargoFijo({
    required String cuentaSalida,
    String concepto = "Cargo fijo mensual de plataforma",
  }) async {
    return await _postConManejoRedirect("registrarCargoFijo", {
      "cuentaSalida": cuentaSalida,
      "concepto": concepto,
    });
  }
}
