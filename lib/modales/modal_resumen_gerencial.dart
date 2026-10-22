import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../servicios/api_service.dart';

class ModalResumenGerencial extends StatefulWidget {
  final double tasaUSD;
  final double tasaUSDT;

  const ModalResumenGerencial({
    super.key,
    required this.tasaUSD,
    required this.tasaUSDT,
  });

  @override
  State<ModalResumenGerencial> createState() => _ModalResumenGerencialState();
}

class _ModalResumenGerencialState extends State<ModalResumenGerencial> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 2);

  DateTime _fecha = DateTime.now();
  bool _cargando = true;

  Map<String, dynamic> _ventas = {
    "pos": 0.0,
    "pm": 0.0,
    "efectivo": 0.0,
    "divisas": 0.0
  };
  List<dynamic> _saldos = [];
  Map<String, dynamic> _resumen = {
    "ingresos": 0.0,
    "egresos": 0.0,
    "comisiones": 0.0,
    "ganancia": 0.0,
    "margen": 0.0
  };
  List<dynamic> _categorias = [];

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      final fechaStr = DateFormat('yyyy-MM-dd').format(_fecha);
      final res = await ApiService.obtenerResumenGerencial(fechaStr);

      if (!mounted) return;

      if (res['status'] == "SUCCESS") {
        setState(() {
          _ventas = Map<String, dynamic>.from(res['ventas'] ?? _ventas);
          _saldos = List.from(res['saldos'] ?? []);
          _resumen = Map<String, dynamic>.from(res['resumen'] ?? _resumen);
          _categorias = List.from(res['categorias'] ?? []);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _fecha) {
      setState(() => _fecha = picked);
      _cargarTodo();
    }
  }

  double _d(String key) => (_resumen[key] as num?)?.toDouble() ?? 0.0;
  double _v(String key) => (_ventas[key] as num?)?.toDouble() ?? 0.0;

  double _totalVentasBs() {
    return _v('pos') +
        _v('pm') +
        _v('efectivo') +
        (_v('divisas') * widget.tasaUSD);
  }

  Future<void> _generarPDF() async {
    final doc = pw.Document();

    final colorAzul = PdfColor.fromHex('#0F52BA');
    final colorHeader = PdfColor.fromHex('#E3F2FD');
    final colorTitulos = PdfColor.fromHex('#455A64');
    final colorFilaPar = PdfColor.fromHex('#F5F7FA');
    final colorRojo = PdfColor.fromHex('#C62828');
    final colorVerde = PdfColor.fromHex('#2E7D32');
    final colorGris = PdfColor.fromHex('#757575');

    final ingresos = _d('ingresos');
    final egresos = _d('egresos');
    final comisiones = _d('comisiones');
    final ganancia = _d('ganancia');
    final margen = _d('margen');
    final tasa = widget.tasaUSD > 0 ? widget.tasaUSD : 1;

    final fechaStr = DateFormat('dd/MM/yyyy').format(_fecha);
    final totalCat = _categorias.fold<double>(
        0, (a, b) => a + ((b['monto'] as num?)?.toDouble() ?? 0));

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: colorHeader,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("CONTROL Y GESTIÓN",
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: colorAzul)),
                  pw.SizedBox(height: 2),
                  pw.Text("Resumen Gerencial",
                      style: pw.TextStyle(fontSize: 11, color: colorTitulos)),
                  pw.SizedBox(height: 4),
                  pw.Text("Día: $fechaStr",
                      style: pw.TextStyle(fontSize: 9, color: colorGris)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Ventas
            pw.Text("VENTAS DEL DÍA",
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: colorTitulos,
                    letterSpacing: 0.5)),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F5F7FA'),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: [
                  _filaTotalPDF(
                      "POS", "${_fmt.format(_v('pos'))} Bs", colorTitulos),
                  _filaTotalPDF("Pago Móvil", "${_fmt.format(_v('pm'))} Bs",
                      colorTitulos),
                  _filaTotalPDF("Efectivo Bs",
                      "${_fmt.format(_v('efectivo'))} Bs", colorTitulos),
                  _filaTotalPDF("Divisas", "${_fmt.format(_v('divisas'))} \$",
                      colorTitulos),
                  pw.Divider(height: 8, thickness: 0.5),
                  _filaTotalPDF(
                      "TOTAL VENTAS",
                      "${_fmt.format(_totalVentasBs())} Bs  ≈  \$ ${(_totalVentasBs() / tasa).toStringAsFixed(2)}",
                      colorAzul,
                      bold: true),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Resumen financiero
            pw.Text("RESUMEN FINANCIERO",
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: colorTitulos,
                    letterSpacing: 0.5)),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F5F7FA'),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: [
                  _filaTotalPDF(
                      "Ingresos", "+${_fmt.format(ingresos)} Bs", colorVerde),
                  _filaTotalPDF(
                      "Egresos", "−${_fmt.format(egresos)} Bs", colorRojo),
                  _filaTotalPDF("Comisiones bancarias",
                      "−${_fmt.format(comisiones)} Bs", colorRojo),
                  pw.Divider(height: 8, thickness: 0.5),
                  _filaTotalPDF(
                      "GANANCIA NETA",
                      "${_fmt.format(ganancia)} Bs  ≈  \$ ${(ganancia / tasa).toStringAsFixed(2)}",
                      ganancia >= 0 ? colorVerde : colorRojo,
                      bold: true),
                  _filaTotalPDF("MARGEN", "${margen.toStringAsFixed(1)} %",
                      ganancia >= 0 ? colorVerde : colorRojo),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Saldos por cuenta
            pw.Text("SALDO POR CUENTA",
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: colorTitulos,
                    letterSpacing: 0.5)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#E0E0E0'), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: colorHeader),
                  children: [
                    _celdaHeaderPDF("Cuenta"),
                    _celdaHeaderPDF("Inicio", align: pw.TextAlign.right),
                    _celdaHeaderPDF("Ingresos", align: pw.TextAlign.right),
                    _celdaHeaderPDF("Egresos", align: pw.TextAlign.right),
                    _celdaHeaderPDF("Final", align: pw.TextAlign.right),
                  ],
                ),
                ..._saldos.asMap().entries.map((e) {
                  final i = e.key;
                  final s = e.value;
                  final bg = i % 2 == 0 ? null : colorFilaPar;
                  return pw.TableRow(
                    decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
                    children: [
                      _celdaPDF(s['cuenta']?.toString() ?? '', bold: true),
                      _celdaPDF(
                          _fmt.format((s['inicio'] as num?)?.toDouble() ?? 0),
                          align: pw.TextAlign.right),
                      _celdaPDF(
                          _fmt.format((s['ingresos'] as num?)?.toDouble() ?? 0),
                          align: pw.TextAlign.right,
                          color: colorVerde),
                      _celdaPDF(
                          _fmt.format((s['egresos'] as num?)?.toDouble() ?? 0),
                          align: pw.TextAlign.right,
                          color: colorRojo),
                      _celdaPDF(
                          _fmt.format((s['final'] as num?)?.toDouble() ?? 0),
                          align: pw.TextAlign.right,
                          bold: true,
                          color: colorAzul),
                    ],
                  );
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 16),

            // Categorías
            pw.Text("EGRESOS POR CATEGORÍA",
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: colorTitulos,
                    letterSpacing: 0.5)),
            pw.SizedBox(height: 6),
            if (_categorias.isEmpty)
              pw.Text("Sin egresos.",
                  style: pw.TextStyle(fontSize: 10, color: colorGris))
            else
              ..._categorias.map((c) {
                final nombre = c['nombre']?.toString() ?? '';
                final monto = (c['monto'] as num?)?.toDouble() ?? 0;
                final pct = totalCat > 0 ? (monto / totalCat) : 0.0;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    children: [
                      pw.SizedBox(
                        width: 130,
                        child: pw.Text(nombre,
                            style: pw.TextStyle(
                                fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Expanded(
                        child: pw.Row(
                          children: [
                            if (pct > 0.005)
                              pw.Expanded(
                                flex: (pct * 100).round().clamp(1, 100),
                                child: pw.Container(
                                  height: 8,
                                  decoration: pw.BoxDecoration(
                                    color: colorRojo,
                                    borderRadius: pw.BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            if (pct < 0.995)
                              pw.Expanded(
                                flex: ((1 - pct) * 100).round().clamp(1, 100),
                                child: pw.Container(
                                  height: 8,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColor.fromHex('#E0E0E0'),
                                    borderRadius: pw.BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.SizedBox(
                        width: 90,
                        child: pw.Text("${_fmt.format(monto)} Bs",
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.SizedBox(width: 8),
                      pw.SizedBox(
                        width: 45,
                        child: pw.Text("${(pct * 100).toStringAsFixed(0)}%",
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(fontSize: 9, color: colorGris)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            pw.SizedBox(height: 16),

            // Pendientes
            pw.Text("PENDIENTES",
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: colorTitulos,
                    letterSpacing: 0.5)),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FAFAFA'),
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
              ),
              child: pw.Column(
                children: [
                  _filaTotalPDF("Por pagar a proveedores", "—", colorGris),
                  _filaTotalPDF("Por cobrar", "—", colorGris),
                ],
              ),
            ),
          ],
        );
      },
    ));

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save());
  }

  pw.Widget _filaTotalPDF(String label, String valor, PdfColor color,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
          pw.Text(valor,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  pw.Widget _celdaHeaderPDF(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#455A64')),
          textAlign: align),
    );
  }

  pw.Widget _celdaPDF(String text,
      {bool bold = false,
      pw.TextAlign align = pw.TextAlign.left,
      PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color),
          textAlign: align),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color azulHeader = Color(0xFF0F52BA);
    final fechaStr = DateFormat('dd/MM/yyyy').format(_fecha);
    final totalVentasBs = _totalVentasBs();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 780,
        constraints: const BoxConstraints(maxHeight: 720),
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
                        child: const Icon(Icons.assessment,
                            size: 15, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Text("RESUMEN GERENCIAL",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5)),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: azulHeader,
                          minimumSize: const Size(100, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        icon: const Icon(Icons.picture_as_pdf, size: 13),
                        label: const Text("PDF",
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                        onPressed: _cargando ? null : _generarPDF,
                      ),
                      const SizedBox(width: 6),
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

            // FECHA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: azulHeader),
                  const SizedBox(width: 8),
                  const Text("Día:",
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Text(fechaStr,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: azulHeader)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _seleccionarFecha,
                    icon: const Icon(Icons.edit, size: 12),
                    label:
                        const Text("Cambiar", style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),

            // CONTENIDO
            Flexible(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // VENTAS
                          _buildSeccion(
                            titulo: "VENTAS DEL DÍA",
                            color: Colors.indigo.shade700,
                            icono: Icons.shopping_cart,
                            child: Column(
                              children: [
                                _buildFila("POS", _v('pos'), "Bs",
                                    Colors.indigo.shade700),
                                _buildFila("Pago Móvil", _v('pm'), "Bs",
                                    Colors.indigo.shade700),
                                _buildFila("Efectivo Bs", _v('efectivo'), "Bs",
                                    Colors.indigo.shade700),
                                _buildFila("Divisas", _v('divisas'), "\$",
                                    Colors.green.shade700),
                                const Divider(height: 10),
                                _buildFila("TOTAL VENTAS", totalVentasBs, "Bs",
                                    azulHeader,
                                    bold: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // RESUMEN FINANCIERO
                          _buildSeccion(
                            titulo: "RESUMEN FINANCIERO",
                            color: Colors.green.shade700,
                            icono: Icons.trending_up,
                            child: Column(
                              children: [
                                _buildFila("Ingresos", _d('ingresos'), "Bs",
                                    Colors.green.shade700),
                                _buildFila("Egresos", _d('egresos'), "Bs",
                                    Colors.red.shade700),
                                _buildFila(
                                    "Comisiones bancarias",
                                    _d('comisiones'),
                                    "Bs",
                                    Colors.red.shade700),
                                const Divider(height: 10),
                                _buildFila(
                                    "GANANCIA NETA",
                                    _d('ganancia'),
                                    "Bs",
                                    _d('ganancia') >= 0
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                    bold: true),
                                _buildFila(
                                    "Margen",
                                    _d('margen'),
                                    "%",
                                    _d('margen') >= 0
                                        ? Colors.green.shade800
                                        : Colors.red.shade800),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // SALDOS
                          _buildSeccion(
                            titulo: "SALDO POR CUENTA",
                            color: azulHeader,
                            icono: Icons.account_balance,
                            child: _saldos.isEmpty
                                ? const Text("Sin cuentas.",
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey))
                                : Column(
                                    children: _saldos.map((s) {
                                      final cuenta =
                                          s['cuenta']?.toString() ?? '';
                                      final inicio =
                                          (s['inicio'] as num?)?.toDouble() ??
                                              0;
                                      final ingresos =
                                          (s['ingresos'] as num?)?.toDouble() ??
                                              0;
                                      final egresos =
                                          (s['egresos'] as num?)?.toDouble() ??
                                              0;
                                      final fin =
                                          (s['final'] as num?)?.toDouble() ?? 0;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 3),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 110,
                                              child: Text(cuenta,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            Expanded(
                                              child: Text(_fmt.format(inicio),
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey)),
                                            ),
                                            Expanded(
                                              child: Text(
                                                  "+${_fmt.format(ingresos)}",
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors
                                                          .green.shade700)),
                                            ),
                                            Expanded(
                                              child: Text(
                                                  "−${_fmt.format(egresos)}",
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          Colors.red.shade700)),
                                            ),
                                            Expanded(
                                              child: Text(_fmt.format(fin),
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: azulHeader)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                          const SizedBox(height: 10),

                          // CATEGORÍAS
                          _buildSeccion(
                            titulo: "EGRESOS POR CATEGORÍA",
                            color: Colors.deepPurple.shade700,
                            icono: Icons.pie_chart,
                            child: _categorias.isEmpty
                                ? const Text("Sin egresos.",
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey))
                                : Column(
                                    children: _categorias.map((c) {
                                      final nombre =
                                          c['nombre']?.toString() ?? '';
                                      final monto =
                                          (c['monto'] as num?)?.toDouble() ?? 0;
                                      final total = _categorias.fold<double>(
                                          0,
                                          (a, b) =>
                                              a +
                                              ((b['monto'] as num?)
                                                      ?.toDouble() ??
                                                  0));
                                      final pct =
                                          total > 0 ? monto / total : 0.0;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 110,
                                              child: Text(nombre,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.deepPurple
                                                          .shade700)),
                                            ),
                                            Expanded(
                                              child: Container(
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: FractionallySizedBox(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  widthFactor:
                                                      pct.clamp(0.0, 1.0),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors
                                                          .deepPurple.shade400,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 90,
                                              child: Text(
                                                  "${_fmt.format(monto)} Bs",
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 6),
                                            SizedBox(
                                              width: 42,
                                              child: Text(
                                                  "${(pct * 100).toStringAsFixed(0)}%",
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                          const SizedBox(height: 10),

                          // PENDIENTES
                          _buildSeccion(
                            titulo: "PENDIENTES",
                            color: Colors.grey.shade700,
                            icono: Icons.hourglass_empty,
                            child: Column(
                              children: [
                                _buildFilaTexto("Por pagar a proveedores", "—"),
                                _buildFilaTexto("Por cobrar", "—"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccion({
    required String titulo,
    required Color color,
    required IconData icono,
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
                child: Icon(icono, size: 12, color: color),
              ),
              const SizedBox(width: 6),
              Text(titulo,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildFila(String label, double monto, String moneda, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 11 : 10.5,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
              moneda == "%"
                  ? "${monto.toStringAsFixed(1)} %"
                  : "${_fmt.format(monto)} $moneda",
              style: TextStyle(
                  fontSize: bold ? 12 : 10.5,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildFilaTexto(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5)),
          Text(valor,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
        ],
      ),
    );
  }
}
