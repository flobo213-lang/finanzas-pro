import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../servicios/api_service.dart';
import '../servicios/cache_service.dart';

class ModalDisponibilidad extends StatefulWidget {
  final double tasaUSD;
  final double tasaUSDT;

  const ModalDisponibilidad({
    super.key,
    required this.tasaUSD,
    required this.tasaUSDT,
  });

  @override
  State<ModalDisponibilidad> createState() => _ModalDisponibilidadState();
}

class _ModalDisponibilidadState extends State<ModalDisponibilidad> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 2);

  late TextEditingController _tasaUsdCtrl;
  late TextEditingController _tasaUsdtCtrl;
  late TextEditingController _tasaEurCtrl;
  late TextEditingController _tasaParaleloCtrl;

  bool _procesando = false;
  double _ratioMargen = 1.2487033;
  bool _sincronizando = false;

  final List<Map<String, dynamic>> _cuentas = [
    {
      "nombre": "Caja Efectivo Bs",
      "icono": Icons.payments,
      "color": const Color(0xFF0F52BA),
      "moneda": "Bs",
    },
    {
      "nombre": "Efectivo USD",
      "icono": Icons.attach_money,
      "color": const Color(0xFF2E7D32),
      "moneda": "\$",
    },
    {
      "nombre": "USDT",
      "icono": Icons.currency_bitcoin,
      "color": const Color(0xFF2E7D32),
      "moneda": "₮",
    },
    {
      "nombre": "Bancamiga",
      "icono": Icons.account_balance,
      "color": const Color(0xFF0F52BA),
      "moneda": "Bs",
    },
    {
      "nombre": "BNC",
      "icono": Icons.account_balance,
      "color": const Color(0xFF0F52BA),
      "moneda": "Bs",
    },
    {
      "nombre": "BBVA",
      "icono": Icons.account_balance,
      "color": const Color(0xFF0F52BA),
      "moneda": "Bs",
    },
    {
      "nombre": "BDV",
      "icono": Icons.account_balance,
      "color": const Color(0xFF0F52BA),
      "moneda": "Bs",
    },
    {
      "nombre": "Banesco",
      "icono": Icons.account_balance,
      "color": const Color(0xFF0F52BA),
      "moneda": "Bs",
    },
  ];

  final Map<String, TextEditingController> _saldosControllers = {};

  @override
  void initState() {
    super.initState();
    _tasaUsdCtrl =
        TextEditingController(text: widget.tasaUSD.toStringAsFixed(2));
    _tasaUsdtCtrl =
        TextEditingController(text: widget.tasaUSDT.toStringAsFixed(2));
    _tasaEurCtrl = TextEditingController(text: "0.00");
    _tasaParaleloCtrl = TextEditingController(text: "0.00");

    for (var cta in _cuentas) {
      _saldosControllers[cta['nombre']] = TextEditingController(text: "0,00");
    }

    _cargarTodo();

    _tasaUsdCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _cargarTodo() async {
    final tasasCache = await CacheService.leerTasas();
    final saldosCache = await CacheService.leerSaldos();

    if (mounted) {
      setState(() {
        if (tasasCache != null) {
          _tasaUsdCtrl.text =
              ((tasasCache['tasaUSD'] as num?)?.toDouble() ?? widget.tasaUSD)
                  .toStringAsFixed(2);
          _tasaUsdtCtrl.text =
              ((tasasCache['tasaUSDT'] as num?)?.toDouble() ?? widget.tasaUSDT)
                  .toStringAsFixed(2);
          _tasaEurCtrl.text =
              ((tasasCache['tasaEUR'] as num?)?.toDouble() ?? 0.0)
                  .toStringAsFixed(2);
          _tasaParaleloCtrl.text =
              ((tasasCache['tasaUSDTParalelo'] as num?)?.toDouble() ?? 0.0)
                  .toStringAsFixed(2);
          _ratioMargen =
              (tasasCache['ratioMargen'] as num?)?.toDouble() ?? _ratioMargen;
        }
        _llenarSaldosDesdeMapa(saldosCache);
      });
    }

    try {
      final resTasas = await ApiService.obtenerTasas();
      final resSaldos = await ApiService.obtenerSaldos();
      if (!mounted) return;

      setState(() {
        _tasaUsdCtrl.text =
            ((resTasas['tasaUSD'] as num?)?.toDouble() ?? widget.tasaUSD)
                .toStringAsFixed(2);
        _tasaUsdtCtrl.text =
            ((resTasas['tasaUSDT'] as num?)?.toDouble() ?? widget.tasaUSDT)
                .toStringAsFixed(2);
        _tasaEurCtrl.text = ((resTasas['tasaEUR'] as num?)?.toDouble() ??
                (resTasas['tasas']?['EUR'] as num?)?.toDouble() ??
                0.0)
            .toStringAsFixed(2);
        _tasaParaleloCtrl.text =
            ((resTasas['tasaUSDTParalelo'] as num?)?.toDouble() ??
                    (resTasas['tasaUSDParalelo'] as num?)?.toDouble() ??
                    (resTasas['tasas']?['USD_PARALELO'] as num?)?.toDouble() ??
                    0.0)
                .toStringAsFixed(2);
        _ratioMargen =
            (resTasas['ratioMargen'] as num?)?.toDouble() ?? _ratioMargen;
        _llenarSaldosDesdeMapa(resSaldos);
      });
    } catch (_) {}
  }

  void _llenarSaldosDesdeMapa(Map<String, dynamic>? mapa) {
    if (mapa == null) return;

    Map<String, dynamic> mapaSaldos = {};
    if (mapa.containsKey('saldos') && mapa['saldos'] is Map) {
      mapaSaldos = Map<String, dynamic>.from(mapa['saldos']);
    } else {
      mapaSaldos = mapa;
    }

    if (mapaSaldos.isEmpty && mapa.containsKey('saldosMap')) {
      final sm = mapa['saldosMap'];
      if (sm is Map) {
        mapaSaldos = Map<String, dynamic>.from(sm);
      }
    }

    mapaSaldos.forEach((key, val) {
      double monto = 0.0;
      if (val is num) {
        monto = val.toDouble();
      } else if (val is Map) {
        monto = (val['monto'] as num?)?.toDouble() ?? 0.0;
      } else if (val is String) {
        monto = double.tryParse(val.replaceAll('.', '').replaceAll(',', '.')) ??
            0.0;
      }

      for (var ctrlKey in _saldosControllers.keys) {
        if (ctrlKey.toUpperCase() == key.toUpperCase() ||
            ctrlKey.toUpperCase().contains(key.toUpperCase())) {
          _saldosControllers[ctrlKey]!.text = _fmt.format(monto);
        }
      }
    });
  }

  @override
  void dispose() {
    _tasaUsdCtrl.dispose();
    _tasaUsdtCtrl.dispose();
    _tasaEurCtrl.dispose();
    _tasaParaleloCtrl.dispose();
    _saldosControllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  double _parseInput(String text) {
    if (text.trim().isEmpty) return 0.0;
    String clean = text.trim().replaceAll(' ', '');
    int dots = '.'.allMatches(clean).length;
    int commas = ','.allMatches(clean).length;
    if (dots > 0 && commas > 0) {
      int lastDot = clean.lastIndexOf('.');
      int lastComma = clean.lastIndexOf(',');
      if (lastComma > lastDot) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '');
      }
    } else if (commas == 1 && dots == 0) {
      clean = clean.replaceAll(',', '.');
    } else if (dots > 1) {
      clean = clean.replaceAll('.', '');
    } else if (commas > 1) {
      clean = clean.replaceAll(',', '');
    }
    return double.tryParse(clean) ?? 0.0;
  }

  double _totalBs() {
    double total = 0;
    for (var cta in _cuentas) {
      if (cta['moneda'] == 'Bs') {
        total += _parseInput(_saldosControllers[cta['nombre']]!.text);
      }
    }
    return total;
  }

  double _totalUsd() {
    return _parseInput(_saldosControllers['Efectivo USD']!.text);
  }

  double _totalUsdt() {
    return _parseInput(_saldosControllers['USDT']!.text);
  }

  void _mostrarMensaje(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 11)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    try {
      final resTasas = await ApiService.obtenerTasas();
      final resSaldos = await ApiService.obtenerSaldos();
      if (!mounted) return;

      setState(() {
        _tasaUsdCtrl.text =
            ((resTasas['tasaUSD'] as num?)?.toDouble() ?? widget.tasaUSD)
                .toStringAsFixed(2);
        _tasaUsdtCtrl.text =
            ((resTasas['tasaUSDT'] as num?)?.toDouble() ?? widget.tasaUSDT)
                .toStringAsFixed(2);
        _tasaEurCtrl.text = ((resTasas['tasaEUR'] as num?)?.toDouble() ??
                (resTasas['tasas']?['EUR'] as num?)?.toDouble() ??
                0.0)
            .toStringAsFixed(2);
        _tasaParaleloCtrl.text =
            ((resTasas['tasaUSDTParalelo'] as num?)?.toDouble() ??
                    (resTasas['tasaUSDParalelo'] as num?)?.toDouble() ??
                    (resTasas['tasas']?['USD_PARALELO'] as num?)?.toDouble() ??
                    0.0)
                .toStringAsFixed(2);
        _ratioMargen =
            (resTasas['ratioMargen'] as num?)?.toDouble() ?? _ratioMargen;
        _llenarSaldosDesdeMapa(resSaldos);
        _sincronizando = false;
      });
      _mostrarMensaje("Sincronizado con el servidor", Colors.blue.shade800);
    } catch (_) {
      setState(() => _sincronizando = false);
      _mostrarMensaje("Error al sincronizar", Colors.red.shade800);
    }
  }

  Future<void> _guardarCambios() async {
    final tasaUSD = _parseInput(_tasaUsdCtrl.text);
    final tasaUSDT = _parseInput(_tasaUsdtCtrl.text);
    final tasaEUR = _parseInput(_tasaEurCtrl.text);
    final tasaParalelo = _parseInput(_tasaParaleloCtrl.text);

    if (tasaUSD <= 0 || tasaUSDT <= 0) {
      _mostrarMensaje(
          "Las tasas BCV y USDT no pueden ser 0", Colors.red.shade800);
      return;
    }

    for (var cta in _cuentas) {
      final v = _parseInput(_saldosControllers[cta['nombre']]!.text);
      if (v < 0) {
        _mostrarMensaje("El saldo de ${cta['nombre']} no puede ser negativo",
            Colors.red.shade800);
        return;
      }
    }

    if (!mounted) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar actualización",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        content: const Text(
            "¿Estás seguro de actualizar las tasas y los saldos? Esta acción sobrescribe los valores actuales.",
            style: TextStyle(fontSize: 11)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F52BA),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Actualizar"),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmar != true) return;

    setState(() => _procesando = true);

    Map<String, double> nuevosSaldos = {};
    _saldosControllers.forEach((cuenta, ctrl) {
      nuevosSaldos[cuenta] = _parseInput(ctrl.text);
    });

    final payload = {
      "tasaUSD": tasaUSD,
      "tasaUSDT": tasaUSDT,
      "tasaEUR": tasaEUR,
      "tasaUSDTParalelo": tasaParalelo,
      "saldos": nuevosSaldos,
    };
    try {
      final res = await ApiService.registrarAccionConRespuesta(
          "actualizarSaldosYTasas", payload);

      if (!mounted) return;
      setState(() => _procesando = false);

      if (res['status'] == "DESCUADRE") {
        final List difs = (res['diferencias'] as List?) ?? [];
        await _mostrarDialogoDescuadre(difs);
        return;
      }

      await CacheService.guardarTasas({
        "tasaUSD": tasaUSD,
        "tasaUSDT": tasaUSDT,
        "tasaEUR": tasaEUR,
        "tasaUSDTParalelo": tasaParalelo,
        "ratioMargen": _ratioMargen,
      });
      await CacheService.guardarSaldos({
        "saldos": nuevosSaldos,
      });

      if (!mounted) return;

      if (res['status'] == "SUCCESS" || res['exito'] == true) {
        _mostrarMensaje("Saldos y tasas actualizados", Colors.green.shade800);
        Navigator.pop(context, true);
      } else {
        _mostrarMensaje(
            res['mensaje'] ?? "Error al actualizar", Colors.red.shade800);
      }
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje("Error: $e", Colors.red.shade800);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ============================================================
  // DIÁLOGO DE DESCUADRE
  // ============================================================
  Future<void> _mostrarDialogoDescuadre(List diferencias) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFB00020),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text("DESCUADRE DETECTADO",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5)),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "No se guardó nada. Los saldos no coinciden con lo que el sistema calculó. Registra las operaciones faltantes antes de actualizar.",
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Expanded(
                                    flex: 3,
                                    child: Text("Cuenta",
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold))),
                                Expanded(
                                    flex: 2,
                                    child: Text("Sistema",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold))),
                                Expanded(
                                    flex: 2,
                                    child: Text("Real",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold))),
                                Expanded(
                                    flex: 2,
                                    child: Text("Dif.",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          ...diferencias.map((d) {
                            final cuenta = d['cuenta'].toString();
                            final enSistema =
                                (d['enSistema'] as num).toDouble();
                            final enReal = (d['enReal'] as num).toDouble();
                            final dif = (d['diferencia'] as num).toDouble();
                            final esFaltante = dif < 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              child: Row(
                                children: [
                                  Expanded(
                                      flex: 3,
                                      child: Text(cuenta,
                                          style:
                                              const TextStyle(fontSize: 10.5))),
                                  Expanded(
                                      flex: 2,
                                      child: Text(_fmt.format(enSistema),
                                          textAlign: TextAlign.right,
                                          style:
                                              const TextStyle(fontSize: 10.5))),
                                  Expanded(
                                      flex: 2,
                                      child: Text(_fmt.format(enReal),
                                          textAlign: TextAlign.right,
                                          style:
                                              const TextStyle(fontSize: 10.5))),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                        (esFaltante ? '' : '+') +
                                            _fmt.format(dif),
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: esFaltante
                                                ? Colors.red.shade800
                                                : Colors.green.shade800)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: Colors.orange.shade900),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              "Ve al módulo 2 (Operaciones) y registra lo que falte con la fecha correspondiente. Cuando el saldo del sistema coincida con el real, podrás actualizar sin problema.",
                              style: TextStyle(
                                  fontSize: 10, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F52BA),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text("Entendido",
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorPct(double pct) {
    if (pct < 5) return Colors.grey.shade700;
    if (pct < 15) return Colors.amber.shade800;
    if (pct < 25) return Colors.green.shade600;
    return Colors.green.shade800;
  }

  double _pctVsBCV(double tasa) {
    final base = _parseInput(_tasaUsdCtrl.text);
    if (base <= 0 || tasa <= 0) return 0.0;
    return ((tasa - base) / base) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F52BA), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(Icons.account_balance_wallet,
                            size: 15, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "TASAS Y DISPONIBILIDAD",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: _sincronizando ? null : _sincronizar,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: _sincronizando
                              ? const SizedBox(
                                  height: 12,
                                  width: 12,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.sync,
                                  size: 14, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // CONTENIDO
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TASAS
                    _buildSeccion(
                      icono: Icons.trending_up,
                      titulo: "TASAS OFICIALES",
                      color: Colors.blue.shade700,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildCampoTasa(
                                  label: "BCV",
                                  sufijo: "Bs/\$",
                                  icono: Icons.attach_money,
                                  color: const Color(0xFF0F52BA),
                                  controller: _tasaUsdCtrl,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCampoTasa(
                                  label: "USDT",
                                  sufijo: "Bs/₮",
                                  icono: Icons.currency_bitcoin,
                                  color: Colors.green.shade700,
                                  controller: _tasaUsdtCtrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCampoTasa(
                                  label: "EUR",
                                  sufijo: "Bs/€",
                                  icono: Icons.euro,
                                  color: Colors.blue.shade700,
                                  controller: _tasaEurCtrl,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCampoTasaCalculado(
                                  label: "USDT VALERY",
                                  sufijo: "Bs/₮",
                                  icono: Icons.calculate,
                                  color: Colors.purple.shade700,
                                  valor: _ratioMargen *
                                      _parseInput(_tasaUsdCtrl.text),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // SALDOS
                    _buildSeccion(
                      icono: Icons.list_alt,
                      titulo: "SALDOS DISPONIBLES",
                      color: Colors.teal.shade700,
                      child: Column(
                        children: _cuentas.map((cta) {
                          return _buildFilaCuenta(
                            nombre: cta['nombre'],
                            icono: cta['icono'] as IconData,
                            color: cta['color'] as Color,
                            moneda: cta['moneda'] as String,
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // TOTALES
                    Row(
                      children: [
                        Expanded(
                          child: _buildBloqueTotal(
                            "TOTAL BS",
                            _totalBs(),
                            "Bs",
                            const Color(0xFF0F52BA),
                            Icons.payments,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildBloqueTotal(
                            "TOTAL USD",
                            _totalUsd(),
                            "\$",
                            Colors.green.shade700,
                            Icons.attach_money,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildBloqueTotal(
                            "TOTAL USDT",
                            _totalUsdt(),
                            "₮",
                            Colors.green.shade800,
                            Icons.currency_bitcoin,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // BOTÓN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F52BA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: _procesando
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save, size: 16),
                  label: Text(
                    _procesando ? "GUARDANDO..." : "GUARDAR Y ACTUALIZAR",
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _procesando ? null : _guardarCambios,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WIDGETS COMPACTOS
  // ============================================================

  Widget _buildSeccion({
    required IconData icono,
    required String titulo,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icono, size: 11, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildCampoTasa({
    required String label,
    required String sufijo,
    required IconData icono,
    required Color color,
    required TextEditingController controller,
    double? pct,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: color.withValues(alpha: 0.8),
                    letterSpacing: 0.3)),
            if (pct != null) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _colorPct(pct).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                  border:
                      Border.all(color: _colorPct(pct).withValues(alpha: 0.4)),
                ),
                child: Text(
                  "${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)} %",
                  style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                      color: _colorPct(pct)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 28,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color),
            decoration: InputDecoration(
              prefixIcon: Icon(icono, size: 11, color: color),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              suffixText: sufijo,
              suffixStyle: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 8, color: color),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: color, width: 2),
              ),
              filled: true,
              fillColor: color.withValues(alpha: 0.05),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoTasaCalculado({
    required String label,
    required String sufijo,
    required IconData icono,
    required Color color,
    required double valor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.8),
                letterSpacing: 0.3)),
        const SizedBox(height: 3),
        SizedBox(
          height: 28,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(icono, size: 11, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      valor > 0 ? valor.toStringAsFixed(2) : "—",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                  ),
                ),
                Text(sufijo,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                        color: color)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilaCuenta({
    required String nombre,
    required IconData icono,
    required Color color,
    required String moneda,
  }) {
    final ctrl = _saldosControllers[nombre]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icono, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              nombre,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10.5,
                color: color,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: ctrl,
                textAlign: TextAlign.right,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                decoration: InputDecoration(
                  suffixText: moneda,
                  suffixStyle: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: color.withValues(alpha: 0.7)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide(color: color, width: 2),
                  ),
                  filled: true,
                  fillColor: color.withValues(alpha: 0.03),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloqueTotal(
      String titulo, double monto, String moneda, Color color, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 10, color: color),
              const SizedBox(width: 3),
              Text(titulo,
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              _fmt.format(monto),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          Text(moneda,
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}
