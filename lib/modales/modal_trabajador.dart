import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../servicios/api_service.dart';

class ModalTrabajador extends StatefulWidget {
  final double tasaUSD;
  final double tasaUSDT;

  const ModalTrabajador(
      {super.key, required this.tasaUSD, required this.tasaUSDT});

  @override
  State<ModalTrabajador> createState() => _ModalTrabajadorState();
}

class _ModalTrabajadorState extends State<ModalTrabajador> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 2);

  final TextEditingController _cedulaCtrl = TextEditingController();
  final TextEditingController _tasaEspecialCtrl = TextEditingController();
  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _descuentoDeudaCtrl =
      TextEditingController(text: "0.00");
  final TextEditingController _montoFuenteTmpCtrl = TextEditingController();

  String _cuentaFuenteTmp = "Caja Efectivo Bs";
  String _metodoFuenteTmp = "EFECTIVO";
  String _monedaDescuento = "USD"; // "USD" o "Bs"

  bool _cargando = false;
  bool _procesando = false;
  bool _aplicarDescuentoDeuda = false;
  bool _cargandoHistorial = false;

  final List<Map<String, dynamic>> _adicionales = [];
  final List<String> _categoriasAdicional = [
    "Transporte",
    "Incentivo",
    "Comisión",
    "Viático",
    "Otro",
  ];
  double _totalAdicionalesUSD = 0.0;

  List<dynamic> _historialPrestamos = [];

  bool _encontrado = false;
  bool _trabajadorInactivo = false;
  String _nombreTrabajador = "";
  double _sueldoBase = 0.0;
  double _ayudaFamiliar = 0.0;
  double _bonoAlimenticio = 0.0;
  double _deudaPendiente = 0.0;
  String _fechaIngresoStr = "";
  DateTime _fechaEgresoSeleccionada = DateTime.now();

  int _anosTrabajados = 0;
  int _mesesTrabajados = 0;
  int _diasTrabajados = 0;

  double _detallePrestaciones = 0.0;
  double _detalleVacaciones = 0.0;
  double _detalleUtilidades = 0.0;
  double _detalleSemana = 0.0;
  double _detalleAyudaFamiliar = 0.0;
  double _detalleBonoAlimenticio = 0.0;
  double _detalleComision = 0.0;

  double _totalSalarial = 0.0;
  double _totalNoSalarial = 0.0;
  double _totalDivisasCalculado = 0.0;
  double _montoNetoDivisas = 0.0;

  String _tipoOperacion = "Abono / Pago de Nómina";
  final String _modalidadBonoAlimenticio = "Efectivo";

  final List<Map<String, dynamic>> _fuentesPago = [];

  final List<String> _tiposOperacion = [
    "Abono / Pago de Nómina",
    "Adelanto de Prest. Soc. + Beneficios",
    "Liquidación / Finiquito"
  ];

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

  @override
  void initState() {
    super.initState();
    _tasaEspecialCtrl.text = widget.tasaUSD.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _cedulaCtrl.dispose();
    _tasaEspecialCtrl.dispose();
    _montoCtrl.dispose();
    _descuentoDeudaCtrl.dispose();
    _montoFuenteTmpCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Helpers financieros
  // ─────────────────────────────────────────────
  double _r2(double v) => (v * 100).roundToDouble() / 100;

  double _mathMax(double a, double b) => a > b ? a : b;

  /// Parsea un número aceptando coma o punto decimal ("5,00" o "5.00").
  double _parseNum(String s) {
    final cleaned = s.trim().replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  double _tasaActual() {
    final t = _parseNum(_tasaEspecialCtrl.text);
    return t > 0 ? t : widget.tasaUSD;
  }

  /// Retorna el monto del descuento de deuda convertido a USD.
  /// Respeta la moneda seleccionada (_monedaDescuento) y nunca excede la deuda.
  double _descDeudaUsd() {
    if (!_aplicarDescuentoDeuda) return 0.0;
    final raw = _parseNum(_descuentoDeudaCtrl.text);
    if (raw <= 0) return 0.0;
    double usd;
    if (_monedaDescuento == "Bs") {
      final tasa = _tasaActual();
      usd = tasa > 0 ? _r2(raw / tasa) : 0.0;
    } else {
      usd = _r2(raw);
    }
    if (usd > _deudaPendiente) usd = _deudaPendiente;
    return _r2(usd);
  }

  String _textoLegal() {
    if (_tipoOperacion == "Liquidación / Finiquito") {
      return "HE RECIBIDO A MI ENTERA SATISFACCION EL PAGO DE MI LIQUIDACIÓN";
    } else if (_tipoOperacion == "Adelanto de Prest. Soc. + Beneficios") {
      return "HE RECIBIDO A MI ENTERA SATISFACCION EL ADELANTO SOLICITADO";
    }
    return "HE RECIBIDO A MI ENTERA SATISFACCION POR MI SEMANA DE TRABAJO";
  }

  String? _notaLegalBonoAlimenticio() {
    if (_bonoAlimenticio <= 0) return null;
    if (_modalidadBonoAlimenticio == "Efectivo") {
      return "NOTA: El pago en efectivo del beneficio de alimentación puede ser considerado salario por jurisprudencia del TSJ (Sala de Casación Social). Se recomienda el uso de tarjeta electrónica, cupones o comedor conforme a la Ley de Alimentación para los Trabajadores.";
    }
    return "Beneficio de Alimentación otorgado conforme a la Ley de Alimentación para los Trabajadores. No tiene carácter salarial (Art. 105 LOTTT).";
  }

  double _totalFuentesBs() {
    double total = 0;
    for (var f in _fuentesPago) {
      total += (f['monto'] as num).toDouble();
    }
    return _r2(total);
  }

  double _comisionFuentesBs() {
    double com = 0;
    for (var f in _fuentesPago) {
      if (f['metodo'].toString() != "EFECTIVO") {
        com += (f['monto'] as num).toDouble() * 0.003;
      }
    }
    return _r2(com);
  }

  void _agregarFuente() {
    final tasaActual = _tasaActual();
    if (tasaActual <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("La tasa cambiaria debe ser mayor a 0.",
                style: TextStyle(fontSize: 11)),
            backgroundColor: Colors.red),
      );
      return;
    }

    _calcularValores();
    double monto = _parseNum(_montoFuenteTmpCtrl.text);
    final netoBs = _r2(_montoNetoDivisas * tasaActual);
    double restante = _r2(netoBs - _totalFuentesBs());

    if (monto <= 0 && restante > 0) {
      monto = restante;
    }

    if (monto <= 0) return;

    if (monto > restante + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("El monto excede lo que falta por asignar.",
                style: TextStyle(fontSize: 11)),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _fuentesPago.add({
        "cuenta": _cuentaFuenteTmp,
        "monto": _r2(monto),
        "metodo": _metodoFuenteTmp,
      });
      _montoFuenteTmpCtrl.clear();
      _calcularValores();
    });
  }

  void _quitarFuente(int index) {
    setState(() {
      _fuentesPago.removeAt(index);
      _calcularValores();
    });
  }

  Future<void> _cargarHistorialPrestamos(String cedula) async {
    setState(() {
      _cargandoHistorial = true;
      _historialPrestamos = [];
    });

    List<dynamic> movimientos = [];

    // 1) Intento el endpoint completo (préstamos + abonos + nóminas + liquidaciones)
    try {
      final res = await ApiService.registrarAccionConRespuesta(
        "obtenerHistorialTransacciones",
        {"cedula": cedula},
      );
      if (res['historial'] is List) {
        movimientos = List<dynamic>.from(res['historial']);
      }
    } catch (e, st) {
      debugPrint('obtenerHistorialTransacciones no disponible: $e\n$st');
    }

    // 2) Fallback: solo préstamos (compatibilidad con backend actual)
    if (movimientos.isEmpty) {
      try {
        final res = await ApiService.registrarAccionConRespuesta(
          "obtenerHistorialPrestamos",
          {"cedula": cedula},
        );
        movimientos = List<dynamic>.from(res['historial'] ?? []);
      } catch (e, st) {
        debugPrint('Error cargando historial de préstamos: $e\n$st');
      }
    }

    if (!mounted) return;
    setState(() {
      _historialPrestamos = movimientos;
      _cargandoHistorial = false;
    });
  }

  void _recalcularAdicionales() {
    double total = 0;
    for (var ad in _adicionales) {
      total += _parseNum(ad['monto'].toString());
    }
    _totalAdicionalesUSD = _r2(total);
  }

  void _agregarAdicional() {
    setState(() {
      _adicionales.add({
        "id": "adic_${DateTime.now().microsecondsSinceEpoch}",
        "categoria": "Transporte",
        "monto": 0.0,
      });
    });
  }

  void _quitarAdicional(int index) {
    setState(() {
      _adicionales.removeAt(index);
      _recalcularAdicionales();
      _calcularValores();
    });
  }

  void _calcularValores() {
    if (!_encontrado) return;

    final tasaActual = _tasaActual();
    if (tasaActual <= 0) return;

    try {
      DateTime ingreso = DateTime.tryParse(_fechaIngresoStr) ?? DateTime.now();
      DateTime hoy = (_tipoOperacion == "Liquidación / Finiquito")
          ? _fechaEgresoSeleccionada
          : DateTime.now();

      int anos = hoy.year - ingreso.year;
      int meses = hoy.month - ingreso.month;
      int dias = hoy.day - ingreso.day;

      if (dias < 0) {
        meses--;
        dias += 30;
      }
      if (meses < 0) {
        anos--;
        meses += 12;
      }

      _anosTrabajados = anos < 0 ? 0 : anos;
      _mesesTrabajados = meses < 0 ? 0 : meses;
      _diasTrabajados = dias < 0 ? 0 : dias;

      double totalMesesDecimal =
          (_anosTrabajados * 12) + _mesesTrabajados + (_diasTrabajados / 30.0);

      double sueldoMensualEquiv = _sueldoBase * 4.0;
      double salarioDiario = sueldoMensualEquiv / 30.0;

      double diasPrest = totalMesesDecimal * 5.0;
      double diasVac = totalMesesDecimal * 2.5;
      double diasUtil = totalMesesDecimal * 2.5;

      _detallePrestaciones = 0.0;
      _detalleVacaciones = 0.0;
      _detalleUtilidades = 0.0;
      _detalleSemana = 0.0;
      _detalleAyudaFamiliar = 0.0;
      _detalleBonoAlimenticio = 0.0;
      _detalleComision = 0.0;

      if (_tipoOperacion == "Abono / Pago de Nómina") {
        _detalleSemana = _sueldoBase;
        _detalleAyudaFamiliar = _ayudaFamiliar;
        _detalleBonoAlimenticio = _bonoAlimenticio;
      } else if (_tipoOperacion == "Adelanto de Prest. Soc. + Beneficios") {
        _detallePrestaciones = diasPrest * salarioDiario;
        _detalleVacaciones = diasVac * salarioDiario;
        _detalleUtilidades = diasUtil * salarioDiario;
      } else if (_tipoOperacion == "Liquidación / Finiquito") {
        _detallePrestaciones = diasPrest * salarioDiario;
        _detalleVacaciones = diasVac * salarioDiario;
        _detalleUtilidades = diasUtil * salarioDiario;
        _detalleSemana = _sueldoBase;
        _detalleAyudaFamiliar = _ayudaFamiliar;
        _detalleBonoAlimenticio = _bonoAlimenticio;
      }

      _totalSalarial = _r2(_detalleSemana +
          _detallePrestaciones +
          _detalleVacaciones +
          _detalleUtilidades);
      _totalNoSalarial = _r2(_detalleAyudaFamiliar + _detalleBonoAlimenticio);
      _recalcularAdicionales();
      _totalDivisasCalculado =
          _r2(_totalSalarial + _totalNoSalarial + _totalAdicionalesUSD);

      final descDeuda = _descDeudaUsd();
      _montoNetoDivisas =
          _r2(_mathMax(0.0, _totalDivisasCalculado - descDeuda));

      _montoCtrl.text = _r2(_montoNetoDivisas * tasaActual).toStringAsFixed(2);

      _detalleComision = _r2(_comisionFuentesBs() / tasaActual);
    } catch (e, st) {
      debugPrint('Error en cálculo de valores: $e\n$st');
      _detalleSemana = _sueldoBase;
      _detalleAyudaFamiliar = _ayudaFamiliar;
      _totalSalarial = _r2(_sueldoBase);
      _totalNoSalarial = _r2(_ayudaFamiliar);
      _totalDivisasCalculado = _r2(_totalSalarial + _totalNoSalarial);
      _montoNetoDivisas = _totalDivisasCalculado;
      _montoCtrl.text =
          _r2(_montoNetoDivisas * _tasaActual()).toStringAsFixed(2);
    }
  }

  Widget _filaDesglose(String label, double monto, Color color,
      {bool negrita = false, bool grande = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: grande ? 11 : 10,
                    fontWeight: negrita ? FontWeight.bold : FontWeight.normal,
                    color: color)),
          ),
          Text("${monto < 0 ? '-' : ''}\$ ${_fmt.format(monto.abs())}",
              style: TextStyle(
                  fontSize: grande ? 11 : 10,
                  fontWeight: negrita ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  void _cargarDatosTrabajador(Map<String, dynamic> data) {
    setState(() {
      _encontrado = true;
      _nombreTrabajador = data['nombre'] ?? '';
      _sueldoBase = (data['sueldoBase'] as num?)?.toDouble() ?? 0.0;
      _ayudaFamiliar = (data['ayudaFamiliar'] as num?)?.toDouble() ?? 0.0;
      _bonoAlimenticio = (data['bonoAlimenticio'] as num?)?.toDouble() ?? 0.0;
      _deudaPendiente = _r2((data['deudaPendiente'] as num?)?.toDouble() ?? 0.0);
      _fechaIngresoStr =
          data['fechaIngreso'] ?? DateTime.now().toString().substring(0, 10);

      final ced = (data['cedula'] ?? '').toString();
      if (ced.isNotEmpty) {
        _cedulaCtrl.text = ced;
      }

      final estadoStr = (data['estado'] ?? '').toString().toUpperCase();
      _trabajadorInactivo = estadoStr == 'INACTIVO' ||
          estadoStr == 'FINALIZADO' ||
          estadoStr == 'EGRESADO';

      final fe = (data['fechaEgreso'] ?? '').toString();
      if (fe.isNotEmpty && fe.length >= 10) {
        final parsed = DateTime.tryParse(fe);
        if (parsed != null) _fechaEgresoSeleccionada = parsed;
      }

      _aplicarDescuentoDeuda = false;
      _monedaDescuento = "USD";
      if (_deudaPendiente > 0 && _deudaPendiente >= 5.0) {
        _descuentoDeudaCtrl.text = "5.00";
      } else {
        _descuentoDeudaCtrl.text = _deudaPendiente.toStringAsFixed(2);
      }

      if (_trabajadorInactivo) {
        _tipoOperacion = "Liquidación / Finiquito";
      }

      _fuentesPago.clear();

      _adicionales.clear();
      if (data['adicionales'] is List) {
        int i = 0;
        for (var ad in data['adicionales']) {
          if (ad is Map) {
            _adicionales.add({
              "id": "adic_${DateTime.now().microsecondsSinceEpoch}_$i",
              "categoria": ad['categoria']?.toString() ?? 'Otro',
              "monto": _parseNum(ad['monto']?.toString() ?? '0'),
            });
            i++;
          }
        }
      }
      _recalcularAdicionales();
      _cargarHistorialPrestamos(data['cedula']?.toString() ?? _cedulaCtrl.text.trim());
      _calcularValores();
    });
  }

  void _mostrarListaCoincidencias(List<dynamic> resultados) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Seleccione un trabajador",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F52BA),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: resultados.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = Map<String, dynamic>.from(resultados[index]);
                    final nombre = item['nombre'] ?? 'Sin Nombre';
                    final cedula = item['cedula'] ?? '';
                    final cargo = item['cargo'] ?? '';
                    return ListTile(
                      dense: true,
                      title: Text(
                        nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Text(
                        "Cédula: $cedula${cargo.toString().isNotEmpty ? ' | Cargo: $cargo' : ''}",
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () {
                        Navigator.pop(ctx);
                        _cargarDatosTrabajador(item);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _buscarTrabajador() async {
    final busqueda = _cedulaCtrl.text.trim();
    if (busqueda.isEmpty) return;

    setState(() => _cargando = true);

    try {
      final res = await ApiService.buscarTrabajadorCompleto(busqueda);
      if (!mounted) return;

      setState(() => _cargando = false);

      final resultados =
          res['resultados'] is List ? (res['resultados'] as List) : [];

      if (resultados.length > 1) {
        _mostrarListaCoincidencias(resultados);
      } else if (res['encontrado'] == true) {
        final Map<String, dynamic> datos = resultados.isNotEmpty
            ? Map<String, dynamic>.from(resultados.first)
            : Map<String, dynamic>.from(res);
        _cargarDatosTrabajador(datos);
      } else {
        setState(() {
          _encontrado = false;
          _trabajadorInactivo = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res['debug'] ?? "Trabajador no encontrado",
                  style: const TextStyle(fontSize: 11)),
              backgroundColor: Colors.red.shade900),
        );
      }
    } catch (e, st) {
      debugPrint('Error búsqueda trabajador: $e\n$st');
      if (mounted) setState(() => _cargando = false);
    }
  }

  InputDecoration _dec({String? hint, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11),
      suffixText: suffix,
      suffixStyle: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF0F52BA)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF0F52BA), width: 2),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  Future<void> _imprimirRecibo(
      Map<String, dynamic> datos, bool esTicket) async {
    final doc = pw.Document();
    final pageFormat = esTicket ? PdfPageFormat.roll80 : PdfPageFormat.a4;
    final notaLegal = datos['notaLegalBono'] as String?;

    doc.addPage(pw.Page(
      pageFormat: pageFormat,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
                child: pw.Text("CONTROL Y GESTION",
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 12))),
            pw.Center(
                child: pw.Text(
                    datos['tipo'] == "Liquidación / Finiquito"
                        ? "COMPROBANTE DE LIQUIDACIÓN"
                        : "COMPROBANTE DE PAGO",
                    style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 6),
            pw.Text("Fecha: ${datos['fecha']}",
                style: const pw.TextStyle(fontSize: 7)),
            if (datos['adicionales'] != null &&
                (datos['adicionales'] as List).isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text("PAGOS ADICIONALES (NO SALARIAL):",
                  style: const pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                      color: PdfColors.teal700)),
              pw.SizedBox(height: 2),
              ...(datos['adicionales'] as List).map((ad) {
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("  ${ad['categoria']}",
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text("\$ ${(ad['monto'] as num).toStringAsFixed(2)}",
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                );
              }),
              pw.Divider(thickness: 0.5),
            ],
            pw.Divider(thickness: 0.5),
            pw.Text("Operación: ${datos['tipo']}",
                style: const pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.Text("Trabajador: ${datos['nombre']}",
                style: const pw.TextStyle(fontSize: 8)),
            pw.Text("Cédula: V-${datos['cedula']}",
                style: const pw.TextStyle(fontSize: 8)),
            if (datos['fechaEgreso'] != null &&
                datos['fechaEgreso'].toString().isNotEmpty)
              pw.Text("Fecha de Egreso: ${datos['fechaEgreso']}",
                  style: const pw.TextStyle(fontSize: 8)),
            pw.Divider(thickness: 0.5),
            pw.Text("CONCEPTOS SALARIALES:",
                style: const pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                    color: PdfColors.blueGrey900)),
            pw.SizedBox(height: 2),
            if (datos['detSemana'] > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Sueldo Semanal:",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("\$ ${datos['detSemana'].toStringAsFixed(2)}",
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            if (datos['detPrestaciones'] > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Prestaciones:",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("\$ ${datos['detPrestaciones'].toStringAsFixed(2)}",
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            if (datos['detVacaciones'] > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Vacaciones + Bono:",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("\$ ${datos['detVacaciones'].toStringAsFixed(2)}",
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            if (datos['detUtilidades'] > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Utilidades:",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("\$ ${datos['detUtilidades'].toStringAsFixed(2)}",
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            pw.SizedBox(height: 3),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Subtotal Salarial:",
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 8)),
                pw.Text("\$ ${datos['totalSalarial'].toStringAsFixed(2)}",
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 8)),
              ],
            ),
            pw.Divider(thickness: 0.5),
            if (datos['totalNoSalarial'] > 0) ...[
              pw.Text("BENEFICIOS NO SALARIALES:",
                  style: const pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                      color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              if (datos['detAyudaFamiliar'] > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Ayuda Familiar:",
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        "\$ ${datos['detAyudaFamiliar'].toStringAsFixed(2)}",
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Text("   G.O. Ext. N° 6.076 (07/05/2012) - Art. 104 LOTTT",
                    style: const pw.TextStyle(
                        fontSize: 6, color: PdfColors.grey700)),
              ],
              if (datos['detBonoAlimenticio'] > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Bono Alimenticio:",
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        "\$ ${datos['detBonoAlimenticio'].toStringAsFixed(2)}",
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Text(
                    "   G.O. N° 39.666 (04/05/2011) - Art. 5 Ley de Alimentación",
                    style: const pw.TextStyle(
                        fontSize: 6, color: PdfColors.grey700)),
              ],
              pw.SizedBox(height: 2),
              pw.Text(
                "Estos conceptos no forman parte del salario y no inciden en prestaciones, vacaciones, bono vacacional ni utilidades.",
                style:
                    const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
              ),
              pw.Divider(thickness: 0.5),
            ],
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Total Bruto:",
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 8)),
                pw.Text("\$ ${datos['montoBrutoUSD'].toStringAsFixed(2)}",
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 8)),
              ],
            ),
            if (datos['descuentoDeuda'] > 0) ...[
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Deuda Anterior:",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("\$ ${datos['deudaAnterior'].toStringAsFixed(2)}",
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Abono a Deuda:",
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.green800)),
                  pw.Text("- \$ ${datos['descuentoDeuda'].toStringAsFixed(2)}",
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.green800)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Nueva Deuda:",
                      style: const pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text("\$ ${datos['nuevoSaldoDeuda'].toStringAsFixed(2)}",
                      style: const pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Total Neto:",
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text("\$ ${datos['montoUSD'].toStringAsFixed(2)}",
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Pagado en Bs:",
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text("${datos['montoBs'].toStringAsFixed(2)} Bs",
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Tasa:", style: const pw.TextStyle(fontSize: 7)),
                pw.Text("${datos['tasa'].toStringAsFixed(2)} Bs/\$",
                    style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),
            pw.Center(
                child: pw.Text(datos['textoLegal'],
                    style: const pw.TextStyle(fontSize: 6),
                    textAlign: pw.TextAlign.center)),
            if (notaLegal != null && notaLegal.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.3, color: PdfColors.grey400),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                child: pw.Text(notaLegal,
                    style: const pw.TextStyle(
                        fontSize: 6, color: PdfColors.grey700),
                    textAlign: pw.TextAlign.justify),
              ),
            ],
            pw.SizedBox(height: 20),
            pw.Center(
                child: pw.Text("__________________________",
                    style: const pw.TextStyle(fontSize: 7))),
            pw.Center(
                child: pw.Text("Firma del Trabajador",
                    style: const pw.TextStyle(fontSize: 6))),
          ],
        );
      },
    ));

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save());
  }

  void _procesarOperacion() async {
    if (!_encontrado) return;

    final tasaUsada = _tasaActual();
    if (tasaUsada <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("La tasa cambiaria debe ser mayor a 0.",
                style: TextStyle(fontSize: 11)),
            backgroundColor: Colors.red),
      );
      return;
    }

    final netoBs = _r2(_montoNetoDivisas * tasaUsada);
    final totalFuentes = _totalFuentesBs();

    if (_fuentesPago.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Debes agregar al menos una fuente de pago",
                style: TextStyle(fontSize: 11)),
            backgroundColor: Colors.red),
      );
      return;
    }

    if ((totalFuentes - netoBs).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "La suma de fuentes (${_fmt.format(totalFuentes)}) no coincide con el neto (${_fmt.format(netoBs)})",
                style: const TextStyle(fontSize: 11)),
            backgroundColor: Colors.red),
      );
      return;
    }

    final montoBs = totalFuentes;
    if (montoBs <= 0) return;

    setState(() => _procesando = true);

    final descDeuda = _descDeudaUsd();
    final nuevoSaldoDeuda = _r2(_mathMax(0.0, _deudaPendiente - descDeuda));

    final esLiquidacion = _tipoOperacion == "Liquidación / Finiquito";
    final fechaEgreso = esLiquidacion
        ? DateFormat('yyyy-MM-dd').format(_fechaEgresoSeleccionada)
        : "";

    final payload = {
      "tipoOperacion": _tipoOperacion,
      "cedula": _cedulaCtrl.text.trim(),
      "nombre": _nombreTrabajador,
      "adicionales": _adicionales
          .map((a) => {
                "categoria": a['categoria'],
                "monto": _r2(_parseNum(a['monto'].toString())),
              })
          .toList(),
      "montoTotal": _r2(_montoNetoDivisas),
      "montoBruto": _r2(_totalDivisasCalculado),
      "totalSalarial": _r2(_totalSalarial),
      "totalNoSalarial": _r2(_totalNoSalarial),
      "modalidadBonoAlimenticio": _modalidadBonoAlimenticio,
      "comisionBs": _r2(_comisionFuentesBs()),
      "montoBsNeto": netoBs,
      "descuentoDeuda": descDeuda,
      "deudaAnterior": _r2(_deudaPendiente),
      "nuevoSaldoDeuda": nuevoSaldoDeuda,
      "montoBsCalculado": _r2(montoBs),
      "fuentesPago": _fuentesPago,
      "cuentaSalida": _fuentesPago.isNotEmpty
          ? _fuentesPago.first['cuenta'].toString()
          : "Caja Efectivo Bs",
      "tasaUSD": tasaUsada,
      "fechaEgreso": fechaEgreso,
      "notaLegal": _textoLegal()
    };

    final res = await ApiService.registrarAccionConRespuesta(
        "procesarOperacionTrabajador", payload);

    if (!mounted) return;
    setState(() => _procesando = false);

    if (res['status'] == "SUCCESS" || res['exito'] == true) {
      final datosRecibo = {
        "tipo": _tipoOperacion,
        "nombre": _nombreTrabajador,
        "cedula": _cedulaCtrl.text.trim(),
        "cuenta": _fuentesPago.isNotEmpty
            ? _fuentesPago
                .map((f) => "${f['cuenta']}: ${f['monto']}")
                .join(" | ")
            : "VARIAS",
        "detSemana": _detalleSemana,
        "detPrestaciones": _detallePrestaciones,
        "detVacaciones": _detalleVacaciones,
        "detUtilidades": _detalleUtilidades,
        "detAyudaFamiliar": _detalleAyudaFamiliar,
        "detBonoAlimenticio": _detalleBonoAlimenticio,
        "detComision": _detalleComision,
        "totalSalarial": _totalSalarial,
        "totalNoSalarial": _totalNoSalarial,
        "montoBrutoUSD": _totalDivisasCalculado,
        "descuentoDeuda": descDeuda,
        "deudaAnterior": _deudaPendiente,
        "montoUSD": _montoNetoDivisas,
        "montoBs": montoBs,
        "tasa": tasaUsada,
        "nuevoSaldoDeuda": nuevoSaldoDeuda,
        "fecha": DateTime.now().toString().substring(0, 19),
        "antiguedad":
            "$_anosTrabajados años, $_mesesTrabajados meses, $_diasTrabajados días",
        "fechaEgreso": fechaEgreso,
        "textoLegal": _textoLegal(),
        "notaLegalBono": _notaLegalBonoAlimenticio(),
      };

      _mostrarDialogoRecibo(context, {
        ...datosRecibo,
        "adicionales": _adicionales,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['mensaje'] ?? "Error al registrar operación"),
            backgroundColor: Colors.red),
      );
    }
  }

  void _mostrarDialogoRecibo(BuildContext context, Map<String, dynamic> datos) {
    final notaLegal = datos['notaLegalBono'] as String?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
                decoration: const BoxDecoration(
                  color: Color(0xFF0F52BA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long, size: 15, color: Colors.white),
                        SizedBox(width: 8),
                        Text("COMPROBANTE",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5)),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pop(context, true);
                      },
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Fecha: ${datos['fecha']}",
                          style:
                              const TextStyle(fontSize: 9, color: Colors.grey)),
                      Text("Operación: ${datos['tipo']}",
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      Text("Trabajador: ${datos['nombre']}",
                          style: const TextStyle(fontSize: 10)),
                      Text("Cédula: V-${datos['cedula']}",
                          style: const TextStyle(fontSize: 10)),
                      if (datos['fechaEgreso'] != null &&
                          datos['fechaEgreso'].toString().isNotEmpty)
                        Text("Fecha de Egreso: ${datos['fechaEgreso']}",
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700)),
                      const Divider(height: 12),
                      if (datos['detSemana'] > 0)
                        _filaDesglose("Sueldo Semanal", datos['detSemana'],
                            Colors.black87),
                      if (datos['detPrestaciones'] > 0)
                        _filaDesglose("Prestaciones", datos['detPrestaciones'],
                            Colors.black87),
                      if (datos['detVacaciones'] > 0)
                        _filaDesglose("Vacaciones + Bono",
                            datos['detVacaciones'], Colors.black87),
                      if (datos['detUtilidades'] > 0)
                        _filaDesglose("Utilidades", datos['detUtilidades'],
                            Colors.black87),
                      const Divider(height: 12),
                      if (datos['detAyudaFamiliar'] > 0)
                        _filaDesglose("Ayuda Familiar",
                            datos['detAyudaFamiliar'], Colors.grey.shade700),
                      if (datos['detBonoAlimenticio'] > 0)
                        _filaDesglose("Bono Alimenticio",
                            datos['detBonoAlimenticio'], Colors.grey.shade700),
                      const Divider(height: 12),
                      if (datos['descuentoDeuda'] > 0) ...[
                        const Divider(height: 12),
                        _filaDesglose("Deuda Anterior", datos['deudaAnterior'],
                            Colors.red.shade700),
                        _filaDesglose("Abono a Deuda", -datos['descuentoDeuda'],
                            Colors.green.shade700),
                        _filaDesglose("Nueva Deuda", datos['nuevoSaldoDeuda'],
                            Colors.red.shade900,
                            negrita: true),
                      ],
                      _filaDesglose("TOTAL USD", datos['montoUSD'], Colors.blue,
                          negrita: true, grande: true),
                      _filaDesglose("TOTAL Bs", datos['montoBs'], Colors.green,
                          negrita: true, grande: true),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(datos['textoLegal'],
                            style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown),
                            textAlign: TextAlign.center),
                      ),
                      if (notaLegal != null && notaLegal.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        Text(notaLegal,
                            style: const TextStyle(
                                fontSize: 8,
                                color: Colors.black54,
                                fontStyle: FontStyle.italic),
                            textAlign: TextAlign.justify),
                      ],
                    ],
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
                            await _imprimirRecibo(datos, true);
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
                            await _imprimirRecibo(datos, false);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            Navigator.pop(context, true);
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

  // ─────────────────────────────────────────────
  // Item del historial de movimientos
  // ─────────────────────────────────────────────
  Widget _buildHistorialItem(dynamic p) {
    final monto = (p['monto'] as num?)?.toDouble() ?? 0.0;
    final tipo = (p['tipo'] ?? p['tipoOperacion'] ?? 'PRÉSTAMO')
        .toString()
        .toUpperCase();
    final fecha = (p['fecha'] ?? '').toString();

    Color color;
    IconData icon;
    String label;
    if (tipo.contains('ABONO') || tipo.contains('PAGO')) {
      color = Colors.green;
      icon = Icons.arrow_downward;
      label = 'ABONO';
    } else if (tipo.contains('NOMINA') || tipo.contains('NÓMINA')) {
      color = Colors.blue;
      icon = Icons.receipt;
      label = 'NÓMINA';
    } else if (tipo.contains('LIQUID')) {
      color = Colors.red;
      icon = Icons.exit_to_app;
      label = 'LIQUIDACIÓN';
    } else if (tipo.contains('ADELANTO')) {
      color = Colors.teal;
      icon = Icons.trending_up;
      label = 'ADELANTO';
    } else {
      color = Colors.orange;
      icon = Icons.account_balance_wallet;
      label = 'PRÉSTAMO';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fecha.length >= 10 ? fecha.substring(0, 10) : fecha,
                  style: const TextStyle(fontSize: 8.5, color: Colors.grey),
                ),
                Text(label,
                    style: TextStyle(
                        fontSize: 7.5,
                        color: color,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text('${_fmt.format(monto)} Bs',
              style:
                  const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color azulHeader = Color(0xFF0F52BA);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 650,
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
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(Icons.badge,
                            size: 15, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "GESTIÓN, NÓMINA Y LIQUIDACIONES",
                        style: TextStyle(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              controller: _cedulaCtrl,
                              keyboardType: TextInputType.text,
                              style: const TextStyle(fontSize: 11),
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _buscarTrabajador(),
                              decoration:
                                  _dec(hint: "Cédula o Nombre del Trabajador"),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: azulHeader,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: _cargando ? null : _buscarTrabajador,
                            child: _cargando
                                ? const SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text("BUSCAR",
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_encontrado)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.blue.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Nombre: $_nombreTrabajador",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.black87)),
                            const SizedBox(height: 3),
                            Text(
                                "Sueldo: \$ ${_fmt.format(_sueldoBase)} | Ayuda: \$ ${_fmt.format(_ayudaFamiliar)}${_bonoAlimenticio > 0 ? ' | Bono: \$ ${_fmt.format(_bonoAlimenticio)}' : ''}",
                                style: const TextStyle(
                                    fontSize: 9.5, color: Colors.blueGrey)),
                            if (_deudaPendiente > 0)
                              Text(
                                  "Deuda: \$ ${_fmt.format(_deudaPendiente)} USD",
                                  style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red)),
                            const Divider(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 32,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _tiposOperacion
                                              .contains(_tipoOperacion)
                                          ? _tipoOperacion
                                          : _tiposOperacion.first,
                                      isExpanded: true,
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.black87),
                                      decoration:
                                          _dec(hint: "Tipo de Operación"),
                                      items: _tiposOperacion
                                          .map((t) => DropdownMenuItem<String>(
                                              value: t,
                                              child: Text(t,
                                                  style: const TextStyle(
                                                      fontSize: 11))))
                                          .toList(),
                                      onChanged: (v) {
                                        if (_trabajadorInactivo &&
                                            v != "Liquidación / Finiquito") {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      "Trabajador INACTIVO. Solo se permite LIQUIDACIÓN / FINIQUITO.",
                                                      style: TextStyle(
                                                          fontSize: 11)),
                                                  backgroundColor: Colors.red));
                                          return;
                                        }
                                        setState(() {
                                          _tipoOperacion = v!;
                                          if (_encontrado) _calcularValores();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 32,
                                    child: TextField(
                                      controller: _tasaEspecialCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                      onChanged: (val) {
                                        final tasa = _parseNum(val);
                                        if (tasa > 0) {
                                          setState(() {
                                            _calcularValores();
                                          });
                                        }
                                      },
                                      decoration: _dec(hint: "Tasa (Bs/\$)"),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (_encontrado &&
                        _tipoOperacion == "Liquidación / Finiquito") ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_busy,
                                size: 16, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            const Text("Fecha de Egreso:",
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _fechaEgresoSeleccionada,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _fechaEgresoSeleccionada = picked;
                                      _calcularValores();
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border:
                                        Border.all(color: Colors.red.shade300),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('dd/MM/yyyy')
                                            .format(_fechaEgresoSeleccionada),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Icon(Icons.calendar_today,
                                          size: 12, color: Colors.red.shade700),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    if (_encontrado)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // COLUMNA IZQUIERDA: FUENTES DE PAGO
                          Expanded(
                            flex: 5,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: Colors.blue.shade200)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.payments,
                                          size: 12, color: Color(0xFF0F52BA)),
                                      const SizedBox(width: 5),
                                      const Expanded(
                                        child: Text("FUENTES DE PAGO",
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F52BA))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: SizedBox(
                                          height: 30,
                                          child:
                                              DropdownButtonFormField<String>(
                                            initialValue: _cuentaFuenteTmp,
                                            isExpanded: true,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black87),
                                            decoration: _dec(hint: "Cuenta"),
                                            items: _cuentasBancos
                                                .map((c) =>
                                                    DropdownMenuItem<String>(
                                                        value: c,
                                                        child: Text(c,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        10))))
                                                .toList(),
                                            onChanged: (v) => setState(
                                                () => _cuentaFuenteTmp = v!),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        flex: 2,
                                        child: SizedBox(
                                          height: 30,
                                          child:
                                              DropdownButtonFormField<String>(
                                            initialValue: _metodoFuenteTmp,
                                            isExpanded: true,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black87),
                                            decoration: _dec(hint: "Método"),
                                            items: const [
                                              DropdownMenuItem(
                                                  value: "EFECTIVO",
                                                  child: Text("Efectivo",
                                                      style: TextStyle(
                                                          fontSize: 10))),
                                              DropdownMenuItem(
                                                  value: "TRANSFERENCIA",
                                                  child: Text("Transf.",
                                                      style: TextStyle(
                                                          fontSize: 10))),
                                              DropdownMenuItem(
                                                  value: "PAGO_MOVIL",
                                                  child: Text("P. Móvil",
                                                      style: TextStyle(
                                                          fontSize: 10))),
                                            ],
                                            onChanged: (v) => setState(
                                                () => _metodoFuenteTmp = v!),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 30,
                                          child: TextField(
                                            controller: _montoFuenteTmpCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold),
                                            decoration: _dec(hint: "Monto"),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        height: 30,
                                        width: 30,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF0F52BA),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6)),
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(30, 30),
                                          ),
                                          onPressed: _agregarFuente,
                                          child:
                                              const Icon(Icons.add, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (_fuentesPago.isNotEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: Colors.grey.shade300)),
                                      child: Column(
                                        children: _fuentesPago
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final idx = entry.key;
                                          final f = entry.value;
                                          final metodo = f['metodo'].toString();
                                          final montoF =
                                              (f['monto'] as num).toDouble();
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 2),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                      "${f['cuenta']} · ${metodo.replaceAll('_', ' ')}",
                                                      style: const TextStyle(
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                ),
                                                Text(
                                                    "${_fmt.format(montoF)} Bs",
                                                    style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF0F52BA))),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.delete_outline,
                                                      size: 12,
                                                      color: Colors.red),
                                                  onPressed: () =>
                                                      _quitarFuente(idx),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 20,
                                                          minHeight: 20),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  const Divider(height: 10),
                                  Builder(
                                    builder: (context) {
                                      final tasaActual = _tasaActual();
                                      final netoBs =
                                          _r2(_montoNetoDivisas * tasaActual);
                                      final restante =
                                          _r2(netoBs - _totalFuentesBs());

                                      return Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text("Neto a pagar:",
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      color: Colors.black54)),
                                              Text("${_fmt.format(netoBs)} Bs",
                                                  style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          ),
                                          if (_comisionFuentesBs() > 0)
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text("Comisiones:",
                                                    style: TextStyle(
                                                        fontSize: 9,
                                                        color: Colors.orange)),
                                                Text(
                                                    "+${_fmt.format(_comisionFuentesBs())} Bs",
                                                    style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.orange)),
                                              ],
                                            ),
                                          const Divider(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                restante > 0.01
                                                    ? "FALTA POR ASIGNAR:"
                                                    : "TOTAL ASIGNADO:",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: restante > 0.01
                                                      ? Colors.red
                                                      : Colors.green.shade700,
                                                ),
                                              ),
                                              Text(
                                                "${_fmt.format(restante.abs())} Bs",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: restante > 0.01
                                                      ? Colors.red
                                                      : Colors.green.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // COLUMNA DERECHA: DEUDA, HISTORIAL Y ADICIONALES
                          Expanded(
                            flex: 4,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_historialPrestamos.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.history,
                                            size: 12,
                                            color: Colors.orange.shade900),
                                        const SizedBox(width: 4),
                                        const Expanded(
                                          child: Text("HISTORIAL MOVIMIENTOS",
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange)),
                                        ),
                                        Text(
                                            "Deuda: \$${_deudaPendiente.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      constraints:
                                          const BoxConstraints(maxHeight: 80),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: _historialPrestamos.length,
                                        itemBuilder: (context, index) =>
                                            _buildHistorialItem(
                                                _historialPrestamos[index]),
                                      ),
                                    ),
                                    const Divider(height: 12),
                                  ],
                                  if (_deudaPendiente > 0) ...[
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: Checkbox(
                                            value: _aplicarDescuentoDeuda,
                                            onChanged: (v) {
                                              setState(() {
                                                _aplicarDescuentoDeuda =
                                                    v ?? false;
                                                _calcularValores();
                                              });
                                            },
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Expanded(
                                            child: Text("Descontar Préstamo",
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red))),
                                      ],
                                    ),
                                    if (_aplicarDescuentoDeuda)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 4, bottom: 4),
                                        child: Row(
                                          children: [
                                            Container(
                                              height: 28,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color:
                                                        Colors.grey.shade300),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: DropdownButton<String>(
                                                value: _monedaDescuento,
                                                isDense: true,
                                                underline: const SizedBox(),
                                                style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87),
                                                items: const [
                                                  DropdownMenuItem(
                                                      value: "USD",
                                                      child: Text("USD")),
                                                  DropdownMenuItem(
                                                      value: "Bs",
                                                      child: Text("Bs")),
                                                ],
                                                onChanged: (v) {
                                                  setState(() {
                                                    _monedaDescuento =
                                                        v ?? "USD";
                                                    _calcularValores();
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: SizedBox(
                                                height: 28,
                                                child: TextField(
                                                  controller:
                                                      _descuentoDeudaCtrl,
                                                  keyboardType:
                                                      const TextInputType
                                                          .numberWithOptions(
                                                          decimal: true),
                                                  style: const TextStyle(
                                                      fontSize: 10),
                                                  onChanged: (_) =>
                                                      _calcularValores(),
                                                  decoration: _dec(
                                                      hint: _monedaDescuento ==
                                                              "USD"
                                                          ? "Monto a Descontar (\$)"
                                                          : "Monto a Descontar (Bs)"),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (_aplicarDescuentoDeuda)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 2, bottom: 2),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("Descuento en USD:",
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.black54)),
                                            Text(
                                                "\$${_descDeudaUsd().toStringAsFixed(2)}",
                                                style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green)),
                                          ],
                                        ),
                                      ),
                                    const Divider(height: 12),
                                  ],
                                  Row(
                                    children: [
                                      Icon(Icons.add_circle_outline,
                                          size: 12,
                                          color: Colors.teal.shade800),
                                      const SizedBox(width: 4),
                                      const Expanded(
                                          child: Text("PAGOS ADICIONALES",
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal))),
                                      InkWell(
                                          onTap: _agregarAdicional,
                                          child: const Icon(Icons.add,
                                              size: 14, color: Colors.teal)),
                                    ],
                                  ),
                                  ..._adicionales.asMap().entries.map((e) {
                                    final idx = e.key;
                                    final ad = e.value;
                                    return _AdicionalRowWidget(
                                      key: ValueKey(ad['id'] ??
                                          'adic_${idx}_${ad.hashCode}'),
                                      data: ad,
                                      categorias: _categoriasAdicional,
                                      onMontoChanged: (v) {
                                        setState(() {
                                          ad['monto'] = v;
                                          _recalcularAdicionales();
                                          _calcularValores();
                                        });
                                      },
                                      onCategoriaChanged: (v) {
                                        setState(() => ad['categoria'] = v);
                                      },
                                      onDelete: () => _quitarAdicional(idx),
                                    );
                                  }),
                                  if (_adicionales.isNotEmpty) ...[
                                    const Divider(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Total adicional:",
                                            style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                            "\$ ${_fmt.format(_totalAdicionalesUSD)}",
                                            style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
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
                    backgroundColor: azulHeader,
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
                      : Icon(
                          _tipoOperacion == "Liquidación / Finiquito"
                              ? Icons.exit_to_app
                              : Icons.receipt_long,
                          size: 15),
                  label: Text(
                    _procesando
                        ? "REGISTRANDO..."
                        : (_tipoOperacion == "Liquidación / Finiquito"
                            ? "REGISTRAR LIQUIDACIÓN"
                            : "REGISTRAR Y GENERAR RECIBO"),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed:
                      _procesando || !_encontrado ? null : _procesarOperacion,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widget del adicional (Stateful, con controller propio)
// ─────────────────────────────────────────────
class _AdicionalRowWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<String> categorias;
  final ValueChanged<double> onMontoChanged;
  final ValueChanged<String> onCategoriaChanged;
  final VoidCallback onDelete;

  const _AdicionalRowWidget({
    super.key,
    required this.data,
    required this.categorias,
    required this.onMontoChanged,
    required this.onCategoriaChanged,
    required this.onDelete,
  });

  @override
  State<_AdicionalRowWidget> createState() => _AdicionalRowWidgetState();
}

class _AdicionalRowWidgetState extends State<_AdicionalRowWidget> {
  late final TextEditingController _montoCtrl;

  @override
  void initState() {
    super.initState();
    final m = (widget.data['monto'] as num?)?.toDouble() ?? 0.0;
    _montoCtrl = TextEditingController(text: m > 0 ? m.toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec({String? hint, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11),
      suffixText: suffix,
      suffixStyle: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF0F52BA)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF0F52BA), width: 2),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 26,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        widget.data['categoria']?.toString() ?? 'Transporte',
                    style: const TextStyle(fontSize: 9, color: Colors.black87),
                    isDense: true,
                    decoration: _dec(hint: ""),
                    items: widget.categorias
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child:
                                  Text(c, style: const TextStyle(fontSize: 9)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        widget.onCategoriaChanged(v);
                        setState(() {});
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 2),
              SizedBox(
                height: 26,
                width: 26,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 12, color: Colors.red),
                  padding: EdgeInsets.zero,
                  onPressed: widget.onDelete,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 26,
            child: TextField(
              controller: _montoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              onChanged: (v) {
                final parsed = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                widget.onMontoChanged(parsed);
              },
              decoration: _dec(hint: "\$", suffix: "USD"),
            ),
          ),
        ],
      ),
    );
  }
}
