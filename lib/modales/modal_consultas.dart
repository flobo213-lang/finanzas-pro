import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../servicios/api_service.dart';

class ModalConsultas extends StatefulWidget {
  final double tasaUSD;
  const ModalConsultas({super.key, required this.tasaUSD});

  @override
  State<ModalConsultas> createState() => _ModalConsultasState();
}

class _ModalConsultasState extends State<ModalConsultas> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 2);

  // Vista: 'RESUMEN' | 'CATEGORIAS' | 'MOVIMIENTOS' | 'DASHBOARD'
  String _vista = 'RESUMEN';

  // Rango
  String _rango = 'DIA';
  DateTime _fechaBase = DateTime.now();

  bool _cargando = true;

  // Datos
  Map<String, dynamic>? _estadisticas;
  Map<String, dynamic>? _movimientos;
  Map<String, dynamic>? _dashboard;
  List<dynamic> _cierres = [];
  String? _cierreExpandido;
  Map<String, dynamic>? _detalleCierre;
  Map<String, dynamic>? _conciliacion;
  bool _cargandoDetalleCierre = false;

  // Categoría seleccionada para detalle
  String? _categoriaDetalle;
  List<dynamic> _detalleCategoria = [];
  bool _cargandoDetalle = false;

  bool get _esMovil => MediaQuery.of(context).size.width < 700;

  double _usd(double bs) {
    if (widget.tasaUSD <= 0) return bs;
    return bs / widget.tasaUSD;
  }

  String _fmtUsd(double bs) => _fmt.format(_usd(bs));

  DateTime _inicioRango() {
    switch (_rango) {
      case 'DIA':
        return DateTime(_fechaBase.year, _fechaBase.month, _fechaBase.day);
      case 'SEMANA':
        final lunes =
            _fechaBase.subtract(Duration(days: _fechaBase.weekday - 1));
        return DateTime(lunes.year, lunes.month, lunes.day);
      case 'MES':
        return DateTime(_fechaBase.year, _fechaBase.month, 1);
      case 'TRIMESTRE':
        final trimestre = ((_fechaBase.month - 1) ~/ 3);
        return DateTime(_fechaBase.year, trimestre * 3 + 1, 1);
      case 'SEMESTRE':
        final mes = _fechaBase.month <= 6 ? 1 : 7;
        return DateTime(_fechaBase.year, mes, 1);
      case 'AÑO':
        return DateTime(_fechaBase.year, 1, 1);
      default:
        return _fechaBase;
    }
  }

  DateTime _finRango() {
    return DateTime(_fechaBase.year, _fechaBase.month, _fechaBase.day);
  }

  String _rangoStr() {
    final f = DateFormat('dd/MM/yyyy');
    final a = _inicioRango();
    final b = _finRango();
    if (a.year == b.year && a.month == b.month && a.day == b.day) {
      return f.format(a);
    }
    return "${f.format(a)}  →  ${f.format(b)}";
  }

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      final desde = DateFormat('yyyy-MM-dd').format(_inicioRango());
      final hasta = DateFormat('yyyy-MM-dd').format(_finRango());

      final resEst = await ApiService.registrarAccionConRespuesta(
        "obtenerEstadisticas",
        {"fechaDesde": desde, "fechaHasta": hasta},
      );
      print("=== RESPUESTA ESTADISTICAS ===");
      print(resEst);
      if (!mounted) return;
      setState(() => _estadisticas = resEst);

      if (_vista == 'MOVIMIENTOS') {
        final resMov =
            await ApiService.obtenerConsultasConFecha(desde, fechaHasta: hasta);
        if (!mounted) return;
        setState(() => _movimientos = resMov);
      }
      if (_vista == 'CONCILIACION') {
        final resConc = await ApiService.registrarAccionConRespuesta(
          "obtenerConciliacionPorCuenta",
          {"fechaDesde": desde, "fechaHasta": hasta},
        );
        if (!mounted) return;
        setState(() => _conciliacion = resConc);
      }

      if (_vista == 'CIERRES') {
        final resCierres = await ApiService.registrarAccionConRespuesta(
          "obtenerCierresDelRango",
          {"fechaDesde": desde, "fechaHasta": hasta},
        );
        if (!mounted) return;
        setState(() {
          _cierres = List<dynamic>.from(resCierres['cierres'] ?? []);
          _cierreExpandido = null;
          _detalleCierre = null;
        });
      }
    } catch (e, stackTrace) {
      print("❌ ERROR EN _cargarTodo: $e");
      print(stackTrace);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarDetalleCategoria(String cat) async {
    setState(() {
      _categoriaDetalle = cat;
      _cargandoDetalle = true;
      _detalleCategoria = [];
    });
    try {
      final desde = DateFormat('yyyy-MM-dd').format(_inicioRango());
      final hasta = DateFormat('yyyy-MM-dd').format(_finRango());
      final res = await ApiService.registrarAccionConRespuesta(
        "obtenerDetallePorCategoria",
        {"fechaDesde": desde, "fechaHasta": hasta, "categoria": cat},
      );
      if (!mounted) return;
      setState(() {
        _detalleCategoria = List<dynamic>.from(res['movimientos'] ?? []);
        _cargandoDetalle = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoDetalle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: _esMovil ? MediaQuery.of(context).size.width * 0.98 : 920,
        height: _esMovil ? MediaQuery.of(context).size.height * 0.95 : 700,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildToggleVista(),
            _buildRangoBar(),
            Expanded(child: _buildContenido()),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    return Container(
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
        children: [
          const Icon(Icons.menu_book, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          const Text(
            "CONSULTAS Y ESTADÍSTICAS",
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 28),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.picture_as_pdf, size: 12),
            label: const Text("PDF",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            onPressed: _cargando ? null : _imprimirPDF,
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
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOGGLE VISTA
  // ============================================================
  Widget _buildToggleVista() {
    final vistas = [
      {'key': 'RESUMEN', 'label': 'RESUMEN', 'icon': Icons.assessment},
      {'key': 'CATEGORIAS', 'label': 'CATEGORÍAS', 'icon': Icons.pie_chart},
      {'key': 'MOVIMIENTOS', 'label': 'MOVIMIENTOS', 'icon': Icons.list_alt},
      {'key': 'CIERRES', 'label': 'CIERRES', 'icon': Icons.point_of_sale},
      {
        'key': 'CONCILIACION',
        'label': 'CONCILIACIÓN',
        'icon': Icons.account_balance_wallet
      },
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      color: Colors.grey.shade100,
      child: Row(
        children: vistas.map((v) {
          final activo = _vista == v['key'];
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _vista = v['key'] as String);
                _cargarTodo();
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: activo ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: activo
                      ? [
                          const BoxShadow(
                              color: Colors.black12,
                              blurRadius: 2,
                              offset: Offset(0, 1))
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(v['icon'] as IconData,
                        size: 12,
                        color: activo ? const Color(0xFF0F52BA) : Colors.grey),
                    const SizedBox(width: 4),
                    Text(v['label'] as String,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: activo
                                ? const Color(0xFF0F52BA)
                                : Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // BARRA RANGOS
  // ============================================================
  Widget _buildRangoBar() {
    final rangos = ['DIA', 'SEMANA', 'MES', 'TRIMESTRE', 'SEMESTRE', 'AÑO'];
    final labels = {
      'DIA': 'Hoy',
      'SEMANA': 'Semana',
      'MES': 'Mes',
      'TRIMESTRE': 'Trim.',
      'SEMESTRE': 'Sem.',
      'AÑO': 'Año',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          ...rangos.map((r) {
            final activo = _rango == r;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () {
                    setState(() => _rango = r);
                    _cargarTodo();
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: activo ? const Color(0xFF0F52BA) : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: activo
                              ? const Color(0xFF0F52BA)
                              : Colors.grey.shade300),
                    ),
                    child: Text(labels[r]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: activo ? Colors.white : Colors.black87)),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          InkWell(
            onTap: _seleccionarFecha,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 11, color: Color(0xFF0F52BA)),
                  const SizedBox(width: 4),
                  Text(
                    _rangoStr(),
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaBase,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _fechaBase = picked);
      _cargarTodo();
    }
  }

  // ============================================================
  // CONTENIDO
  // ============================================================
  Widget _buildContenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_vista) {
      case 'RESUMEN':
        return _buildVistaResumen();
      case 'CATEGORIAS':
        return _buildVistaCategorias();
      case 'MOVIMIENTOS':
        return _buildVistaMovimientos();
      case 'CIERRES':
        return _buildVistaCierres();
      case 'CONCILIACION':
        return _buildVistaConciliacion();
      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // VISTA 1 — RESUMEN
  // ============================================================
  Widget _buildVistaResumen() {
    if (_estadisticas == null || _estadisticas!['status'] != 'SUCCESS') {
      return const Center(
        child: Text("No se pudieron cargar las estadísticas.",
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }

    final act = _estadisticas!['actual'] as Map? ?? {};
    final ant = _estadisticas!['anterior'] as Map? ?? {};
    final var_ = _estadisticas!['variaciones'] as Map? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBloque('VENTAS', [
            _filaComp(
                'Ventas brutas',
                (act['ventas'] as num?)?.toDouble() ?? 0,
                (ant['ventas'] as num?)?.toDouble() ?? 0,
                (var_['ventas'] as num?)?.toDouble() ?? 0,
                Colors.green.shade800),
            _filaComp(
                'Comisiones',
                (act['comisiones'] as num?)?.toDouble() ?? 0,
                (ant['comisiones'] as num?)?.toDouble() ?? 0,
                (var_['comisiones'] as num?)?.toDouble() ?? 0,
                Colors.orange.shade800),
            _filaComp(
                'Ventas netas',
                (act['ventasNetas'] as num?)?.toDouble() ?? 0,
                (ant['ventasNetas'] as num?)?.toDouble() ?? 0,
                0,
                Colors.black87,
                bold: true),
          ]),
          const SizedBox(height: 10),
          _buildBloque('EGRESOS', [
            _filaComp(
                'Proveedores',
                (act['proveedores'] as num?)?.toDouble() ?? 0,
                (ant['proveedores'] as num?)?.toDouble() ?? 0,
                (var_['proveedores'] as num?)?.toDouble() ?? 0,
                Colors.orange.shade800),
            _filaComp(
                'Personal',
                (act['personal'] as num?)?.toDouble() ?? 0,
                (ant['personal'] as num?)?.toDouble() ?? 0,
                (var_['personal'] as num?)?.toDouble() ?? 0,
                Colors.red.shade700),
            _filaComp(
                'Nómina',
                (act['nomina'] as num?)?.toDouble() ?? 0,
                (ant['nomina'] as num?)?.toDouble() ?? 0,
                (var_['nomina'] as num?)?.toDouble() ?? 0,
                Colors.red.shade700),
            _filaComp(
                'Servicios',
                (act['servicios'] as num?)?.toDouble() ?? 0,
                (ant['servicios'] as num?)?.toDouble() ?? 0,
                (var_['servicios'] as num?)?.toDouble() ?? 0,
                Colors.blue.shade700),
            _filaComp(
                'Otros',
                (act['otros'] as num?)?.toDouble() ?? 0,
                (ant['otros'] as num?)?.toDouble() ?? 0,
                0,
                Colors.grey.shade700),
            const Divider(height: 10),
            _filaComp(
                'Total egresos',
                (act['totalEgresos'] as num?)?.toDouble() ?? 0,
                (ant['totalEgresos'] as num?)?.toDouble() ?? 0,
                (var_['egresos'] as num?)?.toDouble() ?? 0,
                Colors.red.shade900,
                bold: true),
          ]),
          const SizedBox(height: 10),
          _buildBloque('RESULTADO', [
            _filaComp(
                'Ganancia',
                (act['ganancia'] as num?)?.toDouble() ?? 0,
                (ant['ganancia'] as num?)?.toDouble() ?? 0,
                (var_['ganancia'] as num?)?.toDouble() ?? 0,
                ((act['ganancia'] as num?)?.toDouble() ?? 0) >= 0
                    ? Colors.green.shade800
                    : Colors.red.shade800,
                bold: true),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Margen',
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.bold)),
                  Text(
                      '${(act['margen'] as num?)?.toStringAsFixed(1) ?? "0"} %',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: ((act['margen'] as num?)?.toDouble() ?? 0) >= 0
                              ? Colors.green.shade800
                              : Colors.red.shade800)),
                ],
              ),
            ),
            _filaComp(
                'Movimientos',
                (act['movimientos'] as num?)?.toDouble() ?? 0,
                (ant['movimientos'] as num?)?.toDouble() ?? 0,
                0,
                Colors.grey.shade700),
          ]),
        ],
      ),
    );
  }

  Widget _buildBloque(String titulo, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _filaComp(
      String label, double monto, double montoAnt, double pct, Color color,
      {bool bold = false}) {
    final pctEsPositivo = pct >= 0;
    final colorPct =
        pctEsPositivo ? Colors.green.shade700 : Colors.red.shade700;
    final iconoPct = pctEsPositivo ? Icons.arrow_upward : Icons.arrow_downward;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: TextStyle(
                    fontSize: bold ? 11 : 10.5,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_fmt.format(monto)} Bs',
                    style: TextStyle(
                        fontSize: bold ? 11.5 : 10.5,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text('≈ \$ ${_fmtUsd(monto)}',
                    style: TextStyle(
                        fontSize: 8.5,
                        color: color.withValues(alpha: 0.7),
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: montoAnt > 0 || monto > 0
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(iconoPct, size: 10, color: colorPct),
                      Text('${pct.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: colorPct)),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VISTA 2 — CATEGORÍAS
  // ============================================================
  Widget _buildVistaCategorias() {
    if (_estadisticas == null || _estadisticas!['status'] != 'SUCCESS') {
      return const Center(
        child: Text("No se pudieron cargar las categorías.",
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }

    final act = _estadisticas!['actual'] as Map? ?? {};
    final categorias = [
      {
        'key': 'PROVEEDORES',
        'label': 'Proveedores',
        'icon': Icons.store,
        'color': Colors.orange.shade800
      },
      {
        'key': 'PERSONAL',
        'label': 'Personal',
        'icon': Icons.person,
        'color': Colors.red.shade700
      },
      {
        'key': 'NOMINA',
        'label': 'Nómina',
        'icon': Icons.badge,
        'color': Colors.red.shade700
      },
      {
        'key': 'SERVICIOS',
        'label': 'Servicios',
        'icon': Icons.bolt,
        'color': Colors.blue.shade700
      },
      {
        'key': 'FALTANTE',
        'label': 'Faltantes',
        'icon': Icons.warning_amber,
        'color': Colors.deepOrange.shade700
      },
      {
        'key': 'OTROS',
        'label': 'Otros',
        'icon': Icons.more_horiz,
        'color': Colors.grey.shade700
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: ListView(
              children: categorias.map((c) {
                final activo = _categoriaDetalle == c['key'];
                final monto = (act[_claveCategoria(c['key'] as String)] as num?)
                        ?.toDouble() ??
                    0;
                return InkWell(
                  onTap: () => _cargarDetalleCategoria(c['key'] as String),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activo
                          ? (c['color'] as Color).withValues(alpha: 0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: activo
                              ? (c['color'] as Color)
                              : Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(c['icon'] as IconData,
                            size: 14, color: c['color'] as Color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(c['label'] as String,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: c['color'] as Color)),
                        ),
                        Text(_fmt.format(monto),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: c['color'] as Color)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _categoriaDetalle == null
                ? const Center(
                    child: Text("Selecciona una categoría",
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  )
                : _cargandoDetalle
                    ? const Center(child: CircularProgressIndicator())
                    : _detalleCategoria.isEmpty
                        ? const Center(
                            child: Text("Sin movimientos",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          )
                        : ListView.separated(
                            itemCount: _detalleCategoria.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (context, i) {
                              final m = _detalleCategoria[i];
                              final tipo =
                                  (m['tipo'] ?? '').toString().toUpperCase();
                              final origen = (m['origen'] ?? '').toString();
                              final conceptoRaw =
                                  m['concepto']?.toString() ?? '';

                              String titulo;
                              String cuentaOrigen;
                              if (tipo.startsWith('PAGO_NOMINA') ||
                                  tipo.startsWith('LIQUIDACION')) {
                                final p = _parsearNomina(conceptoRaw, origen);
                                titulo = p['titulo']!;
                                cuentaOrigen = p['cuenta']!;
                              } else {
                                titulo = _limpiarConcepto(conceptoRaw);
                                cuentaOrigen = origen;
                              }

                              final esNominaOLiquidacion = tipo.contains('NOMINA') ||
                                  tipo.contains('LIQUIDAC') ||
                                  tipo.contains('PAGO_NOMINA');
                              final idTx = m['idTx']?.toString() ?? '';

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 70,
                                      child: Text(m['fecha']?.toString() ?? '',
                                          style: const TextStyle(
                                              fontSize: 9.5,
                                              color: Colors.grey)),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            titulo,
                                            style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Row(
                                            children: [
                                              Icon(Icons.account_balance,
                                                  size: 8,
                                                  color: Colors.grey.shade600),
                                              const SizedBox(width: 3),
                                              Flexible(
                                                child: Text(
                                                  cuentaOrigen.isEmpty
                                                      ? '—'
                                                      : _limpiarOrigen(
                                                          cuentaOrigen),
                                                  style: TextStyle(
                                                      fontSize: 8.5,
                                                      color:
                                                          Colors.grey.shade700,
                                                      fontStyle:
                                                          FontStyle.italic),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (esNominaOLiquidacion && idTx.isNotEmpty) ...[
                                      InkWell(
                                        onTap: () => _reimprimirRecibo(idTx),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F52BA)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: const Color(0xFF0F52BA)
                                                    .withValues(alpha: 0.3)),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.print,
                                                  size: 11,
                                                  color: Color(0xFF0F52BA)),
                                              SizedBox(width: 3),
                                              Text(
                                                "Reimprimir",
                                                style: TextStyle(
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0F52BA)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${_fmt.format((m['montoNeto'] as num?)?.toDouble() ?? (m['monto'] as num?)?.toDouble() ?? 0)} Bs',
                                          style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '≈ \$ ${_fmt.format(_usd((m['montoNeto'] as num?)?.toDouble() ?? (m['monto'] as num?)?.toDouble() ?? 0))}',
                                          style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VISTA — CONCILIACIÓN POR CUENTA
  // ============================================================
  Widget _buildVistaConciliacion() {
    if (_conciliacion == null || _conciliacion!['status'] != 'SUCCESS') {
      return const Center(
        child: Text("No se pudo cargar la conciliación.",
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }

    final cuentas = List<dynamic>.from(_conciliacion!['cuentas'] ?? []);
    if (cuentas.isEmpty) {
      return const Center(
        child: Text("Sin cuentas",
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              "Saldo inicial + movimientos = saldo final del rango",
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic),
            ),
          ),
          ...cuentas.map((c) => _buildBloqueCuenta(c)).toList(),
        ],
      ),
    );
  }

  Widget _buildBloqueCuenta(Map<dynamic, dynamic> c) {
    // Lee tasaUSD desde la raíz del response (fallback: de la cuenta)
    final tasaRoot = (_conciliacion!['tasaUSD'] as num?)?.toDouble() ?? 0;
    final tasaCuenta = (c['tasaUSD'] as num?)?.toDouble() ?? 0;
    final tasaConsulta = tasaRoot > 0 ? tasaRoot : tasaCuenta;

    double aUsd(double bs) => tasaConsulta > 0 ? bs / tasaConsulta : 0;

    final cuenta = c['cuenta']?.toString() ?? '';
    final saldoInicio = (c['saldoInicio'] as num?)?.toDouble() ?? 0;
    final ingresos = (c['ingresos'] as num?)?.toDouble() ?? 0;
    final egresos = (c['egresos'] as num?)?.toDouble() ?? 0;
    final esperado = (c['esperado'] as num?)?.toDouble() ?? 0;
    final movs = List<dynamic>.from(c['movimientos'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFF0F52BA).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance,
                  size: 14, color: const Color(0xFF0F52BA)),
              const SizedBox(width: 6),
              Text(cuenta,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Saldo inicio del rango:",
                    style:
                        TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${_fmt.format(saldoInicio)} Bs",
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    Text("≈ \$ ${_fmt.format(aUsd(saldoInicio))}",
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text("Movimientos:",
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 3),
          if (movs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text("Sin movimientos",
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic)),
            )
          else
            ...movs.map((m) {
              final signo = (m['signo'] as num?)?.toInt() ?? 0;
              final monto = (m['monto'] as num?)?.toDouble() ?? 0;
              final tipo = (m['tipo'] ?? '').toString();
              final concepto =
                  _limpiarConcepto((m['concepto'] ?? '').toString());
              final fecha = (m['fecha'] ?? '').toString();
              final esIngreso = signo > 0;
              // Tasa del movimiento si viene, si no la global
              final tasaMov =
                  (m['tasaUSD'] as num?)?.toDouble() ?? tasaConsulta;
              double aUsdMov(double bs) => tasaMov > 0 ? bs / tasaMov : 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(fecha,
                          style:
                              const TextStyle(fontSize: 9, color: Colors.grey)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tipo.replaceAll('_', ' '),
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: esIngreso
                                      ? Colors.green.shade700
                                      : Colors.red.shade700)),
                          Text(concepto,
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sin guion, solo color según signo
                        Text('${_fmt.format(monto)} Bs',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: esIngreso
                                    ? Colors.green.shade700
                                    : Colors.red.shade700)),
                        Text("≈ \$ ${_fmt.format(aUsdMov(monto))}",
                            style: TextStyle(
                                fontSize: 8.5,
                                color: (esIngreso
                                        ? Colors.green.shade700
                                        : Colors.red.shade700)
                                    .withValues(alpha: 0.6))),
                      ],
                    ),
                  ],
                ),
              );
            }),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total ingresos:",
                  style: TextStyle(fontSize: 10, color: Colors.green)),
              Text("${_fmt.format(ingresos)} Bs",
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total egresos:",
                  style: TextStyle(fontSize: 10, color: Colors.red)),
              // Sin guion
              Text("${_fmt.format(egresos)} Bs",
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
            ],
          ),
          const Divider(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F52BA).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Saldo final del rango:",
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${_fmt.format(esperado)} Bs",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F52BA))),
                    Text("≈ \$ ${_fmt.format(aUsd(esperado))}",
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _claveCategoria(String cat) {
    switch (cat) {
      case 'PROVEEDORES':
        return 'proveedores';
      case 'PERSONAL':
        return 'personal';
      case 'NOMINA':
        return 'nomina';
      case 'SERVICIOS':
        return 'servicios';
      case 'FALTANTE':
        return 'faltantes';
      case 'OTROS':
        return 'otros';
    }
    return 'otros';
  }

  // ============================================================
  // VISTA 3 — MOVIMIENTOS
  // ============================================================
  Widget _buildVistaMovimientos() {
    if (_movimientos == null || _movimientos!['status'] != 'SUCCESS') {
      return const Center(
        child: Text("No se pudieron cargar los movimientos.",
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }

    final lista = List<dynamic>.from(_movimientos!['movimientos'] ?? []);

    if (lista.isEmpty) {
      return const Center(
        child: Text("Sin movimientos en el rango",
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: lista.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (context, i) {
        final m = lista[i];
        final tipo = (m['tipo'] ?? '').toString().toUpperCase();
        final origen = (m['origen'] ?? '').toString();
        final esIngreso = tipo.contains('INGRESO') || tipo.contains('CIERRE');
        final monto = (m['montoNeto'] as num?)?.toDouble() ??
            (m['monto'] as num?)?.toDouble() ??
            0;

        // Parseo
        final conceptoRaw = m['concepto']?.toString() ?? '';
        String titulo;
        String cuentaOrigen;
        if (tipo.startsWith('PAGO_NOMINA') || tipo.startsWith('LIQUIDACION')) {
          final p = _parsearNomina(conceptoRaw, origen);
          titulo = p['titulo']!;
          cuentaOrigen = p['cuenta']!;
        } else {
          titulo = _limpiarConcepto(conceptoRaw);
          cuentaOrigen = origen;
        }

        final esNominaOLiquidacion = tipo.contains('NOMINA') ||
            tipo.contains('LIQUIDAC') ||
            tipo.contains('PAGO_NOMINA');
        final idTx = m['idTx']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(m['fecha']?.toString() ?? '',
                    style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fecha + Tipo (badge)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: esIngreso
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: esIngreso
                                    ? Colors.green.shade200
                                    : Colors.red.shade200),
                          ),
                          child: Text(tipo.replaceAll('_', ' '),
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: esIngreso
                                      ? Colors.green.shade800
                                      : Colors.red.shade800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Concepto limpio
                    Text(titulo,
                        style: const TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    // Cuenta origen
                    Row(
                      children: [
                        Icon(Icons.account_balance,
                            size: 9, color: Colors.grey.shade600),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            cuentaOrigen.isEmpty
                                ? '—'
                                : _limpiarOrigen(cuentaOrigen),
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (esNominaOLiquidacion && idTx.isNotEmpty) ...[
                InkWell(
                  onTap: () => _reimprimirRecibo(idTx),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F52BA).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: const Color(0xFF0F52BA).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.print, size: 11, color: Color(0xFF0F52BA)),
                        SizedBox(width: 3),
                        Text(
                          "Reimprimir Recibo",
                          style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F52BA)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${esIngreso ? '+' : '-'}${_fmt.format(monto)} Bs',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: esIngreso
                              ? Colors.green.shade700
                              : Colors.red.shade700)),
                  Text('≈ \$ ${_fmt.format(_usd(monto))}',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: (esIngreso
                                  ? Colors.green.shade700
                                  : Colors.red.shade700)
                              .withValues(alpha: 0.6))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // VISTA 4 — DASHBOARD
  // ============================================================
  Widget _buildVistaDashboard() {
    if (_dashboard == null || _dashboard!['status'] != 'SUCCESS') {
      return const Center(
        child: Text("No se pudo cargar el dashboard.",
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }

    final d = _dashboard!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBloque('RESULTADO DEL PERÍODO', [
            _filaSimple('Ventas', (d['ventas'] as num?)?.toDouble() ?? 0,
                Colors.green.shade800),
            _filaSimple(
                'Comisiones',
                (d['comisiones'] as num?)?.toDouble() ?? 0,
                Colors.orange.shade800),
            _filaSimple('Ventas netas',
                (d['ventasNetas'] as num?)?.toDouble() ?? 0, Colors.black87,
                bold: true),
            const Divider(height: 10),
            _filaSimple(
                'Egresos operativos',
                (d['egresosOperativos'] as num?)?.toDouble() ?? 0,
                Colors.red.shade700),
            _filaSimple('Personal', (d['personal'] as num?)?.toDouble() ?? 0,
                Colors.red.shade700),
            _filaSimple('Nómina', (d['nomina'] as num?)?.toDouble() ?? 0,
                Colors.red.shade700),
            _filaSimple(
                'Total egresos',
                (d['totalEgresos'] as num?)?.toDouble() ?? 0,
                Colors.red.shade900,
                bold: true),
            const Divider(height: 10),
            _filaSimple('Caja del rango',
                (d['cajaRango'] as num?)?.toDouble() ?? 0, Colors.indigo,
                bold: true),
            _filaSimple(
                'Pendientes vencen',
                (d['pendientesVencen'] as num?)?.toDouble() ?? 0,
                Colors.orange.shade800),
            const Divider(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ((d['gananciaReal'] as num?)?.toDouble() ?? 0) >= 0
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Text('RESULTADO',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(
                      '${_fmt.format((d['gananciaReal'] as num?)?.toDouble() ?? 0)} Bs',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color:
                              ((d['gananciaReal'] as num?)?.toDouble() ?? 0) >=
                                      0
                                  ? Colors.green.shade800
                                  : Colors.red.shade800)),
                  const SizedBox(width: 8),
                  Text(
                      '${((d['margen'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} %',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700)),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _filaSimple(String label, double monto, Color color,
      {bool bold = false, double? aUsd}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: bold ? 11 : 10.5,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ),
          Text('${_fmt.format(monto)} Bs',
              style: TextStyle(
                  fontSize: bold ? 11.5 : 10.5,
                  fontWeight: FontWeight.bold,
                  color: color)),
          if (aUsd != null) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 80,
              child: Text('≈ \$ ${_fmt.format(aUsd)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: color.withValues(alpha: 0.7))),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // PDF
  // ============================================================
  Future<void> _imprimirPDF() async {
    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (pw.Context ctx) {
        return [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#E3F2FD'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("CONTROL Y GESTIÓN",
                    style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F52BA'))),
                pw.SizedBox(height: 2),
                pw.Text("Reporte $_vista · ${_rangoStr()}",
                    style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          if (_vista == 'RESUMEN' && _estadisticas != null) ...[
            ..._pdfBloqueResumen(),
          ],
          if (_vista == 'CONCILIACION' && _conciliacion != null) ...[
            ..._pdfBloqueConciliacion(),
          ],
        ];
      },
    ));
    await Printing.layoutPdf(onLayout: (f) async => doc.save());
  }

  List<pw.Widget> _pdfBloqueResumen() {
    final act = _estadisticas!['actual'] as Map? ?? {};
    return [
      pw.Text("RESUMEN",
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfFila('Ventas', (act['ventas'] as num?)?.toDouble() ?? 0),
      _pdfFila('Comisiones', (act['comisiones'] as num?)?.toDouble() ?? 0),
      _pdfFila('Ventas netas', (act['ventasNetas'] as num?)?.toDouble() ?? 0),
      _pdfFila('Proveedores', (act['proveedores'] as num?)?.toDouble() ?? 0),
      _pdfFila('Personal', (act['personal'] as num?)?.toDouble() ?? 0),
      _pdfFila('Nómina', (act['nomina'] as num?)?.toDouble() ?? 0),
      _pdfFila('Servicios', (act['servicios'] as num?)?.toDouble() ?? 0),
      _pdfFila('Total egresos', (act['totalEgresos'] as num?)?.toDouble() ?? 0),
      pw.Divider(),
      _pdfFila('GANANCIA', (act['ganancia'] as num?)?.toDouble() ?? 0),
    ];
  }

  List<pw.Widget> _pdfBloqueConciliacion() {
    if (_conciliacion == null) return [];
    final cuentas = List<dynamic>.from(_conciliacion!['cuentas'] ?? []);
    final tasaConsulta = (_conciliacion!['tasaUSD'] as num?)?.toDouble() ?? 0;
    double aUsd(double bs) => tasaConsulta > 0 ? bs / tasaConsulta : 0;

    List<pw.Widget> items = [
      pw.Text("CONCILIACIÓN POR CUENTA",
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(
          "Rango: ${_conciliacion!['fechaDesde']} a ${_conciliacion!['fechaHasta']}",
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 10),
    ];

    for (var c in cuentas) {
      final cuenta = c['cuenta']?.toString() ?? '';
      final saldoInicio = (c['saldoInicio'] as num?)?.toDouble() ?? 0;
      final ingresos = (c['ingresos'] as num?)?.toDouble() ?? 0;
      final egresos = (c['egresos'] as num?)?.toDouble() ?? 0;
      final esperado = (c['esperado'] as num?)?.toDouble() ?? 0;
      final movs = List<dynamic>.from(c['movimientos'] ?? []);

      items.add(pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F5F7FA'),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(cuenta,
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Saldo inicio:",
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text(
                    "${_fmt.format(saldoInicio)} Bs ~ \$ ${_fmt.format(aUsd(saldoInicio))}",
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 3),
            ...movs.map((m) {
              final signo = (m['signo'] as num?)?.toInt() ?? 0;
              final monto = (m['monto'] as num?)?.toDouble() ?? 0;
              final tipo = (m['tipo'] ?? '').toString().replaceAll('_', ' ');
              final concepto =
                  _limpiarConcepto((m['concepto'] ?? '').toString());
              final fecha = (m['fecha'] ?? '').toString();
              return pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text("$fecha · $tipo · $concepto",
                          style: const pw.TextStyle(fontSize: 8), maxLines: 1),
                    ),
                    // Sin signo, solo color
                    pw.Text(
                        "${_fmt.format(monto)} Bs ~ \$ ${_fmt.format(aUsd(monto))}",
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: signo > 0
                                ? PdfColors.green800
                                : PdfColors.red800)),
                  ],
                ),
              );
            }),
            pw.Divider(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Total ingresos:",
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.green800)),
                pw.Text("${_fmt.format(ingresos)} Bs",
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.green800)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Total egresos:",
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.red800)),
                // Sin guion
                pw.Text("${_fmt.format(egresos)} Bs",
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.red800)),
              ],
            ),
            pw.Divider(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Saldo final del rango:",
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    "${_fmt.format(esperado)} Bs ~ \$ ${_fmt.format(aUsd(esperado))}",
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F52BA'))),
              ],
            ),
          ],
        ),
      ));
    }

    return items;
  }

  pw.Widget _pdfFila(String label, double monto) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text('${_fmt.format(monto)} Bs',
              style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  // ============================================================
  // VISTA CIERRES
  // ============================================================
  Widget _buildVistaCierres() {
    if (_cierres.isEmpty) {
      return const Center(
        child: Text("Sin cierres en el rango",
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _cierres.length,
      itemBuilder: (context, i) {
        final c = _cierres[i];
        final id = c['idCierre']?.toString() ?? '';
        final expandido = _cierreExpandido == id;
        final venta = (c['ventaEsperadaBs'] as num?)?.toDouble() ?? 0;
        final descuadre = (c['descuadreBs'] as num?)?.toDouble() ?? 0;
        final cuadro = descuadre.abs() < 0.01;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color:
                    expandido ? const Color(0xFF0F52BA) : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  if (expandido) {
                    setState(() {
                      _cierreExpandido = null;
                      _detalleCierre = null;
                    });
                  } else {
                    _abrirDetalleCierre(id);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(expandido ? Icons.expand_less : Icons.expand_more,
                          size: 16, color: const Color(0xFF0F52BA)),
                      const SizedBox(width: 6),
                      Icon(Icons.calendar_today,
                          size: 12, color: Colors.grey.shade700),
                      const SizedBox(width: 6),
                      Text(c['fecha']?.toString() ?? '',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Text(id,
                          style: const TextStyle(
                              fontSize: 9.5, color: Colors.grey)),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${_fmt.format(venta)} Bs',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                          Text(
                              cuadro
                                  ? 'CUADRE ✅'
                                  : 'DESCUADRE ${_fmt.format(descuadre)} Bs',
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: cuadro
                                      ? Colors.green.shade700
                                      : Colors.red.shade700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (expandido) _buildDetalleCierreExpandido(id),
            ],
          ),
        );
      },
    );
  }

  Future<void> _abrirDetalleCierre(String id) async {
    setState(() {
      _cierreExpandido = id;
      _cargandoDetalleCierre = true;
      _detalleCierre = null;
    });
    try {
      final cierre = _cierres.firstWhere(
        (c) => c['idCierre'] == id,
        orElse: () => <String, dynamic>{},
      );
      final res = await ApiService.registrarAccionConRespuesta(
        "obtenerDetalleCierre",
        {
          "idCierre": id,
          "fechaCierre": cierre['fecha']?.toString() ?? '',
          "ventaTotal": cierre['ventaEsperadaBs'] ?? 0,
          "descuadre": cierre['descuadreBs'] ?? 0,
          "tasaBCV": cierre['tasaUSD'] ?? 0,
        },
      );
      if (!mounted) return;
      setState(() {
        _detalleCierre = res;
        _cargandoDetalleCierre = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoDetalleCierre = false);
    }
  }

  IconData _iconoCuentaCierre(String cuenta) {
    final c = cuenta.toUpperCase();
    if (c.contains('EFECTIVO USD') || c.contains('USD'))
      return Icons.attach_money;
    if (c.contains('USDT')) return Icons.currency_bitcoin;
    if (c.contains('CAJA') || c.contains('EFECTIVO')) return Icons.payments;
    return Icons.account_balance;
  }

  Color _colorCategoriaGasto(String cat) {
    final c = cat.toUpperCase();
    if (c.contains('PROVEEDOR')) return Colors.orange.shade800;
    if (c.contains('PERSONAL')) return Colors.red.shade700;
    if (c.contains('SERVICIO')) return Colors.blue.shade700;
    if (c.contains('NOMINA') || c.contains('NÓMINA'))
      return Colors.purple.shade700;
    if (c.contains('PRESTAMO') || c.contains('PRÉSTAMO'))
      return Colors.deepPurple.shade700;
    if (c.contains('COMISION') || c.contains('COMISIÓN'))
      return Colors.pink.shade700;
    if (c.contains('FALTANTE')) return Colors.red.shade900;
    if (c.contains('OPERATIVO')) return Colors.teal.shade700;
    return Colors.grey.shade700;
  }

  Widget _miniCard(
      String label, String valor, String usd, IconData icono, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icono, size: 14, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.3)),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(valor,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ),
            if (usd.isNotEmpty)
              FittedBox(
                child: Text(usd,
                    style: TextStyle(
                        fontSize: 8, color: color.withValues(alpha: 0.7))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleCierreExpandido(String id) {
    if (_cargandoDetalleCierre) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_detalleCierre == null) return const SizedBox.shrink();

    final dist = List<dynamic>.from(_detalleCierre!['distribucion'] ?? []);
    final gastosV = List<dynamic>.from(_detalleCierre!['gastosVenta'] ?? []);
    final gastosA =
        List<dynamic>.from(_detalleCierre!['gastosAcumulado'] ?? []);
    final totalDist =
        (_detalleCierre!['totalDistribucion'] as num?)?.toDouble() ?? 0;
    final totalGV =
        (_detalleCierre!['totalGastosVenta'] as num?)?.toDouble() ?? 0;
    final totalGA =
        (_detalleCierre!['totalGastosAcumulado'] as num?)?.toDouble() ?? 0;
    final ventaTotal = (_detalleCierre!['ventaTotal'] as num?)?.toDouble() ?? 0;
    final descuadre =
        (_detalleCierre!['descuadreCierre'] as num?)?.toDouble() ?? 0;
    final tasaBCV = (_detalleCierre!['tasaBCV'] as num?)?.toDouble() ?? 0;
    final tasaUSDT = (_detalleCierre!['tasaUSDT'] as num?)?.toDouble() ?? 0;
    final horaCierre = _detalleCierre!['horaCierre']?.toString() ?? '';
    final pendientes = List<dynamic>.from(_detalleCierre!['pendientes'] ?? []);
    final totalPend =
        (_detalleCierre!['totalPendientes'] as num?)?.toDouble() ?? 0;

    double aUsd(double bs) => tasaBCV > 0 ? bs / tasaBCV : 0;
    final cuadro = descuadre.abs() < 0.01;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== A) HORA + TASAS =====
          Row(
            children: [
              if (horaCierre.isNotEmpty) ...[
                Icon(Icons.access_time, size: 11, color: Colors.grey.shade700),
                const SizedBox(width: 4),
                Text("Cierre: $horaCierre",
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700)),
                const SizedBox(width: 12),
              ],
              Icon(Icons.attach_money,
                  size: 11, color: const Color(0xFF0F52BA)),
              const SizedBox(width: 3),
              Text("BCV ${tasaBCV.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F52BA))),
              const SizedBox(width: 10),
              Icon(Icons.currency_bitcoin,
                  size: 11, color: Colors.green.shade700),
              const SizedBox(width: 3),
              Text("USDT ${tasaUSDT.toStringAsFixed(2)}",
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700)),
            ],
          ),
          const SizedBox(height: 8),

          // ===== G) MINI TARJETAS =====
          Row(
            children: [
              _miniCard(
                  'VENTA',
                  _fmt.format(ventaTotal),
                  "≈ \$${_fmt.format(aUsd(ventaTotal))}",
                  Icons.trending_up,
                  const Color(0xFF0F52BA)),
              _miniCard(
                  'GASTOS',
                  _fmt.format(totalGA),
                  "≈ \$${_fmt.format(aUsd(totalGA))}",
                  Icons.trending_down,
                  Colors.red.shade700),
              _miniCard(
                  cuadro ? 'CUADRE' : (descuadre > 0 ? 'FALTANTE' : 'SOBRANTE'),
                  _fmt.format(descuadre.abs()),
                  "≈ \$${_fmt.format(aUsd(descuadre.abs()))}",
                  cuadro
                      ? Icons.check_circle
                      : (descuadre > 0
                          ? Icons.warning_amber_rounded
                          : Icons.info),
                  cuadro
                      ? Colors.green.shade700
                      : (descuadre > 0
                          ? Colors.red.shade800
                          : Colors.blue.shade700)),
              _miniCard('PENDIENTES', _fmt.format(totalPend), '',
                  Icons.hourglass_empty, Colors.orange.shade800),
            ],
          ),
          const SizedBox(height: 12),

          // ===== D) DISTRIBUCIÓN DETALLADA POR CUENTA =====
          _tituloBloque('DISTRIBUCIÓN POR CUENTA'),
          const SizedBox(height: 4),
          ...dist.map((d) {
            final cuenta = d['cuenta']?.toString() ?? '';
            final total = (d['total'] as num?)?.toDouble() ?? 0;
            final items = List<dynamic>.from(d['items'] ?? []);
            final icono = _iconoCuentaCierre(cuenta);

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icono, size: 13, color: Colors.grey.shade700),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(cuenta,
                            style: const TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ),
                      Text('${_fmt.format(total)} Bs',
                          style: const TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 80,
                        child: Text('≈ \$ ${_fmt.format(aUsd(total))}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 9, color: Colors.grey.shade700)),
                      ),
                    ],
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: items.map((it) {
                          final metodo = it['metodo']?.toString() ?? '';
                          final monto = (it['monto'] as num?)?.toDouble() ?? 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(3),
                              border:
                                  Border.all(color: Colors.blueGrey.shade200),
                            ),
                            child: Text(
                              '$metodo: ${_fmt.format(monto)}',
                              style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade800),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const Divider(height: 10),
          _filaSimple('Total distribuido', totalDist, Colors.blueGrey,
              bold: true, aUsd: aUsd(totalDist)),

          const SizedBox(height: 10),
          _tituloBloque('GASTOS DE LA VENTA DEL DÍA'),
          const SizedBox(height: 4),
          if (gastosV.isEmpty)
            const Text("Ninguno",
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic))
          else
            ...gastosV.map((g) {
              final cat = g['categoria']?.toString() ?? '';
              final monto = (g['monto'] as num?)?.toDouble() ?? 0;
              final color = _colorCategoriaGasto(cat);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(cat,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ),
                    Text('${_fmt.format(monto)} Bs',
                        style: const TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 80,
                      child: Text('≈ \$ ${_fmt.format(aUsd(monto))}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey.shade700)),
                    ),
                  ],
                ),
              );
            }),
          const Divider(height: 10),
          _filaSimple('Total gastos venta', totalGV, Colors.red,
              bold: true, aUsd: aUsd(totalGV)),

          // ===== GASTOS ACUMULADOS CON COLORES =====
          if (gastosA.isNotEmpty) ...[
            const SizedBox(height: 10),
            _tituloBloque('GASTOS DEL ACUMULADO (referencia)'),
            const SizedBox(height: 4),
            ...gastosA.map((g) {
              final cat = g['categoria']?.toString() ?? '';
              final monto = (g['monto'] as num?)?.toDouble() ?? 0;
              final color = _colorCategoriaGasto(cat);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(cat,
                          style: TextStyle(fontSize: 10.5, color: color)),
                    ),
                    Text('${_fmt.format(monto)} Bs',
                        style: TextStyle(fontSize: 10.5, color: color)),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 80,
                      child: Text('≈ \$ ${_fmt.format(aUsd(monto))}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey.shade600)),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 10),
            _filaSimple('Total acumulado', totalGA, Colors.grey,
                aUsd: aUsd(totalGA)),
          ],

          // ===== F) AVISO DESTACADO FALTANTE =====
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cuadro
                  ? Colors.green.shade50
                  : (descuadre > 0 ? Colors.red.shade50 : Colors.blue.shade50),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: cuadro
                      ? Colors.green.shade400
                      : (descuadre > 0
                          ? Colors.red.shade500
                          : Colors.blue.shade400),
                  width: 2),
            ),
            child: Row(
              children: [
                Icon(
                  cuadro
                      ? Icons.check_circle
                      : (descuadre > 0
                          ? Icons.warning_amber_rounded
                          : Icons.info),
                  color: cuadro
                      ? Colors.green.shade800
                      : (descuadre > 0
                          ? Colors.red.shade800
                          : Colors.blue.shade800),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cuadro
                            ? 'CUADRE PERFECTO'
                            : (descuadre > 0 ? 'FALTANTE' : 'SOBRANTE'),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: cuadro
                                ? Colors.green.shade900
                                : (descuadre > 0
                                    ? Colors.red.shade900
                                    : Colors.blue.shade900)),
                      ),
                      Text(
                        'Diferencia: ${_fmt.format(descuadre.abs())} Bs  ≈  \$${_fmt.format(aUsd(descuadre.abs()))}',
                        style: TextStyle(
                            fontSize: 10,
                            color: cuadro
                                ? Colors.green.shade700
                                : Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ===== PENDIENTES =====
          if (pendientes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _tituloBloque('PENDIENTES POR PAGAR'),
            const SizedBox(height: 4),
            ...pendientes.map((p) {
              final tercero = p['tercero']?.toString() ?? '';
              final concepto = p['concepto']?.toString() ?? '';
              final monto = (p['monto'] as num?)?.toDouble() ?? 0;
              final moneda = p['moneda']?.toString() ?? 'BS';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tercero,
                              style: const TextStyle(
                                  fontSize: 10.5, fontWeight: FontWeight.bold)),
                          if (concepto.isNotEmpty)
                            Text(concepto,
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text('${_fmt.format(monto)} $moneda',
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange)),
                  ],
                ),
              );
            }),
            if (totalPend > 0) ...[
              const Divider(height: 8),
              _filaSimple(
                  'Total pendientes (Bs)', totalPend, Colors.orange.shade800,
                  bold: true, aUsd: aUsd(totalPend)),
            ],
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F52BA),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.picture_as_pdf, size: 12),
              label: const Text("Imprimir PDF",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              onPressed: () => _imprimirPDFCierre(id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloBloque(String t) {
    return Text(t,
        style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 0.5));
  }

  Future<void> _imprimirPDFCierre(String id) async {
    final cierre =
        _cierres.firstWhere((c) => c['idCierre'] == id, orElse: () => {});
    final doc = pw.Document();
    final colorRojo = PdfColor.fromHex('#C62828');
    final colorVerde = PdfColor.fromHex('#2E7D32');
    final colorGris = PdfColor.fromHex('#757575');

    final dist = List<dynamic>.from(_detalleCierre?['distribucion'] ?? []);
    final gastosV = List<dynamic>.from(_detalleCierre?['gastosVenta'] ?? []);
    final gastosA =
        List<dynamic>.from(_detalleCierre?['gastosAcumulado'] ?? []);
    final totalGV =
        (_detalleCierre?['totalGastosVenta'] as num?)?.toDouble() ?? 0;
    final totalGA =
        (_detalleCierre?['totalGastosAcumulado'] as num?)?.toDouble() ?? 0;
    final totalDist =
        (_detalleCierre?['totalDistribucion'] as num?)?.toDouble() ?? 0;
    final ventaTotal = (_detalleCierre?['ventaTotal'] as num?)?.toDouble() ?? 0;
    final descuadre =
        (_detalleCierre?['descuadreCierre'] as num?)?.toDouble() ?? 0;
    final tasaBCV = (_detalleCierre?['tasaBCV'] as num?)?.toDouble() ?? 0;
    final pendientes = List<dynamic>.from(_detalleCierre?['pendientes'] ?? []);
    final totalPend =
        (_detalleCierre?['totalPendientes'] as num?)?.toDouble() ?? 0;

    double aUsd(double bs) => tasaBCV > 0 ? bs / tasaBCV : 0;

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // HEADER
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#E3F2FD'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("CONTROL Y GESTIÓN",
                    style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F52BA'))),
                pw.SizedBox(height: 2),
                pw.Text("Reporte de Cierre",
                    style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 4),
                pw.Text("ID: $id  ·  Fecha: ${cierre['fecha'] ?? ''}",
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // VENTA TOTAL
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#E3F2FD'),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("VENTA TOTAL",
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F52BA'))),
                pw.Text(
                    "${_fmt.format(ventaTotal)} Bs ~ \$ ${_fmt.format(aUsd(ventaTotal))}",
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F52BA'))),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // DISTRIBUCIÓN
          pw.Text("DISTRIBUCIÓN POR CUENTA",
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: colorGris)),
          pw.SizedBox(height: 6),
          ...dist.map((d) {
            final cuenta = d['cuenta']?.toString() ?? '';
            final total = (d['total'] as num?)?.toDouble() ?? 0;
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(cuenta, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(
                      "${_fmt.format(total)} Bs ~ \$ ${_fmt.format(aUsd(total))}",
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            );
          }),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Total distribuido",
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  "${_fmt.format(totalDist)} Bs ~ \$ ${_fmt.format(aUsd(totalDist))}",
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0F52BA'))),
            ],
          ),

          pw.SizedBox(height: 14),
          pw.Text("GASTOS DE LA VENTA DEL DÍA",
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: colorGris)),
          pw.SizedBox(height: 6),
          if (gastosV.isEmpty)
            pw.Text("Ninguno",
                style: pw.TextStyle(fontSize: 10, color: colorGris))
          else
            ...gastosV.map((g) {
              final cat = g['categoria']?.toString() ?? '';
              final monto = (g['monto'] as num?)?.toDouble() ?? 0;
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(cat, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                        "${_fmt.format(monto)} Bs ~ \$ ${_fmt.format(aUsd(monto))}",
                        style: pw.TextStyle(fontSize: 10, color: colorRojo)),
                  ],
                ),
              );
            }),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Total gastos venta",
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  "${_fmt.format(totalGV)} Bs ~ \$ ${_fmt.format(aUsd(totalGV))}",
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: colorRojo)),
            ],
          ),

          if (gastosA.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text("GASTOS DEL ACUMULADO (referencia)",
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: colorGris)),
            pw.SizedBox(height: 6),
            ...gastosA.map((g) {
              final cat = g['categoria']?.toString() ?? '';
              final monto = (g['monto'] as num?)?.toDouble() ?? 0;
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(cat, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                        "${_fmt.format(monto)} Bs ~ \$ ${_fmt.format(aUsd(monto))}",
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              );
            }),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Total acumulado",
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    "${_fmt.format(totalGA)} Bs ~ \$ ${_fmt.format(aUsd(totalGA))}",
                    style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ],

          // CUADRE
          pw.SizedBox(height: 16),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: descuadre.abs() < 0.01
                  ? PdfColor.fromHex('#E8F5E9')
                  : PdfColor.fromHex('#FFEBEE'),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    descuadre.abs() < 0.01
                        ? "CUADRE PERFECTO"
                        : (descuadre > 0 ? "FALTANTE" : "SOBRANTE"),
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color:
                            descuadre.abs() < 0.01 ? colorVerde : colorRojo)),
                pw.Text(
                    "${_fmt.format(descuadre.abs())} Bs ~ \$ ${_fmt.format(aUsd(descuadre.abs()))}",
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color:
                            descuadre.abs() < 0.01 ? colorVerde : colorRojo)),
              ],
            ),
          ),

          // PENDIENTES
          if (pendientes.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text("PENDIENTES POR PAGAR",
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: colorGris)),
            pw.SizedBox(height: 6),
            ...pendientes.map((p) {
              final tercero = p['tercero']?.toString() ?? '';
              final monto = (p['monto'] as num?)?.toDouble() ?? 0;
              final moneda = p['moneda']?.toString() ?? 'BS';
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(tercero, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("${_fmt.format(monto)} $moneda",
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              );
            }),
            if (totalPend > 0) ...[
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Total pendientes (Bs)",
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      "${_fmt.format(totalPend)} Bs ~ \$ ${_fmt.format(aUsd(totalPend))}",
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ],
        ],
      ),
    ));

    await Printing.layoutPdf(onLayout: (f) async => doc.save());
  }

  // ============================================================
  // HELPERS DE CONCEPTO
  // ============================================================
  Widget _filaDesgloseRecibo(String label, double monto, Color color,
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

  Future<void> _reimprimirRecibo(String idTx) async {
    try {
      final res = await ApiService.registrarAccionConRespuesta(
        "obtenerDetalleRecibo",
        {"idTx": idTx},
      );
      if (!mounted) return;
      if (res['status'] == 'SUCCESS' && res['recibo'] != null) {
        final Map<String, dynamic> datos =
            Map<String, dynamic>.from(res['recibo'] as Map);
        _mostrarDialogoRecibo(context, datos);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                res['mensaje'] ?? "No se encontró detalle para este recibo."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al recuperar el recibo: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _imprimirReciboDocumento(
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
            pw.Text("Fecha: ${datos['fecha'] ?? ''}",
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
                    pw.Text("\$ ${((ad['monto'] ?? 0) as num).toStringAsFixed(2)}",
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                );
              }),
              pw.Divider(thickness: 0.5),
            ],
            pw.Divider(thickness: 0.5),
            pw.Text("Operación: ${datos['tipo'] ?? ''}",
                style: const pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.Text("Trabajador: ${datos['nombre'] ?? ''}",
                style: const pw.TextStyle(fontSize: 8)),
            pw.Text("Cédula: V-${datos['cedula'] ?? ''}",
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
            if (((datos['detSemana'] ?? 0) as num) > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Sueldo Semanal:",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("\$ ${((datos['detSemana'] ?? 0) as num).toStringAsFixed(2)}",
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            if (((datos['detPrestaciones'] ?? 0) as num) > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Prestaciones:",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("\$ ${((datos['detPrestaciones'] ?? 0) as num).toStringAsFixed(2)}",
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            if (((datos['detVacaciones'] ?? 0) as num) > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Vacaciones + Bono:",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("\$ ${((datos['detVacaciones'] ?? 0) as num).toStringAsFixed(2)}",
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            if (((datos['detUtilidades'] ?? 0) as num) > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Utilidades:",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("\$ ${((datos['detUtilidades'] ?? 0) as num).toStringAsFixed(2)}",
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
                pw.Text("\$ ${((datos['totalSalarial'] ?? 0) as num).toStringAsFixed(2)}",
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 8)),
              ],
            ),
            pw.Divider(thickness: 0.5),
            if (((datos['totalNoSalarial'] ?? 0) as num) > 0) ...[
              pw.Text("BENEFICIOS NO SALARIALES:",
                  style: const pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                      color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              if (((datos['detAyudaFamiliar'] ?? 0) as num) > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Ayuda Familiar:",
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        "\$ ${((datos['detAyudaFamiliar'] ?? 0) as num).toStringAsFixed(2)}",
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Text("   G.O. Ext. N° 6.076 (07/05/2012) - Art. 104 LOTTT",
                    style: const pw.TextStyle(
                        fontSize: 6, color: PdfColors.grey700)),
              ],
              if (((datos['detBonoAlimenticio'] ?? 0) as num) > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Bono Alimenticio:",
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        "\$ ${((datos['detBonoAlimenticio'] ?? 0) as num).toStringAsFixed(2)}",
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
                pw.Text("\$ ${((datos['montoBrutoUSD'] ?? 0) as num).toStringAsFixed(2)}",
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 8)),
              ],
            ),
            if (((datos['descuentoDeuda'] ?? 0) as num) > 0) ...[
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Deuda Anterior:",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("\$ ${((datos['deudaAnterior'] ?? 0) as num).toStringAsFixed(2)}",
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Abono a Deuda:",
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.green800)),
                  pw.Text("- \$ ${((datos['descuentoDeuda'] ?? 0) as num).toStringAsFixed(2)}",
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
                  pw.Text("\$ ${((datos['nuevoSaldoDeuda'] ?? 0) as num).toStringAsFixed(2)}",
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
                pw.Text("\$ ${((datos['montoUSD'] ?? 0) as num).toStringAsFixed(2)}",
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
                pw.Text("${((datos['montoBs'] ?? 0) as num).toStringAsFixed(2)} Bs",
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Tasa:", style: const pw.TextStyle(fontSize: 7)),
                pw.Text("${((datos['tasa'] ?? 0) as num).toStringAsFixed(2)} Bs/\$",
                    style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),
            pw.Center(
                child: pw.Text(datos['textoLegal'] ?? '',
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

  void _mostrarDialogoRecibo(
      BuildContext context, Map<String, dynamic> datos) {
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
                        Text("COMPROBANTE REIMPRESO",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5)),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
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
                      Text("Fecha: ${datos['fecha'] ?? ''}",
                          style:
                              const TextStyle(fontSize: 9, color: Colors.grey)),
                      Text("Operación: ${datos['tipo'] ?? ''}",
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      Text("Trabajador: ${datos['nombre'] ?? ''}",
                          style: const TextStyle(fontSize: 10)),
                      Text("Cédula: V-${datos['cedula'] ?? ''}",
                          style: const TextStyle(fontSize: 10)),
                      if (datos['fechaEgreso'] != null &&
                          datos['fechaEgreso'].toString().isNotEmpty)
                        Text("Fecha de Egreso: ${datos['fechaEgreso']}",
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700)),
                      const Divider(height: 12),
                      if (((datos['detSemana'] ?? 0) as num) > 0)
                        _filaDesgloseRecibo("Sueldo Semanal",
                            (datos['detSemana'] as num).toDouble(), Colors.black87),
                      if (((datos['detPrestaciones'] ?? 0) as num) > 0)
                        _filaDesgloseRecibo("Prestaciones",
                            (datos['detPrestaciones'] as num).toDouble(), Colors.black87),
                      if (((datos['detVacaciones'] ?? 0) as num) > 0)
                        _filaDesgloseRecibo("Vacaciones + Bono",
                            (datos['detVacaciones'] as num).toDouble(), Colors.black87),
                      if (((datos['detUtilidades'] ?? 0) as num) > 0)
                        _filaDesgloseRecibo("Utilidades",
                            (datos['detUtilidades'] as num).toDouble(), Colors.black87),
                      const Divider(height: 12),
                      if (((datos['detAyudaFamiliar'] ?? 0) as num) > 0)
                        _filaDesgloseRecibo("Ayuda Familiar",
                            (datos['detAyudaFamiliar'] as num).toDouble(), Colors.grey.shade700),
                      if (((datos['detBonoAlimenticio'] ?? 0) as num) > 0)
                        _filaDesgloseRecibo("Bono Alimenticio",
                            (datos['detBonoAlimenticio'] as num).toDouble(), Colors.grey.shade700),
                      const Divider(height: 12),
                      if (((datos['descuentoDeuda'] ?? 0) as num) > 0) ...[
                        const Divider(height: 12),
                        _filaDesgloseRecibo("Deuda Anterior",
                            (datos['deudaAnterior'] as num).toDouble(), Colors.red.shade700),
                        _filaDesgloseRecibo("Abono a Deuda",
                            -(datos['descuentoDeuda'] as num).toDouble(), Colors.green.shade700),
                        _filaDesgloseRecibo("Nueva Deuda",
                            (datos['nuevoSaldoDeuda'] as num).toDouble(), Colors.red.shade900,
                            negrita: true),
                      ],
                      _filaDesgloseRecibo("TOTAL USD",
                          ((datos['montoUSD'] ?? 0) as num).toDouble(), Colors.blue,
                          negrita: true, grande: true),
                      _filaDesgloseRecibo("TOTAL Bs",
                          ((datos['montoBs'] ?? 0) as num).toDouble(), Colors.green,
                          negrita: true, grande: true),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(datos['textoLegal'] ?? '',
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
                            await _imprimirReciboDocumento(datos, true);
                            if (!context.mounted) return;
                            Navigator.pop(context);
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
                            await _imprimirReciboDocumento(datos, false);
                            if (!context.mounted) return;
                            Navigator.pop(context);
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

  String _limpiarOrigen(String origen) {
    final idx = origen.indexOf(':');
    if (idx > 0) {
      final antes = origen.substring(0, idx).trim();
      if (antes.isNotEmpty) return antes;
    }
    return origen;
  }

  String _limpiarConcepto(String concepto) {
    final idx = concepto.indexOf('| IDEMP:');
    if (idx > 0) return concepto.substring(0, idx).trim();
    final idx2 = concepto.indexOf('IDEMP:');
    if (idx2 > 0) return concepto.substring(0, idx2).trim();
    return concepto;
  }

  /// Extrae nombre + cuenta origen de un concepto de nómina
  Map<String, String> _parsearNomina(String concepto, String origen) {
    final limpio = _limpiarConcepto(concepto);
    final idx = limpio.indexOf('Nómina:');
    if (idx < 0) {
      return {'titulo': limpio, 'cuenta': origen.isNotEmpty ? origen : '—'};
    }
    var resto = limpio.substring(idx + 7).trim();
    // resto = "NOMBRE (V-XXX) | CUENTA: MONTO"
    String nombre = resto;
    String cuenta = origen.isNotEmpty ? origen : '—';
    final partes = resto.split('|');
    if (partes.isNotEmpty) {
      nombre = partes[0].trim();
    }
    if (partes.length > 1) {
      var c = partes[1].trim();
      final colon = c.lastIndexOf(':');
      if (colon > 0) c = c.substring(0, colon).trim();
      if (c.isNotEmpty) cuenta = c;
    }
    return {'titulo': nombre, 'cuenta': cuenta};
  }
}
