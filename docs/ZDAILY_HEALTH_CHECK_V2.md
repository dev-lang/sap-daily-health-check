# ZDAILY_HEALTH_CHECK V2 – cómo lee cada dato

Documentación técnica de [`src/ZDAILY_HEALTH_CHECK_V2.abap`](../src/ZDAILY_HEALTH_CHECK_V2.abap),
la versión 2 del health check (en prueba): de dónde sale cada valor del reporte, cómo se evalúa
y con qué transacción se puede comparar a mano. Para instalación y uso ver el
[README](../README.md).

Se compara contra la versión actual ([`src/ZDAILY_HEALTH_CHECK.abap`](../src/ZDAILY_HEALTH_CHECK.abap),
v25, documentada en [ZDAILY_HEALTH_CHECK.md](ZDAILY_HEALTH_CHECK.md)). Las secciones que no
cambian son iguales en los dos documentos.

## Diferencias con la v1

| Cambio | Antes (v1) | Ahora (V2) | Ejemplo |
|---|---|---|---|
| Certificado de confianza vencido | Advertencia | **Error**, igual que un certificado propio vencido | Un PSE con un certificado de confianza vencido pone el chequeo en rojo |
| Fila final de certificados | Advertencia si había cualquier aviso | **Error** si hay vencidos; Advertencia si solo hay por vencer | "1 vencido(s), 0 por vencer en 30 dias" |
| PSE de System PKI | Incompleto (no se puede leer) | Fila informativa en **OK**, no se lee | "sap_system_pki_instance.pse: PSE de System PKI, gestionado por el kernel" |
| **Licencias firmadas** (formato nuevo) | **No se revisaban**: solo se miraban las licencias antiguas | **Chequeo nuevo** con su tilde: cada licencia firmada, la clave del producto del sistema (`NetWeaver_SYB`) y el certificado de mantenimiento (`Maintenance_SYB`) | La licencia firmada temporal de `NetWeaver_SYB` venció: la v1 daba OK, la V2 da **Error** |
| Licencias antiguas (formato clásico) | Chequeo "Licencia SAP" | El mismo chequeo, sin cambios de lógica; ahora se llama "Licencias antiguas" | Mismo resultado en las dos versiones |

### Licencias antiguas y licencias firmadas

SAP maneja dos formatos de licencia y SLICENSE muestra los dos:

- **Licencias antiguas:** formato clásico, una clave atada a la clave de hardware del servidor,
  con fecha de vencimiento. Es lo único que revisa la v1 (`SLIC_READ_LICENSES`), y la V2 lo
  sigue revisando igual.
- **Licencias firmadas:** formato nuevo, con firma digital, una licencia por producto
  (`NetWeaver_SYB` para el sistema, `Maintenance_SYB` para el certificado de mantenimiento). Son las
  de la pantalla principal de SLICENSE. La v1 no las mira; la V2 las revisa en el chequeo nuevo
  *Licencias firmadas*.

Por qué importa: en el laboratorio venció la licencia firmada temporal de `NetWeaver_SYB` mientras
seguía instalada una licencia antigua permanente. La v1 informaba **OK** (la licencia antigua no
vence) aunque el sistema se había quedado sin clave firmada válida para su producto; la V2 lo marca
en **Error**.

## Índice

- [Flujo general](#flujo-general)
- [Piezas comunes](#piezas-comunes)
- [SICK – consistencia del sistema](#sick--consistencia-del-sistema)
- [ST22 – dumps](#st22--dumps)
- [SM12 – bloqueos](#sm12--bloqueos)
- [SM13 – actualizaciones](#sm13--actualizaciones)
- [SM50 – estado de work processes](#sm50--estado-de-work-processes)
- [SM50 – capacidad de work processes](#sm50--capacidad-de-work-processes)
- [RTCCTOOL – herramientas de servicio](#rtcctool--herramientas-de-servicio)
- [STRUST – certificados](#strust--certificados)
  - [PSE de System PKI](#pse-de-system-pki)
- [ST03N – tiempos de respuesta del día hábil anterior](#st03n--tiempos-de-respuesta-del-día-hábil-anterior)
- [SMLG – tiempo de respuesta por instancia](#smlg--tiempo-de-respuesta-por-instancia)
- [SCOT – SAPconnect](#scot--sapconnect)
- [SLICENSE – licencias antiguas](#slicense--licencias-antiguas)
- [SLICENSE – licencias firmadas (nuevo en la V2)](#slicense--licencias-firmadas-nuevo-en-la-v2)
- [SOST – envío por mail](#sost--envío-por-mail)
- [Estado general y salida ALV](#estado-general-y-salida-alv)
- [Resumen de objetos SAP usados](#resumen-de-objetos-sap-usados)
- [Pruebas en el laboratorio](#pruebas-en-el-laboratorio)

## Flujo general

```
START-OF-SELECTION
  read_servers          TH_SERVER_LIST            -> gt_servers
  read_wpinfo           RFC_SYSTEM_INFO, TH_GET_OWN_WP_NO, TH_WPINFO -> gt_wp
  check_sick            (si X_SICK)
  check_st22            (si X_ST22)
  check_sm12            (si X_SM12)
  check_sm13            (si X_SM13)
  check_sm50 + check_wp_capacity  (si X_SM50)
  check_rtcctool        (si X_RTCC)
  check_certificates    (si X_CERT)
  check_st03n           (si X_ST03)
  check_smlg            (si X_SMLG)
  check_scot            (si X_SCOT)
  check_license         (si P_LIC)    licencias antiguas
  check_license_likey   (si P_LIKEY)  licencias firmadas (nuevo en la V2)
  calculate_global
  send_mail             (si P_MAIL) + calculate_global otra vez
  build_fieldcat / display_report
```

La lista de instancias (`gt_servers`) y la foto de work processes (`gt_wp`) se leen una sola
vez al principio y las reutilizan ST22, SM13, SM50 y SMLG.

## Piezas comunes

### `add_result`: una fila del reporte

Cada chequeo agrega filas con `PERFORM add_result USING control status resumen detalle`.
El *control* define la transacción, el nombre del chequeo y el orden (`seq`) con que se agrupa
en el ALV; el *status* (`OK`, `WARNING`, `ERROR`, `INCOMPLETO`) define el semáforo y el
color de la celda Estado. Por convención la primera fila de cada chequeo es un resumen y
las siguientes son el detalle.

| Status | Texto | Ícono | Color celda (ALV) |
|---|---|---|---|
| `OK` | OK | `ICON_GREEN_LIGHT` | 5 (verde) |
| `WARNING` | Advertencia | `ICON_YELLOW_LIGHT` | 3 (amarillo) |
| `ERROR` | Error | `ICON_RED_LIGHT` | 6 (rojo) |
| `INCOMPLETO` | Incompleto | `ICON_INFORMATION` | 7 (naranja) |

### Llamadas dinámicas a FMs (`fm_exists`, `fm_param`, `fm_set`, `fm_call`)

Las FMs cuya interfaz puede cambiar entre releases no se llaman en forma estática:

1. `fm_exists` busca la FM en `TFDIR`.
2. `fm_param` lee de `FUPARAREF` (versión activa, `R3STATE = 'A'`) el tipo del parámetro,
   crea la variable con `CREATE DATA` y la agrega a una `ABAP_FUNC_PARMBIND_TAB` con el
   tipo de pasaje correcto (I/E/C/T). Si el tipo de diccionario no existe, usa un tipo por
   defecto (`STRING`, `XSTRING`, `I`).
3. `fm_set` hace lo mismo y le asigna un valor (parámetros de entrada).
4. `fm_call` ejecuta `CALL FUNCTION ... PARAMETER-TABLE ... EXCEPTION-TABLE` capturando
   `ERROR_MESSAGE`, `OTHERS` y cualquier excepción de clase; si hay error, arma el texto con
   `sy-msgid/sy-msgno`.

Si un parámetro no existe o la llamada falla, el chequeo queda **INCOMPLETO** con el motivo
en lugar de dar dump. Lo mismo pasa con las tablas leídas con `SELECT ... FROM (lv_tab)`
dentro de `TRY ... CATCH cx_root`.

### `submit_list`: leer la salida de otro report

Usado por SICK y RTCCTOOL. Verifica en `TRDIR` que el programa exista y sea ejecutable
(`SUBC = '1'`), lo ejecuta con `SUBMIT (prog) EXPORTING LIST TO MEMORY AND RETURN`, recupera
la lista con `LIST_FROM_MEMORY`, la pasa a texto con `LIST_TO_ASCI`, libera la memoria con
`LIST_FREE_MEMORY`, reemplaza los marcos `|` por espacios y descarta las líneas vacías.

### Instancias y work processes

| Dato | Cómo se obtiene |
|---|---|
| Instancias activas | `TH_SERVER_LIST` (igual que SM51). Si falla, se usa una sola entrada vacía = instancia local. |
| Instancia local | `RFC_SYSTEM_INFO` → `RFCSI-RFCDEST`. |
| WP propio | `TH_GET_OWN_WP_NO` → `WP_NO` (dinámico). Si no existe, queda en -1. |
| Work processes | `TH_WPINFO` por instancia (`WITH_CPU = '0'`, `WITH_MTX_INFO = '0'`). Para la instancia local se pasa `SRVNAME` vacío, que lee directo sin RFC. |

---

## SICK – consistencia del sistema

**Equivalente manual:** transacción SICK.

**Cómo lee:**
1. Busca el programa de la transacción SICK en `TSTC-PGMNA` (si no está, el de SM28).
2. Lo ejecuta con `submit_list` y obtiene la lista en texto.

**Cómo evalúa** (comparaciones `CS`, sin distinguir mayúsculas):

| Condición en la lista | Resultado |
|---|---|
| Línea con `NO ERROR`, `SIN ERROR` o `NINGUN ERROR` | Se guarda como texto de OK |
| Cualquier otra línea con `ERROR` | **Error**, una fila por línea (máximo 10) |
| Sin errores y con línea de OK | **OK** "Sistema consistente" con esa línea como detalle |
| Ni errores ni línea de OK | **Incompleto**, con la primera línea de la salida |

---

## ST22 – dumps

**Equivalente manual:** ST22, filtrando desde la misma fecha/hora.

**Parámetros:** `P_DMPDT` / `P_DMPTM` (vacío = últimas 24 h: ayer a la hora actual).

**Cómo lee:**
1. Lee las cabeceras de dumps de `SNAP_BEG` con `DATUM >= fecha desde`. Si esa tabla no
   existe, usa `SNAP` con `SEQNO = '000'` (la fila de cabecera de cada dump). Ambas son
   independientes de mandante, así que cuenta los dumps de todos los mandantes.
2. Descarta los anteriores a la hora desde (en el primer día) y las filas que no sean
   cabecera.
3. Obtiene el nombre del error del campo `FLIST`, que es una lista de campos con formato
   `ID(2) + LARGO(3) + VALOR`: recorre hasta 30 entradas y toma la de ID `FC`.
   Si no lo encuentra, usa `(sin nombre)`.
4. Agrupa por instancia (`AHOST`) y por error, y guarda el último dump de cada instancia
   (fecha, hora, usuario `UNAME`, error).
5. Agrega las instancias de `gt_servers` que no tuvieron dumps, para que figuren igual.

**Cómo evalúa:**

| Fila | Estado |
|---|---|
| Resumen `N dump(s) desde ...` | **OK** si N = 0, **Advertencia** si N > 0 |
| `instancia: sin dumps` | OK |
| `instancia: N dump(s)` | Advertencia. Detalle: errores con cantidad, ordenados de más a menos, y el último dump |

---

## SM12 – bloqueos

**Equivalente manual:** SM12 con mandante `*` (o el actual) y sin filtros.

**Parámetros:** `P_LOCKH` (horas, por defecto 24), `P_ALLCL` (todos los mandantes).

**Cómo lee:**
1. Mandantes: todos los de `T000` si `P_ALLCL = 'X'`, si no solo `sy-mandt`.
2. Por mandante llama a `ENQUEUE_READ` (`GCLIENT` = mandante, resto en blanco) y obtiene la
   tabla `ENQ` (estructura `SEQG3`).
3. Antigüedad de cada bloqueo = ahora − `GTDATE`/`GTTIME`, en segundos.
   Si el bloqueo no tiene fecha u hora, queda marcado como "sin fecha".
4. Modo (`GMODE`) y transacción (`GTCODE`) se leen con `ASSIGN COMPONENT`, por si no están
   en el release.

**Cómo evalúa:**

| Fila | Estado |
|---|---|
| Resumen | **Error** si algún bloqueo supera `P_LOCKH` horas; si no, **OK**. Detalle: total de bloqueos |
| Cada bloqueo (del más viejo al más nuevo, máximo 100) | **Error** si supera el límite, **OK** si no, **Advertencia** si no tiene fecha. Detalle: usuario, tabla, argumento, modo, transacción y desde cuándo |
| Más de 100 bloqueos | Advertencia "se muestran los 100 más viejos" |
| `ENQUEUE_READ` falla para un mandante | Incompleto |

---

## SM13 – actualizaciones

**Equivalente manual:** SM13 (registros con error y pendientes) + SM50 (WP de tipo UPD).

**Parámetros:** `P_VBMIN` (minutos, por defecto 10).

**Cómo lee:**
1. **WP de update:** cuenta en `gt_wp` los procesos con `WP_TYP = 'UPD'`.
2. **Errores:** lee `VBERROR` (hasta 500 filas): clave `VBKEY`, módulo `VBFUNC` y mensaje
   (`ARBGB`, `MSGNR`, `VARMSGVAL`). El texto del mensaje se arma con
   `MESSAGE ID ... INTO`.
3. **Cabeceras:** lee `VBHDR` (hasta 2000 filas): usuario `VBUSR`, transacción `VBTCODE`,
   programa y `VBDATE` (AAAAMMDDhhmmss).
4. **Pendientes viejos:** para las cabeceras sin error calcula la antigüedad de `VBDATE`
   contra la hora local y contra la hora UTC (`GET TIME STAMP` + `CONVERT TIME STAMP` con
   zona `UTC`) y se queda con la menor no negativa, porque según el release `VBDATE` se
   graba en una u otra zona.

**Cómo evalúa:**

| Condición | Estado |
|---|---|
| Hay WP pero ninguno UPD | **Error** "No hay work processes de update" |
| Cada registro con error (una vez por `VBKEY`, máximo 20) | **Error** con usuario, transacción, módulo y mensaje |
| Más de 20 registros con error | Error "N updates con error en total" |
| Pendientes con más de `P_VBMIN` min | **Advertencia** (posible update desactivado o trabado), con la antigüedad del más viejo |
| Nada de lo anterior | **OK** "Updates activos y sin errores": WP UPD y pendientes recientes |

---

## SM50 – estado de work processes

**Equivalente manual:** SM50 en cada instancia (o SM66).

**Parámetros:** `P_HOLDM` (minutos, por defecto 10) y `P_HWAIT` (segundos de la 2da
muestra, por defecto 15).

**Cómo lee:** usa la foto `gt_wp` de `TH_WPINFO`. El estado (`WP_STATUS`) se clasifica por
texto, en inglés o español:

| Categoría | Contiene |
|---|---|
| STOP | `STOP`, `DETEN`, `PARAD` |
| END | `ENDED`, `FINALIZ`, `TERMIN` |
| HOLD | `HOLD`, `RETEN` |
| WAIT | `WAIT`, `ESPER` |
| RUN | `RUN`, `EJEC` |
| OTHER | cualquier otro |

Se excluye el WP donde corre el propio programa (mientras consulta `TH_WPINFO`, aparece en
HOLD). Se lo identifica por el número de `TH_GET_OWN_WP_NO`; si esa FM no existe, se excluye
el WP del usuario que ejecuta sin programa asociado.

**Cómo evalúa:**

| Categoría | Resultado |
|---|---|
| WAIT / RUN | Normal, no se informa |
| STOP | **Error** "Work process detenido" |
| END | **Error** "Work process finalizado" |
| OTHER | **Advertencia** "estado no habitual" |
| HOLD con menos de `P_HOLDM` min (`WP_ELTIME`, columna Tiempo de SM50) | Se cuenta como HOLD breve |
| HOLD con `P_HOLDM` min o más | Candidato: se toma una 2da muestra (`WAIT UP TO P_HWAIT SECONDS` + `TH_WPINFO` otra vez) |

En la 2da muestra el candidato se descarta si cambió algo: ya no está en HOLD, cambió el
usuario, el programa o el PID, o el tiempo volvió atrás (atendió otro pedido). Si sigue
igual → **Error** "WP en HOLD hace N min sin cambios". Si el release no informa
`WP_ELTIME`, todos los HOLD pasan a la 2da muestra y, si siguen igual, quedan en
**Advertencia**.

El detalle de cada WP muestra: instancia, número, tipo, estado, motivo (`WP_WAITING`),
usuario, programa, acción y tiempo. Si no hubo problemas, una fila **OK** con el total de WP,
la cantidad de instancias y la de HOLD breves.

---

## SM50 – capacidad de work processes

**Equivalente manual:** la vista de totales de SM50 (procesos por tipo).

**Cómo lee:** sobre la misma foto `gt_wp`, por instancia cuenta el total y los libres
(categoría WAIT) por tipo, en el orden DIA, UPD, ENQ, BTC, SPO, UP2 y otros que aparezcan.
Los tipos sin procesos no se muestran, salvo DIA.

**Cómo evalúa:**

| Condición | Estado |
|---|---|
| Instancia sin WP de diálogo | **Error** |
| Ningún WP de diálogo libre | **Advertencia** |
| Ningún WP de update libre | **Advertencia** |
| Resto | **OK** |

Resumen: `instancia: N procesos - DIA 6/5 UPD 1/1 ...` (Total/Libres).

---

## RTCCTOOL – herramientas de servicio

**Equivalente manual:** transacción RTCCTOOL.

**Cómo lee:** ejecuta el report `RTCCTOOL` con `submit_list`. Al pasar la lista a texto,
`LIST_TO_ASCI` deja los íconos como códigos `@xx@`, y por ellos clasifica cada línea:

| Código | Significado |
|---|---|
| `@0A@`, `@5C@`, `@F1@` | Rojo |
| `@09@`, `@5D@` | Amarillo |
| `@08@`, `@5B@` | Verde |
| Línea con `MISSING` / `FALTA` (RTCCTOOL viejo, sin ST-A/PI) | Nota faltante (amarillo) |

También guarda la primera línea que contenga `VERSION`, para mostrarla.

**Cómo evalúa:**

| Condición | Estado |
|---|---|
| Línea roja | **Error** "Recomendación pendiente (rojo)" |
| Línea amarilla | **Advertencia** "Recomendación pendiente (amarillo)" |
| Nota faltante | **Advertencia** "Pendiente (versión)" con la línea |
| Más de 15 pendientes | Se muestran 15 y una fila de totales |
| Solo verdes | **OK** "Sin recomendaciones pendientes" |
| RTCCTOOL viejo sin notas faltantes | **OK** "Sin notas faltantes" |
| No reconoce ningún semáforo | **Incompleto**, con los códigos vistos y las primeras 40 líneas de la salida, para ajustar el parser |

---

## STRUST – certificados

**Equivalente manual:** STRUST, PSE por PSE (certificado propio y lista de certificados).

**Parámetros:** `P_CDIAS` (días de aviso, por defecto 30).

**Cómo lee:**
1. Directorio `sec` de la instancia: lee el parámetro `DIR_INSTANCE` con
   `CALL 'C_SAPGPARAM'` y le agrega `\sec` o `/sec` según el separador.
2. Lista los archivos del directorio con `EPS_GET_DIRECTORY_LISTING` y se queda con los
   `*.pse`.
3. Los PSE cuyo nombre empieza con `sap_system_pki` se informan y no se leen
   (ver [PSE de System PKI](#pse-de-system-pki)).
4. Por cada PSE:
   - **Certificado propio:** `SSFC_GET_OWNCERTIFICATE` (`PROFILE` = archivo PSE →
     `CERTIFICATE`, xstring).
   - **Lista de confianza:** `SSFC_GET_CERTIFICATELIST` (`PROFILE` → `CERTIFICATELIST`). Cada
     fila puede ser un xstring o una estructura cuyo primer campo es el xstring; se
     contemplan los dos casos.
5. Cada certificado se interpreta con `SSFC_PARSE_CERTIFICATE` (`CERTIFICATE` → `SUBJECT`,
   `VALIDTO`):
   - CN: regex `CN=([^,]+)` sobre el subject (si no hay CN, se muestra el subject completo).
   - Vencimiento: de `VALIDTO` se toman solo los dígitos. Con 14 o más, es AAAAMMDDhhmmss;
     con 12 (AAMMDDhhmmss), se antepone `20`.

**Cómo evalúa** (días = vencimiento − hoy). En la V2 el criterio es el mismo para el
certificado propio y para los de confianza:

| Condición | Propio | Confianza |
|---|---|---|
| Vencido | **Error** | **Error** (en la v1, Advertencia) |
| Vence en `P_CDIAS` días o menos | **Advertencia** | **Advertencia** |
| Más de `P_CDIAS` días | OK | OK |

Hay una fila por certificado (`PSE (propio)` o `PSE (confianza)`, con el CN; en el detalle,
el vencimiento, los días y el subject). Un certificado vencido dice
`VENCIDO el <fecha> (hace N dias)`.

La fila final tiene la cantidad de PSE, propios y de confianza
(`N PSE - M certificado(s) propio(s) + K de confianza`) y su estado depende de lo encontrado:

| Condición | Estado | Detalle |
|---|---|---|
| Al menos un vencido | **Error** | `N vencido(s), M por vencer en X dias (ver filas anteriores)` |
| Ninguno vencido, alguno por vencer | **Advertencia** | `M por vencer en X dias (ver filas anteriores)` |
| Ninguno | OK | `Ninguno vence en los proximos X dias` |

`eval_cert` cuenta por separado los vencidos (`p_expired`) y los que tuvieron aviso
(`p_flagged`); los por vencer son la diferencia.

### PSE de System PKI

Los PSE `sap_system_pki_instance.pse` (y en general `sap_system_pki*`) los genera y renueva el
kernel / `sapstartsrv` para la comunicación interna entre instancias. Están protegidos con PIN y
no se administran en STRUST, así que `SSFC_GET_OWNCERTIFICATE` no los puede abrir
("SSF kernel error: invalid parameter") y en la v1 el chequeo quedaba **Incompleto**.

En la V2, si el nombre del archivo cumple `CP 'sap_system_pki*'` (sin distinguir mayúsculas),
se agrega una fila **OK** `<pse>: PSE de System PKI, gestionado por el kernel` con el detalle
`No se revisa (no es un PSE de STRUST)`, y se pasa al siguiente PSE sin leerlo. Estos PSE no
suman en la cantidad de PSE del resumen.

**Limitaciones:** lee solo los PSE del directorio `sec` de la instancia donde corre (no los
de otras instancias ni los certificados de destinos SM59). Los errores al leer un PSE solo se
informan para el certificado propio. Un PSE sin lista de confianza es normal y no se informa.

---

## ST03N – tiempos de respuesta del día hábil anterior

**Equivalente manual:** ST03N → Total → Día → *Tmpo. resp. medio / paso diálogo (ms)* de
las filas DIALOG y RFC.

**Parámetros:** `P_RTDIV` (divisor, por defecto 1: el colector ya devuelve ms).

**Cómo lee (`get_workload`):**
1. Llama a `SWNC_COLLECTOR_GET_AGGREGATES` con `COMPONENT = 'TOTAL'`, `ASSIGNDSYS = sy-sysid`,
   `PERIODTYPE = 'D'` y `PERIODSTRT` = el día.
2. Lee la tabla `TASKTYPE`. Por cada fila toma `TASKTYPE`, `RESPTI` (tiempo total) y
   `DCOUNT` (pasos de diálogo; si no existe, `COUNT`).
3. Suma por tipo de tarea: `01` = DIALOG, `FE` = RFC.
4. Promedio = Σ`RESPTI` / Σ`DCOUNT` / `P_RTDIV`.

**Día que se usa:** el hábil anterior a hoy (`previous_workday` con `DATE_COMPUTE_DAY`:
saltea sábados y domingos; no contempla feriados). Si ese día no tiene datos, retrocede día
hábil por día hábil hasta encontrar uno, con un máximo de 30 días corridos.

**Cómo evalúa:**

| Fila | Estado |
|---|---|
| Tiempo resp. Dialog | **OK**, informativo: `X ms`, con los pasos y el día |
| Tiempo resp. RFC | **OK**, informativo |
| Sin datos en 30 días | **Advertencia**: revisar el job `SAP_COLLECTOR_FOR_PERFMONITOR` (SWNCTOTAL) |

Si se usó un día anterior al buscado, el detalle lo aclara.

---

## SMLG – tiempo de respuesta por instancia

**Equivalente manual:** SMLG → columna de tiempo de respuesta de cada instancia.

**Parámetros:** `P_RTLIM` (ms, por defecto 3000).

**Cómo lee:**
1. **Grupos de logon:** tabla `RZLLITAB` (`CLASSNAME` = grupo, `APPLSERVER` = instancia,
   `RESP_TIME` = umbral de tiempo de respuesta definido en SMLG).
2. **Muestra en vivo del message server** (lo mismo que muestra SMLG):
   `RZL_STRG_READALL_I` con `SRVNAME = 'MSGSERVER'`, tabla `INTG_TBL` (`SALSTINTG`), filas con
   `VALUE1 = 7353`:

   | Campo | Dato |
   |---|---|
   | `NAME` | instancia |
   | `VALUE2` | tiempo de respuesta (ms) |
   | `VALUE3` | pasos de diálogo |
   | `VALUE4` | usuarios |
   | `VALUE5` | calidad |
   | `VALUE` | hora de la muestra |

3. **Referencia:** promedio Dialog de hoy de la instancia con `get_workload`
   (`COMPONENT` = nombre de instancia, día = hoy).

**Cómo evalúa:**

| Condición | Estado |
|---|---|
| Hay muestra en vivo y es menor a `P_RTLIM` | **OK** |
| Hay muestra en vivo y es mayor o igual | **Error** |
| No hay muestra: se compara el promedio del día | OK o Error con el mismo criterio |
| No hay muestra ni promedio | **Incompleto** |

El detalle muestra la hora de la muestra, los pasos, los usuarios, la calidad, los grupos de
logon, el umbral de SMLG (si hay) y el promedio del día.

---

## SCOT – SAPconnect

**Equivalente manual:** SCOT (nodos) + SOST (cola) + SM37 (job de envío).

**Cómo lee:**
1. **Nodos:** `SELECT *` de `SXNODES` en una tabla creada en forma dinámica. El campo que
   indica si el nodo está activo depende del release, así que se busca por RTTS
   (`CL_ABAP_TYPEDESCR=>DESCRIBE_BY_NAME`) entre `NODE_ACTIVE`, `ACTIVE`, `NODE_ACT`,
   `NODEACTIVE`, `INUSE`, `NODE_INUSE` e `IN_USE`, o los inversos `NODE_INACT`, `INACTIVE`
   y `NODEINACT`.
2. **Cola:** `SELECT COUNT(*)` de `SOSC`.
3. **Job de envío:** `TBTCP` (paso con `PROGNAME = 'RSCONN01'`) unida con `TBTCO`
   (`STATUS = 'S'`, liberado).

**Cómo evalúa:**

| Condición | Estado |
|---|---|
| Sin nodos y cola vacía | **OK** |
| Sin nodos y envíos en cola | **Error** |
| Cada nodo activo | **OK** "Nodo X activo" |
| Cada nodo inactivo | **Error** "Nodo X inactivo" |
| No se encontró el campo de activo | **Incompleto**, con la lista de campos de `SXNODES` |
| Envíos pendientes en cola | **Advertencia** |
| Hay nodos activos pero ningún job RSCONN01 liberado | **Advertencia** |

---

## SLICENSE – licencias antiguas

**Equivalente manual:** SLICENSE (licencias del formato anterior). Replica la lógica de
`SAPMSLIC` (FORM `sl_read_data`).

**Cambio en la V2:** solo el nombre. En la pantalla es *Licencias antiguas (vencimiento)*
(`P_LIC`) y en el reporte el chequeo se llama *Licencias antiguas*; la lógica es la de la v1.

**Parámetros:** `P_LDIAS` (días de aviso, por defecto 30).

**Cómo lee:**
1. **Clave de hardware actual:** `SLIC_GET_CUSTKEY` (`FROM_WHERE = 1`, `HOSTNAME` vacío →
   `CUSTKEY`).
2. **Licencias instaladas:** `SLIC_READ_LICENSES` → tabla `LICENSES`. De cada fila toma
   `SYSNAME`, `CUSTKEY`, `PRODUCTID`, `INSTNUMBER` y `EXP_DATE`.
3. Solo considera las licencias de `SYSNAME = sy-sysid`. Una licencia está **activa** si su
   `CUSTKEY` coincide con la clave de hardware actual (o si no se pudo leer la clave).
4. `EXP_DATE`: solo los dígitos (AAAAMMDD); `99991231` = permanente.

**Cómo evalúa:**

| Condición | Estado de la licencia |
|---|---|
| Fecha ilegible | Incompleto |
| Permanente | OK |
| Vencida | **Error** |
| Vence en `P_LDIAS` días o menos | **Advertencia** |
| Más días | OK |
| Licencia de otra clave de hardware | OK (solo informativa, "inactiva") |

La fila de resumen dice "N licencia(s) activa(s) de M instalada(s)" con el peor estado entre
las activas. Si no hay licencias para el sistema, o ninguna coincide con la clave de hardware
actual, queda en **Error**.

> El detalle incluye el número de instalación y la clave de hardware: tenerlo en cuenta
> antes de compartir capturas o mails del reporte.

---

## SLICENSE – licencias firmadas (nuevo en la V2)

**Equivalente manual:** SLICENSE, pantalla de licencias firmadas (`SAPMSLIC` dynpro 2000).

**Parámetros:** tilde `P_LIKEY` en *Chequeos* (*Licencias firmadas y cert. mantenimiento*,
marcada por defecto; *Marcar todos* / *Desmarcar todos* también la incluyen) y `P_LDIAS`
(días de aviso, el mismo que las licencias antiguas).

**Cómo lee:**
1. **Licencias firmadas:** `SLIC_LIKEY_GET_ALL_LICENSES` (dinámica) → tabla `LICENSES`
   (estructura `LIKEY_LICENSE`). De cada fila toma `SID`, `SW_PRODUCT`, `TYPE`
   (`0` permanente, `1` temporal), `VALIDITY`, `BEGIN_DATE` y `END_DATE`.
   Solo evalúa las de `SID = sy-sysid`; las de otros SID solo se cuentan.
2. **Certificado de mantenimiento:** es la licencia del producto `Maintenance_` + tipo de base
   de datos, con el mismo criterio que `OCS_CHECK_MAINTENANCE_CERT`: los tres primeros
   caracteres de `sy-dbsys`, salvo `DB400` / `DB2/400` / `DB2/400A` = `AS4`, `DB2/CS` = `DB6`
   y `DB2/EXS` = `DB8`. En Sybase ASE queda `Maintenance_SYB`.
3. **Producto estándar:** `SLIC_LIKEY_GET_STANDARD_PROD` → `STANDARD_SW_PRODUCT` (por ejemplo
   `NetWeaver_SYB`) y después `SLIC_LIKEY_CHECK` con `PRODUCT` = ese producto. Se llama con
   una tabla de excepciones (`NO_VALID_LICENSE_KEY` = 1, `ERROR` = 2, `OTHERS` = 99).

`VALIDITY` usa el dominio `LIKEY_VALIDITY`:

| Valor | Texto en el reporte |
|---|---|
| 0 | valida |
| 1 | validez desconocida |
| 2 | ID de sistema incorrecto |
| 3 | no se permite clave de licencia temporal |
| 4 | vencida |
| 5 | aun no valida |
| 6 | firma no valida |

**Cómo evalúa cada licencia:** primero la validez que informa el kernel y, si es válida, la
fecha de fin (`99991231` = sin vencimiento; días = fin − hoy):

| Condición | Estado |
|---|---|
| `VALIDITY` 2, 3, 4 o 6 | **Error** |
| `VALIDITY` 1 o 5 | **Advertencia** |
| Válida, fecha de fin ilegible | **Incompleto** |
| Válida, sin vencimiento | OK |
| Válida, ya vencida | **Error** |
| Válida, vence en `P_LDIAS` días o menos | **Advertencia** |
| Válida, más días | OK |

Cada licencia es una fila
`Licencia <producto> (<permanente|temporal>): <validez> - <vencimiento>` (o
`Certificado de mantenimiento ...` si el producto es `Maintenance_*`), con el período de
validez en el detalle.

**Otras filas:**

| Fila | Estado |
|---|---|
| `Producto <estándar>: clave de licencia valida` (`SLIC_LIKEY_CHECK` sin error) | OK |
| `Producto <estándar>: sin clave de licencia valida` (`NO_VALID_LICENSE_KEY`) | **Error** |
| `SLIC_LIKEY_CHECK` con otro error, o no se pudo determinar el producto | **Incompleto** |
| `Certificado de mantenimiento (Maintenance_XXX): no instalado` | OK, informativa (SPAM/SAINT lo verifican al importar paquetes) |

**Orden en el reporte:** primero una fila de resumen
`N licencia(s) firmada(s) para <SID>` con el peor estado de todas
(ERROR > WARNING > INCOMPLETO > OK). En el detalle va el producto estándar, si hay certificado de
mantenimiento, cuántas licencias son de otros SID y los días de aviso. Después, la fila del
producto estándar y una fila por licencia.

Si `SLIC_LIKEY_GET_ALL_LICENSES` no existe o falla, una sola fila **Incompleto** con el motivo.

A diferencia de las licencias antiguas, **no muestra la clave de hardware ni el número de
instalación**.

---

## SOST – envío por mail

**Equivalente manual:** SOST (estado de la orden de envío).

**Cuándo envía:** según la pestaña *Envio por mail*:

| Opción | Envía si el estado general es |
|---|---|
| `R_MALL` Siempre | cualquiera |
| `R_MWARN` Solo con errores, advertencias o incompletos | distinto de OK |
| `R_MERR` Solo con errores | ERROR |

Si no corresponde enviar, agrega una fila **OK** "No se envió: ..." con el motivo.

**Cómo arma el mail:**
- **Asunto:** `Health check <SID>/<mandante> <fecha> - <estado>` o, si se completó
  `P_MSUBJ`, ese texto + ` - <estado>`.
- **Cuerpo (`build_mail_html`):** HTML con estilos en línea (para que lo respeten los
  clientes de correo): título, línea de sistema/mandante/host/fecha, recuadro de estado
  general con los contadores y una tabla con las mismas filas y el mismo orden que el ALV.
  La transacción y el chequeo van solo en la primera fila de cada grupo, la celda Estado
  sale coloreada y los textos se escapan (`& < > "`). El string se corta en líneas de 255
  caracteres (`SOLI_TAB`).
- **Envío:** `CL_BCS=>CREATE_PERSISTENT`, `CL_DOCUMENT_BCS=>CREATE_DOCUMENT` (`I_TYPE = 'HTM'`),
  remitente opcional (`CL_CAM_ADDRESS_BCS=>CREATE_INTERNET_ADDRESS`), destinatarios `S_MTO`
  (express) y copias `S_MCC`, `SET_SEND_IMMEDIATELY( P_MIMM )`, `SEND` y `COMMIT WORK`.

**Resultado:** fila **OK** "Mail generado para ..." (con el asunto y si salió inmediato o
queda en cola), **Error** si `SEND` devuelve falso o hay una excepción `CX_BCS`. Que el mail
se haya generado no garantiza que se haya entregado: el estado real se ve en SOST.

Como el envío ocurre antes de mostrar el ALV, la fila de SOST no viaja en el mail, pero sí
cuenta para el estado general que se ve en pantalla (se recalcula después de enviar).

---

## Estado general y salida ALV

**Estado general (`calculate_global`):** cuenta las filas por estado. El estado general es el
peor que aparezca, en este orden: ERROR > WARNING > INCOMPLETO > OK. En fondo
(`sy-batch = 'X'`) se escribe además un mensaje `S` con el estado y los contadores, que queda
en el log del job.

**ALV:** `REUSE_ALV_GRID_DISPLAY` con:
- Columnas: semáforo, Transacción, Chequeo, Estado (celda coloreada vía `CELLCOLOR`),
  Resultado y Detalle.
- Orden por `SEQ`, transacción, chequeo y `ROWNO` (orden de inserción). Transacción y
  chequeo son columnas clave del orden, así que el ALV no repite el valor en las filas
  siguientes del mismo grupo.
- Layout con cebra, color de celda (`COLTAB_FIELDNAME = 'CELLCOLOR'`) y variantes de
  disposición grabables (`I_SAVE = 'A'`).
- Encabezado HTML en pantalla (`html_top_of_page` con `CL_DD_DOCUMENT`): título, sistema,
  mandante, host, fecha/hora, estado general y contadores. Para impresión y para el spool
  del job, `top_of_page` con `REUSE_ALV_COMMENTARY_WRITE`.

**Límite conocido:** el ALV grid muestra hasta 128 caracteres por celda. El campo Detalle
guarda 255 y el mail lo muestra completo.

---

## Resumen de objetos SAP usados

| Chequeo | FMs / kernel | Tablas |
|---|---|---|
| General | `TH_SERVER_LIST`, `RFC_SYSTEM_INFO`, `TH_GET_OWN_WP_NO`, `TH_WPINFO` | `TFDIR`, `FUPARAREF`, `TRDIR` |
| SICK | `LIST_FROM_MEMORY`, `LIST_TO_ASCI`, `LIST_FREE_MEMORY` | `TSTC` |
| ST22 | – | `SNAP_BEG` (o `SNAP`) |
| SM12 | `ENQUEUE_READ` | `T000` |
| SM13 | – | `VBERROR`, `VBHDR` |
| SM50 | `TH_WPINFO` (2da muestra) | – |
| RTCCTOOL | `SUBMIT RTCCTOOL` + funciones de lista | `TRDIR` |
| STRUST | `C_SAPGPARAM`, `EPS_GET_DIRECTORY_LISTING`, `SSFC_GET_OWNCERTIFICATE`, `SSFC_GET_CERTIFICATELIST`, `SSFC_PARSE_CERTIFICATE` | – |
| ST03N | `SWNC_COLLECTOR_GET_AGGREGATES`, `DATE_COMPUTE_DAY` | – |
| SMLG | `RZL_STRG_READALL_I`, `SWNC_COLLECTOR_GET_AGGREGATES` | `RZLLITAB` |
| SCOT | – | `SXNODES`, `SOSC`, `TBTCP`, `TBTCO` |
| SLICENSE (antiguas) | `SLIC_GET_CUSTKEY`, `SLIC_READ_LICENSES` | – |
| SLICENSE (firmadas, V2) | `SLIC_LIKEY_GET_ALL_LICENSES`, `SLIC_LIKEY_GET_STANDARD_PROD`, `SLIC_LIKEY_CHECK` | – |
| Mail | `CL_BCS`, `CL_DOCUMENT_BCS`, `CL_CAM_ADDRESS_BCS` | – |
| ALV | `REUSE_ALV_GRID_DISPLAY`, `REUSE_ALV_COMMENTARY_WRITE`, `CL_DD_DOCUMENT` | – |

Las FMs marcadas como dinámicas en el código (`SWNC_*`, `SSFC_*`, `SLIC_*`,
`TH_GET_OWN_WP_NO`) se llaman mediante `fm_param` / `fm_call`; si no existen o cambian de
interfaz, el chequeo queda Incompleto. `SLIC_LIKEY_CHECK` se llama con `CALL FUNCTION ...
PARAMETER-TABLE ... EXCEPTION-TABLE` propio, para distinguir `NO_VALID_LICENSE_KEY` de otros
errores.

---

## Pruebas en el laboratorio

Probado en BAS/001 (SAP_BASIS 731, kernel 722, Sybase ASE) del 12 al 13.11.2026, corriendo la
v1 y la V2 sobre los mismos casos:

| Caso | v1 (v25) | V2 |
|---|---|---|
| Copia de un PSE de System PKI en el directorio `sec` | Incompleto (no se puede leer el certificado propio) | Fila informativa OK, resumen sin cambios |
| PSE de prueba con un certificado de confianza vencido | Fila en Advertencia, resumen en Advertencia | Fila en **Error**, resumen en **Error** "1 vencido(s), 0 por vencer" |
| Licencia firmada temporal de `NetWeaver_SYB` que venció el 12.11.2026 | No la ve: la licencia antigua permanente sigue OK | Resumen en **Error**; producto `NetWeaver_SYB` sin clave válida (`NO_VALID_LICENSE_KEY`); licencia temporal vencida (`VALIDITY` 4) en Error |
| Sin certificado de mantenimiento instalado | – | Fila informativa OK "Certificado de mantenimiento (Maintenance_SYB): no instalado" |
| Licencias antiguas | OK | OK (mismo resultado, con el nombre nuevo) |
