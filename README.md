# sap-daily-health-check

Report ABAP **`ZDAILY_HEALTH_CHECK`** que automatiza el control diario de Basis de un sistema SAP
y muestra el resultado en un ALV tipo tablero (semáforo, transacción, chequeo, estado, resultado y detalle).

Probado en SAP ECC 6.0 EHP6 (SAP_BASIS 731, kernel 722, Sybase ASE). Las llamadas a FMs y tablas
que pueden cambiar entre releases se hacen en forma dinámica: si algo no existe o tiene otra interfaz,
el chequeo queda **INCOMPLETO** con el motivo, en lugar de dar dump.

## Chequeos

| Transacción | Chequeo | Criterio |
|---|---|---|
| SICK | Consistencia del sistema | OK si informa "no errors reported" |
| ST22 | Dumps | Cantidad por instancia desde fecha/hora configurable (por defecto, últimas 24 h), con desglose por error |
| SM12 | Bloqueos | Detalla todos; **Error** si alguno supera N horas (por defecto 24) |
| SM13 | Actualizaciones | WP de update presentes, sin registros con error ni pendientes viejos |
| SM50 | Work processes | Stopped/Ended = Error; HOLD solo si supera N minutos y sigue sin cambios en una 2da muestra. Además, total/libres por tipo de WP |
| RTCCTOOL | Herramientas de servicio | Recomendaciones / notas pendientes |
| STRUST | Certificados | CN y vencimiento de los certificados propios y de confianza de cada PSE; aviso N días antes |
| ST03N | Tiempos de respuesta | Tiempo resp. medio / paso de diálogo (ms) de Dialog y RFC del día hábil anterior (retrocede hasta el último con datos) |
| SMLG | Tiempo por instancia | Valor en vivo del message server (igual que SMLG) contra un límite (por defecto 3000 ms) |
| SCOT | SAPconnect | Nodos activos o, si no hay nodos, cola vacía; job RSCONN01 liberado |
| SLICENSE | Licencia SAP | Vencimiento de la licencia activa (misma lógica que SLICENSE) |

## Instalación

1. SE38 → crear `ZDAILY_HEALTH_CHECK` (tipo *Programa ejecutable*).
2. Pegar el contenido de [`src/ZDAILY_HEALTH_CHECK.abap`](src/ZDAILY_HEALTH_CHECK.abap) y activar.
   No hace falta crear elementos de texto: los textos de pantalla se cargan desde el código.

Si al activar aparece `GEN_SELECTION_SCREEN_ERROR`, ejecutar el programa `RSDBGENA` sobre
`ZDAILY_HEALTH_CHECK` para ver el detalle (por ejemplo, *Screen contains overlapping objects*).

## Uso

La pantalla de selección tiene pestañas:

- **Chequeos**: qué controles ejecutar (botones *Marcar todos* / *Desmarcar todos*).
- **Parámetros**: umbrales de cada control (horas de bloqueo, minutos de HOLD, días de aviso, etc.).

### Variantes y jobs

Una variante guarda todas las pestañas, pero **SAP solo incluye las pestañas que se abrieron
antes de grabarla**: hacer clic en cada pestaña y recién después *Grabar como variante*.

Para jobs de fondo, en la variante conviene poner `P_DMPDT` (dumps desde) como
variable de selección **D** → *Fecha actual +/- ??? días* = `-1`.

En fondo, el ALV sale al spool del job y el estado general queda en el log del job.
