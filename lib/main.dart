import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'modales/modal_conciliacion.dart';
import 'modales/modal_consultas.dart';
import 'modales/modal_disponibilidad.dart';
import 'modales/modal_operaciones.dart';
import 'modales/modal_trabajador.dart';
import 'servicios/api_service.dart';
import 'servicios/cache_service.dart';
import 'servicios/queue_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ControlYGestionApp());
}

class ControlYGestionApp extends StatelessWidget {
  const ControlYGestionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CONTROL Y GESTION',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 2);
  // Formateador exclusivo para Bs (sin decimales)
  final NumberFormat _fmtBs =
      NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 0);

  double _tasaUSD = 827.74;
  double _tasaUSDT = 965.00;
  double _tasaEUR = 0.0;
  double _tasaUSDTParalelo = 0.0;
  double _ratioMargen = 1.2487033;
  Map<String, dynamic> _saldos = {};
  bool _cargandoInicial = true;

  int _pendientes = 0;
  int _errores = 0;
  bool _sincronizandoCola = false;

  Map<String, dynamic>? _estadoDia;
  bool _bannerIgnorado = false;

  bool get _puedeOperar => true;

  bool get _mostrarBannerTasa {
    if (_bannerIgnorado) return false;
    if (_estadoDia == null) return false;
    return _estadoDia!['tasasCargadas'] == false;
  }

  @override
  void initState() {
    super.initState();

    _despertarBackend();
    _cargarDatosPrincipales();
    _contarCola();
    _verificarEstadoDia();

    QueueService.setOnQueueChanged(() {
      if (mounted) _contarCola();
    });

    QueueService.iniciarSyncAutomatico(() async {
      final pend = await QueueService.contarPendientes();
      if (pend > 0) {
        await _sincronizarPendientes();
      }
    });
  }

  void _despertarBackend() async {
    try {
      await ApiService.obtenerTasas().timeout(
        const Duration(seconds: 120),
        onTimeout: () => {},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    QueueService.detenerSync();
    super.dispose();
  }

  Future<void> _verificarEstadoDia() async {
    final fechaHoy = DateTime.now().toString().substring(0, 10);
    final ignoradoGuardado = await CacheService.leerBannerIgnorado();
    final bool bannerIgn = (ignoradoGuardado == fechaHoy);

    try {
      final res = await ApiService.verificarEstadoDelDia();
      if (!mounted) return;
      setState(() {
        _estadoDia = res;
        _bannerIgnorado = bannerIgn;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _bannerIgnorado = bannerIgn;
        });
      }
    }
  }

  Future<void> _ignorarBanner() async {
    final fechaHoy = DateTime.now().toString().substring(0, 10);
    await CacheService.guardarBannerIgnorado(fechaHoy);
    if (mounted) {
      setState(() => _bannerIgnorado = true);
    }
  }

  Future<void> _contarCola() async {
    final pend = await QueueService.contarPendientes();
    final err = await QueueService.contarErrores();
    if (mounted) {
      setState(() {
        _pendientes = pend;
        _errores = err;
      });
    }
  }

  Future<void> _sincronizarPendientes() async {
    if (_sincronizandoCola) return;

    final cola = await QueueService.leerCola();
    if (cola.isEmpty) return;

    if (mounted) setState(() => _sincronizandoCola = true);

    for (var item in cola) {
      if (item['estado'] != 'pendiente') continue;

      try {
        final res = await ApiService.sincronizarItem(
          item['action'].toString(),
          Map<String, dynamic>.from(item['payload']),
        );

        if (res['status'] == 'SUCCESS' || res['exito'] == true) {
          await QueueService.eliminar(item['id'].toString());
        } else {
          final intentos = (item['intentos'] as int?) ?? 0;
          final nuevosIntentos = intentos + 1;

          if (nuevosIntentos >= QueueService.maxIntentos) {
            await QueueService.actualizarItem(item['id'].toString(), {
              'intentos': nuevosIntentos,
              'estado': 'error',
              'ultimoError': res['mensaje'] ?? 'Error desconocido',
            });
          } else {
            await QueueService.actualizarItem(item['id'].toString(), {
              'intentos': nuevosIntentos,
            });
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _sincronizandoCola = false);
      await _contarCola();
    }
  }

  void _cargarDatosPrincipales() async {
    final tasasCache = await CacheService.leerTasas();
    final saldosCache = await CacheService.leerSaldos();

    if (mounted) {
      setState(() {
        if (tasasCache != null) {
          _tasaUSD = (tasasCache['tasaUSD'] as num?)?.toDouble() ?? _tasaUSD;
          _tasaUSDT = (tasasCache['tasaUSDT'] as num?)?.toDouble() ?? _tasaUSDT;
          _tasaEUR = (tasasCache['tasaEUR'] as num?)?.toDouble() ?? _tasaEUR;
          _tasaUSDTParalelo =
              (tasasCache['tasaUSDTParalelo'] as num?)?.toDouble() ??
                  _tasaUSDTParalelo;
          _ratioMargen =
              (tasasCache['ratioMargen'] as num?)?.toDouble() ?? _ratioMargen;
        }
        if (saldosCache != null) {
          _saldos = saldosCache;
        }
        _cargandoInicial = false;
      });
    }

    try {
      final resultados = await Future.wait([
        ApiService.obtenerTasas(),
        ApiService.obtenerSaldos(),
      ]);
      if (!mounted) return;
      setState(() {
        _tasaUSD = (resultados[0]['tasaUSD'] as num?)?.toDouble() ?? _tasaUSD;
        _tasaUSDT =
            (resultados[0]['tasaUSDT'] as num?)?.toDouble() ?? _tasaUSDT;
        _tasaEUR = (resultados[0]['tasaEUR'] as num?)?.toDouble() ??
            (resultados[0]['tasas']?['EUR'] as num?)?.toDouble() ??
            _tasaEUR;
        _tasaUSDTParalelo =
            (resultados[0]['tasaUSDTParalelo'] as num?)?.toDouble() ??
                (resultados[0]['tasaUSDParalelo'] as num?)?.toDouble() ??
                (resultados[0]['tasas']?['USD_PARALELO'] as num?)?.toDouble() ??
                _tasaUSDTParalelo;
        _ratioMargen =
            (resultados[0]['ratioMargen'] as num?)?.toDouble() ?? _ratioMargen;
        _saldos = resultados[1];
      });
    } catch (_) {}
  }

  void _refrescarSaldosForzado() async {
    await CacheService.marcarSaldosViejos();
    await CacheService.marcarTasasViejas();
    _cargarDatosPrincipales();
  }

  void _mostrarPanelCola() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload, color: Color(0xFF0F52BA)),
            SizedBox(width: 8),
            Text("Cola de operaciones",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 480,
          height: 400,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: QueueService.leerCola(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final cola = snapshot.data!;
              if (cola.isEmpty) {
                return const Center(
                  child: Text("No hay operaciones pendientes",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                );
              }
              return ListView.separated(
                itemCount: cola.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final item = cola[i];
                  final estado = item['estado'].toString();
                  final isError = estado == 'error';
                  final color = isError ? Colors.red : Colors.orange;

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isError ? Icons.error : Icons.hourglass_empty,
                      color: color,
                      size: 20,
                    ),
                    title: Text(item['action'].toString(),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      isError
                          ? "Error: ${item['ultimoError'] ?? 'desconocido'}"
                          : "Intentos: ${item['intentos']}/5",
                      style: TextStyle(fontSize: 10, color: color),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isError)
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                size: 18, color: Colors.green),
                            onPressed: () async {
                              await QueueService.reintentar(
                                  item['id'].toString());
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _sincronizarPendientes();
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () async {
                            await QueueService.eliminar(item['id'].toString());
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _contarCola();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await QueueService.limpiarErrores();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _contarCola();
            },
            child: const Text("Limpiar errores"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerAmarillo() {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade900, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Aviso: no hay tasa del día cargada. Cárgala en Disponibilidad.",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900),
            ),
          ),
          TextButton(
            onPressed: _ignorarBanner,
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 28),
            ),
            child: const Text("Ignorar",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, double>> _procesarSaldos() {
    List<MapEntry<String, double>> saldosBs = [];
    List<MapEntry<String, double>> saldosVerdes = [];

    Map<String, dynamic> mapaAProcesar = {};
    if (_saldos.containsKey('saldos') && _saldos['saldos'] is Map) {
      mapaAProcesar = Map<String, dynamic>.from(_saldos['saldos']);
    } else {
      mapaAProcesar = _saldos;
    }

    mapaAProcesar.forEach((key, value) {
      if (key == 'status' || key == 'exito' || key == 'message') return;

      double monto = 0.0;
      if (value is num) {
        monto = value.toDouble();
      } else if (value is Map) {
        monto = (value['monto'] as num?)?.toDouble() ?? 0.0;
      } else if (value is String) {
        monto =
            double.tryParse(value.replaceAll('.', '').replaceAll(',', '.')) ??
                0.0;
      }

      String keyUpper = key.toUpperCase();
      if (monto > 0.001 &&
          !keyUpper.contains("PAGO MÓVIL") &&
          !keyUpper.contains("PAGO MOVIL")) {
        if (keyUpper.contains('USD') || keyUpper.contains('USDT')) {
          saldosVerdes.add(MapEntry(key, monto));
        } else {
          saldosBs.add(MapEntry(key, monto));
        }
      }
    });

    return [...saldosBs, ...saldosVerdes];
  }

  Widget _buildMenuPrincipal(Color azulHeader) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("PANEL PRINCIPAL",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 10),
        _buildMenuButton("1. DISPONIBILIDAD Y TASAS",
            Icons.account_balance_wallet, azulHeader, () async {
          await showDialog(
            context: context,
            builder: (context) =>
                ModalDisponibilidad(tasaUSD: _tasaUSD, tasaUSDT: _tasaUSDT),
          );
          if (!mounted) return;
          _cargarDatosPrincipales();
          _verificarEstadoDia();
        }),
        const SizedBox(height: 8),
        _buildMenuButton(
            "2. OPERACIONES Y EGRESOS", Icons.swap_horiz, azulHeader, () async {
          await showDialog(
            context: context,
            builder: (context) =>
                ModalOperaciones(tasaUSD: _tasaUSD, tasaUSDT: _tasaUSDT),
          );
          if (!mounted) return;
          _refrescarSaldosForzado();
        }),
        const SizedBox(height: 8),
        _buildMenuButton(
            "3. CONCILIACIÓN DIARIA", Icons.check_circle_outline, azulHeader,
            () async {
          await showDialog(
            context: context,
            builder: (context) =>
                ModalConciliacion(tasaUSD: _tasaUSD, tasaUSDT: _tasaUSDT),
          );
          if (!mounted) return;
          _cargarDatosPrincipales();
        }),
        const SizedBox(height: 8),
        _buildMenuButton(
            "4. FICHA TRABAJADOR Y NÓMINA", Icons.badge, azulHeader, () async {
          await showDialog(
            context: context,
            builder: (context) =>
                ModalTrabajador(tasaUSD: _tasaUSD, tasaUSDT: _tasaUSDT),
          );
          if (!mounted) return;
          _cargarDatosPrincipales();
        }),
        const SizedBox(height: 8),
        _buildMenuButton("5. CONSULTAS E HISTORIAL", Icons.history, azulHeader,
            () {
          showDialog(
            context: context,
            builder: (context) => ModalConsultas(tasaUSD: _tasaUSD),
          );
        }),
      ],
    );
  }

  Color _colorDiferencial(double pct) {
    if (pct < 5) return Colors.grey.shade700;
    if (pct < 15) return Colors.amber.shade800;
    if (pct < 25) return Colors.green.shade600;
    return Colors.green.shade800;
  }

  double _pctDiferencial(double tasa) {
    if (_tasaUSD <= 0 || tasa <= 0) return 0.0;
    return ((tasa - _tasaUSD) / _tasaUSD) * 100;
  }

  Widget _tarjetaTasaCompacta({
    required String titulo,
    required double tasa,
    required String sufijo,
    required Color color,
    required IconData icono,
  }) {
    return Expanded(
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icono, size: 10, color: color),
                  const SizedBox(width: 3),
                  Text(
                    titulo,
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(
                  "${tasa.toStringAsFixed(2)} $sufijo",
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaDiferencial(String nombre, double tasa, double pct) {
    final color = _colorDiferencial(pct);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              nombre,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              tasa > 0 ? "${tasa.toStringAsFixed(2)} Bs" : "—",
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              tasa > 0
                  ? "${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)} %"
                  : "—",
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetasTasas(Color azulHeader) {
    final pctUSDT = _pctDiferencial(_tasaUSDT);
    final pctEUR = _pctDiferencial(_tasaEUR);
    final pctValery = _pctDiferencial(_ratioMargen * _tasaUSD);

    return Column(
      children: [
        Row(
          children: [
            _tarjetaTasaCompacta(
              titulo: "BCV",
              tasa: _tasaUSD,
              sufijo: "Bs/\$",
              color: azulHeader,
              icono: Icons.attach_money,
            ),
            const SizedBox(width: 6),
            _tarjetaTasaCompacta(
              titulo: "USDT",
              tasa: _tasaUSDT,
              sufijo: "Bs/₮",
              color: Colors.green.shade700,
              icono: Icons.currency_bitcoin,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _tarjetaTasaCompacta(
              titulo: "EUR",
              tasa: _tasaEUR,
              sufijo: "Bs/€",
              color: Colors.blue.shade700,
              icono: Icons.euro,
            ),
            const SizedBox(width: 6),
            _tarjetaTasaCompacta(
              titulo: "USDT VALERY",
              tasa: _ratioMargen * _tasaUSD,
              sufijo: "Bs/₮",
              color: Colors.purple.shade700,
              icono: Icons.calculate,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, size: 11, color: azulHeader),
                    const SizedBox(width: 4),
                    const Text(
                      "DIFERENCIAL CAMBIARIO (vs BCV)",
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.4),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _filaDiferencial("USDT", _tasaUSDT, pctUSDT),
                _filaDiferencial("EUR", _tasaEUR, pctEUR),
                _filaDiferencial(
                    "USDT VALERY", _ratioMargen * _tasaUSD, pctValery),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaldoCard(MapEntry<String, double> item, Color azulHeader) {
    String nombre = item.key;
    double monto = item.value;

    bool esVerde = nombre.toUpperCase().contains('USD') ||
        nombre.toUpperCase().contains('USDT');
    Color colorValor = esVerde ? Colors.green.shade700 : azulHeader;
    String etiquetaMoneda = nombre.toUpperCase().contains('USDT')
        ? 'USDT'
        : (nombre.toUpperCase().contains('USD') ? '\$' : 'BS');
    bool esCajaFisica = nombre.toUpperCase().contains('CAJA EFECTIVO');
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: ListTile(
        dense: true,
        leading:
            Icon(Icons.account_balance_wallet, color: colorValor, size: 18),
        title: Text(nombre,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        trailing: Text(
          esVerde
              ? "${_fmt.format(monto)} $etiquetaMoneda" // USD y USDT
              : (esCajaFisica
                  ? "${_fmtBs.format((monto / 10).floor() * 10)} $etiquetaMoneda" // SOLO Caja Física
                  : "${_fmt.format(monto)} $etiquetaMoneda"), // Los demás bancos (BBVA, Banesco, etc.)
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: colorValor),
        ),
      ),
    );
  }

  Widget _buildListaSaldos(
      List<MapEntry<String, double>> saldosOrdenados, Color azulHeader,
      {bool shrinkWrap = false}) {
    if (_cargandoInicial) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (saldosOrdenados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text("No hay saldos registrados.",
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      );
    }
    if (shrinkWrap) {
      return Column(
        children: saldosOrdenados
            .map((item) => _buildSaldoCard(item, azulHeader))
            .toList(),
      );
    }
    return ListView.builder(
      itemCount: saldosOrdenados.length,
      itemBuilder: (context, index) =>
          _buildSaldoCard(saldosOrdenados[index], azulHeader),
    );
  }

  Widget _buildContenidoEscritorio(
      Color azulHeader, List<MapEntry<String, double>> saldosOrdenados) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 270,
            child: _buildMenuPrincipal(azulHeader),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTarjetasTasas(azulHeader),
                const SizedBox(height: 14),
                const Text("SALDOS DISPONIBLES EN TIEMPO REAL",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildListaSaldos(saldosOrdenados, azulHeader),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContenidoMovil(
      Color azulHeader, List<MapEntry<String, double>> saldosOrdenados) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMenuPrincipal(azulHeader),
          const SizedBox(height: 16),
          _buildTarjetasTasas(azulHeader),
          const SizedBox(height: 14),
          const Text("SALDOS DISPONIBLES EN TIEMPO REAL",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          _buildListaSaldos(saldosOrdenados, azulHeader, shrinkWrap: true),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color azulHeader = Color(0xFF0F52BA);
    final saldosOrdenados = _procesarSaldos();

    return Scaffold(
      appBar: AppBar(
        title: const Text("CONTROL Y GESTION",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        backgroundColor: azulHeader,
        actions: [
          if (_pendientes > 0 || _errores > 0)
            InkWell(
              onTap: _mostrarPanelCola,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _errores > 0
                      ? Colors.red.shade700
                      : Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      height: 12,
                      width: 12,
                      child: _sincronizandoCola
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : const Icon(Icons.cloud_queue,
                              size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _errores > 0
                          ? "$_errores err · $_pendientes"
                          : "$_pendientes pend",
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                "Fecha: ${DateTime.now().toString().substring(0, 10)}",
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              _cargarDatosPrincipales();
              _sincronizarPendientes();
              _verificarEstadoDia();
            },
            tooltip: "Actualizar",
          ),
        ],
      ),
      body: Column(
        children: [
          if (_mostrarBannerTasa) _buildBannerAmarillo(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final esMovil = constraints.maxWidth < 700;
                if (esMovil) {
                  return _buildContenidoMovil(azulHeader, saldosOrdenados);
                }
                return _buildContenidoEscritorio(azulHeader, saldosOrdenados);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
      String titulo, IconData icono, Color color, VoidCallback? onPressed) {
    final bool bloqueado = onPressed == null;
    final Color colorTexto = bloqueado ? Colors.grey.shade400 : color;

    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bloqueado ? Colors.grey.shade100 : Colors.white,
          foregroundColor: colorTexto,
          elevation: 1,
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Icon(icono, size: 16, color: colorTexto),
            const SizedBox(width: 8),
            Expanded(
              child: Text(titulo,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorTexto),
                  overflow: TextOverflow.ellipsis),
            ),
            if (bloqueado)
              Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
