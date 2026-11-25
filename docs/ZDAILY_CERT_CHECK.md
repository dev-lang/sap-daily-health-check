# ZDAILY_CERT_CHECK – control diario de certificados

Report ABAP que revisa el vencimiento de los certificados de todos los PSE del directorio
`sec` de la instancia (lo mismo que se ve en STRUST), con el mismo criterio que el chequeo de
certificados de [ZDAILY_HEALTH_CHECK V2](ZDAILY_HEALTH_CHECK_V2.md). Sirve para correrlo solo,
por ejemplo en un job diario, sin el resto del health check.

Salida: ALV tipo tablero (semáforo, transacción, chequeo, estado, resultado y detalle) y,
opcionalmente, el mismo tablero en un mail HTML.

Probado en BAS/001 (SAP ECC 6.0 EHP6, SAP_BASIS 731, Sybase ASE) el 20.11.2026 y el 25.11.2026.

---

## Pantalla de selección

Tres pestañas. Una variante guarda las tres, así que sirve para un job de fondo.

| Pestaña | Campo | Por defecto | Qué hace |
|---|---|---|---|
| Chequeos | `X_OWN` | marcado | Certificado propio de cada PSE |
| | `X_TRUST` | marcado | Lista de certificados de confianza de cada PSE |
| | `X_PKI` | marcado | Lista los PSE de System PKI (informativo, no se leen) |
| Parámetros | `P_CDIAS` | 30 | Advertencia si el certificado vence dentro de N días |
| | `P_CERR` | 0 | Error si vence dentro de N días (0 = solo vencidos). No puede superar a `P_CDIAS` |
| | `S_PSE` | vacío | Filtro por nombre de archivo PSE (`SAPSSL*`, `SAPSYS.pse`). Vacío = todos |
| | `P_OKROW` | marcado | Mostrar también los certificados en OK. Desmarcado, el reporte muestra solo los avisos |
| Envío por mail | `P_MAIL` | desmarcado | Enviar el reporte por mail al terminar |
| | `S_MTO`, `S_MCC` | | Destinatarios y copia |
| | `P_MFROM` | vacío = usuario | Remitente |
| | `P_MSUBJ` | vacío = automático | Asunto; el estado general se agrega al final |
| | `R_MALL`, `R_MWARN`, `R_MERR` | Siempre | Cuándo enviar: siempre, solo con avisos, o solo con errores |
| | `P_MIMM` | marcado | Envío inmediato, sin esperar al job de SCOT |

---

## Cómo lee

1. **Directorio `sec`:** toma `DIR_INSTANCE` del perfil (`C_SAPGPARAM`) y le agrega `\sec`
   (o `/sec`). Lista los archivos con `EPS_GET_DIRECTORY_LISTING` y se queda con los `*.pse`.
2. **PSE de System PKI** (`sap_system_pki*`): los maneja el kernel y están protegidos con PIN,
   así que no se leen. Con `X_PKI` aparecen como fila informativa en OK.
3. **Certificado propio:** `SSFC_GET_OWNCERTIFICATE` con el nombre del PSE.
4. **Lista de confianza:** `SSFC_GET_CERTIFICATELIST`. Un PSE sin lista es normal y no se informa.
5. **Datos de cada certificado:** `SSFC_PARSE_CERTIFICATE` devuelve subject, vencimiento
   (`VALIDTO`) y, si el release los tiene, `VALIDFROM`, `ISSUER` y `SERIALNO`. Un certificado es
   autofirmado cuando el emisor es igual al subject.

Las FMs `SSFC_*` se llaman en forma dinámica, con los tipos leídos de `FUPARAREF`. Si alguna
no existe o tiene otra interfaz, la fila queda **Incompleto** con el motivo, en lugar de dar dump.

---

## Cómo evalúa

| Condición | Estado |
|---|---|
| Vencido | **Error** |
| Vence dentro de `P_CERR` días (si `P_CERR` > 0) | **Error** |
| Vence dentro de `P_CDIAS` días | **Advertencia** |
| Resto | OK |
| No se pudo leer el certificado, la lista o la fecha | **Incompleto**, con el motivo |
| No se pudo leer `DIR_INSTANCE` o el directorio, o no hay PSE para revisar | **Incompleto** |

Filas del reporte:

| Chequeo | Fila |
|---|---|
| Resumen de certificados | "N PSE - N certificado(s) propio(s) + N de confianza", con el peor estado. El detalle dice cuántos están vencidos, por vencer, sin leer y autofirmados |
| | "Próximo vencimiento: fecha (días)", con el CN y el PSE (informativo) |
| | "Todos los certificados en OK", solo si `P_OKROW` está desmarcado y no hay avisos |
| Certificados propios | Una fila por PSE: vencimiento, desde, autofirmado o emisor, serie y subject |
| Certificados de confianza | Una fila por certificado de cada lista |
| PSE de System PKI | Una fila por PSE de System PKI |
| Envío por mail | Resultado del envío (si `P_MAIL`) |

---

## Estado general y contadores

El estado general es el peor que aparezca: ERROR > ADVERTENCIA > INCOMPLETO > OK.

Los contadores del encabezado (Errores, Advertencias, Incompletos, OK) cuentan filas. Las del
resumen ("N PSE…" y "Próximo vencimiento") no se cuentan, porque repiten lo que ya cuentan las
filas de cada certificado. Se agregan con `add_summary`, que las marca (`IS_SUM = 'X'`), y se
siguen mostrando en el ALV y en el mail. Las filas Incompleto del resumen (por ejemplo "No se
encontraron PSE para revisar") sí se cuentan.

Con `P_OKROW` desmarcado, los certificados en OK no generan fila, así que tampoco se cuentan.

En fondo (`sy-batch = 'X'`) se escribe un mensaje con el estado y los contadores, que queda en
el log del job.

---

## Prueba en BAS (25.11.2026)

10 PSE, 10 certificados propios y 5 de confianza, más un PSE de System PKI. Incluye el PSE de
prueba `ZPRUEBA_VENCIDO.pse`, con un certificado de confianza vencido el 01.01.2021.

| Corrida | Encabezado | Filas |
|---|---|---|
| Con certificados en OK | Errores: 1, Advertencias: 0, Incompletos: 0, OK: 15 | Resumen en Error, próximo vencimiento ISRG Root X1 el 04.06.2035, 10 propios en OK, 4 de confianza en OK, 1 vencido en Error, System PKI en OK |
| Sin certificados en OK | Errores: 1, Advertencias: 0, Incompletos: 0, OK: 1 | Resumen, próximo vencimiento, el vencido y System PKI |

---

## Objetos SAP usados

| Tipo | Objetos |
|---|---|
| FMs | `EPS_GET_DIRECTORY_LISTING`, `SSFC_GET_OWNCERTIFICATE`, `SSFC_GET_CERTIFICATELIST`, `SSFC_PARSE_CERTIFICATE`, `REUSE_ALV_GRID_DISPLAY`, `REUSE_ALV_COMMENTARY_WRITE` |
| Tablas | `FUPARAREF` (interfaz de las FMs dinámicas) |
| Clases | `CL_BCS`, `CL_DOCUMENT_BCS`, `CL_CAM_ADDRESS_BCS` (mail), `CL_DD_DOCUMENT` (encabezado HTML) |
| Kernel | `C_SAPGPARAM` (`DIR_INSTANCE`) |
