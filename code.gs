// ============================================================================
// FINANZAS PRO — BACKEND
// Versión: 3.0 (diferencia cambiaria + tasas histórico)
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
      action === "verificarEstadoDelDia"||
      action === "buscarTrabajador" ||
      action === "obtenerConsultasConFecha" ||
      action === "obtenerResumenGerencial" ||
      action === "obtenerPendientes" ||
      action === "obtenerPendientesPorPagar" ||  // <--- AGREGADO AQUÍ
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
      else if (action === "verificarEstadoDelDia") resG = verificarEstadoDelDia();
      else if (action === "buscarTrabajador") resG = buscarTrabajadorCompleto(payload);
      else if (action === "obtenerConsultasConFecha") resG = obtenerConsultasConFecha(payload);
      else if (action === "obtenerResumenGerencial") resG = obtenerResumenGerencial(payload);
      else if (action === "obtenerPendientes") resG = obtenerPendientes(payload);
      else if (action === "obtenerPendientesPorPagar") resG = obtenerPendientesPorPagar(); // <--- AGREGADO AQUÍ
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
  for (var c in saldosMap) respuesta[c] = saldosMap[c];
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
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("TASAS");
  if (!sheet) {
    throw new Error("No existe la hoja TASAS.");
  }

  var fechaBusqueda = _normalizarFecha(fecha, "America/Caracas");
  if (!fechaBusqueda) {
    fechaBusqueda = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  }
  var fuenteBuscada = (fuente || "BCV").toString().trim().toUpperCase();

  var lastRow = sheet.getLastRow();
  if (lastRow < 2) {
    throw new Error("No hay tasas registradas en la hoja TASAS.");
  }

  var data = sheet.getRange(2, 1, lastRow - 1, 7).getValues();
  var mejorTasa = null;
  var mejorFecha = "";

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var fRow = _normalizarFecha(row[0], "America/Caracas");
    var fuenteRow = (row[1] || "").toString().trim().toUpperCase();
    var valor = limpiarNumero(row[4]);

    if (fuenteRow === fuenteBuscada && fRow !== "" && fRow <= fechaBusqueda && valor > 0) {
      if (mejorFecha === "" || fRow > mejorFecha) {
        mejorFecha = fRow;
        mejorTasa = valor;
      } else if (fRow === mejorFecha) {
        mejorTasa = valor;
      }
    }
  }

  if (mejorTasa === null || mejorTasa <= 0) {
    throw new Error("No existe tasa registrada para fuente '" + fuenteBuscada + "' en la fecha " + fechaBusqueda + " o anterior.");
  }

  return mejorTasa;
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
    var fechaFila = "";
    try {
      var f = data[i][0];
      if (f instanceof Date) fechaFila = Utilities.formatDate(f, "America/Caracas", "yyyy-MM-dd");
      else fechaFila = f.toString().substring(0, 10);
    } catch (e) { fechaFila = data[i][0].toString().substring(0, 10); }

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
        comision > 0 ? "COMISIONES" : "VENTAS",
        "S", "ACUMULADO", idCierre,
        tasaRefCierre, "BCV", equivBsPos
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
        "S", "ACUMULADO", idCierre
      ]);
    }

    if (comision > 0) {
      var idTxCom = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);
      var comBs = (it.moneda === "BS") ? comision : _r2(comision * tasaItem);
      filasHistorial.push([
        idTxCom, fechaCierre, "GASTO", "Gastos Bancarios", "",
        comision, it.moneda, comBs, 0,
        "Comisión cierre " + it.cuenta + " — " + fechaOp + marcaIdemp,
        tasaBCV, tasaUSDT, "GASTOS_BANCARIOS", "S", "ACUMULADO", idCierre
      ]);
      actualizarSaldoEnHojaSaldos(sheetSaldos, "Gastos Bancarios", comision, true);
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

  var diferencia = _r2(ventaTotal - distribuido - comisiones - gastos - prestamos);
  var descuadreBs = payload.descuadreBs !== undefined ? _r2(limpiarNumero(payload.descuadreBs)) : diferencia;
  var estadoCierre = diferencia < 0 ? "FALTANTE" : "CERRADO";

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
  if (Math.abs(descuadreBs) > 0.01 || diferencia < 0) {
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
        tasaBCV, tasaUSDT, categoriaAuto, "N", "ACUMULADO", idCierre
      ]);
    } else {
      actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaAjuste, montoAuto, true);
      sheetHistorial.appendRow([
        idTxAuto, fechaCierre, "INGRESO", "VARIAS", cuentaAjuste,
        montoAuto, "BS", montoAuto, 0,
        conceptoAuto,
        tasaBCV, tasaUSDT, categoriaAuto, "N", "ACUMULADO", idCierre
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
    var nuevaFila = sheetSaldos.getLastRow() + 1;
    sheetSaldos.getRange(nuevaFila, 1).setValue(cuentaId);
    sheetSaldos.getRange(nuevaFila, 2).setValue(nuevoSaldo);
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
  var tasaUSD = limpiarNumero(payload.tasaUSD || 0);
  var tasaUSDT = limpiarNumero(payload.tasaUSDT || 0);
  var parteDelCierre = payload.parteDelCierre === true ? "S" : "N";

  // === NUEVO: flag informativo (no afecta saldo) ===
  var noAfectaSaldo = payload.noAfectaSaldo === true;

  if (montoTotal <= 0) return { status: "ERROR", mensaje: "Monto inválido." };

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
    var cuentasTxt = [];
    for (var k = 0; k < payload.cuentasDesglose.length; k++) {
      var it = payload.cuentasDesglose[k];
      var ctaD = it.cuenta || "Caja Efectivo Bs";
      var montoNat = limpiarNumero(it.monto || 0);
      var monedaNat = (it.moneda || "BS").toString().toUpperCase();
      if (k === 0) {
        cuentaComision = ctaD;
        if (monedaNat === "USD") comisionNativa = comisionBs / (tasaUSD || 1);
        else if (monedaNat === "USDT") comisionNativa = comisionBs / (tasaUSDT || 1);
        else comisionNativa = comisionBs;
      }
      if (montoNat > 0) {
        // === NUEVO: solo validar y actualizar saldo si NO es informativo ===
        if (!noAfectaSaldo) {
          var saldoD = obtenerSaldoCuenta(sheetSaldos, ctaD);
          var requerido = montoNat + (k === 0 ? comisionNativa : 0);
          if (saldoD < requerido) {
            return {
              status: "ERROR",
              mensaje: "Fondos insuficientes en " + ctaD +
                       ". Disponible: " + saldoD.toFixed(2) + " " + monedaNat +
                       " | Requerido: " + requerido.toFixed(2) + " " + monedaNat
            };
          }
          actualizarSaldoEnHojaSaldos(sheetSaldos, ctaD, montoNat, false);
        }
        cuentasTxt.push(ctaD + ": " + montoNat.toFixed(2) + " " + monedaNat);
      }
    }
    cuentaSalida = cuentasTxt.join(" | ");

    if (comisionNativa > 0 && cuentaComision !== "" && !noAfectaSaldo) {
      actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaComision, comisionNativa, false);
      cuentaSalida += " | Comisión: " + comisionNativa.toFixed(2);
    }
  } else {
    // === NUEVO: mismo flag aplica a ruta sin desglose ===
    if (!noAfectaSaldo) {
      var saldoDisponible = obtenerSaldoCuenta(sheetSaldos, cuentaSalida);
      if (saldoDisponible < montoTotal + comisionBs) {
        return {
          status: "ERROR",
          mensaje: "Fondos insuficientes en " + cuentaSalida +
                   ". Disponible: " + saldoDisponible.toFixed(2) +
                   " | Requerido: " + (montoTotal + comisionBs).toFixed(2)
        };
      }
      actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaSalida, montoTotal, false);
      if (comisionBs > 0) {
        actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaSalida, comisionBs, false);
      }
    }
  }

  var montoFinal = montoTotal + comisionBs;
  var notaComision = comisionBs > 0
    ? " | " + montoTotal.toFixed(2) + " + comisión " + comisionBs.toFixed(2) + " (" + metodoPago + ")"
    : "";

  if (idempotenciaKey !== "") {
    concepto = concepto + " | IDEMP:" + idempotenciaKey;
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
  var montoBsOp = (payload.moneda === "USD" || payload.moneda === "USDT") ? (montoFinal * tasaFinalOp) : montoFinal;

  sheetHistorial.appendRow([
    idTx, fechaTx, tipoOperacion, cuentaSalida, "VARIAS",
    montoFinal, "BS", montoFinal, comisionBs,
    concepto + notaComision,
    tasaUSD, tasaUSDT, categoria, parteDelCierre, origenFondos, "",
    tasaFinalOp, fuenteFinalOp, montoBsOp
  ]);

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

  // === SI ES PRÉSTAMO A TRABAJADOR: ACTUALIZAR DEUDA ===
  if (categoria === "PRESTAMO_TRABAJADOR" && payload.cedula) {
    try {
      var sheetTrab = ss.getSheetByName("NOMINA_PERSONAL");
      if (sheetTrab) {
        var cedulaClean = payload.cedula.toString().replace(/[^0-9]/g, "");
        var dataT = sheetTrab.getDataRange().getValues();
        var montoUSD = tasaUSD > 0 ? montoTotal / tasaUSD : 0;

        for (var ti = 1; ti < dataT.length; ti++) {
          var cedFila = (dataT[ti][2] || dataT[ti][0] || "").toString().replace(/[^0-9]/g, "");
          if (cedFila === cedulaClean && cedulaClean !== "") {
            var deudaActual = limpiarNumero(dataT[ti][9] || 0);
            var nuevaDeuda = deudaActual + montoUSD;
            sheetTrab.getRange(ti + 1, 10).setValue(nuevaDeuda);
            return {
              status: "SUCCESS", exito: true, idTx: idTx,
              mensaje: "Préstamo registrado. Deuda nueva: $" + nuevaDeuda.toFixed(2),
              deudaNueva: nuevaDeuda,
              montoUSD: montoUSD
            };
          }
        }
      }
    } catch (eTrab) {
      Logger.log("Error actualizando deuda: " + eTrab);
    }
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
  var tasaFinalCd = tasaUsada > 0 ? tasaUsada : tasaRefCd;
  var fuenteFinalCd = tasaUsada > 0 ? "MANUAL" : "USDT";

  sheetHistorial.appendRow([
    idTx,
    fechaTx,
    "COMPRA_DIVISA",
    origen.cuentaId,
    destino.cuentaId,
    montoBs,          // MONTO = cuenta ORIGEN (montoBs)
    origen.moneda,    // MONEDA = origen.moneda (NO hardcode)
    montoBs,          // MONTO_BS
    0,                // COMISION
    concepto,         // CONCEPTO
    tasa,             // TASA
    fuenteTasa,       // FUENTE_TASA
    "COMPRA_DIVISA",  // CATEGORIA
    "ABIERTA",        // PARTE_DEL_CIERRE / ESTADO
    "ACUMULADO",      // ORIGEN_FONDOS
    ""                // ID_CIERRE
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
  var tasaUSD = limpiarNumero(payload.tasaUSD || 0);
  var tasaUSDT = limpiarNumero(payload.tasaUSDT || 0);

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

  var fechaTrStr = Utilities.formatDate(fechaTx, "America/Caracas", "yyyy-MM-dd");
  var fuenteBuscadaTr = (payload.fuenteTasa || payload.fuente || "BCV").toString().toUpperCase();
  var tasaRefTr = obtenerTasa(fechaTrStr, fuenteBuscadaTr);
  var tasaFinalTr = (tasaUSD > 0) ? tasaUSD : tasaRefTr;
  var fuenteFinalTr = (tasaUSD > 0) ? "MANUAL" : fuenteBuscadaTr;
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

  if (diaSemana === 6 || diaSemana === 7) {
    return { status: "SUCCESS", tasasCargadas: true, esFinDeSemana: true, fecha: fechaHoy };
  }

  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("TASAS_HISTORICO");
  if (!sheet) return { status: "SUCCESS", tasasCargadas: false, esFinDeSemana: false, fecha: fechaHoy };

  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return { status: "SUCCESS", tasasCargadas: false, esFinDeSemana: false, fecha: fechaHoy };

  var data = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  var fechasCargadas = {};
  for (var i = 0; i < data.length; i++) {
    var f = convertirAFecha(data[i][0]);
    if (f !== "") fechasCargadas[f] = true;
  }

  var tasasCargadas = false;
  var fechaVigente = "";
  for (var d = 0; d < 5; d++) {
    var fechaCheck = new Date(hoy.getTime() - d * 24 * 60 * 60 * 1000);
    var fechaStr = Utilities.formatDate(fechaCheck, tz, "yyyy-MM-dd");
    var dow = Number(Utilities.formatDate(fechaCheck, tz, "u"));
    if (dow === 6 || dow === 7) continue;
    if (fechasCargadas[fechaStr]) {
      tasasCargadas = true;
      fechaVigente = fechaStr;
      break;
    }
  }

  return {
    status: "SUCCESS",
    tasasCargadas: tasasCargadas,
    esFinDeSemana: false,
    fecha: fechaHoy,
    fechaVigente: fechaVigente
  };
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
  var tasaUSD = limpiarNumero(payload.tasaUSD || 0);
  var tasaUSDT = limpiarNumero(payload.tasaUSDT || 0);

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
  var tasaFinalFa = (tasaUSD > 0) ? tasaUSD : tasaRefFa;
  var fuenteFinalFa = (tasaUSD > 0) ? "MANUAL" : "BCV";

  sheetHistorial.appendRow([
    idTx, fechaTx, "EGRESO", cuentaOrigen, "VARIAS",
    montoBs, "BS", montoBs, 0,
    concepto, tasaUSD, tasaUSDT, "FALTANTE", "N", "ACUMULADO", "",
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
  var tasaUSD = limpiarNumero(payload.tasaUSD || 0);
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
        cuentasTxt.push(ctaD + ": +" + montoNat.toFixed(2) + " " + monedaNat);
      }
    }
    cuentaDestino = cuentasTxt.join(" | ");
  } else {
    actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaDestino, montoBs, true);
  }

  if (idempotenciaKey !== "") {
    concepto = concepto + " | IDEMP:" + idempotenciaKey;
  }

  var fechaIngStr = Utilities.formatDate(fechaTx, "America/Caracas", "yyyy-MM-dd");
  var fuenteBuscadaIng = (payload.fuenteTasa || payload.fuente || "BCV").toString().toUpperCase();
  var tasaRefIng = obtenerTasa(fechaIngStr, fuenteBuscadaIng);
  var tasaFinalIng = (tasaUSD > 0) ? tasaUSD : tasaRefIng;
  var fuenteFinalIng = (tasaUSD > 0) ? "MANUAL" : fuenteBuscadaIng;

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
// ============================================================================
// INGRESOS YA DECLARADOS DEL DÍA (marca S) — para restarlos del cierre
// ============================================================================
function obtenerIngresosDeclaradosDelDia(payload) {
  var fecha = "";
  if (payload) fecha = (payload.fecha || "").toString().trim();
  if (fecha === "") {
    fecha = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  }

  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("HISTORIAL");
  if (!sheet) {
    return { status: "ERROR", fecha: fecha, totalBs: 0, items: [], cantidad: 0 };
  }

  var lastRow = sheet.getLastRow();
  if (lastRow < 2) {
    return { status: "SUCCESS", fecha: fecha, totalBs: 0, items: [], cantidad: 0 };
  }

  var tz = "America/Caracas";
  var data = sheet.getRange(2, 1, lastRow - 1, 16).getValues();
  var totalBs = 0;
  var items = [];
  var totalPorCuenta = {};

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var idTx = row[0] ? row[0].toString().trim().toUpperCase() : "";
    if (idTx.indexOf("TX-") !== 0) continue;

    var f = "";
    try {
      var vf = row[1];
      if (vf instanceof Date) f = Utilities.formatDate(vf, tz, "yyyy-MM-dd");
      else f = vf.toString().substring(0, 10);
    } catch (e) { continue; }

    if (f !== fecha) continue;

    var tipo = row[2] ? row[2].toString().toUpperCase() : "";
    if (tipo.indexOf("INGRESO") === -1) continue;

    var categoria = row[12] ? row[12].toString().toUpperCase() : "";
    if (categoria !== "VENTA" && categoria !== "COBRO_CLIENTE") continue;

    var marca = row[13] ? row[13].toString().trim().toUpperCase() : "";
    if (marca !== "S") continue;

    var monto = limpiarNumero(row[7]);
    if (monto <= 0) monto = limpiarNumero(row[5]);
    if (monto <= 0) continue;

    var cuenta = row[4] ? row[4].toString() : "";
    totalBs += monto;

    if (cuenta !== "") {
      var cuentaClean = cuenta.split(" | ")[0].split(":")[0].trim();
      totalPorCuenta[cuentaClean] = (totalPorCuenta[cuentaClean] || 0) + monto;
    }

    items.push({
      idTx: idTx,
      cuenta: cuenta,
      categoria: categoria,
      concepto: row[9] ? row[9].toString() : "",
      monto: monto
    });
  }

  return {
    status: "SUCCESS",
    fecha: fecha,
    totalBs: totalBs,
    totalPorCuenta: totalPorCuenta,
    items: items,
    cantidad: items.length
  };
}// ============================================================================
// REGISTRAR TRANSACCIÓN CENTRALIZADA
// ============================================================================
function registrarTransaccion(payload) {
  var ss = obtenerSpreadsheet();
  var sheetHistorial = ss.getSheetByName("HISTORIAL");
  var sheetSaldos = ss.getSheetByName("SALDOS");
  if (!sheetHistorial || !sheetSaldos) {
    return { status: "ERROR", mensaje: "Faltan hojas requeridas (HISTORIAL o SALDOS)" };
  }

  var origen = (payload.origen || payload.cuentaOrigen || payload.cuentaSalida || "Caja Efectivo Bs").toString().trim();
  var destino = (payload.destino || payload.cuentaDestino || "VARIAS").toString().trim();
  var monto = limpiarNumero(payload.monto !== undefined ? payload.monto : (payload.montoBs || payload.montoBsPagado || 0));
  var moneda = (payload.moneda || "BS").toString().toUpperCase();
  var tasa = limpiarNumero(payload.tasa !== undefined ? payload.tasa : (payload.tasaUSD || payload.tasaBCV || 0));
  var tipoMovimiento = (payload.tipo_movimiento || payload.tipoMovimiento || payload.tipoOperacion || "GASTO").toString().toUpperCase().trim();

  var comision = limpiarNumero(payload.comision !== undefined ? payload.comision : (payload.comisionBs || 0));
  var concepto = (payload.concepto || "").toString().trim();
  var categoria = (payload.categoria || "").toString().trim();
  var idempotenciaKey = (payload.idempotenciaKey || "").toString().trim();
  var origenFondos = (payload.origenFondos || "ACUMULADO").toString().toUpperCase();

  if (monto <= 0) return { status: "ERROR", mensaje: "Monto inválido." };

  if (idempotenciaKey !== "") {
    var histCheck = sheetHistorial.getDataRange().getValues();
    var inicioBusqueda = histCheck.length > 100 ? histCheck.length - 100 : 1;
    for (var hi = inicioBusqueda; hi < histCheck.length; hi++) {
      var conceptoFila = histCheck[hi][9] ? histCheck[hi][9].toString() : "";
      if (conceptoFila.indexOf("IDEMP:" + idempotenciaKey) !== -1) {
        return {
          status: "SUCCESS", exito: true,
          idTx: histCheck[hi][0].toString(),
          mensaje: "Transacción ya registrada (idempotencia)",
          duplicado: true
        };
      }
    }
  }

  var fechaTx = new Date();
  if (payload.fechaOperacion && payload.fechaOperacion.toString().trim() !== "") {
    try {
      var fp = new Date(payload.fechaOperacion + "T12:00:00");
      if (!isNaN(fp.getTime())) fechaTx = fp;
    } catch (e) {}
  }

  var idTx = "TX-" + Math.floor(Math.random() * 900000000 + 100000000);

  var fechaTxStr = Utilities.formatDate(fechaTx, "America/Caracas", "yyyy-MM-dd");
  var fuenteBuscadaTx = (payload.fuenteTasa || payload.fuente || "BCV").toString().toUpperCase();
  var tasaRefTx = obtenerTasa(fechaTxStr, fuenteBuscadaTx);
  var tasaFinalTx = (tasa > 0) ? tasa : tasaRefTx;
  var fuenteFinalTx = (tasa > 0) ? "MANUAL" : fuenteBuscadaTx;
  var totalBsTx = (moneda === "USD" || moneda === "USDT") ? (monto + comision) * tasaFinalTx : (monto + comision);

  if (tipoMovimiento === "PRESTAMO" || tipoMovimiento === "PRESTAMO_TRABAJADOR") {
    var cedula = (payload.cedula || "").toString().trim();
    if (cedula === "") return { status: "ERROR", mensaje: "Cédula obligatoria para préstamos." };
    if (tasa <= 0) return { status: "ERROR", mensaje: "Tasa inválida para préstamo." };

    var totalDebito = monto + comision;
    var saldoDisponible = obtenerSaldoCuenta(sheetSaldos, origen);
    if (saldoDisponible < totalDebito) {
      return {
        status: "ERROR",
        mensaje: "Fondos insuficientes en " + origen + ". Disponible: " + saldoDisponible.toFixed(2)
      };
    }

    var sheetTrab = ss.getSheetByName("NOMINA_PERSONAL") ||
                    ss.getSheetByName("TRABAJADORES") ||
                    ss.getSheetByName("PERSONAL");
    if (!sheetTrab) return { status: "ERROR", mensaje: "No existe hoja de Trabajadores." };

    var cedulaClean = cedula.replace(/[^0-9]/g, "");
    var dataT = sheetTrab.getDataRange().getValues();
    var filaTrab = -1;
    var deudaActual = 0.0;
    var nombreTrab = (payload.nombre || "").toString().trim();

    for (var i = 1; i < dataT.length; i++) {
      var cedFila = (dataT[i][2] || dataT[i][0] || "").toString().replace(/[^0-9]/g, "");
      if (cedFila === cedulaClean && cedulaClean !== "") {
        filaTrab = i + 1;
        deudaActual = limpiarNumero(dataT[i][9] || 0);
        if (nombreTrab === "") nombreTrab = dataT[i][1] ? dataT[i][1].toString() : "";
        break;
      }
    }

    if (filaTrab === -1) {
      return { status: "ERROR", mensaje: "Trabajador no encontrado con cédula: " + cedula };
    }

    var montoUSD = monto / tasa;
    var nuevaDeuda = deudaActual + montoUSD;

    actualizarSaldoEnHojaSaldos(sheetSaldos, origen, totalDebito, false);
    sheetTrab.getRange(filaTrab, 10).setValue(nuevaDeuda);

    var conceptoTx = concepto || ("PRÉSTAMO A TRABAJADOR - " + nombreTrab + " (V-" + cedula + ") | $" + montoUSD.toFixed(2) + " @ " + tasa.toFixed(2));
    if (idempotenciaKey !== "") conceptoTx += " | IDEMP:" + idempotenciaKey;

    sheetHistorial.appendRow([
      idTx, fechaTx, "PRESTAMO", origen, destino !== "VARIAS" ? destino : "PERSONAL",
      totalDebito, moneda, monto, comision,
      conceptoTx,
      tasa, 0, "PRESTAMO_TRABAJADOR", "S", origenFondos, "",
      tasaFinalTx, fuenteFinalTx, totalBsTx
    ]);

    return {
      status: "SUCCESS", exito: true, idTx: idTx,
      montoUSD: montoUSD, deudaAnterior: deudaActual, deudaNueva: nuevaDeuda,
      mensaje: "Préstamo registrado correctamente. Deuda actualizada: $" + nuevaDeuda.toFixed(2)
    };

  } else if (tipoMovimiento === "GASTO" || tipoMovimiento === "EGRESO") {
    var totalGasto = monto + comision;
    var saldoDispGasto = obtenerSaldoCuenta(sheetSaldos, origen);
    if (saldoDispGasto < totalGasto) {
      return {
        status: "ERROR",
        mensaje: "Fondos insuficientes en " + origen + ". Disponible: " + saldoDispGasto.toFixed(2)
      };
    }

    actualizarSaldoEnHojaSaldos(sheetSaldos, origen, totalGasto, false);

    var conceptoGasto = concepto || categoria || "Gasto";
    if (idempotenciaKey !== "") conceptoGasto += " | IDEMP:" + idempotenciaKey;

    sheetHistorial.appendRow([
      idTx, fechaTx, "EGRESO", origen, destino,
      totalGasto, moneda, monto, comision,
      conceptoGasto,
      tasa, 0, categoria || "OPERATIVO", "N", origenFondos, "",
      tasaFinalTx, fuenteFinalTx, totalBsTx
    ]);

    return { status: "SUCCESS", exito: true, idTx: idTx, mensaje: "Gasto registrado correctamente" };

  } else {
    var conceptoOtros = concepto || tipoMovimiento;
    if (idempotenciaKey !== "") conceptoOtros += " | IDEMP:" + idempotenciaKey;

    if (tipoMovimiento === "INGRESO") {
      actualizarSaldoEnHojaSaldos(sheetSaldos, destino !== "VARIAS" ? destino : origen, monto, true);
      sheetHistorial.appendRow([
        idTx, fechaTx, "INGRESO", origen, destino,
        monto, moneda, monto, comision,
        conceptoOtros,
        tasa, 0, categoria || "VENTA", "S", origenFondos, "",
        tasaFinalTx, fuenteFinalTx, totalBsTx
      ]);
    } else {
      actualizarSaldoEnHojaSaldos(sheetSaldos, origen, monto + comision, false);
      sheetHistorial.appendRow([
        idTx, fechaTx, tipoMovimiento, origen, destino,
        monto + comision, moneda, monto, comision,
        conceptoOtros,
        tasa, 0, categoria || "GENERAL", "N", origenFondos, "",
        tasaFinalTx, fuenteFinalTx, totalBsTx
      ]);
    }

    return { status: "SUCCESS", exito: true, idTx: idTx, mensaje: "Transacción registrada correctamente" };
  }
}

// ============================================================================
// PRÉSTAMO A TRABAJADOR — resta de cuenta + suma deuda en NOMINA_PERSONAL
// ============================================================================
function registrarPrestamoTrabajador(payload) {
  var p = payload || {};
  p.tipo_movimiento = "PRESTAMO";
  return registrarTransaccion(p);
}
// ============================================================================
// MOVIMIENTOS DEL DÍA — para jalar al cierre
// ============================================================================
function obtenerMovimientosDelDia(payload) {
  var fecha = "";
  if (payload) fecha = (payload.fecha || "").toString().trim();
  if (fecha === "") {
    fecha = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  }

  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("HISTORIAL");
  if (!sheet) return { status: "ERROR", movimientos: [] };

  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return { status: "SUCCESS", fecha: fecha, movimientos: [] };

  var tz = "America/Caracas";
  var data = sheet.getRange(2, 1, lastRow - 1, 16).getValues();
  var movimientos = [];

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var idTx = row[0] ? row[0].toString().trim().toUpperCase() : "";
    if (idTx.indexOf("TX-") !== 0) continue;

    var f = "";
    try {
      var vf = row[1];
      if (vf instanceof Date) f = Utilities.formatDate(vf, tz, "yyyy-MM-dd");
      else f = vf.toString().substring(0, 10);
    } catch (e) { continue; }

    if (f !== fecha) continue;

    var tipo = row[2] ? row[2].toString().toUpperCase() : "";
    var esEgreso = tipo.indexOf("EGRESO") === 0 ||
                   tipo.indexOf("CARGO_FIJO") === 0 ||
                   tipo.indexOf("PAGO_NOMINA") === 0 ||
                   tipo.indexOf("LIQUIDACION") === 0 ||
                   tipo.indexOf("PRESTAMO") === 0 ||
                   tipo.indexOf("FALTANTE") === 0;
    var esTraspaso = tipo.indexOf("TRASPASO") === 0;

    if (!esEgreso && !esTraspaso) continue;

    // Si ya tiene marca S, ya fue parte del cierre → no mostrar
    var marca = row[13] ? row[13].toString().trim().toUpperCase() : "";
    if (marca === "S") continue;

        movimientos.push({
      idTx: idTx,
      tipo: tipo,
      origen: row[3] ? row[3].toString() : "",
      destino: row[4] ? row[4].toString() : "",
      monto: limpiarNumero(row[5]),
      montoNeto: limpiarNumero(row[7]),
      comision: limpiarNumero(row[8]),
      concepto: row[9] ? row[9].toString() : "",
      categoria: row[12] ? row[12].toString() : "",
      marcaCierre: row[13] ? row[13].toString().toUpperCase() : "",
      origenFondos: row[14] ? row[14].toString().toUpperCase() : "ACUMULADO",
      esTraspaso: esTraspaso
    });
  }

  return {
    status: "SUCCESS",
    fecha: fecha,
    movimientos: movimientos,
    cantidad: movimientos.length
  };
}// ============================================================================
// DASHBOARD — Lee métricas de la hoja DASHBOARD
// ============================================================================
function obtenerDashboard(payload) {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("DASHBOARD");
  if (!sheet) return { status: "ERROR", mensaje: "No existe hoja DASHBOARD" };

  var desde = "";
  var hasta = "";
  if (payload) {
    desde = (payload.fechaDesde || "").toString().trim();
    hasta = (payload.fechaHasta || "").toString().trim();
  }
  if (desde === "" || hasta === "") {
    var hoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
    if (desde === "") desde = hoy;
    if (hasta === "") hasta = hoy;
  }

  sheet.getRange("A2").setValue(desde);
  sheet.getRange("B2").setValue(hasta);

  SpreadsheetApp.flush();

  var valores = sheet.getRange("B5:B15").getValues();
  return {
    status: "SUCCESS",
    fechaDesde: desde,
    fechaHasta: hasta,
    ventas: Number(valores[0][0]) || 0,
    comisiones: Number(valores[1][0]) || 0,
    ventasNetas: Number(valores[2][0]) || 0,
    egresosOperativos: Number(valores[3][0]) || 0,
    personal: Number(valores[4][0]) || 0,
    nomina: Number(valores[5][0]) || 0,
    totalEgresos: Number(valores[6][0]) || 0,
    cajaRango: Number(valores[7][0]) || 0,
    pendientesVencen: Number(valores[8][0]) || 0,
    gananciaReal: Number(valores[9][0]) || 0,
    margen: Number(valores[10][0]) || 0
  };
}// ============================================================================
// ESTADÍSTICAS — resumen por rango con comparativo
// ============================================================================
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

function _calcularEstadisticasRango(desde, hasta) {
  var ss = obtenerSpreadsheet();
  var sheetHist = ss.getSheetByName("HISTORIAL");
  var resultado = {
    ventas: 0,
    comisiones: 0,
    ventasNetas: 0,
    egresosOperativos: 0,
    personal: 0,
    nomina: 0,
    proveedores: 0,
    servicios: 0,
    comprasDivisa: 0,
    faltantes: 0,
    otros: 0,
    totalEgresos: 0,
    caja: 0,
    ganancia: 0,
    margen: 0,
    movimientos: 0
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

    var f = "";
    try {
      var vf = row[1];
      f = _normalizarFecha(vf, tz);
    } catch (e) { continue; }

    if (f === "" || f < desde || f > hasta) continue;

    resultado.movimientos++;

    var tipo = row[2] ? row[2].toString().toUpperCase() : "";
    var origen = row[3] ? row[3].toString() : "";
    var monto = limpiarNumero(row[5]);
    var montoNeto = limpiarNumero(row[7]);
    var comision = limpiarNumero(row[8]);
    var categoria = row[12] ? row[12].toString().toUpperCase() : "";

    var esIngreso = tipo.indexOf("INGRESO") === 0 ||
                    tipo.indexOf("CIERRE_POS") === 0 ||
                    tipo.indexOf("CIERRE_PAGO_MOVIL") === 0;

    if (esIngreso) {
      resultado.ventas += montoNeto > 0 ? montoNeto : monto;
    } else {
      var neto = montoNeto > 0 ? montoNeto : monto;
      if (tipo.indexOf("TRASPASO") === 0) continue;

      if (tipo.indexOf("COMPRA_DIVISA") === 0) {
        resultado.comprasDivisa += monto;
      } else if (tipo.indexOf("NOMINA") !== -1 || tipo.indexOf("LIQUIDACION") !== -1) {
        resultado.nomina += neto;
        resultado.totalEgresos += neto;
      } else if (categoria === "PERSONAL") {
        resultado.personal += neto;
        resultado.totalEgresos += neto;
      } else if (categoria === "PROVEEDORES" || categoria === "PAGO A PROVEEDORES") {
        resultado.proveedores += neto;
        resultado.totalEgresos += neto;
      } else if (categoria === "SERVICIOS" || categoria === "SERVICIOS BÁSICOS") {
        resultado.servicios += neto;
        resultado.totalEgresos += neto;
      } else if (categoria === "FALTANTE") {
        resultado.faltantes += neto;
        resultado.totalEgresos += neto;
      } else {
        resultado.otros += neto;
        resultado.totalEgresos += neto;
      }
    }
    resultado.comisiones += comision;
  }

  resultado.ventasNetas = resultado.ventas - resultado.comisiones;
  resultado.caja = resultado.ventasNetas - resultado.totalEgresos;
  resultado.ganancia = resultado.caja;
  resultado.margen = resultado.ventasNetas > 0
    ? (resultado.ganancia / resultado.ventasNetas) * 100
    : 0;

  return resultado;
}// ============================================================================
// DETALLE POR CATEGORÍA — lista de movimientos de una categoría
// ============================================================================
function obtenerDetallePorCategoria(payload) {
  var desde = "";
  var hasta = "";
  var categoriaBuscada = "";
  if (payload) {
    desde = (payload.fechaDesde || "").toString().trim();
    hasta = (payload.fechaHasta || "").toString().trim();
    categoriaBuscada = (payload.categoria || "").toString().trim().toUpperCase();
  }
  if (desde === "" || hasta === "") {
    var hoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
    desde = hoy;
    hasta = hoy;
  }
  if (categoriaBuscada === "") {
    return { status: "ERROR", mensaje: "Falta categoría", movimientos: [] };
  }

  var ss = obtenerSpreadsheet();
  var sheetHist = ss.getSheetByName("HISTORIAL");
  if (!sheetHist) return { status: "ERROR", movimientos: [] };

  var lastRow = sheetHist.getLastRow();
  if (lastRow < 2) return { status: "SUCCESS", movimientos: [], total: 0 };

  var tz = "America/Caracas";
  var data = sheetHist.getRange(2, 1, lastRow - 1, 16).getValues();
  var lista = [];
  var total = 0;

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var idTx = row[0] ? row[0].toString().trim().toUpperCase() : "";
    if (idTx.indexOf("TX-") !== 0) continue;

    var f = "";
    try {
      var vf = row[1];
      f = _normalizarFecha(vf, tz);
    } catch (e) { continue; }

    if (f === "" || f < desde || f > hasta) continue;

    var categoria = row[12] ? row[12].toString().toUpperCase() : "";
    var tipo = row[2] ? row[2].toString().toUpperCase() : "";

    var coincide = false;
    if (categoriaBuscada === "NOMINA") {
      coincide = tipo.indexOf("NOMINA") !== -1 || tipo.indexOf("LIQUIDACION") !== -1;
    } else {
      coincide = categoria === categoriaBuscada;
    }
    if (!coincide) continue;

    var monto = limpiarNumero(row[5]);
    var montoNeto = limpiarNumero(row[7]);
    var comision = limpiarNumero(row[8]);
    var neto = montoNeto > 0 ? montoNeto : monto;

    total += neto;
    lista.push({
      idTx: idTx,
      fecha: f,
      tipo: tipo,
      origen: row[3] ? row[3].toString() : "",
      destino: row[4] ? row[4].toString() : "",
      concepto: row[9] ? row[9].toString() : "",
      monto: monto,
      montoNeto: montoNeto,
      comision: comision,
      categoria: categoria
    });
  }

  return {
    status: "SUCCESS",
    categoria: categoriaBuscada,
    fechaDesde: desde,
    fechaHasta: hasta,
    movimientos: lista,
    total: total,
    cantidad: lista.length
  };
}// ============================================================================
// DETALLE DE UN CIERRE — filas vinculadas por ID_SESION_CIERRE
// ============================================================================
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
    } else if (tipo.indexOf("EGRESO") === 0 ||
               tipo.indexOf("PAGO_NOMINA") === 0 ||
               tipo.indexOf("LIQUIDACION") === 0 ||
               tipo.indexOf("PRESTAMO") === 0 ||
               tipo.indexOf("TRASPASO") === 0 ||
               tipo.indexOf("FALTANTE") === 0) {
      var item = {
        idTx: idTx,
        tipo: tipo,
        cuenta: cuenta,
        monto: monto,
        montoNeto: montoNeto,
        comision: comision,
        concepto: concepto,
        categoria: categoria,
        origenFondos: origenFondos
      };
      if (origenFondos === "VENTA_DIA") {
        gastosVenta.push(item);
      } else if (tipo.indexOf("TRASPASO") !== 0) {
        gastosAcumulado.push(item);
      }
    }
  }

  // Agrupar distribución por cuenta
  var distribucionPorCuenta = {};
  var totalDistribucion = 0;
  for (var d = 0; d < distribucion.length; d++) {
    var itD = distribucion[d];
    var cta = itD.cuenta;
    if (!distribucionPorCuenta[cta]) {
      distribucionPorCuenta[cta] = { cuenta: cta, pos: 0, pm: 0, total: 0, items: [] };
    }
    var neto = itD.montoNeto > 0 ? itD.montoNeto : itD.monto;
    if (itD.metodo === "POS") {
      distribucionPorCuenta[cta].pos += neto;
    } else if (itD.metodo === "PM") {
      distribucionPorCuenta[cta].pm += neto;
    } else {
      distribucionPorCuenta[cta].pos += neto;
    }
    distribucionPorCuenta[cta].total += neto;
    distribucionPorCuenta[cta].items.push({
      metodo: itD.metodo,
      monto: neto,
      concepto: itD.concepto || ""
    });
    totalDistribucion += neto;
  }

  // Agrupar gastos venta por categoría
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

  // Agrupar gastos acumulados por categoría
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

  // Obtener pendientes por pagar
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
        pendientes.push({
          tercero: dataCP[p][4] ? dataCP[p][4].toString() : "",
          concepto: dataCP[p][5] ? dataCP[p][5].toString() : "",
          monto: montoP,
          moneda: monedaP
        });
        if (monedaP === "BS") totalPendientes += montoP;
      }
    }
  }

  // Leer datos del cierre (venta total y descuadre) desde HISTORIAL_CIERRES
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
            if (vfh instanceof Date) {
              horaCierre = Utilities.formatDate(vfh, tz, "HH:mm");
            } else {
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
    status: "SUCCESS",
    idCierre: idCierre,
    distribucion: arrDistribucion,
    gastosVenta: arrGastosVenta,
    gastosAcumulado: arrGastosAcum,
    totalDistribucion: totalDistribucion,
    totalGastosVenta: totalGastosVenta,
    totalGastosAcumulado: totalGastosAcum,
    ventaTotal: ventaTotal,
    descuadreCierre: descuadreCierre,
    tasaBCV: tasaBCV,
    tasaUSDT: tasaUSDT,
    horaCierre: horaCierre,
    pendientes: pendientes,
    totalPendientes: totalPendientes
  };
}
// ============================================================================
// NORMALIZAR FECHA — acepta Date, "2026-10-03", "3/10/2026", "03/10/2026"
// ============================================================================
function _normalizarFecha(valor, tz) {
  if (!valor) return "";
  if (valor instanceof Date) {
    return Utilities.formatDate(valor, tz || "America/Caracas", "yyyy-MM-dd");
  }
  var str = valor.toString().trim();
  if (str === "") return "";

  // Caso "2026-10-03..." (ISO)
  if (/^\d{4}-\d{2}-\d{2}/.test(str)) {
    return str.substring(0, 10);
  }

  // Caso "3/10/2026" o "03/10/2026" (formato español)
  var partesFecha = str.split(' ')[0];
  if (/^\d{1,2}\/\d{1,2}\/\d{4}$/.test(partesFecha)) {
    var p = partesFecha.split('/');
    var dd = p[0].length === 1 ? '0' + p[0] : p[0];
    var mm = p[1].length === 1 ? '0' + p[1] : p[1];
    var yyyy = p[2];
    return yyyy + '-' + mm + '-' + dd;
  }

  // Caso "10/3/2026" (formato inglés M/D/YYYY)
  if (/^\d{1,2}\/\d{1,2}\/\d{4}$/.test(partesFecha)) {
    var p2 = partesFecha.split('/');
    var mm2 = p2[0].length === 1 ? '0' + p2[0] : p2[0];
    var dd2 = p2[1].length === 1 ? '0' + p2[1] : p2[1];
    var yyyy2 = p2[2];
    return yyyy2 + '-' + mm2 + '-' + dd2;
  }

  return str.substring(0, 10);
}// ============================================================================
// CIERRES DEL RANGO — lista de cierres con resumen
// ============================================================================
function obtenerCierresDelRango(payload) {
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
      idCierre: idCierre,
      fecha: f,
      montoVentaUSD: limpiarNumero(row[2]),
      ventaEsperadaBs: limpiarNumero(row[3]),
      ventaUSDT: limpiarNumero(row[4]),
      totalEquivalenteBs: limpiarNumero(row[5]),
      totalCobradoUSD: limpiarNumero(row[6]),
      descuadreBs: limpiarNumero(row[7]),
      estado: row[8] ? row[8].toString() : "CERRADO",
      observacion: row[9] ? row[9].toString() : "",
      tasaUSD: limpiarNumero(row[10]),
      tasaUSDT: limpiarNumero(row[11])
    });
  }

  cierres.reverse();

  return {
    status: "SUCCESS",
    fechaDesde: desde,
    fechaHasta: hasta,
    cierres: cierres,
    cantidad: cierres.length
  };
}
// ============================================================================
// HISTORIAL DE PRÉSTAMOS POR TRABAJADOR
// ============================================================================
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

    historial.push({
      idTx: idTx,
      fecha: f,
      monto: montoNeto > 0 ? montoNeto : monto,
      concepto: concepto
    });
  }

  historial.reverse();

  var deudaActual = 0;
  var sheetTrab = ss.getSheetByName("NOMINA_PERSONAL") ||
                  ss.getSheetByName("TRABAJADORES") ||
                  ss.getSheetByName("PERSONAL");
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

  return {
    status: "SUCCESS",
    cedula: cedula,
    historial: historial,
    deudaActual: deudaActual,
    cantidad: historial.length
  };
}// ============================================================================
// MIGRACIÓN — Crear préstamos históricos para deudas previas
// ============================================================================
function migrarDeudasHistoricas() {
  Logger.log('=== INICIO MIGRACION ===');
  var ss = obtenerSpreadsheet();
  var sheetTrab = ss.getSheetByName("NOMINA_PERSONAL");
  var sheetHist = ss.getSheetByName("HISTORIAL");
  
  if (!sheetTrab) { Logger.log('NO EXISTE NOMINA_PERSONAL'); return; }
  if (!sheetHist) { Logger.log('NO EXISTE HISTORIAL'); return; }

  // 1) Leer trabajadores
  var lastT = sheetTrab.getLastRow();
  if (lastT < 2) { Logger.log('Sin trabajadores'); return; }
  var dataT = sheetTrab.getRange(2, 1, lastT - 1, 13).getValues();
  
  var trabajadores = [];
  for (var i = 0; i < dataT.length; i++) {
    var cedula = (dataT[i][2] || "").toString().replace(/[^0-9]/g, "");
    var nombre = dataT[i][1] ? dataT[i][1].toString().trim() : "";
    var deudaActual = limpiarNumero(dataT[i][9] || 0);
    if (cedula === "" || deudaActual <= 0) continue;
    trabajadores.push({
      fila: i + 2,
      cedula: cedula,
      nombre: nombre,
      deudaActual: deudaActual
    });
  }
  Logger.log('Trabajadores con deuda: ' + trabajadores.length);

  // 2) Sumar prestamos en HISTORIAL por cedula
  var lastH = sheetHist.getLastRow();
  var sumaPorCedula = {};
  if (lastH >= 2) {
    var dataH = sheetHist.getRange(2, 1, lastH - 1, 16).getValues();
    for (var j = 0; j < dataH.length; j++) {
      var cat = dataH[j][12] ? dataH[j][12].toString().toUpperCase() : "";
      if (cat !== "PRESTAMO_TRABAJADOR") continue;
      var conceptoTx = dataH[j][9] ? dataH[j][9].toString() : "";
      // Extraer cedula del concepto
      var matchCed = conceptoTx.match(/\(V-?(\d+)\)|V-?(\d+)/);
      if (!matchCed) continue;
      var cedConc = (matchCed[1] || matchCed[2] || "").replace(/[^0-9]/g, "");
      if (cedConc === "") continue;
      var montoBs = limpiarNumero(dataH[j][7] || dataH[j][5] || 0);
      var tasa = limpiarNumero(dataH[j][10] || 1);
      var montoUSD = tasa > 0 ? montoBs / tasa : 0;
      if (!sumaPorCedula[cedConc]) sumaPorCedula[cedConc] = 0;
      sumaPorCedula[cedConc] += montoUSD;
    }
  }
  Logger.log('Cedulas con prestamos en HISTORIAL: ' + Object.keys(sumaPorCedula).length);

  // 3) Armar filas para migrar
  var hoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  var tasaDefault = 871.37;
  try {
    var cfg = obtenerTasasConfig();
    if (cfg && cfg.tasaUSD) tasaDefault = cfg.tasaUSD;
  } catch (e) {}

  var filasMigrar = [];
  for (var k = 0; k < trabajadores.length; k++) {
    var t = trabajadores[k];
    var yaRegistrado = sumaPorCedula[t.cedula] || 0;
    var deudaPrevia = t.deudaActual - yaRegistrado;
    deudaPrevia = Math.round(deudaPrevia * 100) / 100; // redondear

    Logger.log(t.nombre + ' (V-' + t.cedula + '): Deuda=' + t.deudaActual.toFixed(2) + 
               ' | En HISTORIAL=' + yaRegistrado.toFixed(2) + 
               ' | Diferencia=' + deudaPrevia.toFixed(2));

    if (deudaPrevia < 0.01) continue;

    var montoBs = deudaPrevia * tasaDefault;
    var idTx = "TX-HIST-" + t.cedula + "-" + Date.now();
    var concepto = "PRESTAMO HISTORICO - " + t.nombre + " (V-" + t.cedula + ") | $" + deudaPrevia.toFixed(2);

    filasMigrar.push([
      idTx, hoy, "EGRESO", "PERSONAL", "VARIAS",
      montoBs, "BS", montoBs, 0,
      concepto,
      tasaDefault, 0, "PRESTAMO_TRABAJADOR", "S", "ACUMULADO", ""
    ]);
  }

  if (filasMigrar.length === 0) {
    Logger.log('No hay filas para migrar');
    Logger.log('=== FIN ===');
    return;
  }

  // 4) Escribir en HISTORIAL
  var targetRow = lastH + 1;
  sheetHist.getRange(targetRow, 1, filasMigrar.length, 16).setValues(filasMigrar);
  Logger.log('FILAS MIGRADAS: ' + filasMigrar.length);
  Logger.log('=== FIN MIGRACION ===');
}function testEgreso() {
  Logger.log('=== INICIO ===');
  var res = registrarOperacion({
    tipoOperacion: "EGRESO",
    categoria: "Pago a Proveedores",
    concepto: "PRUEBA TEST",
    montoBsPagado: 100,
    cuentaSalida: "Bancamiga",
    moneda: "BS",
    tasaUSD: 872.39,
    tasaUSDT: 975,
    cuentasDesglose: [{
      cuenta: "Bancamiga",
      monto: 100,
      moneda: "BS",
      montoBs: 100
    }],
    comisionBs: 0,
    metodoPago: "TRANS_MISMO_BANCO",
    origenFondos: "ACUMULADO",
    fechaOperacion: "2026-10-06"
  });
  Logger.log('RES: ' + JSON.stringify(res));
  Logger.log('=== FIN ===');
}function testBuscarSufijo() {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("HISTORIAL");
  var data = sheet.getDataRange().getValues();
  // Buscar todas las filas que contengan IDEMP
  for (var i = 0; i < data.length; i++) {
    var concepto = data[i][9] ? data[i][9].toString() : "";
    var match = concepto.match(/IDEMP:(\S+)/);
    if (match) {
      Logger.log("Fila " + (i+1) + " | TX=" + data[i][0] + 
                 " | KEY=" + match[1] + 
                 " | últimos 8=" + match[1].slice(-8));
    }
  }
  Logger.log("=== FIN ===");
}function testAuditoriaBancos() {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("HISTORIAL");
  var data = sheet.getDataRange().getValues();
  var tz = "America/Caracas";

  // Ajusta estas fechas si quieres un rango específico
  var desde = "2026-10-01";
  var hasta = "2026-10-09";

  Logger.log("=== AUDITORIA BANCAMIGA vs BNC (" + desde + " a " + hasta + ") ===");

  var acumBancamiga = 0;
  var acumBNC = 0;
  var detalle = [];

  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    var idTx = row[0] ? row[0].toString().trim() : "";
    if (idTx.indexOf("TX-") !== 0) continue;

    var f = "";
    try {
      var vf = row[1];
      if (vf instanceof Date) f = Utilities.formatDate(vf, tz, "yyyy-MM-dd");
      else f = vf.toString().substring(0, 10);
    } catch (e) { continue; }
    if (f < desde || f > hasta) continue;

    var tipo = row[2] ? row[2].toString().toUpperCase() : "";
    var origen = row[3] ? row[3].toString() : "";
    var destino = row[4] ? row[4].toString() : "";
    var monto = limpiarNumero(row[5]);
    var concepto = row[9] ? row[9].toString() : "";
    var cat = row[12] ? row[12].toString() : "";

    var afectaBancamiga = false;
    var afectaBNC = false;
    var signoBancamiga = 0;
    var signoBNC = 0;

    // Movimiento que toca Bancamiga
    if (origen.indexOf("Bancamiga") !== -1) {
      afectaBancamiga = true;
      signoBancamiga = -1; // sale de origen
    }
    if (destino.indexOf("Bancamiga") !== -1) {
      afectaBancamiga = true;
      signoBancamiga = 1;  // entra a destino
    }
    if (origen.indexOf("BNC") !== -1) {
      afectaBNC = true;
      signoBNC = -1;
    }
    if (destino.indexOf("BNC") !== -1) {
      afectaBNC = true;
      signoBNC = 1;
    }

    // CIERRE_POS: acredita a cuenta (destino)
    if (tipo.indexOf("CIERRE_POS") === 0 || tipo.indexOf("CIERRE_PAGO_MOVIL") === 0) {
      if (destino.indexOf("Bancamiga") !== -1) {
        acumBancamiga += monto;
      }
      if (destino.indexOf("BNC") !== -1) {
        acumBNC += monto;
      }
    } else {
      // Egreso/Ingreso/Traspaso
      if (signoBancamiga !== 0) acumBancamiga += signoBancamiga * monto;
      if (signoBNC !== 0) acumBNC += signoBNC * monto;
    }

    if (afectaBancamiga || afectaBNC) {
      detalle.push({
        fila: i + 1,
        fecha: f,
        tipo: tipo,
        tx: idTx,
        monto: monto,
        bcamiga: signoBancamiga * monto,
        bnc: signoBNC * monto,
        concepto: concepto.substring(0, 60)
      });
    }
  }

  Logger.log("Total movido en BANCAMIGA: " + acumBancamiga.toFixed(2));
  Logger.log("Total movido en BNC: " + acumBNC.toFixed(2));
  Logger.log("--- DETALLE ---");
  for (var j = 0; j < detalle.length; j++) {
    var d = detalle[j];
    Logger.log(
      "Fila " + d.fila + " | " + d.fecha + " | " + d.tipo +
      " | " + d.tx +
      " | monto=" + d.monto.toFixed(2) +
      " | Bancamiga=" + d.bcamiga.toFixed(2) +
      " | BNC=" + d.bnc.toFixed(2) +
      " | " + d.concepto
    );
  }

  Logger.log("=== FIN ===");
}function testSaldosDiaPorDia() {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("HISTORIAL");
  var data = sheet.getDataRange().getValues();
  var tz = "America/Caracas";

  // Saldo inicial del 30/09 (ajusta si tienes el dato real)
  var saldoIni = { "Bancamiga": 0, "BNC": 0 }; // ⚠️ PON AQUÍ LOS REALES

  var acum = { "Bancamiga": saldoIni.Bancamiga, "BNC": saldoIni.BNC };
  var ultimaFecha = "";

  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    var idTx = row[0] ? row[0].toString().trim() : "";
    if (idTx.indexOf("TX-") !== 0) continue;

    var f = "";
    try {
      var vf = row[1];
      if (vf instanceof Date) f = Utilities.formatDate(vf, tz, "yyyy-MM-dd");
      else f = vf.toString().substring(0, 10);
    } catch (e) { continue; }

    if (f < "2026-09-30" || f > "2026-10-09") continue;

    if (f !== ultimaFecha && ultimaFecha !== "") {
      Logger.log("Cierre día " + ultimaFecha +
                 " | Bancamiga=" + acum.Bancamiga.toFixed(2) +
                 " | BNC=" + acum.BNC.toFixed(2));
    }
    ultimaFecha = f;

    var tipo = row[2] ? row[2].toString().toUpperCase() : "";
    var origen = row[3] ? row[3].toString() : "";
    var destino = row[4] ? row[4].toString() : "";
    var monto = limpiarNumero(row[5]);

    // Bancamiga
    if (origen.indexOf("Bancamiga") !== -1) acum.Bancamiga -= monto;
    if (destino.indexOf("Bancamiga") !== -1) acum.Bancamiga += monto;
    // BNC
    if (origen.indexOf("BNC") !== -1) acum.BNC -= monto;
    if (destino.indexOf("BNC") !== -1) acum.BNC += monto;
  }

  if (ultimaFecha !== "") {
    Logger.log("Cierre día " + ultimaFecha +
               " | Bancamiga=" + acum.Bancamiga.toFixed(2) +
               " | BNC=" + acum.BNC.toFixed(2));
  }
  Logger.log("=== FIN ===");
}function testDriftBancos() {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("HISTORIAL");
  var data = sheet.getDataRange().getValues();
  var tz = "America/Caracas";

  // Rango: últimos 10 días
  var desde = "2026-09-30";
  var hasta = "2026-10-10";

  var bancos = ["Bancamiga", "BNC", "BBVA", "Banesco", "Caja Efectivo Bs"];
  var flujo = {};
  var porDia = {};
  bancos.forEach(function(b) { flujo[b] = 0; porDia[b] = {}; });

  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    var idTx = row[0] ? row[0].toString().trim() : "";
    if (idTx.indexOf("TX-") !== 0) continue;

    var f = "";
    try {
      var vf = row[1];
      if (vf instanceof Date) f = Utilities.formatDate(vf, tz, "yyyy-MM-dd");
      else f = vf.toString().substring(0, 10);
    } catch (e) { continue; }
    if (f < desde || f > hasta) continue;

    var origen = row[3] ? row[3].toString() : "";
    var destino = row[4] ? row[4].toString() : "";
    var monto = limpiarNumero(row[5]);
    var tipo = row[2] ? row[2].toString() : "";

    bancos.forEach(function(b) {
      var up = b.toUpperCase();
      if (origen.toUpperCase().indexOf(up) !== -1) {
        flujo[b] -= monto;
        if (!porDia[b][f]) porDia[b][f] = 0;
        porDia[b][f] -= monto;
      }
      if (destino.toUpperCase().indexOf(up) !== -1) {
        flujo[b] += monto;
        if (!porDia[b][f]) porDia[b][f] = 0;
        porDia[b][f] += monto;
      }
    });
  }

  Logger.log("=== FLUJO NETO POR BANCO (" + desde + " a " + hasta + ") ===");
  bancos.forEach(function(b) {
    Logger.log(b + ": " + flujo[b].toFixed(2));
    var dias = Object.keys(porDia[b]).sort();
    for (var d = 0; d < dias.length; d++) {
      Logger.log("  " + dias[d] + ": " + porDia[b][dias[d]].toFixed(2));
    }
  });
  Logger.log("=== FIN ===");
}function testCierresPorBanco() {
  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("HISTORIAL");
  var data = sheet.getDataRange().getValues();
  var tz = "America/Caracas";

  Logger.log("=== CIERRES POS Y PM POR BANCO Y DÍA ===");
  Logger.log("Fecha | Banco | Tipo | MontoNeto | ID_Cierre");

  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    var idTx = row[0] ? row[0].toString().trim() : "";
    if (idTx.indexOf("TX-") !== 0) continue;

    var tipo = row[2] ? row[2].toString().toUpperCase() : "";
    if (tipo.indexOf("CIERRE_POS") !== 0 && tipo.indexOf("CIERRE_PAGO_MOVIL") !== 0) continue;

    var f = "";
    try {
      var vf = row[1];
      if (vf instanceof Date) f = Utilities.formatDate(vf, tz, "yyyy-MM-dd");
      else f = vf.toString().substring(0, 10);
    } catch (e) { continue; }

    if (f < "2026-09-30") continue;

    var destino = row[4] ? row[4].toString() : "";
    var neto = limpiarNumero(row[7]);
    var idCierre = row[15] ? row[15].toString() : "";

    Logger.log(f + " | " + destino + " | " + tipo + " | " + neto.toFixed(2) + " | " + idCierre);
  }
  Logger.log("=== FIN ===");
}
// ===============================================================================================
// CONCILIACIÓN POR CUENTA v3 — parseo de conceptos multi-cuenta con tasas para conversión a $
// ================================================================================================

function _normCuenta(s) {
  return (s || "").toString().toUpperCase().replace(/[_ ]/g, "").trim();
}

function _parseCuentasMulti(str) {
  var res = [];
  if (!str) return res;
  var partes = str.toString().split("|");
  for (var i = 0; i < partes.length; i++) {
    var p = partes[i].trim();
    var m = p.match(/^([^:]+):\s*\+?\s*([\d.,]+)\s*([A-Z]{2,4})?/);
    if (!m) continue;
    var cta = m[1].trim();
    var monto = limpiarNumero(m[2]);
    var moneda = (m[3] || "BS").toUpperCase();
    if (!cta || monto <= 0) continue;
    var ctaLow = cta.toLowerCase();
    if (ctaLow.indexOf("comisión") === 0 || ctaLow.indexOf("comision") === 0 ||
        ctaLow.indexOf("desc") === 0 || ctaLow.indexOf("idemp") === 0 ||
        ctaLow.indexOf("enviado") === 0 || ctaLow.indexOf("recibido") === 0) continue;
    res.push({ cuenta: cta, monto: monto, moneda: moneda });
  }
  return res;
}

function _deltasDeMovimiento(mov, cuentaNorm) {
  var tipo = mov.tipo;
  var deltas = [];

  if (tipo.indexOf("PAGO_NOMINA") === 0 || tipo.indexOf("LIQUIDACION") === 0) {
    var partesNom = _parseCuentasMulti(mov.concepto);
    for (var i = 0; i < partesNom.length; i++) {
      if (_normCuenta(partesNom[i].cuenta) === cuentaNorm) deltas.push(-partesNom[i].monto);
    }
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
    var mE = mov.concepto.match(/Enviado:\s*([\d.,]+)/);
    var mR = mov.concepto.match(/Recibido:\s*([\d.,]+)/);
    var mC = mov.concepto.match(/Com:\s*([\d.,]+)/);
    var enviado = mE ? limpiarNumero(mE[1]) : mov.monto;
    var recibido = mR ? limpiarNumero(mR[1]) : mov.montoNeto;
    var com = mC ? limpiarNumero(mC[1]) : 0;
    if (_normCuenta(mov.origen) === cuentaNorm) deltas.push(-(enviado + com));
    if (_normCuenta(mov.destino) === cuentaNorm) deltas.push(recibido);
    return deltas;
  }

  if (tipo.indexOf("CIERRE_POS") === 0 || tipo.indexOf("CIERRE_PAGO_MOVIL") === 0) {
    if (_normCuenta(mov.destino) === cuentaNorm) {
      deltas.push(mov.montoNeto > 0 ? mov.montoNeto : mov.monto);
    }
    return deltas;
  }

  if (tipo.indexOf("INGRESO") === 0) {
    var partesI = _parseCuentasMulti(mov.destino);
    if (partesI.length > 0) {
      for (var i = 0; i < partesI.length; i++) {
        if (_normCuenta(partesI[i].cuenta) === cuentaNorm) deltas.push(partesI[i].monto);
      }
    } else if (_normCuenta(mov.destino) === cuentaNorm) {
      deltas.push(mov.montoNeto > 0 ? mov.montoNeto : mov.monto);
    }
    return deltas;
  }

  if (tipo.indexOf("EGRESO") === 0 ||
      tipo.indexOf("CARGO") === 0 ||
      tipo.indexOf("PRESTAMO") === 0 ||
      tipo.indexOf("FALTANTE") === 0) {
    var partesE = _parseCuentasMulti(mov.origen);
    if (partesE.length > 0) {
      for (var i = 0; i < partesE.length; i++) {
        if (_normCuenta(partesE[i].cuenta) === cuentaNorm) {
          var d = -partesE[i].monto;
          if (i === 0 && mov.comision > 0) {
            var comApl = mov.comision;
            if (partesE[i].moneda === "USD" && mov.tasaUSD > 0) comApl = mov.comision / mov.tasaUSD;
            else if (partesE[i].moneda === "USDT" && mov.tasaUSDT > 0) comApl = mov.comision / mov.tasaUSDT;
            d -= comApl;
          }
          deltas.push(d);
        }
      }
    } else if (_normCuenta(mov.origen) === cuentaNorm) {
      deltas.push(-mov.monto);
    }
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
        fecha: f,
        tipo: row[2] ? row[2].toString().toUpperCase() : "",
        origen: row[3] ? row[3].toString() : "",
        destino: row[4] ? row[4].toString() : "",
        monto: limpiarNumero(row[5]),
        montoNeto: limpiarNumero(row[7]),
        comision: limpiarNumero(row[8]),
        concepto: row[9] ? row[9].toString() : "",
        categoria: row[12] ? row[12].toString() : "",
        tasaUSD: limpiarNumero(row[10]),
        tasaUSDT: limpiarNumero(row[11])
      });
    }
  }

  // === TASA DE REFERENCIA DEL RANGO ===
  // 1) Primera tasa USD > 0 de movimientos dentro del rango
  var tasaRango = 0;
  for (var tr = 0; tr < movimientos.length; tr++) {
    var mv = movimientos[tr];
    if (mv.fecha >= desde && mv.fecha <= hasta && mv.tasaUSD > 0) {
      tasaRango = mv.tasaUSD;
      break;
    }
  }
  // 2) Si no hay, última tasa USD > 0 anterior o posterior
  if (tasaRango === 0) {
    for (var tr2 = movimientos.length - 1; tr2 >= 0; tr2--) {
      if (movimientos[tr2].tasaUSD > 0) {
        tasaRango = movimientos[tr2].tasaUSD;
        break;
      }
    }
  }
  // 3) Fallback: tasa BCV actual de CONFIG
  if (tasaRango === 0) {
    try {
      var cfg = obtenerTasasConfig();
      if (cfg && cfg.tasas && cfg.tasas.BCV) tasaRango = cfg.tasas.BCV;
    } catch (e) {}
  }

  var cuentas = Object.keys(saldosActuales);
  var resultado = [];

  for (var k = 0; k < cuentas.length; k++) {
    var cuenta = cuentas[k];
    var cuentaNorm = _normCuenta(cuenta);
    var saldoActual = saldosActuales[cuenta];

    var ingresosRango = 0;
    var egresosRango = 0;
    var ajustePosterior = 0;
    var movsCuenta = [];

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
          fecha: mov.fecha, tipo: mov.tipo,
          concepto: mov.concepto, categoria: mov.categoria,
          monto: Math.abs(deltaTotal),
          signo: deltaTotal > 0 ? 1 : -1,
          tasaUSD: mov.tasaUSD > 0 ? mov.tasaUSD : tasaRango,
          tasaUSDT: mov.tasaUSDT
        });
      } else {
        ajustePosterior += deltaTotal;
      }
    }

    var saldoFinalRango = saldoActual - ajustePosterior;
    var saldoInicioRango = saldoFinalRango - ingresosRango + egresosRango;

    resultado.push({
      cuenta: cuenta,
      saldoInicio: saldoInicioRango,
      ingresos: ingresosRango,
      egresos: egresosRango,
      esperado: saldoFinalRango,
      saldoActual: saldoActual,
      tasaUSD: tasaRango,
      movimientos: movsCuenta
    });
  }

  return {
    status: "SUCCESS",
    fechaDesde: desde,
    fechaHasta: hasta,
    tasaUSD: tasaRango,
    cuentas: resultado
  };
}
function testConciliacionTasas() {
  var res = obtenerConciliacionPorCuenta({
    fechaDesde: "2026-10-16",
    fechaHasta: "2026-10-16"
  });
  Logger.log("tasaUSD global: " + res.tasaUSD);
  if (res.cuentas && res.cuentas.length > 0) {
    var c = res.cuentas[0];
    Logger.log("Cuenta: " + c.cuenta);
    Logger.log("Cuenta tasaUSD: " + c.tasaUSD);
    if (c.movimientos && c.movimientos.length > 0) {
      Logger.log("Mov 1 tasaUSD: " + c.movimientos[0].tasaUSD);
    }
  }
  Logger.log(JSON.stringify(res).substring(0, 500));
}// ============================================================================
// OBTENER PENDIENTES POR PAGAR (Para el selector en Operaciones)
// ============================================================================
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
      id: row[0] ? row[0].toString() : "",
      tercero: row[4] ? row[4].toString() : "",
      concepto: row[5] ? row[5].toString() : "",
      monto: limpiarNumero(row[6]),
      moneda: row[7] ? row[7].toString() : "BS"
    });
  }
  return { status: "SUCCESS", pendientes: pendientes };
}function procesarOperacionTrabajador(payload) {
  var ss = obtenerSpreadsheet();
  var sheetHistorial = ss.getSheetByName("HISTORIAL");
  var sheetSaldos = ss.getSheetByName("SALDOS");
  if (!sheetHistorial) return { status: "ERROR", mensaje: "Falta HISTORIAL" };
  if (!sheetSaldos) return { status: "ERROR", mensaje: "Falta SALDOS" };

  var fechaHoy = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  var cedulaBuscada = (payload.cedula || "").toString().trim();

  if (cedulaBuscada !== "") {
    var histData = sheetHistorial.getDataRange().getValues();
    for (var h = 1; h < histData.length; h++) {
      var rowH = histData[h];
      var tipoH = rowH[2] ? rowH[2].toString().toUpperCase() : "";
      if (tipoH === "PAGO_NOMINA" || tipoH === "LIQUIDACION_FINAL") {
        var fechaH = _normalizarFecha(rowH[1], "America/Caracas");
        if (fechaH === fechaHoy) {
          var conceptoH = rowH[9] ? rowH[9].toString() : "";
          if (conceptoH.indexOf(cedulaBuscada) !== -1) {
            return { status: "ERROR", mensaje: "Este trabajador ya fue pagado hoy. Verifica el historial." };
          }
        }
      }
    }
  }

  var idempotenciaKey = payload.idempotenciaKey || "";
  if (idempotenciaKey !== "") {
    var histCheck = sheetHistorial.getDataRange().getValues();
    var inicioBusqueda = histCheck.length > 100 ? histCheck.length - 100 : 1;
    for (var hi = inicioBusqueda; hi < histCheck.length; hi++) {
      var conceptoFila = histCheck[hi][9] ? histCheck[hi][9].toString() : "";
      if (conceptoFila.indexOf("IDEMP:" + idempotenciaKey) !== -1) {
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
  var nuevaDeuda = limpiarNumero(payload.nuevoSaldoDeuda || 0);
  var netoFinalBs = montoBsNeto;
  var fuentes = payload.fuentesPago;

  if (!fuentes || !Array.isArray(fuentes) || fuentes.length === 0) {
    return { status: "ERROR", mensaje: "Debes agregar al menos una fuente de pago." };
  }

  var sumaFuentes = 0;
  for (var fi = 0; fi < fuentes.length; fi++) { sumaFuentes += limpiarNumero(fuentes[fi].monto || 0); }
  if (Math.abs(sumaFuentes - netoFinalBs) > 0.01) {
    return { status: "ERROR", mensaje: "Suma de fuentes no coincide con el neto." };
  }

  var descripcionFuentes = [];
  var totalComisionCalculada = 0;

  for (var fi = 0; fi < fuentes.length; fi++) {
    var cuentaF = (fuentes[fi].cuenta || "").toString().trim();
    var montoF = limpiarNumero(fuentes[fi].monto || 0);
    var metodoF = (fuentes[fi].metodo || "EFECTIVO").toString().toUpperCase();
    if (cuentaF === "" || montoF <= 0) continue;

    var comisionF = metodoF === "EFECTIVO" ? 0 : montoF * 0.003;
    var totalDebitarF = montoF + comisionF;
    var saldoF = obtenerSaldoCuenta(sheetSaldos, cuentaF);
    if (saldoF < totalDebitarF) {
      return { status: "ERROR", mensaje: "Fondos insuficientes en " + cuentaF };
    }
    actualizarSaldoEnHojaSaldos(sheetSaldos, cuentaF, totalDebitarF, false);
    descripcionFuentes.push(cuentaF + ": " + montoF.toFixed(2));
    totalComisionCalculada += comisionF;
  }

  var origenFondos = (payload.origenFondos || "ACUMULADO").toString().toUpperCase();
  var concepto = (esLiquidacion ? "LIQUIDACIÓN FINAL - " : "PAGO NÓMINA - ") + tipoOperacion + ": " + nombre + " (V-" + cedula + ") | " + descripcionFuentes.join(" | ");
  if (idempotenciaKey !== "") concepto += " | IDEMP:" + idempotenciaKey;
  
  var montoTotalDebitado = netoFinalBs + totalComisionCalculada;
  var conceptoFinal = concepto;
  if (descuentoDeudaUSD > 0.01) conceptoFinal += " | Desc. préstamo: $" + descuentoDeudaUSD.toFixed(2) + " USD";

  var fechaProcStr = Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd");
  var tasaRefProc = obtenerTasa(fechaProcStr, "BCV");
  var tasaFinalProc = (tasaUSD > 0) ? tasaUSD : tasaRefProc;
  var fuenteFinalProc = (tasaUSD > 0) ? "MANUAL" : "BCV";

  sheetHistorial.appendRow([
    idTx, new Date(), esLiquidacion ? "LIQUIDACION_FINAL" : "PAGO_NOMINA",
    "VARIAS", "PERSONAL", montoTotalDebitado, "BS", netoFinalBs, totalComisionCalculada,
    conceptoFinal, tasaUSD, 0, esLiquidacion ? "LIQUIDACION" : "NOMINA", "N", origenFondos, "",
    tasaFinalProc, fuenteFinalProc, netoFinalBs
  ]);

  var sheetTrab = ss.getSheetByName("NOMINA_PERSONAL") || ss.getSheetByName("TRABAJADORES") || ss.getSheetByName("PERSONAL");
  if (sheetTrab) {
    var data = sheetTrab.getDataRange().getValues();
    var cedulaBuscada = cedula.toString().replace(/[^0-9]/g, "");
    for (var i = 1; i < data.length; i++) {
      var cedulaFila = (data[i][2] || data[i][0] || "").toString().replace(/[^0-9]/g, "");
      if (cedulaFila === cedulaBuscada && cedulaBuscada !== "") {
        if (!esLiquidacion && descuentoDeudaUSD > 0) sheetTrab.getRange(i + 1, 10).setValue(nuevaDeuda);
        if (esLiquidacion) {
          sheetTrab.getRange(i + 1, 9).setValue("INACTIVO");
          sheetTrab.getRange(i + 1, 12).setValue(payload.fechaEgreso || Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd"));
          sheetTrab.getRange(i + 1, 10).setValue(0);
        }
        break;
      }
    }
  }

  // Guardar detalle de recibo en RECIBOS_DETALLE
  try {
    var sheetRecibos = ss.getSheetByName("RECIBOS_DETALLE");
    if (!sheetRecibos) {
      sheetRecibos = ss.insertSheet("RECIBOS_DETALLE");
      sheetRecibos.appendRow(["ID_TX", "FECHA", "CEDULA", "TIPO", "DETALLE_JSON"]);
    }
    var reciboData = {
      idTx: idTx,
      tipo: tipoOperacion,
      nombre: nombre,
      cedula: cedula,
      cuenta: fuentes.map(function(f) { return f.cuenta + ": " + f.monto; }).join(" | "),
      detSemana: limpiarNumero(payload.detSemana || 0),
      detPrestaciones: limpiarNumero(payload.detPrestaciones || 0),
      detVacaciones: limpiarNumero(payload.detVacaciones || 0),
      detUtilidades: limpiarNumero(payload.detUtilidades || 0),
      detAyudaFamiliar: limpiarNumero(payload.detAyudaFamiliar || 0),
      detBonoAlimenticio: limpiarNumero(payload.detBonoAlimenticio || 0),
      detComision: limpiarNumero(payload.detComision || 0),
      totalSalarial: limpiarNumero(payload.totalSalarial || 0),
      totalNoSalarial: limpiarNumero(payload.totalNoSalarial || 0),
      montoBrutoUSD: limpiarNumero(payload.montoBruto || 0),
      descuentoDeuda: descuentoDeudaUSD,
      deudaAnterior: limpiarNumero(payload.deudaAnterior || 0),
      montoUSD: limpiarNumero(payload.montoTotal || 0),
      montoBs: netoFinalBs,
      tasa: tasaUSD,
      nuevoSaldoDeuda: nuevaDeuda,
      fecha: Utilities.formatDate(new Date(), "America/Caracas", "yyyy-MM-dd HH:mm:ss"),
      antiguedad: payload.antiguedad || "",
      fechaEgreso: payload.fechaEgreso || "",
      textoLegal: payload.notaLegal || (esLiquidacion ? "HE RECIBIDO A MI ENTERA SATISFACCION EL PAGO DE MI LIQUIDACIÓN" : "HE RECIBIDO A MI ENTERA SATISFACCION POR MI SEMANA DE TRABAJO"),
      notaLegalBono: payload.notaLegalBono || null,
      adicionales: payload.adicionales || []
    };

    sheetRecibos.appendRow([
      idTx,
      reciboData.fecha,
      cedula,
      esLiquidacion ? "LIQUIDACION_FINAL" : "PAGO_NOMINA",
      JSON.stringify(reciboData)
    ]);
  } catch (errRecibo) {
    Logger.log("Error guardando recibo detalle: " + errRecibo.toString());
  }

  return { status: "SUCCESS", exito: true, idTx: idTx, mensaje: "Pago registrado correctamente" };
}

function obtenerDetalleRecibo(payload) {
  var idTx = "";
  if (payload) {
    idTx = (payload.idTx || payload.id || "").toString().trim().toUpperCase();
  }
  if (idTx === "") return { status: "ERROR", mensaje: "Falta idTx" };

  var ss = obtenerSpreadsheet();
  var sheet = ss.getSheetByName("RECIBOS_DETALLE");
  if (!sheet) return { status: "ERROR", mensaje: "No existe la hoja RECIBOS_DETALLE" };

  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return { status: "ERROR", mensaje: "No hay recibos guardados" };

  var data = sheet.getRange(2, 1, lastRow - 1, 5).getValues();
  for (var i = 0; i < data.length; i++) {
    var idFila = data[i][0] ? data[i][0].toString().trim().toUpperCase() : "";
    if (idFila === idTx) {
      try {
        var jsonStr = data[i][4] ? data[i][4].toString() : "{}";
        var detalle = JSON.parse(jsonStr);
        return { status: "SUCCESS", exito: true, recibo: detalle };
      } catch (e) {
        return { status: "ERROR", mensaje: "Error al parsear el JSON del recibo: " + e.toString() };
      }
    }
  }

  return { status: "ERROR", mensaje: "Recibo no encontrado para el idTx: " + idTx };
}