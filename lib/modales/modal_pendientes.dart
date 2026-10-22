import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../servicios/api_service.dart';

class ModalPendientes extends StatefulWidget {
  final double tasaUSD;
  const ModalPendientes({super.key, this.tasaUSD = 0});

  @override
  State<ModalPendientes> createState() => _ModalPendientesState();
}

class _ModalPendientesState extends State<ModalPendientes> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 2);

  bool _cargando = true;
  bool _procesando = false;
  List<dynamic> _pendientes = [];
  double _totalPorPagar = 0;

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final res = await ApiService.obtenerPendientes();
      if (!mounted) return;
      setState(() {
        _pendientes = List.from(res['pendientes'] ?? []);
        _totalPorPagar = (res['totalPorPagar'] as num?)?.toDouble() ?? 0.0;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _agregarPendiente() async {
    final terceroCtrl = TextEditingController();
    final conceptCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final notaCtrl = TextEditingController();
    DateTime? fechaVenc;
    String moneda = "BS";

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Text("Nuevo Pendiente por Pagar",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: terceroCtrl,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      hintText: "Proveedor / Tercero",
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: conceptCtrl,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      hintText: "Concepto (factura, servicio...)",
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: montoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: "Monto",
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ChoiceChip(
                            label: const Text("BS",
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold)),
                            selected: moneda == "BS",
                            onSelected: (val) => setSt(() => moneda = "BS"),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text("USD",
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold)),
                            selected: moneda == "USD",
                            onSelected: (val) => setSt(() => moneda = "USD"),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text("USDT",
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold)),
                            selected: moneda == "USDT",
                            onSelected: (val) => setSt(() => moneda = "USDT"),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final f = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (f != null) setSt(() => fechaVenc = f);
                  },
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 12, color: Color(0xFF0F52BA)),
                        const SizedBox(width: 6),
                        Text(
                          fechaVenc == null
                              ? "Fecha vencimiento (opcional)"
                              : DateFormat('dd/MM/yyyy').format(fechaVenc!),
                          style: const TextStyle(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: notaCtrl,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      hintText: "Nota (opcional)",
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
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
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );

    if (guardar != true) return;

    final monto =
        double.tryParse(montoCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    if (monto <= 0 || terceroCtrl.text.trim().isEmpty) {
      _mostrarMensaje("Tercero y monto son obligatorios", Colors.red);
      return;
    }

    setState(() => _procesando = true);

    final payload = {
      "tipo": "POR_PAGAR",
      "tercero": terceroCtrl.text.trim(),
      "concepto": conceptCtrl.text.trim(),
      "monto": monto,
      "moneda": moneda,
      "fechaVencimiento":
          fechaVenc != null ? DateFormat('yyyy-MM-dd').format(fechaVenc!) : "",
      "nota": notaCtrl.text.trim(),
    };

    final res = await ApiService.registrarPendiente(payload);
    if (!mounted) return;
    setState(() => _procesando = false);

    if (res['status'] == "SUCCESS" || res['exito'] == true) {
      _mostrarMensaje("Pendiente agregado", Colors.green);
      _cargarPendientes();
    } else {
      _mostrarMensaje(res['mensaje']?.toString() ?? "Error", Colors.red);
    }
  }

  Future<void> _marcarPagado(String id, String tercero, double monto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text("Marcar como pagado",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        content: Text(
            "¿Marcar el pendiente de $tercero por ${_fmt.format(monto)} como PAGADO?",
            style: const TextStyle(fontSize: 11)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sí, pagado"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesando = true);

    final res = await ApiService.marcarPendientePagado({"id": id});
    if (!mounted) return;
    setState(() => _procesando = false);

    if (res['status'] == "SUCCESS" || res['exito'] == true) {
      _mostrarMensaje("Marcado como pagado", Colors.green);
      _cargarPendientes();
    } else {
      _mostrarMensaje(res['mensaje']?.toString() ?? "Error", Colors.red);
    }
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

  @override
  Widget build(BuildContext context) {
    const Color azulHeader = Color(0xFF0F52BA);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 640),
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
                  const Row(
                    children: [
                      Icon(Icons.hourglass_empty,
                          size: 15, color: Colors.white),
                      SizedBox(width: 8),
                      Text("CUENTAS PENDIENTES",
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
                        icon: const Icon(Icons.add, size: 13),
                        label: const Text("AGREGAR",
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                        onPressed: _procesando ? null : _agregarPendiente,
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

            // RESUMEN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.orange.shade900),
                  const SizedBox(width: 8),
                  const Text("Total por pagar:",
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text("${_fmt.format(_totalPorPagar)} Bs",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900)),
                ],
              ),
            ),

            // LISTA
            Flexible(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _pendientes.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              "No hay cuentas pendientes.",
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _pendientes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final p = _pendientes[i];
                            final id = p['id']?.toString() ?? '';
                            final tercero = p['tercero']?.toString() ?? '';
                            final concepto = p['concepto']?.toString() ?? '';
                            final monto =
                                (p['monto'] as num?)?.toDouble() ?? 0.0;
                            final moneda = p['moneda']?.toString() ?? 'BS';
                            final fechaVenc =
                                p['fechaVencimiento']?.toString() ?? '';
                            final nota = p['nota']?.toString() ?? '';
                            final estado =
                                (p['estado']?.toString() ?? 'PENDIENTE')
                                    .toUpperCase();
                            final esPagado = estado == 'PAGADO';

                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: esPagado
                                      ? Colors.green.shade200
                                      : Colors.amber.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: esPagado
                                          ? Colors.green.shade100
                                          : Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      esPagado
                                          ? Icons.check_circle
                                          : Icons.schedule,
                                      size: 16,
                                      color: esPagado
                                          ? Colors.green.shade800
                                          : Colors.orange.shade800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(tercero,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold)),
                                        if (concepto.isNotEmpty)
                                          Text(concepto,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.black54)),
                                        Row(
                                          children: [
                                            if (fechaVenc.isNotEmpty)
                                              Text("Vence: $fechaVenc",
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      color: Colors
                                                          .orange.shade800,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            if (nota.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text("· $nota",
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 9,
                                                        color: Colors.grey)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("${_fmt.format(monto)} $moneda",
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: esPagado
                                                  ? Colors.grey.shade600
                                                  : Colors.orange.shade900)),
                                      const SizedBox(height: 2),
                                      if (esPagado)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check,
                                                size: 12,
                                                color: Colors.green.shade700),
                                            const SizedBox(width: 4),
                                            Text("Pagado",
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.green.shade700)),
                                          ],
                                        )
                                      else
                                        SizedBox(
                                          height: 22,
                                          child: TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  Colors.green.shade700,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6),
                                              minimumSize: const Size(0, 22),
                                            ),
                                            icon: const Icon(Icons.check,
                                                size: 12),
                                            label: const Text("Marcar pagado",
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            onPressed: _procesando
                                                ? null
                                                : () => _marcarPagado(
                                                    id, tercero, monto),
                                          ),
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
      ),
    );
  }
}
