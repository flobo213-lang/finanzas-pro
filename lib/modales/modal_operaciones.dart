import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../servicios/api_service.dart';
import '../servicios/cache_service.dart';
import 'modal_pendientes.dart';

class ModalOperaciones extends StatefulWidget {
  final double tasaUSD;
  final double tasaUSDT;

  const ModalOperaciones({
    super.key,
    required this.tasaUSD,
    required this.tasaUSDT,
  });

  @override
  State<ModalOperaciones> createState() => _ModalOperacionesState();
}

class _ModalOperacionesState extends State<ModalOperaciones> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 2);

  String? _vistaActual;

  // INGRESO
  String _categoriaIngreso = "AJUSTE";
  String _origenFondosIngreso = "VENTA_DIA";
  String _cuentaIngresoActual = "Banesco";
  String? _monedaCalcIngreso;
  final TextEditingController _montoIngresoCtrl = TextEditingController();
  final TextEditingController _conceptoIngresoCtrl = TextEditingController();
  final List<Map<String, dynamic>> _desgloseIngreso = [];
  DateTime _fechaIngreso = DateTime.now();

  // EGRESO
  String _categoriaEgreso = "Gasto Operativo / General";
  String _cuentaEgresoActual = "Caja Efectivo Bs";
  String _metodoPagoEgreso = "EFECTIVO";
  String _origenFondosEgreso = "ACUMULADO";
  String? _monedaCalcEgreso;
  final TextEditingController _montoEgresoCtrl = TextEditingController();
  final TextEditingController _conceptoEgresoCtrl = TextEditingController();
  final TextEditingController _cedulaPrestamoEgresoCtrl =
      TextEditingController();
  String _nombrePrestamoEgreso = "";
  bool _buscandoPrestamoEgreso = false;
  final List<Map<String, dynamic>> _desgloseEgreso = [];
  DateTime _fechaEgreso = DateTime.now();

  // --- NUEVAS VARIABLES PARA VINCULAR PENDIENTES ---
  bool _vincularPendiente = false;
  String? _idPendienteSeleccionado;
  List<dynamic> _facturasPendientes = [];
  // -------------------------------------------------

  // Préstamo a trabajador
  final TextEditingController _cedulaPrestamoCtrl = TextEditingController();
  final TextEditingController _nombrePrestamoCtrl = TextEditingController();
  final TextEditingController _montoPrestamoCtrl = TextEditingController();
  bool _buscandoTrabajador = false;
  String _metodoPrestamo = "EFECTIVO";
  final List<Map<String, dynamic>> _metodosPrestamo = [
    {"valor": "EFECTIVO", "label": "Efectivo / Depósito", "pct": 0.0},
    {
      "valor": "TRANS_OTRO_BANCO",
      "label": "Transferencia (0,3%)",
      "pct": 0.003
    },
    {"valor": "PAGO_MOVIL", "label": "Pago Móvil (0,3%)", "pct": 0.003},
  ];

  // TRASPASO
  String _cuentaOrigenTraspaso = "Bancamiga";
  String _cuentaDestinoTraspaso = "Banesco";
  String _tipoTraspaso = "OTRO_BANCO";
  String _origenFondosTraspaso = "ACUMULADO";
  String? _monedaCalcTraspaso;
  final TextEditingController _montoTraspasoCtrl = TextEditingController();
  final TextEditingController _conceptoTraspasoCtrl =
      TextEditingController(text: "Traspaso entre cuentas");
  DateTime _fechaTraspaso = DateTime.now();

  // DIVISA
  String _cuentaOrigenCompra = "Bancamiga";
  String _cuentaDestinoCompra = "USDT";
  String _monedaDestinoCompra = "USDT";
  final TextEditingController _montoCompraCtrl = TextEditingController();
  late TextEditingController _tasaBCVCtrl;
  late TextEditingController _tasaUSDTCTRL;
  DateTime _fechaCompra = DateTime.now();

  Map<String, dynamic> _saldos = {};
  bool _cargandoSaldos = true;
  bool _procesando = false;

  final List<String> _cuentasBancos = [
    "Caja Efectivo Bs",
    "Efectivo USD",
    "BBVA",
    "Bancamiga",
    "BNC",
    "BDV",
    "Banesco",
    "USDT"
  ];

  final List<String> _categoriasEgreso = [
    "Gasto Operativo / General",
    "Pago a Proveedores",
    "Mantenimiento y Repuestos",
    "Servicios Básicos",
    "PERSONAL",
    "Otros Egresos",
    "PRESTAMO_TRABAJADOR",
  ];

  final List<String> _categoriasIngreso = [
    "AJUSTE",
    "INTERESES",
    "PRESTAMO_RECIBIDO",
    "DEVOLUCION",
    "OTRO_INGRESO",
  ];

  final List<Map<String, dynamic>> _metodosPagoEgreso = [
    {"valor": "EFECTIVO", "label": "Efectivo / Depósito", "pct": 0.0},
    {
      "valor": "TRANS_MISMO_BANCO",
      "label": "Transferencia mismo banco",
      "pct": 0.0
    },
    {
      "valor": "TRANS_OTRO_BANCO",
      "label": "Transferencia otro banco (0,3%)",
      "pct": 0.003
    },
    {"valor": "PAGO_MOVIL", "label": "Pago Móvil (0,3%)", "pct": 0.003},
  ];

  @override
  void initState() {
    super.initState();
    _tasaBCVCtrl =
        TextEditingController(text: widget.tasaUSD.toStringAsFixed(2));
    _tasaUSDTCTRL =
        TextEditingController(text: widget.tasaUSDT.toStringAsFixed(2));
    _cargarSaldosInicial();
  }

  Future<void> _cargarSaldosInicial() async {
    final cache = await CacheService.leerSaldos();
    if (cache != null && mounted) {
      setState(() {
        _saldos = cache;
        _cargandoSaldos = false;
      });
    }
    _cargarSaldosEnVivo();
  }

  Future<void> _cargarSaldosEnVivo() async {
    final res = await ApiService.obtenerSaldos();
    if (mounted) {
      setState(() {
        _saldos = res;
        _cargandoSaldos = false;
      });
    }
  }

  // --- NUEVA FUNCION PARA CARGAR FACTURAS ---
  Future<void> _cargarFacturasPendientes() async {
    try {
      final res = await ApiService.obtenerPendientesPorPagar();
      if (!mounted) return;
      setState(() {
        _facturasPendientes = List.from(res['pendientes'] ?? []);
      });
    } catch (_) {}
  }
  // ------------------------------------------

  @override
  void dispose() {
    _montoEgresoCtrl.dispose();
    _conceptoEgresoCtrl.dispose();
    _montoIngresoCtrl.dispose();
    _conceptoIngresoCtrl.dispose();
    _montoTraspasoCtrl.dispose();
    _conceptoTraspasoCtrl.dispose();
    _montoCompraCtrl.dispose();
    _tasaBCVCtrl.dispose();
    _tasaUSDTCTRL.dispose();
    _cedulaPrestamoCtrl.dispose();
    _nombrePrestamoCtrl.dispose();
    _montoPrestamoCtrl.dispose();
    super.dispose();
  }

  String _fechaAString(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$y-$m-$dd";
  }

  Widget _buildFechaSelector({
    required DateTime fecha,
    required void Function(DateTime) onCambio,
    required Color color,
  }) {
    final hoy = DateTime.now();
    final esHoy = fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: esHoy ? Colors.grey.shade100 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: esHoy ? Colors.grey.shade300 : Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today,
              size: 12,
              color: esHoy ? Colors.grey.shade700 : Colors.orange.shade900),
          const SizedBox(width: 6),
          Text(
            esHoy
                ? "Fecha: Hoy (${_fechaAString(fecha)})"
                : "⚠ Fecha retroactiva: ${_fechaAString(fecha)}",
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: esHoy ? Colors.black87 : Colors.orange.shade900,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () async {
              final sel = await showDatePicker(
                context: context,
                initialDate: fecha,
                firstDate: DateTime(2024),
                lastDate: hoy,
              );
              if (sel != null) onCambio(sel);
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 11, color: color),
                  const SizedBox(width: 3),
                  Text("Cambiar",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monedaParaCuenta(String cuenta) {
    if (cuenta == "USDT") return "USDT";
    if (cuenta == "Efectivo USD") return "USD";
    return "BS";
  }

  double _aBs(double monto, String moneda) {
    if (moneda == "USD") return monto * widget.tasaUSD;
    if (moneda == "USDT") return monto * widget.tasaUSDT;
    return monto;
  }

  double _deBs(double montoBs, String moneda) {
    if (moneda == "USD") return montoBs / widget.tasaUSD;
    if (moneda == "USDT") return montoBs / widget.tasaUSDT;
    return montoBs;
  }

  double _convertir(double monto, String origen, String destino) {
    if (origen == destino) return monto;
    return _deBs(_aBs(monto, origen), destino);
  }

  String _monedaCalcEgresoEfectiva() =>
      _monedaCalcEgreso ?? _monedaParaCuenta(_cuentaEgresoActual);

  String _monedaCalcIngresoEfectiva() =>
      _monedaCalcIngreso ?? _monedaParaCuenta(_cuentaIngresoActual);

  String _monedaCalcTraspasoEfectiva() =>
      _monedaCalcTraspaso ?? _monedaParaCuenta(_cuentaOrigenTraspaso);

  Future<void> _elegirMonedaCalc({required bool esEgreso}) async {
    final actual =
        esEgreso ? _monedaCalcEgresoEfectiva() : _monedaCalcTraspasoEfectiva();
    final nativa = esEgreso
        ? _monedaParaCuenta(_cuentaEgresoActual)
        : _monedaParaCuenta(_cuentaOrigenTraspaso);

    final sel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text("Moneda del monto",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  "Elige en qué moneda escribes el monto.\nEl débito se hace siempre en la moneda de la cuenta.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
            ),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: ["BS", "USD", "USDT"].map((m) {
                final label = m == "BS" ? "Bolívares" : m;
                final isNativa = nativa == m;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      if (isNativa) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.star, size: 12, color: Colors.orange),
                      ]
                    ],
                  ),
                  selected: actual == m,
                  selectedColor: const Color(0xFF0F52BA).withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) Navigator.pop(ctx, m);
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          if (actual != nativa)
            TextButton(
              onPressed: () => Navigator.pop(ctx, "RESET"),
              child: const Text("Volver a nativa"),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
        ],
      ),
    );

    if (sel == null) return;
    setState(() {
      if (esEgreso) {
        _monedaCalcEgreso = (sel == "RESET") ? null : sel;
      } else {
        _monedaCalcTraspaso = (sel == "RESET") ? null : sel;
      }
    });
  }

  Future<void> _elegirMonedaCalcIngreso() async {
    final actual = _monedaCalcIngresoEfectiva();
    final nativa = _monedaParaCuenta(_cuentaIngresoActual);

    final sel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text("Moneda del monto",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  "Elige en qué moneda escribes el monto.\nEl abono se hace siempre en la moneda de la cuenta.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
            ),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: ["BS", "USD", "USDT"].map((m) {
                final label = m == "BS" ? "Bolívares" : m;
                final isNativa = nativa == m;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      if (isNativa) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.star, size: 12, color: Colors.orange),
                      ]
                    ],
                  ),
                  selected: actual == m,
                  selectedColor: const Color(0xFF0F52BA).withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) Navigator.pop(ctx, m);
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          if (actual != nativa)
            TextButton(
              onPressed: () => Navigator.pop(ctx, "RESET"),
              child: const Text("Volver a nativa"),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
        ],
      ),
    );

    if (sel == null) return;
    setState(() {
      _monedaCalcIngreso = (sel == "RESET") ? null : sel;
    });
  }

  double _obtenerSaldoDisponible(String cuenta) {
    final item = _saldos[cuenta];
    if (item is num) return item.toDouble();
    if (item is String) {
      final parsed =
          double.tryParse(item.replaceAll('.', '').replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
    if (item is Map && item.containsKey('monto')) {
      return (item['monto'] as num?)?.toDouble() ?? 0.0;
    }
    final mapa = _saldos['saldosMap'];
    if (mapa is Map && mapa.containsKey(cuenta)) {
      final v = mapa[cuenta];
      if (v is num) return v.toDouble();
      if (v is String) {
        return double.tryParse(v.replaceAll('.', '').replaceAll(',', '.')) ??
            0.0;
      }
    }
    final arr = _saldos['saldos'];
    if (arr is List) {
      for (var s in arr) {
        if (s is Map && s['cuenta'] == cuenta) {
          return (s['monto'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }
    return 0.0;
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
    } else if (dots == 1 && commas == 0) {
      int dotPos = clean.indexOf('.');
      int digitsAfter = clean.length - dotPos - 1;
      if (digitsAfter == 3 && dotPos > 0 && clean.length > 4) {
        clean = clean.replaceAll('.', '');
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

  // ============================================================
  // PRÉSTAMO A TRABAJADOR
  // ============================================================
  Future<void> _buscarTrabajadorPrestamo() async {
    final ced = _cedulaPrestamoCtrl.text.trim();
    if (ced.isEmpty) return;
    setState(() => _buscandoTrabajador = true);
    try {
      final res = await ApiService.buscarTrabajadorCompleto(ced);
      if (!mounted) return;
      setState(() {
        _buscandoTrabajador = false;
        if (res['encontrado'] == true) {
          _nombrePrestamoCtrl.text = res['nombre'] ?? '';
        } else {
          _nombrePrestamoCtrl.text = '';
          _mostrarMensaje("Trabajador no encontrado", Colors.red.shade800);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _buscandoTrabajador = false);
    }
  }

  Future<void> _procesarPrestamoTrabajador() async {
    final ced = _cedulaPrestamoCtrl.text.trim();
    final nom = _nombrePrestamoCtrl.text.trim();
    final monto = _parseInput(_montoPrestamoCtrl.text);
    final cuenta = _cuentaEgresoActual;
    final tasa = widget.tasaUSD;

    if (ced.isEmpty) {
      _mostrarMensaje("Falta la cédula", Colors.red.shade800);
      return;
    }
    if (nom.isEmpty) {
      _mostrarMensaje("Busca el trabajador primero", Colors.red.shade800);
      return;
    }
    if (monto <= 0) {
      _mostrarMensaje("Monto inválido", Colors.red.shade800);
      return;
    }
    if (tasa <= 0) {
      _mostrarMensaje("Tasa BCV inválida", Colors.red.shade800);
      return;
    }

    final montoUSD = monto / tasa;
    final pctCom = _metodosPrestamo.firstWhere(
        (m) => m['valor'] == _metodoPrestamo,
        orElse: () => {"pct": 0.0})['pct'] as double;
    final comisionBs = monto * pctCom;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text("Confirmar préstamo",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Trabajador: $nom", style: const TextStyle(fontSize: 11)),
            Text("Monto: ${_fmt.format(monto)} Bs",
                style: const TextStyle(fontSize: 11)),
            Text("Equivalente: \$${montoUSD.toStringAsFixed(2)} USD",
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            if (comisionBs > 0)
              Text(
                  "Comisión: ${_fmt.format(comisionBs)} Bs (${_metodoPrestamo.replaceAll('_', ' ')})",
                  style: const TextStyle(fontSize: 11, color: Colors.orange)),
            const SizedBox(height: 6),
            const Text("Se restará de la cuenta y se sumará a su deuda.",
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
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
            child: const Text("Registrar"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesando = true);

    final fechaStr = _fechaAString(_fechaEgreso);
    final payload = {
      "cedula": ced,
      "nombre": nom,
      "montoBs": monto,
      "cuentaOrigen": cuenta,
      "tasaUSD": tasa,
      "comisionBs": comisionBs,
      "metodoPago": _metodoPrestamo,
      "fechaOperacion": fechaStr,
      "concepto": "Préstamo a trabajador",
    };

    final res = await ApiService.registrarAccionConRespuesta(
        "registrarPrestamoTrabajador", payload);

    if (!mounted) return;
    setState(() => _procesando = false);

    if (res['status'] == "SUCCESS" || res['exito'] == true) {
      await _cargarSaldosEnVivo();
      _mostrarMensaje(
        "Préstamo registrado. Deuda nueva: \$${(res['deudaNueva'] as num?)?.toStringAsFixed(2) ?? '?'}",
        Colors.green.shade800,
      );
      setState(() {
        _cedulaPrestamoCtrl.clear();
        _nombrePrestamoCtrl.clear();
        _montoPrestamoCtrl.clear();
        _metodoPrestamo = "EFECTIVO";
        _fechaEgreso = DateTime.now();
      });
    } else {
      _mostrarMensaje(
          res['mensaje']?.toString() ?? "Error", Colors.red.shade800);
    }
  }

  Widget _buildVistaPrestamoTrabajador() {
    final monto = _parseInput(_montoPrestamoCtrl.text);
    final equivalenteUSD = monto > 0 ? monto / widget.tasaUSD : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFechaSelector(
          fecha: _fechaEgreso,
          onCambio: (d) => setState(() => _fechaEgreso = d),
          color: Colors.red.shade700,
        ),
        const SizedBox(height: 6),
        _buildSeccion(
          icono: Icons.account_balance_wallet,
          titulo: "PRÉSTAMO A TRABAJADOR",
          color: Colors.red.shade700,
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _cedulaPrestamoCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _buscarTrabajadorPrestamo(),
                  decoration: InputDecoration(
                    hintText: "Cédula del trabajador",
                    hintStyle: const TextStyle(fontSize: 11),
                    suffixIcon: _buscandoTrabajador
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search, size: 16),
                            onPressed: _buscarTrabajadorPrestamo,
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _nombrePrestamoCtrl,
                  readOnly: true,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: "Nombre (auto)",
                    hintStyle: TextStyle(fontSize: 11),
                    border: OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Color(0xFFF5F7FA),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: DropdownButtonFormField<String>(
                  initialValue: _cuentaEgresoActual,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  decoration: _inputDec(hint: "Cuenta Origen"),
                  items: _cuentasBancos
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 11))))
                      .toList(),
                  onChanged: (v) => setState(() => _cuentaEgresoActual = v!),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _montoPrestamoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Monto en Bs",
                    hintStyle: const TextStyle(fontSize: 11),
                    suffixText: "Bs",
                    suffixStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F52BA)),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: DropdownButtonFormField<String>(
                  initialValue: _metodoPrestamo,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  decoration: _inputDec(hint: "Método"),
                  items: _metodosPrestamo
                      .map((m) => DropdownMenuItem(
                            value: m['valor'].toString(),
                            child: Text(m['label'].toString(),
                                style: const TextStyle(fontSize: 11)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _metodoPrestamo = v!),
                ),
              ),
              if (equivalenteUSD > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: Colors.blue.shade800),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Se sumará \$${equivalenteUSD.toStringAsFixed(2)} USD a su deuda",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                      if (monto *
                              (_metodosPrestamo.firstWhere(
                                      (m) => m['valor'] == _metodoPrestamo,
                                      orElse: () => {"pct": 0.0})['pct']
                                  as double) >
                          0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "Se debitará ${_fmt.format(monto + monto * (_metodosPrestamo.firstWhere((m) => m['valor'] == _metodoPrestamo, orElse: () => {
                                  "pct": 0.0
                                })['pct'] as double))} Bs (incluye comisión)",
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 36,
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
                      : const Icon(Icons.check_circle, size: 16),
                  label: const Text("REGISTRAR PRÉSTAMO",
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: _procesando ? null : _procesarPrestamoTrabajador,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EGRESO
  // ============================================================
  void _agregarPartidaEgreso() {
    final montoEscrito = _parseInput(_montoEgresoCtrl.text);
    if (montoEscrito <= 0) return;

    final monedaCalc = _monedaCalcEgresoEfectiva();
    final monedaCuenta = _monedaParaCuenta(_cuentaEgresoActual);

    final montoNativo = _convertir(montoEscrito, monedaCalc, monedaCuenta);
    final montoBs = _aBs(montoEscrito, monedaCalc);

    setState(() {
      _desgloseEgreso.add({
        "cuenta": _cuentaEgresoActual,
        "monto": montoNativo,
        "moneda": monedaCuenta,
        "montoBs": montoBs,
        "montoEscrito": montoEscrito,
        "monedaEscrita": monedaCalc,
      });
      _montoEgresoCtrl.clear();
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _quitarPartidaEgreso(int index) {
    setState(() => _desgloseEgreso.removeAt(index));
  }

  double _totalBsEgreso() {
    double total = 0;
    for (var it in _desgloseEgreso) {
      total += (it['montoBs'] as num).toDouble();
    }
    return total;
  }

  double _pctComisionEgreso() {
    for (var m in _metodosPagoEgreso) {
      if (m['valor'] == _metodoPagoEgreso) {
        return (m['pct'] as num).toDouble();
      }
    }
    return 0.0;
  }

  double _comisionEgresoBs() {
    return _totalBsEgreso() * _pctComisionEgreso();
  }

  String _labelMetodoEgreso() {
    for (var m in _metodosPagoEgreso) {
      if (m['valor'] == _metodoPagoEgreso) return m['label'].toString();
    }
    return "Efectivo / Depósito";
  }

  Future<void> _buscarTrabajadorEgreso() async {
    final ced = _cedulaPrestamoEgresoCtrl.text.trim();
    if (ced.isEmpty) return;
    setState(() => _buscandoPrestamoEgreso = true);
    try {
      final res = await ApiService.buscarTrabajadorCompleto(ced);
      if (!mounted) return;
      setState(() {
        _buscandoPrestamoEgreso = false;
        if (res['encontrado'] == true) {
          _nombrePrestamoEgreso = res['nombre'] ?? '';
        } else {
          _nombrePrestamoEgreso = '';
          _mostrarMensaje("Trabajador no encontrado", Colors.red.shade800);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _buscandoPrestamoEgreso = false);
    }
  }

  Future<void> _procesarEgreso() async {
    final totalBs = _totalBsEgreso();
    if (totalBs <= 0) {
      _mostrarMensaje(
          "Debes agregar al menos una partida", Colors.red.shade800);
      return;
    }
    if (_conceptoEgresoCtrl.text.trim().isEmpty) {
      _mostrarMensaje("Falta el concepto / descripción", Colors.red.shade800);
      return;
    }

    final comisionBs = _comisionEgresoBs();
    double comisionEnPrimeraCuenta = 0;
    String primeraCuenta = "";
    if (comisionBs > 0 && _desgloseEgreso.isNotEmpty) {
      primeraCuenta = _desgloseEgreso.first['cuenta'].toString();
      final monedaPrimera = _monedaParaCuenta(primeraCuenta);
      comisionEnPrimeraCuenta = _deBs(comisionBs, monedaPrimera);
    }

    for (var it in _desgloseEgreso) {
      final c = it['cuenta'].toString();
      final montoNat = (it['monto'] as num).toDouble();
      final monedaNat = it['moneda'].toString();
      final disp = _obtenerSaldoDisponible(c);
      double requerido = montoNat;
      if (c == primeraCuenta) requerido += comisionEnPrimeraCuenta;
      if (disp < requerido) {
        _mostrarMensaje(
            "Fondos insuficientes en $c. Disponible: ${_fmt.format(disp)} $monedaNat · Requerido: ${_fmt.format(requerido)} $monedaNat",
            Colors.red.shade800);
        return;
      }
    }

    List<Map<String, dynamic>> desglose = [];
    for (var it in _desgloseEgreso) {
      desglose.add({
        "cuenta": it['cuenta'],
        "monto": it['monto'],
        "moneda": it['moneda'],
        "montoBs": it['montoBs'],
      });
    }

    setState(() => _procesando = true);

    final payload = {
      "tipoOperacion": "EGRESO",
      "categoria": _categoriaEgreso,
      "concepto": (_categoriaEgreso == "PRESTAMO_TRABAJADOR" &&
              _nombrePrestamoEgreso.isNotEmpty)
          ? "${_conceptoEgresoCtrl.text.trim()} · $_nombrePrestamoEgreso (V-${_cedulaPrestamoEgresoCtrl.text.trim()})"
          : _conceptoEgresoCtrl.text.trim(),
      "montoBsPagado": totalBs,
      if (_categoriaEgreso == "PRESTAMO_TRABAJADOR" &&
          _cedulaPrestamoEgresoCtrl.text.trim().isNotEmpty)
        "cedula": _cedulaPrestamoEgresoCtrl.text.trim(),
      if (_vincularPendiente && _idPendienteSeleccionado != null)
        "idPendiente": _idPendienteSeleccionado, // <--- VINCULACION PENDIENTE
      "cuentaSalida": desglose.isNotEmpty ? desglose[0]['cuenta'] : "VARIAS",
      "moneda": "BS",
      "tasaUSD": widget.tasaUSD,
      "tasaUSDT": widget.tasaUSDT,
      "cuentasDesglose": desglose,
      "comisionBs": comisionBs,
      "metodoPago": _metodoPagoEgreso,
      "fechaOperacion": _fechaAString(_fechaEgreso),
    };

    final res = await ApiService.registrarAccionConRespuesta(
        "registrarOperacion", payload);
    print("RESPUESTA: " + res.toString());

    if (!mounted) return;
    setState(() => _procesando = false);

    if (res['status'] == "SUCCESS" || res['exito'] == true) {
      final datos = {
        "tipo": "EGRESO",
        "idTx": res['idTx']?.toString() ?? '',
        "categoria": _categoriaEgreso,
        "concepto": (_categoriaEgreso == "PRESTAMO_TRABAJADOR" &&
                _nombrePrestamoEgreso.isNotEmpty)
            ? "${_conceptoEgresoCtrl.text.trim()} · $_nombrePrestamoEgreso (V-${_cedulaPrestamoEgresoCtrl.text.trim()})"
            : _conceptoEgresoCtrl.text.trim(),
        "montoTotal": totalBs,
        "comision": comisionBs,
        "metodoPago": _labelMetodoEgreso(),
        "fechaOperacion": _fechaAString(_fechaEgreso),
        "desglose": _desgloseEgreso
            .map((e) => {
                  "cuenta": e['cuenta'],
                  "monto": e['monto'],
                  "moneda": e['moneda'],
                  "montoBs": e['montoBs'],
                })
            .toList(),
        "fecha": DateTime.now().toString().substring(0, 19),
      };

      _mostrarMensaje("Egreso registrado correctamente", Colors.green.shade800);
      await _cargarSaldosEnVivo();
      setState(() {
        _desgloseEgreso.clear();
        _conceptoEgresoCtrl.clear();
        _montoEgresoCtrl.clear();
        _fechaEgreso = DateTime.now();
        _cedulaPrestamoEgresoCtrl.clear();
        _nombrePrestamoEgreso = "";

        // Limpiar selección de pendientes
        _vincularPendiente = false;
        _idPendienteSeleccionado = null;
        _facturasPendientes.clear();
      });
      if (!mounted) return;
      _mostrarComprobanteEgreso(context, datos);
    } else {
      _mostrarMensaje(
          res['mensaje'] ?? "Error al registrar egreso", Colors.red.shade800);
    }
  }

  // ============================================================
  // INGRESO
  // ============================================================
  void _agregarPartidaIngreso() {
    final montoEscrito = _parseInput(_montoIngresoCtrl.text);
    if (montoEscrito <= 0) return;

    final monedaCalc = _monedaCalcIngresoEfectiva();
    final monedaCuenta = _monedaParaCuenta(_cuentaIngresoActual);

    final montoNativo = _convertir(montoEscrito, monedaCalc, monedaCuenta);
    final montoBs = _aBs(montoEscrito, monedaCalc);

    setState(() {
      _desgloseIngreso.add({
        "cuenta": _cuentaIngresoActual,
        "monto": montoNativo,
        "moneda": monedaCuenta,
        "montoBs": montoBs,
        "montoEscrito": montoEscrito,
        "monedaEscrita": monedaCalc,
      });
      _montoIngresoCtrl.clear();
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _quitarPartidaIngreso(int index) {
    setState(() => _desgloseIngreso.removeAt(index));
  }

  double _totalBsIngreso() {
    double total = 0;
    for (var it in _desgloseIngreso) {
      total += (it['montoBs'] as num).toDouble();
    }
    return total;
  }

  Future<void> _procesarIngreso() async {
    final totalBs = _totalBsIngreso();
    if (totalBs <= 0) {
      _mostrarMensaje(
          "Debes agregar al menos una partida", Colors.red.shade800);
      return;
    }
    if (_conceptoIngresoCtrl.text.trim().isEmpty) {
      _mostrarMensaje("Falta el concepto / descripción", Colors.red.shade800);
      return;
    }

    List<Map<String, dynamic>> desglose = [];
    for (var it in _desgloseIngreso) {
      desglose.add({
        "cuenta": it['cuenta'],
        "monto": it['monto'],
        "moneda": it['moneda'],
        "montoBs": it['montoBs'],
      });
    }

    setState(() => _procesando = true);

    final payload = {
      "tipoOperacion": "INGRESO",
      "categoria": _categoriaIngreso,
      "concepto": _conceptoIngresoCtrl.text.trim(),
      "montoBs": totalBs,
      "cuentaDestino": desglose.isNotEmpty ? desglose[0]['cuenta'] : "VARIAS",
      "moneda": "BS",
      "tasaUSD": widget.tasaUSD,
      "tasaUSDT": widget.tasaUSDT,
      "cuentasDesglose": desglose,
      "origenFondos": _origenFondosIngreso,
      "fechaOperacion": _fechaAString(_fechaIngreso),
    };

    final res = await ApiService.registrarAccionConRespuesta(
        "registrarIngreso", payload);

    if (!mounted) return;
    setState(() => _procesando = false);

    if (res['status'] == "SUCCESS" || res['exito'] == true) {
      final datos = {
        "tipo": "INGRESO",
        "idTx": res['idTx']?.toString() ?? '',
        "categoria": _categoriaIngreso,
        "concepto": _conceptoIngresoCtrl.text.trim(),
        "montoTotal": totalBs,
        "fechaOperacion": _fechaAString(_fechaIngreso),
        "desglose": _desgloseIngreso
            .map((e) => {
                  "cuenta": e['cuenta'],
                  "monto": e['monto'],
                  "moneda": e['moneda'],
                  "montoBs": e['montoBs'],
                })
            .toList(),
        "fecha": DateTime.now().toString().substring(0, 19),
      };

      _mostrarMensaje(
          "Ingreso registrado correctamente", Colors.green.shade800);
      await _cargarSaldosEnVivo();
      setState(() {
        _desgloseIngreso.clear();
        _conceptoIngresoCtrl.clear();
        _montoIngresoCtrl.clear();
        _fechaIngreso = DateTime.now();
      });
      if (!mounted) return;
      _mostrarComprobanteIngreso(context, datos);
    } else {
      _mostrarMensaje(
          res['mensaje'] ?? "Error al registrar ingreso", Colors.red.shade800);
    }
  }

  // ============================================================
  // TRASPASO
  // ============================================================
  double _comisionTraspaso(double montoEnOrigen) {
    if (_tipoTraspaso != "OTRO_BANCO") return 0;
    return montoEnOrigen * 0.003;
  }

  Future<void> _procesarTraspaso() async {
    final montoEscrito = _parseInput(_montoTraspasoCtrl.text);
    if (_cargandoSaldos || _saldos.isEmpty) {
      _mostrarMensaje(
          "Cargando saldos, espera un momento...", Colors.orange.shade800);
      return;
    }
    if (montoEscrito <= 0) {
      _mostrarMensaje("Ingresa un monto válido", Colors.red.shade800);
      return;
    }
    if (_cuentaOrigenTraspaso == _cuentaDestinoTraspaso) {
      _mostrarMensaje(
          "Cuenta origen y destino deben ser distintas", Colors.red.shade800);
      return;
    }

    final monedaCalc = _monedaCalcTraspasoEfectiva();
    final monedaOrigen = _monedaParaCuenta(_cuentaOrigenTraspaso);
    final monedaDestino = _monedaParaCuenta(_cuentaDestinoTraspaso);

    final montoEnOrigen = _convertir(montoEscrito, monedaCalc, monedaOrigen);
    final montoEnDestino = _convertir(montoEscrito, monedaCalc, monedaDestino);
    final montoBs = _aBs(montoEscrito, monedaCalc);

    final comision = _comisionTraspaso(montoEnOrigen);
    final totalDebitar = montoEnOrigen + comision;

    final dispOrigen = _obtenerSaldoDisponible(_cuentaOrigenTraspaso);
    if (dispOrigen < totalDebitar) {
      _mostrarMensaje(
          "Fondos insuficientes en $_cuentaOrigenTraspaso. Disponible: ${_fmt.format(dispOrigen)} $monedaOrigen",
          Colors.red.shade800);
      return;
    }

    setState(() => _procesando = true);

    final payload = {
      "cuentaOrigen": _cuentaOrigenTraspaso,
      "cuentaDestino": _cuentaDestinoTraspaso,
      "monto": montoEnOrigen,
      "montoDestino": montoEnDestino,
      "montoBs": montoBs,
      "monedaOrigen": monedaOrigen,
      "monedaDestino": monedaDestino,
      "tipoTraspaso": _tipoTraspaso,
      "origenFondos": _origenFondosTraspaso,
      "concepto": _conceptoTraspasoCtrl.text.trim(),
      "tasaUSD": widget.tasaUSD,
      "tasaUSDT": widget.tasaUSDT,
      "fechaOperacion": _fechaAString(_fechaTraspaso),
    };

    final res = await ApiService.registrarAccionConRespuesta(
        "registrarTraspaso", payload);

    if (!mounted) return;
    setState(() => _procesando = false);

    if (res['status'] == "SUCCESS" || res['exito'] == true) {
      final datos = {
        "tipo": "TRASPASO",
        "idTx": res['idTx']?.toString() ?? '',
        "tipoTraspaso": _tipoTraspaso,
        "cuentaOrigen": _cuentaOrigenTraspaso,
        "cuentaDestino": _cuentaDestinoTraspaso,
        "monedaOrigen": monedaOrigen,
        "monedaDestino": monedaDestino,
        "montoEnOrigen": montoEnOrigen,
        "montoEnDestino": montoEnDestino,
        "comision": comision,
        "totalDebitar": totalDebitar,
        "concepto": _conceptoTraspasoCtrl.text.trim(),
        "fechaOperacion": _fechaAString(_fechaTraspaso),
        "fecha": DateTime.now().toString().substring(0, 19),
      };

      _mostrarMensaje(
          "Traspaso registrado correctamente", Colors.green.shade800);
      await _cargarSaldosEnVivo();
      setState(() {
        _montoTraspasoCtrl.clear();
        _conceptoTraspasoCtrl.text = "Traspaso entre cuentas";
        _fechaTraspaso = DateTime.now();
      });
      if (!mounted) return;
      _mostrarComprobanteTraspaso(context, datos);
    } else {
      _mostrarMensaje(
          res['mensaje'] ?? "Error al registrar traspaso", Colors.red.shade800);
    }
  }

  // ============================================================
  // COMPRA DIVISA (SIMPLIFICADA)
  // ============================================================
  Future<void> _procesarCompraDivisa() async {
    final monto = _parseInput(_montoCompraCtrl.text);
    if (monto <= 0) {
      _mostrarMensaje("Ingresa un monto válido", Colors.red.shade800);
      return;
    }

    final tasa = _monedaDestinoCompra == "USD"
        ? _parseInput(_tasaBCVCtrl.text)
        : _parseInput(_tasaUSDTCTRL.text);

    if (tasa <= 0) {
      _mostrarMensaje("La tasa debe ser mayor a 0", Colors.red.shade800);
      return;
    }

    final totalDebitar = monto * tasa;
    final dispOrigen = _obtenerSaldoDisponible(_cuentaOrigenCompra);
    if (dispOrigen < totalDebitar) {
      _mostrarMensaje(
          "Fondos insuficientes en $_cuentaOrigenCompra. Disponible: ${_fmt.format(dispOrigen)} Bs",
          Colors.red.shade800);
      return;
    }

    final tasaBase =
        _monedaDestinoCompra == "USD" ? widget.tasaUSD : widget.tasaUSDT;
    final esManual = (tasa - tasaBase).abs() > 0.01;

    setState(() => _procesando = true);

    final payload = {
      "cuentaOrigen": _cuentaOrigenCompra,
      "cuentaDestino": _cuentaDestinoCompra,
      "montoDivisa": monto,
      "montoBs": totalDebitar,
      "tasaUsada": tasa,
      "monedaDestino": _monedaDestinoCompra,
      "concepto": "Compra de $_monedaDestinoCompra",
      "tasaManual": esManual,
      "tasaBCVUsada": widget.tasaUSD,
      "tasaUSDTUsada": widget.tasaUSDT,
      "fechaOperacion": _fechaAString(_fechaCompra),
    };

    final res = await ApiService.registrarAccionConRespuesta(
        "registrarCompraDivisa", payload);

    if (!mounted) return;
    setState(() => _procesando = false);

    if (res['status'] == "SUCCESS" || res['exito'] == true) {
      final datos = {
        "tipo": "COMPRA_DIVISA",
        "idTx": res['idTx']?.toString() ?? '',
        "cuentaOrigen": _cuentaOrigenCompra,
        "cuentaDestino": _cuentaDestinoCompra,
        "monedaDestino": _monedaDestinoCompra,
        "montoDivisa": monto,
        "montoBs": totalDebitar,
        "tasa": tasa,
        "tasaManual": esManual,
        "fechaOperacion": _fechaAString(_fechaCompra),
        "fecha": DateTime.now().toString().substring(0, 19),
      };

      _mostrarMensaje("Compra de divisa registrada", Colors.green.shade800);
      await _cargarSaldosEnVivo();
      setState(() {
        _montoCompraCtrl.clear();
        _fechaCompra = DateTime.now();
      });
      if (!mounted) return;
      _mostrarComprobanteDivisa(context, datos);
    } else {
      _mostrarMensaje(
          res['mensaje'] ?? "Error al registrar compra", Colors.red.shade800);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                      if (_vistaActual != null)
                        InkWell(
                          onTap: () => setState(() => _vistaActual = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.arrow_back,
                                size: 14, color: Colors.white),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(5),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(Icons.swap_horiz,
                              size: 15, color: Colors.white),
                        ),
                      Text(
                        _vistaActual == null
                            ? "OPERACIONES"
                            : _vistaActual == "EGRESO"
                                ? "EGRESO / PAGO"
                                : _vistaActual == "INGRESO"
                                    ? "INGRESO / COBRO"
                                    : _vistaActual == "TRASPASO"
                                        ? "TRASPASO"
                                        : "COMPRA DIVISA",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
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
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: _vistaActual == null
                    ? _buildVistaTarjetas()
                    : _vistaActual == "EGRESO"
                        ? _buildVistaEgreso()
                        : _vistaActual == "INGRESO"
                            ? _buildVistaIngreso()
                            : _vistaActual == "TRASPASO"
                                ? _buildVistaTraspaso()
                                : _buildVistaCompraDivisa(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaTarjetas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text("¿Qué deseas hacer?",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
        ),
        _buildTarjeta(
          icono: Icons.upload,
          titulo: "EGRESO / PAGO",
          subtitulo: "Pagar a proveedor, gastos operativos",
          colorFondo: Colors.red.shade50,
          colorBorde: Colors.red.shade300,
          colorIcono: Colors.red.shade700,
          onTap: () => setState(() => _vistaActual = "EGRESO"),
        ),
        _buildTarjeta(
          icono: Icons.download,
          titulo: "INGRESO / COBRO",
          subtitulo: "Cobros, ventas, pagos recibidos",
          colorFondo: Colors.teal.shade50,
          colorBorde: Colors.teal.shade300,
          colorIcono: Colors.teal.shade700,
          onTap: () => setState(() => _vistaActual = "INGRESO"),
        ),
        const SizedBox(height: 8),
        _buildTarjeta(
          icono: Icons.swap_horiz,
          titulo: "TRASPASO ENTRE CUENTAS",
          subtitulo: "Mover dinero de una cuenta a otra",
          colorFondo: Colors.orange.shade50,
          colorBorde: Colors.orange.shade300,
          colorIcono: Colors.orange.shade800,
          onTap: () => setState(() => _vistaActual = "TRASPASO"),
        ),
        const SizedBox(height: 8),
        _buildTarjeta(
          icono: Icons.currency_exchange,
          titulo: "COMPRA DE DIVISA",
          subtitulo: "Comprar USDT o dólares con bolívares",
          colorFondo: Colors.green.shade50,
          colorBorde: Colors.green.shade300,
          colorIcono: Colors.green.shade800,
          onTap: () => setState(() => _vistaActual = "DIVISA"),
        ),
        const SizedBox(height: 8),
        _buildTarjeta(
          icono: Icons.hourglass_empty,
          titulo: "CUENTAS PENDIENTES",
          subtitulo: "Facturas y pagos por realizar",
          colorFondo: Colors.amber.shade50,
          colorBorde: Colors.amber.shade300,
          colorIcono: Colors.orange.shade800,
          onTap: _abrirPendientes,
        ),
      ],
    );
  }

  Future<void> _abrirPendientes() async {
    await showDialog(
      context: context,
      builder: (context) => ModalPendientes(tasaUSD: widget.tasaUSD),
    );
  }

  Widget _buildTarjeta({
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required Color colorFondo,
    required Color colorBorde,
    required Color colorIcono,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorBorde, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icono, color: colorIcono, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: colorIcono)),
                  const SizedBox(height: 1),
                  Text(subtitulo,
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: colorIcono),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VISTA EGRESO
  // ============================================================
  Widget _buildVistaEgreso() {
    final totalBs = _totalBsEgreso();
    final comisionBs = _comisionEgresoBs();
    final montoEscrito = _parseInput(_montoEgresoCtrl.text);
    final monedaCalc = _monedaCalcEgresoEfectiva();
    final monedaCuenta = _monedaParaCuenta(_cuentaEgresoActual);
    final equivEnBs = montoEscrito > 0 ? _aBs(montoEscrito, monedaCalc) : 0.0;
    final equivNativo = montoEscrito > 0
        ? _convertir(montoEscrito, monedaCalc, monedaCuenta)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFechaSelector(
          fecha: _fechaEgreso,
          onCambio: (d) => setState(() => _fechaEgreso = d),
          color: Colors.red.shade700,
        ),
        const SizedBox(height: 6),
        _buildSeccion(
          icono: Icons.upload,
          titulo: "EGRESO / PAGO",
          color: Colors.red.shade700,
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: DropdownButtonFormField<String>(
                  initialValue: _categoriaEgreso,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  decoration: _inputDec(),
                  items: _categoriasEgreso
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, style: const TextStyle(fontSize: 11))))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _categoriaEgreso = v!;
                    if (v != "PRESTAMO_TRABAJADOR") {
                      _cedulaPrestamoEgresoCtrl.clear();
                      _nombrePrestamoEgreso = "";
                    }
                    if (v != "Pago a Proveedores") {
                      _vincularPendiente = false;
                      _idPendienteSeleccionado = null;
                    }
                  }),
                ),
              ),

              // --- BLOQUE DE VINCULACIÓN A PENDIENTES ---
              const SizedBox(height: 6),
              SwitchListTile(
                title: const Text("Vincular a Pendiente",
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                value: _vincularPendiente,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF0F52BA),
                onChanged: (v) {
                  setState(() {
                    _vincularPendiente = v;
                    if (v) {
                      _cargarFacturasPendientes();
                    } else {
                      _idPendienteSeleccionado = null;
                      _montoEgresoCtrl.clear();
                      _conceptoEgresoCtrl.clear();
                    }
                  });
                },
              ),
              if (_vincularPendiente) ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: 36,
                  child: DropdownButtonFormField<String>(
                    value: _idPendienteSeleccionado,
                    isExpanded: true,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black87),
                    decoration:
                        _inputDec(hint: "Seleccione cuenta pendiente"),
                    items: _facturasPendientes.map((f) {
                      final tercero = f['tercero']?.toString() ?? '';
                      final concepto = f['concepto']?.toString() ?? '';
                      final desc = concepto.isNotEmpty ? "$tercero - $concepto" : tercero;
                      return DropdownMenuItem<String>(
                        value: f['id'].toString(),
                        child: Text(
                            "$desc (${_fmt.format(f['monto'])} ${f['moneda']})",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        _idPendienteSeleccionado = v;
                        final f = _facturasPendientes
                            .firstWhere((x) => x['id'].toString() == v, orElse: () => null);
                        if (f != null) {
                          final tercero = f['tercero']?.toString() ?? '';
                          final concepto = f['concepto']?.toString() ?? '';
                          _conceptoEgresoCtrl.text = concepto.isNotEmpty
                              ? "$tercero - $concepto"
                              : tercero;
                          _montoEgresoCtrl.text = (f['monto'] as num)
                              .toDouble()
                              .toStringAsFixed(2);
                          if (f['moneda'] != null && f['moneda'].toString().isNotEmpty) {
                            _monedaCalcEgreso = f['moneda'].toString().toUpperCase();
                          }
                        }
                      });
                    },
                  ),
                ),
              ],
              // ------------------------------------

              if (_categoriaEgreso == "PRESTAMO_TRABAJADOR") ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _cedulaPrestamoEgresoCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 11),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _buscarTrabajadorEgreso(),
                    decoration:
                        _inputDec(hint: "Cédula del trabajador").copyWith(
                      suffixIcon: _buscandoPrestamoEgreso
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                height: 14,
                                width: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search, size: 16),
                              onPressed: _buscarTrabajadorEgreso,
                            ),
                    ),
                  ),
                ),
                if (_nombrePrestamoEgreso.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Trabajador: $_nombrePrestamoEgreso",
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  ),
              ],
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _conceptoEgresoCtrl,
                  style: const TextStyle(fontSize: 11),
                  textInputAction: TextInputAction.next,
                  decoration: _inputDec(hint: "Concepto / Descripción"),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: DropdownButtonFormField<String>(
                  initialValue: _metodoPagoEgreso,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  decoration: _inputDec(hint: "Método de pago"),
                  items: _metodosPagoEgreso
                      .map((m) => DropdownMenuItem(
                            value: m['valor'].toString(),
                            child: Text(m['label'].toString(),
                                style: const TextStyle(fontSize: 11)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _metodoPagoEgreso = v!),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: DropdownButtonFormField<String>(
                  initialValue: _origenFondosEgreso,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  decoration: _inputDec(hint: "Origen de fondos"),
                  items: const [
                    DropdownMenuItem(
                        value: "ACUMULADO",
                        child: Text("Del acumulado",
                            style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(
                        value: "VENTA_DIA",
                        child: Text("De la venta del día",
                            style: TextStyle(fontSize: 11))),
                  ],
                  onChanged: (v) => setState(() => _origenFondosEgreso = v!),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: DropdownButtonFormField<String>(
                  initialValue: _cuentaEgresoActual,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  decoration: _inputDec(hint: "Cuenta Origen"),
                  items: _cuentasBancos
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 11))))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _cuentaEgresoActual = v!;
                    if (v == "Caja Efectivo Bs") {
                      _origenFondosEgreso = "VENTA_DIA";
                    } else {
                      _origenFondosEgreso = "ACUMULADO";
                    }
                  }),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                  "Disponible: ${_cargandoSaldos ? '...' : _fmt.format(_obtenerSaldoDisponible(_cuentaEgresoActual))} $monedaCuenta",
                  style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _montoEgresoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _agregarPartidaEgreso(),
                        decoration: _inputDecMonto(
                          monedaCalc: monedaCalc,
                          onTapCalc: () => _elegirMonedaCalc(esEgreso: true),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 36,
                    width: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F52BA),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(36, 36),
                      ),
                      onPressed: _agregarPartidaEgreso,
                      child: const Icon(Icons.add, size: 18),
                    ),
                  ),
                ],
              ),
              if (montoEscrito > 0 && monedaCalc != monedaCuenta)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      "≈ Se debitarán ${_fmt.format(equivNativo)} $monedaCuenta",
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF0F52BA),
                          fontWeight: FontWeight.bold)),
                )
              else if (montoEscrito > 0 && monedaCalc != "BS")
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("≈ ${_fmt.format(equivEnBs)} Bs",
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF0F52BA),
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 6),
              Container(
                height: 90,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _desgloseEgreso.isEmpty
                    ? const Center(
                        child: Text("Sin partidas agregadas",
                            style: TextStyle(fontSize: 10, color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _desgloseEgreso.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final it = _desgloseEgreso[i];
                          final escritura = it['monedaEscrita'] == it['moneda']
                              ? null
                              : "${_fmt.format(it['montoEscrito'])} ${it['monedaEscrita']}";
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text(it['cuenta'],
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold)),
                            subtitle: escritura != null
                                ? Text("escrito: $escritura",
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.grey))
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                        "-${_fmt.format(it['monto'])} ${it['moneda']}",
                                        style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F52BA))),
                                    if (it['moneda'] != "BS")
                                      Text("≈ ${_fmt.format(it['montoBs'])} Bs",
                                          style: const TextStyle(
                                              fontSize: 9, color: Colors.grey))
                                    else
                                      Text(
                                          "≈ \$ ${_fmt.format(widget.tasaUSD > 0 ? (it['montoBs'] as num).toDouble() / widget.tasaUSD : 0)}",
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey.shade600)),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 14, color: Colors.red),
                                  onPressed: () => _quitarPartidaEgreso(i),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (comisionBs > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          "Comisión ${(_pctComisionEgreso() * 100).toStringAsFixed(1)}% (${_labelMetodoEgreso()}):",
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("+${_fmt.format(comisionBs)} Bs",
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange)),
                          Text(
                              "≈ \$ ${_fmt.format(widget.tasaUSD > 0 ? comisionBs / widget.tasaUSD : 0)}",
                              style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade400)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total a Debitar:",
                        style: TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.bold)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${_fmt.format(totalBs + comisionBs)} Bs",
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                        Text(
                            "≈ \$ ${_fmt.format(widget.tasaUSD > 0 ? (totalBs + comisionBs) / widget.tasaUSD : 0)}",
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 36,
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
                      : const Icon(Icons.check_circle, size: 16),
                  label: const Text("REGISTRAR EGRESO",
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: _procesando ? null : _procesarEgreso,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VISTA INGRESO
  // ============================================================
  Widget _buildVistaIngreso() {
    final totalBs = _totalBsIngreso();
    final montoEscrito = _parseInput(_montoIngresoCtrl.text);
    final monedaCalc = _monedaCalcIngresoEfectiva();
    final monedaCuenta = _monedaParaCuenta(_cuentaIngresoActual);
    final equivEnBs = montoEscrito > 0 ? _aBs(montoEscrito, monedaCalc) : 0.0;
    final equivNativo = montoEscrito > 0
        ? _convertir(montoEscrito, monedaCalc, monedaCuenta)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFechaSelector(
          fecha: _fechaIngreso,
          onCambio: (d) => setState(() => _fechaIngreso = d),
          color: Colors.teal.shade700,
        ),
        const SizedBox(height: 6),
        _buildSeccion(
          icono: Icons.download,
          titulo: "INGRESO / COBRO",
          color: Colors.teal.shade700,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 12, color: Colors.orange.shade900),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        "VENTAS solo por CIERRE. Este módulo es para AJUSTES, intereses o cobros externos.",
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 36,
                child: DropdownButtonFormField<String>(
                  initialValue: _categoriaIngreso,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  decoration: _inputDec(),
                  items: _categoriasIngreso
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, style: const TextStyle(fontSize: 11))))
                      .toList(),
                  onChanged: (v) => setState(() => _categoriaIngreso = v!),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _conceptoIngresoCtrl,
                  style: const TextStyle(fontSize: 11),
                  textInputAction: TextInputAction.next,
                  decoration: _inputDec(hint: "Concepto / Descripción"),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: DropdownButtonFormField<String>(
                  initialValue: _origenFondosIngreso,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  decoration: _inputDec(hint: "Origen de fondos"),
                  items: const [
                    DropdownMenuItem(
                        value: "VENTA_DIA",
                        child: Text("De la venta del día",
                            style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(
                        value: "ACUMULADO",
                        child: Text("Del acumulado",
                            style: TextStyle(fontSize: 11))),
                  ],
                  onChanged: (v) => setState(() => _origenFondosIngreso = v!),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: DropdownButtonFormField<String>(
                  initialValue: _cuentaIngresoActual,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  decoration: _inputDec(hint: "Cuenta Destino"),
                  items: _cuentasBancos
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 11))))
                      .toList(),
                  onChanged: (v) => setState(() => _cuentaIngresoActual = v!),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                  "Disponible: ${_cargandoSaldos ? '...' : _fmt.format(_obtenerSaldoDisponible(_cuentaIngresoActual))} $monedaCuenta",
                  style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _montoIngresoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _agregarPartidaIngreso(),
                        decoration: _inputDecMonto(
                          monedaCalc: monedaCalc,
                          onTapCalc: _elegirMonedaCalcIngreso,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 36,
                    width: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F52BA),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(36, 36),
                      ),
                      onPressed: _agregarPartidaIngreso,
                      child: const Icon(Icons.add, size: 18),
                    ),
                  ),
                ],
              ),
              if (montoEscrito > 0 && monedaCalc != monedaCuenta)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      "≈ Se acreditarán ${_fmt.format(equivNativo)} $monedaCuenta",
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF0F52BA),
                          fontWeight: FontWeight.bold)),
                )
              else if (montoEscrito > 0 && monedaCalc != "BS")
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("≈ ${_fmt.format(equivEnBs)} Bs",
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF0F52BA),
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 6),
              Container(
                height: 90,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _desgloseIngreso.isEmpty
                    ? const Center(
                        child: Text("Sin partidas agregadas",
                            style: TextStyle(fontSize: 10, color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _desgloseIngreso.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final it = _desgloseIngreso[i];
                          final escritura = it['monedaEscrita'] == it['moneda']
                              ? null
                              : "${_fmt.format(it['montoEscrito'])} ${it['monedaEscrita']}";
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text(it['cuenta'],
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold)),
                            subtitle: escritura != null
                                ? Text("escrito: $escritura",
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.grey))
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                        "+${_fmt.format(it['monto'])} ${it['moneda']}",
                                        style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green)),
                                    if (it['moneda'] != "BS")
                                      Text("≈ ${_fmt.format(it['montoBs'])} Bs",
                                          style: const TextStyle(
                                              fontSize: 9, color: Colors.grey))
                                    else
                                      Text(
                                          "≈ \$ ${_fmt.format(widget.tasaUSD > 0 ? (it['montoBs'] as num).toDouble() / widget.tasaUSD : 0)}",
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey.shade600)),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 14, color: Colors.red),
                                  onPressed: () => _quitarPartidaIngreso(i),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total a Acreditar:",
                        style: TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.bold)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${_fmt.format(totalBs)} Bs",
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                        Text(
                            "≈ \$ ${_fmt.format(widget.tasaUSD > 0 ? totalBs / widget.tasaUSD : 0)}",
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
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
                      : const Icon(Icons.check_circle, size: 16),
                  label: const Text("REGISTRAR INGRESO",
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: _procesando ? null : _procesarIngreso,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VISTA TRASPASO
  // ============================================================
  Widget _buildVistaTraspaso() {
    final montoEscrito = _parseInput(_montoTraspasoCtrl.text);
    final monedaCalc = _monedaCalcTraspasoEfectiva();
    final monedaOrigen = _monedaParaCuenta(_cuentaOrigenTraspaso);
    final monedaDestino = _monedaParaCuenta(_cuentaDestinoTraspaso);

    final montoEnOrigen = _convertir(montoEscrito, monedaCalc, monedaOrigen);
    final montoEnDestino = _convertir(montoEscrito, monedaCalc, monedaDestino);
    final comision = _comisionTraspaso(montoEnOrigen);
    final totalDebitar = montoEnOrigen + comision;
    final cruzaMoneda = monedaOrigen != monedaDestino;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFechaSelector(
          fecha: _fechaTraspaso,
          onCambio: (d) => setState(() => _fechaTraspaso = d),
          color: Colors.orange.shade800,
        ),
        const SizedBox(height: 6),
        _buildSeccion(
          icono: Icons.swap_horiz,
          titulo: "TRASPASO ENTRE CUENTAS",
          color: Colors.orange.shade800,
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: DropdownButtonFormField<String>(
                  initialValue: _tipoTraspaso,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  decoration: _inputDec(hint: "Tipo de Traspaso"),
                  items: const [
                    DropdownMenuItem(
                        value: "MISMO_BANCO",
                        child: Text("Mismo Banco (sin comisión)",
                            style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(
                        value: "OTRO_BANCO",
                        child: Text("Otro Banco (0.3% comisión)",
                            style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(
                        value: "PAGO_MOVIL",
                        child: Text("Pago Móvil (sin comisión)",
                            style: TextStyle(fontSize: 11))),
                  ],
                  onChanged: (v) => setState(() => _tipoTraspaso = v!),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: DropdownButtonFormField<String>(
                  initialValue: _origenFondosTraspaso,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  decoration: _inputDec(hint: "Origen de fondos"),
                  items: const [
                    DropdownMenuItem(
                        value: "ACUMULADO",
                        child: Text("Del acumulado",
                            style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(
                        value: "VENTA_DIA",
                        child: Text("De la venta del día",
                            style: TextStyle(fontSize: 11))),
                  ],
                  onChanged: (v) => setState(() => _origenFondosTraspaso = v!),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: DropdownButtonFormField<String>(
                        initialValue: _cuentaOrigenTraspaso,
                        isExpanded: true,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black87),
                        decoration: _inputDec(hint: "Cuenta Origen"),
                        items: _cuentasBancos
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: const TextStyle(fontSize: 11))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _cuentaOrigenTraspaso = v!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: DropdownButtonFormField<String>(
                        initialValue: _cuentaDestinoTraspaso,
                        isExpanded: true,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black87),
                        decoration: _inputDec(hint: "Cuenta Destino"),
                        items: _cuentasBancos
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: const TextStyle(fontSize: 11))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _cuentaDestinoTraspaso = v!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  "Origen: $monedaOrigen · Destino: $monedaDestino · Disponible: ${_cargandoSaldos ? '...' : _fmt.format(_obtenerSaldoDisponible(_cuentaOrigenTraspaso))} $monedaOrigen",
                  style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey)),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _montoTraspasoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecMonto(
                    monedaCalc: monedaCalc,
                    onTapCalc: () => _elegirMonedaCalc(esEgreso: false),
                    hint: "Monto a Traspasar",
                  ),
                ),
              ),
              if (montoEscrito > 0 && cruzaMoneda)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      "≈ Al destino llegan ${_fmt.format(montoEnDestino)} $monedaDestino",
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF0F52BA),
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _conceptoTraspasoCtrl,
                  style: const TextStyle(fontSize: 11),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _procesarTraspaso(),
                  decoration: _inputDec(hint: "Concepto"),
                ),
              ),
              if (comision > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Comisión 0.3%:",
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                      Text("${_fmt.format(comision)} $monedaOrigen",
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Se debita de $_cuentaOrigenTraspaso:",
                            style: const TextStyle(fontSize: 10.5)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("${_fmt.format(totalDebitar)} $monedaOrigen",
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red)),
                            if (monedaOrigen == "BS")
                              Text(
                                  "≈ \$ ${_fmt.format(widget.tasaUSD > 0 ? totalDebitar / widget.tasaUSD : 0)}",
                                  style: TextStyle(
                                      fontSize: 8.5,
                                      color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Se acredita a $_cuentaDestinoTraspaso:",
                            style: const TextStyle(fontSize: 10.5)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                "${_fmt.format(montoEnDestino)} $monedaDestino",
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
                            if (monedaDestino == "BS")
                              Text(
                                  "≈ \$ ${_fmt.format(widget.tasaUSD > 0 ? montoEnDestino / widget.tasaUSD : 0)}",
                                  style: TextStyle(
                                      fontSize: 8.5,
                                      color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 36,
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
                      : const Icon(Icons.check_circle, size: 16),
                  label: const Text("REGISTRAR TRASPASO",
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: _procesando ? null : _procesarTraspaso,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VISTA COMPRA DIVISA (SIMPLIFICADA)
  // ============================================================
  Widget _buildVistaCompraDivisa() {
    final monto = _parseInput(_montoCompraCtrl.text);
    final tasa = _monedaDestinoCompra == "USD"
        ? _parseInput(_tasaBCVCtrl.text)
        : _parseInput(_tasaUSDTCTRL.text);
    final totalDebitar = monto * tasa;
    final tasaBase =
        _monedaDestinoCompra == "USD" ? widget.tasaUSD : widget.tasaUSDT;
    final esManual = (tasa - tasaBase).abs() > 0.01;
    final sufijoTasa = _monedaDestinoCompra == "USD" ? "Bs/\$" : "Bs/₮";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFechaSelector(
          fecha: _fechaCompra,
          onCambio: (d) => setState(() => _fechaCompra = d),
          color: Colors.green.shade800,
        ),
        const SizedBox(height: 6),
        _buildSeccion(
          icono: Icons.currency_exchange,
          titulo: "COMPRA DE DIVISA",
          color: Colors.green.shade800,
          child: Column(
            children: [
              // Cuenta Origen + Cuenta Destino
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: DropdownButtonFormField<String>(
                        initialValue: _cuentaOrigenCompra,
                        isExpanded: true,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black87),
                        decoration: _inputDec(hint: "Cuenta Origen (Bs)"),
                        items: _cuentasBancos
                            .where((c) => c != "USDT" && c != "Efectivo USD")
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: const TextStyle(fontSize: 11))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _cuentaOrigenCompra = v!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: DropdownButtonFormField<String>(
                        initialValue: _cuentaDestinoCompra,
                        isExpanded: true,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black87),
                        decoration: _inputDec(hint: "Cuenta Destino"),
                        items: const [
                          DropdownMenuItem(
                              value: "USDT",
                              child: Text("USDT (Binance)",
                                  style: TextStyle(fontSize: 11))),
                          DropdownMenuItem(
                              value: "Efectivo USD",
                              child: Text("Efectivo USD",
                                  style: TextStyle(fontSize: 11))),
                        ],
                        onChanged: (v) =>
                            setState(() => _cuentaDestinoCompra = v!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Moneda a comprar + Monto
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text("USDT",
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold)),
                            selected: _monedaDestinoCompra == "USDT",
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _monedaDestinoCompra = "USDT";
                                  _tasaUSDTCTRL.text =
                                      widget.tasaUSDT.toStringAsFixed(2);
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text("USD",
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold)),
                            selected: _monedaDestinoCompra == "USD",
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _monedaDestinoCompra = "USD";
                                  _tasaBCVCtrl.text =
                                      widget.tasaUSD.toStringAsFixed(2);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _montoCompraCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _procesarCompraDivisa(),
                        decoration: _inputDec(
                          hint: "Monto a Comprar",
                          suffix: _monedaDestinoCompra,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Tasa única (editable)
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _monedaDestinoCompra == "USD"
                      ? _tasaBCVCtrl
                      : _tasaUSDTCTRL,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDec(
                    hint: _monedaDestinoCompra == "USD"
                        ? "Tasa BCV (editable)"
                        : "Tasa USDT (editable)",
                    suffix: sufijoTasa,
                  ),
                ),
              ),
              if (esManual && tasa > 0)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text("⚠ Usando tasa manual",
                      style: TextStyle(
                          fontSize: 9.5,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold)),
                ),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Acredita:",
                            style: TextStyle(fontSize: 10.5)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                "+ ${_fmt.format(monto)} $_monedaDestinoCompra",
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
                            if (_monedaDestinoCompra == "USDT")
                              Text(
                                  "≈ \$ ${_fmt.format(widget.tasaUSDT > 0 ? monto / widget.tasaUSDT : monto)}",
                                  style: TextStyle(
                                      fontSize: 8.5,
                                      color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Debita:", style: TextStyle(fontSize: 10.5)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("- ${_fmt.format(totalDebitar)} Bs",
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red)),
                            Text(
                                "≈ \$ ${_fmt.format(widget.tasaUSD > 0 ? totalDebitar / widget.tasaUSD : 0)}",
                                style: TextStyle(
                                    fontSize: 8.5,
                                    color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Tasa aplicada:",
                            style: TextStyle(fontSize: 10.5)),
                        Text("${_fmt.format(tasa)} Bs",
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color:
                                    esManual ? Colors.orange : Colors.black87)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                  "Disponible: ${_cargandoSaldos ? '...' : _fmt.format(_obtenerSaldoDisponible(_cuentaOrigenCompra))} Bs",
                  style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 36,
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
                      : const Icon(Icons.check_circle, size: 16),
                  label: const Text("PROCESAR COMPRA",
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: _procesando ? null : _procesarCompraDivisa,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // WIDGETS AUXILIARES
  // ============================================================
  InputDecoration _inputDec({String? hint, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11),
      suffixText: suffix,
      suffixStyle: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF0F52BA)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF0F52BA), width: 2),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  InputDecoration _inputDecMonto({
    required String monedaCalc,
    required VoidCallback onTapCalc,
    String? hint,
  }) {
    return InputDecoration(
      hintText: hint ?? "Monto",
      hintStyle: const TextStyle(fontSize: 11),
      suffixIcon: InkWell(
        onTap: onTapCalc,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calculate_outlined,
                  size: 12, color: Color(0xFF0F52BA)),
              const SizedBox(width: 4),
              Text(monedaCalc,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F52BA))),
            ],
          ),
        ),
      ),
      suffixIconConstraints: const BoxConstraints(minWidth: 60),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF0F52BA), width: 2),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

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

  // ============================================================
  // COMPROBANTES
  // ============================================================
  void _mostrarComprobanteIngreso(
      BuildContext ctx, Map<String, dynamic> datos) {
    _mostrarDialogoComprobante(
      ctx,
      datos: datos,
      titulo: "COMPROBANTE DE INGRESO",
      colorHeader: Colors.teal.shade700,
      iconoHeader: Icons.download,
      lineas: (d) => [
        _lineaInfo("Fecha registro", d['fecha']),
        if (d['fechaOperacion'] != null)
          _lineaInfo("Fecha operación", d['fechaOperacion']),
        _lineaInfo("ID", d['idTx']),
        _lineaInfo("Categoría", d['categoria']),
        _lineaInfo("Concepto", d['concepto']),
        _lineaSeparador(),
        _lineaInfo("Desglose de cuentas:", ''),
        ...(d['desglose'] as List).map((it) {
          final monto = (it['monto'] as num).toDouble();
          final moneda = it['moneda']?.toString() ?? "BS";
          final montoBs = (it['montoBs'] as num?)?.toDouble() ?? 0;
          return Padding(
            padding: const EdgeInsets.only(left: 12, top: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(it['cuenta'], style: const TextStyle(fontSize: 11)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("+${_fmt.format(monto)} $moneda",
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    if (moneda != "BS")
                      Text("≈ ${_fmt.format(montoBs)} Bs",
                          style:
                              const TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          );
        }),
        _lineaSeparador(),
        _lineaTotal("TOTAL ACREDITADO", "${_fmt.format(d['montoTotal'])} Bs"),
      ],
    );
  }

  void _mostrarComprobanteEgreso(BuildContext ctx, Map<String, dynamic> datos) {
    _mostrarDialogoComprobante(
      ctx,
      datos: datos,
      titulo: "COMPROBANTE DE EGRESO",
      colorHeader: Colors.red.shade700,
      iconoHeader: Icons.upload,
      lineas: (d) => [
        _lineaInfo("Fecha registro", d['fecha']),
        if (d['fechaOperacion'] != null)
          _lineaInfo("Fecha operación", d['fechaOperacion']),
        _lineaInfo("ID", d['idTx']),
        _lineaInfo("Tipo", d['categoria']),
        _lineaInfo("Método", d['metodoPago'] ?? '-'),
        _lineaInfo("Concepto", d['concepto']),
        _lineaSeparador(),
        _lineaInfo("Desglose de cuentas:", ''),
        ...(d['desglose'] as List).map((it) {
          final monto = (it['monto'] as num).toDouble();
          final moneda = it['moneda']?.toString() ?? "BS";
          final montoBs = (it['montoBs'] as num?)?.toDouble() ?? 0;
          return Padding(
            padding: const EdgeInsets.only(left: 12, top: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(it['cuenta'], style: const TextStyle(fontSize: 11)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("-${_fmt.format(monto)} $moneda",
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    if (moneda != "BS")
                      Text("≈ ${_fmt.format(montoBs)} Bs",
                          style:
                              const TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          );
        }),
        if ((d['comision'] as num?)?.toDouble() != null &&
            (d['comision'] as num).toDouble() > 0) ...[
          _lineaSeparador(),
          _lineaInfo("Comisión bancaria", "+${_fmt.format(d['comision'])} Bs"),
        ],
        _lineaSeparador(),
        _lineaTotal("TOTAL DEBITADO",
            "${_fmt.format((d['montoTotal'] as num) + ((d['comision'] ?? 0) as num))} Bs"),
      ],
    );
  }

  void _mostrarComprobanteTraspaso(
      BuildContext ctx, Map<String, dynamic> datos) {
    _mostrarDialogoComprobante(
      ctx,
      datos: datos,
      titulo: "COMPROBANTE DE TRASPASO",
      colorHeader: Colors.orange.shade800,
      iconoHeader: Icons.swap_horiz,
      lineas: (d) => [
        _lineaInfo("Fecha registro", d['fecha']),
        if (d['fechaOperacion'] != null)
          _lineaInfo("Fecha operación", d['fechaOperacion']),
        _lineaInfo("ID", d['idTx']),
        _lineaInfo("Tipo", d['tipoTraspaso'].toString().replaceAll('_', ' ')),
        _lineaInfo("Concepto", d['concepto']),
        _lineaSeparador(),
        _lineaInfo("Cuenta Origen", d['cuentaOrigen']),
        _lineaInfo("Cuenta Destino", d['cuentaDestino']),
        _lineaSeparador(),
        _lineaInfo("Enviado",
            "${_fmt.format(d['montoEnOrigen'])} ${d['monedaOrigen']}"),
        if ((d['comision'] as num).toDouble() > 0)
          _lineaInfo("Comisión bancaria",
              "${_fmt.format(d['comision'])} ${d['monedaOrigen']}"),
        _lineaInfo("Recibido",
            "${_fmt.format(d['montoEnDestino'])} ${d['monedaDestino']}"),
        _lineaSeparador(),
        _lineaTotal("TOTAL DEBITADO",
            "${_fmt.format(d['totalDebitar'])} ${d['monedaOrigen']}"),
      ],
    );
  }

  void _mostrarComprobanteDivisa(BuildContext ctx, Map<String, dynamic> datos) {
    _mostrarDialogoComprobante(
      ctx,
      datos: datos,
      titulo: "COMPROBANTE DE COMPRA DIVISA",
      colorHeader: Colors.green.shade700,
      iconoHeader: Icons.currency_exchange,
      lineas: (d) => [
        _lineaInfo("Fecha registro", d['fecha']),
        if (d['fechaOperacion'] != null)
          _lineaInfo("Fecha operación", d['fechaOperacion']),
        _lineaInfo("ID", d['idTx']),
        if (d['tasaManual'] == true) _lineaInfo("Aviso", "Usó tasa manual"),
        _lineaSeparador(),
        _lineaInfo("Cuenta Origen", d['cuentaOrigen']),
        _lineaInfo("Cuenta Destino", d['cuentaDestino']),
        _lineaSeparador(),
        _lineaInfo("Acredita",
            "+ ${_fmt.format(d['montoDivisa'])} ${d['monedaDestino']}"),
        _lineaInfo("Debita", "- ${_fmt.format(d['montoBs'])} Bs"),
        _lineaInfo("Tasa aplicada", "${_fmt.format(d['tasa'])} Bs"),
        _lineaSeparador(),
        _lineaTotal("TOTAL DEBITADO", "${_fmt.format(d['montoBs'])} Bs"),
      ],
    );
  }

  Widget _lineaInfo(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text("$label:",
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
          ),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _lineaTotal(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          Text(valor,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F52BA))),
        ],
      ),
    );
  }

  Widget _lineaSeparador() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Divider(height: 1),
    );
  }

  void _mostrarDialogoComprobante(
    BuildContext ctx, {
    required Map<String, dynamic> datos,
    required String titulo,
    required Color colorHeader,
    required IconData iconoHeader,
    required List<Widget> Function(Map<String, dynamic>) lineas,
  }) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colorHeader,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(iconoHeader, size: 15, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(titulo,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5)),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(dialogCtx),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lineas(datos),
                  ),
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
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.print, size: 13),
                          label: const Text("TICKET 80mm",
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            await _imprimirComprobante(datos, true);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F52BA),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 13),
                          label: const Text("PDF",
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            await _imprimirComprobante(datos, false);
                            if (!dialogCtx.mounted) return;
                            Navigator.pop(dialogCtx);
                          },
                        ),
                      ),
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

  Future<void> _imprimirComprobante(
      Map<String, dynamic> datos, bool esTicket) async {
    final doc = pw.Document();
    final pageFormat = esTicket ? PdfPageFormat.roll80 : PdfPageFormat.a4;
    final tipo = datos['tipo']?.toString() ?? 'OPERACION';

    doc.addPage(pw.Page(
      pageFormat: pageFormat,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text("CONTROL Y GESTION",
                  style: const pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ),
            pw.Center(
              child: pw.Text(
                tipo == "EGRESO"
                    ? "COMPROBANTE DE EGRESO"
                    : tipo == "INGRESO"
                        ? "COMPROBANTE DE INGRESO"
                        : tipo == "TRASPASO"
                            ? "COMPROBANTE DE TRASPASO"
                            : "COMPROBANTE DE COMPRA DIVISA",
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text("Fecha registro: ${datos['fecha']}",
                style: const pw.TextStyle(fontSize: 7)),
            if (datos['fechaOperacion'] != null)
              pw.Text("Fecha operación: ${datos['fechaOperacion']}",
                  style: const pw.TextStyle(fontSize: 7)),
            pw.Text("ID: ${datos['idTx']}",
                style: const pw.TextStyle(fontSize: 7)),
            pw.Divider(thickness: 0.5),
            if (tipo == "INGRESO") ...[
              _buildFilaPdf("Categoría", datos['categoria']?.toString() ?? ''),
              _buildFilaPdf("Concepto", datos['concepto']?.toString() ?? ''),
              pw.Divider(thickness: 0.5),
              pw.Text("Desglose:",
                  style: const pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 8)),
              pw.SizedBox(height: 3),
              ...(datos['desglose'] as List).map((it) {
                final monto = (it['monto'] as num).toDouble();
                final moneda = it['moneda']?.toString() ?? "BS";
                final montoBs = (it['montoBs'] as num?)?.toDouble() ?? 0;
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(it['cuenta'].toString(),
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("+${_fmt.format(monto)} $moneda",
                            style: const pw.TextStyle(fontSize: 8)),
                        if (moneda != "BS")
                          pw.Text("≈ ${_fmt.format(montoBs)} Bs",
                              style: const pw.TextStyle(fontSize: 6)),
                      ],
                    ),
                  ],
                );
              }),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL ACREDITADO",
                      style: const pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text("${_fmt.format(datos['montoTotal'])} Bs",
                      style: const pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
            ],
            if (tipo == "EGRESO") ...[
              _buildFilaPdf("Tipo", datos['categoria']?.toString() ?? ''),
              if (datos['metodoPago'] != null)
                _buildFilaPdf("Método", datos['metodoPago'].toString()),
              _buildFilaPdf("Concepto", datos['concepto']?.toString() ?? ''),
              pw.Divider(thickness: 0.5),
              pw.Text("Desglose:",
                  style: const pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 8)),
              pw.SizedBox(height: 3),
              ...(datos['desglose'] as List).map((it) {
                final monto = (it['monto'] as num).toDouble();
                final moneda = it['moneda']?.toString() ?? "BS";
                final montoBs = (it['montoBs'] as num?)?.toDouble() ?? 0;
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(it['cuenta'].toString(),
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("-${_fmt.format(monto)} $moneda",
                            style: const pw.TextStyle(fontSize: 8)),
                        if (moneda != "BS")
                          pw.Text("≈ ${_fmt.format(montoBs)} Bs",
                              style: const pw.TextStyle(fontSize: 6)),
                      ],
                    ),
                  ],
                );
              }),
              if ((datos['comision'] as num?)?.toDouble() != null &&
                  (datos['comision'] as num).toDouble() > 0) ...[
                pw.Divider(thickness: 0.5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Comisión bancaria",
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text("+${_fmt.format(datos['comision'])} Bs",
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL DEBITADO",
                      style: const pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text(
                      "${_fmt.format((datos['montoTotal'] as num) + ((datos['comision'] ?? 0) as num))} Bs",
                      style: const pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
            ],
            if (tipo == "TRASPASO") ...[
              _buildFilaPdf("Tipo",
                  datos['tipoTraspaso'].toString().replaceAll('_', ' ')),
              _buildFilaPdf("Concepto", datos['concepto']?.toString() ?? ''),
              pw.Divider(thickness: 0.5),
              _buildFilaPdf("Origen", datos['cuentaOrigen'].toString()),
              _buildFilaPdf("Destino", datos['cuentaDestino'].toString()),
              pw.Divider(thickness: 0.5),
              _buildFilaPdf("Enviado",
                  "${_fmt.format(datos['montoEnOrigen'])} ${datos['monedaOrigen']}"),
              if ((datos['comision'] as num).toDouble() > 0)
                _buildFilaPdf("Comisión",
                    "${_fmt.format(datos['comision'])} ${datos['monedaOrigen']}"),
              _buildFilaPdf("Recibido",
                  "${_fmt.format(datos['montoEnDestino'])} ${datos['monedaDestino']}"),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL DEBITADO",
                      style: const pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text(
                      "${_fmt.format(datos['totalDebitar'])} ${datos['monedaOrigen']}",
                      style: const pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
            ],
            if (tipo == "COMPRA_DIVISA") ...[
              _buildFilaPdf("Origen", datos['cuentaOrigen'].toString()),
              _buildFilaPdf("Destino", datos['cuentaDestino'].toString()),
              if (datos['tasaManual'] == true)
                _buildFilaPdf("Aviso", "Tasa manual"),
              pw.Divider(thickness: 0.5),
              _buildFilaPdf("Acredita",
                  "+ ${_fmt.format(datos['montoDivisa'])} ${datos['monedaDestino']}"),
              _buildFilaPdf("Debita", "- ${_fmt.format(datos['montoBs'])} Bs"),
              _buildFilaPdf("Tasa", "${_fmt.format(datos['tasa'])} Bs"),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL DEBITADO",
                      style: const pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text("${_fmt.format(datos['montoBs'])} Bs",
                      style: const pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
            ],
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 0.5),
            pw.Center(
              child: pw.Text("__________________________",
                  style: const pw.TextStyle(fontSize: 7)),
            ),
            pw.Center(
              child: pw.Text("Firma del Beneficiario",
                  style: const pw.TextStyle(fontSize: 6)),
            ),
          ],
        );
      },
    ));

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save());
  }

  pw.Widget _buildFilaPdf(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text("$label:",
                style: const pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(valor, style: const pw.TextStyle(fontSize: 8)),
          ),
        ],
      ),
    );
  }
}
