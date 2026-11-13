// ============================================================================
// FINANZAS PRO — BACKEND
// Versión: 5.7.2 MODIFICADO DEEP 13-11-26 12.27m
// ============================================================================

var SPREADSHEET_ID = "1hUosJCAw9Xtg1pR5zku5TDpIiiji0cM6TDr-COE-Rqc";

function obtenerSpreadsheet() {
  try {
    var active = SpreadsheetApp.getActiveSpreadsheet();
    if (active) return active;
  } catch (e) {}
  if (SPREADSHEET_ID && SPREADSHEET_ID !== "") {
    try {
      return SpreadsheetApp.openById(SPREADSHEET_ID);
    } catch (e) {
      throw new Error("No se pudo abrir el Spreadsheet: " + e.toString());
    }
  }
  throw new Error("Spreadsheet no configurado.");
}

function responderJSON(objeto) {
  return ContentService.createTextOutput(JSON.stringify(objeto))
    .setMimeType(ContentService.MimeType.JSON);
}

function limpiarNumero(valor) {
  if (typeof valor === "number") return valor;
  if (!valor) return 0.0;
  var str = valor.toString().trim();
  var lastComma = str.lastIndexOf(",");
  var lastDot = str.lastIndexOf(".");
  if (lastComma > lastDot) {
    str = str.replace(/\./g, "").replace(",", ".");
  } else if (lastDot > lastComma) {
    str = str.replace(/,/g, "");
  }
  return parseFloat(str) || 0.0;
}

function extraerDatosPeticion(e) {
  var action = "";
  var payload = {};
  try {
    if (e && e.postData && e.postData.contents) {
      try {
        var body = JSON.parse(e.postData.contents);
        action = body.action || "";
        payload = body.payload !== undefined ? body.payload : body;
      } catch (errBody) {}
    }
    if (e && e.parameter) {
      action = action || e.parameter.action || "";
      if (e.parameter.payload) {
        try { payload = JSON.parse(e.parameter.payload); } catch(err) { payload = e.parameter.payload; }
      } else if (Object.keys(payload).length === 0) {
        for (var k in e.parameter) { if (k !== "action") payload[k] = e.parameter[k]; }
      }
    }
    if (typeof payload === 'string') {
       try { payload = JSON.parse(payload); } catch(ex){}
    }
  } catch (err) {}
  return { action: action, payload: payload };
}

function doGet(e) {
  var req = extraerDatosPeticion(e);
  if (req.action !== "") return manejarPeticionApi(req.action, req.payload);
  return responderJSON({ status: "OK", mensaje: "Servidor Activo (GET)" });
}

function doPost(e) {
  var req = extraerDatosPeticion(e);
  if (req.action !== "") return manejarPeticionApi(req.action, req.payload);
  return responderJSON({ status: "OK", mensaje: "Servidor Activo (POST)" });
}

function manejarPeticionApi(action, payload) {
  // GETs NO usan lock
  if (action === "obtenerTasas" || 
      action === "obtenerSaldos" || 
      action === "obtenerCuentas" ||
      action === "obtenerMaestroCuentas" ||
      action === "obtenerTasasHistorico"||
      action === "obtenerTasasPorFecha" ||
      action === "verificarEstadoDelDia"||
      action === "buscarTrabajador" ||
      action === "obtenerConsultasConFecha" ||
      action === "obtenerResumenGerencial" ||
      action === "obtenerPendientes" ||
      action === "obtenerPendientesPorPagar" ||
      action === "buscarGastos" ||
      action === "obtenerEstadisticas" ||
      action === "obtenerCierresDelRango" ||
      action === "obtenerDetalleCierre" ||
      action === "obtenerHistorialPrestamos" ||
      action === "obtenerDetallePorCategoria" ||
      action === "obtenerConciliacionPorCuenta" ||
      action === "obtenerDetalleRecibo") {
    var resG = { status: "ERROR", mensaje: "Acción: " + action };
    try {
      if (action === "obtenerTasas") resG = obtenerTasasConfig();
      else if (action === "obtenerSaldos") resG = obtenerSaldosActuales();
      else if (action === "obtenerCuentas") resG = obtenerCuentas();
      else if (action === "obtenerMaestroCuentas") resG = obtenerMaestroCuentas();
      else if (action === "obtenerTasasHistorico") resG = obtenerTasasHistorico();
      else if (action === "obtenerTasasPorFecha") {
        var fBuscar = payload.fecha || payload.fechaDesde || Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
        try {
          var bcv = obtenerTasa(fBuscar, "BCV");
          var usdt = obtenerTasa(fBuscar, "USDT");
          resG = { status: "SUCCESS", fecha: fBuscar, BCV: bcv, USDT: usdt };
        } catch (e) {
          resG = { status: "ERROR", mensaje: e.toString() };
        }
      }
      else if (action === "verificarEstadoDelDia") resG = verificarEstadoDelDia();
      else if (action === "buscarTrabajador") resG = buscarTrabajadorCompleto(payload);
      else if (action === "obtenerConsultasConFecha") resG = obtenerConsultasConFecha(payload);
      else if (action === "obtenerResumenGerencial") resG = obtenerResumenGerencial(payload);
      else if (action === "obtenerPendientes") resG = obtenerPendientes(payload);
      else if (action === "obtenerPendientesPorPagar") resG = obtenerPendientesPorPagar();
      else if (action === "buscarGastos") resG = buscarGastos(payload);
      else if (action === "obtenerEstadisticas") resG = obtenerEstadisticas(payload);
      else if (action === "obtenerDetallePorCategoria") resG = obtenerDetallePorCategoria(payload);
      else if (action === "obtenerConciliacionPorCuenta") resG = obtenerConciliacionPorCuenta(payload);
      else if (action === "obtenerCierresDelRango") resG = obtenerCierresDelRango(payload);
      else if (action === "obtenerDetalleCierre") resG = obtenerDetalleCierre(payload);
      else if (action === "obtenerHistorialPrestamos") resG = obtenerHistorialPrestamos(payload);
      else if (action === "obtenerDetalleRecibo") resG = obtenerDetalleRecibo(payload);
      else if (action === "auditarIntegridadSaldos") resG = auditarIntegridadSaldos(payload ? payload.dryRun : true);
    } catch (err) {
      return responderJSON({ status: "ERROR", mensaje: "Excepción GET: " + err.toString() });
    }
    return responderJSON(resG);
  }

  // POSTs SÍ usan lock
  var lock = LockService.getScriptLock();
  try {
    if (!lock.tryLock(30000)) {
      return responderJSON({ status: "ERROR", mensaje: "Servidor ocupado." });
    }
    var res = { status: "ERROR", mensaje: "Acción: " + action };
    if (action === "actualizarTasas") res = actualizarTasas(payload);
    else if (action === "backfillTasasHistoricas") res = backfillTasasHistoricas(payload);
    else if (action === "guardarTasaDelDia") res = guardarTasaDelDia(payload);
    else if (action === "actualizarSaldosYTasas") res = actualizarSaldosYTasas(payload);
    else if (action === "registrarCierreJornada") res = registrarCierreJornada(payload);
    else if (action === "obtenerIngresosDeclaradosDelDia") res = obtenerIngresosDeclaradosDelDia(payload);
    else if (action === "procesarOperacionTrabajador") res = procesarOperacionTrabajador(payload);
    else if (action === "registrarTransaccion") res = registrarTransaccion(payload);
    else if (action === "registrarOperacion") res = registrarOperacion(payload);
    else if (action === "registrarIngreso") res = registrarIngreso(payload);
    else if (action === "registrarFaltante") res = registrarFaltante(payload);
    else if (action === "registrarPrestamoTrabajador" || action === "registrarPrestamo") res = registrarPrestamoTrabajador(payload);
    else if (action === "obtenerMovimientosDelDia") res = obtenerMovimientosDelDia(payload);
    else if (action === "obtenerDashboard") res = obtenerDashboard(payload);
    else if (action === "registrarPendiente") res = registrarPendiente(payload);
    else if (action === "marcarPendientePagado") res = marcarPendientePagado(payload);
    else if (action === "registrarCompraDivisa") res = registrarCompraDivisa(payload);
    else if (action === "registrarTraspaso") res = registrarTraspaso(payload);
    else if (action === "registrarCargoFijo") res = registrarCargoFijoMensual(payload);
    else if (action === "anularOperacion") res = anularOperacion(payload);
    else if (action === "registrarNuevoTrabajador") res = registrarNuevoTrabajador(payload);
    else if (action === "darDeBajaTrabajador") res = darDeBajaTrabajador(payload);
    return responderJSON(res);
  } catch (err) {
    return responderJSON({ status: "ERROR", mensaje: "Excepción POST: " + err.toString() });
  } finally {
    lock.releaseLock();
  }
}

// ============================================================================
// 1. TASAS Y SALDOS
// ============================================================================

function obtenerTasasConfig() {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("CONFIG") || ss.getSheetByName("TASAS");
  if (!sheet) return { status: "ERROR", mensaje: "No existe CONFIG", tasaUSD: 827.74, tasaUSDT: 965.00 };
  var data = sheet.getDataRange().getValues();
  var tasas = {
    BCV: 827.74, USDT: 965.00, USD_PARALELO: 950.00, EUR: 900.00,
    COMISION_INTERBANCARIA: 0.003,
    COMISION_CREDICARD: 0.25,
    COMISION_BANCO: 0.75
  };
  for (var i = 1; i < data.length; i++) {
    var clave = data[i][0] ? data[i][0].toString().toUpperCase().trim() : "";
    var valor = limpiarNumero(data[i][1]);
    if (clave === "BCV" || clave === "USD" || clave === "TASAUSD") tasas.BCV = valor;
    else if (clave === "USDT" || clave === "TASAUSDT") tasas.USDT = valor;
    else if (clave === "EUR" || clave === "EURO") tasas.EUR = valor;
    else if (clave === "USD_PARALELO" || clave === "PARALELO") tasas.USD_PARALELO = valor;
    else if (clave === "COMISION_INTERBANCARIA") tasas.COMISION_INTERBANCARIA = valor;
    else if (clave === "COMISION_CREDICARD") tasas.COMISION_CREDICARD = valor;
    else if (clave === "COMISION_BANCO") tasas.COMISION_BANCO = valor;
    else if (clave === "USDT_SEED") tasas.USDT_SEED = valor;
    else if (clave === "BCV_SEED") tasas.BCV_SEED = valor;
  }
  var ratioMargen = 1.2487033;
if (tasas.USDT_SEED && tasas.BCV_SEED && tasas.BCV_SEED > 0) {
  ratioMargen = tasas.USDT_SEED / tasas.BCV_SEED;
}
return {
  status: "SUCCESS", tasas: tasas,
  tasaUSD: tasas.BCV, tasaUSDT: tasas.USDT,
  comisionCredicard: tasas.COMISION_CREDICARD,
  comisionBanco: tasas.COMISION_BANCO,
  ratioMargen: ratioMargen,
  usdtSeed: tasas.USDT_SEED || 0,
  bcvSeed: tasas.BCV_SEED || 0
};
}

function obtenerSaldosActuales() {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("SALDOS");
  if (!sheet) return { status: "ERROR", mensaje: "No existe SALDOS", saldos: [], saldosMap: {} };
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return { status: "SUCCESS", saldos: [], saldosMap: {} };
  var data = sheet.getRange(2, 1, lastRow - 1, 2).getValues();
  var saldosArray = [];
  var saldosMap = {};
  for (var i = 0; i < data.length; i++) {
    var cuenta = data[i][0] ? data[i][0].toString().trim() : "";
    if (cuenta !== "") {
      var monto = limpiarNumero(data[i][1]);
      saldosArray.push({ cuenta: cuenta, monto: monto });
      saldosMap[cuenta] = monto;
    }
  }
  var respuesta = { status: "SUCCESS", saldos: saldosArray, saldosMap: saldosMap };
  return respuesta;
}

function obtenerCuentas() {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("SALDOS");
  if (!sheet) return { status: "ERROR", cuentas: [] };
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return { status: "SUCCESS", cuentas: [] };
  var data = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  var cuentas = [];
  for (var i = 0; i < data.length; i++) {
    var nombre = data[i][0] ? data[i][0].toString().trim() : "";
    if (nombre !== "") cuentas.push(nombre);
  }
  return { status: "SUCCESS", cuentas: cuentas };
}

function obtenerMaestroCuentas() {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("MAESTRO_CUENTAS");
  if (!sheet) {
    sheet = ss.insertSheet("MAESTRO_CUENTAS");
    sheet.appendRow(["Nombre", "Moneda", "Afecta_Cierre"]);
  }
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) {
    return { status: "SUCCESS", cuentas: [] };
  }
  var data = sheet.getRange(2, 1, lastRow - 1, 3).getValues();
  var cuentas = [];
  for (var i = 0; i < data.length; i++) {
    var nombre = data[i][0] ? data[i][0].toString().trim() : "";
    if (nombre !== "") {
      cuentas.push({
        nombre: nombre,
        moneda: data[i][1] ? data[i][1].toString().trim().toUpperCase() : "BS",
        afectaCierre: data[i][2] === true || (data[i][2] && data[i][2].toString().toUpperCase() === "SI") || data[i][2] === "S"
      });
    }
  }
  return { status: "SUCCESS", cuentas: cuentas };
}

function obtenerSaldoCuenta(sheetSaldos, nombreCuenta) {
  var lastRow = sheetSaldos.getLastRow();
  if (lastRow < 2) return 0.0;
  var data = sheetSaldos.getRange(2, 1, lastRow - 1, 2).getValues();
  var keyCleanBuscada = nombreCuenta.toUpperCase().replace(/[_ ]/g, "");
  for (var i = 0; i < data.length; i++) {
    var ctaFila = data[i][0] ? data[i][0].toString().trim() : "";
    var keyCleanFila = ctaFila.toUpperCase().replace(/[_ ]/g, "");
    if (keyCleanFila === keyCleanBuscada) {
      return limpiarNumero(data[i][1]);
    }
  }
  return 0.0;
}

// ============================================================================
// 2. TASAS Y FUENTE DE VERDAD CAMBIARIA (HOJA TASAS)
// ============================================================================

function obtenerHojaTasas(ss) {
  if (!ss) ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("TASAS");
  if (!sheet) {
    sheet = ss.insertSheet("TASAS");
    sheet.appendRow(["FECHA", "FUENTE", "MONEDA_BASE", "MONEDA_COTIZADA", "VALOR", "USUARIO", "TIMESTAMP"]);
  }
  return sheet;
}

function obtenerTasa(fecha, fuente) {
  var fuenteNorm = (fuente || "BCV").toString().toUpperCase().trim();
  var fechaBusqueda = fecha ? fecha.toString().substring(0, 10) : Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("TASAS");
  
  if (sheet) {
    var lastRow = sheet.getLastRow();
    if (lastRow >= 2) {
      var data = sheet.getRange(2, 1, lastRow - 1, 7).getValues();
      var mejorTasa = null;
      var mejorFecha = "";

      for (var i = 0; i < data.length; i++) {
        var row = data[i];
        var fRow = _normalizarFecha(row[0], "America/Caracas");
        var fuenteRow = (row[1] || "").toString().trim().toUpperCase();
        var valor = limpiarNumero(row[4]);

        if (fuenteRow === fuenteNorm && fRow !== "" && fRow <= fechaBusqueda && valor > 0) {
          if (mejorFecha === "" || fRow > mejorFecha) {
            mejorFecha = fRow;
            mejorTasa = valor;
          }
        }
      }
      if (mejorTasa !== null && mejorTasa > 0) return mejorTasa;
    }
  }

  // Fallback 1: TASAS_HISTORICO
  try {
    var tf = obtenerTasaPorFecha(fechaBusqueda);
    if (tf && tf[fuenteNorm] && tf[fuenteNorm] > 0) return tf[fuenteNorm];
    if (tf && tf.BCV && tf.BCV > 0) return tf.BCV;
  } catch (e) {}

  // Fallback 2: CONFIG (la tasa actual)
  try {
    var cfg = obtenerTasasConfig();
    if (cfg && cfg.tasas && cfg.tasas[fuenteNorm] && cfg.tasas[fuenteNorm] > 0) return cfg.tasas[fuenteNorm];
    if (cfg && cfg.tasas && cfg.tasas.BCV && cfg.tasas.BCV > 0) return cfg.tasas.BCV;
    if (cfg && cfg.tasaUSD && cfg.tasaUSD > 0) return cfg.tasaUSD;
  } catch (e) {}
  
  return 1.0;
}

function actualizarTasas(payload) {
  if (!payload || typeof payload !== "object") {
    return { status: "ERROR", mensaje: "Payload de tasas inválido" };
  }

  var ss = obtenerSpreadsheet();
  var sheetConfig = ss.getSheetByName("CONFIG");
  var sheetTasas = obtenerHojaTasas(ss);

  var fechaHoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  var timestamp = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd HH:mm:ss");
  var usuario = (payload.usuario || payload.USUARIO || "SISTEMA").toString().trim();

  var mapaTasas = {};
  if (payload.BCV !== undefined || payload.tasaUSD !== undefined) {
    mapaTasas["BCV"] = limpiarNumero(payload.BCV !== undefined ? payload.BCV : payload.tasaUSD);
  }
  if (payload.USDT !== undefined || payload.tasaUSDT !== undefined) {
    mapaTasas["USDT"] = limpiarNumero(payload.USDT !== undefined ? payload.USDT : payload.tasaUSDT);
  }
  if (payload.USD_PARALELO !== undefined || payload.tasaUSDTParalelo !== undefined || payload.PARALELO !== undefined) {
    mapaTasas["USD_PARALELO"] = limpiarNumero(payload.USD_PARALELO !== undefined ? payload.USD_PARALELO : (payload.tasaUSDTParalelo !== undefined ? payload.tasaUSDTParalelo : payload.PARALELO));
  }
  if (payload.EUR !== undefined || payload.tasaEUR !== undefined) {
    mapaTasas["EUR"] = limpiarNumero(payload.EUR !== undefined ? payload.EUR : payload.tasaEUR);
  }

  var contador = 0;

  // 1. Escribir en CONFIG (tasa actual para compatibilidad)
  if (sheetConfig) {
    var dataC = sheetConfig.getDataRange().getValues();
    for (var fuente in mapaTasas) {
      var val = mapaTasas[fuente];
      if (val <= 0) continue;
      var act = false;
      for (var i = 1; i < dataC.length; i++) {
        var clave = dataC[i][0] ? dataC[i][0].toString().toUpperCase().trim() : "";
        if ((fuente === "BCV" && (clave === "BCV" || clave === "USD")) ||
            (fuente === "USDT" && clave === "USDT") ||
            (fuente === "EUR" && (clave === "EUR" || clave === "EURO")) ||
            (fuente === "USD_PARALELO" && (clave === "USD_PARALELO" || clave === "USDT_PARALELO" || clave === "PARALELO"))) {
          sheetConfig.getRange(i + 1, 2).setValue(val);
          act = true;
          break;
        }
      }
      if (!act) {
        sheetConfig.appendRow([fuente, val]);
      }
    }
  }

  // 2. Insertar SIEMPRE nueva fila en TASAS con timestamp
  for (var fFuente in mapaTasas) {
    var valorTasa = mapaTasas[fFuente];
    if (valorTasa <= 0) continue;

    var monedaBase = "USD";
    var monedaCotizada = "BS";
    if (fFuente === "EUR") monedaBase = "EUR";

    var tipoFuente = (payload.fuente || payload.FUENTE || fFuente).toString().toUpperCase();
    if (tipoFuente !== "MANUAL" && tipoFuente !== "BCV" && tipoFuente !== "USDT" && tipoFuente !== "USD_PARALELO" && tipoFuente !== "EUR") {
      tipoFuente = fFuente;
    }

    sheetTasas.appendRow([
      fechaHoy,
      tipoFuente,
      monedaBase,
      monedaCotizada,
      valorTasa,
      usuario,
      timestamp
    ]);
    contador++;
  }

  // Guardar también en TASAS_HISTORICO por compatibilidad
  try {
    guardarTasaDelDia({
      BCV: mapaTasas["BCV"] || 0,
      USDT: mapaTasas["USDT"] || 0,
      EUR: mapaTasas["EUR"] || 0,
      USD_PARALELO: mapaTasas["USD_PARALELO"] || 0
    });
  } catch (e) {}

  return {
    status: "SUCCESS",
    mensaje: "Tasas actualizadas correctamente",
    actualizados: contador,
    fecha: fechaHoy
  };
}

function backfillTasasHistoricas(payloadOrDryRun) {
  var dryRun = true;
  if (payloadOrDryRun === false || (typeof payloadOrDryRun === "object" && payloadOrDryRun.dryRun === false) || payloadOrDryRun === "false") {
    dryRun = false;
  }

  var ss = obtenerSpreadsheet();
  var sheetHist = ss.getSheetByName("HISTORIAL");
  if (!sheetHist) {
    return { status: "ERROR", mensaje: "No existe la hoja HISTORIAL" };
  }

  var lastRow = sheetHist.getLastRow();
  if (lastRow < 2) {
    return { status: "SUCCESS", dryRun: dryRun, totalFilas: 0, modificadas: 0, sinTasa: 0, detalles: [] };
  }

  var data = sheetHist.getRange(2, 1, lastRow - 1, 19).getValues();
  var modificadas = 0;
  var sinTasa = 0;
  var omitidasConTasa = 0;
  var detalles = [];

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var idTx = row[0] ? row[0].toString().trim() : "";
    if (!idTx || idTx.indexOf("TX-") !== 0) continue;

    var tasaExistente = row[16] !== undefined && row[16] !== "" ? limpiarNumero(row[16]) : 0;
    if (tasaExistente > 0) {
      omitidasConTasa++;
      continue;
    }

    var fecha = _normalizarFecha(row[1], "America/Caracas");
    var moneda = (row[6] || "BS").toString().trim().toUpperCase();
    var monto = limpiarNumero(row[5] || row[7] || 0);
    var fuente = moneda === "USDT" ? "USDT" : (moneda === "EUR" ? "EUR" : "BCV");

    var tasaEncontrada = 0;

    // 1. Buscar en TASAS
    try {
      tasaEncontrada = obtenerTasa(fecha, fuente);
    } catch (e1) {
      // 2. Fallback a TASAS_HISTORICO
      try {
        var tasaHist = obtenerTasaPorFecha(fecha);
        if (tasaHist) {
          if (fuente === "USDT") tasaEncontrada = tasaHist.USDT || tasaHist.BCV;
          else if (fuente === "EUR") tasaEncontrada = tasaHist.EUR || tasaHist.BCV;
          else tasaEncontrada = tasaHist.BCV;
        }
      } catch (e2) {}
    }

    // 3. Fallback a tasaUSD de la columna 10/K si ya venía en el registro legado
    if (tasaEncontrada <= 0 && row[10] && limpiarNumero(row[10]) > 0) {
      tasaEncontrada = limpiarNumero(row[10]);
    }

    if (tasaEncontrada > 0) {
      var montoBs = (moneda === "USD" || moneda === "USDT" || moneda === "EUR") ? (monto * tasaEncontrada) : monto;
      modificadas++;
      detalles.push({
        fila: i + 2,
        idTx: idTx,
        fecha: fecha,
        moneda: moneda,
        monto: monto,
        tasa: tasaEncontrada,
        fuenteTasa: "BACKFILL",
        montoBs: montoBs,
        estado: "OK"
      });

      if (!dryRun) {
        sheetHist.getRange(i + 2, 17).setValue(tasaEncontrada);
        sheetHist.getRange(i + 2, 18).setValue("BACKFILL");
        sheetHist.getRange(i + 2, 19).setValue(montoBs);
        try { sheetHist.getRange(i + 2, 17).clearNote(); } catch (eNote) {}
      }
    } else {
      sinTasa++;
      var nota = "AUDITORÍA: Tasa no encontrada para fecha " + fecha + " y fuente " + fuente;
      detalles.push({
        fila: i + 2,
        idTx: idTx,
        fecha: fecha,
        moneda: moneda,
        monto: monto,
        tasa: null,
        fuenteTasa: null,
        montoBs: null,
        estado: "SIN_TASA",
        nota: nota
      });

      if (!dryRun) {
        sheetHist.getRange(i + 2, 17).setNote(nota);
      }
    }
  }

  return {
    status: "SUCCESS",
    dryRun: dryRun,
    totalFilas: data.length,
    modificadas: modificadas,
    sinTasa: sinTasa,
    omitidasConTasa: omitidasConTasa,
    detalles: detalles
  };
}

function guardarTasaDelDia(payload) {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("TASAS_HISTORICO");
  if (!sheet) return { status: "ERROR", mensaje: "No existe TASAS_HISTORICO" };

  var fechaHoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  var bcv = limpiarNumero(payload.BCV || 0);
  var usdt = limpiarNumero(payload.USDT || 0);
  var eur = limpiarNumero(payload.EUR || 0);
  var paralelo = limpiarNumero(payload.USD_PARALELO || 0);

  var lastRow = sheet.getLastRow();
  var data = lastRow >= 2 ? sheet.getRange(2, 1, lastRow - 1, 5).getValues() : [];

  for (var i = 0; i < data.length; i++) {
    var fechaFila = "";
    try {
      var f = data[i][0];
      if (f instanceof Date) fechaFila = Utilities.formatDate(f, "America/Caracas", "yyyy-MM-dd");
      else fechaFila = f.toString().substring(0, 10);
    } catch (e) { fechaFila = data[i][0].toString().substring(0, 10); }

    if (fechaFila === fechaHoy) {
      sheet.getRange(i + 2, 1, 1, 5).setValues([[fechaHoy, bcv, usdt, eur, paralelo]]);
      return { status: "SUCCESS", mensaje: "Tasa del día actualizada", fecha: fechaHoy };
    }
  }

  sheet.appendRow([fechaHoy, bcv, usdt, eur, paralelo]);
  return { status: "SUCCESS", mensaje: "Tasa del día guardada", fecha: fechaHoy };
}

function obtenerTasasHistorico() {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("TASAS_HISTORICO");
  if (!sheet) return { status: "ERROR", historico: [] };

  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return { status: "SUCCESS", historico: [] };

  var data = sheet.getRange(2, 1, lastRow - 1, 5).getValues();
  var historico = [];
  for (var i = 0; i < data.length; i++) {
    var fecha = "";
    try {
      var f = data[i][0];
      if (f instanceof Date) fecha = Utilities.formatDate(f, "America/Caracas", "yyyy-MM-dd");
      else fecha = f.toString().substring(0, 10);
    } catch (e) { fecha = data[i][0].toString().substring(0, 10); }

    historico.push({
      fecha: fecha,
      BCV: limpiarNumero(data[i][1]),
      USDT: limpiarNumero(data[i][2]),
      EUR: limpiarNumero(data[i][3]),
      USD_PARALELO: limpiarNumero(data[i][4])
    });
  }
  return { status: "SUCCESS", historico: historico };
}

function obtenerTasaPorFecha(fecha) {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("TASAS_HISTORICO");
  if (!sheet) return null;

  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return null;

  var data = sheet.getRange(2, 1, lastRow - 1, 5).getValues();
  for (var i = 0; i < data.length; i++) {
    // ESTA ES LA MAGIA: Convierte "27/10/2026" a "2026-10-27" para poder compararlo
    var fechaFila = _normalizarFecha(data[i][0], "America/Caracas"); 
    
    if (fechaFila === fecha) {
      return {
        fecha: fecha,
        BCV: limpiarNumero(data[i][1]),
        USDT: limpiarNumero(data[i][2]),
        EUR: limpiarNumero(data[i][3]),
        USD_PARALELO: limpiarNumero(data[i][4])
      };
    }
  }
  return null;
}

function _r2(num) {
  var val = limpiarNumero(num);
  return Math.round((val + Number.EPSILON) * 100) / 100;
}

function obtenerTasa(fecha, fuente) {
  var fuenteNorm = (fuente || "BCV").toString().toUpperCase().trim();
  var fechaNorm = fecha ? fecha.toString().substring(0, 10) : "";
  if (fechaNorm) {
    try {
      var tf = obtenerTasaPorFecha(fechaNorm);
      if (tf && tf[fuenteNorm] && tf[fuenteNorm] > 0) return tf[fuenteNorm];
      if (tf && tf.BCV && tf.BCV > 0) return tf.BCV;
    } catch (e) {}
  }
  try {
    var cfg = obtenerTasasConfig();
    if (cfg && cfg.tasas && cfg.tasas[fuenteNorm] && cfg.tasas[fuenteNorm] > 0) return cfg.tasas[fuenteNorm];
    if (cfg && cfg.tasas && cfg.tasas.BCV && cfg.tasas.BCV > 0) return cfg.tasas.BCV;
    if (cfg && cfg.tasaUSD && cfg.tasaUSD > 0) return cfg.tasaUSD;
  } catch (e) {}
  return 1.0;
}

function buscarCuenta(nombreCuenta) {
  var nombreClean = (nombreCuenta || "").toString().trim();
  if (!nombreClean) return { cuentaId: "", nombre: "", moneda: "BS" };

  try {
    var mc = obtenerMaestroCuentas();
    if (mc && mc.cuentas && mc.cuentas.length > 0) {
      var keyBuscada = nombreClean.toUpperCase().replace(/[_ ]/g, "");
      for (var i = 0; i < mc.cuentas.length; i++) {
        var c = mc.cuentas[i];
        var keyFila = (c.nombre || "").toUpperCase().replace(/[_ ]/g, "");
        if (keyFila === keyBuscada) {
          return {
            cuentaId: c.nombre,
            nombre: c.nombre,
            moneda: (c.moneda || "BS").toUpperCase()
          };
        }
      }
    }
  } catch (e) {}

  var nameUpper = nombreClean.toUpperCase();
  var moneda = "BS";
  if (nameUpper.indexOf("USDT") !== -1 || nameUpper.indexOf("BINANCE") !== -1) {
    moneda = "USDT";
  } else if (nameUpper.indexOf("USD") !== -1 || nameUpper.indexOf("DOLAR") !== -1 || nameUpper.indexOf("DÓLAR") !== -1 || nameUpper.indexOf("CASH USD") !== -1) {
    moneda = "USD";
  } else if (nameUpper.indexOf("EUR") !== -1 || nameUpper.indexOf("EURO") !== -1) {
    moneda = "EUR";
  }

  return {
    cuentaId: nombreClean,
    nombre: nombreClean,
    moneda: moneda
  };
}

function monedaDeCuenta(nombreCuenta) {
  var c = buscarCuenta(nombreCuenta);
  return c ? c.moneda : "BS";
}

function obtenerDiaSiguienteHabil(fechaStr) {
  var fecha = new Date(fechaStr + "T12:00:00");
  fecha.setDate(fecha.getDate() + 1);
  var diaSemana = fecha.getDay();
  if (diaSemana === 6) fecha.setDate(fecha.getDate() + 2);
  else if (diaSemana === 0) fecha.setDate(fecha.getDate() + 1);
  return Utilities.formatDate(fecha, "America/Caracas", "yyyy-MM-dd");
}

// ============================================================================
// 3. TRABAJADORES
// ============================================================================

function buscarTrabajadorCompleto(params) {
  var busqueda = "";
  if (params) busqueda = (params.cedula || params.ci || params.id || params.busqueda || "").toString().trim().toUpperCase();
  if (busqueda === "" && typeof params === "string") busqueda = params.trim().toUpperCase();
  
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("NOMINA_PERSONAL") || ss.getSheetByName("TRABAJADORES") || ss.getSheetByName("PERSONAL");
  if (!sheet) return { status: "ERROR", encontrado: false, mensaje: "No existe pestaña de trabajadores" };
  
  var data = sheet.getDataRange().getValues();
  var cleanBusquedaNum = busqueda.replace(/[^0-9]/g, "");
  var resultados = [];
  
  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    var cedulaFila = (row[2] || row[0] || "").toString().trim();
    var nombreFila = (row[1] || "").toString().trim().toUpperCase();
    var cleanCedulaFila = cedulaFila.replace(/[^0-9]/g, "");
    
    var coincide = false;
    if (cleanBusquedaNum !== "" && cleanCedulaFila === cleanBusquedaNum) coincide = true;
    else if (busqueda !== "" && nombreFila.indexOf(busqueda) !== -1) coincide = true;
    
    if (coincide) {
      var fechaIng = "2026-01-01";
      if (row[4]) {
        try { fechaIng = Utilities.formatDate(new Date(row[4]), "America/Caracas", "yyyy-MM-dd"); }
        catch (e) { fechaIng = row[4].toString().substring(0, 10); }
      }
      var adicionales = [];
      if (row[12]) {
        try { adicionales = JSON.parse(row[12].toString()); if (!Array.isArray(adicionales)) adicionales = []; } catch (e) { adicionales = []; }
      }
      var itemTrabajador = {
        status: "SUCCESS", encontrado: true,
        nombre: row[1] ? row[1].toString() : "Sin Nombre",
        cedula: cedulaFila, 
        cargo: row[3] ? row[3].toString() : "",
        fechaIngreso: fechaIng,
        sueldoBase: limpiarNumero(row[5]), 
        ayudaFamiliar: limpiarNumero(row[6]),
        frecuencia: row[7] ? row[7].toString() : "", 
        estado: row[8] ? row[8].toString() : "",
        deudaPendiente: limpiarNumero(row[9] || 0), 
        bonoAlimenticio: limpiarNumero(row[10] || 0),
        fechaEgreso: row[11] ? row[11].toString().substring(0, 10) : "", 
        adicionales: adicionales
      };
      resultados.push(itemTrabajador);
    }
  }

  if (resultados.length > 0) {
    var respuesta = {};
    for (var k in resultados[0]) {
      respuesta[k] = resultados[0][k];
    }
    respuesta.resultados = resultados;
    return respuesta;
  }

  return { status: "SUCCESS", encontrado: false, debug: "Trabajador no encontrado" };
}

// ============================================================================
// 4. CONSULTAS
// ============================================================================

function obtenerConsultasConFecha(params) {
  var fechaDesde = "";
  var fechaHasta = "";
  if (params) {
    fechaDesde = (params.fechaDesde || params.fecha || params.date || "").toString().trim();
    fechaHasta = (params.fechaHasta || params.fecha || params.date || fechaDesde).toString().trim();
  }
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("HISTORIAL");
  if (!sheet) return { status: "ERROR", mensaje: "Falta HISTORIAL", movimientos: [], gastos: [], totalEgresos: 0, totalNomina: 0, totalVentas: 0 };

  var movimientos = [];
  var gastos = [];
  var totalEgresos = 0.0, totalNomina = 0.0, totalVentas = 0.0, totalComisiones = 0.0;
  var resumenCat = {}, resumenTipo = {};
  var tz = "America/Caracas";

  var lastRow = sheet.getLastRow();
  if (lastRow > 1) {
    var data = sheet.getRange(2, 1, lastRow - 1, 19).getValues();
    for (var i = 0; i < data.length; i++) {
      var row = data[i];
      var idTx = row[0] ? row[0].toString().trim().toUpperCase() : "";
      if (idTx.indexOf("TX-") !== 0) continue;

      var f = "";
      try {
        var valFecha = row[1];
        if (valFecha instanceof Date) f = Utilities.formatDate(valFecha, tz, "yyyy-MM-dd");
        else f = valFecha.toString().substring(0, 10);
      } catch (err) { f = row[1].toString().substring(0, 10); }

      var enRango = false;
      if (fechaDesde === "" && fechaHasta === "") enRango = true;
      else if (f >= fechaDesde && f <= fechaHasta) enRango = true;

      if (enRango) {
        var tipo = row[2] ? row[2].toString().toUpperCase() : "OPERACION";
        var monto = limpiarNumero(row[5]);
        var montoNeto = limpiarNumero(row[7]);
        var comision = limpiarNumero(row[8]);
        var categoria = row[12] ? row[12].toString() : "";
        var monedaVal = row[6] ? row[6].toString() : "BS";

        var tasaVal = (row[16] !== undefined && row[16] !== "") ? limpiarNumero(row[16]) : limpiarNumero(row[10]);
        var fuenteTasaVal = row[17] ? row[17].toString() : (tasaVal > 0 ? "BCV" : "");
        var montoBsVal = (row[18] !== undefined && row[18] !== "") ? limpiarNumero(row[18]) : ((monedaVal === "USD" || monedaVal === "USDT") ? monto * tasaVal : monto);

        var mov = {
          idTx: idTx, fecha: f, tipo: tipo,
          origen: row[3] ? row[3].toString() : "",
          destino: row[4] ? row[4].toString() : "",
          monto: monto, moneda: monedaVal,
          montoNeto: montoNeto, comision: comision,
          concepto: row[9] ? row[9].toString() : "",
          tasaUsd: limpiarNumero(row[10]),
          tasaUsdt: limpiarNumero(row[11]),
          tasa: tasaVal,
          fuenteTasa: fuenteTasaVal,
          montoBs: montoBsVal,
          categoria: categoria
        };
        movimientos.push(mov);

        if ((tipo.indexOf("EGRESO") !== -1 || tipo.indexOf("GASTO") !== -1 || tipo.indexOf("CARGO") !== -1) && categoria !== "PRESTAMO_TRABAJADOR" && categoria !== "PRESTAMO" && tipo !== "PRESTAMO") {
          totalEgresos += monto; gastos.push(mov);
        } else if (tipo.indexOf("NOMINA") !== -1 || tipo.indexOf("PAGO_NOMINA") !== -1 || tipo.indexOf("LIQUIDACION") !== -1) {
          totalNomina += monto; gastos.push(mov);
        } else if (tipo.indexOf("VENTA") !== -1 || tipo.indexOf("CIERRE") !== -1) {
          totalVentas += montoNeto;
        }
        if (comision > 0) totalComisiones += comision;
        if (categoria !== "") {
          if (!resumenCat[categoria]) resumenCat[categoria] = 0;
          resumenCat[categoria] += monto;
        }
        if (!resumenTipo[tipo]) resumenTipo[tipo] = 0;
        resumenTipo[tipo] += monto;
      }
    }
  }

  var arrCat = [];
  for (var c in resumenCat) arrCat.push({ categoria: c, totalBs: resumenCat[c] });
  var arrTipo = [];
  for (var t in resumenTipo) arrTipo.push({ tipo: t, totalBs: resumenTipo[t] });

  var difCambiaria = null;
  if (fechaDesde !== "") {
    difCambiaria = calcularDiferenciaCambiariaDia(fechaDesde, totalVentas);
  }

  return {
    status: "SUCCESS", movimientos: movimientos, gastos: gastos,
    totales: { registros: movimientos.length, egresos: totalEgresos, nomina: totalNomina, ventas: totalVentas, comisiones: totalComisiones },
    resumenPorCategoria: arrCat, resumenPorTipo: arrTipo,
    totalEgresos: totalEgresos, totalNomina: totalNomina, totalVentas: totalVentas,
    diferenciaCambiaria: difCambiaria
  };
}

// ============================================================================
// 5. CÁLCULO DIFERENCIA CAMBIARIA
// ============================================================================

function calcularDiferenciaCambiariaDia(fechaCierre, montoBsVendido) {
  if (!fechaCierre || montoBsVendido <= 0) return null;

  var tasaCierre = obtenerTasaPorFecha(fechaCierre);
  if (!tasaCierre || !tasaCierre.BCV) return null;

  var diaSiguiente = obtenerDiaSiguienteHabil(fechaCierre);
  var tasaAcred = obtenerTasaPorFecha(diaSiguiente);

  var valorCierre = montoBsVendido / tasaCierre.BCV;
  var valorAcred = null;
  var difAcred = null;

  if (tasaAcred && tasaAcred.BCV) {
    valorAcred = montoBsVendido / tasaAcred.BCV;
    difAcred = valorAcred - valorCierre;
  }

  return {
    fechaCierre: fechaCierre,
    fechaAcreditacion: diaSiguiente,
    montoBsVendido: montoBsVendido,
    tasaCierre: tasaCierre.BCV,
    tasaAcreditacion: tasaAcred ? tasaAcred.BCV : 0,
    valorCierre: valorCierre,
    valorAcreditacion: valorAcred || 0,
    diferenciaUSD: difAcred || 0,
    diferenciaPct: valorCierre > 0 ? ((difAcred || 0) / valorCierre * 100) : 0
  };
}

function guardarDiferenciaCambiaria(idCierre, fechaCierre, montoBs) {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("DIFERENCIAS_CAMBIARIAS");
  if (!sheet) return null;

  var calc = calcularDiferenciaCambiariaDia(fechaCierre, montoBs);
  if (!calc) return null;

  sheet.appendRow([
    idCierre,
    fechaCierre,
    montoBs,
    calc.tasaCierre,
    calc.tasaAcreditacion,
    calc.valorCierre,
    calc.valorAcreditacion,
    calc.diferenciaUSD
  ]);

  return calc;
}

// ============================================================================
// 6. CIERRE DE JORNADA
// ============================================================================
function registrarCierreJornada(payload) {
  var ss = obtenerSpreadsheet();
  var sheetHistorial = ss.getSheetByName("HISTORIAL");
  var sheetSaldos = ss.getSheetByName("SALDOS");
  var sheetCierres = ss.getSheetByName("HISTORIAL_CIERRES");

  if (!sheetHistorial) return { status: "ERROR", mensaje: "No existe HISTORIAL" };
  if (!sheetSaldos) return { status: "ERROR", mensaje: "No existe SALDOS" };

  var fechaOpStr = (payload.fechaOperativa || payload.fechaOperacion || "").toString().trim();
  var fechaCierre = new Date();
  if (fechaOpStr !== "") {
    try {
      var fp = new Date(fechaOpStr + "T12:00:00");
      if (!isNaN(fp.getTime())) fechaCierre = fp;
    } catch (e) {}
  }
  var fechaOp = Utilities.formatDate(fechaCierre, "America/Caracas", "yyyy-MM-dd");
  
  // === AUTO-CÁLCULO DE GASTOS Y PRÉSTAMOS DESDE LA VENTA DEL DÍA ===
  var totalVentaDiaUsado = 0;
  var histCheck = sheetHistorial.getDataRange().getValues();
  for (var hc = 1; hc < histCheck.length; hc++) {
    var rowHC = histCheck[hc];
    var fechaHC = _normalizarFecha(rowHC[1], "America/Caracas");
    var origenHC = (rowHC[14] || "ACUMULADO").toString().toUpperCase();
    
    if (fechaHC === fechaOp && origenHC === "VENTA_DIA") {
      var tipoHC = (rowHC[2] || "").toString().toUpperCase();
      if (tipoHC.indexOf("EGRESO") !== -1 || tipoHC.indexOf("PRESTAMO") !== -1 || tipoHC.indexOf("GASTO") !== -1) {
        var montoHC = limpiarNumero(rowHC[5]);
        totalVentaDiaUsado += montoHC;
      }
    }
  }

  var tasaBCV = _r2(limpiarNumero(payload.tasaUSD || payload.tasaBCV || obtenerTasa(fechaOp, "BCV")));
  var tasaUSDT = _r2(limpiarNumero(payload.tasaUSDT || obtenerTasa(fechaOp, "USDT")));

  // === IDEMPOTENCIA ===
  var idempotenciaKey = (payload.idempotenciaKey || "").toString().trim();
  if (idempotenciaKey !== "") {
    var histCheck = sheetHistorial.getDataRange().getValues();
    var inicioBusqueda = histCheck.length > 100 ? histCheck.length - 100 : 1;
    for (var hi = inicioBusqueda; hi < histCheck.length; hi++) {
      var conceptoFila = histCheck[hi][9] ? histCheck[hi][9].toString() : "";
      var sufijoKey = "IDEMP:" + idempotenciaKey;
      if (conceptoFila.indexOf(sufijoKey) !== -1) {
        return {
          status: "SUCCESS", exito: true,
          idTx: histCheck[hi][0].toString(),
          mensaje: "Cierre ya registrado (idempotencia)",
          duplicado: true
        };
      }
    }
  }

  var idCierre = "CJ-" + Utilities.formatDate(fechaCierre, "America/Caracas", "yyyyMMdd") + "-" + Math.floor(Math.random() * 900 + 100);
  var marcaIdemp = idempotenciaKey !== "" ? " | IDEMP:" + idempotenciaKey : "";

  // Normalizar ítems de desglose / bancos
  var itemsArray = [];
  if (Array.isArray(payload.bancos)) {
    for (var bi = 0; bi < payload.bancos.length; bi++) {
      var b = payload.bancos[bi];
      if (!b) continue;
      var ctaB = b.cuenta || b.nombreCuenta || b.nombre || "";
      var brutoB = _r2(limpiarNumero(b.montoBruto !== undefined ? b.montoBruto : (b.bruto !== undefined ? b.bruto : (b.monto || b.punto || 0))));
      var comB = _r2(limpiarNumero(b.comision !== undefined ? b.comision : 0));
      var monB = (b.moneda || monedaDeCuenta(ctaB)).toString().toUpperCase().trim();
      if (ctaB && (brutoB > 0 || comB > 0)) {
        itemsArray.push({
          cuenta: ctaB, punto: brutoB, pagoMovil: 0, comision: comB, moneda: monB
        });
      }
    }
  } else {
    var desglose = payload.desglose || payload.cuentasDesglose || payload.partidas || null;
    if (typeof desglose === "string") {
      try { desglose = JSON.parse(desglose); } catch (e) { desglose = null; }
    }
    if (Array.isArray(desglose)) {
      for (var di = 0; di < desglose.length; di++) {
        var itemD = desglose[di];
        if (!itemD) continue;
        var ctaD = itemD.cuenta || itemD.nombre || "";
        var pD = _r2(limpiarNumero(itemD.punto || itemD.montoBruto || itemD.monto || 0));
        var pmD = _r2(limpiarNumero(itemD.pagoMovil || 0));
        var comD = _r2(limpiarNumero(itemD.comision || 0));
        var monD = (itemD.moneda || monedaDeCuenta(ctaD)).toString().toUpperCase().trim();
        if (ctaD && (pD > 0 || pmD > 0 || comD > 0)) {
          itemsArray.push({
            cuenta: ctaD, punto: pD, pagoMovil: pmD, comision: comD, moneda: monD
          });
        }
      }
    } else if (desglose && typeof desglose === "object") {
      for (var nombreCuenta in desglose) {
        var itemObj = desglose[nombreCuenta];
        var punto = 0, pagoMovil = 0, comisionObj = 0;
        var c1Activa = false, c1Pct = 0.25;
        var c2Activa = false, c2Pct = 0.75;
        var monedaItem = monedaDeCuenta(nombreCuenta);

        if (typeof itemObj === "object" && itemObj !== null) {
          punto = _r2(limpiarNumero(itemObj.punto || itemObj.montoBruto || 0));
          pagoMovil = _r2(limpiarNumero(itemObj.pagoMovil || 0));
          comisionObj = _r2(limpiarNumero(itemObj.comision || 0));
          c1Activa = itemObj.comision1Activa === true;
          c1Pct = _r2(limpiarNumero(itemObj.comision1Porcentaje || 0.25));
          c2Activa = itemObj.comision2Activa === true;
          c2Pct = _r2(limpiarNumero(itemObj.comision2Porcentaje || 0.75));
          if (itemObj.moneda) monedaItem = itemObj.moneda.toString().toUpperCase().trim();
        } else {
          punto = _r2(limpiarNumero(itemObj));
        }

        if (punto > 0 || pagoMovil > 0 || comisionObj > 0) {
          itemsArray.push({
            cuenta: nombreCuenta, punto: punto, pagoMovil: pagoMovil,
            comision: comisionObj, moneda: monedaItem,
            c1Activa: c1Activa, c1Pct: c1Pct, c2Activa: c2Activa, c2Pct: c2Pct
          });
        }
      }
    }
  }

  if (itemsArray.length === 0) {
    return { status: "ERROR", mensaje: "No hay montos válidos para registrar en el cierre." };
  }

  var filasHistorial = [];
  var totalComisiones = 0;
  var totalNeto = 0;
  var totalEquivalenteBs = 0;

  for (var k = 0; k < itemsArray.length; k++) {
    var it = itemsArray[k];
    var comision = it.comision;
    var netoPunto = it.punto;

    if (comision <= 0 && (it.c1Activa || it.c2Activa)) {
      if (it.c1Activa) {
        var t1 = it.c1Pct / 100;
        var a1 = netoPunto;
        netoPunto = _r2(netoPunto * (1 - t1));
        comision = _r2(comision + (a1 - netoPunto));
      }
      if (it.c2Activa) {
        var t2 = it.c2Pct / 100;
        var a2 = netoPunto;
        netoPunto = _r2(netoPunto * (1 - t2));
        comision = _r2(comision + (a2 - netoPunto));
      }
    } else if (comision > 0) {
      netoPunto = _r2(it.punto - comision);
    }

    var totalCuenta = _r2(netoPunto + it.pagoMovil);
    actualizarSaldoEnHojaSaldos(sheetSaldos, it.cuenta, totalCuenta, true);

    var tasaItem = it.moneda === "USDT" ? tasaUSDT : (it.moneda === "USD" ? tasaBCV : 1.0);
    var equivBsItem = (it.moneda === "BS") ? (it.punto + it.pagoMovil) : _r2((it.punto + it.pagoMovil) * tasaItem);
    totalEquivalenteBs = _r2(totalEquivalenteBs + equivBsItem);

    if (it.punto > 0) {
      var idTxPos = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);
      var montoBsPos = (it.moneda === "BS") ? netoPunto : _r2(netoPunto * tasaItem);
      filasHistorial.push([
        idTxPos, fechaCierre, "CIERRE_POS", "Cierre Jornada", it.cuenta,
        netoPunto, it.moneda, montoBsPos, comision,
        "CIERRE POS - " + it.cuenta + " | Bruto: " + it.punto.toFixed(2) + ", Com: " + comision.toFixed(2) + ", Neto: " + netoPunto.toFixed(2) + marcaIdemp,
        tasaBCV, tasaUSDT,
        "VENTAS",
        "S", "ACUMULADO", idCierre,
        tasaBCV, "BCV", montoBsPos
      ]);
    }

    if (it.pagoMovil > 0) {
      var idTxPm = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);
      var equivPm = (it.moneda === "BS") ? it.pagoMovil : _r2(it.pagoMovil * tasaItem);
      filasHistorial.push([
        idTxPm, fechaCierre, "CIERRE_PAGO_MOVIL", "Cierre Jornada", it.cuenta,
        it.pagoMovil, it.moneda, equivPm, 0,
        "CIERRE PAGO MÓVIL - " + it.cuenta + " | Monto: " + it.pagoMovil.toFixed(2) + marcaIdemp,
        tasaBCV, tasaUSDT, "VENTAS",
        "S", "ACUMULADO", idCierre,
        tasaBCV, "BCV", equivPm
      ]);
    }

    totalNeto = _r2(totalNeto + totalCuenta);
    totalComisiones = _r2(totalComisiones + comision);
  }

  var lastHRow = sheetHistorial.getLastRow();
  var targetRow = lastHRow === 0 ? 1 : lastHRow + 1;
  sheetHistorial.getRange(targetRow, 1, filasHistorial.length, filasHistorial[0].length).setValues(filasHistorial);

  var fechaHoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  var ventaTotal = _r2(limpiarNumero(payload.ventaTotal !== undefined ? payload.ventaTotal : (payload.ventaEsperadaBs || payload.ventaTotalBs || 0)));
  var distribuido = _r2(limpiarNumero(payload.distribuido !== undefined ? payload.distribuido : totalNeto));
  var comisiones = _r2(limpiarNumero(payload.comisiones !== undefined ? payload.comisiones : totalComisiones));
  var gastos = _r2(limpiarNumero(payload.gastos || 0));
  var prestamos = _r2(limpiarNumero(payload.prestamos || 0));

  // === PROCESAR GASTOS Y PRÉSTAMOS DESDE EL CIERRE ===
  if (payload.gastosVenta && Array.isArray(payload.gastosVenta)) {
    var sheetTrab = ss.getSheetByName("NOMINA_PERSONAL");
    var dataT = sheetTrab ? sheetTrab.getDataRange().getValues() : [];

    for (var g = 0; g < payload.gastosVenta.length; g++) {
      var gasto = payload.gastosVenta[g];
      var montoGasto = limpiarNumero(gasto.monto || 0);
      if (montoGasto <= 0) continue;

        var cuentaGasto = gasto.cuenta || "Caja Efectivo Bs";
        var catGasto = gasto.categoria || "OPERATIVO";
        var origenF = gasto.afectaCuadre ? "VENTA_DIA" : "ACUMULADO";
        var idTxGasto = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);

        // CANDADO DE SEGURIDAD: Si el nombre es un número o dice "Gastos", lo mandamos a Caja Efectivo Bs.
        if (!isNaN(cuentaGasto) || cuentaGasto.toString().toUpperCase().includes("GASTO") || cuentaGasto.toString().trim() === "") {
            cuentaGasto = "Caja Efectivo Bs";
        }
      
      var conGasto = gasto.concepto || "Gasto del cierre";
      if (catGasto === "PRESTAMO_TRABAJADOR" && gasto.cedula) {
         conGasto += " · (V-" + gasto.cedula + ")";
      }

      // 1. Guardar en HISTORIAL
      sheetHistorial.appendRow([
        idTxGasto, fechaCierre, "EGRESO", cuentaGasto, catGasto,
        montoGasto, "BS", montoGasto, 0, conGasto,
        tasaBCV, tasaUSDT, catGasto, "N", origenF, idCierre,
        tasaBCV, "BCV", montoGasto
      ]);

      // 2. Restar el saldo de la cuenta
      actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaGasto, montoGasto, false);

      // 3. Si es préstamo, sumar deuda
      if (catGasto === "PRESTAMO_TRABAJADOR" && gasto.cedula) {
        var cedulaClean = gasto.cedula.toString().replace(/[^0-9]/g, "");
        var montoUSD = tasaBCV > 0 ? _r2(montoGasto / tasaBCV) : 0;

        for (var t = 1; t < dataT.length; t++) {
          var cedFila = (dataT[t][2] || dataT[t][0] || "").toString().replace(/[^0-9]/g, "");
          if (cedFila === cedulaClean) {
            var deudaActual = limpiarNumero(dataT[t][9] || 0);
            var nuevaDeuda = _r2(deudaActual + montoUSD);
            sheetTrab.getRange(t + 1, 10).setValue(nuevaDeuda);
            break;
          }
        }
      }
    }
  }
  // === FIN GASTOS Y PRÉSTAMOS ===

// CANDADO DIRECTOR TÉCNICO: Respetar la verdad absoluta de Flutter
var descuadreFlutter = _r2(limpiarNumero(payload.descuadreBs !== undefined ? payload.descuadreBs : (payload.descuadre || 0)));

// Tolerancia estricta: Si está entre 0.01 y 50.00 Bs, se asume Cuadre Perfecto (0)
if (Math.abs(descuadreFlutter) <= 50.00) {
  descuadreFlutter = 0.00; 
}

var descuadreBs = descuadreFlutter;
var estadoCierre = descuadreBs < 0 ? "FALTANTE" : "CERRADO";

  if (sheetCierres) {
    var totalCobradoUSD = tasaBCV > 0 ? _r2(totalEquivalenteBs / tasaBCV) : 0;
    sheetCierres.appendRow([
      idCierre, fechaCierre,
      _r2(limpiarNumero(payload.montoVentaUSD || payload.ventaTotalUsd || 0)),
      ventaTotal,
      _r2(limpiarNumero(payload.ventaUSDT || 0)),
      totalEquivalenteBs,
      totalCobradoUSD,
      descuadreBs,
      estadoCierre,
      (payload.observacion || "") + marcaIdemp,
      tasaBCV, tasaUSDT
    ]);
  }

  // ===== FALTANTE / SOBRANTE AUTOMÁTICO =====
  if (Math.abs(descuadreBs) > 50.00) {
    var esFaltante = descuadreBs < 0 || diferencia < 0;
    var categoriaAuto = esFaltante ? "FALTANTE" : "AJUSTE";
    var montoAuto = Math.abs(descuadreBs);
    var observacion = (payload.observacion || "").toString().trim();
    if (observacion === "") observacion = esFaltante ? "Sin motivo especificado" : "Sobrante no identificado";

    var idTxAuto = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);
    var cuentaAjuste = "Caja Efectivo Bs";
    var conceptoAuto = (esFaltante ? "FALTANTE" : "SOBRANTE") +
                       " cierre " + idCierre + " · " + observacion;

    if (esFaltante) {
      actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaAjuste, montoAuto, false);
      sheetHistorial.appendRow([
        idTxAuto, fechaCierre, "EGRESO", cuentaAjuste, "VARIAS",
        montoAuto, "BS", montoAuto, 0,
        conceptoAuto,
        tasaBCV, tasaUSDT, categoriaAuto, "N", "ACUMULADO", idCierre,
        tasaBCV, "BCV", montoAuto // <--- COLUMNAS 19 CORREGIDAS
      ]);
    } else {
      actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaAjuste, montoAuto, true);
      sheetHistorial.appendRow([
        idTxAuto, fechaCierre, "INGRESO", "VARIAS", cuentaAjuste,
        montoAuto, "BS", montoAuto, 0,
        conceptoAuto,
        tasaBCV, tasaUSDT, categoriaAuto, "N", "ACUMULADO", idCierre,
        tasaBCV, "BCV", montoAuto // <--- COLUMNAS 19 CORREGIDAS
      ]);
    }
  }

  try {
    guardarDiferenciaCambiaria(idCierre, fechaHoy, totalEquivalenteBs);
  } catch (e) {}

  return {
    status: "SUCCESS", exito: true, mensaje: "Cierre procesado correctamente",
    idCierre: idCierre, filas: filasHistorial.length,
    totalNeto: totalNeto, totalComisiones: totalComisiones
  };
}
// ============================================================================
// 7. RESTO DE FUNCIONES
// ============================================================================

function actualizarSaldoEnHojaSaldos(param1, param2, param3, param4) {
  var sheetSaldos, cuentaId, delta;

  if (typeof param1 === "object" && param1 !== null && typeof param1.getName === "function") {
    sheetSaldos = param1;
    cuentaId = param2;
    var monto = _r2(limpiarNumero(param3 || 0));
    var esSuma = param4 !== false;
    delta = esSuma ? monto : -monto;
  } else {
    var ss = obtenerSpreadsheet();
    sheetSaldos = ss.getSheetByName("SALDOS");
    cuentaId = param1;
    delta = _r2(limpiarNumero(param2 || 0));
  }

  if (!sheetSaldos) {
    var ss = obtenerSpreadsheet();
    sheetSaldos = ss.getSheetByName("SALDOS");
  }
  if (!sheetSaldos) throw new Error("Hoja SALDOS no encontrada");

  cuentaId = (cuentaId || "").toString().trim();
  if (!cuentaId) throw new Error("Nombre de cuenta inválido");

  var lastRow = sheetSaldos.getLastRow();
  var data = lastRow >= 2 ? sheetSaldos.getRange(2, 1, lastRow - 1, 2).getValues() : [];
  var targetRow = -1;
  var saldoActual = 0;
  var keyCleanBuscada = cuentaId.toUpperCase().replace(/[_ ]/g, "");

  for (var i = 0; i < data.length; i++) {
    var ctaFila = data[i][0] ? data[i][0].toString().trim() : "";
    var keyCleanFila = ctaFila.toUpperCase().replace(/[_ ]/g, "");
    if (keyCleanFila === keyCleanBuscada) {
      targetRow = i + 2;
      saldoActual = _r2(limpiarNumero(data[i][1]));
      break;
    }
  }

  var nuevoSaldo = _r2(saldoActual + delta);

  if (targetRow !== -1) {
    sheetSaldos.getRange(targetRow, 2).setValue(nuevoSaldo);
  } else {
    // CANDADO DE SEGURIDAD: Si la cuenta no existe, lanza error y NO la crea.
    throw new Error("La cuenta '" + cuentaId + "' no existe en la hoja SALDOS. Operación abortada para no crear fantasmas.");
  }

  return nuevoSaldo;
}

function _obtenerCuentasDeMovimiento(mov) {
  var tipo = (mov.tipo || "").toUpperCase();
  var deltas = [];

  if (tipo.indexOf("COMPRA_DIVISA") === 0) {
    var origen = mov.origen;
    var destino = mov.destino;
    var montoOrig = _r2(mov.monto);
    var tasa = _r2(mov.tasaUSD || mov.tasa || 0);

    var montoDivisa = 0;
    var matchDiv = (mov.concepto || "").match(/Compra\s+([\d.,]+)/i) || (mov.concepto || "").match(/([\d.,]+)\s+([A-Z]+)\s+a\s+tasa/i);
    if (matchDiv) {
      montoDivisa = _r2(limpiarNumero(matchDiv[1]));
    } else if (tasa > 0) {
      montoDivisa = _r2(montoOrig / tasa);
    }

    if (origen) deltas.push({ cuenta: origen, delta: -montoOrig });
    if (destino && montoDivisa > 0) deltas.push({ cuenta: destino, delta: +montoDivisa });
    return deltas;
  }

  if (tipo.indexOf("CIERRE_POS") === 0 || tipo.indexOf("CIERRE_PAGO_MOVIL") === 0 || tipo.indexOf("CIERRE") === 0) {
    if (mov.destino) {
      deltas.push({ cuenta: mov.destino, delta: +_r2(mov.monto) });
    }
    return deltas;
  }

  if (tipo.indexOf("GASTO") === 0 || tipo.indexOf("EGRESO") === 0 || tipo.indexOf("CARGO") === 0 || tipo.indexOf("FALTANTE") === 0 || tipo.indexOf("PAGO_NOMINA") === 0 || tipo.indexOf("LIQUIDACION") === 0 || tipo.indexOf("PRESTAMO") === 0) {
    var montoTotal = _r2(mov.monto);
    if (mov.origen && mov.origen !== "VARIAS" && mov.origen !== "Gastos Bancarios") {
      deltas.push({ cuenta: mov.origen, delta: -montoTotal });
    }
    if (tipo.indexOf("GASTO") === 0 && mov.origen === "Gastos Bancarios") {
      deltas.push({ cuenta: "Gastos Bancarios", delta: +montoTotal });
    }
    return deltas;
  }

  if (tipo.indexOf("INGRESO") === 0 || tipo.indexOf("SOBRANTE") === 0) {
    if (mov.destino && mov.destino !== "VARIAS") {
      deltas.push({ cuenta: mov.destino, delta: +_r2(mov.monto) });
    }
    return deltas;
  }

  if (tipo.indexOf("TRASPASO") === 0) {
    var matchE = (mov.concepto || "").match(/Enviado:\s*([\d.,]+)/i);
    var matchR = (mov.concepto || "").match(/Recibido:\s*([\d.,]+)/i);
    var matchC = (mov.concepto || "").match(/Com:\s*([\d.,]+)/i);

    var enviado = matchE ? _r2(limpiarNumero(matchE[1])) : _r2(mov.monto);
    var recibido = matchR ? _r2(limpiarNumero(matchR[1])) : _r2(mov.montoNeto > 0 ? mov.montoNeto : mov.monto);
    var comision = matchC ? _r2(limpiarNumero(matchC[1])) : _r2(mov.comision || 0);

    if (mov.origen) deltas.push({ cuenta: mov.origen, delta: -_r2(enviado + comision) });
    if (mov.destino) deltas.push({ cuenta: mov.destino, delta: +recibido });
    return deltas;
  }

  return deltas;
}

function auditarIntegridadSaldos(dryRun) {
  if (dryRun === undefined) dryRun = true;

  var ss = obtenerSpreadsheet();
  var sheetSaldos = ss.getSheetByName("SALDOS");
  var sheetHist = ss.getSheetByName("HISTORIAL");

  if (!sheetSaldos || !sheetHist) {
    return { status: "ERROR", mensaje: "Faltan pestañas SALDOS o HISTORIAL" };
  }

  var saldosSistema = {};
  var lastS = sheetSaldos.getLastRow();
  if (lastS >= 2) {
    var dataS = sheetSaldos.getRange(2, 1, lastS - 1, 2).getValues();
    for (var i = 0; i < dataS.length; i++) {
      var cta = dataS[i][0] ? dataS[i][0].toString().trim() : "";
      if (cta) saldosSistema[cta] = _r2(limpiarNumero(dataS[i][1]));
    }
  }

  var saldosTeoricos = {};
  for (var c in saldosSistema) {
    saldosTeoricos[c] = 0;
  }

  var lastH = sheetHist.getLastRow();
  if (lastH >= 2) {
    var dataH = sheetHist.getRange(2, 1, lastH - 1, 16).getValues();
    for (var j = 0; j < dataH.length; j++) {
      var row = dataH[j];
      var idTx = row[0] ? row[0].toString().trim().toUpperCase() : "";
      if (idTx.indexOf("TX-") !== 0) continue;

      var tipo = row[2] ? row[2].toString().toUpperCase() : "";
      var origen = row[3] ? row[3].toString().trim() : "";
      var destino = row[4] ? row[4].toString().trim() : "";
      var monto = _r2(limpiarNumero(row[5]));
      var moneda = row[6] ? row[6].toString().toUpperCase().trim() : "BS";
      var montoBs = _r2(limpiarNumero(row[7]));
      var comision = _r2(limpiarNumero(row[8]));
      var concepto = row[9] ? row[9].toString() : "";
      var tasa = _r2(limpiarNumero(row[10]));

      var mov = {
        tipo: tipo,
        origen: origen,
        destino: destino,
        monto: monto,
        moneda: moneda,
        montoNeto: montoBs,
        comision: comision,
        concepto: concepto,
        tasa: tasa,
        tasaUSD: tasa,
        tasaUSDT: _r2(limpiarNumero(row[11]))
      };

      var deltas = _obtenerCuentasDeMovimiento(mov);
      for (var k = 0; k < deltas.length; k++) {
        var itemDelta = deltas[k];
        var ctaKey = itemDelta.cuenta;
        if (!ctaKey) continue;

        var ctaEncontrada = null;
        var keyCleanBuscada = ctaKey.toUpperCase().replace(/[_ ]/g, "");
        for (var cNombre in saldosTeoricos) {
          if (cNombre.toUpperCase().replace(/[_ ]/g, "") === keyCleanBuscada) {
            ctaEncontrada = cNombre;
            break;
          }
        }

        if (!ctaEncontrada) {
          ctaEncontrada = ctaKey;
          saldosTeoricos[ctaEncontrada] = 0;
        }

        saldosTeoricos[ctaEncontrada] = _r2(saldosTeoricos[ctaEncontrada] + itemDelta.delta);
      }
    }
  }

  var discrepancias = [];
  var todasCuentasMap = {};
  for (var c1 in saldosSistema) todasCuentasMap[c1] = true;
  for (var c2 in saldosTeoricos) todasCuentasMap[c2] = true;

  for (var ctaNombre in todasCuentasMap) {
    var sSis = saldosSistema[ctaNombre] !== undefined ? saldosSistema[ctaNombre] : 0;
    var sTeor = saldosTeoricos[ctaNombre] !== undefined ? _r2(saldosTeoricos[ctaNombre]) : 0;
    var diff = _r2(sSis - sTeor);

    if (Math.abs(diff) > 0.01) {
      discrepancias.push({
        cuenta: ctaNombre,
        saldoSistema: sSis,
        saldoTeorico: sTeor,
        diferencia: diff
      });
    }
  }

  var reporte = {
    status: discrepancias.length === 0 ? "SUCCESS" : "ALERTA_DISCREPANCIA",
    dryRun: true,
    discrepanciasCount: discrepancias.length,
    discrepancias: discrepancias,
    mensaje: discrepancias.length === 0
      ? "Auditoría de integridad de saldos: 0 discrepancias detectadas. Saldos 100% íntegros."
      : "ALERTA: Se detectaron " + discrepancias.length + " discrepancia(s) entre HISTORIAL y SALDOS. Modo dryRun=true (sin modificaciones realizadas)."
  };

  Logger.log(JSON.stringify(reporte));
  return reporte;
}

function actualizarSaldosYTasas(payload) {
  var ss = obtenerSpreadsheet();
  var resultado = { status: "SUCCESS", actualizados: { tasas: 0, saldos: 0 } };

  // ===== PASO 1: Detectar descuadre en saldos ANTES de guardar =====
  if (payload.saldos && typeof payload.saldos === "object") {
    var sheetSaldos = ss.getSheetByName("SALDOS");
    if (!sheetSaldos) return { status: "ERROR", mensaje: "No existe SALDOS" };

    var dataS = sheetSaldos.getDataRange().getValues();
    var diferencias = [];
    var TOLERANCIA = 0.01;

    for (var nombreCuenta in payload.saldos) {
      var montoNuevo = limpiarNumero(payload.saldos[nombreCuenta]);
      var montoActual = null;

      for (var j = 1; j < dataS.length; j++) {
        var ctaFila = dataS[j][0] ? dataS[j][0].toString().trim() : "";
        if (ctaFila.toUpperCase() === nombreCuenta.toString().trim().toUpperCase()) {
          montoActual = limpiarNumero(dataS[j][1]);
          break;
        }
      }

      if (montoActual === null) continue;

      var dif = montoNuevo - montoActual;
      if (Math.abs(dif) > TOLERANCIA) {
        diferencias.push({
          cuenta: nombreCuenta,
          enSistema: montoActual,
          enReal: montoNuevo,
          diferencia: dif
        });
      }
    }

    if (diferencias.length > 0) {
      return {
        status: "DESCUADRE",
        mensaje: "Hay " + diferencias.length +
                 " cuenta(s) descuadrada(s). Registra las operaciones faltantes antes de actualizar.",
        diferencias: diferencias
      };
    }

    // Sin descuadres → aplicar (solo cuentas nuevas o iguales)
    for (var nombreCuenta in payload.saldos) {
      var montoNuevo = limpiarNumero(payload.saldos[nombreCuenta]);
      var encontrado = false;
      for (var j = 1; j < dataS.length; j++) {
        var ctaFila = dataS[j][0] ? dataS[j][0].toString().trim() : "";
        if (ctaFila.toUpperCase() === nombreCuenta.toString().trim().toUpperCase()) {
          sheetSaldos.getRange(j + 1, 2).setValue(montoNuevo);
          encontrado = true; resultado.actualizados.saldos++; break;
        }
      }
      if (!encontrado) {
        sheetSaldos.appendRow([nombreCuenta, montoNuevo]);
        resultado.actualizados.saldos++;
      }
    }
  }

  // ===== PASO 2: Guardar tasas en CONFIG y TASAS (vía actualizarTasas) =====
  if (payload.tasaUSD || payload.tasaUSDT || payload.tasaEUR || payload.tasaUSDTParalelo || payload.BCV || payload.USDT) {
    var resTasas = actualizarTasas(payload);
    if (resTasas.status === "SUCCESS") {
      resultado.actualizados.tasas = resTasas.actualizados || 1;
    }
  }

  return resultado;
}

function buscarGastos(params) {
  var res = obtenerConsultasConFecha(params);
  if (res.status === "SUCCESS") {
    return { status: "SUCCESS", gastos: res.gastos, totales: res.totales, resumenPorCategoria: res.resumenPorCategoria };
  }
  return res;
}

function registrarOperacion(payload) {
  var tasasReales = _resolverTasas(payload);
  var tasaUSD = tasasReales.tasaUSD;
  var tasaUSDT = tasasReales.tasaUSDT;
  var ss = obtenerSpreadsheet();
  var sheetHistorial = ss.getSheetByName("HISTORIAL");
  var sheetSaldos = ss.getSheetByName("SALDOS");
  if (!sheetHistorial) return { status: "ERROR", mensaje: "Falta HISTORIAL" };
  if (!sheetSaldos) return { status: "ERROR", mensaje: "Falta SALDOS" };

  // === IDEMPOTENCIA ===
  var idempotenciaKey = payload.idempotenciaKey || "";
  if (idempotenciaKey !== "") {
    var histCheck = sheetHistorial.getDataRange().getValues();
    for (var hi = 1; hi < histCheck.length; hi++) {
      var conceptoFila = histCheck[hi][9] ? histCheck[hi][9].toString() : "";
      var sufijoKey = "IDEMP:" + idempotenciaKey;
      if (conceptoFila.indexOf(sufijoKey) !== -1) {
        return {
          status: "SUCCESS", exito: true,
          idTx: histCheck[hi][0].toString(),
          mensaje: "Operación ya registrada (idempotencia)",
          duplicado: true
        };
      }
    }
  }
  // === FIN IDEMPOTENCIA ===

  var idTx = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);
  var montoTotal = limpiarNumero(payload.montoBsPagado || payload.montoBsCalculado || 0);
  var comisionBs = limpiarNumero(payload.comisionBs || 0);
  var metodoPago = payload.metodoPago || "EFECTIVO";
  var cuentaSalida = payload.cuentaSalida || "Caja Efectivo Bs";
  var concepto = payload.concepto || payload.categoria || "Gasto";
  var categoria = payload.categoria || "OPERATIVO";
  var tipoOperacion = payload.tipoOperacion || "EGRESO";
  var origenFondos = (payload.origenFondos || "ACUMULADO").toString().toUpperCase();
  var parteDelCierre = payload.parteDelCierre === true ? "S" : "N";

  // === NUEVO: flag informativo (no afecta saldo) ===
  var noAfectaSaldo = payload.noAfectaSaldo === true;

  if (montoTotal <= 0) return { status: "ERROR", mensaje: "Monto inválido." };
    // === VALIDACIÓN ESTRICTA DE TRABAJADOR (FAIL-FAST) ===
  var esPrestamoTrabajador = (categoria === "PRESTAMO_TRABAJADOR");
  var filaTrabajadorIndex = -1;
  var montoUSD = 0;
  var sheetTrab = ss.getSheetByName("NOMINA_PERSONAL");
  var dataT = [];

  if (esPrestamoTrabajador) {
    if (!payload.cedula || payload.cedula.toString().trim() === "") {
      return { status: "ERROR", mensaje: "Falta la cédula del trabajador. No se registró nada." };
    }
    var cedulaClean = payload.cedula.toString().replace(/[^0-9]/g, "");
    if (cedulaClean === "") {
      return { status: "ERROR", mensaje: "Cédula inválida. Debe contener números. No se registró nada." };
    }
    if (!sheetTrab) return { status: "ERROR", mensaje: "No existe hoja NOMINA_PERSONAL." };

    dataT = sheetTrab.getDataRange().getValues();
    for (var ti = 1; ti < dataT.length; ti++) {
      var cedFila = (dataT[ti][2] || dataT[ti][0] || "").toString().replace(/[^0-9]/g, "");
      if (cedFila === cedulaClean) {
        filaTrabajadorIndex = ti;
        break;
      }
    }
    if (filaTrabajadorIndex === -1) {
      return { status: "ERROR", mensaje: "Trabajador no encontrado con cédula " + cedulaClean + ". No se registró nada." };
    }
    montoUSD = tasaUSD > 0 ? montoTotal / tasaUSD : 0;
  }
  // === FIN VALIDACIÓN ===

  var fechaTx = new Date();
  if (payload.fechaOperacion && payload.fechaOperacion.toString().trim() !== "") {
    try {
      var fechaParseada = new Date(payload.fechaOperacion + "T12:00:00");
      if (!isNaN(fechaParseada.getTime())) fechaTx = fechaParseada;
    } catch (e) {}
  }

    var cuentaComision = "";
  var comisionNativa = 0;
  if (payload.cuentasDesglose && payload.cuentasDesglose.length > 0) {
    for (var k = 0; k < payload.cuentasDesglose.length; k++) {
      var it = payload.cuentasDesglose[k];
      var ctaD = it.cuenta || "Caja Efectivo Bs";
      var montoNat = limpiarNumero(it.monto || 0);
      var monedaNat = (it.moneda || "BS").toString().toUpperCase();
      if (montoNat <= 0) continue;

      // FIX USDT: Si la cuenta es divisa, convertir el monto a su moneda nativa
      var montoARestar = montoNat;
      if (monedaNat === "USDT" && tasaUSDT > 0) montoARestar = montoNat / tasaUSDT;
      else if (monedaNat === "USD" && tasaUSD > 0) montoARestar = montoNat / tasaUSD;

      var comNativa = 0;
      if (k === 0 && comisionBs > 0) {
        comNativa = comisionBs;
        if (monedaNat === "USD") comNativa = comisionBs / (tasaUSD || 1);
        else if (monedaNat === "USDT") comNativa = comisionBs / (tasaUSDT || 1);
      }

      if (!noAfectaSaldo) {
        var saldoD = obtenerSaldoCuenta(sheetSaldos, ctaD);
        var requerido = montoARestar + (k === 0 ? comNativa : 0);
        if (saldoD < requerido) {
          origenFondos = "VENTA_DIA"; 
          actualizarSaldoEnHojaSaldos(sheetSaldos, ctaD, saldoD, false);
        } else {
          actualizarSaldoEnHojaSaldos(sheetSaldos, ctaD, montoARestar, false);
        }
        if (comNativa > 0) actualizarSaldoEnHojaSaldos(sheetSaldos, ctaD, comNativa, false);
      }
    }
  } else {
    // Ruta normal sin desglose
    if (!noAfectaSaldo) {
      var saldoDisponible = obtenerSaldoCuenta(sheetSaldos, cuentaSalida);
      var requeridoTotal = montoTotal + comisionBs;
      if (saldoDisponible < requeridoTotal) {
        origenFondos = "VENTA_DIA";
        actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaSalida, saldoDisponible, false); 
      } else {
        actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaSalida, montoTotal, false);
        if (comisionBs > 0) actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaSalida, comisionBs, false);
      }
    }
  }  

  // === NUEVO: marcar en concepto si es informativo ===
  if (noAfectaSaldo) {
    concepto = concepto + " | [INFORMATIVO - no afecta saldo]";
  }

  var fechaOpStr = Utilities.formatDate(fechaTx, "America/Caracas", "yyyy-MM-dd");
  var fuenteBuscadaOp = (payload.fuenteTasa || payload.fuente || "BCV").toString().toUpperCase();
  var tasaRefOp = obtenerTasa(fechaOpStr, fuenteBuscadaOp);
  var tasaFinalOp = (tasaUSD > 0) ? tasaUSD : tasaRefOp;
  var fuenteFinalOp = (tasaUSD > 0) ? "MANUAL" : fuenteBuscadaOp;
var montoBsOp = (payload.moneda === "USD" || payload.moneda === "USDT") ? (montoTotal * tasaFinalOp) : montoTotal;

  // Destino inteligente: usa el proveedor, la categoría o deja vacío. Nunca "VARIAS".
  var destinoReal = payload.proveedor || payload.tercero || categoria;
  if (destinoReal === "VARIAS") destinoReal = "";

  if (payload.cuentasDesglose && payload.cuentasDesglose.length > 0) {
    for (var k = 0; k < payload.cuentasDesglose.length; k++) {
      var it = payload.cuentasDesglose[k];
      var ctaD = it.cuenta || "Caja Efectivo Bs";
      var montoNat = limpiarNumero(it.monto || 0);
      var monedaNat = (it.moneda || "BS").toString().toUpperCase();
      if (montoNat <= 0) continue;
      
      var idTxPart = k === 0 ? idTx : "TX-" + Math.floor(Math.random() * 900000000 + 100000000);
      var comPart = k === 0 ? comisionBs : 0;
      
      sheetHistorial.appendRow([
        idTxPart, fechaTx, tipoOperacion, ctaD, destinoReal,
        montoNat, monedaNat, montoNat, comPart,
        concepto,
        tasaUSD, tasaUSDT, categoria, parteDelCierre, origenFondos, "",
        tasaFinalOp, fuenteFinalOp, montoNat
      ]);
    }
  } else {
    sheetHistorial.appendRow([
      idTx, fechaTx, tipoOperacion, cuentaSalida, destinoReal,
      montoTotal, "BS", montoTotal, comisionBs,
      concepto,
      tasaUSD, tasaUSDT, categoria, parteDelCierre, origenFondos, "",
      tasaFinalOp, fuenteFinalOp, montoBsOp
    ]);
  }

  // === MARCAR PENDIENTE COMO PAGADO SI SE PROPORCIONÓ ID DE PENDIENTE ===
  if (payload.idPendiente && payload.idPendiente.toString().trim() !== "") {
    try {
      marcarPendientePagado({
        id: payload.idPendiente.toString().trim(),
        idTxPago: idTx
      });
    } catch (ePend) {
      Logger.log("Error marcando pendiente pagado: " + ePend);
    }
  }

    // === ACTUALIZAR DEUDA (Ya validado arriba, es seguro) ===
  if (esPrestamoTrabajador && filaTrabajadorIndex !== -1) {
    var deudaActual = limpiarNumero(dataT[filaTrabajadorIndex][9] || 0);
    var nuevaDeuda = deudaActual + montoUSD;
    sheetTrab.getRange(filaTrabajadorIndex + 1, 10).setValue(nuevaDeuda);
    
    return {
      status: "SUCCESS", exito: true, idTx: idTx,
      mensaje: "Préstamo registrado. Deuda nueva: $" + nuevaDeuda.toFixed(2),
      deudaNueva: nuevaDeuda,
      montoUSD: montoUSD
    };
  }

  return { status: "SUCCESS", exito: true, idTx: idTx, mensaje: "Egreso registrado correctamente" };
}

function registrarCompraDivisa(payload) {
  var ss = obtenerSpreadsheet();
  var sheetHistorial = ss.getSheetByName("HISTORIAL");
  var sheetSaldos = ss.getSheetByName("SALDOS");
  if (!sheetHistorial || !sheetSaldos) return { status: "ERROR", mensaje: "Faltan pestañas" };

  var cuentaOrigenNombre = (payload.cuentaOrigen || payload.origen || "Caja Efectivo Bs").toString().trim();
  var cuentaDestinoNombre = (payload.cuentaDestino || payload.destino || "Binance Pay").toString().trim();

  var origen = buscarCuenta(cuentaOrigenNombre);
  var destino = buscarCuenta(cuentaDestinoNombre);

  var tasa = _r2(limpiarNumero(payload.tasaUsada !== undefined ? payload.tasaUsada : (payload.tasa || 0)));
  var montoDivisa = _r2(limpiarNumero(payload.montoDivisa || payload.monto || 0));
  var montoBs = _r2(limpiarNumero(payload.montoBs || 0));

  if (montoBs <= 0 && montoDivisa > 0 && tasa > 0) {
    montoBs = _r2(montoDivisa * tasa);
  }

  if (tasa <= 0) {
    return { status: "ERROR", mensaje: "Tasa debe ser mayor a 0." };
  }
  if (montoDivisa <= 0 || montoBs <= 0) {
    return { status: "ERROR", mensaje: "Montos inválidos." };
  }
  if (origen.moneda === destino.moneda) {
    return { status: "ERROR", mensaje: "Las cuentas origen y destino deben tener monedas distintas (compra de divisa rechazada)." };
  }
  if (Math.abs(_r2(montoDivisa * tasa) - _r2(montoBs)) > 0.01) {
    return { status: "ERROR", mensaje: "Conservación de monto ±0.01 violada: " + montoDivisa + " * " + tasa + " != " + montoBs };
  }

  // === IDEMPOTENCIA ===
  var idempotenciaKey = (payload.idempotenciaKey || "").toString().trim();
  if (idempotenciaKey !== "") {
    var histCheck = sheetHistorial.getDataRange().getValues();
    var inicioBusqueda = histCheck.length > 100 ? histCheck.length - 100 : 1;
    for (var hi = inicioBusqueda; hi < histCheck.length; hi++) {
      var conceptoFila = histCheck[hi][9] ? histCheck[hi][9].toString() : "";
      var sufijoKey = "IDEMP:" + idempotenciaKey;
      if (conceptoFila.indexOf(sufijoKey) !== -1) {
        return {
          status: "SUCCESS", exito: true,
          idTx: histCheck[hi][0].toString(),
          mensaje: "Operación ya registrada (idempotencia)",
          duplicado: true
        };
      }
    }
  }

  var idTx = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);
  var fechaTx = new Date();
  var fechaOp = payload.fechaOperativa || payload.fechaOperacion || "";
  if (fechaOp.toString().trim() !== "") {
    try {
      var fp = new Date(fechaOp.toString().trim() + "T12:00:00");
      if (!isNaN(fp.getTime())) fechaTx = fp;
    } catch (e) {}
  }

  var fuenteTasa = (payload.fuenteTasa || payload.fuente || (destino.moneda === "USDT" ? "USDT" : "MANUAL")).toString().toUpperCase();

  var concepto = "Compra " + montoDivisa.toFixed(2) + " " + destino.moneda + " a tasa " + tasa.toFixed(2) + " desde " + origen.nombre;
  if (payload.concepto && payload.concepto.toString().trim() !== "" && payload.concepto !== "Compra de divisa" && payload.concepto.indexOf("Compra") !== 0) {
    concepto = payload.concepto.toString().trim() + " | " + concepto;
  }
  if (idempotenciaKey !== "") {
    concepto = concepto + " | IDEMP:" + idempotenciaKey;
  }

  var fechaCdStr = Utilities.formatDate(fechaTx, "America/Caracas", "yyyy-MM-dd");
  var tasaRefCd = obtenerTasa(fechaCdStr, "USDT");
  var tasaFinalCd = tasa > 0 ? tasa : tasaRefCd;
  var fuenteFinalCd = tasa > 0 ? "MANUAL" : "USDT";

  sheetHistorial.appendRow([
    idTx, fechaTx, "COMPRA_DIVISA", origen.cuentaId, destino.cuentaId,
    montoBs, origen.moneda, montoBs, 0, concepto,
    0, 0, "COMPRA_DIVISA", "N", "ACUMULADO", "",
    tasaFinalCd, fuenteFinalCd, montoBs
  ]);

  actualizarSaldoEnHojaSaldos(origen.cuentaId, -montoBs);
  actualizarSaldoEnHojaSaldos(destino.cuentaId, +montoDivisa);

  return {
    status: "SUCCESS",
    exito: true,
    idTx: idTx,
    mensaje: "Compra de divisa registrada correctamente"
  };
}

function registrarTraspaso(payload) {
  var ss = obtenerSpreadsheet();
  var sheetHistorial = ss.getSheetByName("HISTORIAL");
  var sheetSaldos = ss.getSheetByName("SALDOS");
  if (!sheetHistorial || !sheetSaldos) return { status: "ERROR", mensaje: "Faltan pestañas" };

  // === IDEMPOTENCIA: evitar duplicados por reintentos ===
  var idempotenciaKey = payload.idempotenciaKey || "";
  if (idempotenciaKey !== "") {
    var histCheck = sheetHistorial.getDataRange().getValues();
    var inicioBusqueda = histCheck.length > 100 ? histCheck.length - 100 : 1;
    for (var hi = inicioBusqueda; hi < histCheck.length; hi++) {
      var conceptoFila = histCheck[hi][9] ? histCheck[hi][9].toString() : "";
      var sufijoKey = "IDEMP:" + idempotenciaKey;
      if (conceptoFila.indexOf(sufijoKey) !== -1) {
        return {
          status: "SUCCESS",
          exito: true,
          idTx: histCheck[hi][0].toString(),
          mensaje: "Operación ya registrada (idempotencia)",
          duplicado: true
        };
      }
    }
  }
  // === FIN IDEMPOTENCIA ===

  var idTx = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);
  var cuentaOrigen = (payload.cuentaOrigen || "").toString().trim();
  var cuentaDestino = (payload.cuentaDestino || "").toString().trim();
  var montoOrigen = limpiarNumero(payload.monto || 0);
  var montoDestino = limpiarNumero(payload.montoDestino || 0);
  var montoBs = limpiarNumero(payload.montoBs || 0);
  var monedaOrigen = (payload.monedaOrigen || "BS").toString().toUpperCase();
  var monedaDestino = (payload.monedaDestino || "BS").toString().toUpperCase();
  var tipoTraspaso = payload.tipoTraspaso || "OTRO_BANCO";
  var concepto = payload.concepto || "Traspaso entre cuentas";
  var origenFondos = (payload.origenFondos || "ACUMULADO").toString().toUpperCase();
  var tasasReales = _resolverTasas(payload);
  var tasaUSD = tasasReales.tasaUSD;
  var tasaUSDT = tasasReales.tasaUSDT;

  if (montoOrigen <= 0) return { status: "ERROR", mensaje: "Monto inválido." };
  if (cuentaOrigen === "" || cuentaDestino === "") {
    return { status: "ERROR", mensaje: "Cuenta origen y destino son obligatorias." };
  }
  if (cuentaOrigen === cuentaDestino) {
    return { status: "ERROR", mensaje: "La cuenta origen y destino no pueden ser iguales." };
  }

  var fechaTx = new Date();
  if (payload.fechaOperacion && payload.fechaOperacion.toString().trim() !== "") {
    try {
      var fechaParseada = new Date(payload.fechaOperacion + "T12:00:00");
      if (!isNaN(fechaParseada.getTime())) fechaTx = fechaParseada;
    } catch (e) {}
  }

  var comision = 0;
  if (tipoTraspaso === "OTRO_BANCO") {
    comision = montoOrigen * 0.003;
  }

  var totalDebito = montoOrigen + comision;

  var saldoOrigen = obtenerSaldoCuenta(sheetSaldos, cuentaOrigen);
  if (saldoOrigen < totalDebito) {
    return {
      status: "ERROR",
      mensaje: "Fondos insuficientes en " + cuentaOrigen +
               ". Disponible: " + saldoOrigen.toFixed(2) + " " + monedaOrigen +
               " | Requerido: " + totalDebito.toFixed(2) + " " + monedaOrigen
    };
  }

  actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaOrigen, totalDebito, false);
  actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaDestino, montoDestino, true);

  var tipoDetalle = "TRASPASO_INTERBANCARIO";
  if (tipoTraspaso === "MISMO_BANCO") tipoDetalle = "TRASPASO_MISMO_BANCO";
  else if (tipoTraspaso === "PAGO_MOVIL") tipoDetalle = "TRASPASO_PAGO_MOVIL";

  var detalleCom = comision > 0
    ? " | Com: " + comision.toFixed(2) + " " + monedaOrigen
    : "";

  if (idempotenciaKey !== "") {
    concepto = concepto + " | IDEMP:" + idempotenciaKey;
  }

  var tasaFinalTr = tasaUSD;
  var fuenteFinalTr = "SISTEMA";
  var montoBsTr = limpiarNumero(montoBs > 0 ? montoBs : (monedaOrigen === "USD" ? montoOrigen * tasaFinalTr : montoOrigen));

  sheetHistorial.appendRow([
    idTx, fechaTx, tipoDetalle, cuentaOrigen, cuentaDestino,
    montoBs, "BS", montoDestino, comision,
    concepto + detalleCom +
      " | Enviado: " + montoOrigen.toFixed(2) + " " + monedaOrigen +
      " | Recibido: " + montoDestino.toFixed(2) + " " + monedaDestino,
    tasaUSD, tasaUSDT, "TRASPASO", "N", origenFondos, "",
    tasaFinalTr, fuenteFinalTr, montoBsTr
  ]);

  return {
    status: "SUCCESS", exito: true, idTx: idTx,
    mensaje: "Traspaso registrado correctamente",
    comision: comision,
    totalDebitado: totalDebito
  };
}
function registrarCargoFijoMensual(payload) {
  var ss = obtenerSpreadsheet();
  var sheetHistorial = ss.getSheetByName("HISTORIAL");
  var sheetSaldos = ss.getSheetByName("SALDOS");
  if (!sheetHistorial || !sheetSaldos) return { status: "ERROR", mensaje: "Faltan pestañas" };
  var idTx = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);
  var monto = limpiarNumero(payload.montoBs || payload.monto || 0);
  var cuentaSalida = payload.cuentaSalida || "Caja Efectivo Bs";
  var concepto = payload.concepto || "Cargo Fijo Mensual";
  var categoria = payload.categoria || "CARGO_FIJO";

  if (monto > 0) {
    var saldoDisponible = obtenerSaldoCuenta(sheetSaldos, cuentaSalida);
    if (saldoDisponible < monto) {
      return { status: "ERROR", mensaje: "Fondos insuficientes en " + cuentaSalida };
    }
    var fechaCfStr = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
    var tasaRefCf = obtenerTasa(fechaCfStr, "BCV");

    actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaSalida, monto, false);
    sheetHistorial.appendRow([
      idTx, new Date(), "CARGO_FIJO", cuentaSalida, "GASTOS",
      monto, "BS", monto, 0, concepto,
      0, 0, categoria, "N", "ACUMULADO", "",
      tasaRefCf, "BCV", monto
    ]);
  }
  return { status: "SUCCESS", exito: true, idTx: idTx };
}
// ============================================================================
// VERIFICAR ESTADO DEL DÍA
// ============================================================================
function verificarEstadoDelDia() {
  var tz = "America/Caracas";
  var hoy = new Date();
  var diaSemana = Number(Utilities.formatDate(hoy, tz, "u"));
  var fechaHoy = Utilities.formatDate(hoy, tz, "yyyy-MM-dd");
  var ss = obtenerSpreadsheet();
  
  // Tasas
  var tasasCargadas = false, fechaVigente = "";
  var sheetTasas = ss.getSheetByName("TASAS_HISTORICO");
  if (sheetTasas && sheetTasas.getLastRow() >= 2) {
    var data = sheetTasas.getRange(2, 1, sheetTasas.getLastRow() - 1, 1).getValues();
    var fechasCargadas = {};
    for (var i = 0; i < data.length; i++) {
      var f = convertirAFecha(data[i][0]);
      if (f !== "") fechasCargadas[f] = true;
    }
    for (var d = 0; d < 5; d++) {
      var fechaCheck = new Date(hoy.getTime() - d * 24 * 60 * 60 * 1000);
      var fechaStr = Utilities.formatDate(fechaCheck, tz, "yyyy-MM-dd");
      if ([6,7].indexOf(Number(Utilities.formatDate(fechaCheck, tz, "u"))) !== -1) continue;
      if (fechasCargadas[fechaStr]) { tasasCargadas = true; fechaVigente = fechaStr; break; }
    }
  }

  // Último Cierre
  var ultimoCierre = "";
  var sheetCierres = ss.getSheetByName("HISTORIAL_CIERRES");
  if (sheetCierres && sheetCierres.getLastRow() >= 2) {
    var dataC = sheetCierres.getRange(2, 1, sheetCierres.getLastRow() - 1, 2).getValues();
    for (var c = 0; c < dataC.length; c++) {
      var fCierre = _normalizarFecha(dataC[c][1], tz);
      if (fCierre > ultimoCierre) ultimoCierre = fCierre;
    }
  }

  // Validar Fecha Esperada (saltando fines de semana)
  var ayer = new Date(hoy);
  if (diaSemana === 1) ayer.setDate(hoy.getDate() - 3);
  else if (diaSemana === 7) ayer.setDate(hoy.getDate() - 2);
  else ayer.setDate(hoy.getDate() - 1);
  
  var fechaEsperada = Utilities.formatDate(ayer, tz, "yyyy-MM-dd");
  var faltaCierre = (ultimoCierre < fechaEsperada) && (diaSemana !== 6 && diaSemana !== 7); 

  return { status: "SUCCESS", tasasCargadas: tasasCargadas, esFinDeSemana: (diaSemana === 6 || diaSemana === 7), fecha: fechaHoy, fechaVigente: fechaVigente, ultimoCierre: ultimoCierre, faltaCierre: faltaCierre };
}

// ============================================================================
// HELPER FECHA
// ============================================================================
function convertirAFecha(valor) {
  if (!valor) return "";
  try {
    if (valor instanceof Date) {
      return Utilities.formatDate(valor, "America/Caracas", "yyyy-MM-dd");
    }
        return valor.toString().substring(0, 10);
  } catch (e) {
    return "";
  }
}

function registrarFaltante(payload) {
  var ss = obtenerSpreadsheet();
  var sheetHistorial = ss.getSheetByName("HISTORIAL");
  var sheetSaldos = ss.getSheetByName("SALDOS");
  if (!sheetHistorial) return { status: "ERROR", mensaje: "Falta HISTORIAL" };
  if (!sheetSaldos) return { status: "ERROR", mensaje: "Falta SALDOS" };

  // === IDEMPOTENCIA ===
  var idempotenciaKey = payload.idempotenciaKey || "";
  if (idempotenciaKey !== "") {
    var histCheck = sheetHistorial.getDataRange().getValues();
    var inicioBusqueda = histCheck.length > 100 ? histCheck.length - 100 : 1;
    for (var hi = inicioBusqueda; hi < histCheck.length; hi++) {
      var conceptoFila = histCheck[hi][9] ? histCheck[hi][9].toString() : "";
      var sufijoKey = "IDEMP:" + idempotenciaKey;
      if (conceptoFila.indexOf(sufijoKey) !== -1) {
        return {
          status: "SUCCESS", exito: true,
          idTx: histCheck[hi][0].toString(),
          mensaje: "Faltante ya registrado (idempotencia)",
          duplicado: true
        };
      }
    }
  }
  // === FIN IDEMPOTENCIA ===

  var idTx = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);
  var montoBs = limpiarNumero(payload.montoBs || 0);
  var cuentaOrigen = payload.cuentaOrigen || "Caja Efectivo Bs";
  var nota = payload.nota || "";
 
  if (montoBs <= 0) return { status: "ERROR", mensaje: "Monto inválido." };

  var fechaTx = new Date();
  if (payload.fechaOperacion && payload.fechaOperacion.toString().trim() !== "") {
    try {
      var fechaParseada = new Date(payload.fechaOperacion + "T12:00:00");
      if (!isNaN(fechaParseada.getTime())) fechaTx = fechaParseada;
    } catch (e) {}
  }

  var saldoDisponible = obtenerSaldoCuenta(sheetSaldos, cuentaOrigen);
  if (saldoDisponible < montoBs) {
    return {
      status: "ERROR",
      mensaje: "Fondos insuficientes en " + cuentaOrigen +
               ". Disponible: " + saldoDisponible.toFixed(2) +
               " | Requerido: " + montoBs.toFixed(2)
    };
  }

  actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaOrigen, montoBs, false);

  var concepto = "FALTANTE CIERRE" + (nota !== "" ? " - " + nota : "");
  if (idempotenciaKey !== "") {
    concepto = concepto + " | IDEMP:" + idempotenciaKey;
  }

  var fechaFaStr = Utilities.formatDate(fechaTx, "America/Caracas", "yyyy-MM-dd");
  var tasaRefFa = obtenerTasa(fechaFaStr, "BCV");
  var tasaFinalFa = (limpiarNumero(payload.tasaUSD || 0) > 0) ? limpiarNumero(payload.tasaUSD) : tasaRefFa;
  var fuenteFinalFa = (limpiarNumero(payload.tasaUSD || 0) > 0) ? "MANUAL" : "BCV";

  sheetHistorial.appendRow([
    idTx, fechaTx, "EGRESO", cuentaOrigen, "VARIAS",
    montoBs, "BS", montoBs, 0,
    concepto, limpiarNumero(payload.tasaUSD || 0), limpiarNumero(payload.tasaUSDT || 0), "FALTANTE", "N", "ACUMULADO", "",
    tasaFinalFa, fuenteFinalFa, montoBs
  ]);

  return { status: "SUCCESS", exito: true, idTx: idTx, mensaje: "Faltante registrado" };
}

function registrarIngreso(payload) {
  var ss = obtenerSpreadsheet();
  var sheetHistorial = ss.getSheetByName("HISTORIAL");
  var sheetSaldos = ss.getSheetByName("SALDOS");
  if (!sheetHistorial) return { status: "ERROR", mensaje: "Falta HISTORIAL" };
  if (!sheetSaldos) return { status: "ERROR", mensaje: "Falta SALDOS" };

  // === IDEMPOTENCIA ===
  var idempotenciaKey = payload.idempotenciaKey || "";
  if (idempotenciaKey !== "") {
    var histCheck = sheetHistorial.getDataRange().getValues();
    var inicioBusqueda = histCheck.length > 100 ? histCheck.length - 100 : 1;
    for (var hi = inicioBusqueda; hi < histCheck.length; hi++) {
      var conceptoFila = histCheck[hi][9] ? histCheck[hi][9].toString() : "";
      var sufijoKey = "IDEMP:" + idempotenciaKey;
      if (conceptoFila.indexOf(sufijoKey) !== -1) {
        return {
          status: "SUCCESS", exito: true,
          idTx: histCheck[hi][0].toString(),
          mensaje: "Operación ya registrada (idempotencia)",
          duplicado: true
        };
      }
    }
  }
  // === FIN IDEMPOTENCIA ===

  var idTx = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);
  var montoBs = limpiarNumero(payload.montoBs || 0);
  var cuentaDestino = payload.cuentaDestino || "Caja Efectivo Bs";
  var concepto = payload.concepto || "Ingreso";
  var categoria = payload.categoria || "VENTA";
  var parteDelCierre = (categoria === "VENTA" || categoria === "COBRO_CLIENTE") ? "S" : "N";
  var origenFondos = (payload.origenFondos || "VENTA_DIA").toString().toUpperCase();
  var tasasReales = _resolverTasas(payload);
  var tasaUSD = tasasReales.tasaUSD;
  var tasaUSDT = limpiarNumero(payload.tasaUSDT || 0);

  if (montoBs <= 0) return { status: "ERROR", mensaje: "Monto inválido." };

  var fechaTx = new Date();
  if (payload.fechaOperacion && payload.fechaOperacion.toString().trim() !== "") {
    try {
      var fechaParseada = new Date(payload.fechaOperacion + "T12:00:00");
      if (!isNaN(fechaParseada.getTime())) fechaTx = fechaParseada;
    } catch (e) {}
  }

  if (payload.cuentasDesglose && payload.cuentasDesglose.length > 0) {
    var cuentasTxt = [];
    for (var k = 0; k < payload.cuentasDesglose.length; k++) {
      var it = payload.cuentasDesglose[k];
      var ctaD = it.cuenta || "Caja Efectivo Bs";
      var montoNat = limpiarNumero(it.monto || 0);
      var monedaNat = (it.moneda || "BS").toString().toUpperCase();
      if (montoNat > 0) {
        actualizarSaldoEnHojaSaldos(sheetSaldos, ctaD, montoNat, true);
        cuentasTxt.push(ctaD);
      }
    }
    cuentaDestino = cuentasTxt.join(" | ");
  } else {
    actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaDestino, montoBs, true);
  }

  if (idempotenciaKey !== "") {
    concepto = concepto + " | IDEMP:" + idempotenciaKey;
  }

  var tasaFinalIng = tasaUSD;
  var fuenteFinalIng = "SISTEMA";

  sheetHistorial.appendRow([
    idTx, fechaTx, "INGRESO", "VARIAS", cuentaDestino,
    montoBs, "BS", montoBs, 0, concepto,
    tasaUSD, tasaUSDT, categoria, parteDelCierre, origenFondos, "",
    tasaFinalIng, fuenteFinalIng, montoBs
  ]);

  return {
    status: "SUCCESS", exito: true, idTx: idTx,
    mensaje: "Ingreso registrado correctamente"
  };
}
// ============================================================================
// CUENTAS PENDIENTES (POR PAGAR)
// ============================================================================

function registrarPendiente(payload) {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("CUENTAS_PENDIENTES");
  if (!sheet) {
    sheet = ss.insertSheet("CUENTAS_PENDIENTES");
    sheet.appendRow([
      "ID", "Fecha", "Vencimiento", "Tipo", "Tercero",
      "Concepto", "Monto", "Moneda", "Estado", "Fecha Pago", "ID Tx Pago", "Nota"
    ]);
  }

  var tipo = (payload.tipo || "POR_PAGAR").toString().toUpperCase();
  var tercero = (payload.tercero || "").toString().trim();
  var concepto = (payload.concepto || "").toString().trim();
  var monto = limpiarNumero(payload.monto || 0);
  var moneda = (payload.moneda || "BS").toString().toUpperCase();
  var fechaVencimiento = (payload.fechaVencimiento || "").toString().trim();
  var nota = (payload.nota || "").toString().trim();

  if (monto <= 0) return { status: "ERROR", mensaje: "Monto inválido." };
  if (tercero === "") return { status: "ERROR", mensaje: "Tercero obligatorio." };

  var fechaRegistro = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  var id = "CP-" + Math.floor(Math.random() * 900000 + 100000);

  sheet.appendRow([
    id, fechaRegistro, fechaVencimiento, tipo, tercero,
    concepto, monto, moneda, "PENDIENTE", "", "", nota
  ]);

  return {
    status: "SUCCESS",
    exito: true,
    id: id,
    mensaje: "Pendiente registrado correctamente"
  };
}

function marcarPendientePagado(payload) {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("CUENTAS_PENDIENTES");
  if (!sheet) return { status: "ERROR", mensaje: "No existe CUENTAS_PENDIENTES" };

  var id = (payload.id || "").toString().trim();
  if (id === "") return { status: "ERROR", mensaje: "Falta el ID." };

  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return { status: "ERROR", mensaje: "No hay pendientes." };

  var data = sheet.getRange(2, 1, lastRow - 1, 12).getValues();
  var fechaHoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");

  for (var i = 0; i < data.length; i++) {
    if (data[i][0].toString().trim() === id) {
      sheet.getRange(i + 2, 9).setValue("PAGADO");
      sheet.getRange(i + 2, 10).setValue(fechaHoy);
      sheet.getRange(i + 2, 11).setValue(payload.idTxPago || "");
      return {
        status: "SUCCESS",
        exito: true,
        mensaje: "Pendiente marcado como pagado"
      };
    }
  }

  return { status: "ERROR", mensaje: "No se encontró el ID: " + id };
}

function obtenerPendientes(params) {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("CUENTAS_PENDIENTES");
  if (!sheet) return { status: "ERROR", pendientes: [], totalPorPagar: 0 };

  var soloActivos = true;
  if (params && params.todos === "true") soloActivos = false;

  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return { status: "SUCCESS", pendientes: [], totalPorPagar: 0 };

  var data = sheet.getRange(2, 1, lastRow - 1, 12).getValues();
  var pendientes = [];
  var totalPorPagar = 0;

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var estado = row[8] ? row[8].toString().toUpperCase() : "PENDIENTE";
    if (soloActivos && estado !== "PENDIENTE") continue;

    var monto = limpiarNumero(row[6]);
    var moneda = row[7] ? row[7].toString() : "BS";

    var item = {
      id: row[0] ? row[0].toString() : "",
      fechaRegistro: row[1] ? row[1].toString().substring(0, 10) : "",
      fechaVencimiento: row[2] ? row[2].toString().substring(0, 10) : "",
      tipo: row[3] ? row[3].toString() : "POR_PAGAR",
      tercero: row[4] ? row[4].toString() : "",
      concepto: row[5] ? row[5].toString() : "",
      monto: monto,
      moneda: moneda,
      estado: estado,
      fechaPago: row[9] ? row[9].toString().substring(0, 10) : "",
      idTxPago: row[10] ? row[10].toString() : "",
      nota: row[11] ? row[11].toString() : ""
    };
    pendientes.push(item);

    if (estado === "PENDIENTE" && item.tipo === "POR_PAGAR") {
      // Solo sumamos en Bs para el total (si es otra moneda, no la suma aquí)
      if (moneda === "BS") totalPorPagar += monto;
    }
  }

  return {
    status: "SUCCESS",
    pendientes: pendientes,
    totalPorPagar: totalPorPagar
  };
}

// ============================================================================
// 8. FORMATEO AUTOMÁTICO DEL SHEET
// ============================================================================
// ============================================================================
// RESUMEN GERENCIAL
// ============================================================================
function obtenerResumenGerencial(params) {
  var fecha = "";
  if (params) fecha = (params.fecha || "").toString().trim();
  if (fecha === "") fecha = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");

  var ss = obtenerSpreadsheet();
  var sheetHist = ss.getSheetByName("HISTORIAL");
  var sheetSaldos = ss.getSheetByName("SALDOS");
  if (!sheetHist) return { status: "ERROR", mensaje: "Falta HISTORIAL" };

  var tz = "America/Caracas";

  // === LEER SALDOS ACTUALES ===
  var saldosActuales = {};
  if (sheetSaldos) {
    var lastRowS = sheetSaldos.getLastRow();
    if (lastRowS >= 2) {
      var dataS = sheetSaldos.getRange(2, 1, lastRowS - 1, 2).getValues();
      for (var i = 0; i < dataS.length; i++) {
        var cta = dataS[i][0] ? dataS[i][0].toString().trim() : "";
        if (cta !== "") saldosActuales[cta] = limpiarNumero(dataS[i][1]);
      }
    }
  }

  // === LEER HISTORIAL ===
  var lastRow = sheetHist.getLastRow();
  if (lastRow < 2) {
    return {
      status: "SUCCESS",
      fecha: fecha,
      ventas: { pos: 0, pm: 0, efectivo: 0, divisas: 0 },
      saldos: [],
      resumen: { ingresos: 0, egresos: 0, comisiones: 0, ganancia: 0, margen: 0 },
      categorias: [],
      totales: { ingresos: 0, egresos: 0 }
    };
  }

  var data = sheetHist.getRange(2, 1, lastRow - 1, 16).getValues();

  // === MÓVIMIENTOS POSTERIORES AL DÍA ===
  // (para reconstruir el saldo inicio del día)
  var movsPosteriores = {};

  // === TOTALES DEL DÍA ===
  var ventasPOS = 0, ventasPM = 0, ventasEfectivo = 0, ventasDivisas = 0;
  var ingresosDia = 0, egresosDia = 0, comisionesDia = 0;
  var porCategoria = {};
  var porCuentaDia = {};

  for (var j = 0; j < data.length; j++) {
    var row = data[j];
    var idTx = row[0] ? row[0].toString().trim().toUpperCase() : "";
    if (idTx.indexOf("TX-") !== 0) continue;

    var f = "";
    try {
      var vf = row[1];
      if (vf instanceof Date) f = Utilities.formatDate(vf, tz, "yyyy-MM-dd");
      else f = vf.toString().substring(0, 10);
    } catch (e) { f = row[1].toString().substring(0, 10); }

    var tipo = row[2] ? row[2].toString().toUpperCase() : "OPERACION";
    var origen = row[3] ? row[3].toString() : "";
    var destino = row[4] ? row[4].toString() : "";
    var montoNeto = limpiarNumero(row[7]);
    var comision = limpiarNumero(row[8]);
    var categoria = row[12] ? row[12].toString() : "";
    var moneda = row[6] ? row[6].toString().toUpperCase() : "BS";

    var esDelDia = (f === fecha);
    var esPosterior = (f > fecha);

    // === MÓVIMIENTOS POSTERIORES (para retro-calcular saldo inicio) ===
    if (esPosterior) {
      // Revertimos el efecto de este movimiento
      var ctaAfectada = "";
      var esSumaParaSaldo = false;
      if (tipo.indexOf("INGRESO") !== -1 || tipo.indexOf("CIERRE") !== -1) {
        ctaAfectada = destino;
        esSumaParaSaldo = true;
      } else if (tipo.indexOf("EGRESO") !== -1 || tipo.indexOf("NOMINA") !== -1 ||
                 tipo.indexOf("LIQUIDACION") !== -1 || tipo.indexOf("CARGO") !== -1) {
        ctaAfectada = origen;
        esSumaParaSaldo = false;
      } else if (tipo.indexOf("TRASPASO") !== -1) {
        // Ambos: origen baja, destino sube
        if (origen) {
          movsPosteriores[origen] = (movsPosteriores[origen] || 0) + montoNeto;
        }
        if (destino) {
          movsPosteriores[destino] = (movsPosteriores[destino] || 0) - montoNeto;
        }
        continue;
      } else if (tipo.indexOf("COMPRA_DIVISA") !== -1) {
        // Origen baja montoBs, destino sube montoDivisa
        var montoBsDiv = limpiarNumero(row[5]);
        if (origen) movsPosteriores[origen] = (movsPosteriores[origen] || 0) + montoBsDiv;
        if (destino) movsPosteriores[destino] = (movsPosteriores[destino] || 0) - montoNeto;
        continue;
      }

      if (ctaAfectada) {
        // si fue suma (+), hay que restar para ir al día anterior
        // si fue resta (−), hay que sumar
        var efecto = esSumaParaSaldo ? -montoNeto : montoNeto;
        movsPosteriores[ctaAfectada] = (movsPosteriores[ctaAfectada] || 0) + efecto;
      }
      continue;
    }

    if (!esDelDia) continue;

    // === CONTABILIZAR DEL DÍA ===
    var esIngreso = tipo.indexOf("INGRESO") !== -1 ||
                    tipo.indexOf("CIERRE_POS") !== -1 ||
                    tipo.indexOf("CIERRE_PAGO_MOVIL") !== -1;

    if (tipo === "CIERRE_POS") {
      ventasPOS += montoNeto;
      ingresosDia += montoNeto;
    } else if (tipo === "CIERRE_PAGO_MOVIL") {
      ventasPM += montoNeto;
      ingresosDia += montoNeto;
    } else if (esIngreso) {
      ingresosDia += montoNeto;
      if (moneda === "USD" || moneda === "USDT") {
        ventasDivisas += montoNeto;
      } else {
        ventasEfectivo += montoNeto;
      }
    } else {
      // Egresos
      if (tipo.indexOf("NOMINA") !== -1 || tipo.indexOf("LIQUIDACION") !== -1) {
        egresosDia += montoNeto;
      } else if (tipo.indexOf("TRASPASO") !== -1 || tipo.indexOf("COMPRA_DIVISA") !== -1 || tipo.indexOf("PRESTAMO") !== -1 || categoria === "PRESTAMO_TRABAJADOR" || categoria === "PRESTAMO") {
        // Préstamos, Traspasos y compra divisa no son egresos reales
      } else {
        egresosDia += montoNeto;
      }
    }
    comisionesDia += comision;

    if (categoria !== "" && !esIngreso && tipo.indexOf("TRASPASO") === -1 && tipo.indexOf("COMPRA_DIVISA") === -1) {
      if (!porCategoria[categoria]) porCategoria[categoria] = 0;
      porCategoria[categoria] += montoNeto;
    }

    // Movimientos del día por cuenta (para bloque de saldos)
    var ctaDia = "";
    var deltaDia = 0;
    if (esIngreso) {
      ctaDia = destino;
      deltaDia = montoNeto;
    } else if (tipo.indexOf("TRASPASO") !== -1) {
      // Ignoramos para el resumen por cuenta (es cambio interno)
      continue;
    } else if (tipo.indexOf("COMPRA_DIVISA") !== -1) {
      continue;
    } else {
      ctaDia = origen;
      deltaDia = -montoNeto;
    }
    if (ctaDia) {
      if (!porCuentaDia[ctaDia]) porCuentaDia[ctaDia] = { ingresos: 0, egresos: 0 };
      if (deltaDia > 0) porCuentaDia[ctaDia].ingresos += deltaDia;
      else porCuentaDia[ctaDia].egresos += Math.abs(deltaDia);
    }
  }

  // === ARMAR BLOQUE SALDOS ===
  var saldosArr = [];
  var cuentas = Object.keys(saldosActuales);
  for (var k = 0; k < cuentas.length; k++) {
    var c = cuentas[k];
    var saldoActual = saldosActuales[c] || 0;
    var ajuste = movsPosteriores[c] || 0;
    var saldoFinalDia = saldoActual + ajuste; // saldo al cerrar ese día
    var mov = porCuentaDia[c] || { ingresos: 0, egresos: 0 };
    var saldoInicio = saldoFinalDia - mov.ingresos + mov.egresos;

    saldosArr.push({
      cuenta: c,
      inicio: saldoInicio,
      ingresos: mov.ingresos,
      egresos: mov.egresos,
      final: saldoFinalDia
    });
  }

  // === ARMAR CATEGORÍAS ===
  var catArr = [];
  for (var cc in porCategoria) {
    catArr.push({ nombre: cc, monto: porCategoria[cc] });
  }
  catArr.sort(function(a, b) { return b.monto - a.monto; });

  // === ARMAR RESUMEN ===
  var ganancia = ingresosDia - egresosDia;
  var margen = ingresosDia > 0 ? (ganancia / ingresosDia * 100) : 0;

  return {
    status: "SUCCESS",
    fecha: fecha,
    ventas: {
      pos: ventasPOS,
      pm: ventasPM,
      efectivo: ventasEfectivo,
      divisas: ventasDivisas
    },
    saldos: saldosArr,
    resumen: {
      ingresos: ingresosDia,
      egresos: egresosDia,
      comisiones: comisionesDia,
      ganancia: ganancia,
      margen: margen
    },
    categorias: catArr
  };
}
function onOpen() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var hojas = ["SALDOS", "HISTORIAL", "HISTORIAL_CIERRES", "NOMINA_PERSONAL", "CONFIG", "TASAS_HISTORICO", "DIFERENCIAS_CAMBIARIAS", "MAESTRO_CUENTAS"];
  hojas.forEach(function(nombre) {
    var sheet = ss.getSheetByName(nombre);
    if (!sheet) return;
    try {
      var lastCol = sheet.getLastColumn();
      if (lastCol > 0) {
        for (var i = 1; i <= lastCol; i++) {
          sheet.autoResizeColumn(i);
        }
        for (var j = 1; j <= lastCol; j++) {
          var ancho = sheet.getColumnWidth(j);
          if (ancho > 300) sheet.setColumnWidth(j, 300);
          if (ancho < 80) sheet.setColumnWidth(j, 80);
        }
      }
      if (nombre === "SALDOS") {
        sheet.getRange("B2:B").setNumberFormat("#,##0.00");
      } else if (nombre === "HISTORIAL") {
        sheet.getRange("A2:A").setNumberFormat("@");
        sheet.getRange("B2:B").setNumberFormat("dd/mm/yyyy hh:mm");
        sheet.getRange("F2:F").setNumberFormat("#,##0.00");
        sheet.getRange("H2:H").setNumberFormat("#,##0.00");
        sheet.getRange("I2:I").setNumberFormat("#,##0.00");
        sheet.getRange("K2:K").setNumberFormat("#,##0.00");
        sheet.getRange("L2:L").setNumberFormat("#,##0.00");
      } else if (nombre === "HISTORIAL_CIERRES") {
        sheet.getRange("B2:B").setNumberFormat("dd/mm/yyyy hh:mm");
        sheet.getRange("C2:H").setNumberFormat("#,##0.00");
        sheet.getRange("K2:L").setNumberFormat("#,##0.00");
      } else if (nombre === "NOMINA_PERSONAL") {
        sheet.getRange("E2:E").setNumberFormat("dd/mm/yyyy");
        sheet.getRange("F2:G").setNumberFormat("#,##0.00");
        sheet.getRange("J2:K").setNumberFormat("#,##0.00");
        sheet.getRange("L2:L").setNumberFormat("dd/mm/yyyy");
      } else if (nombre === "CONFIG") {
        sheet.getRange("B2:B").setNumberFormat("#,##0.00");
      } else if (nombre === "TASAS_HISTORICO") {
        sheet.getRange("A2:A").setNumberFormat("dd/mm/yyyy");
        sheet.getRange("B2:E").setNumberFormat("#,##0.00");
      } else if (nombre === "DIFERENCIAS_CAMBIARIAS") {
        sheet.getRange("B2:B").setNumberFormat("dd/mm/yyyy");
        sheet.getRange("C2:H").setNumberFormat("#,##0.00");
      }
    } catch (e) {}
  });
}



function obtenerDetalleCierre(payload) {
  var idCierre = "";
  var fechaCierre = "";
  var ventaTotalPayload = 0;
  var descuadrePayload = 0;
  var tasaBCVPayload = 0;
  if (payload) {
    idCierre = (payload.idCierre || "").toString().trim();
    fechaCierre = (payload.fechaCierre || "").toString().trim();
    ventaTotalPayload = limpiarNumero(payload.ventaTotal || 0);
    descuadrePayload = limpiarNumero(payload.descuadre || 0);
    tasaBCVPayload = limpiarNumero(payload.tasaBCV || 0);
  }
  if (idCierre === "") return { status: "ERROR", mensaje: "Falta idCierre" };

  var ss = obtenerSpreadsheet();
  var sheetHist = ss.getSheetByName("HISTORIAL");
  if (!sheetHist) return { status: "ERROR", mensaje: "Falta HISTORIAL" };

  var lastRow = sheetHist.getLastRow();
  if (lastRow < 2) return { status: "SUCCESS", distribucion: [], gastosVenta: [], gastosAcumulado: [] };

  var tz = "America/Caracas";
  var data = sheetHist.getRange(2, 1, lastRow - 1, 16).getValues();

  var distribucion = [];
  var gastosVenta = [];
  var gastosAcumulado = [];

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var idTx = row[0] ? row[0].toString().trim().toUpperCase() : "";
    if (idTx.indexOf("TX-") !== 0) continue;

    var idSesion = row[15] ? row[15].toString().trim() : "";
    var fechaFila = _normalizarFecha(row[1], tz);
    var coincidePorId = (idSesion === idCierre);
    var coincidePorFecha = (idSesion === "" && fechaFila === fechaCierre);
    if (!coincidePorId && !coincidePorFecha) continue;

    var tipo = row[2] ? row[2].toString().toUpperCase() : "";
    var cuenta = row[4] ? row[4].toString() : "";
    var monto = limpiarNumero(row[5]);
    var montoNeto = limpiarNumero(row[7]);
    var comision = limpiarNumero(row[8]);
    var concepto = row[9] ? row[9].toString() : "";
    var categoria = row[12] ? row[12].toString() : "";
    var marca = row[13] ? row[13].toString().toUpperCase() : "";
    var origenFondos = row[14] ? row[14].toString().toUpperCase() : "ACUMULADO";

    if (tipo.indexOf("CIERRE_POS") === 0) {
      distribucion.push({ cuenta: cuenta, metodo: "POS", monto: monto, montoNeto: montoNeto, comision: comision, concepto: concepto });
    } else if (tipo.indexOf("CIERRE_PAGO_MOVIL") === 0) {
      distribucion.push({ cuenta: cuenta, metodo: "PM", monto: monto, montoNeto: montoNeto, comision: 0, concepto: concepto });
    } else if (tipo.indexOf("INGRESO") === 0 && marca === "S") {
      distribucion.push({ cuenta: cuenta, metodo: "VENTA_DIA", monto: monto, montoNeto: montoNeto, comision: 0, concepto: concepto });
    } else if (tipo.indexOf("EGRESO") === 0 || tipo.indexOf("PAGO_NOMINA") === 0 || tipo.indexOf("LIQUIDACION") === 0 || tipo.indexOf("PRESTAMO") === 0 || tipo.indexOf("TRASPASO") === 0 || tipo.indexOf("FALTANTE") === 0) {
      var item = {
        idTx: idTx, tipo: tipo, cuenta: cuenta, monto: monto,
        montoNeto: montoNeto, comision: comision, concepto: concepto,
        categoria: categoria, origenFondos: origenFondos
      };
      if (origenFondos === "VENTA_DIA") {
        gastosVenta.push(item);
      } else if (tipo.indexOf("TRASPASO") !== 0) {
        gastosAcumulado.push(item);
      }
    }
  }

  var distribucionPorCuenta = {};
  var totalDistribucion = 0;
  for (var d = 0; d < distribucion.length; d++) {
    var itD = distribucion[d];
    var cta = itD.cuenta;
    if (!distribucionPorCuenta[cta]) {
      distribucionPorCuenta[cta] = { cuenta: cta, pos: 0, pm: 0, total: 0, items: [] };
    }
    var neto = itD.montoNeto > 0 ? itD.montoNeto : itD.monto;
    if (itD.metodo === "POS") distribucionPorCuenta[cta].pos += neto;
    else if (itD.metodo === "PM") distribucionPorCuenta[cta].pm += neto;
    else distribucionPorCuenta[cta].pos += neto;

    distribucionPorCuenta[cta].total += neto;
    distribucionPorCuenta[cta].items.push({ metodo: itD.metodo, monto: neto, concepto: itD.concepto || "" });
    totalDistribucion += neto;
  }

  var gastosVentaPorCat = {};
  var totalGastosVenta = 0;
  for (var gv = 0; gv < gastosVenta.length; gv++) {
    var itG = gastosVenta[gv];
    var cat = itG.categoria || "OTROS";
    var montoGasto = itG.montoNeto + itG.comision;
    if (!gastosVentaPorCat[cat]) gastosVentaPorCat[cat] = { categoria: cat, monto: 0, items: [] };
    gastosVentaPorCat[cat].monto += montoGasto;
    gastosVentaPorCat[cat].items.push(itG);
    totalGastosVenta += montoGasto;
  }

  var gastosAcumPorCat = {};
  var totalGastosAcum = 0;
  for (var ga = 0; ga < gastosAcumulado.length; ga++) {
    var itA = gastosAcumulado[ga];
    var cat2 = itA.categoria || "OTROS";
    var montoGasto2 = itA.montoNeto + itA.comision;
    if (!gastosAcumPorCat[cat2]) gastosAcumPorCat[cat2] = { categoria: cat2, monto: 0, items: [] };
    gastosAcumPorCat[cat2].monto += montoGasto2;
    gastosAcumPorCat[cat2].items.push(itA);
    totalGastosAcum += montoGasto2;
  }

  var arrDistribucion = [];
  for (var k1 in distribucionPorCuenta) arrDistribucion.push(distribucionPorCuenta[k1]);
  var arrGastosVenta = [];
  for (var k2 in gastosVentaPorCat) arrGastosVenta.push(gastosVentaPorCat[k2]);
  var arrGastosAcum = [];
  for (var k3 in gastosAcumPorCat) arrGastosAcum.push(gastosAcumPorCat[k3]);

  var pendientes = [];
  var totalPendientes = 0;
  var sheetCP = ss.getSheetByName("CUENTAS_PENDIENTES");
  if (sheetCP) {
    var lastCP = sheetCP.getLastRow();
    if (lastCP >= 2) {
      var dataCP = sheetCP.getRange(2, 1, lastCP - 1, 12).getValues();
      for (var p = 0; p < dataCP.length; p++) {
        var estadoP = dataCP[p][8] ? dataCP[p][8].toString().toUpperCase() : "";
        if (estadoP !== "PENDIENTE") continue;
        var montoP = limpiarNumero(dataCP[p][6]);
        var monedaP = dataCP[p][7] ? dataCP[p][7].toString().toUpperCase() : "BS";
        pendientes.push({ tercero: dataCP[p][4] ? dataCP[p][4].toString() : "", concepto: dataCP[p][5] ? dataCP[p][5].toString() : "", monto: montoP, moneda: monedaP });
        if (monedaP === "BS") totalPendientes += montoP;
      }
    }
  }

  var ventaTotal = ventaTotalPayload;
  var descuadreCierre = descuadrePayload;
  var tasaBCV = tasaBCVPayload;
  var tasaUSDT = 0;
  var horaCierre = "";
  var sheetCierres = ss.getSheetByName("HISTORIAL_CIERRES");
  if (sheetCierres) {
    var lastC = sheetCierres.getLastRow();
    if (lastC >= 2) {
      var dataC = sheetCierres.getRange(2, 1, lastC - 1, 12).getValues();
      for (var c2 = 0; c2 < dataC.length; c2++) {
        if (dataC[c2][0].toString().trim() === idCierre) {
          ventaTotal = limpiarNumero(dataC[c2][3]);
          descuadreCierre = limpiarNumero(dataC[c2][7]);
          tasaBCV = limpiarNumero(dataC[c2][10]);
          tasaUSDT = limpiarNumero(dataC[c2][11]);
          try {
            var vfh = dataC[c2][1];
            if (vfh instanceof Date) horaCierre = Utilities.formatDate(vfh, tz, "HH:mm");
            else {
              var matchH = vfh.toString().match(/(\d{1,2}):(\d{2})/);
              if (matchH) horaCierre = matchH[0];
            }
          } catch (e) {}
          break;
        }
      }
    }
  }
  
  return {
    status: "SUCCESS", idCierre: idCierre, distribucion: arrDistribucion, gastosVenta: arrGastosVenta, gastosAcumulado: arrGastosAcum,
    totalDistribucion: totalDistribucion, totalGastosVenta: totalGastosVenta, totalGastosAcumulado: totalGastosAcum,
    ventaTotal: ventaTotal, descuadreCierre: descuadreCierre, tasaBCV: tasaBCV, tasaUSDT: tasaUSDT, horaCierre: horaCierre,
    pendientes: pendientes, totalPendientes: totalPendientes
  };
}

function _normalizarFecha(valor, tz) {
  if (!valor) return "";
  if (valor instanceof Date) {
    return Utilities.formatDate(valor, tz || "America/Caracas", "yyyy-MM-dd");
  }
  var str = valor.toString().trim();
  if (str === "") return "";
  if (/^\d{4}-\d{2}-\d{2}/.test(str)) return str.substring(0, 10);
  var partesFecha = str.split(' ')[0];
  if (/^\d{1,2}\/\d{1,2}\/\d{4}$/.test(partesFecha)) {
    var p = partesFecha.split('/');
    var dd = p[0].length === 1 ? '0' + p[0] : p[0];
    var mm = p[1].length === 1 ? '0' + p[1] : p[1];
    return p[2] + '-' + mm + '-' + dd;
  }
  if (/^\d{1,2}\/\d{1,2}\/\d{4}$/.test(partesFecha)) {
    var p2 = partesFecha.split('/');
    var mm2 = p2[0].length === 1 ? '0' + p2[0] : p2[0];
    var dd2 = p2[1].length === 1 ? '0' + p2[1] : p2[1];
    return p2[2] + '-' + mm2 + '-' + dd2;
  }
  return str.substring(0, 10);
}

function obtenerCierresDelRango(payload) {
  var desde = "";
  var hasta = "";
  if (payload) {
    desde = (payload.fechaDesde || "").toString().trim();
    hasta = (payload.fechaHasta || "").toString().trim();
  }
  if (desde === "" || hasta === "") {
    var hoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
    desde = hoy; hasta = hoy;
  }

  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("HISTORIAL_CIERRES");
  if (!sheet) return { status: "ERROR", cierres: [] };

  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return { status: "SUCCESS", cierres: [] };

  var tz = "America/Caracas";
  var data = sheet.getRange(2, 1, lastRow - 1, 12).getValues();
  var cierres = [];

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var idCierre = row[0] ? row[0].toString().trim() : "";
    if (idCierre === "") continue;

    var f = "";
    try {
      var vf = row[1];
      if (vf instanceof Date) f = Utilities.formatDate(vf, tz, "yyyy-MM-dd");
      else f = vf.toString().substring(0, 10);
    } catch (e) { continue; }

    if (f < desde || f > hasta) continue;

    cierres.push({
      idCierre: idCierre, fecha: f,
      montoVentaUSD: limpiarNumero(row[2]), ventaEsperadaBs: limpiarNumero(row[3]),
      ventaUSDT: limpiarNumero(row[4]), totalEquivalenteBs: limpiarNumero(row[5]),
      totalCobradoUSD: limpiarNumero(row[6]), descuadreBs: limpiarNumero(row[7]),
      estado: row[8] ? row[8].toString() : "CERRADO", observacion: row[9] ? row[9].toString() : "",
      tasaUSD: limpiarNumero(row[10]), tasaUSDT: limpiarNumero(row[11])
    });
  }

  cierres.reverse();
  return { status: "SUCCESS", fechaDesde: desde, fechaHasta: hasta, cierres: cierres, cantidad: cierres.length };
}

function obtenerHistorialPrestamos(payload) {
  var cedula = "";
  if (payload) cedula = (payload.cedula || "").toString().trim();
  if (cedula === "") return { status: "ERROR", mensaje: "Falta cédula", historial: [], deudaActual: 0 };

  var cedulaClean = cedula.replace(/[^0-9]/g, "");
  var ss = obtenerSpreadsheet();
  var sheetHist = ss.getSheetByName("HISTORIAL");
  if (!sheetHist) return { status: "ERROR", historial: [], deudaActual: 0 };

  var lastRow = sheetHist.getLastRow();
  if (lastRow < 2) return { status: "SUCCESS", historial: [], deudaActual: 0 };

  var tz = "America/Caracas";
  var data = sheetHist.getRange(2, 1, lastRow - 1, 16).getValues();
  var historial = [];

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var idTx = row[0] ? row[0].toString().trim().toUpperCase() : "";
    if (idTx.indexOf("TX-") !== 0) continue;

    var categoria = row[12] ? row[12].toString().toUpperCase() : "";
    if (categoria !== "PRESTAMO_TRABAJADOR") continue;

    var concepto = row[9] ? row[9].toString() : "";
    if (concepto.indexOf(cedulaClean) === -1) continue;

    var f = _normalizarFecha(row[1], tz);
    var monto = limpiarNumero(row[5]);
    var montoNeto = limpiarNumero(row[7]);

    historial.push({ idTx: idTx, fecha: f, monto: montoNeto > 0 ? montoNeto : monto, concepto: concepto });
  }

  historial.reverse();
  var deudaActual = 0;
  var sheetTrab = ss.getSheetByName("NOMINA_PERSONAL") || ss.getSheetByName("TRABAJADORES") || ss.getSheetByName("PERSONAL");
  if (sheetTrab) {
    var dataT = sheetTrab.getDataRange().getValues();
    for (var j = 1; j < dataT.length; j++) {
      var cedT = (dataT[j][2] || dataT[j][0] || "").toString().replace(/[^0-9]/g, "");
      if (cedT === cedulaClean) {
        deudaActual = limpiarNumero(dataT[j][9] || 0);
        break;
      }
    }
  }

  return { status: "SUCCESS", cedula: cedula, historial: historial, deudaActual: deudaActual, cantidad: historial.length };
}

function migrarDeudasHistoricas() {
  Logger.log('=== INICIO MIGRACION ===');
  var ss = obtenerSpreadsheet();
  var sheetTrab = ss.getSheetByName("NOMINA_PERSONAL");
  var sheetHist = ss.getSheetByName("HISTORIAL");
  if (!sheetTrab || !sheetHist) return;

  var lastT = sheetTrab.getLastRow();
  if (lastT < 2) return;
  var dataT = sheetTrab.getRange(2, 1, lastT - 1, 13).getValues();
  
  var trabajadores = [];
  for (var i = 0; i < dataT.length; i++) {
    var cedula = (dataT[i][2] || "").toString().replace(/[^0-9]/g, "");
    var deudaActual = limpiarNumero(dataT[i][9] || 0);
    if (cedula !== "" && deudaActual > 0) {
      trabajadores.push({ cedula: cedula, nombre: dataT[i][1] ? dataT[i][1].toString().trim() : "", deudaActual: deudaActual });
    }
  }

  var lastH = sheetHist.getLastRow();
  var sumaPorCedula = {};
  if (lastH >= 2) {
    var dataH = sheetHist.getRange(2, 1, lastH - 1, 16).getValues();
    for (var j = 0; j < dataH.length; j++) {
      var cat = dataH[j][12] ? dataH[j][12].toString().toUpperCase() : "";
      if (cat !== "PRESTAMO_TRABAJADOR") continue;
      var matchCed = dataH[j][9] ? dataH[j][9].toString().match(/\(V-?(\d+)\)|V-?(\d+)/) : null;
      if (!matchCed) continue;
      var cedConc = (matchCed[1] || matchCed[2] || "").replace(/[^0-9]/g, "");
      if (cedConc === "") continue;
      var montoBs = limpiarNumero(dataH[j][7] || dataH[j][5] || 0);
      var tasa = limpiarNumero(dataH[j][10] || 1);
      if (!sumaPorCedula[cedConc]) sumaPorCedula[cedConc] = 0;
      sumaPorCedula[cedConc] += (tasa > 0 ? montoBs / tasa : 0);
    }
  }

  var hoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  var tasaDefault = 871.37;
  var cfg = obtenerTasasConfig();
  if (cfg && cfg.tasaUSD) tasaDefault = cfg.tasaUSD;

  var filasMigrar = [];
  for (var k = 0; k < trabajadores.length; k++) {
    var t = trabajadores[k];
    var deudaPrevia = Math.round((t.deudaActual - (sumaPorCedula[t.cedula] || 0)) * 100) / 100;
    if (deudaPrevia < 0.01) continue;
    
    filasMigrar.push([
      "TX-HIST-" + t.cedula + "-" + Date.now(), hoy, "EGRESO", "PERSONAL", "VARIAS",
      (deudaPrevia * tasaDefault), "BS", (deudaPrevia * tasaDefault), 0,
      "PRESTAMO HISTORICO - " + t.nombre + " (V-" + t.cedula + ") | $" + deudaPrevia.toFixed(2),
      tasaDefault, 0, "PRESTAMO_TRABAJADOR", "S", "ACUMULADO", ""
    ]);
  }

  if (filasMigrar.length > 0) {
    sheetHist.getRange(lastH + 1, 1, filasMigrar.length, 16).setValues(filasMigrar);
  }
}

function _normCuenta(s) { return (s || "").toString().toUpperCase().replace(/[_ ]/g, "").trim(); }

function _parseCuentasMulti(str) {
  var res = [];
  if (!str) return res;
  var partes = str.toString().split("|");
  for (var i = 0; i < partes.length; i++) {
    var m = partes[i].trim().match(/^([^:]+):\s*\+?\s*([\d.,]+)\s*([A-Z]{2,4})?/);
    if (!m) continue;
    var monto = limpiarNumero(m[2]);
    if (monto > 0 && m[1].toLowerCase().indexOf("comisión") !== 0 && m[1].toLowerCase().indexOf("comision") !== 0) {
      res.push({ cuenta: m[1].trim(), monto: monto, moneda: (m[3] || "BS").toUpperCase() });
    }
  }
  return res;
}

function _deltasDeMovimiento(mov, cuentaNorm) {
  var deltas = [];
  var tipo = mov.tipo;

  if (tipo.indexOf("PAGO_NOMINA") === 0 || tipo.indexOf("LIQUIDACION") === 0) {
    _parseCuentasMulti(mov.concepto).forEach(function(p) { if (_normCuenta(p.cuenta) === cuentaNorm) deltas.push(-p.monto); });
    return deltas;
  }
  if (tipo.indexOf("COMPRA_DIVISA") === 0) {
    if (_normCuenta(mov.origen) === cuentaNorm) deltas.push(-mov.monto);
    if (_normCuenta(mov.destino) === cuentaNorm) {
      var mDiv = mov.concepto.match(/([\d.,]+)\s+a\s+tasa/i);
      if (mDiv) deltas.push(limpiarNumero(mDiv[1]));
    }
    return deltas;
  }
  if (tipo.indexOf("TRASPASO") === 0) {
    var enviado = limpiarNumero((mov.concepto.match(/Enviado:\s*([\d.,]+)/) || [0, mov.monto])[1]);
    var recibido = limpiarNumero((mov.concepto.match(/Recibido:\s*([\d.,]+)/) || [0, mov.montoNeto])[1]);
    var com = limpiarNumero((mov.concepto.match(/Com:\s*([\d.,]+)/) || [0, 0])[1]);
    if (_normCuenta(mov.origen) === cuentaNorm) deltas.push(-(enviado + com));
    if (_normCuenta(mov.destino) === cuentaNorm) deltas.push(recibido);
    return deltas;
  }
  if (tipo.indexOf("CIERRE_POS") === 0 || tipo.indexOf("CIERRE_PAGO_MOVIL") === 0) {
    if (_normCuenta(mov.destino) === cuentaNorm) deltas.push(mov.montoNeto > 0 ? mov.montoNeto : mov.monto);
    return deltas;
  }
  if (tipo.indexOf("INGRESO") === 0) {
    var partesI = _parseCuentasMulti(mov.destino);
    if (partesI.length > 0) partesI.forEach(function(p) { if (_normCuenta(p.cuenta) === cuentaNorm) deltas.push(p.monto); });
    else if (_normCuenta(mov.destino) === cuentaNorm) deltas.push(mov.montoNeto > 0 ? mov.montoNeto : mov.monto);
    return deltas;
  }
  if (tipo.indexOf("EGRESO") === 0 || tipo.indexOf("CARGO") === 0 || tipo.indexOf("PRESTAMO") === 0 || tipo.indexOf("FALTANTE") === 0) {
    var partesE = _parseCuentasMulti(mov.origen);
    if (partesE.length > 0) {
      partesE.forEach(function(p, idx) {
        if (_normCuenta(p.cuenta) === cuentaNorm) {
          var d = -p.monto;
          if (idx === 0 && mov.comision > 0) {
            var comApl = mov.comision;
            if (p.moneda === "USD" && mov.tasaUSD > 0) comApl = mov.comision / mov.tasaUSD;
            else if (p.moneda === "USDT" && mov.tasaUSDT > 0) comApl = mov.comision / mov.tasaUSDT;
            d -= comApl;
          }
          deltas.push(d);
        }
      });
    } else if (_normCuenta(mov.origen) === cuentaNorm) deltas.push(-mov.monto);
    return deltas;
  }
  return deltas;
}

function obtenerConciliacionPorCuenta(payload) {
  var desde = _normalizarFecha((payload.fechaDesde || "").toString().trim(), "America/Caracas");
  var hasta = _normalizarFecha((payload.fechaHasta || "").toString().trim(), "America/Caracas");
  if (desde === "" || hasta === "") {
    var hoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
    desde = hoy; hasta = hoy;
  }

  var ss = obtenerSpreadsheet();
  var sheetSaldos = ss.getSheetByName("SALDOS");
  var sheetHist = ss.getSheetByName("HISTORIAL");
  if (!sheetSaldos || !sheetHist) return { status: "ERROR", mensaje: "Faltan pestañas" };

  var saldosActuales = {};
  var lastS = sheetSaldos.getLastRow();
  if (lastS >= 2) {
    var dataS = sheetSaldos.getRange(2, 1, lastS - 1, 2).getValues();
    for (var i = 0; i < dataS.length; i++) {
      var cta = dataS[i][0] ? dataS[i][0].toString().trim() : "";
      if (cta) saldosActuales[cta] = limpiarNumero(dataS[i][1]);
    }
  }

  var tz = "America/Caracas";
  var lastH = sheetHist.getLastRow();
  var movimientos = [];
  if (lastH >= 2) {
    var dataH = sheetHist.getRange(2, 1, lastH - 1, 16).getValues();
    for (var j = 0; j < dataH.length; j++) {
      var row = dataH[j];
      var idTx = row[0] ? row[0].toString().trim().toUpperCase() : "";
      if (idTx.indexOf("TX-") !== 0) continue;
      var f = _normalizarFecha(row[1], tz);
      if (f === "") continue;
      movimientos.push({
        fecha: f, tipo: row[2] ? row[2].toString().toUpperCase() : "",
        origen: row[3] ? row[3].toString() : "", destino: row[4] ? row[4].toString() : "",
        monto: limpiarNumero(row[5]), montoNeto: limpiarNumero(row[7]), comision: limpiarNumero(row[8]),
        concepto: row[9] ? row[9].toString() : "", categoria: row[12] ? row[12].toString() : "",
        tasaUSD: limpiarNumero(row[10]), tasaUSDT: limpiarNumero(row[11])
      });
    }
  }

  var tasaRango = 0;
  for (var tr = 0; tr < movimientos.length; tr++) {
    var mv = movimientos[tr];
    if (mv.fecha >= desde && mv.fecha <= hasta && mv.tasaUSD > 0) { tasaRango = mv.tasaUSD; break; }
  }
  if (tasaRango === 0) {
    for (var tr2 = movimientos.length - 1; tr2 >= 0; tr2--) {
      if (movimientos[tr2].tasaUSD > 0) { tasaRango = movimientos[tr2].tasaUSD; break; }
    }
  }
  if (tasaRango === 0) {
    var cfg = obtenerTasasConfig();
    if (cfg && cfg.tasas && cfg.tasas.BCV) tasaRango = cfg.tasas.BCV;
  }

  var resultado = [];
  for (var k = 0; k < Object.keys(saldosActuales).length; k++) {
    var cuenta = Object.keys(saldosActuales)[k];
    var cuentaNorm = _normCuenta(cuenta);
    var saldoActual = saldosActuales[cuenta];
    var ingresosRango = 0, egresosRango = 0, ajustePosterior = 0, movsCuenta = [];

    for (var m = 0; m < movimientos.length; m++) {
      var mov = movimientos[m];
      var esEnRango = (mov.fecha >= desde && mov.fecha <= hasta);
      var esPosterior = (mov.fecha > hasta);
      if (!esEnRango && !esPosterior) continue;

      var deltas = _deltasDeMovimiento(mov, cuentaNorm);
      if (deltas.length === 0) continue;

      var deltaTotal = 0;
      for (var d = 0; d < deltas.length; d++) deltaTotal += deltas[d];

      if (esEnRango) {
        if (deltaTotal > 0) ingresosRango += deltaTotal;
        else egresosRango += Math.abs(deltaTotal);
        movsCuenta.push({
          fecha: mov.fecha, tipo: mov.tipo, concepto: mov.concepto, categoria: mov.categoria,
          monto: Math.abs(deltaTotal), signo: deltaTotal > 0 ? 1 : -1,
          tasaUSD: mov.tasaUSD > 0 ? mov.tasaUSD : tasaRango, tasaUSDT: mov.tasaUSDT
        });
      } else {
        ajustePosterior += deltaTotal;
      }
    }

    var saldoFinalRango = saldoActual - ajustePosterior;
    var saldoInicioRango = saldoFinalRango - ingresosRango + egresosRango;

    resultado.push({
      cuenta: cuenta, saldoInicio: saldoInicioRango, ingresos: ingresosRango, egresos: egresosRango,
      esperado: saldoFinalRango, saldoActual: saldoActual, tasaUSD: tasaRango, movimientos: movsCuenta
    });
  }

  return { status: "SUCCESS", fechaDesde: desde, fechaHasta: hasta, tasaUSD: tasaRango, cuentas: resultado };
}

function obtenerPendientesPorPagar() {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("CUENTAS_PENDIENTES");
  if (!sheet) return { status: "ERROR", pendientes: [] };
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return { status: "SUCCESS", pendientes: [] };

  var data = sheet.getRange(2, 1, lastRow - 1, 12).getValues();
  var pendientes = [];

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var estado = row[8] ? row[8].toString().toUpperCase() : "PENDIENTE";
    if (estado !== "PENDIENTE") continue; 
    pendientes.push({
      id: row[0] ? row[0].toString() : "", tercero: row[4] ? row[4].toString() : "",
      concepto: row[5] ? row[5].toString() : "", monto: limpiarNumero(row[6]), moneda: row[7] ? row[7].toString() : "BS"
    });
  }
  return { status: "SUCCESS", pendientes: pendientes };
}

function procesarOperacionTrabajador(payload) {
  var ss = obtenerSpreadsheet();
  var sheetHistorial = ss.getSheetByName("HISTORIAL");
  var sheetSaldos = ss.getSheetByName("SALDOS");
  if (!sheetHistorial || !sheetSaldos) return { status: "ERROR", mensaje: "Faltan pestañas" };

  var fechaOp = payload.fechaOperacion || Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  var cedulaBuscada = (payload.cedula || "").toString().trim();

  if (cedulaBuscada !== "") {
    // Calcular Lunes y Domingo de la semana de la operación
    var d = new Date(fechaOp + "T12:00:00");
    var diaSemana = d.getDay() || 7; 
    d.setDate(d.getDate() - diaSemana + 1); // Lunes
    var lunesStr = Utilities.formatDate(d, "America/Caracas", "yyyy-MM-dd");
    d.setDate(d.getDate() + 6); // Domingo
    var domingoStr = Utilities.formatDate(d, "America/Caracas", "yyyy-MM-dd");

    var histData = sheetHistorial.getDataRange().getValues();
    for (var h = 1; h < histData.length; h++) {
      var rowH = histData[h];
      var tipoH = rowH[2] ? rowH[2].toString().toUpperCase() : "";
      if (tipoH === "PAGO_NOMINA" || tipoH === "LIQUIDACION_FINAL") {
        var fRow = _normalizarFecha(rowH[1], "America/Caracas");
        if (fRow >= lunesStr && fRow <= domingoStr && (rowH[9] || "").toString().indexOf(cedulaBuscada) !== -1) {
          return { status: "ERROR", mensaje: "Este trabajador ya fue pagado en esta semana (" + lunesStr + " al " + domingoStr + ")." };
        }
      }
    }
  }

  var idempotenciaKey = payload.idempotenciaKey || "";
  if (idempotenciaKey !== "") {
    var histCheck = sheetHistorial.getDataRange().getValues();
    for (var hi = Math.max(1, histCheck.length - 100); hi < histCheck.length; hi++) {
      if ((histCheck[hi][9] || "").toString().indexOf("IDEMP:" + idempotenciaKey) !== -1) {
        return { status: "SUCCESS", exito: true, idTx: histCheck[hi][0].toString(), mensaje: "Ya registrado", duplicado: true };
      }
    }
  }

  var idTx = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);
  var montoBsNeto = limpiarNumero(payload.montoBsNeto || payload.montoBsCalculado || 0);
  var comisionBs = limpiarNumero(payload.comisionBs || 0);
  var tasaUSD = limpiarNumero(payload.tasaUSD || 0);
  var tipoOperacion = payload.tipoOperacion || "PAGO_NOMINA";
  var cedula = payload.cedula || "";
  var nombre = payload.nombre || "";
  var esLiquidacion = tipoOperacion.toUpperCase().indexOf("LIQUIDACI") !== -1 || tipoOperacion.toUpperCase().indexOf("FINIQUITO") !== -1;
  var descuentoDeudaUSD = limpiarNumero(payload.descuentoDeuda || 0);
  var descuentoFaltasUSD = limpiarNumero(payload.descuentoFaltas || 0);
  var nuevaDeuda = limpiarNumero(payload.nuevoSaldoDeuda || 0);
  var fuentes = payload.fuentesPago;

  if (!fuentes || !Array.isArray(fuentes) || fuentes.length === 0) return { status: "ERROR", mensaje: "Debes agregar al menos una fuente de pago." };

  var sumaFuentes = 0;
  for (var fi = 0; fi < fuentes.length; fi++) { sumaFuentes += limpiarNumero(fuentes[fi].monto || 0); }
  if (Math.abs(sumaFuentes - montoBsNeto) > 0.01) return { status: "ERROR", mensaje: "Suma de fuentes no coincide con el neto." };

  var descripcionFuentes = [];
  var totalComisionCalculada = 0;

  for (var fi = 0; fi < fuentes.length; fi++) {
    var cuentaF = (fuentes[fi].cuenta || "").toString().trim();
    var montoF = limpiarNumero(fuentes[fi].monto || 0);
    var metodoF = (fuentes[fi].metodo || "EFECTIVO").toString().toUpperCase();
    if (cuentaF === "" || montoF <= 0) continue;

    var comisionF = metodoF === "EFECTIVO" ? 0 : montoF * 0.003;
    var totalDebitarF = montoF + comisionF;
    if (obtenerSaldoCuenta(sheetSaldos, cuentaF) < totalDebitarF) return { status: "ERROR", mensaje: "Fondos insuficientes en " + cuentaF };

    actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaF, totalDebitarF, false);
    descripcionFuentes.push(cuentaF + ": " + montoF.toFixed(2));
    totalComisionCalculada += comisionF;
  }

  var origenFondos = (payload.origenFondos || "ACUMULADO").toString().toUpperCase();
  var concepto = (esLiquidacion ? "LIQUIDACIÓN FINAL - " : "PAGO NÓMINA - ") + tipoOperacion + ": " + nombre + " (V-" + cedula + ") | " + descripcionFuentes.join(" | ");
  if (idempotenciaKey !== "") concepto += " | IDEMP:" + idempotenciaKey;
  if (descuentoDeudaUSD > 0.01) concepto += " | Desc. préstamo: $" + descuentoDeudaUSD.toFixed(2) + " USD";
  if (descuentoFaltasUSD > 0.01) concepto += " | Desc. faltas: $" + descuentoFaltasUSD.toFixed(2) + " USD";

  var tasaFinalProc = tasaUSD;
  var fuenteFinalProc = "SISTEMA";

  sheetHistorial.appendRow([
    idTx, new Date(), esLiquidacion ? "LIQUIDACION_FINAL" : "PAGO_NOMINA",
    "VARIAS", "PERSONAL", (montoBsNeto + totalComisionCalculada), "BS", montoBsNeto, totalComisionCalculada,
    concepto, tasaUSD, 0, esLiquidacion ? "LIQUIDACION" : "NOMINA", "N", origenFondos, "",
    tasaFinalProc, fuenteFinalProc, montoBsNeto
  ]);

  var sheetTrab = ss.getSheetByName("NOMINA_PERSONAL") || ss.getSheetByName("TRABAJADORES") || ss.getSheetByName("PERSONAL");
  if (sheetTrab) {
    var data = sheetTrab.getDataRange().getValues();
    var cedulaBuscada = cedula.toString().replace(/[^0-9]/g, "");
    for (var i = 1; i < data.length; i++) {
      var cedulaFila = (data[i][2] || data[i][0] || "").toString().replace(/[^0-9]/g, "");
      if (cedulaFila === cedulaBuscada && cedulaBuscada !== "") {
          if (!esLiquidacion && descuentoDeudaUSD > 0) {
          var deudaActualEnHoja = limpiarNumero(data[i][9] || 0);
          var nuevaDeudaCalculada = deudaActualEnHoja - descuentoDeudaUSD;
          if (nuevaDeudaCalculada < 0) nuevaDeudaCalculada = 0; // Evita deudas negativas
          sheetTrab.getRange(i + 1, 10).setValue(nuevaDeudaCalculada);
          nuevaDeuda = nuevaDeudaCalculada; // Actualizamos la variable para el recibo
        }
        if (esLiquidacion) {
          sheetTrab.getRange(i + 1, 9).setValue("INACTIVO");
          sheetTrab.getRange(i + 1, 12).setValue(payload.fechaEgreso || Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd"));
          sheetTrab.getRange(i + 1, 10).setValue(0);
        }
        break;
      }
    }
  }

  try {
    var sheetRecibos = ss.getSheetByName("RECIBOS_DETALLE");
    if (!sheetRecibos) {
      sheetRecibos = ss.insertSheet("RECIBOS_DETALLE");
      sheetRecibos.appendRow(["ID_TX", "FECHA", "CEDULA", "TIPO", "DETALLE_JSON"]);
    }
    var reciboData = {
      idTx: idTx, tipo: tipoOperacion, nombre: nombre, cedula: cedula,
      cuenta: fuentes.map(function(f) { return f.cuenta + ": " + f.monto; }).join(" | "),
      detSemana: limpiarNumero(payload.detSemana || 0), detPrestaciones: limpiarNumero(payload.detPrestaciones || 0),
      detVacaciones: limpiarNumero(payload.detVacaciones || 0), detUtilidades: limpiarNumero(payload.detUtilidades || 0),
      detAyudaFamiliar: limpiarNumero(payload.detAyudaFamiliar || 0), detBonoAlimenticio: limpiarNumero(payload.detBonoAlimenticio || 0),
      detComision: limpiarNumero(payload.detComision || 0), totalSalarial: limpiarNumero(payload.totalSalarial || 0),
      totalNoSalarial: limpiarNumero(payload.totalNoSalarial || 0), montoBrutoUSD: limpiarNumero(payload.montoBruto || 0),
      descuentoDeuda: descuentoDeudaUSD, descuentoFaltas: descuentoFaltasUSD, deudaAnterior: limpiarNumero(payload.deudaAnterior || 0),
      montoUSD: limpiarNumero(payload.montoTotal || 0), montoBs: montoBsNeto, tasa: tasaUSD, nuevoSaldoDeuda: nuevaDeuda,
      fecha: Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd HH:mm:ss"),
      antiguedad: payload.antiguedad || "", fechaEgreso: payload.fechaEgreso || "",
      textoLegal: payload.notaLegal || (esLiquidacion ? "HE RECIBIDO A MI ENTERA SATISFACCION EL PAGO DE MI LIQUIDACIÓN" : "HE RECIBIDO A MI ENTERA SATISFACCION POR MI SEMANA DE TRABAJO"),
      notaLegalBono: payload.notaLegalBono || null, adicionales: payload.adicionales || []
    };
    sheetRecibos.appendRow([idTx, reciboData.fecha, cedula, esLiquidacion ? "LIQUIDACION_FINAL" : "PAGO_NOMINA", JSON.stringify(reciboData)]);
  } catch (errRecibo) {}

  return { status: "SUCCESS", exito: true, idTx: idTx, mensaje: "Pago registrado correctamente" };
}

function obtenerDetalleRecibo(payload) {
  var idTx = payload ? (payload.idTx || payload.id || "").toString().trim().toUpperCase() : "";
  if (idTx === "") return { status: "ERROR", mensaje: "Falta idTx" };

  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("RECIBOS_DETALLE");
  if (!sheet) return { status: "ERROR", mensaje: "No existe la hoja RECIBOS_DETALLE" };

  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return { status: "ERROR", mensaje: "No hay recibos guardados" };

  var data = sheet.getRange(2, 1, lastRow - 1, 5).getValues();
  for (var i = 0; i < data.length; i++) {
    if ((data[i][0] || "").toString().trim().toUpperCase() === idTx) {
      try { return { status: "SUCCESS", exito: true, recibo: JSON.parse(data[i][4] || "{}") }; } catch (e) { return { status: "ERROR", mensaje: "Error al parsear JSON" }; }
    }
  }
  return { status: "ERROR", mensaje: "Recibo no encontrado para el idTx: " + idTx };
}

// ESTA ES LA FUNCIÓN BUENA (COPIAR Y PEGAR)
function _resolverTasas(payload) {
  var fechaOp = payload.fechaOperacion || Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  var hoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  var tasaUSD = limpiarNumero(payload.tasaUSD || 0);
  var tasaUSDT = limpiarNumero(payload.tasaUSDT || 0);

  if (fechaOp < hoy) {
    var tasaHist = obtenerTasaPorFecha(fechaOp);
    if (tasaHist && tasaHist.BCV > 0) {
      tasaUSD = tasaHist.BCV;
      tasaUSDT = tasaHist.USDT;
    }
  }
  return { tasaUSD: tasaUSD, tasaUSDT: tasaUSDT };
}

function _calcularEstadisticasRango(desde, hasta) {
  var ss = obtenerSpreadsheet();
  var sheetHist = ss.getSheetByName("HISTORIAL");
  var sheetDif = ss.getSheetByName("DIFERENCIAS_CAMBIARIAS");
  
  var resultado = {
    ventas: 0, comisiones: 0, ventasNetas: 0,
    proveedores: 0, personal: 0, nomina: 0, servicios: 0, otros: 0, comprasDivisa: 0,
    totalEgresos: 0, gastosNoOperativos: 0,
    perdidaCambiariaUSD: 0, perdidaCambiariaBs: 0,
    ganancia: 0, margen: 0, movimientos: 0
  };
  
  if (!sheetHist) return resultado;
  var lastRow = sheetHist.getLastRow();
  if (lastRow < 2) return resultado;

  var tz = "America/Caracas";
  var data = sheetHist.getRange(2, 1, lastRow - 1, 16).getValues();

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var idTx = row[0] ? row[0].toString().trim().toUpperCase() : "";
    if (idTx.indexOf("TX-") !== 0) continue;

    var f = _normalizarFecha(row[1], tz);
    if (f === "" || f < desde || f > hasta) continue;

    resultado.movimientos++;
    var tipo = row[2] ? row[2].toString().toUpperCase() : "";
    var monto = limpiarNumero(row[5]);
    var montoNeto = limpiarNumero(row[7]);
    var comision = limpiarNumero(row[8]);
    var concepto = row[9] ? row[9].toString().toUpperCase() : "";
    var categoria = row[12] ? row[12].toString().toUpperCase() : "";

    var esIngreso = tipo.indexOf("INGRESO") === 0 || tipo.indexOf("CIERRE") === 0;

    if (esIngreso) {
      // SOLO contamos como venta si es un CIERRE o si es un INGRESO categorizado explícitamente como VENTA
      var esVentaReal = (tipo.indexOf("CIERRE") === 0) || 
                        (tipo === "INGRESO" && (categoria === "VENTA" || categoria === "VENTAS"));
      
      if (esVentaReal) {
        var brutoBs = (montoNeto > 0 ? montoNeto : monto) + comision;
        resultado.ventas += brutoBs;
        resultado.comisiones += comision;
      }
    } else {
      var neto = montoNeto > 0 ? montoNeto : monto;
      
      if (tipo.indexOf("TRASPASO") === 0) {
        resultado.gastosNoOperativos += comision; // Comisión de traspaso va a gasto financiero
        continue;
      }

      // 1. EXCLUIMOS PRÉSTAMOS
      if (tipo.indexOf("PRESTAMO") === 0 || categoria === "PRESTAMO_TRABAJADOR") continue;
      
      // 2. EXCLUIMOS EL GASTO DE LA COMISIÓN DEL CIERRE PARA NO DOBLE CONTAR
      if (categoria === "GASTOS_BANCARIOS" && concepto.indexOf("COMISIÓN CIERRE") !== -1) continue;
      
      // 3. COMPRA DE DIVISAS (P2P): No es egreso, es cambio de activo. No afecta la ganancia.
      if (tipo.indexOf("COMPRA_DIVISA") === 0) {
        // Solo registramos la comisión bancaria como gasto si existiera
        if (comision > 0) resultado.gastosNoOperativos += comision;
        continue; // Sale del bucle sin sumar a totalEgresos
      } 
      
      // 4. GASTOS NO OPERATIVOS
      if (categoria === "GASTO_FINANCIERO" || categoria === "IMPUESTOS" || categoria === "AJUSTE_CAJA" || categoria === "RETIRO_DUENO" || categoria === "GASTOS_PERSONALES") {
        resultado.gastosNoOperativos += neto;
      } 
      // 5. GASTOS OPERATIVOS REALES
      else if (tipo.indexOf("NOMINA") !== -1 || tipo.indexOf("LIQUIDACION") !== -1 || tipo.indexOf("PAGO_NOMINA") !== -1) {
        resultado.nomina += neto;
        resultado.totalEgresos += neto;
      } else if (categoria === "PERSONAL") {
        resultado.personal += neto;
        resultado.totalEgresos += neto;
      } else if (categoria === "PROVEEDORES" || categoria === "PAGO A PROVEEDORES") {
        resultado.proveedores += neto;
        resultado.totalEgresos += neto;
      } else if (categoria === "SERVICIOS" || categoria === "SERVICIOS BÁSICOS" || categoria === "ALQUILER") {
        resultado.servicios += neto;
        resultado.totalEgresos += neto;
      } else {
        resultado.otros += neto;
        resultado.totalEgresos += neto;
      }
    }
  }

  if (sheetDif) {
    var lastDif = sheetDif.getLastRow();
    if (lastDif >= 2) {
      var dataDif = sheetDif.getRange(2, 1, lastDif - 1, 8).getValues();
      for (var d = 0; d < dataDif.length; d++) {
        var fechaDif = _normalizarFecha(dataDif[d][1], tz);
        if (fechaDif >= desde && fechaDif <= hasta) {
          var difUsd = limpiarNumero(dataDif[d][7]);
          var tasaCierre = limpiarNumero(dataDif[d][3]);
          resultado.perdidaCambiariaUSD += difUsd;
          resultado.perdidaCambiariaBs += (difUsd * tasaCierre);
        }
      }
    }
  }

  resultado.ventasNetas = resultado.ventas - resultado.comisiones;
  // La ganancia se calcula SOLO con egresos operativos reales y pérdida cambiaria.
  // Las compras de divisas ya fueron ignoradas en el bucle.
  resultado.ganancia = resultado.ventasNetas - resultado.totalEgresos - resultado.perdidaCambiariaBs;
  resultado.margen = resultado.ventasNetas > 0 ? (resultado.ganancia / resultado.ventasNetas) * 100 : 0;

  return resultado;
}

function obtenerEstadisticas(payload) {
  var desde = "";
  var hasta = "";
  if (payload) {
    desde = (payload.fechaDesde || "").toString().trim();
    hasta = (payload.fechaHasta || "").toString().trim();
  }
  if (desde === "" || hasta === "") {
    var hoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
    desde = hoy;
    hasta = hoy;
  }

  var actual = _calcularEstadisticasRango(desde, hasta);

  // Calcular rango anterior de igual longitud
  var d1 = new Date(desde + "T12:00:00");
  var d2 = new Date(hasta + "T12:00:00");
  var dias = Math.round((d2.getTime() - d1.getTime()) / 86400000) + 1;
  var prevHasta = new Date(d1.getTime() - 86400000);
  var prevDesde = new Date(prevHasta.getTime() - (dias - 1) * 86400000);
  var prevDesdeStr = Utilities.formatDate(prevDesde, "America/Caracas", "yyyy-MM-dd");
  var prevHastaStr = Utilities.formatDate(prevHasta, "America/Caracas", "yyyy-MM-dd");

  var anterior = _calcularEstadisticasRango(prevDesdeStr, prevHastaStr);

  // Calcular variaciones %
  function varPct(act, ant) {
    if (ant <= 0) return act > 0 ? 100 : 0;
    return ((act - ant) / ant) * 100;
  }

  return {
    status: "SUCCESS",
    fechaDesde: desde,
    fechaHasta: hasta,
    fechaDesdeAnterior: prevDesdeStr,
    fechaHastaAnterior: prevHastaStr,
    actual: actual,
    anterior: anterior,
    variaciones: {
      ventas: varPct(actual.ventas, anterior.ventas),
      egresos: varPct(actual.totalEgresos, anterior.totalEgresos),
      ganancia: varPct(actual.ganancia, anterior.ganancia),
      personal: varPct(actual.personal, anterior.personal),
      nomina: varPct(actual.nomina, anterior.nomina),
      proveedores: varPct(actual.proveedores, anterior.proveedores),
      comisiones: varPct(actual.comisiones, anterior.comisiones),
      servicios: varPct(actual.servicios, anterior.servicios)
    }
  };
}
function limpiarSobranteFalso() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheetHist = ss.getSheetByName("HISTORIAL");
  var sheetSaldos = ss.getSheetByName("SALDOS");

  if (!sheetHist || !sheetSaldos) {
    SpreadsheetApp.getUi().alert("No se encontraron las hojas.");
    return;
  }

  var data = sheetHist.getDataRange().getValues();
  var filaAEliminar = -1;
  var montoFalso = 0;

  // Buscamos la transacción exacta del error
  for (var i = 0; i < data.length; i++) {
    if (data[i][0] === "TX-143082294") {
      filaAEliminar = i + 1;
      montoFalso = data[i][5]; // El monto está en la columna F
      break;
    }
  }

  if (filaAEliminar !== -1) {
    // 1. Borramos la fila de HISTORIAL
    sheetHist.deleteRow(filaAEliminar);
    
    // 2. Restamos el dinero falso del saldo de Caja Efectivo Bs
    var dataSaldos = sheetSaldos.getDataRange().getValues();
    for (var j = 0; j < dataSaldos.length; j++) {
      if (dataSaldos[j][0] === "Caja Efectivo Bs") {
        var saldoActual = dataSaldos[j][1];
        var nuevoSaldo = saldoActual - montoFalso;
        sheetSaldos.getRange(j + 1, 2).setValue(nuevoSaldo);
        break;
      }
    }
    SpreadsheetApp.getUi().alert("✅ ¡Listo! Se borró el sobrante falso de " + montoFalso + " Bs y se corrigió el saldo de la Caja.");
  } else {
    SpreadsheetApp.getUi().alert("No se encontró el error. Quizás ya lo borraste.");
  }
}
function TEST_SimularCierre() {
  var payloadPrueba = {
    fechaOperacion: Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd"),
    tasaUSD: 890.00,
    tasaUSDT: 1000.00,
    descuadreBs: 10.00, // Simulamos un descuadre de 10 Bs (menor a 50)
    desglose: {
      "Bancamiga": {
        punto: 1000.00,
        pagoMovil: 500.00,
        comision1Activa: true,
        comision2Activa: true
      }
    }
  };
  
  var resultado = registrarCierreJornada(payloadPrueba);
  Logger.log(resultado);
}
function PRUEBA_OPERACION_DESTINO() {
  var payload = {
    tipoOperacion: "EGRESO",
    categoria: "Pago a Proveedores",
    concepto: "Prueba de destino",
    montoBsPagado: 10,
    cuentaSalida: "Caja Efectivo Bs",
    proveedor: "PROVEEDOR DE PRUEBA", // Simulamos que Flutter envía esto
    tasaUSD: 890,
    fechaOperacion: Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd")
  };
  
  var res = registrarOperacion(payload);
  Logger.log(res);
}
// ============================================================================
// 9. GESTIÓN DE TRABAJADORES (ALTA Y BAJA)
// ============================================================================

function registrarNuevoTrabajador(payload) {
  var ss = obtenerSpreadsheet();
  var sheetTrab = ss.getSheetByName("NOMINA_PERSONAL");
  if (!sheetTrab) return { status: "ERROR", mensaje: "No existe NOMINA_PERSONAL" };

  var cedula = (payload.cedula || "").toString().trim();
  var nombre = (payload.nombre || "").toString().trim().toUpperCase();
  var cargo = (payload.cargo || "").toString().trim();
  var fechaIngreso = (payload.fechaIngreso || "").toString().trim();
  var sueldoBase = limpiarNumero(payload.sueldoBase || 0);
  var ayudaFamiliar = limpiarNumero(payload.ayudaFamiliar || 0);
  var frecuencia = (payload.frecuencia || "Semanal").toString().trim();
  var bonoAlimenticio = limpiarNumero(payload.bonoAlimenticio || 0);

  if (cedula === "" || nombre === "") {
    return { status: "ERROR", mensaje: "La cédula y el nombre son obligatorios." };
  }

  // Validar que no exista la cédula
  var data = sheetTrab.getDataRange().getValues();
  var cedulaClean = cedula.replace(/[^0-9]/g, "");
  for (var i = 1; i < data.length; i++) {
    var cedFila = (data[i][2] || data[i][0] || "").toString().replace(/[^0-9]/g, "");
    if (cedFila === cedulaClean && cedulaClean !== "") {
      return { status: "ERROR", mensaje: "Ya existe un trabajador con esta cédula." };
    }
  }

  // Insertar nueva fila (respetando el orden de tus columnas)
  sheetTrab.appendRow([
    "",               // Columna A (vacía o ID interno)
    nombre,           // B: Nombre
    cedula,           // C: Cédula
    cargo,            // D: Cargo
    fechaIngreso,     // E: Fecha Ingreso
    sueldoBase,       // F: Sueldo Base
    ayudaFamiliar,    // G: Ayuda Familiar
    frecuencia,       // H: Frecuencia
    "ACTIVO",         // I: Estado
    0,                // J: Deuda
    bonoAlimenticio,  // K: Bono Alimenticio
    "",               // L: Fecha Egreso
    "[]"              // M: Adicionales (JSON vacío)
  ]);

  return { status: "SUCCESS", exito: true, mensaje: "Trabajador registrado exitosamente." };
}

function darDeBajaTrabajador(payload) {
  var ss = obtenerSpreadsheet();
  var sheetTrab = ss.getSheetByName("NOMINA_PERSONAL");
  if (!sheetTrab) return { status: "ERROR", mensaje: "No existe NOMINA_PERSONAL" };

  var cedula = (payload.cedula || "").toString().replace(/[^0-9]/g, "");
  var fechaEgreso = (payload.fechaEgreso || "").toString().trim();

  if (cedula === "" || fechaEgreso === "") {
    return { status: "ERROR", mensaje: "Faltan datos para procesar la baja." };
  }

  var data = sheetTrab.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    var cedFila = (data[i][2] || data[i][0] || "").toString().replace(/[^0-9]/g, "");
    if (cedFila === cedula) {
      // Columna I (índice 8) = Estado | Columna L (índice 11) = Fecha Egreso
      sheetTrab.getRange(i + 1, 9).setValue("INACTIVO");
      sheetTrab.getRange(i + 1, 12).setValue(fechaEgreso);
      return { status: "SUCCESS", exito: true, mensaje: "Trabajador dado de baja correctamente." };
    }
  }

  return { status: "ERROR", mensaje: "Trabajador no encontrado." };
}

function corregirSaldosUSDTV11() {
  const hoja = SpreadsheetApp.getActiveSheet(); 
  if (!hoja.getName().toUpperCase().includes("HISTORIAL")) return;

  const ultimaFila = hoja.getLastRow();
  if (ultimaFila < 2) return;

  // Leemos de A a L
  const datos = hoja.getRange(2, 1, ultimaFila - 1, 12).getValues(); 
  let cambiados = 0;

  for (let i = 0; i < datos.length; i++) {
    let tipo = datos[i][2] ? datos[i][2].toString().toUpperCase() : ""; // C
    let origen = datos[i][3] ? datos[i][3].toString().toUpperCase() : ""; // D
    let destino = datos[i][4] ? datos[i][4].toString().toUpperCase() : ""; // E
    let monto = Number(datos[i][5]) || 0; // F
    let moneda = datos[i][6] ? datos[i][6].toString().toUpperCase() : ""; // G
    let tasaUsdt = Number(datos[i][11]) || 0; // L

    // Si es un INGRESO o EGRESO, y toca la cuenta USDT, pero está guardado como BS
    if ((tipo === "INGRESO" || tipo === "EGRESO") && 
        (origen.includes("USDT") || destino.includes("USDT")) && 
        moneda === "BS") {
      
      // Si hay una tasa válida, convertimos el monto a USDT real
      if (tasaUsdt > 0) {
        let montoEnUSDT = monto / tasaUsdt;
        
        // Redondeamos a 2 decimales
        datos[i][5] = Math.round(montoEnUSDT * 100) / 100; // MONTO (F)
        datos[i][6] = "USDT"; // MONEDA (G)
        
        cambiados++;
      }
    }
  }

  if (cambiados > 0) {
    // Escribimos solo F, G (MONTO y MONEDA)
    let resultadosFG = [];
    for (let i = 0; i < datos.length; i++) {
      resultadosFG.push([datos[i][5], datos[i][6]]); 
    }
    hoja.getRange(2, 6, resultadosFG.length, 2).setValues(resultadosFG);
    SpreadsheetApp.getUi().alert(`✅ Éxito. Se corrigieron ${cambiados} operaciones de USDT que estaban guardadas como Bs.`);
  } else {
    SpreadsheetApp.getUi().alert("No se encontraron operaciones de USDT con montos en Bs.");
  }
}