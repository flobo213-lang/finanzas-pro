# PROTOCOLO DE ISSUES — FINANZAS PRO

> Este documento es la **ley** para todo issue y PR del backend (`code.gs` + Sheets).
> Vive en el repo, hermano de `CONTEXTO.md`. No se repite en cada issue: se referencia.

---

## 1. Regla de oro

**Un Issue = Una Ficha dueña del cambio + una Matriz de Impacto Cruzado cerrada (7 filas).**

- Si el fix es **transversal** (ej. TASAS), vive en la ficha que lo origina pero **arrastra** la matriz completa.
- **Celda vacía en la matriz = PR rechazado.** Sin excepción.
- El issue es corto. La regla pesada vive acá, una sola vez.

---

## 2. Fichas del sistema

| Ficha | Hoja(s) | Responsabilidad |
|---|---|---|
| **F0 · TASAS** | `TASAS`, `CONFIG`, `HISTORIAL` (cols TASA/FUENTE_TASA/MONTO_BS) | Fuente de verdad cambiaria. Transversal. |
| **F1 · Trabajadores** | `TRABAJADORES`, `NOMINA_MOVIMIENTOS`, `NOMINA_ACUMULADO` | Nómina, adelantos, prestaciones, liquidaciones. |
| **F2 · Operaciones** | `HISTORIAL`, `SALDOS` | Egresos, traspasos, gastos, ingresos. |
| **F3 · Divisas** | `HISTORIAL`, `SALDOS` | Compra/venta de divisa. |
| **F4 · Saldos y Cierres** | `SALDOS`, `CIERRES`, `CIERRES_DETALLE`, `HISTORIAL` | Cierre de jornada, apertura, reconciliación. |
| **F5 · Consultas / Reportes** | `HISTORIAL`, `AUDITORIA_CAMBIOS` | Consultas, edición, anulación, P&L. |

---

## 3. Matriz de Impacto Cruzado (copiar en cada issue)

| Ficha | ¿Impacta? | Qué verificar concretamente | ✅ |
|---|---|---|---|
| **F0 TASAS** | ⬜ Sí / ⬜ No | ¿La función llama `obtenerTasa()`? ¿Falla si no hay tasa? | |
| **F1 Trabajadores** | ⬜ Sí / ⬜ No | ¿`registrarPagoNomina`, `registrarAdelanto` guardan TASA y MONTO_BS? | |
| **F2 Operaciones** | ⬜ Sí / ⬜ No | ¿`registrarEgreso`, `registrarTraspaso` guardan TASA y MONTO_BS? | |
| **F3 Divisas** | ⬜ Sí / ⬜ No | ¿`registrarCompraDivisa`, `registrarVentaDivisa` usan `tasaUsada` del payload? | |
| **F4 Saldos/Cierres** | ⬜ Sí / ⬜ No | ¿`registrarCierreJornada` genera movimientos en HISTORIAL? ¿Saldos se actualizan por cuenta? | |
| **F5 Consultas** | ⬜ Sí / ⬜ No | ¿`obtenerConsultasConFecha` devuelve TASA, FUENTE_TASA, MONTO_BS? | |
| **`code.gs`** | ⬜ Sí / ⬜ No | Correr los 5 `grep` de §5. Listar cada call-site y verificar contrato de firma. | |

---

## 4. Política de merge

1. PR sin matriz llena → `request changes` automático.
2. `Sí` sin evidencia (captura, log, o diff) → `request changes`.
3. `No` sin justificación (ej. "F1 no usa esta función, verificado con `grep -n`) → `request changes`.
4. Scripts con `apply=true` requieren **aprobación explícita del owner** en el PR, con `dryRun` adjunto.
5. Deploy a producción: ventana de bajo tráfico (domingo AM) + backup previo del Sheet.

---

## 5. Comandos `grep` obligatorios en `code.gs`

```bash
grep -n "function registrar" code.gs
grep -n "actualizarSaldoEnHojaSaldos" code.gs
grep -n "obtenerTasa" code.gs
grep -n "'BS'" code.gs           # cazar hardcodes de moneda
grep -n "MONTO:" code.gs         # verificar que no asigna montoDivisa
