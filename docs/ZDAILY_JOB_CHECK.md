# ZDAILY_JOB_CHECK – cómo lee cada dato

Documentación técnica de [`src/ZDAILY_JOB_CHECK.abap`](../src/ZDAILY_JOB_CHECK.abap): de
dónde sale cada valor del reporte, cómo se evalúa y con qué se puede comparar en SM37.
Para instalación y uso ver el [README](../README.md).

## Índice

- [Flujo general](#flujo-general)
- [De dónde salen los jobs](#de-dónde-salen-los-jobs)
- [Filtros comunes](#filtros-comunes)
- [Criterio por status](#criterio-por-status)
- [Error del log de los cancelados](#error-del-log-de-los-cancelados)
- [Fila de resumen de cada status](#fila-de-resumen-de-cada-status)
- [Envío por mail, estado general y ALV](#envío-por-mail-estado-general-y-alv)
- [Resumen de objetos SAP usados](#resumen-de-objetos-sap-usados)
- [Limitaciones](#limitaciones)

## Flujo general

```
START-OF-SELECTION
  get_own_job                 GET_JOB_RUNTIME_INFO (solo en fondo)
  check_status 'P'            (si X_SCHED)  Progr.
  check_status 'S'            (si X_REL)    Liberado
  check_status 'Y'            (si X_READY)  Listo
  check_status 'R'            (si X_ACT)    Activa      <- por defecto
  check_status 'F'            (si X_FIN)    Finaliz.
  check_status 'A'            (si X_CANC)   Cancelado   <- por defecto
  calculate_global
  send_mail                   (si P_MAIL) + calculate_global otra vez
  build_fieldcat / display_report
```

Todos los status pasan por el mismo FORM `check_status`, que cambia la consulta y el
criterio según el status. El orden es el mismo que el de los status en SM37.

## De dónde salen los jobs

**Cabecera del job: `TBTCO`** (lo mismo que lista SM37). Campos usados:

| Campo | Uso |
|---|---|
| `JOBNAME`, `JOBCOUNT` | Identificación del job |
| `STATUS` | Status de SM37 (`P`, `S`, `Y`, `R`, `F`, `A`) |
| `SDLSTRTDT`, `SDLSTRTTM` | Inicio previsto |
| `STRTDATE`, `STRTTIME` | Inicio real |
| `ENDDATE`, `ENDTIME` | Fin |
| `SDLUNAME` | Usuario que programó el job |
| `REAXSERVER` | Instancia donde corrió o corre |
| `AUTHCKMAN` | Mandante del job |

`TBTCO` es independiente de mandante: el reporte lista los jobs de **todos los mandantes**,
y el mandante de cada uno figura en el detalle.

**Paso del job: `TBTCP`**, paso 1 (`STEPCOUNT = 1`): programa (`PROGNAME`) y usuario de
ejecución (`AUTHCKNAM`). Si el job tiene varios pasos, se muestra solo el primero.

**Consulta según status:**

| Status | `SELECT` en `TBTCO` | Orden |
|---|---|---|
| `F`, `A` | `STATUS = p_stat AND ENDDATE >= fecha desde AND JOBNAME IN S_JOBN` | Fin, del más reciente al más viejo |
| `P`, `S`, `Y`, `R` | `STATUS = p_stat AND JOBNAME IN S_JOBN` (estado actual, sin fecha) | Inicio previsto y luego inicio real |

Para `F` y `A` la fecha desde sale de `P_CDAT` / `P_CTIM` (vacío = últimas 24 h, ayer a la
hora actual). La base filtra por día y después, en el primer día, se descartan los que
terminaron antes de la hora desde.

## Filtros comunes

| Filtro | Cómo actúa |
|---|---|
| `S_JOBN` Nombre de job | Va directo en el `WHERE` (`JOBNAME IN S_JOBN`): admite patrones como `Z*`, varios valores y exclusiones |
| `P_NOSAP` Excluir `SAP_*` | Descarta los jobs cuyo nombre cumple `CP 'SAP_*'` |
| Job propio | Si el programa corre en fondo, `GET_JOB_RUNTIME_INFO` (dinámico) devuelve su `JOBNAME`/`JOBCOUNT` y ese job se excluye, para que no se informe a sí mismo como activo |
| Máximo por status | Se muestran como máximo 200 jobs por status; el resto solo se cuenta |

## Criterio por status

Las antigüedades se calculan en segundos contra la fecha/hora actual del servidor
(`sy-datum` / `sy-uzeit`) y se muestran como `N d N h N min` (`fmt_duration`).

| Status | Qué muestra (Resultado) | Estado de cada job | Detalle |
|---|---|---|---|
| **P** Progr. | `JOB: programado, sin liberar` | OK (informativo) | Programa, usuario, creado por, mandante |
| **S** Liberado | Con inicio previsto: `liberado, inicia el ...`. Sin inicio previsto: `liberado, espera un evento` | **Advertencia** si el inicio previsto pasó hace más de `P_READM` min (por defecto 10) y no arrancó; si no, OK | Programa, usuario, mandante |
| **Y** Listo | `listo, esperando WP de fondo hace ...` (desde el inicio previsto) | **Advertencia** si espera más de `P_READM` min; si no, OK | Programa, usuario, inicio previsto, mandante |
| **R** Activa | `en ejecución hace ...` (desde el inicio real) | **Advertencia** si corre más de `P_MAXRM` min (por defecto 60); si no, OK | Programa, usuario, servidor, inicio, mandante |
| **F** Finaliz. | `finalizado el ... (duró ...)` (fin − inicio real) | OK (informativo) | Programa, usuario, servidor, mandante |
| **A** Cancelado | `cancelado el ...` | **Error** | Programa, usuario, servidor, mandante y, si `P_LOG = 'X'`, `Error:` con el mensaje del log |

Un job *Liberado* sin fecha de inicio prevista es uno que espera un evento o el fin de otro
job: se informa sin evaluar demora. Un job *Listo* sin fecha prevista muestra `?` como
tiempo de espera.

## Error del log de los cancelados

**Equivalente manual:** SM37 → seleccionar el job → *Log del job*.

`job_error` lee el log con `BP_JOBLOG_READ` (dinámico) pasando `CLIENT` (= `AUTHCKMAN`),
`JOBNAME` y `JOBCOUNT`, y recorre la tabla `JOBLOGTBL` (campos `TEXT` y `MSGTYPE`):

1. Considera los mensajes de tipo `E`, `A` o `X`.
2. La línea genérica de cancelación (`Job cancel*` o `Job anulad*`, por ejemplo
   *Job cancelled after system exception ERROR_MESSAGE*) no dice la causa, así que se aparta.
3. Se queda con el **último error que no sea la línea genérica**. Típicamente es el texto
   del dump, por ejemplo *Internal session terminated with a runtime error
   STRING_LENGTH_TOO_LARGE (see ST22)*.
4. Si no hay otro error usa la línea genérica, y si el log no tiene errores, su última línea.
5. Si `BP_JOBLOG_READ` falla (log borrado, por ejemplo), muestra `(log no disponible)`.

## Fila de resumen de cada status

Antes de las filas de jobs, cada status agrega una fila de resumen:

| Status | Resultado | Detalle | Estado |
|---|---|---|---|
| P | `N job(s) programado(s) sin liberar` | Informativo | OK |
| S | `N job(s) liberado(s)` | Aviso si el inicio se demora más de `P_READM` min | OK o Advertencia |
| Y | `N job(s) listo(s) esperando WP de fondo` | Ídem | OK o Advertencia |
| R | `N job(s) en ejecución` | Aviso si corre más de `P_MAXRM` min | OK o Advertencia |
| F | `N job(s) finalizado(s) desde ...` | Período desde–hasta | OK |
| A | `N job(s) cancelado(s) desde ...` | Período desde–hasta | **Error** si N > 0; si no, OK |

Si algún job del status quedó con aviso, el resumen pasa a Advertencia (salvo que ya sea
Error) y el detalle empieza con `N con aviso`. Si hubo más de 200 jobs, se agrega
`se muestran 200 de N`.

## Envío por mail, estado general y ALV

Son iguales a los de `ZDAILY_HEALTH_CHECK` (ver
[ZDAILY_HEALTH_CHECK.md](ZDAILY_HEALTH_CHECK.md#sost--envío-por-mail)):

- **Mail:** `CL_BCS` con cuerpo HTML (`build_mail_html`), las mismas opciones de cuándo
  enviar y envío inmediato. El título del cuerpo es *SAP Daily Job Check* y el asunto
  automático es `Jobs <SID>/<mandante> <fecha> - <estado>`.
- **Estado general:** el peor estado de todas las filas (ERROR > WARNING > INCOMPLETO > OK);
  en fondo se escribe además en el log del job.
- **ALV:** `REUSE_ALV_GRID_DISPLAY` con semáforo, Transacción (`SM37`, o `SOST` para el
  mail), Chequeo, Estado coloreado, Resultado y Detalle, agrupado por status y con encabezado
  HTML con los contadores.

## Resumen de objetos SAP usados

| Uso | Objeto |
|---|---|
| Jobs | Tabla `TBTCO` |
| Programa y usuario del paso 1 | Tabla `TBTCP` |
| Job propio (en fondo) | FM `GET_JOB_RUNTIME_INFO` (dinámica) |
| Error de los cancelados | FM `BP_JOBLOG_READ` (dinámica), tabla `JOBLOGTBL` |
| Llamadas dinámicas | Tablas `TFDIR`, `FUPARAREF` |
| Mail | `CL_BCS`, `CL_DOCUMENT_BCS`, `CL_CAM_ADDRESS_BCS` |
| ALV | `REUSE_ALV_GRID_DISPLAY`, `REUSE_ALV_COMMENTARY_WRITE`, `CL_DD_DOCUMENT` |

## Limitaciones

- **128 caracteres por celda en el ALV:** el detalle de los cancelados, que incluye el
  error del log, se ve cortado en pantalla. El campo guarda 255 caracteres y el mail lo
  muestra completo.
- **Jobs Listo huérfanos:** si después de una caída del sistema quedaron jobs en *Listo*
  (por ejemplo `SAP_COLLECTOR_PERFMON_*`), aparecen uno por uno con su espera. Se limpian
  desde SM37 (*Job → Verificar status*) o SM65.
- **Solo el primer paso:** en jobs de varios pasos, el programa y el usuario que se muestran
  son los del paso 1.
- **Activos sin filtro de fecha:** P, S, Y y R muestran el estado actual de `TBTCO`, sin
  importar la fecha desde (que solo aplica a F y A).
