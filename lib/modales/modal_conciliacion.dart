import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../servicios/api_service.dart';

class ModalConciliacion extends StatefulWidget {
  final double tasaUSD;
  final double tasaUSDT;

  const ModalConciliacion({
    super.key,
    required this.tasaUSD,
    required this.tasaUSDT,
  });

  @override
  State<ModalConciliacion> createState() => _ModalConciliacionState();
}

class _PartidaData {
  String cuenta;
  final TextEditingController posCtrl = TextEditingController();
  final TextEditingController pmCtrl = TextEditingController();
  bool comision1Activa = false;
  bool comision2Activa = false;

  _PartidaData({required this.cuenta});

  void dispose() {
    posCtrl.dispose();
    pmCtrl.dispose();
  }
}

class _GastoData {
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController montoCtrl = TextEditingController();
  String categoria = "OPERATIVO";
  String cuenta = "Caja Efectivo Bs";
  bool afectaCuadre = true;

  void dispose() {
    descCtrl.dispose();
    montoCtrl.dispose();
  }
}

class _ModalConciliacionState extends State<ModalConciliacion> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 2);

  final TextEditingController _observacionCtrl =
      TextEditingController(text: "CIERRE DE CAJA / TURNO");
  final TextEditingController _ventaSistemaCtrl = TextEditingController();
  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _pagoMovilCtrl = TextEditingController();

  bool _procesando = false;
  DateTime _fechaCierre = DateTime.now();

  double _ingresosDeclaradosBs = 0.0;
  int _ingresosDeclaradosCount = 0;

  String _cuentaSeleccionada = "Bancamiga";
  final List<String> _cuentasDisponibles = [
    "Bancamiga",
    "BNC",
    "BBVA",
    "BDV",
    "Banesco",
    "Caja Efectivo Bs",
    "Efectivo USD",
    "USDT",
  ];
  final List<String> _bancos = ["Bancamiga", "BNC", "BBVA", "BDV", "Banesco"];

  final List<_PartidaData> _partidas = [];
  final List<_GastoData> _gastosVenta = [];

  // Movimientos del día (solo los de VENTA_DIA)
  List<Map<String, dynamic>> _movimientosDelDia = [];
  final Set<String> _movimientosMarcados = {};
  bool _mostrarMovimientos = false;
  bool _cargandoMovimientos = false;

  final List<String> _categoriasGasto = [
    "OPERATIVO",
    "PERSONAL",
    "PROVEEDORES",
    "SERVICIOS",
    "MANTENIMIENTO",
    "PRESTAMO_TRABAJADOR",
    "OTROS",
  ];

  @override
  void initState() {
    super.initState();
    _cargarIngresosDeclarados();
    _autoCargarMovimientos();
  }

  @override
  void dispose() {
    _observacionCtrl.dispose();
    _ventaSistemaCtrl.dispose();
    _montoCtrl.dispose();
    _pagoMovilCtrl.dispose();
    for (var p in _partidas) {
      p.dispose();
    }
    for (var g in _gastosVenta) {
      g.dispose();
    }
    super.dispose();
  }

  // ============================================================
  // LIMPIEZA DE CONCEPTO (quita "| IDEMP:xxxxx")
  // ============================================================
  String _limpiarConcepto(String concepto) {
    final idx = concepto.indexOf('| IDEMP:');
    if (idx > 0) return concepto.substring(0, idx).trim();
    final idx2 = concepto.indexOf('IDEMP:');
    if (idx2 > 0) return concepto.substring(0, idx2).trim();
    return concepto;
  }

  Future<void> _cargarIngresosDeclarados() async {
    try {
      final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaCierre);
      final res = await ApiService.registrarAccionConRespuesta(
        "obtenerIngresosDeclaradosDelDia",
        {"fecha": fechaStr},
      );
      if (!mounted) return;
      setState(() {
        _ingresosDeclaradosBs = (res['totalBs'] as num?)?.toDouble() ?? 0.0;
        _ingresosDeclaradosCount = (res['cantidad'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _autoCargarMovimientos() async {
    setState(() => _cargandoMovimientos = true);
    try {
      final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaCierre);
      final res = await ApiService.registrarAccionConRespuesta(
        "obtenerMovimientosDelDia",
        {"fecha": fechaStr},
      );
      if (!mounted) return;
      final todos = List<Map<String, dynamic>>.from(res['movimientos'] ?? []);

      // === FILTRO: solo movimientos con origen = VENTA_DIA ===
      final soloVentaDia = todos.where((m) {
        final origen = (m['origenFondos'] ?? '').toString().toUpperCase();
        return origen == 'VENTA_DIA';
      }).toList();

      setState(() {
        _movimientosDelDia = soloVentaDia;
        _movimientosMarcados.clear();
        for (var m in soloVentaDia) {
          _movimientosMarcados.add(m['idTx'].toString());
        }
        _cargandoMovimientos = false;
        _mostrarMovimientos = soloVentaDia.isNotEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoMovimientos = false);
    }
  }

  double _parseInput(String input) {
    if (input.trim().isEmpty) return 0.0;
    String clean = input.trim().replaceAll(' ', '');
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
      int commaPos = clean.indexOf(',');
      int digitsAfter = clean.length - commaPos - 1;
      if (digitsAfter == 3 && commaPos > 0 && clean.length > 4) {
        clean = clean.replaceAll(',', ''); // 10,100 -> 10100
      } else {
        clean = clean.replaceAll(',', '.'); // 10,10 -> 10.10
      }
    } else if (dots == 1 && commas == 0) {
      int dotPos = clean.indexOf('.');
      int digitsAfter = clean.length - dotPos - 1;
      if (digitsAfter == 3 && dotPos > 0 && clean.length > 4) {
        clean = clean.replaceAll('.', ''); // 10.100 -> 10100
      }
    } else if (dots > 1) {
      clean = clean.replaceAll('.', '');
    } else if (commas > 1) {
      clean = clean.replaceAll(',', '');
    }

    return double.tryParse(clean) ?? 0.0;
  }

  String _monedaDe(String cuenta) {
    if (cuenta == "Efectivo USD") return "USD";
    if (cuenta == "USDT") return "USDT";
    return "BS";
  }

  IconData _iconoCuenta(String cuenta) {
    if (cuenta == "Efectivo USD") return Icons.attach_money;
    if (cuenta == "USDT") return Icons.currency_bitcoin;
    if (cuenta == "Caja Efectivo Bs") return Icons.payments;
    return Icons.account_balance;
  }

  Color _colorCuenta(String cuenta) {
    if (cuenta == "Efectivo USD") return Colors.green.shade700;
    if (cuenta == "USDT") return Colors.green.shade800;
    return const Color(0xFF0F52BA);
  }

  bool _esBanco(String c) => _bancos.contains(c);

  double _montoEnBs(double monto, String cuenta) {
    if (cuenta == "Efectivo USD") return monto * widget.tasaUSD;
    if (cuenta == "USDT") return monto * widget.tasaUSDT;
    return monto;
  }

  double _netoPos(_PartidaData p) {
    final pos = _parseInput(p.posCtrl.text);
    if (pos <= 0) return 0.0;
    double n = pos;
    if (p.comision1Activa) n *= 0.9975;
    if (p.comision2Activa) n *= 0.9925;
    return n;
  }

  double _comisionP(_PartidaData p) {
    final pos = _parseInput(p.posCtrl.text);
    if (pos <= 0) return 0.0;
    if (p.cuenta == "Efectivo USD" || p.cuenta == "USDT") return 0.0;
    return pos - _netoPos(p);
  }

  double _totalBruto() {
    double t = 0;
    for (var p in _partidas) {
      final pos = _parseInput(p.posCtrl.text);
      final pm = _parseInput(p.pmCtrl.text);
      t += _montoEnBs(pos, p.cuenta);
      t += _montoEnBs(pm, p.cuenta);
    }
    return t;
  }

  double _totalComisiones() {
    double t = 0;
    for (var p in _partidas) {
      t += _comisionP(p);
    }
    return t;
  }

  double _totalGastosAfectan() {
    double t = 0;
    for (var g in _gastosVenta) {
      if (g.afectaCuadre) {
        t += _montoEnBs(_parseInput(g.montoCtrl.text), g.cuenta);
      }
    }
    return t;
  }

  double _totalGastosRegistrados() {
    double t = 0;
    for (var g in _gastosVenta) {
      t += _montoEnBs(_parseInput(g.montoCtrl.text), g.cuenta);
    }
    return t;
  }

  double _totalReferencia() {
    double t = 0;
    for (var m in _movimientosDelDia) {
      if (!_movimientosMarcados.contains(m['idTx'].toString())) continue;
      final v = (m['montoNeto'] as num?)?.toDouble() ?? 0.0;
      final com = (m['comision'] as num?)?.toDouble() ?? 0.0;
      final tipo = (m['tipo'] ?? '').toString().toUpperCase();
      final monto = (v > 0 ? v : (m['monto'] as num?)?.toDouble() ?? 0.0) + com;
      if (tipo.indexOf("INGRESO") == 0) {
        t -= monto;
      } else {
        t += monto;
      }
    }
    return t;
  }

  // Venta del sistema: input en $, se convierte a Bs con la tasa
  double _ventaSistemaBs() {
    return _parseInput(_ventaSistemaCtrl.text) * widget.tasaUSD;
  }

  void _agregarPartida() {
    final pos = _parseInput(_montoCtrl.text);
    final pm = _parseInput(_pagoMovilCtrl.text);
    if (pos <= 0 && pm <= 0) return;

    final idx = _partidas.indexWhere((p) => p.cuenta == _cuentaSeleccionada);
    setState(() {
      if (idx != -1) {
        final p = _partidas[idx];
        if (pos > 0) {
          final actual = _parseInput(p.posCtrl.text);
          p.posCtrl.text = (actual + pos).toStringAsFixed(2);
        }
        if (pm > 0) {
          final actual = _parseInput(p.pmCtrl.text);
          p.pmCtrl.text = (actual + pm).toStringAsFixed(2);
        }
      } else {
        final p = _PartidaData(cuenta: _cuentaSeleccionada);
        if (pos > 0) p.posCtrl.text = pos.toStringAsFixed(2);
        if (pm > 0) p.pmCtrl.text = pm.toStringAsFixed(2);
        _partidas.add(p);
      }
      _montoCtrl.clear();
      _pagoMovilCtrl.clear();
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _quitarPartida(int i) {
    setState(() {
      _partidas[i].dispose();
      _partidas.removeAt(i);
    });
  }

  void _toggleComision(int i, int num) {
    setState(() {
      final p = _partidas[i];
      if (num == 1) {
        p.comision1Activa = !p.comision1Activa;
      } else {
        p.comision2Activa = !p.comision2Activa;
      }
    });
  }

  void _agregarGasto() {
    setState(() => _gastosVenta.add(_GastoData()));
  }

  void _quitarGasto(int i) {
    setState(() {
      _gastosVenta[i].dispose();
      _gastosVenta.removeAt(i);
    });
  }

  void _toggleMovimiento(String idTx) {
    setState(() {
      if (_movimientosMarcados.contains(idTx)) {
        _movimientosMarcados.remove(idTx);
      } else {
        _movimientosMarcados.add(idTx);
      }
    });
  }

  void _procesarCierreFinal() async {
    final ventaBs = _ventaSistemaBs();
    final distribuido = _totalBruto();
    final gastosAfectan = _totalGastosAfectan();
    final movMarcados = _totalReferencia();

    if (ventaBs <= 0) {
      _snack("Falta la venta del sistema.", Colors.red);
      return;
    }
    if (distribuido <= 0) {
      _snack("No hay distribución cargada.", Colors.red);
      return;
    }

    setState(() => _procesando = true);

    Map<String, dynamic> desglose = {};
    for (var p in _partidas) {
      final cta = p.cuenta;
      final pos = _parseInput(p.posCtrl.text);
      final pm = _parseInput(p.pmCtrl.text);
      if (pos <= 0 && pm <= 0) continue;
      desglose[cta] = {
        "punto": pos,
        "pagoMovil": pm,
        "moneda": _monedaDe(cta) == "Bs" ? "BS" : _monedaDe(cta),
        "comision1Activa": p.comision1Activa,
        "comision2Activa": p.comision2Activa,
        "comision1Porcentaje": 0.25,
        "comision2Porcentaje": 0.75,
      };
    }

    final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaCierre);
    final descuadre = ventaBs - distribuido - gastosAfectan - movMarcados;

    final payload = {
      "montoVentaUSD": _parseInput(_ventaSistemaCtrl.text),
      "ventaEsperadaBs": ventaBs,
      "totalCargadoBs": distribuido,
      "totalComisionesBs": _totalComisiones(),
      "ingresosDeclaradosBs": _ingresosDeclaradosBs,
      "descuadreBs": descuadre,
      "observacion": _observacionCtrl.text.trim(),
      "desglose": desglose,
      "tasaUSD": widget.tasaUSD,
      "tasaUSDT": widget.tasaUSDT,
      "fechaOperacion": fechaStr,
    };

    final res = await ApiService.registrarAccionConRespuesta(
        "registrarCierreJornada", payload);
    if (!mounted) return;

    if (!(res['status'] == "SUCCESS" || res['exito'] == true)) {
      setState(() => _procesando = false);
      _snack(res['mensaje'] ?? "Error al procesar cierre", Colors.red.shade800);
      return;
    }

    int ok = 0, fail = 0;
    for (var g in _gastosVenta) {
      final monto = _parseInput(g.montoCtrl.text);
      if (monto <= 0) continue;
      final desc = g.descCtrl.text.trim().isEmpty
          ? "Gasto del cierre"
          : g.descCtrl.text.trim();
      final gp = {
        "tipoOperacion": "EGRESO",
        "categoria": g.categoria,
        "concepto": desc,
        "montoBsPagado": monto,
        "cuentaSalida": g.cuenta,
        "moneda": "BS",
        "tasaUSD": widget.tasaUSD,
        "tasaUSDT": widget.tasaUSDT,
        "cuentasDesglose": [
          {
            "cuenta": g.cuenta,
            "monto": monto,
            "moneda": _monedaDe(g.cuenta) == "Bs" ? "BS" : _monedaDe(g.cuenta),
            "montoBs": monto,
          }
        ],
        "comisionBs": 0,
        "metodoPago": "EFECTIVO",
        "origenFondos": g.afectaCuadre ? "VENTA_DIA" : "ACUMULADO",
        "noAfectaSaldo": g.afectaCuadre, // ⬅️ FIX: informativo si afecta cuadre
        "fechaOperacion": fechaStr,
      };
      final rg = await ApiService.registrarAccionConRespuesta(
          "registrarOperacion", gp);
      if (!mounted) return;
      if (rg['status'] == "SUCCESS" || rg['exito'] == true) {
        ok++;
      } else {
        fail++;
      }
    }

    if (!mounted) return;
    setState(() => _procesando = false);

    final idCierre = res['idCierre']?.toString() ?? 'S/N';
    final msj = ok + fail > 0
        ? " · Gastos: $ok ok${fail > 0 ? ", $fail fallaron" : ""}"
        : "";

    _snack("Cierre $idCierre$msj",
        fail > 0 ? Colors.orange.shade800 : Colors.green.shade800);
    Navigator.pop(context, true);
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 10)),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 430,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _filaFechaYMovimientos(),
                    const SizedBox(height: 6),
                    if (_ingresosDeclaradosBs > 0) _avisoDeclarados(),
                    _seccionVentaSistema(),
                    const SizedBox(height: 6),
                    _seccionAgregarPartida(),
                    const SizedBox(height: 6),
                    _seccionPartidas(),
                    const SizedBox(height: 6),
                    _seccionGastos(),
                    const SizedBox(height: 6),
                    if (_mostrarMovimientos && _movimientosDelDia.isNotEmpty)
                      _seccionMovimientos(),
                    if (_mostrarMovimientos && _movimientosDelDia.isNotEmpty)
                      const SizedBox(height: 6),
                    _estadoCuadre(),
                    const SizedBox(height: 6),
                    _observacion(),
                  ],
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.point_of_sale,
                    size: 13, color: Colors.white),
              ),
              const SizedBox(width: 6),
              const Text(
                "CIERRE DE JORNADA",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              InkWell(
                onTap: _autoCargarMovimientos,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child:
                      const Icon(Icons.refresh, size: 12, color: Colors.white),
                ),
              ),
              const SizedBox(width: 5),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filaFechaYMovimientos() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 12, color: Color(0xFF0F52BA)),
          const SizedBox(width: 5),
          InkWell(
            onTap: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: _fechaCierre,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (p != null) {
                setState(() {
                  _fechaCierre = p;
                  _movimientosDelDia = [];
                  _movimientosMarcados.clear();
                });
                _cargarIngresosDeclarados();
                _autoCargarMovimientos();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF0F52BA)),
              ),
              child: Row(
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(_fechaCierre),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F52BA)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 10, color: Color(0xFF0F52BA)),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (_movimientosDelDia.isNotEmpty)
            InkWell(
              onTap: _cargandoMovimientos ? null : _autoCargarMovimientos,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blueGrey.shade300),
                ),
                child: Row(
                  children: [
                    _cargandoMovimientos
                        ? const SizedBox(
                            height: 9,
                            width: 9,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.list_alt,
                            size: 10, color: Colors.blueGrey.shade700),
                    const SizedBox(width: 3),
                    Text(
                      _mostrarMovimientos ? "Ocultar" : "Ver mov.",
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade800),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avisoDeclarados() {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 11, color: Colors.blue.shade800),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              "Ya declarado hoy: ${_fmt.format(_ingresosDeclaradosBs)} Bs ($_ingresosDeclaradosCount)",
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VENTA TOTAL DEL SISTEMA — input en $, referencia en Bs
  // ============================================================
  Widget _seccionVentaSistema() {
    final ventaBs = _ventaSistemaBs();
    return _seccion(
      icono: Icons.attach_money,
      titulo: "VENTA TOTAL DEL SISTEMA (\$)",
      color: Colors.blue.shade700,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _ventaSistemaCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.attach_money,
                      size: 13, color: Color(0xFF0F52BA)),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  suffixText: "\$",
                  suffixStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F52BA)),
                  hintText: "0,00",
                  hintStyle: const TextStyle(fontSize: 11),
                  filled: true,
                  fillColor: Colors.blue.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Container(
              height: 32,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                "≈ ${_fmt.format(ventaBs)} Bs",
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionAgregarPartida() {
    final esBanco = _esBanco(_cuentaSeleccionada);
    return _seccion(
      icono: Icons.add_circle_outline,
      titulo: "AGREGAR PARTIDA",
      color: Colors.teal.shade700,
      child: Column(
        children: [
          SizedBox(
            height: 30,
            child: DropdownButtonFormField<String>(
              initialValue: _cuentaSeleccionada,
              style: const TextStyle(fontSize: 10, color: Colors.black87),
              isDense: true,
              decoration: InputDecoration(
                prefixIcon: Icon(_iconoCuenta(_cuentaSeleccionada),
                    color: _colorCuenta(_cuentaSeleccionada), size: 13),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              ),
              items: _cuentasDisponibles
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(_iconoCuenta(c),
                                size: 11, color: _colorCuenta(c)),
                            const SizedBox(width: 5),
                            Text(c, style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _cuentaSeleccionada = v!),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _montoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: esBanco ? "POS" : "Monto",
                      hintStyle: const TextStyle(fontSize: 10),
                      prefixIcon: const Icon(Icons.calculate_outlined,
                          size: 12, color: Color(0xFF0F52BA)),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              if (esBanco)
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: TextField(
                      controller: _pagoMovilCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "PM",
                        hintStyle: const TextStyle(fontSize: 10),
                        prefixIcon: Icon(Icons.phone_android,
                            size: 12, color: Colors.orange.shade700),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 24, minHeight: 24),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 5),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 3),
              SizedBox(
                height: 30,
                width: 30,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F52BA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(30, 30),
                  ),
                  onPressed: _agregarPartida,
                  child: const Icon(Icons.add, size: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seccionPartidas() {
    return _seccion(
      icono: Icons.list_alt,
      titulo: "PARTIDAS CARGADAS (${_partidas.length})",
      color: Colors.purple.shade700,
      child: _partidas.isEmpty
          ? Container(
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "Sin partidas cargadas",
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic),
              ),
            )
          : Column(
              children: _partidas
                  .asMap()
                  .entries
                  .map((e) => _partidaRow(e.key, e.value))
                  .toList(),
            ),
    );
  }

  Widget _partidaRow(int i, _PartidaData p) {
    final color = _colorCuenta(p.cuenta);
    final pos = _parseInput(p.posCtrl.text);
    final pm = _parseInput(p.pmCtrl.text);
    final com = _comisionP(p);
    final totalBs = _montoEnBs(pos + pm, p.cuenta);
    final esVerde = p.cuenta == "Efectivo USD" || p.cuenta == "USDT";

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_iconoCuenta(p.cuenta), size: 10, color: color),
              const SizedBox(width: 4),
              Text(p.cuenta,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              const Spacer(),
              if (esVerde)
                Text("≈ ${_fmt.format(totalBs)} Bs",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color))
              else
                Text("${_fmt.format(totalBs)} Bs",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color)),
              const SizedBox(width: 3),
              InkWell(
                onTap: () => _quitarPartida(i),
                child: const Padding(
                  padding: EdgeInsets.all(1),
                  child:
                      Icon(Icons.delete_outline, size: 12, color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              SizedBox(
                width: 75,
                height: 26,
                child: TextField(
                  controller: p.posCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: "POS",
                    hintStyle: TextStyle(fontSize: 9),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              // PM solo para bancos. Caja / USD / USDT no tienen pago móvil.
              if (_esBanco(p.cuenta)) ...[
                const SizedBox(width: 3),
                SizedBox(
                  width: 75,
                  height: 26,
                  child: TextField(
                    controller: p.pmCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: "PM",
                      hintStyle: TextStyle(fontSize: 9),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
              if (_esBanco(p.cuenta) && pos > 0) ...[
                const SizedBox(width: 4),
                _buildToggleComision(i, 1),
                const SizedBox(width: 3),
                _buildToggleComision(i, 2),
              ],
              if (com > 0) ...[
                const Spacer(),
                Text("-${_fmt.format(com)}",
                    style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleComision(int i, int num) {
    final p = _partidas[i];
    final activa = num == 1 ? p.comision1Activa : p.comision2Activa;
    final label = num == 1 ? "0.25%" : "0.75%";

    return InkWell(
      onTap: () => _toggleComision(i, num),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: activa ? Colors.orange.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: activa ? Colors.orange.shade500 : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              activa ? Icons.check_box : Icons.check_box_outline_blank,
              size: 9,
              color: activa ? Colors.orange.shade900 : Colors.grey.shade600,
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
                color: activa ? Colors.orange.shade900 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionGastos() {
    final totalAfectan = _totalGastosAfectan();
    final totalRegistrados = _totalGastosRegistrados();

    return _seccion(
      icono: Icons.receipt_long,
      titulo: "GASTOS PAGADOS CON LA VENTA",
      color: Colors.red.shade700,
      child: Column(
        children: [
          ..._gastosVenta.asMap().entries.map((e) => _gastoRow(e.key, e.value)),
          const SizedBox(height: 3),
          InkWell(
            onTap: _agregarGasto,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline,
                      size: 11, color: Colors.red.shade700),
                  const SizedBox(width: 3),
                  Text("Agregar gasto",
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700)),
                ],
              ),
            ),
          ),
          if (_gastosVenta.isNotEmpty) ...[
            const Divider(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total registrado:",
                    style:
                        TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                Text("${_fmt.format(totalRegistrados)} Bs",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700)),
              ],
            ),
            if ((totalAfectan - totalRegistrados).abs() > 0.01) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Afectan cuadre:",
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700)),
                  Text("${_fmt.format(totalAfectan)} Bs",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _gastoRow(int i, _GastoData g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 26,
                  child: TextField(
                    controller: g.descCtrl,
                    style: const TextStyle(fontSize: 9.5),
                    decoration: const InputDecoration(
                      hintText: "Descripción",
                      hintStyle: TextStyle(fontSize: 9.5),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              SizedBox(
                width: 70,
                height: 26,
                child: TextField(
                  controller: g.montoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: "0,00",
                    hintStyle: TextStyle(fontSize: 9.5),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              InkWell(
                onTap: () => _quitarGasto(i),
                child: const Padding(
                  padding: EdgeInsets.all(1),
                  child:
                      Icon(Icons.delete_outline, size: 12, color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 26,
                  child: DropdownButtonFormField<String>(
                    initialValue: g.categoria,
                    isExpanded: true,
                    style:
                        const TextStyle(fontSize: 9.5, color: Colors.black87),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      border: OutlineInputBorder(),
                    ),
                    items: _categoriasGasto
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child:
                                Text(c, style: const TextStyle(fontSize: 9.5))))
                        .toList(),
                    onChanged: (v) => setState(() => g.categoria = v!),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: SizedBox(
                  height: 26,
                  child: DropdownButtonFormField<String>(
                    initialValue: g.cuenta,
                    isExpanded: true,
                    style:
                        const TextStyle(fontSize: 9.5, color: Colors.black87),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      border: OutlineInputBorder(),
                    ),
                    items: _cuentasDisponibles
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child:
                                Text(c, style: const TextStyle(fontSize: 9.5))))
                        .toList(),
                    onChanged: (v) => setState(() => g.cuenta = v!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          InkWell(
            onTap: () => setState(() => g.afectaCuadre = !g.afectaCuadre),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color:
                    g.afectaCuadre ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: g.afectaCuadre
                        ? Colors.red.shade300
                        : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    g.afectaCuadre
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 11,
                    color: g.afectaCuadre
                        ? Colors.red.shade800
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      g.afectaCuadre
                          ? "Afecta el cuadre de la venta"
                          : "No afecta el cuadre",
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: g.afectaCuadre
                              ? Colors.red.shade800
                              : Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionMovimientos() {
    final totalRef = _totalReferencia();

    return _seccion(
      icono: Icons.checklist,
      titulo: "MOVIMIENTOS DEL DÍA · MARCADOS: ${_movimientosMarcados.length}",
      color: Colors.blueGrey.shade700,
      child: Column(
        children: [
          Column(
            children: _movimientosDelDia.map((m) {
              final id = m['idTx'].toString();
              final marcado = _movimientosMarcados.contains(id);
              final monto = (m['montoNeto'] as num?)?.toDouble() ?? 0.0;
              final com = (m['comision'] as num?)?.toDouble() ?? 0.0;
              final total = monto + com;
              final esTraspaso = m['esTraspaso'] == true;
              final tipo = (m['tipo'] ?? '').toString().toUpperCase();
              final esIngreso = tipo.indexOf("INGRESO") == 0;

              return InkWell(
                onTap: () => _toggleMovimiento(id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: marcado ? Colors.blue.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: marcado
                            ? Colors.blue.shade300
                            : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        marcado
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 12,
                        color: marcado
                            ? Colors.blue.shade800
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _limpiarConcepto(m['concepto']?.toString() ?? ''),
                              style: const TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    "VENTA DÍA",
                                    style: TextStyle(
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    "${m['tipo']} · ${m['origen']}",
                                    style: const TextStyle(
                                        fontSize: 7.5, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "${esIngreso ? '+' : '−'}${_fmt.format(total)}",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: esIngreso
                              ? Colors.green.shade700
                              : esTraspaso
                                  ? Colors.orange.shade800
                                  : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_movimientosMarcados.isNotEmpty) ...[
            const Divider(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total marcado:",
                    style:
                        TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                Text("${_fmt.format(totalRef)} Bs",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade800)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _estadoCuadre() {
    final ventaBs = _ventaSistemaBs();
    final distribuido = _totalBruto();
    final comisiones = _totalComisiones();
    final gastos = _totalGastosAfectan();
    final movMarcados = _totalReferencia();
    final diferencia = ventaBs - distribuido - gastos - movMarcados;
    final cuadra = ventaBs > 0 && diferencia.abs() < 0.01;
    final falta = diferencia > 0.01;

    final color = cuadra
        ? Colors.green.shade700
        : (falta ? Colors.red.shade700 : Colors.blue.shade700);
    final fondo = cuadra
        ? Colors.green.shade50
        : (falta ? Colors.red.shade50 : Colors.blue.shade50);
    final icono = cuadra
        ? Icons.check_circle
        : (falta ? Icons.warning_amber_rounded : Icons.info);
    final titulo =
        cuadra ? "CUADRE PERFECTO" : (falta ? "FALTA DISTRIBUIR" : "SOBRANTE");

    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          _filaCuadre("Venta del sistema:", ventaBs),
          _filaCuadre("Distribuido:", distribuido),
          if (comisiones > 0)
            _filaCuadre("Comisiones bancarias:", -comisiones,
                color: Colors.orange.shade800),
          if (gastos > 0)
            _filaCuadre("Gastos de la venta:", -gastos,
                color: Colors.red.shade700),
          if (movMarcados > 0)
            _filaCuadre("Movimientos marcados:", -movMarcados,
                color: Colors.blueGrey.shade700),
          const Divider(height: 8),
          Row(
            children: [
              Icon(icono, color: color, size: 14),
              const SizedBox(width: 5),
              Text(titulo,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.3)),
              const Spacer(),
              Text("${_fmt.format(diferencia.abs())} Bs",
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filaCuadre(String label, double monto, {Color? color}) {
    final c = color ?? Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.bold, color: c)),
          Text("${monto < 0 ? '−' : ''}${_fmt.format(monto.abs())} Bs",
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: c)),
        ],
      ),
    );
  }

  Widget _observacion() {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: _observacionCtrl,
        style: const TextStyle(fontSize: 9.5),
        decoration: InputDecoration(
          hintText: "Observación",
          hintStyle: const TextStyle(fontSize: 9.5),
          prefixIcon: const Icon(Icons.edit_note, size: 13, color: Colors.grey),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 24, minHeight: 24),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        ),
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        height: 32,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F52BA),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: _procesando
              ? const SizedBox(
                  height: 11,
                  width: 11,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check_circle, size: 13),
          label: Text(
            _procesando ? "PROCESANDO..." : "PROCESAR CIERRE",
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          onPressed: _procesando ? null : _procesarCierreFinal,
        ),
      ),
    );
  }

  Widget _seccion({
    required IconData icono,
    required String titulo,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(7),
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
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icono, size: 9, color: color),
              ),
              const SizedBox(width: 4),
              Text(titulo,
                  style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }
}
