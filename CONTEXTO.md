# FINANZAS PRO - DOCUMENTO MAESTRO DE ARQUITECTURA Y REGLAS DE NEGOCIO

Este documento es la fuente de la verdad para el desarrollo de la app. Cualquier IA o desarrollador (incluyendo Jules) DEBE leer este archivo antes de modificar código.

## 1. ARQUITECTURA DE LAS 5 FICHAS (Flujo de Trabajo)

El sistema está diseñado en un flujo lógico de 5 pasos secuenciales. Si una ficha falla, las siguientes se ven afectadas.

### Ficha 1: Disponibilidad y Tasas
*   **Propósito:** Punto de partida del día.
*   **Regla de Oro (Corte 6:00 AM):** Los saldos se congelan hasta las 6:00 AM. Si no hay cierre del día anterior registrado, la app debe mostrar los saldos de ayer y un banner de advertencia.
*   **Multimoneda:** Se manejan tasas independientes (BCV, USDT, EUR). La tasa usada se guarda en cada transacción.

### Ficha 2: Operaciones y Egresos
*   **Propósito:** Registrar gastos, compras de divisas y traspasos.
*   **Regla de No Duplicidad:** Si un gasto sale de la "Venta del Día", NO entra a la Caja Acumulada. Se resta directamente de la venta.
*   **Regla de Compra de Divisas:** Si compras USDT pagando desde un banco en Bs, el `MONTO` en el Sheet debe ser el total en BOLÍVARES, la `MONEDA` debe ser `BS`, y los USDT comprados van en el `CONCEPTO`. (Nunca guardar el monto en USDT en la columna MONTO si se pagó en Bs).

### Ficha 3: Conciliación Diaria / Cierre
*   **Propósito:** Cuadrar la venta del día con el dinero real.
*   **Fórmula:** (Venta Total) - (Distribuido) - (Comisiones) - (Gastos de la venta) - (Préstamos).
*   **Ajuste:** Debe existir un botón de "Ajustar y Cuadrar" que cree un ingreso/egreso automático por la diferencia (Faltante/Sobrante) para que las cuentas no queden infladas.

### Ficha 4: Ficha Trabajador y Nómina
*   **Propósito:** Pagos, préstamos y liquidaciones.
*   **Regla de Cédula Real:** El sistema NUNCA debe usar el texto que el usuario escribe en el buscador para armar el recibo. Siempre debe usar la cédula numérica (`_cedulaReal`) devuelta por el backend.
*   **Historial Limpio:** Al buscar a un nuevo trabajador, se debe limpiar el historial anterior (`_historialPrestamos.clear()`) para que no se mezclen las deudas.
*   **Bloqueo de Doble Pago:** El backend rechaza el pago si el trabajador ya fue pagado el mismo día.
*   **Préstamos:** Se manejan en USD. Si se hace una liquidación, la deuda pendiente se resta automáticamente del finiquito.

### Ficha 5: Consultas e Historial
*   **Propósito:** Reportes de Ganancias/Pérdidas (P&L) y Reimpresión.
*   **Reimpresión:** Los recibos pasados se reimprimen desde aquí (el detalle debe estar guardado en la hoja `RECIBOS_DETALLE`).
*   **Ganancias:** El reporte debe desglosar egresos por categoría (Comisiones, Servicios, Gastos Personales, etc.) y mostrar el Neto.

## 2. REGLAS CONTABLES Y MULTIMONEDA (CRÍTICO)

*   **Moneda Base de Deuda:** USD.
*   **Moneda de Pago:** Bs y USDT.
*   **Fuente de Verdad Cambiaria:** `obtenerTasa` es la única vía de lectura de tasas.
*   **Etiquetado en HISTORIAL:** La columna `MONTO` y `MONEDA` deben corresponder a la cuenta de origen (si salió de BBVA, es Bs; si salió de USDT, es USDT). Todo movimiento insertado en `HISTORIAL` debe congelar la tasa usada en `TASA` y `FUENTE_TASA`, y el equivalente en Bs en `MONTO_BS`.
*   **Saldos:** La función `actualizarSaldoEnHojaSaldos` debe hacer doble partida: resta en la cuenta origen y suma en la destino.

## 3. HISTORIAL DE BUGS CORREGIDOS (Para no repetirlos)

1.  **Cédulas truncadas:** Las versiones viejas guardaban `(V-MIRT)` en lugar de `(V-13949031)`. El backend ahora debe validar estrictamente la cédula numérica.
2.  **Doble pago de nómina:** Resuelto en el backend validando la fecha y cédula en el Historial.
3.  **Caché de Flutter:** La app guardaba datos viejos de trabajadores. Se solucionó agregando `_historialPrestamos.clear()` antes de cada búsqueda.
4.  **Compra de Divisas:** Se corrompían los montos. Ahora la regla es "MONTO en Bs si el origen es banco".

## 4. STACK TECNOLÓGICO Y DESPLIEGUE

*   **Frontend:** Flutter (Dart). Se compila vía GitHub Actions y se despliega automáticamente a Firebase (`finanzas-pro-7807.web.app`).
*   **Backend:** Google Apps Script (`code.gs`). Se sube con `clasp push`.
*   **Base de Datos:** Google Sheets.

## 5. DIRECTRICES PARA LA IA (Jules o similares)

*   **NO romper la lógica de las 5 fichas.**
*   **NO modificar la estructura de columnas del Sheet** sin consultar. (El código depende de los índices de las columnas: 0=ID, 1=Fecha, 2=Tipo, etc.).
*   **Siempre usar `_r2()`** para redondear montos financieros en Flutter.
*   **Si un PR toca `modal_trabajador.dart` o `code.gs`**, revisar que no se pierdan las validaciones de cédulas y saldos.