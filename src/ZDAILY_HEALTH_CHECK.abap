*&---------------------------------------------------------------------*
*& Report  ZDAILY_HEALTH_CHECK
*&
*& Health check diario Basis:
*&   SICK, SM12, SM13, SM50, RTCCTOOL, certificados (STRUST),
*&   ST03N, SMLG, SCOT
*&
*& Notas:
*& - Las llamadas a FMs/tablas que pueden variar entre releases se
*&   hacen en forma dinamica: si algo no existe o tiene otra interfaz,
*&   el control queda INCOMPLETO con el motivo, en lugar de dar dump.
*& - En job de fondo la grilla ALV sale al spool, y el estado general
*&   se escribe tambien en el log del job.
*&---------------------------------------------------------------------*
REPORT zdaily_health_check LINE-SIZE 255.

TYPE-POOLS: slis, abap, icon.

*----------------------------------------------------------------------*
* Pantalla de seleccion con 2 pestanas:
*  - Chequeos:   que controles ejecutar
*  - Parametros: umbrales de cada control
*  Una variante guarda las dos pestanas (sirve para jobs de fondo).
*  Los textos se cargan en INITIALIZATION (sin elementos de texto).
*  Ojo: los campos TYPE i ocupan hasta la columna ~45; las unidades van
*  en la 48 para no superponerse (sino da GEN_SELECTION_SCREEN_ERROR).
*----------------------------------------------------------------------*
TABLES sscrfields.
DATA gv_email TYPE ad_smtpadr.            "referencia para S_MTO / S_MCC

*--- Pestana 1: chequeos a ejecutar -----------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 101 AS SUBSCREEN.
SELECTION-SCREEN BEGIN OF BLOCK b_chk WITH FRAME TITLE t_chk.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_sick AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_sick FOR FIELD x_sick.
SELECTION-SCREEN COMMENT 14(45) d_sick.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_st22 AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_st22 FOR FIELD x_st22.
SELECTION-SCREEN COMMENT 14(45) d_st22.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_sm12 AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_sm12 FOR FIELD x_sm12.
SELECTION-SCREEN COMMENT 14(45) d_sm12.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_sm13 AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_sm13 FOR FIELD x_sm13.
SELECTION-SCREEN COMMENT 14(45) d_sm13.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_sm50 AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_sm50 FOR FIELD x_sm50.
SELECTION-SCREEN COMMENT 14(45) d_sm50.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_rtcc AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_rtcc FOR FIELD x_rtcc.
SELECTION-SCREEN COMMENT 14(45) d_rtcc.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_cert AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_cert FOR FIELD x_cert.
SELECTION-SCREEN COMMENT 14(45) d_cert.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_st03 AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_st03 FOR FIELD x_st03.
SELECTION-SCREEN COMMENT 14(45) d_st03.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_smlg AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_smlg FOR FIELD x_smlg.
SELECTION-SCREEN COMMENT 14(45) d_smlg.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_scot AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_scot FOR FIELD x_scot.
SELECTION-SCREEN COMMENT 14(45) d_scot.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_lic AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_lic FOR FIELD p_lic.
SELECTION-SCREEN COMMENT 14(45) d_lic.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN SKIP 1.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN PUSHBUTTON 1(18) b_all USER-COMMAND sall.
SELECTION-SCREEN PUSHBUTTON 21(18) b_none USER-COMMAND snone.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_chk.
SELECTION-SCREEN END OF SCREEN 101.

*--- Pestana 2: parametros ---------------------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 102 AS SUBSCREEN.
SELECTION-SCREEN BEGIN OF BLOCK b_st22 WITH FRAME TITLE t_st22.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_dmpdt FOR FIELD p_dmpdt.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_dmpdt TYPE sy-datum.          "DATS: F4 con calendario
SELECTION-SCREEN POSITION 46.
PARAMETERS p_dmptm TYPE sy-uzeit.          "TIMS: F4 de hora
SELECTION-SCREEN COMMENT 57(16) u_dmpdt.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_st22.

SELECTION-SCREEN BEGIN OF BLOCK b_lock WITH FRAME TITLE t_lock.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_lockh FOR FIELD p_lockh.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_lockh TYPE i DEFAULT 24.
SELECTION-SCREEN COMMENT 48(24) u_lockh.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_allcl AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 36(30) c_allcl FOR FIELD p_allcl.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_vbmin FOR FIELD p_vbmin.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_vbmin TYPE i DEFAULT 10.
SELECTION-SCREEN COMMENT 48(24) u_vbmin.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_lock.

SELECTION-SCREEN BEGIN OF BLOCK b_wp WITH FRAME TITLE t_wp.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_holdm FOR FIELD p_holdm.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_holdm TYPE i DEFAULT 10.
SELECTION-SCREEN COMMENT 48(24) u_holdm.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_hwait FOR FIELD p_hwait.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_hwait TYPE i DEFAULT 15.
SELECTION-SCREEN COMMENT 48(24) u_hwait.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_wp.

SELECTION-SCREEN BEGIN OF BLOCK b_cert WITH FRAME TITLE t_cert.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_cdias FOR FIELD p_cdias.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_cdias TYPE i DEFAULT 30.
SELECTION-SCREEN COMMENT 48(24) u_cdias.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_cert.

SELECTION-SCREEN BEGIN OF BLOCK b_perf WITH FRAME TITLE t_perf.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_rtlim FOR FIELD p_rtlim.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_rtlim TYPE i DEFAULT 3000.
SELECTION-SCREEN COMMENT 48(24) u_rtlim.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_rtdiv FOR FIELD p_rtdiv.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_rtdiv TYPE i DEFAULT 1.
SELECTION-SCREEN COMMENT 48(24) u_rtdiv.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_perf.

SELECTION-SCREEN BEGIN OF BLOCK b_lic WITH FRAME TITLE t_lic.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_ldias FOR FIELD p_ldias.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_ldias TYPE i DEFAULT 30.
SELECTION-SCREEN COMMENT 48(24) u_ldias.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_lic.
SELECTION-SCREEN END OF SCREEN 102.

*--- Pestana 3: envio por mail ----------------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 103 AS SUBSCREEN.
SELECTION-SCREEN BEGIN OF BLOCK b_mail WITH FRAME TITLE t_mail.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_mail AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN COMMENT 4(50) c_mail FOR FIELD p_mail.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN SKIP 1.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_mto FOR FIELD s_mto.
SELECTION-SCREEN POSITION 33.
SELECT-OPTIONS s_mto FOR gv_email NO INTERVALS VISIBLE LENGTH 30.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_mcc FOR FIELD s_mcc.
SELECTION-SCREEN POSITION 33.
SELECT-OPTIONS s_mcc FOR gv_email NO INTERVALS VISIBLE LENGTH 30.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_mfrom FOR FIELD p_mfrom.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_mfrom TYPE ad_smtpadr VISIBLE LENGTH 30.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_msubj FOR FIELD p_msubj.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_msubj TYPE so_obj_des VISIBLE LENGTH 38.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN COMMENT /1(70) c_mnote.
SELECTION-SCREEN END OF BLOCK b_mail.

SELECTION-SCREEN BEGIN OF BLOCK b_when WITH FRAME TITLE t_when.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS r_mall RADIOBUTTON GROUP snd DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(55) c_mall FOR FIELD r_mall.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS r_mwarn RADIOBUTTON GROUP snd.
SELECTION-SCREEN COMMENT 4(55) c_mwarn FOR FIELD r_mwarn.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS r_merr RADIOBUTTON GROUP snd.
SELECTION-SCREEN COMMENT 4(55) c_merr FOR FIELD r_merr.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN SKIP 1.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_mimm AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(55) c_mimm FOR FIELD p_mimm.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_when.
SELECTION-SCREEN END OF SCREEN 103.

*--- Pantalla 1000: las dos pestanas -----------------------------------*
SELECTION-SCREEN BEGIN OF TABBED BLOCK tabs FOR 26 LINES.
SELECTION-SCREEN TAB (20) tab1 USER-COMMAND tab1 DEFAULT SCREEN 101.
SELECTION-SCREEN TAB (20) tab2 USER-COMMAND tab2 DEFAULT SCREEN 102.
SELECTION-SCREEN TAB (20) tab3 USER-COMMAND tab3 DEFAULT SCREEN 103.
SELECTION-SCREEN END OF BLOCK tabs.


*----------------------------------------------------------------------*
* Tipos y datos globales
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_result,
         seq        TYPE n LENGTH 2,          "orden del chequeo
         rowno      TYPE n LENGTH 4,          "orden de insercion
         icon       TYPE c LENGTH 40,         "semaforo
         tcode      TYPE c LENGTH 12,         "transaccion
         checkdesc  TYPE c LENGTH 30,         "nombre del chequeo
         status_txt TYPE c LENGTH 12,         "estado legible
         summary    TYPE c LENGTH 100,
         detail     TYPE c LENGTH 255,
         control    TYPE c LENGTH 15,         "interno
         status     TYPE c LENGTH 10,         "interno
         cellcolor  TYPE slis_t_specialcol_alv,
       END OF ty_result.

TYPES: ty_text   TYPE c LENGTH 255,
       ty_t_text TYPE STANDARD TABLE OF ty_text WITH DEFAULT KEY.

TYPES: BEGIN OF ty_wp,
         server TYPE msxxlist-name,
         info   TYPE wpinfo,
       END OF ty_wp,
       ty_t_wp TYPE STANDARD TABLE OF ty_wp WITH DEFAULT KEY.

CONSTANTS: gc_ok   TYPE c LENGTH 10 VALUE 'OK',
           gc_warn TYPE c LENGTH 10 VALUE 'WARNING',
           gc_err  TYPE c LENGTH 10 VALUE 'ERROR',
           gc_inc  TYPE c LENGTH 10 VALUE 'INCOMPLETO'.

DATA: gt_result   TYPE STANDARD TABLE OF ty_result,
      gt_fieldcat TYPE slis_t_fieldcat_alv,
      gs_layout   TYPE slis_layout_alv,
      gt_sort     TYPE slis_t_sortinfo_alv,
      gv_global   TYPE c LENGTH 10,
      gv_rowno    TYPE i,
      gv_cnt_err  TYPE i,
      gv_cnt_warn TYPE i,
      gv_cnt_inc  TYPE i,
      gv_cnt_ok   TYPE i.

DATA: gt_servers   TYPE STANDARD TABLE OF msxxlist,
      gt_wp        TYPE ty_t_wp,
      gt_wperr     TYPE ty_t_text,
      gv_local_srv TYPE msxxlist-name,   "instancia donde corre el Z
      gv_own_wp    TYPE i VALUE -1.      "WP propio (-1 = desconocido)

*----------------------------------------------------------------------*
*----------------------------------------------------------------------*
INITIALIZATION.
*----------------------------------------------------------------------*
* Pestanas
  tab1 = 'Chequeos'.
  tab2 = 'Parametros'.
  tab3 = 'Envio por mail'.
  tabs-prog      = sy-repid.
  tabs-dynnr     = 101.
  tabs-activetab = 'TAB1'.

* Pestana Chequeos
  t_chk  = 'Chequeos a ejecutar'.
  k_sick = 'SICK'.     d_sick = 'Consistencia del sistema'.
  k_st22 = 'ST22'.     d_st22 = 'Dumps'.
  k_sm12 = 'SM12'.     d_sm12 = 'Bloqueos'.
  k_sm13 = 'SM13'.     d_sm13 = 'Actualizaciones (update)'.
  k_sm50 = 'SM50'.     d_sm50 = 'Work processes (estado y capacidad)'.
  k_rtcc = 'RTCCTOOL'. d_rtcc = 'Herramientas de servicio'.
  k_cert = 'STRUST'.   d_cert = 'Vencimiento de certificados'.
  k_st03 = 'ST03N'.    d_st03 = 'Tiempos de respuesta Dialog / RFC'.
  k_smlg = 'SMLG'.     d_smlg = 'Tiempo de respuesta por instancia'.
  k_scot = 'SCOT'.     d_scot = 'SAPconnect (correo)'.
  k_lic  = 'SLICENSE'. d_lic  = 'Vencimiento de licencia SAP'.
  b_all  = 'Marcar todos'.
  b_none = 'Desmarcar todos'.

* Pestana Parametros
  t_st22  = 'Dumps (ST22)'.
  c_dmpdt = 'Buscar dumps desde (fecha/hora)'.
  u_dmpdt = 'vacio = ult. 24h'.

  t_lock  = 'Bloqueos y actualizaciones (SM12 / SM13)'.
  c_lockh = 'Bloqueo: avisar si supera'.
  u_lockh = 'horas'.
  c_allcl = 'Revisar todos los mandantes'.
  c_vbmin = 'Update pendiente: avisar tras'.
  u_vbmin = 'minutos'.

  t_wp    = 'Work processes (SM50)'.
  c_holdm = 'Informar WP en HOLD despues de'.
  u_holdm = 'minutos'.
  c_hwait = 'Espera para confirmar el HOLD'.
  u_hwait = 'segundos (2da. muestra)'.

  t_cert  = 'Certificados (STRUST)'.
  c_cdias = 'Avisar vencimientos dentro de'.
  u_cdias = 'dias'.

  t_perf  = 'Tiempos de respuesta (SMLG / ST03N)'.
  c_rtlim = 'Tiempo de respuesta maximo'.
  u_rtlim = 'ms (SMLG)'.
  c_rtdiv = 'Divisor de tiempos ST03N'.
  u_rtdiv = 'dejar en 1 (viene en ms)'.

  t_lic   = 'Licencia SAP (SLICENSE)'.
  c_ldias = 'Avisar vencimientos dentro de'.
  u_ldias = 'dias'.

* Pestana Envio por mail
  t_mail  = 'Envio del reporte por mail'.
  c_mail  = 'Enviar el reporte por mail al terminar'.
  c_mto   = 'Para (una o varias direcciones)'.
  c_mcc   = 'Con copia (CC)'.
  c_mfrom = 'Remitente (vacio = usuario)'.
  c_msubj = 'Asunto (vacio = automatico)'.
  c_mnote = 'Requiere SAPconnect (SCOT) configurado. El estado se agrega al asunto.'.
  t_when  = 'Cuando enviar'.
  c_mall  = 'Siempre'.
  c_mwarn = 'Solo si hay errores, advertencias o incompletos'.
  c_merr  = 'Solo si hay errores'.
  c_mimm  = 'Envio inmediato (sin esperar el job de SCOT)'.

* ST22: por defecto, ultimas 24 h. Se puede cambiar y guardar en una
* variante (con variable de seleccion de fecha si se usa en un job).
  p_dmpdt = sy-datum - 1.
  p_dmptm = sy-uzeit.

*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
*----------------------------------------------------------------------*
  CASE sscrfields-ucomm.
    WHEN 'SALL'.
      PERFORM set_all_checks USING 'X'.
    WHEN 'SNONE'.
      PERFORM set_all_checks USING ' '.
    WHEN 'ONLI' OR 'PRIN' OR 'SJOB'.
      IF x_sick IS INITIAL AND x_st22 IS INITIAL AND x_sm12 IS INITIAL
         AND x_sm13 IS INITIAL AND x_sm50 IS INITIAL AND x_rtcc IS INITIAL
         AND x_cert IS INITIAL AND x_st03 IS INITIAL AND x_smlg IS INITIAL
         AND x_scot IS INITIAL AND p_lic IS INITIAL.
        MESSAGE 'Seleccione al menos un chequeo (pestana Chequeos)' TYPE 'E'.
      ENDIF.
      IF p_mail = 'X' AND s_mto[] IS INITIAL.
        MESSAGE 'Indique al menos un destinatario (pestana Envio por mail)' TYPE 'E'.
      ENDIF.
  ENDCASE.

*----------------------------------------------------------------------*
START-OF-SELECTION.
*----------------------------------------------------------------------*
  PERFORM read_servers.
  PERFORM read_wpinfo.

  IF x_sick = 'X'. PERFORM check_sick.         ENDIF.
  IF x_st22 = 'X'. PERFORM check_st22.         ENDIF.
  IF x_sm12 = 'X'. PERFORM check_sm12.         ENDIF.
  IF x_sm13 = 'X'. PERFORM check_sm13.         ENDIF.
  IF x_sm50 = 'X'.
    PERFORM check_sm50.
    PERFORM check_wp_capacity.
  ENDIF.
  IF x_rtcc = 'X'. PERFORM check_rtcctool.     ENDIF.
  IF x_cert = 'X'. PERFORM check_certificates. ENDIF.
  IF x_st03 = 'X'. PERFORM check_st03n.        ENDIF.
  IF x_smlg = 'X'. PERFORM check_smlg.         ENDIF.
  IF x_scot = 'X'. PERFORM check_scot.         ENDIF.
  IF p_lic  = 'X'. PERFORM check_license.      ENDIF.

  PERFORM calculate_global.
  IF p_mail = 'X'.
    PERFORM send_mail.
    PERFORM calculate_global.         "incluye el resultado del envio
  ENDIF.
  PERFORM build_fieldcat.
  PERFORM display_report.

*----------------------------------------------------------------------*
* Marcar / desmarcar todos los chequeos
*----------------------------------------------------------------------*
FORM set_all_checks USING p_value TYPE c.
  x_sick = p_value.
  x_st22 = p_value.
  x_sm12 = p_value.
  x_sm13 = p_value.
  x_sm50 = p_value.
  x_rtcc = p_value.
  x_cert = p_value.
  x_st03 = p_value.
  x_smlg = p_value.
  x_scot = p_value.
  p_lic  = p_value.
ENDFORM.

*======================================================================*
* Utilidades generales
*======================================================================*
FORM add_result USING p_control TYPE any
                      p_status  TYPE any
                      p_summary TYPE any
                      p_detail  TYPE any.
  DATA: ls_res  TYPE ty_result,
        ls_col  TYPE slis_specialcol_alv,
        lv_icon TYPE c LENGTH 4.

  ls_res-control = p_control.
  ls_res-status  = p_status.
  ls_res-summary = p_summary.
  ls_res-detail  = p_detail.
  CONDENSE ls_res-summary.

  gv_rowno = gv_rowno + 1.
  ls_res-rowno = gv_rowno.

* Transaccion y nombre del chequeo para mostrar
  CASE ls_res-control.
    WHEN 'SICK'.
      ls_res-seq = 1.   ls_res-tcode = 'SICK'.     ls_res-checkdesc = 'Consistencia del sistema'.
    WHEN 'ST22'.
      ls_res-seq = 2.   ls_res-tcode = 'ST22'.     ls_res-checkdesc = 'Dumps (ABAP runtime errors)'.
    WHEN 'SM12'.
      ls_res-seq = 3.   ls_res-tcode = 'SM12'.     ls_res-checkdesc = 'Bloqueos'.
    WHEN 'SM13'.
      ls_res-seq = 4.   ls_res-tcode = 'SM13'.     ls_res-checkdesc = 'Actualizaciones (update)'.
    WHEN 'SM50'.
      ls_res-seq = 5.   ls_res-tcode = 'SM50'.     ls_res-checkdesc = 'Estado de work processes'.
    WHEN 'SM50 WP'.
      ls_res-seq = 6.   ls_res-tcode = 'SM50'.     ls_res-checkdesc = 'Capacidad de work processes'.
    WHEN 'RTCCTOOL'.
      ls_res-seq = 7.   ls_res-tcode = 'RTCCTOOL'. ls_res-checkdesc = 'Herramientas de servicio'.
    WHEN 'CERTIFICADOS'.
      ls_res-seq = 8.   ls_res-tcode = 'STRUST'.   ls_res-checkdesc = 'Vencimiento de certificados'.
    WHEN 'ST03N DIALOG'.
      ls_res-seq = 9.   ls_res-tcode = 'ST03N'.    ls_res-checkdesc = 'Tiempo resp. Dialog (dia hab.)'.
    WHEN 'ST03N RFC'.
      ls_res-seq = 10.  ls_res-tcode = 'ST03N'.    ls_res-checkdesc = 'Tiempo resp. RFC (dia hab.)'.
    WHEN 'ST03N'.
      ls_res-seq = 9.   ls_res-tcode = 'ST03N'.    ls_res-checkdesc = 'Tiempos resp. (dia habil ant.)'.
    WHEN 'SMLG'.
      ls_res-seq = 11.  ls_res-tcode = 'SMLG'.     ls_res-checkdesc = 'Tiempo resp. por instancia'.
    WHEN 'SCOT'.
      ls_res-seq = 12.  ls_res-tcode = 'SCOT'.     ls_res-checkdesc = 'SAPconnect (correo)'.
    WHEN 'SLICENSE'.
      ls_res-seq = 13.  ls_res-tcode = 'SLICENSE'. ls_res-checkdesc = 'Licencia SAP'.
    WHEN 'MAIL'.
      ls_res-seq = 14.  ls_res-tcode = 'SOST'.     ls_res-checkdesc = 'Envio del reporte por mail'.
    WHEN OTHERS.
      ls_res-seq = 99. ls_res-tcode = ls_res-control. ls_res-checkdesc = ls_res-control.
  ENDCASE.

* Semaforo, texto y color de la celda de estado
  CASE ls_res-status.
    WHEN gc_ok.
      ls_res-status_txt = 'OK'.          lv_icon = icon_green_light.  ls_col-color-col = 5.
    WHEN gc_warn.
      ls_res-status_txt = 'Advertencia'. lv_icon = icon_yellow_light. ls_col-color-col = 3.
    WHEN gc_err.
      ls_res-status_txt = 'Error'.       lv_icon = icon_red_light.    ls_col-color-col = 6.
    WHEN OTHERS.
      ls_res-status_txt = 'Incompleto'.  lv_icon = icon_information.  ls_col-color-col = 7.
  ENDCASE.
* Icono con texto al pasar el mouse: @xx\QTexto@
  CONCATENATE lv_icon(3) '\Q' ls_res-status_txt '@' INTO ls_res-icon.

  ls_col-fieldname = 'STATUS_TXT'.
  ls_col-color-int = 0.
  APPEND ls_col TO ls_res-cellcolor.

  APPEND ls_res TO gt_result.
ENDFORM.

*----------------------------------------------------------------------*
* Ejecuta un report con SUBMIT y devuelve su lista en texto
*----------------------------------------------------------------------*
FORM submit_list USING    p_prog  TYPE any
                 CHANGING pt_lines TYPE ty_t_text
                          p_ok     TYPE c
                          p_msg    TYPE c.
  DATA: lv_prog  TYPE trdir-name,
        lv_subc  TYPE trdir-subc,
        lv_rc    TYPE sy-subrc,
        lt_list  TYPE STANDARD TABLE OF abaplist,
        lx_root  TYPE REF TO cx_root,
        lv_text  TYPE string.

  REFRESH pt_lines.
  CLEAR: p_ok, p_msg.
  lv_prog = p_prog.

  SELECT SINGLE subc FROM trdir INTO lv_subc WHERE name = lv_prog.
  IF sy-subrc <> 0.
    p_msg = |El programa { lv_prog } no existe en el sistema|.
    RETURN.
  ENDIF.
  IF lv_subc <> '1'.
    p_msg = |{ lv_prog } no es un report ejecutable (tipo { lv_subc })|.
    RETURN.
  ENDIF.

  TRY.
      SUBMIT (lv_prog) EXPORTING LIST TO MEMORY AND RETURN.
    CATCH cx_root INTO lx_root.
      lv_text = lx_root->get_text( ).
      p_msg = lv_text.
      RETURN.
  ENDTRY.

  CALL FUNCTION 'LIST_FROM_MEMORY'
    TABLES
      listobject = lt_list
    EXCEPTIONS
      not_found  = 1
      OTHERS     = 2.
  IF sy-subrc <> 0.
    p_msg = |{ lv_prog } no genero salida de lista|.
    RETURN.
  ENDIF.

  CALL FUNCTION 'LIST_TO_ASCI'
    TABLES
      listasci           = pt_lines
      listobject         = lt_list
    EXCEPTIONS
      empty_list         = 1
      list_index_invalid = 2
      OTHERS             = 3.
  lv_rc = sy-subrc.

  CALL FUNCTION 'LIST_FREE_MEMORY'
    TABLES
      listobject = lt_list.

  IF lv_rc <> 0.
    p_msg = |No se pudo convertir la lista de { lv_prog } (rc { lv_rc })|.
    RETURN.
  ENDIF.

  FIELD-SYMBOLS <lv_l> TYPE ty_text.
  LOOP AT pt_lines ASSIGNING <lv_l>.
    TRANSLATE <lv_l> USING '| '.                 "quitar marcos de la lista
  ENDLOOP.
  DELETE pt_lines WHERE table_line IS INITIAL.
  p_ok = 'X'.
ENDFORM.

*----------------------------------------------------------------------*
* Llamadas dinamicas a FMs (tipos leidos de FUPARAREF)
*----------------------------------------------------------------------*
FORM fm_exists USING p_fm TYPE any CHANGING p_exists TYPE c.
  DATA lv_fm TYPE tfdir-funcname.

  CLEAR p_exists.
  lv_fm = p_fm.
  SELECT SINGLE funcname FROM tfdir INTO lv_fm WHERE funcname = lv_fm.
  IF sy-subrc = 0.
    p_exists = 'X'.
  ENDIF.
ENDFORM.

FORM fm_param USING    p_fm      TYPE any
                       p_param   TYPE any
                       p_default TYPE any
              CHANGING pt_ptab   TYPE abap_func_parmbind_tab
                       pr_data   TYPE REF TO data
                       p_found   TYPE c.
  DATA: lv_fm       TYPE fupararef-funcname,
        lv_par      TYPE fupararef-parameter,
        lv_kind     TYPE fupararef-paramtype,
        lv_type     TYPE fupararef-structure,
        lv_typename TYPE string,
        ls_bind     TYPE abap_func_parmbind.

  CLEAR: p_found, pr_data.
  lv_fm  = p_fm.
  lv_par = p_param.

  SELECT SINGLE paramtype structure FROM fupararef
    INTO (lv_kind, lv_type)
    WHERE funcname  = lv_fm
      AND r3state   = 'A'
      AND parameter = lv_par.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  lv_typename = lv_type.
  TRY.
      IF lv_kind = 'T'.
        CREATE DATA pr_data TYPE STANDARD TABLE OF (lv_typename).
      ELSE.
        CREATE DATA pr_data TYPE (lv_typename).
      ENDIF.
    CATCH cx_sy_create_data_error.
      lv_typename = p_default.
      TRY.
          IF lv_kind = 'T'.
            CREATE DATA pr_data TYPE STANDARD TABLE OF (lv_typename).
          ELSE.
            CREATE DATA pr_data TYPE (lv_typename).
          ENDIF.
        CATCH cx_sy_create_data_error.
          CLEAR pr_data.
      ENDTRY.
  ENDTRY.

  IF pr_data IS NOT BOUND.
    RETURN.
  ENDIF.

  ls_bind-name = lv_par.
  CASE lv_kind.
    WHEN 'I'. ls_bind-kind = abap_func_exporting.
    WHEN 'E'. ls_bind-kind = abap_func_importing.
    WHEN 'C'. ls_bind-kind = abap_func_changing.
    WHEN 'T'. ls_bind-kind = abap_func_tables.
    WHEN OTHERS.
      RETURN.
  ENDCASE.
  ls_bind-value = pr_data.
  INSERT ls_bind INTO TABLE pt_ptab.
  p_found = 'X'.
ENDFORM.

FORM fm_set USING    p_fm    TYPE any
                     p_param TYPE any
                     p_value TYPE any
            CHANGING pt_ptab TYPE abap_func_parmbind_tab
                     p_found TYPE c.
  DATA lr_data TYPE REF TO data.
  FIELD-SYMBOLS <lv_val> TYPE any.

  PERFORM fm_param USING p_fm p_param 'STRING'
                   CHANGING pt_ptab lr_data p_found.
  IF p_found = 'X'.
    ASSIGN lr_data->* TO <lv_val>.
    TRY.
        <lv_val> = p_value.
      CATCH cx_root.                                     "#EC NO_HANDLER
    ENDTRY.
  ENDIF.
ENDFORM.

FORM fm_call USING    p_fm    TYPE any
             CHANGING pt_ptab TYPE abap_func_parmbind_tab
                      p_subrc TYPE i
                      p_msg   TYPE c.
  DATA: lt_exc  TYPE abap_func_excpbind_tab,
        ls_exc  TYPE abap_func_excpbind,
        lv_fm   TYPE rs38l_fnam,
        lx_root TYPE REF TO cx_root,
        lv_text TYPE string.

  lv_fm = p_fm.
  CLEAR: p_msg, sy-msgid.

  ls_exc-name  = 'ERROR_MESSAGE'.
  ls_exc-value = 98.
  INSERT ls_exc INTO TABLE lt_exc.
  ls_exc-name  = 'OTHERS'.
  ls_exc-value = 99.
  INSERT ls_exc INTO TABLE lt_exc.

  TRY.
      CALL FUNCTION lv_fm
        PARAMETER-TABLE pt_ptab
        EXCEPTION-TABLE lt_exc.
      p_subrc = sy-subrc.
    CATCH cx_root INTO lx_root.
      p_subrc = 999.
      lv_text = lx_root->get_text( ).
      p_msg = |{ lv_fm }: { lv_text }|.
      RETURN.
  ENDTRY.

  IF p_subrc <> 0.
    IF sy-msgid IS NOT INITIAL.
      MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_text.
      p_msg = |{ lv_fm }: { lv_text }|.
    ELSE.
      p_msg = |{ lv_fm }: excepcion (subrc { p_subrc })|.
    ENDIF.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* Servidores y work processes (usados por SM50, SM13 y SMLG)
*----------------------------------------------------------------------*
FORM read_servers.
  DATA ls_srv TYPE msxxlist.

  CALL FUNCTION 'TH_SERVER_LIST'
    TABLES
      list           = gt_servers
    EXCEPTIONS
      no_server_list = 1
      OTHERS         = 2.
  IF sy-subrc <> 0 OR gt_servers IS INITIAL.
    REFRESH gt_servers.
    CLEAR ls_srv.                      "nombre vacio = instancia local
    APPEND ls_srv TO gt_servers.
  ENDIF.
ENDFORM.

FORM read_wpinfo.
  DATA: ls_srv    TYPE msxxlist,
        lt_wpinfo TYPE STANDARD TABLE OF wpinfo,
        ls_wpinfo TYPE wpinfo,
        ls_wp     TYPE ty_wp,
        lv_text   TYPE ty_text,
        lv_srv    TYPE msxxlist-name,
        ls_rfcsi  TYPE rfcsi,
        lt_ptab   TYPE abap_func_parmbind_tab,
        lr_wpno   TYPE REF TO data,
        lv_found  TYPE c LENGTH 1,
        lv_subrc  TYPE i,
        lv_msg    TYPE c LENGTH 255.

  FIELD-SYMBOLS <lv_wpno> TYPE any.

* Instancia local (donde corre este programa)
  CALL FUNCTION 'RFC_SYSTEM_INFO'
    IMPORTING
      rfcsi_export = ls_rfcsi
    EXCEPTIONS
      OTHERS       = 1.
  IF sy-subrc = 0.
    gv_local_srv = ls_rfcsi-rfcdest.
  ENDIF.

* WP propio: se excluye en SM50 (mientras TH_WPINFO consulta,
* el propio WP figura "On Hold" sin programa ni accion)
  PERFORM fm_param USING 'TH_GET_OWN_WP_NO' 'WP_NO' 'I'
                   CHANGING lt_ptab lr_wpno lv_found.
  IF lv_found = 'X'.
    PERFORM fm_call USING 'TH_GET_OWN_WP_NO'
                    CHANGING lt_ptab lv_subrc lv_msg.
    IF lv_subrc = 0.
      ASSIGN lr_wpno->* TO <lv_wpno>.
      TRY.
          gv_own_wp = <lv_wpno>.
        CATCH cx_root.
          gv_own_wp = -1.
      ENDTRY.
    ENDIF.
  ENDIF.

  PERFORM collect_wp CHANGING gt_wp gt_wperr.
ENDFORM.

*----------------------------------------------------------------------*
* Foto de los WP de todas las instancias
*----------------------------------------------------------------------*
FORM collect_wp CHANGING pt_wp  TYPE ty_t_wp
                         pt_err TYPE ty_t_text.
  DATA: ls_srv    TYPE msxxlist,
        lv_srv    TYPE msxxlist-name,
        lt_wpinfo TYPE STANDARD TABLE OF wpinfo,
        ls_wpinfo TYPE wpinfo,
        ls_wp     TYPE ty_wp,
        lv_text   TYPE ty_text.

  REFRESH: pt_wp, pt_err.

  LOOP AT gt_servers INTO ls_srv.
    REFRESH lt_wpinfo.
*   Instancia local: srvname vacio = lectura directa, sin RFC
    lv_srv = ls_srv-name.
    IF lv_srv = gv_local_srv.
      CLEAR lv_srv.
    ENDIF.
    CALL FUNCTION 'TH_WPINFO'
      EXPORTING
        srvname       = lv_srv
        with_cpu      = '0'
        with_mtx_info = '0'
        max_elems     = 0
      TABLES
        wplist        = lt_wpinfo
      EXCEPTIONS
        send_error    = 1
        OTHERS        = 2.
    IF sy-subrc <> 0.
      lv_text = |No se pudieron leer los WP de { ls_srv-name } (TH_WPINFO rc { sy-subrc })|.
      APPEND lv_text TO pt_err.
      CONTINUE.
    ENDIF.
    LOOP AT lt_wpinfo INTO ls_wpinfo.
      ls_wp-server = ls_srv-name.
      IF ls_wp-server IS INITIAL.
        ls_wp-server = 'local'.
      ENDIF.
      ls_wp-info = ls_wpinfo.
      APPEND ls_wp TO pt_wp.
    ENDLOOP.
  ENDLOOP.
ENDFORM.

*----------------------------------------------------------------------*
* Workload desde el colector ST03N (SWNC)
*  p_comp = 'TOTAL' o nombre de instancia
*  Promedio = RESPTI / DCOUNT  (Tiempo resp. medio / paso dialogo, ms)
*----------------------------------------------------------------------*
FORM get_workload USING    p_comp    TYPE any
                           p_date    TYPE d
                  CHANGING p_dia_cnt TYPE p
                           p_dia_avg TYPE p
                           p_rfc_cnt TYPE p
                           p_rfc_avg TYPE p
                           p_ok      TYPE c
                           p_msg     TYPE c.
  CONSTANTS: lc_fm  TYPE c LENGTH 30 VALUE 'SWNC_COLLECTOR_GET_AGGREGATES',
             lc_dia TYPE x LENGTH 1 VALUE '01',
             lc_rfc TYPE x LENGTH 1 VALUE 'FE'.

  DATA: lt_ptab   TYPE abap_func_parmbind_tab,
        lr_tt     TYPE REF TO data,
        lv_found  TYPE c LENGTH 1,
        lv_subrc  TYPE i,
        lv_dia_rt TYPE p LENGTH 16 DECIMALS 2,
        lv_rfc_rt TYPE p LENGTH 16 DECIMALS 2,
        lv_steps  TYPE p LENGTH 16 DECIMALS 0,
        lv_div    TYPE i.

  FIELD-SYMBOLS: <lt_tt>   TYPE ANY TABLE,
                 <ls_row>  TYPE any,
                 <lv_type> TYPE any,
                 <lv_cnt>  TYPE any,
                 <lv_dcnt> TYPE any,
                 <lv_resp> TYPE any.

  CLEAR: p_dia_cnt, p_dia_avg, p_rfc_cnt, p_rfc_avg, p_ok, p_msg.

  PERFORM fm_exists USING lc_fm CHANGING lv_found.
  IF lv_found IS INITIAL.
    p_msg = |No existe el FM { lc_fm }|.
    RETURN.
  ENDIF.

  PERFORM fm_set USING lc_fm 'COMPONENT'  p_comp    CHANGING lt_ptab lv_found.
  PERFORM fm_set USING lc_fm 'ASSIGNDSYS' sy-sysid  CHANGING lt_ptab lv_found.
  PERFORM fm_set USING lc_fm 'PERIODTYPE' 'D'       CHANGING lt_ptab lv_found.
  PERFORM fm_set USING lc_fm 'PERIODSTRT' p_date    CHANGING lt_ptab lv_found.
  PERFORM fm_param USING lc_fm 'TASKTYPE' 'STRING'
                   CHANGING lt_ptab lr_tt lv_found.
  IF lv_found IS INITIAL.
    p_msg = |{ lc_fm } no tiene el parametro TASKTYPE|.
    RETURN.
  ENDIF.

  PERFORM fm_call USING lc_fm CHANGING lt_ptab lv_subrc p_msg.
  IF lv_subrc <> 0.
    IF lv_subrc = 1.
      p_msg = |Sin datos de workload para { p_comp } el { p_date DATE = USER }|.
    ENDIF.
    RETURN.
  ENDIF.

  ASSIGN lr_tt->* TO <lt_tt>.
  LOOP AT <lt_tt> ASSIGNING <ls_row>.
    ASSIGN COMPONENT 'TASKTYPE' OF STRUCTURE <ls_row> TO <lv_type>.
    IF sy-subrc <> 0.
      p_msg = 'La tabla TASKTYPE no tiene el campo TASKTYPE'.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT 'RESPTI' OF STRUCTURE <ls_row> TO <lv_resp>.
    IF sy-subrc <> 0.
      p_msg = 'La tabla TASKTYPE no tiene el campo RESPTI'.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT 'DCOUNT' OF STRUCTURE <ls_row> TO <lv_dcnt>.
    IF sy-subrc = 0.
      lv_steps = <lv_dcnt>.
    ELSE.
      ASSIGN COMPONENT 'COUNT' OF STRUCTURE <ls_row> TO <lv_cnt>.
      IF sy-subrc <> 0.
        p_msg = 'La tabla TASKTYPE no tiene DCOUNT ni COUNT'.
        RETURN.
      ENDIF.
      lv_steps = <lv_cnt>.
    ENDIF.

    IF <lv_type> = lc_dia.
      p_dia_cnt = p_dia_cnt + lv_steps.
      lv_dia_rt = lv_dia_rt + <lv_resp>.
    ELSEIF <lv_type> = lc_rfc.
      p_rfc_cnt = p_rfc_cnt + lv_steps.
      lv_rfc_rt = lv_rfc_rt + <lv_resp>.
    ENDIF.
  ENDLOOP.

  lv_div = p_rtdiv.
  IF lv_div <= 0.
    lv_div = 1.
  ENDIF.
  IF p_dia_cnt > 0.
    p_dia_avg = lv_dia_rt / p_dia_cnt / lv_div.
  ENDIF.
  IF p_rfc_cnt > 0.
    p_rfc_avg = lv_rfc_rt / p_rfc_cnt / lv_div.
  ENDIF.

  IF p_dia_cnt = 0 AND p_rfc_cnt = 0.
    p_msg = |Sin pasos Dialog/RFC para { p_comp } el { p_date DATE = USER }|.
    RETURN.
  ENDIF.
  p_ok = 'X'.
ENDFORM.

*======================================================================*
* SICK - consistencia del sistema
*======================================================================*
FORM check_sick.
  DATA: lv_prog   TYPE tstc-pgmna,
        lt_lines  TYPE ty_t_text,
        lv_line   TYPE ty_text,
        lv_ok     TYPE c LENGTH 1,
        lv_msg    TYPE c LENGTH 255,
        lv_okline TYPE ty_text,
        lv_nerr   TYPE i.

  SELECT SINGLE pgmna FROM tstc INTO lv_prog WHERE tcode = 'SICK'.
  IF sy-subrc <> 0 OR lv_prog IS INITIAL.
    SELECT SINGLE pgmna FROM tstc INTO lv_prog WHERE tcode = 'SM28'.
  ENDIF.
  IF lv_prog IS INITIAL.
    PERFORM add_result USING 'SICK' gc_inc
      'No se encontro el programa de SICK/SM28' 'Revisar SE93'.
    RETURN.
  ENDIF.

  PERFORM submit_list USING lv_prog CHANGING lt_lines lv_ok lv_msg.
  IF lv_ok IS INITIAL.
    PERFORM add_result USING 'SICK' gc_inc
      'No se pudo ejecutar el chequeo' lv_msg.
    RETURN.
  ENDIF.

  LOOP AT lt_lines INTO lv_line.
    IF lv_line CS 'NO ERROR' OR lv_line CS 'SIN ERROR'
       OR lv_line CS 'NINGUN ERROR'.
      lv_okline = lv_line.
    ELSEIF lv_line CS 'ERROR'.
      lv_nerr = lv_nerr + 1.
      IF lv_nerr <= 10.
        CONDENSE lv_line.
        PERFORM add_result USING 'SICK' gc_err
          'Error de consistencia' lv_line.
      ENDIF.
    ENDIF.
  ENDLOOP.

  IF lv_nerr > 0.
    RETURN.
  ENDIF.

  IF lv_okline IS NOT INITIAL.
    CONDENSE lv_okline.
    PERFORM add_result USING 'SICK' gc_ok
      'Sistema consistente' lv_okline.
  ELSE.
    READ TABLE lt_lines INTO lv_line INDEX 1.
    CONDENSE lv_line.
    PERFORM add_result USING 'SICK' gc_inc
      'No se pudo interpretar la salida de SICK' lv_line.
  ENDIF.
ENDFORM.

*======================================================================*
* ST22 - dumps desde la fecha/hora de P_DMPDT/P_DMPTM, por instancia
*  (si P_DMPDT esta vacio: ultimas 24 h)
*  Se lee la cabecera de cada dump (SNAP_BEG, o SNAP con SEQNO = '000'). El nombre del error sale de FLIST, que es una
*  lista de campos con formato ID(2) + LARGO(3) + VALOR; el error es 'FC'.
*======================================================================*
FORM check_st22.
  TYPES: BEGIN OF ty_snap,
           datum TYPE d,
           uzeit TYPE t,
           ahost TYPE c LENGTH 40,
           uname TYPE c LENGTH 12,
           mandt TYPE c LENGTH 3,
           seqno TYPE c LENGTH 3,
           flist TYPE c LENGTH 200,
         END OF ty_snap.
  TYPES: BEGIN OF ty_err,
           inst  TYPE c LENGTH 40,
           errid TYPE c LENGTH 40,
           cnt   TYPE i,
         END OF ty_err.
  TYPES: BEGIN OF ty_inst,
           inst  TYPE c LENGTH 40,
           cnt   TYPE i,
           ldate TYPE d,
           ltime TYPE t,
           luser TYPE c LENGTH 12,
           lerr  TYPE c LENGTH 40,
         END OF ty_inst.

  DATA: lt_snap  TYPE STANDARD TABLE OF ty_snap,
        ls_snap  TYPE ty_snap,
        lt_err   TYPE STANDARD TABLE OF ty_err,
        ls_err   TYPE ty_err,
        lt_inst  TYPE STANDARD TABLE OF ty_inst,
        ls_inst  TYPE ty_inst,
        ls_srv   TYPE msxxlist,
        lv_tab   TYPE c LENGTH 30,
        lv_ok    TYPE c LENGTH 1,
        lv_from  TYPE d,
        lv_ftime TYPE t,
        lv_errid TYPE c LENGTH 40,
        lv_pos   TYPE i,
        lv_p2    TYPE i,
        lv_p5    TYPE i,
        lv_len   TYPE i,
        lv_lenc  TYPE c LENGTH 3,
        lv_id    TYPE c LENGTH 2,
        lv_total TYPE i,
        lv_errs  TYPE string,
        lv_text  TYPE string,
        lv_sum   TYPE string,
        lv_det   TYPE string,
        lv_stat  TYPE c LENGTH 10,
        lx_root  TYPE REF TO cx_root.

  FIELD-SYMBOLS <ls_inst> TYPE ty_inst.

  IF p_dmpdt IS INITIAL.
    lv_from  = sy-datum - 1.
    lv_ftime = sy-uzeit.
  ELSE.
    lv_from  = p_dmpdt.
    lv_ftime = p_dmptm.
  ENDIF.

* 1) Cabeceras de dumps desde ayer (SNAP es independiente de mandante)
  lv_tab = 'SNAP_BEG'.
  TRY.
      SELECT * FROM (lv_tab)
        INTO CORRESPONDING FIELDS OF TABLE lt_snap
        WHERE datum >= lv_from.
      lv_ok = 'X'.
    CATCH cx_root.                                       "#EC NO_HANDLER
  ENDTRY.
  IF lv_ok IS INITIAL.
    lv_tab = 'SNAP'.
    TRY.
        SELECT * FROM (lv_tab)
          INTO CORRESPONDING FIELDS OF TABLE lt_snap
          WHERE datum >= lv_from
            AND seqno = '000'.
        lv_ok = 'X'.
      CATCH cx_root INTO lx_root.
        lv_text = lx_root->get_text( ).
    ENDTRY.
  ENDIF.
  IF lv_ok IS INITIAL.
    PERFORM add_result USING 'ST22' gc_inc
      'No se pudieron leer los dumps (SNAP)' lv_text.
    RETURN.
  ENDIF.

* 2) Ultimas 24 h y agrupacion por instancia / error
  SORT lt_snap BY datum uzeit.
  LOOP AT lt_snap INTO ls_snap.
    IF ls_snap-datum < lv_from
       OR ( ls_snap-datum = lv_from AND ls_snap-uzeit < lv_ftime ).
      CONTINUE.
    ENDIF.
    IF ls_snap-seqno IS NOT INITIAL AND ls_snap-seqno <> '000'.
      CONTINUE.
    ENDIF.
    lv_total = lv_total + 1.

*   Nombre del error (campo 'FC' de FLIST)
    CLEAR: lv_errid, lv_pos.
    DO 30 TIMES.
      lv_p2 = lv_pos + 2.
      lv_p5 = lv_pos + 5.
      IF lv_p5 > 200.
        EXIT.
      ENDIF.
      lv_id   = ls_snap-flist+lv_pos(2).
      lv_lenc = ls_snap-flist+lv_p2(3).
      IF lv_lenc CN '0123456789'.
        EXIT.
      ENDIF.
      lv_len = lv_lenc.
      IF lv_len <= 0 OR lv_p5 + lv_len > 200.
        EXIT.
      ENDIF.
      IF lv_id = 'FC'.
        lv_errid = ls_snap-flist+lv_p5(lv_len).
        EXIT.
      ENDIF.
      lv_pos = lv_p5 + lv_len.
    ENDDO.
    IF lv_errid IS INITIAL.
      lv_errid = '(sin nombre)'.
    ENDIF.

    CLEAR ls_err.
    ls_err-inst  = ls_snap-ahost.
    ls_err-errid = lv_errid.
    ls_err-cnt   = 1.
    COLLECT ls_err INTO lt_err.

    READ TABLE lt_inst ASSIGNING <ls_inst> WITH KEY inst = ls_snap-ahost.
    IF sy-subrc <> 0.
      CLEAR ls_inst.
      ls_inst-inst = ls_snap-ahost.
      APPEND ls_inst TO lt_inst ASSIGNING <ls_inst>.
    ENDIF.
    <ls_inst>-cnt   = <ls_inst>-cnt + 1.
    <ls_inst>-ldate = ls_snap-datum.          "queda el mas reciente
    <ls_inst>-ltime = ls_snap-uzeit.
    <ls_inst>-luser = ls_snap-uname.
    <ls_inst>-lerr  = lv_errid.
  ENDLOOP.

* Instancias activas sin dumps tambien se muestran
  LOOP AT gt_servers INTO ls_srv WHERE name IS NOT INITIAL.
    READ TABLE lt_inst TRANSPORTING NO FIELDS WITH KEY inst = ls_srv-name.
    IF sy-subrc <> 0.
      CLEAR ls_inst.
      ls_inst-inst = ls_srv-name.
      APPEND ls_inst TO lt_inst.
    ENDIF.
  ENDLOOP.

* 3) Resumen
  IF lv_total = 0.
    lv_stat = gc_ok.
  ELSE.
    lv_stat = gc_warn.
  ENDIF.
  lv_sum = |{ lv_total } dump(s) desde { lv_from DATE = USER } { lv_ftime TIME = USER }|.
  lv_det = |Periodo: { lv_from DATE = USER } { lv_ftime TIME = USER } a | &&
           |{ sy-datum DATE = USER } { sy-uzeit TIME = USER }|.
  PERFORM add_result USING 'ST22' lv_stat lv_sum lv_det.

* 4) Una fila por instancia
  SORT lt_inst BY inst.
  SORT lt_err BY inst ASCENDING cnt DESCENDING errid ASCENDING.
  LOOP AT lt_inst INTO ls_inst.
    IF ls_inst-inst IS INITIAL.
      ls_inst-inst = '(sin instancia)'.
    ENDIF.
    IF ls_inst-cnt = 0.
      lv_sum = |{ ls_inst-inst }: sin dumps|.
      PERFORM add_result USING 'ST22' gc_ok lv_sum ''.
      CONTINUE.
    ENDIF.

    CLEAR lv_errs.
    LOOP AT lt_err INTO ls_err WHERE inst = ls_inst-inst.
      IF lv_errs IS INITIAL.
        lv_errs = |{ ls_err-errid } ({ ls_err-cnt })|.
      ELSE.
        lv_errs = |{ lv_errs }, { ls_err-errid } ({ ls_err-cnt })|.
      ENDIF.
    ENDLOOP.

    lv_sum = |{ ls_inst-inst }: { ls_inst-cnt } dump(s)|.
    lv_det = |{ lv_errs } - Ultimo: { ls_inst-ldate DATE = USER } | &&
             |{ ls_inst-ltime TIME = USER } { ls_inst-luser } ({ ls_inst-lerr })|.
    PERFORM add_result USING 'ST22' gc_warn lv_sum lv_det.
  ENDLOOP.
ENDFORM.

*======================================================================*
* SM12 - bloqueos con antiguedad mayor a p_lockh horas
*======================================================================*
FORM check_sm12.
  TYPES: BEGIN OF ty_lock,
           client TYPE mandt,
           age    TYPE i,
           enq    TYPE seqg3,
         END OF ty_lock.

  DATA: lt_clients TYPE STANDARD TABLE OF mandt,
        lv_client  TYPE mandt,
        lt_enq     TYPE STANDARD TABLE OF seqg3,
        ls_enq     TYPE seqg3,
        lv_fmrc    TYPE sy-subrc,
        lv_age     TYPE i,
        lv_hours   TYPE i,
        lv_total   TYPE i,
        lv_old     TYPE i,
        lv_nodate  TYPE i,
        lv_sum     TYPE string,
        lv_det     TYPE string,
        lv_n       TYPE i,
        lv_mins    TYPE i,
        lv_mode    TYPE c LENGTH 1,
        lv_tcode   TYPE c LENGTH 20,
        lv_status  TYPE c LENGTH 10,
        lt_lock    TYPE STANDARD TABLE OF ty_lock,
        ls_lock    TYPE ty_lock.

  FIELD-SYMBOLS <lv_fld> TYPE any.

  IF p_allcl = 'X'.
    SELECT mandt FROM t000 INTO TABLE lt_clients.
  ELSE.
    APPEND sy-mandt TO lt_clients.
  ENDIF.

  LOOP AT lt_clients INTO lv_client.
    REFRESH lt_enq.
    CLEAR lv_fmrc.
    CALL FUNCTION 'ENQUEUE_READ'
      EXPORTING
        gclient               = lv_client
        gname                 = space
        garg                  = space
        guname                = space
        local                 = space
        fast                  = space
      IMPORTING
        subrc                 = lv_fmrc
      TABLES
        enq                   = lt_enq
      EXCEPTIONS
        communication_failure = 1
        system_failure        = 2
        OTHERS                = 3.
    IF sy-subrc <> 0 OR lv_fmrc <> 0.
      lv_sum = |Mandante { lv_client }: no se pudieron leer los bloqueos|.
      PERFORM add_result USING 'SM12' gc_inc lv_sum
        'Error al ejecutar ENQUEUE_READ'.
      CONTINUE.
    ENDIF.

    LOOP AT lt_enq INTO ls_enq.
      lv_total = lv_total + 1.
      CLEAR ls_lock.
      ls_lock-client = lv_client.
      ls_lock-enq    = ls_enq.
      IF ls_enq-gtdate IS INITIAL OR ls_enq-gttime IS INITIAL.
        lv_nodate = lv_nodate + 1.
        ls_lock-age = -1.
      ELSE.
        ls_lock-age = ( sy-datum - ls_enq-gtdate ) * 86400
                    + ( sy-uzeit - ls_enq-gttime ).
        IF ls_lock-age > p_lockh * 3600.
          lv_old = lv_old + 1.
        ENDIF.
      ENDIF.
      APPEND ls_lock TO lt_lock.
    ENDLOOP.
  ENDLOOP.

* Resumen primero
  IF lv_old > 0.
    lv_sum = |{ lv_old } bloqueo(s) mayor(es) a { p_lockh } h|.
    lv_det = |{ lv_total } bloqueo(s) activo(s) en total|.
    PERFORM add_result USING 'SM12' gc_err lv_sum lv_det.
  ELSE.
    lv_sum = |Sin bloqueos mayores a { p_lockh } h|.
    lv_det = |{ lv_total } bloqueo(s) activo(s) en total|.
    PERFORM add_result USING 'SM12' gc_ok lv_sum lv_det.
  ENDIF.

* Detalle de cada bloqueo, del mas viejo al mas nuevo (max. 100)
  SORT lt_lock BY age DESCENDING.
  LOOP AT lt_lock INTO ls_lock.
    lv_n = lv_n + 1.
    IF lv_n > 100.
      lv_sum = |{ lv_total } bloqueos: se muestran los 100 mas viejos|.
      PERFORM add_result USING 'SM12' gc_warn lv_sum 'Ver SM12'.
      EXIT.
    ENDIF.

    CLEAR: lv_mode, lv_tcode.
    ASSIGN COMPONENT 'GMODE' OF STRUCTURE ls_lock-enq TO <lv_fld>.
    IF sy-subrc = 0.
      lv_mode = <lv_fld>.
    ENDIF.
    ASSIGN COMPONENT 'GTCODE' OF STRUCTURE ls_lock-enq TO <lv_fld>.
    IF sy-subrc = 0.
      lv_tcode = <lv_fld>.
    ENDIF.

    IF ls_lock-age < 0.
      lv_status = gc_warn.
      lv_sum = |Bloqueo sin fecha/hora (mandante { ls_lock-client })|.
      lv_det = |Usuario: { ls_lock-enq-guname } Tabla: { ls_lock-enq-gname } | &&
               |Argumento: { ls_lock-enq-garg } Modo: { lv_mode } Tx: { lv_tcode }|.
    ELSE.
      IF ls_lock-age > p_lockh * 3600.
        lv_status = gc_err.
      ELSE.
        lv_status = gc_ok.
      ENDIF.
      lv_hours = ls_lock-age DIV 3600.
      lv_mins  = ( ls_lock-age MOD 3600 ) DIV 60.
      lv_sum = |Bloqueo de { lv_hours } h { lv_mins } min (mandante { ls_lock-client })|.
      lv_det = |Usuario: { ls_lock-enq-guname } Tabla: { ls_lock-enq-gname } | &&
               |Argumento: { ls_lock-enq-garg } Modo: { lv_mode } Tx: { lv_tcode } | &&
               |Desde: { ls_lock-enq-gtdate DATE = USER } { ls_lock-enq-gttime TIME = USER }|.
    ENDIF.
    PERFORM add_result USING 'SM12' lv_status lv_sum lv_det.
  ENDLOOP.
ENDFORM.

*======================================================================*
* SM13 - updates activos y sin errores
*  "Activo" = hay WPs UPD y no hay registros pendientes viejos
*  (si el update esta desactivado, los registros se acumulan).
*======================================================================*
FORM check_sm13.
  TYPES: BEGIN OF ty_vberr,
           vbkey     TYPE c LENGTH 32,
           vbmodcnt  TYPE i,
           vbfunc    TYPE c LENGTH 30,
           arbgb     TYPE c LENGTH 20,
           msgnr     TYPE c LENGTH 3,
           varmsgval TYPE c LENGTH 200,
         END OF ty_vberr.
  TYPES: BEGIN OF ty_vbhdr,
           vbkey    TYPE c LENGTH 32,
           vbusr    TYPE c LENGTH 12,
           vbtcode  TYPE c LENGTH 20,
           vbreport TYPE c LENGTH 40,
           vbdate   TYPE c LENGTH 14,
         END OF ty_vbhdr.

  DATA: lt_err    TYPE STANDARD TABLE OF ty_vberr,
        ls_err    TYPE ty_vberr,
        lt_hdr    TYPE STANDARD TABLE OF ty_vbhdr,
        ls_hdr    TYPE ty_vbhdr,
        lt_errkey TYPE SORTED TABLE OF ty_vbhdr-vbkey WITH UNIQUE KEY table_line,
        lv_tab    TYPE c LENGTH 30,
        lx_root   TYPE REF TO cx_root,
        lv_text   TYPE string,
        lv_sum    TYPE string,
        lv_det    TYPE string,
        lv_msgtxt TYPE string,
        lv_nerr   TYPE i,
        lv_upd    TYPE i,
        lv_pend   TYPE i,
        lv_stale  TYPE i,
        lv_nodate TYPE i,
        lv_oldest TYPE i,
        lv_d      TYPE d,
        lv_t      TYPE t,
        lv_ts     TYPE timestamp,
        lv_tz     TYPE tzonref-tzone VALUE 'UTC',
        lv_ud     TYPE d,
        lv_ut     TYPE t,
        lv_age_l  TYPE i,
        lv_age_u  TYPE i,
        lv_age    TYPE i,
        lv_min    TYPE i,
        ls_wp     TYPE ty_wp.

* 1) Work processes de update
  LOOP AT gt_wp INTO ls_wp WHERE info-wp_typ = 'UPD'.
    lv_upd = lv_upd + 1.
  ENDLOOP.
  IF gt_wp IS NOT INITIAL AND lv_upd = 0.
    PERFORM add_result USING 'SM13' gc_err
      'No hay work processes de update (UPD)'
      'Revisar rdisp/wp_no_vb y SM50'.
  ENDIF.

* 2) Errores de update (VBERROR)
  lv_tab = 'VBERROR'.
  TRY.
      SELECT * FROM (lv_tab) INTO CORRESPONDING FIELDS OF TABLE lt_err
        UP TO 500 ROWS.
    CATCH cx_root INTO lx_root.
      lv_text = lx_root->get_text( ).
      PERFORM add_result USING 'SM13' gc_inc
        'No se pudo leer VBERROR' lv_text.
      RETURN.
  ENDTRY.

* 3) Cabeceras de update (VBHDR)
  lv_tab = 'VBHDR'.
  TRY.
      SELECT * FROM (lv_tab) INTO CORRESPONDING FIELDS OF TABLE lt_hdr
        UP TO 2000 ROWS.
    CATCH cx_root INTO lx_root.
      lv_text = lx_root->get_text( ).
      PERFORM add_result USING 'SM13' gc_inc
        'No se pudo leer VBHDR' lv_text.
      RETURN.
  ENDTRY.

  SORT lt_err BY vbkey vbmodcnt.
  LOOP AT lt_err INTO ls_err.
    INSERT ls_err-vbkey INTO TABLE lt_errkey.
    IF sy-subrc <> 0.
      CONTINUE.                          "ya informado este registro
    ENDIF.
    lv_nerr = lv_nerr + 1.
    IF lv_nerr > 20.
      CONTINUE.
    ENDIF.

    CLEAR: ls_hdr, lv_msgtxt.
    READ TABLE lt_hdr INTO ls_hdr WITH KEY vbkey = ls_err-vbkey.

    IF ls_err-arbgb IS NOT INITIAL AND ls_err-msgnr IS NOT INITIAL.
      MESSAGE ID ls_err-arbgb TYPE 'E' NUMBER ls_err-msgnr
        WITH ls_err-varmsgval INTO lv_msgtxt.
    ENDIF.

    lv_sum = |Update con error: usuario { ls_hdr-vbusr } tx { ls_hdr-vbtcode }|.
    lv_det = |Modulo: { ls_err-vbfunc } Msg { ls_err-arbgb }/{ ls_err-msgnr }: | &&
             |{ lv_msgtxt } (clave { ls_err-vbkey })|.
    PERFORM add_result USING 'SM13' gc_err lv_sum lv_det.
  ENDLOOP.

  IF lv_nerr > 20.
    lv_sum = |{ lv_nerr } updates con error en total (se muestran 20)|.
    PERFORM add_result USING 'SM13' gc_err lv_sum 'Ver SM13'.
  ENDIF.

* 4) Pendientes viejos (posible update desactivado o trabado)
*    Se calcula la antiguedad contra hora local y UTC y se toma la menor
*    no negativa, para no depender de en que zona se graba VBDATE.
  GET TIME STAMP FIELD lv_ts.
  CONVERT TIME STAMP lv_ts TIME ZONE lv_tz INTO DATE lv_ud TIME lv_ut.

  LOOP AT lt_hdr INTO ls_hdr.
    READ TABLE lt_errkey WITH TABLE KEY table_line = ls_hdr-vbkey
      TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      CONTINUE.
    ENDIF.
    lv_pend = lv_pend + 1.

    IF ls_hdr-vbdate(8) CO '0123456789' AND ls_hdr-vbdate+8(6) CO '0123456789'.
      lv_d = ls_hdr-vbdate(8).
      lv_t = ls_hdr-vbdate+8(6).
      lv_age_l = ( sy-datum - lv_d ) * 86400 + ( sy-uzeit - lv_t ).
      lv_age_u = ( lv_ud - lv_d ) * 86400 + ( lv_ut - lv_t ).
      IF lv_age_l >= 0 AND lv_age_u >= 0.
        IF lv_age_l < lv_age_u.
          lv_age = lv_age_l.
        ELSE.
          lv_age = lv_age_u.
        ENDIF.
      ELSEIF lv_age_l >= 0.
        lv_age = lv_age_l.
      ELSE.
        lv_age = lv_age_u.
      ENDIF.
      IF lv_age > p_vbmin * 60.
        lv_stale = lv_stale + 1.
        IF lv_age > lv_oldest.
          lv_oldest = lv_age.
        ENDIF.
      ENDIF.
    ELSE.
      lv_nodate = lv_nodate + 1.
    ENDIF.
  ENDLOOP.

  IF lv_stale > 0.
    lv_min = lv_oldest DIV 60.
    lv_sum = |{ lv_stale } update(s) pendiente(s) hace mas de { p_vbmin } min|.
    lv_det = |El mas viejo tiene { lv_min } min. Verificar que el update este activo en SM13|.
    PERFORM add_result USING 'SM13' gc_warn lv_sum lv_det.
  ENDIF.

  IF lv_nerr = 0 AND lv_stale = 0 AND ( lv_upd > 0 OR gt_wp IS INITIAL ).
    lv_sum = 'Updates activos y sin errores'.
    lv_det = |{ lv_upd } WP UPD, { lv_pend } registro(s) pendiente(s) reciente(s)|.
    IF lv_nodate > 0.
      lv_det = |{ lv_det }, { lv_nodate } sin fecha legible|.
    ENDIF.
    PERFORM add_result USING 'SM13' gc_ok lv_sum lv_det.
  ENDIF.
ENDFORM.

*======================================================================*
* SM50 - work processes (todas las instancias)
*======================================================================*
FORM classify_wp USING p_status TYPE c CHANGING p_cat TYPE c.
  IF p_status CS 'STOP' OR p_status CS 'DETEN' OR p_status CS 'PARAD'.
    p_cat = 'STOP'.
  ELSEIF p_status CS 'ENDED' OR p_status CS 'FINALIZ' OR p_status CS 'TERMIN'.
    p_cat = 'END'.
  ELSEIF p_status CS 'HOLD' OR p_status CS 'RETEN'.
    p_cat = 'HOLD'.
  ELSEIF p_status CS 'WAIT' OR p_status CS 'ESPER'.
    p_cat = 'WAIT'.
  ELSEIF p_status CS 'RUN' OR p_status CS 'EJEC'.
    p_cat = 'RUN'.
  ELSE.
    p_cat = 'OTHER'.
  ENDIF.
ENDFORM.

FORM is_own_wp USING ps_wp TYPE ty_wp CHANGING p_own TYPE c.
  DATA lv_wpnum TYPE i.

  CLEAR p_own.
  IF ps_wp-server <> gv_local_srv AND ps_wp-server <> 'local'.
    RETURN.
  ENDIF.
  TRY.
      lv_wpnum = ps_wp-info-wp_no.
    CATCH cx_root.
      lv_wpnum = -2.
  ENDTRY.
  IF gv_own_wp >= 0.
    IF lv_wpnum = gv_own_wp.
      p_own = 'X'.
    ENDIF.
  ELSEIF ps_wp-info-wp_bname = sy-uname
     AND ps_wp-info-wp_report IS INITIAL.
*   Sin TH_GET_OWN_WP_NO: se descarta el WP del usuario que ejecuta
    p_own = 'X'.
  ENDIF.
ENDFORM.

* Tiempo (s) que el WP lleva en el estado/pedido actual (col. Tiempo SM50)
FORM get_wp_field USING    ps_wp   TYPE ty_wp
                           p_field TYPE any
                  CHANGING p_value TYPE any
                           p_found TYPE c.
  FIELD-SYMBOLS <lv_val> TYPE any.

  CLEAR: p_value, p_found.
  ASSIGN COMPONENT p_field OF STRUCTURE ps_wp-info TO <lv_val>.
  IF sy-subrc = 0.
    p_found = 'X'.
    TRY.
        p_value = <lv_val>.
      CATCH cx_root.
        CLEAR p_value.
    ENDTRY.
  ENDIF.
ENDFORM.

FORM wp_detail USING ps_wp TYPE ty_wp p_elt TYPE i CHANGING p_det TYPE string.
  DATA: lv_wpno   TYPE c LENGTH 10,
        lv_reason TYPE c LENGTH 40,
        lv_found  TYPE c LENGTH 1.

  WRITE ps_wp-info-wp_no TO lv_wpno.
  CONDENSE lv_wpno.
  PERFORM get_wp_field USING ps_wp 'WP_WAITING' CHANGING lv_reason lv_found.
  p_det = |Srv: { ps_wp-server } WP: { lv_wpno } Tipo: { ps_wp-info-wp_typ } | &&
          |Estado: { ps_wp-info-wp_status } Motivo: { lv_reason } | &&
          |Usuario: { ps_wp-info-wp_bname } Programa: { ps_wp-info-wp_report } | &&
          |Accion: { ps_wp-info-wp_action } Tiempo: { p_elt } s|.
ENDFORM.

*----------------------------------------------------------------------*
* SM50
*  - Stopped / Ended / otros estados raros: se informan siempre.
*  - HOLD: solo si lleva >= p_holdm minutos en el mismo pedido
*    (columna Tiempo de SM50) y, en una 2da muestra tomada p_hwait
*    segundos despues, sigue en HOLD sin cambios (mismo usuario,
*    programa y proceso, y el tiempo siguio corriendo).
*----------------------------------------------------------------------*
FORM check_sm50.
  TYPES: BEGIN OF ty_cand,
           wp  TYPE ty_wp,
           elt TYPE i,
         END OF ty_cand.

  DATA: ls_wp      TYPE ty_wp,
        ls_wp2     TYPE ty_wp,
        lt_wp2     TYPE ty_t_wp,
        lt_err2    TYPE ty_t_text,
        lt_cand    TYPE STANDARD TABLE OF ty_cand,
        ls_cand    TYPE ty_cand,
        lv_status  TYPE c LENGTH 20,
        lv_cat     TYPE c LENGTH 10,
        lv_own     TYPE c LENGTH 1,
        lv_found   TYPE c LENGTH 1,
        lv_has_elt TYPE c LENGTH 1,
        lv_elt     TYPE i,
        lv_elt2    TYPE i,
        lv_pid     TYPE c LENGTH 20,
        lv_pid2    TYPE c LENGTH 20,
        lv_min     TYPE i,
        lv_tot     TYPE i,
        lv_bad     TYPE i,
        lv_recent  TYPE i,
        lv_gone    TYPE i,
        lv_nsrv    TYPE i,
        lv_text    TYPE ty_text,
        lv_det     TYPE string,
        lv_sum     TYPE string.

  LOOP AT gt_wperr INTO lv_text.
    PERFORM add_result USING 'SM50' gc_inc
      'No se pudieron consultar los procesos' lv_text.
  ENDLOOP.

  IF gt_wp IS INITIAL.
    PERFORM add_result USING 'SM50' gc_inc
      'No se recibieron work processes' 'Verificar TH_WPINFO / SM50'.
    RETURN.
  ENDIF.

* 1ra muestra
  LOOP AT gt_wp INTO ls_wp.
    lv_tot = lv_tot + 1.

    PERFORM is_own_wp USING ls_wp CHANGING lv_own.
    IF lv_own = 'X'.
      CONTINUE.
    ENDIF.

    lv_status = ls_wp-info-wp_status.
    PERFORM classify_wp USING lv_status CHANGING lv_cat.
    IF lv_cat = 'WAIT' OR lv_cat = 'RUN'.
      CONTINUE.
    ENDIF.

    PERFORM get_wp_field USING ls_wp 'WP_ELTIME' CHANGING lv_elt lv_has_elt.

    IF lv_cat = 'HOLD'.
*     Sin columna de tiempo no se puede medir: se valida solo con la
*     2da muestra. Con tiempo, solo pasan los que superan el limite.
      IF lv_has_elt IS INITIAL OR lv_elt >= p_holdm * 60.
        ls_cand-wp  = ls_wp.
        ls_cand-elt = lv_elt.
        APPEND ls_cand TO lt_cand.
      ELSE.
        lv_recent = lv_recent + 1.
      ENDIF.
      CONTINUE.
    ENDIF.

    lv_bad = lv_bad + 1.
    PERFORM wp_detail USING ls_wp lv_elt CHANGING lv_det.
    CASE lv_cat.
      WHEN 'STOP'.
        PERFORM add_result USING 'SM50' gc_err 'Work process detenido (Stopped)' lv_det.
      WHEN 'END'.
        PERFORM add_result USING 'SM50' gc_err 'Work process finalizado (Ended)' lv_det.
      WHEN OTHERS.
        PERFORM add_result USING 'SM50' gc_warn 'Work process en estado no habitual' lv_det.
    ENDCASE.
  ENDLOOP.

* 2da muestra: confirmar que los HOLD largos siguen igual
  IF lt_cand IS NOT INITIAL.
    IF p_hwait > 0.
      WAIT UP TO p_hwait SECONDS.
    ENDIF.
    PERFORM collect_wp CHANGING lt_wp2 lt_err2.

    LOOP AT lt_cand INTO ls_cand.
      READ TABLE lt_wp2 INTO ls_wp2
        WITH KEY server = ls_cand-wp-server
                 info-wp_no = ls_cand-wp-info-wp_no.
      IF sy-subrc <> 0.
        lv_gone = lv_gone + 1.
        CONTINUE.
      ENDIF.

      lv_status = ls_wp2-info-wp_status.
      PERFORM classify_wp USING lv_status CHANGING lv_cat.
      PERFORM get_wp_field USING ls_wp2 'WP_ELTIME' CHANGING lv_elt2 lv_found.
      PERFORM get_wp_field USING ls_cand-wp 'WP_PID' CHANGING lv_pid lv_found.
      PERFORM get_wp_field USING ls_wp2 'WP_PID' CHANGING lv_pid2 lv_found.

      IF lv_cat <> 'HOLD'
         OR ls_wp2-info-wp_bname  <> ls_cand-wp-info-wp_bname
         OR ls_wp2-info-wp_report <> ls_cand-wp-info-wp_report
         OR lv_pid2 <> lv_pid
         OR ( lv_has_elt = 'X' AND lv_elt2 < ls_cand-elt ).
*       Cambio algo entre muestras: no esta trabado
        lv_gone = lv_gone + 1.
        CONTINUE.
      ENDIF.

      lv_bad = lv_bad + 1.
      PERFORM wp_detail USING ls_wp2 lv_elt2 CHANGING lv_det.
      IF lv_has_elt = 'X'.
        lv_min = lv_elt2 DIV 60.
        lv_sum = |WP en HOLD hace { lv_min } min sin cambios|.
        PERFORM add_result USING 'SM50' gc_err lv_sum lv_det.
      ELSE.
        lv_sum = |WP en HOLD sin cambios en { p_hwait } s (sin dato de tiempo)|.
        PERFORM add_result USING 'SM50' gc_warn lv_sum lv_det.
      ENDIF.
    ENDLOOP.
  ENDIF.

  IF lv_bad = 0.
    DESCRIBE TABLE gt_servers LINES lv_nsrv.
    lv_sum = 'Work processes en estados normales'.
    lv_det = |{ lv_tot } WP en { lv_nsrv } instancia(s)|.
    IF lv_recent > 0 OR lv_gone > 0.
      lv_recent = lv_recent + lv_gone.
      lv_det = |{ lv_det }; { lv_recent } en HOLD breve (< { p_holdm } min o se liberaron)|.
    ENDIF.
    PERFORM add_result USING 'SM50' gc_ok lv_sum lv_det.
  ENDIF.
ENDFORM.

*======================================================================*
* SM50 - capacidad: procesos por tipo (Total/Libres) por instancia,
*  como la vista general de SM50. Libre = estado Waiting.
*  WARNING si no queda ningun WP de dialogo o de update libre;
*  ERROR si la instancia no tiene WP de dialogo.
*======================================================================*
FORM check_wp_capacity.
  TYPES: BEGIN OF ty_cnt,
           typ   TYPE c LENGTH 3,
           total TYPE i,
           free  TYPE i,
         END OF ty_cnt.

  DATA: ls_srv    TYPE msxxlist,
        lv_srv    TYPE msxxlist-name,
        ls_wp     TYPE ty_wp,
        lt_cnt    TYPE STANDARD TABLE OF ty_cnt,
        ls_cnt    TYPE ty_cnt,
        lv_status TYPE c LENGTH 20,
        lv_cat    TYPE c LENGTH 10,
        lv_tot    TYPE i,
        lv_state  TYPE c LENGTH 10,
        lv_list   TYPE string,
        lv_alert  TYPE string,
        lv_sum    TYPE string,
        lv_det    TYPE string.

  FIELD-SYMBOLS <ls_cnt> TYPE ty_cnt.

  IF gt_wp IS INITIAL.
    RETURN.                         "ya informado en check_sm50
  ENDIF.

  LOOP AT gt_servers INTO ls_srv.
    lv_srv = ls_srv-name.
    IF lv_srv IS INITIAL.
      lv_srv = 'local'.
    ENDIF.

*   Orden fijo, igual que SM50
    REFRESH lt_cnt.
    CLEAR ls_cnt.
    ls_cnt-typ = 'DIA'. APPEND ls_cnt TO lt_cnt.
    ls_cnt-typ = 'UPD'. APPEND ls_cnt TO lt_cnt.
    ls_cnt-typ = 'ENQ'. APPEND ls_cnt TO lt_cnt.
    ls_cnt-typ = 'BTC'. APPEND ls_cnt TO lt_cnt.
    ls_cnt-typ = 'SPO'. APPEND ls_cnt TO lt_cnt.
    ls_cnt-typ = 'UP2'. APPEND ls_cnt TO lt_cnt.
    CLEAR lv_tot.

    LOOP AT gt_wp INTO ls_wp WHERE server = lv_srv.
      lv_tot = lv_tot + 1.
      READ TABLE lt_cnt ASSIGNING <ls_cnt> WITH KEY typ = ls_wp-info-wp_typ.
      IF sy-subrc <> 0.
        CLEAR ls_cnt.
        ls_cnt-typ = ls_wp-info-wp_typ.
        APPEND ls_cnt TO lt_cnt ASSIGNING <ls_cnt>.
      ENDIF.
      <ls_cnt>-total = <ls_cnt>-total + 1.
      lv_status = ls_wp-info-wp_status.
      PERFORM classify_wp USING lv_status CHANGING lv_cat.
      IF lv_cat = 'WAIT'.
        <ls_cnt>-free = <ls_cnt>-free + 1.
      ENDIF.
    ENDLOOP.

    IF lv_tot = 0.
      CONTINUE.
    ENDIF.

    CLEAR: lv_list, lv_alert.
    lv_state = gc_ok.
    LOOP AT lt_cnt INTO ls_cnt.
      IF ls_cnt-total = 0 AND ls_cnt-typ <> 'DIA'.
        CONTINUE.
      ENDIF.
      lv_list = |{ lv_list } { ls_cnt-typ } { ls_cnt-total }/{ ls_cnt-free }|.

      CASE ls_cnt-typ.
        WHEN 'DIA'.
          IF ls_cnt-total = 0.
            lv_state = gc_err.
            lv_alert = |{ lv_alert } Sin WP de dialogo.|.
          ELSEIF ls_cnt-free = 0.
            IF lv_state <> gc_err.
              lv_state = gc_warn.
            ENDIF.
            lv_alert = |{ lv_alert } Sin WP de dialogo libres.|.
          ENDIF.
        WHEN 'UPD'.
          IF ls_cnt-free = 0.
            IF lv_state <> gc_err.
              lv_state = gc_warn.
            ENDIF.
            lv_alert = |{ lv_alert } Sin WP de update libres.|.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    lv_sum = |{ lv_srv }: { lv_tot } procesos -{ lv_list } (Total/Libres)|.
    IF lv_alert IS INITIAL.
      lv_det = 'DIA=Dialog UPD=Update ENQ=Enqueue BTC=Background SPO=Spool UP2=Update II'.
    ELSE.
      lv_det = lv_alert.
      CONDENSE lv_det.
    ENDIF.
    PERFORM add_result USING 'SM50 WP' lv_state lv_sum lv_det.
  ENDLOOP.
ENDFORM.

*======================================================================*
* RTCCTOOL - recomendaciones pendientes
*  Se interpreta la lista por los codigos de icono que deja LIST_TO_ASCI:
*   rojo:     @0A@ (semaforo)  @5C@ (LED)  @F1@
*   amarillo: @09@ (semaforo)  @5D@ (LED)
*   verde:    @08@ (semaforo)  @5B@ (LED)
*  Si no reconoce ninguno, vuelca la salida para poder ajustar el parser.
*======================================================================*
FORM check_rtcctool.
  DATA: lt_lines TYPE ty_t_text,
        lv_line  TYPE ty_text,
        lv_ok    TYPE c LENGTH 1,
        lv_msg   TYPE c LENGTH 255,
        lv_cat   TYPE c LENGTH 1,
        lv_red   TYPE i,
        lv_yel   TYPE i,
        lv_green TYPE i,
        lv_shown TYPE i,
        lv_n     TYPE i,
        lv_codes TYPE string,
        lv_code  TYPE string,
        lv_ver   TYPE string,
        lv_sum   TYPE string.

  PERFORM submit_list USING 'RTCCTOOL' CHANGING lt_lines lv_ok lv_msg.
  IF lv_ok IS INITIAL.
    PERFORM add_result USING 'RTCCTOOL' gc_inc
      'No se pudo ejecutar RTCCTOOL' lv_msg.
    RETURN.
  ENDIF.

  LOOP AT lt_lines INTO lv_line.
    CLEAR lv_cat.
    IF lv_line CS '@0A@' OR lv_line CS '@5C@' OR lv_line CS '@F1@'.
      lv_cat = 'R'.
    ELSEIF lv_line CS '@09@' OR lv_line CS '@5D@'.
      lv_cat = 'Y'.
    ELSEIF lv_line CS '@08@' OR lv_line CS '@5B@'.
      lv_cat = 'G'.
    ELSEIF lv_line CS 'MISSING' OR lv_line CS 'FALTA'.
*     RTCCTOOL antiguo (sin ST-A/PI): informa notas faltantes en texto
      lv_cat = 'M'.
    ELSE.
      IF lv_line CS 'VERSION' AND lv_ver IS INITIAL.
        lv_ver = lv_line.
        CONDENSE lv_ver.
      ENDIF.
*     Juntar otros codigos de icono que aparezcan (para diagnostico)
      FIND REGEX '(@[0-9A-Z]{2}@)' IN lv_line SUBMATCHES lv_code.
      IF sy-subrc = 0.
        IF lv_codes NS lv_code.
          lv_codes = |{ lv_codes } { lv_code }|.
        ENDIF.
      ENDIF.
      CONTINUE.
    ENDIF.

    CASE lv_cat.
      WHEN 'G'.
        lv_green = lv_green + 1.
        CONTINUE.
      WHEN 'R'.
        lv_red = lv_red + 1.
      WHEN 'Y' OR 'M'.
        lv_yel = lv_yel + 1.
    ENDCASE.

    lv_shown = lv_shown + 1.
    IF lv_shown > 15.
      CONTINUE.
    ENDIF.
    REPLACE ALL OCCURRENCES OF REGEX '@[0-9A-Z]{2}@' IN lv_line WITH ''.
    CONDENSE lv_line.
    IF lv_cat = 'R'.
      PERFORM add_result USING 'RTCCTOOL' gc_err 'Recomendacion pendiente (rojo)' lv_line.
    ELSEIF lv_cat = 'M'.
      IF lv_ver IS NOT INITIAL.
        lv_sum = |Pendiente ({ lv_ver })|.
      ELSE.
        lv_sum = 'Pendiente'.
      ENDIF.
      PERFORM add_result USING 'RTCCTOOL' gc_warn lv_sum lv_line.
    ELSE.
      PERFORM add_result USING 'RTCCTOOL' gc_warn 'Recomendacion pendiente (amarillo)' lv_line.
    ENDIF.
  ENDLOOP.

  IF lv_shown > 15.
    lv_sum = |{ lv_red } en rojo y { lv_yel } en amarillo (se muestran 15)|.
    PERFORM add_result USING 'RTCCTOOL' gc_warn lv_sum 'Ver RTCCTOOL'.
  ENDIF.

  IF lv_red > 0 OR lv_yel > 0.
    RETURN.
  ENDIF.

  IF lv_green = 0 AND lv_ver IS NOT INITIAL AND lv_codes IS INITIAL.
*   RTCCTOOL antiguo sin notas faltantes
    PERFORM add_result USING 'RTCCTOOL' gc_ok 'Sin notas faltantes' lv_ver.
    RETURN.
  ENDIF.

  IF lv_green > 0.
    lv_sum = |{ lv_green } chequeo(s) en verde|.
    PERFORM add_result USING 'RTCCTOOL' gc_ok 'Sin recomendaciones pendientes' lv_sum.
    RETURN.
  ENDIF.

* No se reconocio ningun semaforo: volcar la salida (max. 40 lineas)
  IF lv_codes IS INITIAL.
    lv_codes = 'ninguno (los iconos no llegan como @xx@)'.
  ENDIF.
  lv_sum = |No se reconocieron semaforos. Iconos vistos: { lv_codes }|.
  PERFORM add_result USING 'RTCCTOOL' gc_inc lv_sum
    'Salida de RTCCTOOL en las filas siguientes'.
  lv_n = 0.
  LOOP AT lt_lines INTO lv_line.
    lv_n = lv_n + 1.
    IF lv_n > 40.
      EXIT.
    ENDIF.
    CONDENSE lv_line.
    lv_sum = |Linea { lv_n }|.
    PERFORM add_result USING 'RTCCTOOL' gc_inc lv_sum lv_line.
  ENDLOOP.
ENDFORM.

*======================================================================*
* Certificados - PSE del directorio sec (como STRUST)
*  Certificado propio: siempre se informa CN y vencimiento.
*  Certificados de confianza (lista del PSE): tambien se informan todos.
*======================================================================*
FORM eval_cert USING p_pse  TYPE any
                     p_own  TYPE c
                     p_cert TYPE xstring
               CHANGING p_flagged TYPE i.
  CONSTANTS lc_fm TYPE c LENGTH 30 VALUE 'SSFC_PARSE_CERTIFICATE'.

  DATA: lt_ptab  TYPE abap_func_parmbind_tab,
        lr_subj  TYPE REF TO data,
        lr_to    TYPE REF TO data,
        lv_found TYPE c LENGTH 1,
        lv_subrc TYPE i,
        lv_msg   TYPE c LENGTH 255,
        lv_subj  TYPE string,
        lv_to    TYPE string,
        lv_cn    TYPE string,
        lv_date  TYPE d,
        lv_days  TYPE i,
        lv_len   TYPE i,
        lv_status TYPE c LENGTH 10,
        lv_sum   TYPE string,
        lv_det   TYPE string.

  FIELD-SYMBOLS: <lv_subj> TYPE any,
                 <lv_to>   TYPE any.

  PERFORM fm_set   USING lc_fm 'CERTIFICATE' p_cert CHANGING lt_ptab lv_found.
  PERFORM fm_param USING lc_fm 'SUBJECT' 'STRING' CHANGING lt_ptab lr_subj lv_found.
  PERFORM fm_param USING lc_fm 'VALIDTO' 'STRING' CHANGING lt_ptab lr_to lv_found.
  IF lr_subj IS NOT BOUND OR lr_to IS NOT BOUND.
    IF p_own = 'X'.
      PERFORM add_result USING 'CERTIFICADOS' gc_inc p_pse
        'SSFC_PARSE_CERTIFICATE sin SUBJECT/VALIDTO'.
    ENDIF.
    RETURN.
  ENDIF.

  PERFORM fm_call USING lc_fm CHANGING lt_ptab lv_subrc lv_msg.
  IF lv_subrc <> 0.
    IF p_own = 'X'.
      PERFORM add_result USING 'CERTIFICADOS' gc_inc p_pse lv_msg.
    ENDIF.
    RETURN.
  ENDIF.

  ASSIGN lr_subj->* TO <lv_subj>.
  ASSIGN lr_to->* TO <lv_to>.
  lv_subj = <lv_subj>.
  lv_to   = <lv_to>.

  FIND REGEX 'CN=([^,]+)' IN lv_subj SUBMATCHES lv_cn.
  IF sy-subrc <> 0.
    lv_cn = lv_subj.
  ENDIF.

* VALIDTO: se toman solo los digitos (AAAAMMDDhhmmss o AAMMDDhhmmss)
  REPLACE ALL OCCURRENCES OF REGEX '[^0-9]' IN lv_to WITH ''.
  lv_len = strlen( lv_to ).
  IF lv_len >= 14.
    lv_date = lv_to(8).
  ELSEIF lv_len = 12.
    CONCATENATE '20' lv_to(6) INTO lv_to.
    lv_date = lv_to(8).
  ELSE.
    IF p_own = 'X'.
      lv_det = |No se pudo interpretar la fecha de vencimiento: { lv_to }|.
      PERFORM add_result USING 'CERTIFICADOS' gc_inc p_pse lv_det.
    ENDIF.
    RETURN.
  ENDIF.

  lv_days = lv_date - sy-datum.

  IF lv_days < 0.
    IF p_own = 'X'.
      lv_status = gc_err.
    ELSE.
      lv_status = gc_warn.
    ENDIF.
  ELSEIF lv_days <= p_cdias.
    lv_status = gc_warn.
  ELSE.
    lv_status = gc_ok.
  ENDIF.

  IF lv_status <> gc_ok.
    p_flagged = p_flagged + 1.
  ENDIF.

  IF p_own = 'X'.
    lv_sum = |{ p_pse } (propio): CN={ lv_cn }|.
  ELSE.
    lv_sum = |{ p_pse } (confianza): CN={ lv_cn }|.
  ENDIF.
  IF lv_days < 0.
    lv_det = |VENCIDO el { lv_date DATE = USER } (hace { abs( lv_days ) } dias) - { lv_subj }|.
  ELSE.
    lv_det = |Vence { lv_date DATE = USER } ({ lv_days } dias) - { lv_subj }|.
  ENDIF.
  PERFORM add_result USING 'CERTIFICADOS' lv_status lv_sum lv_det.
ENDFORM.

FORM check_certificates.
  DATA: lv_parname TYPE c LENGTH 60 VALUE 'DIR_INSTANCE',
        lv_dir     TYPE c LENGTH 200,
        lv_secdir  TYPE epsf-epsdirnam,
        lt_files   TYPE STANDARD TABLE OF epsfili,
        ls_file    TYPE epsfili,
        lv_pse     TYPE c LENGTH 255,
        lt_ptab    TYPE abap_func_parmbind_tab,
        lr_cert    TYPE REF TO data,
        lr_list    TYPE REF TO data,
        lv_found   TYPE c LENGTH 1,
        lv_subrc   TYPE i,
        lv_msg     TYPE c LENGTH 255,
        lv_xcert   TYPE xstring,
        lv_kind    TYPE c LENGTH 1,
        lv_npse    TYPE i,
        lv_nown    TYPE i,
        lv_ntrust  TYPE i,
        lv_flag    TYPE i,
        lv_sum     TYPE string,
        lv_det     TYPE string.

  FIELD-SYMBOLS: <lv_cert> TYPE any,
                 <lt_list> TYPE ANY TABLE,
                 <ls_row>  TYPE any,
                 <lv_comp> TYPE any.

* Directorio sec de la instancia
  CALL 'C_SAPGPARAM' ID 'NAME'  FIELD lv_parname
                     ID 'VALUE' FIELD lv_dir.
  IF lv_dir IS INITIAL.
    PERFORM add_result USING 'CERTIFICADOS' gc_inc
      'No se pudo leer DIR_INSTANCE' 'Revisar parametros de perfil'.
    RETURN.
  ENDIF.
  IF lv_dir CA '\'.
    CONCATENATE lv_dir '\sec' INTO lv_secdir.
  ELSE.
    CONCATENATE lv_dir '/sec' INTO lv_secdir.
  ENDIF.

  CALL FUNCTION 'EPS_GET_DIRECTORY_LISTING'
    EXPORTING
      dir_name = lv_secdir
    TABLES
      dir_list = lt_files
    EXCEPTIONS
      OTHERS   = 1.
  IF sy-subrc <> 0.
    lv_det = |No se pudo listar { lv_secdir }|.
    PERFORM add_result USING 'CERTIFICADOS' gc_inc
      'No se pudo leer el directorio sec' lv_det.
    RETURN.
  ENDIF.

  LOOP AT lt_files INTO ls_file.
    IF ls_file-name NP '*.pse' AND ls_file-name NP '*.PSE'.
      CONTINUE.
    ENDIF.
    lv_pse  = ls_file-name.
    lv_npse = lv_npse + 1.

*   Certificado propio
    REFRESH lt_ptab.
    PERFORM fm_set   USING 'SSFC_GET_OWNCERTIFICATE' 'PROFILE' lv_pse
                     CHANGING lt_ptab lv_found.
    PERFORM fm_param USING 'SSFC_GET_OWNCERTIFICATE' 'CERTIFICATE' 'XSTRING'
                     CHANGING lt_ptab lr_cert lv_found.
    IF lv_found = 'X'.
      PERFORM fm_call USING 'SSFC_GET_OWNCERTIFICATE'
                      CHANGING lt_ptab lv_subrc lv_msg.
      IF lv_subrc = 0.
        ASSIGN lr_cert->* TO <lv_cert>.
        TRY.
            lv_xcert = <lv_cert>.
            lv_nown = lv_nown + 1.
            PERFORM eval_cert USING lv_pse 'X' lv_xcert CHANGING lv_flag.
          CATCH cx_root.                                 "#EC NO_HANDLER
        ENDTRY.
      ELSE.
        lv_sum = |{ lv_pse }: no se pudo leer el certificado propio|.
        PERFORM add_result USING 'CERTIFICADOS' gc_inc lv_sum lv_msg.
      ENDIF.
    ENDIF.

*   Lista de certificados de confianza
    REFRESH lt_ptab.
    PERFORM fm_set   USING 'SSFC_GET_CERTIFICATELIST' 'PROFILE' lv_pse
                     CHANGING lt_ptab lv_found.
    PERFORM fm_param USING 'SSFC_GET_CERTIFICATELIST' 'CERTIFICATELIST' 'STRING'
                     CHANGING lt_ptab lr_list lv_found.
    IF lv_found IS INITIAL.
      CONTINUE.
    ENDIF.
    PERFORM fm_call USING 'SSFC_GET_CERTIFICATELIST'
                    CHANGING lt_ptab lv_subrc lv_msg.
    IF lv_subrc <> 0.
      CONTINUE.                          "PSE sin lista (normal en algunos)
    ENDIF.

    ASSIGN lr_list->* TO <lt_list>.
    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.
    LOOP AT <lt_list> ASSIGNING <ls_row>.
      CLEAR lv_xcert.
      DESCRIBE FIELD <ls_row> TYPE lv_kind.
      IF lv_kind = 'y'.                                   "xstring
        lv_xcert = <ls_row>.
      ELSEIF lv_kind = 'u' OR lv_kind = 'v'.              "estructura
        ASSIGN COMPONENT 1 OF STRUCTURE <ls_row> TO <lv_comp>.
        IF sy-subrc = 0.
          DESCRIBE FIELD <lv_comp> TYPE lv_kind.
          IF lv_kind = 'y'.
            lv_xcert = <lv_comp>.
          ENDIF.
        ENDIF.
      ENDIF.
      IF lv_xcert IS INITIAL.
        CONTINUE.
      ENDIF.
      lv_ntrust = lv_ntrust + 1.
      PERFORM eval_cert USING lv_pse ' ' lv_xcert CHANGING lv_flag.
    ENDLOOP.
  ENDLOOP.

  IF lv_npse = 0.
    lv_det = |No hay archivos .pse en { lv_secdir }|.
    PERFORM add_result USING 'CERTIFICADOS' gc_inc 'No se encontraron PSE' lv_det.
    RETURN.
  ENDIF.

  lv_sum = |{ lv_npse } PSE - { lv_nown } certificado(s) propio(s) + { lv_ntrust } de confianza|.
  IF lv_flag = 0.
    lv_det = |Ninguno vence en los proximos { p_cdias } dias|.
    PERFORM add_result USING 'CERTIFICADOS' gc_ok lv_sum lv_det.
  ELSE.
    lv_det = |{ lv_flag } con aviso (ver filas anteriores)|.
    PERFORM add_result USING 'CERTIFICADOS' gc_warn lv_sum lv_det.
  ENDIF.
ENDFORM.

*======================================================================*
* ST03N - Tiempo resp. medio / paso dialogo (ms) del dia anterior
*======================================================================*
*----------------------------------------------------------------------*
* Dia habil anterior a p_date (lunes -> viernes, domingo -> viernes)
*----------------------------------------------------------------------*
FORM previous_workday USING p_date TYPE d CHANGING p_prev TYPE d.
  DATA lv_day TYPE c LENGTH 1.           "1 = lunes ... 7 = domingo

  p_prev = p_date - 1.
  DO 7 TIMES.
    CALL FUNCTION 'DATE_COMPUTE_DAY'
      EXPORTING
        date = p_prev
      IMPORTING
        day  = lv_day.
    IF lv_day <> '6' AND lv_day <> '7'.
      EXIT.
    ENDIF.
    p_prev = p_prev - 1.
  ENDDO.
ENDFORM.

FORM check_st03n.
  DATA: lv_date    TYPE d,
        lv_dia_cnt TYPE p LENGTH 16 DECIMALS 0,
        lv_dia_avg TYPE p LENGTH 16 DECIMALS 1,
        lv_rfc_cnt TYPE p LENGTH 16 DECIMALS 0,
        lv_rfc_avg TYPE p LENGTH 16 DECIMALS 1,
        lv_ok      TYPE c LENGTH 1,
        lv_msg     TYPE c LENGTH 255,
        lv_sum     TYPE string,
        lv_det     TYPE string,
        lv_target  TYPE d,
        lv_prev    TYPE d,
        lv_note    TYPE string.

* Dia habil anterior (se saltean sabados y domingos). Si ese dia no
* tiene datos en el colector, se retrocede dia habil por dia habil
* hasta encontrar el mas cercano con datos (maximo 30 dias corridos).
  PERFORM previous_workday USING sy-datum CHANGING lv_target.
  lv_date = lv_target.

  DO.
    PERFORM get_workload USING 'TOTAL' lv_date
                         CHANGING lv_dia_cnt lv_dia_avg lv_rfc_cnt lv_rfc_avg
                                  lv_ok lv_msg.
    IF lv_ok = 'X'.
      EXIT.
    ENDIF.
    PERFORM previous_workday USING lv_date CHANGING lv_prev.
    lv_date = lv_prev.
    IF sy-datum - lv_date > 30.
      EXIT.
    ENDIF.
  ENDDO.

  IF lv_ok IS INITIAL.
    lv_sum = |Sin datos de workload en los ultimos 30 dias (desde { lv_target DATE = USER })|.
    PERFORM add_result USING 'ST03N' gc_warn lv_sum
      'Verificar job SAP_COLLECTOR_FOR_PERFMONITOR (SWNCTOTAL)'.
    RETURN.
  ENDIF.

  IF lv_date <> lv_target.
    lv_note = | (sin datos del { lv_target DATE = USER }, se usa el ultimo disponible)|.
  ENDIF.

* Dos filas separadas: valor de "Tiempo resp. medio / paso dialogo (ms)"
  lv_sum = |{ lv_dia_avg } ms (Tmpo.resp.medio/paso dialogo)|.
  lv_det = |DIALOG del { lv_date DATE = USER }: { lv_dia_cnt } pasos{ lv_note }|.
  PERFORM add_result USING 'ST03N DIALOG' gc_ok lv_sum lv_det.

  lv_sum = |{ lv_rfc_avg } ms (Tmpo.resp.medio/paso dialogo)|.
  lv_det = |RFC del { lv_date DATE = USER }: { lv_rfc_cnt } pasos{ lv_note }|.
  PERFORM add_result USING 'ST03N RFC' gc_ok lv_sum lv_det.
ENDFORM.

*======================================================================*
* SMLG - tiempo de respuesta por instancia < p_rtlim ms
*  Mismo dato que muestra SMLG: muestra del message server leida con
*  RZL_STRG_READALL_I (SRVNAME = 'MSGSERVER'), filas con VALUE1 = 7353:
*    NAME = instancia, VALUE2 = tiempo resp. (ms), VALUE3 = pasos dialogo,
*    VALUE4 = usuarios, VALUE5 = calidad, VALUE = hora de la muestra.
*  Como referencia se agrega el promedio Dialog del dia (colector ST03N).
*  Si el message server no devuelve muestra, se usa ese promedio.
*======================================================================*
FORM check_smlg.
  TYPES: BEGIN OF ty_grp,
           classname  TYPE c LENGTH 20,
           applserver TYPE c LENGTH 40,
           resp_time  TYPE i,
         END OF ty_grp.

  DATA: lt_grp     TYPE STANDARD TABLE OF ty_grp,
        ls_grp     TYPE ty_grp,
        ls_srv     TYPE msxxlist,
        lv_tab     TYPE c LENGTH 30 VALUE 'RZLLITAB',
        lv_msgsrv  TYPE msxxlist-name VALUE 'MSGSERVER',
        lt_intg    TYPE STANDARD TABLE OF salstintg,
        ls_intg    TYPE salstintg,
        lv_live    TYPE c LENGTH 1,
        lv_name    TYPE c LENGTH 40,
        lv_resp    TYPE i,
        lv_steps   TYPE i,
        lv_users   TYPE i,
        lv_qual    TYPE i,
        lv_time    TYPE t,
        lv_groups  TYPE string,
        lv_thresh  TYPE string,
        lv_comp    TYPE c LENGTH 40,
        lv_date    TYPE d,
        lv_dia_cnt TYPE p LENGTH 16 DECIMALS 0,
        lv_dia_avg TYPE p LENGTH 16 DECIMALS 1,
        lv_rfc_cnt TYPE p LENGTH 16 DECIMALS 0,
        lv_rfc_avg TYPE p LENGTH 16 DECIMALS 1,
        lv_ok      TYPE c LENGTH 1,
        lv_msg     TYPE c LENGTH 255,
        lv_avgtxt  TYPE string,
        lv_status  TYPE c LENGTH 10,
        lv_sum     TYPE string,
        lv_det     TYPE string.

* Grupos de logon y umbrales definidos en SMLG
  TRY.
      SELECT * FROM (lv_tab) INTO CORRESPONDING FIELDS OF TABLE lt_grp.
    CATCH cx_root.                                       "#EC NO_HANDLER
  ENDTRY.

* Muestra en vivo del message server (lo mismo que lee SMLG)
  CALL FUNCTION 'RZL_STRG_READALL_I'
    EXPORTING
      srvname  = lv_msgsrv
    TABLES
      intg_tbl = lt_intg
    EXCEPTIONS
      OTHERS   = 1.
  IF sy-subrc <> 0.
    REFRESH lt_intg.
  ENDIF.
  DELETE lt_intg WHERE value1 <> 7353.

  LOOP AT gt_servers INTO ls_srv.
    lv_comp = ls_srv-name.
    IF lv_comp IS INITIAL.
      lv_comp = 'TOTAL'.
    ENDIF.

*   Grupos y umbral de tiempo de respuesta de la instancia
    CLEAR: lv_groups, lv_thresh.
    LOOP AT lt_grp INTO ls_grp WHERE applserver = ls_srv-name.
      IF ls_grp-classname IS NOT INITIAL.
        IF lv_groups IS INITIAL.
          lv_groups = ls_grp-classname.
        ELSE.
          lv_groups = |{ lv_groups }, { ls_grp-classname }|.
        ENDIF.
      ENDIF.
      IF ls_grp-resp_time > 0 AND lv_thresh IS INITIAL.
        lv_thresh = |{ ls_grp-resp_time }|.
      ENDIF.
    ENDLOOP.
    IF lv_groups IS INITIAL.
      lv_groups = 'sin grupo de logon'.
    ENDIF.

*   Promedio del dia como referencia
    CLEAR lv_avgtxt.
    lv_date = sy-datum.
    PERFORM get_workload USING lv_comp lv_date
                         CHANGING lv_dia_cnt lv_dia_avg lv_rfc_cnt lv_rfc_avg
                                  lv_ok lv_msg.
    IF lv_ok = 'X' AND lv_dia_cnt > 0.
      lv_avgtxt = |Prom. dialog hoy: { lv_dia_avg } ms ({ lv_dia_cnt } pasos)|.
    ENDIF.

*   Muestra en vivo de esta instancia
    CLEAR lv_live.
    LOOP AT lt_intg INTO ls_intg.
      lv_name = ls_intg-name.
      CONDENSE lv_name.
      IF lv_name = ls_srv-name OR ( ls_srv-name IS INITIAL AND lv_name = gv_local_srv ).
        lv_live  = 'X'.
        lv_resp  = ls_intg-value2.
        lv_steps = ls_intg-value3.
        lv_users = ls_intg-value4.
        lv_qual  = ls_intg-value5.
        lv_time  = ls_intg-value.          "igual que SMLG (GZ_STATE_TBL-UZEIT)
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_live = 'X'.
      IF lv_resp < p_rtlim.
        lv_status = gc_ok.
      ELSE.
        lv_status = gc_err.
      ENDIF.
      lv_sum = |{ lv_comp }: { lv_resp } ms (limite { p_rtlim })|.
      lv_det = |Muestra { lv_time TIME = USER }: { lv_steps } pasos dialogo, | &&
               |{ lv_users } usuarios, calidad { lv_qual } - Grupos: { lv_groups }|.
      IF lv_thresh IS NOT INITIAL.
        lv_det = |{ lv_det } (umbral SMLG { lv_thresh } ms)|.
      ENDIF.
      IF lv_avgtxt IS NOT INITIAL.
        lv_det = |{ lv_det } - { lv_avgtxt }|.
      ENDIF.
      PERFORM add_result USING 'SMLG' lv_status lv_sum lv_det.
      CONTINUE.
    ENDIF.

*   Sin muestra del message server: se usa el promedio del dia
    IF lv_avgtxt IS INITIAL.
      lv_sum = |{ lv_comp }: sin datos de tiempo de respuesta|.
      PERFORM add_result USING 'SMLG' gc_inc lv_sum
        'El message server no devolvio muestra y no hay datos en el colector'.
      CONTINUE.
    ENDIF.
    IF lv_dia_avg < p_rtlim.
      lv_status = gc_ok.
    ELSE.
      lv_status = gc_err.
    ENDIF.
    lv_sum = |{ lv_comp }: { lv_dia_avg } ms prom. del dia (limite { p_rtlim })|.
    lv_det = |Sin muestra en vivo del message server - { lv_avgtxt } - Grupos: { lv_groups }|.
    PERFORM add_result USING 'SMLG' lv_status lv_sum lv_det.
  ENDLOOP.
ENDFORM.

*======================================================================*
* SCOT - nodo activo o, si no hay nodos, cola vacia
*======================================================================*
FORM check_scot.
  DATA: lv_tab     TYPE c LENGTH 30,
        lr_tab     TYPE REF TO data,
        lo_struct  TYPE REF TO cl_abap_structdescr,
        lo_type    TYPE REF TO cl_abap_typedescr,
        lt_comp    TYPE abap_compdescr_tab,
        ls_comp    TYPE abap_compdescr,
        lv_actfld  TYPE c LENGTH 30,
        lv_invert  TYPE c LENGTH 1,
        lv_fields  TYPE string,
        lv_nnodes  TYPE i,
        lv_active  TYPE i,
        lv_queue   TYPE i,
        lv_qok     TYPE c LENGTH 1,
        lv_job     TYPE tbtcp-jobname,
        lv_node    TYPE string,
        lv_isact   TYPE c LENGTH 1,
        lx_root    TYPE REF TO cx_root,
        lv_text    TYPE string,
        lv_sum     TYPE string,
        lv_det     TYPE string.

  FIELD-SYMBOLS: <lt_nodes> TYPE STANDARD TABLE,
                 <ls_node>  TYPE any,
                 <lv_fld>   TYPE any.

* 1) Nodos (SXNODES)
  lv_tab = 'SXNODES'.
  TRY.
      CREATE DATA lr_tab TYPE STANDARD TABLE OF (lv_tab).
      ASSIGN lr_tab->* TO <lt_nodes>.
      SELECT * FROM (lv_tab) INTO TABLE <lt_nodes>.
    CATCH cx_root INTO lx_root.
      lv_text = lx_root->get_text( ).
      PERFORM add_result USING 'SCOT' gc_inc 'No se pudo leer SXNODES' lv_text.
      RETURN.
  ENDTRY.
  DESCRIBE TABLE <lt_nodes> LINES lv_nnodes.

* Campo que indica si el nodo esta activo (varia segun release)
  lo_type = cl_abap_typedescr=>describe_by_name( lv_tab ).
  lo_struct ?= lo_type.
  lt_comp = lo_struct->components.
  LOOP AT lt_comp INTO ls_comp.
    lv_fields = |{ lv_fields } { ls_comp-name }|.
    IF lv_actfld IS INITIAL.
      CASE ls_comp-name.
        WHEN 'NODE_ACTIVE' OR 'ACTIVE' OR 'NODE_ACT' OR 'NODEACTIVE'
          OR 'INUSE' OR 'NODE_INUSE' OR 'IN_USE'.
          lv_actfld = ls_comp-name.
        WHEN 'NODE_INACT' OR 'INACTIVE' OR 'NODEINACT'.
          lv_actfld = ls_comp-name.
          lv_invert = 'X'.
      ENDCASE.
    ENDIF.
  ENDLOOP.

* 2) Cola de envio (SOSC)
  lv_tab = 'SOSC'.
  TRY.
      SELECT COUNT(*) FROM (lv_tab) INTO lv_queue.
      lv_qok = 'X'.
    CATCH cx_root INTO lx_root.
      lv_text = lx_root->get_text( ).
      PERFORM add_result USING 'SCOT' gc_inc 'No se pudo leer la cola (SOSC)' lv_text.
  ENDTRY.

* 3) Sin nodos: la cola tiene que estar vacia
  IF lv_nnodes = 0.
    IF lv_qok IS INITIAL.
      RETURN.
    ENDIF.
    IF lv_queue = 0.
      PERFORM add_result USING 'SCOT' gc_ok 'Sin nodos definidos y cola vacia' ''.
    ELSE.
      lv_sum = |Sin nodos definidos pero hay { lv_queue } envio(s) en cola|.
      PERFORM add_result USING 'SCOT' gc_err lv_sum 'Revisar SOST'.
    ENDIF.
    RETURN.
  ENDIF.

* 4) Con nodos: tienen que estar activos
  LOOP AT <lt_nodes> ASSIGNING <ls_node>.
    CLEAR lv_node.
    ASSIGN COMPONENT 'NODE' OF STRUCTURE <ls_node> TO <lv_fld>.
    IF sy-subrc = 0.
      lv_node = <lv_fld>.
    ENDIF.

    IF lv_actfld IS INITIAL.
      lv_sum = |Nodo { lv_node }: no se pudo determinar si esta activo|.
      lv_det = |Campos de SXNODES:{ lv_fields }|.
      PERFORM add_result USING 'SCOT' gc_inc lv_sum lv_det.
      CONTINUE.
    ENDIF.

    ASSIGN COMPONENT lv_actfld OF STRUCTURE <ls_node> TO <lv_fld>.
    lv_isact = <lv_fld>.
    IF lv_invert = 'X'.
      IF lv_isact IS INITIAL.
        lv_isact = 'X'.
      ELSE.
        CLEAR lv_isact.
      ENDIF.
    ENDIF.

    IF lv_isact IS INITIAL.
      lv_sum = |Nodo { lv_node } inactivo|.
      PERFORM add_result USING 'SCOT' gc_err lv_sum 'Activar en SCOT'.
    ELSE.
      lv_active = lv_active + 1.
      lv_sum = |Nodo { lv_node } activo|.
      PERFORM add_result USING 'SCOT' gc_ok lv_sum ''.
    ENDIF.
  ENDLOOP.

  IF lv_qok = 'X' AND lv_queue > 0.
    lv_sum = |{ lv_queue } envio(s) pendiente(s) en cola|.
    PERFORM add_result USING 'SCOT' gc_warn lv_sum 'Revisar SOST'.
  ENDIF.

* 5) Job de envio (RSCONN01) liberado
  IF lv_active > 0.
    SELECT p~jobname FROM tbtcp AS p
      INNER JOIN tbtco AS o ON  o~jobname  = p~jobname
                            AND o~jobcount = p~jobcount
      INTO lv_job UP TO 1 ROWS
      WHERE p~progname = 'RSCONN01'
        AND o~status   = 'S'.
    ENDSELECT.
    IF sy-subrc <> 0.
      PERFORM add_result USING 'SCOT' gc_warn
        'No hay job de envio RSCONN01 liberado'
        'Programarlo desde SCOT > Pasar a > Programar job'.
    ENDIF.
  ENDIF.
ENDFORM.

*======================================================================*
* SLICENSE - vencimiento de licencia (opcional, P_LIC)
*  Misma logica que la transaccion SLICENSE (SAPMSLIC, FORM sl_read_data):
*  - licencias: SLIC_READ_LICENSES (estructura SLIC_TAB)
*  - clave de hardware actual: SLIC_GET_CUSTKEY
*  - una licencia esta activa si SYSNAME = sistema y CUSTKEY = clave
*    de hardware actual.
*======================================================================*
FORM get_comp USING    ps_row  TYPE any
                       p_name  TYPE any
              CHANGING p_value TYPE string.
  FIELD-SYMBOLS <lv_f> TYPE any.

  CLEAR p_value.
  ASSIGN COMPONENT p_name OF STRUCTURE ps_row TO <lv_f>.
  IF sy-subrc = 0.
    p_value = <lv_f>.
    CONDENSE p_value.
  ENDIF.
ENDFORM.

FORM check_license.
  CONSTANTS: lc_fm_key TYPE c LENGTH 30 VALUE 'SLIC_GET_CUSTKEY',
             lc_fm_lic TYPE c LENGTH 30 VALUE 'SLIC_READ_LICENSES'.

  TYPES: BEGIN OF ty_row,
           status  TYPE c LENGTH 10,
           summary TYPE string,
           detail  TYPE string,
         END OF ty_row.

  DATA: lt_ptab   TYPE abap_func_parmbind_tab,
        lr_key    TYPE REF TO data,
        lr_lic    TYPE REF TO data,
        lv_found  TYPE c LENGTH 1,
        lv_subrc  TYPE i,
        lv_msg    TYPE c LENGTH 255,
        lv_hwkey  TYPE string,
        lv_sys    TYPE string,
        lv_ckey   TYPE string,
        lv_prod   TYPE string,
        lv_inst   TYPE string,
        lv_expc   TYPE string,
        lv_exp    TYPE d,
        lv_days   TYPE i,
        lv_expt   TYPE string,
        lv_active TYPE c LENGTH 1,
        lv_n      TYPE i,
        lv_nact   TYPE i,
        lv_worst  TYPE c LENGTH 10,
        lt_rows   TYPE STANDARD TABLE OF ty_row,
        ls_row    TYPE ty_row,
        lv_sum    TYPE string,
        lv_det    TYPE string.

  FIELD-SYMBOLS: <lv_key> TYPE any,
                 <lt_lic> TYPE ANY TABLE,
                 <ls_lic> TYPE any.

* 1) Clave de hardware actual
  PERFORM fm_set   USING lc_fm_key 'FROM_WHERE' 1   CHANGING lt_ptab lv_found.
  PERFORM fm_set   USING lc_fm_key 'HOSTNAME'   ' ' CHANGING lt_ptab lv_found.
  PERFORM fm_param USING lc_fm_key 'CUSTKEY' 'STRING'
                   CHANGING lt_ptab lr_key lv_found.
  IF lv_found = 'X'.
    PERFORM fm_call USING lc_fm_key CHANGING lt_ptab lv_subrc lv_msg.
    IF lv_subrc = 0.
      ASSIGN lr_key->* TO <lv_key>.
      lv_hwkey = <lv_key>.
      CONDENSE lv_hwkey.
    ENDIF.
  ENDIF.

* 2) Licencias instaladas
  REFRESH lt_ptab.
  PERFORM fm_param USING lc_fm_lic 'LICENSES' 'STRING'
                   CHANGING lt_ptab lr_lic lv_found.
  IF lv_found IS INITIAL.
    PERFORM add_result USING 'SLICENSE' gc_inc
      'No se pudo llamar a SLIC_READ_LICENSES' 'Parametro LICENSES no encontrado'.
    RETURN.
  ENDIF.
  PERFORM fm_call USING lc_fm_lic CHANGING lt_ptab lv_subrc lv_msg.
  IF lv_subrc <> 0.
    PERFORM add_result USING 'SLICENSE' gc_inc
      'No se pudieron leer las licencias' lv_msg.
    RETURN.
  ENDIF.

  lv_worst = gc_ok.
  ASSIGN lr_lic->* TO <lt_lic>.
  LOOP AT <lt_lic> ASSIGNING <ls_lic>.
    PERFORM get_comp USING <ls_lic> 'SYSNAME' CHANGING lv_sys.
    IF lv_sys <> sy-sysid.
      CONTINUE.                         "licencia de otro sistema
    ENDIF.
    PERFORM get_comp USING <ls_lic> 'CUSTKEY'    CHANGING lv_ckey.
    PERFORM get_comp USING <ls_lic> 'PRODUCTID'  CHANGING lv_prod.
    PERFORM get_comp USING <ls_lic> 'INSTNUMBER' CHANGING lv_inst.
    PERFORM get_comp USING <ls_lic> 'EXP_DATE'   CHANGING lv_expc.
    lv_n = lv_n + 1.

    IF lv_hwkey IS INITIAL OR lv_ckey = lv_hwkey.
      lv_active = 'X'.
    ELSE.
      CLEAR lv_active.
    ENDIF.

*   Vencimiento (AAAAMMDD; 99991231 = sin vencimiento)
    CLEAR: lv_exp, lv_expt.
    REPLACE ALL OCCURRENCES OF REGEX '[^0-9]' IN lv_expc WITH ''.
    IF strlen( lv_expc ) = 8.
      lv_exp = lv_expc.
    ENDIF.

    CLEAR ls_row.
    IF lv_exp IS INITIAL OR lv_exp = '00000000'.
      lv_expt = |sin fecha de vencimiento legible ({ lv_expc })|.
      ls_row-status = gc_inc.
    ELSEIF lv_exp >= '99991231'.
      lv_expt = 'sin vencimiento (permanente)'.
      ls_row-status = gc_ok.
    ELSE.
      lv_days = lv_exp - sy-datum.
      IF lv_days < 0.
        lv_expt = |VENCIDA el { lv_exp DATE = USER } (hace { abs( lv_days ) } dias)|.
        ls_row-status = gc_err.
      ELSEIF lv_days <= p_ldias.
        lv_expt = |vence el { lv_exp DATE = USER } ({ lv_days } dias)|.
        ls_row-status = gc_warn.
      ELSE.
        lv_expt = |vence el { lv_exp DATE = USER } ({ lv_days } dias)|.
        ls_row-status = gc_ok.
      ENDIF.
    ENDIF.

    IF lv_active = 'X'.
      lv_nact = lv_nact + 1.
      ls_row-summary = |{ lv_prod } (activa): { lv_expt }|.
*     El peor estado de las licencias activas define el resumen
      IF ls_row-status = gc_err.
        lv_worst = gc_err.
      ELSEIF ls_row-status = gc_warn AND lv_worst <> gc_err.
        lv_worst = gc_warn.
      ELSEIF ls_row-status = gc_inc AND lv_worst = gc_ok.
        lv_worst = gc_inc.
      ENDIF.
    ELSE.
*     Licencia de otra clave de hardware: solo informativa
      ls_row-status  = gc_ok.
      ls_row-summary = |{ lv_prod } (inactiva, otra clave de hardware): { lv_expt }|.
    ENDIF.
    ls_row-detail = |Instalacion { lv_inst } - Sistema { lv_sys } - Clave de hardware { lv_ckey }|.
    APPEND ls_row TO lt_rows.
  ENDLOOP.

* 3) Resumen primero, despues una fila por licencia
  IF lv_n = 0.
    lv_sum = |No hay licencias instaladas para { sy-sysid }|.
    PERFORM add_result USING 'SLICENSE' gc_err lv_sum 'Ver SLICENSE'.
    RETURN.
  ENDIF.

  IF lv_nact = 0.
    lv_sum = |Ninguna licencia activa para la clave de hardware actual|.
    lv_det = |Clave de hardware actual: { lv_hwkey } - { lv_n } licencia(s) instalada(s)|.
    PERFORM add_result USING 'SLICENSE' gc_err lv_sum lv_det.
  ELSE.
    lv_sum = |{ lv_nact } licencia(s) activa(s) de { lv_n } instalada(s)|.
    lv_det = |Clave de hardware actual: { lv_hwkey } - aviso con { p_ldias } dias de anticipacion|.
    PERFORM add_result USING 'SLICENSE' lv_worst lv_sum lv_det.
  ENDIF.

  LOOP AT lt_rows INTO ls_row.
    PERFORM add_result USING 'SLICENSE' ls_row-status ls_row-summary ls_row-detail.
  ENDLOOP.
ENDFORM.

*======================================================================*
* Envio del reporte por mail (pestana 3)
*  El cuerpo es una tabla HTML con los mismos datos y colores del ALV.
*  Se envia con CL_BCS; la salida real la hace SAPconnect (SCOT/SOST).
*======================================================================*
FORM html_escape CHANGING p_text TYPE string.
  REPLACE ALL OCCURRENCES OF '&' IN p_text WITH '&amp;'.
  REPLACE ALL OCCURRENCES OF '<' IN p_text WITH '&lt;'.
  REPLACE ALL OCCURRENCES OF '>' IN p_text WITH '&gt;'.
  REPLACE ALL OCCURRENCES OF '"' IN p_text WITH '&quot;'.
ENDFORM.

FORM status_colors USING p_status TYPE c CHANGING p_bg TYPE string p_fg TYPE string.
  CASE p_status.
    WHEN gc_ok.   p_bg = '#d4edda'. p_fg = '#155724'.
    WHEN gc_warn. p_bg = '#fff3cd'. p_fg = '#856404'.
    WHEN gc_err.  p_bg = '#f8d7da'. p_fg = '#721c24'.
    WHEN OTHERS.  p_bg = '#ffe5cc'. p_fg = '#8a4b08'.
  ENDCASE.
ENDFORM.

FORM build_mail_html CHANGING pt_soli TYPE soli_tab.
  CONSTANTS lc_td TYPE string VALUE 'border:1px solid #c8c8c8;padding:4px 6px;vertical-align:top;'.

  DATA: lt_res    TYPE STANDARD TABLE OF ty_result,
        ls_res    TYPE ty_result,
        lv_html   TYPE string,
        lv_bg     TYPE string,
        lv_fg     TYPE string,
        lv_gtext  TYPE c LENGTH 12,
        lv_last   TYPE string,
        lv_key    TYPE string,
        lv_tcode  TYPE string,
        lv_desc   TYPE string,
        lv_sum    TYPE string,
        lv_det    TYPE string,
        lv_zebra  TYPE string,
        lv_n      TYPE i,
        lv_len    TYPE i,
        lv_off    TYPE i,
        ls_soli   TYPE soli.

  PERFORM status_text USING gv_global CHANGING lv_gtext.
  PERFORM status_colors USING gv_global CHANGING lv_bg lv_fg.

  lv_html = |<html><body style="font-family:Arial,Helvetica,sans-serif;font-size:13px;color:#222;">| &&
            |<h2 style="margin:0 0 4px 0;">SAP Daily Health Check</h2>| &&
            |<div style="color:#555;">Sistema { sy-sysid } - Mandante { sy-mandt } - Host { sy-host } - | &&
            |{ sy-datum DATE = USER } { sy-uzeit TIME = USER }</div>| &&
            |<div style="margin:10px 0;padding:8px 12px;background:{ lv_bg };color:{ lv_fg };| &&
            |border:1px solid { lv_fg };font-weight:bold;">Estado general: { lv_gtext }| &&
            |&nbsp;&nbsp;&nbsp;Errores: { gv_cnt_err } - Advertencias: { gv_cnt_warn } - | &&
            |Incompletos: { gv_cnt_inc } - OK: { gv_cnt_ok }</div>| &&
            |<table style="border-collapse:collapse;width:100%;font-size:12px;">| &&
            |<tr style="background:#354a5f;color:#ffffff;">| &&
            |<th style="{ lc_td }text-align:left;">Transaccion</th>| &&
            |<th style="{ lc_td }text-align:left;">Chequeo</th>| &&
            |<th style="{ lc_td }text-align:left;">Estado</th>| &&
            |<th style="{ lc_td }text-align:left;">Resultado</th>| &&
            |<th style="{ lc_td }text-align:left;">Detalle</th></tr>|.

* Mismo orden que el ALV; transaccion y chequeo solo en la 1ra fila
  lt_res = gt_result.
  SORT lt_res BY seq tcode checkdesc rowno.
  LOOP AT lt_res INTO ls_res.
    lv_n = lv_n + 1.
    IF lv_n MOD 2 = 0.
      lv_zebra = 'background:#f6f6f6;'.
    ELSE.
      lv_zebra = 'background:#ffffff;'.
    ENDIF.

    lv_key = |{ ls_res-tcode }{ ls_res-checkdesc }|.
    IF lv_key = lv_last.
      CLEAR: lv_tcode, lv_desc.
    ELSE.
      lv_tcode = ls_res-tcode.
      lv_desc  = ls_res-checkdesc.
      lv_last  = lv_key.
    ENDIF.
    lv_sum = ls_res-summary.
    lv_det = ls_res-detail.
    PERFORM html_escape CHANGING: lv_tcode, lv_desc, lv_sum, lv_det.
    PERFORM status_colors USING ls_res-status CHANGING lv_bg lv_fg.

    lv_html = |{ lv_html }<tr style="{ lv_zebra }">| &&
              |<td style="{ lc_td }font-weight:bold;">{ lv_tcode }</td>| &&
              |<td style="{ lc_td }">{ lv_desc }</td>| &&
              |<td style="{ lc_td }background:{ lv_bg };color:{ lv_fg };font-weight:bold;white-space:nowrap;">| &&
              |{ ls_res-status_txt }</td>| &&
              |<td style="{ lc_td }">{ lv_sum }</td>| &&
              |<td style="{ lc_td }color:#444;">{ lv_det }</td></tr>|.
  ENDLOOP.

  lv_html = |{ lv_html }</table>| &&
            |<p style="color:#888;font-size:11px;margin-top:12px;">Generado por | &&
            |{ sy-repid } - usuario { sy-uname }</p></body></html>|.

* String -> tabla de lineas de 255 caracteres
  REFRESH pt_soli.
  lv_len = strlen( lv_html ).
  lv_off = 0.
  WHILE lv_off < lv_len.
    CLEAR ls_soli.
    IF lv_len - lv_off > 255.
      ls_soli-line = lv_html+lv_off(255).
    ELSE.
      ls_soli-line = lv_html+lv_off.
    ENDIF.
    APPEND ls_soli TO pt_soli.
    lv_off = lv_off + 255.
  ENDWHILE.
ENDFORM.

FORM send_mail.
  DATA: lo_send   TYPE REF TO cl_bcs,
        lo_doc    TYPE REF TO cl_document_bcs,
        lo_rcp    TYPE REF TO if_recipient_bcs,
        lo_sender TYPE REF TO cl_cam_address_bcs,
        lx_bcs    TYPE REF TO cx_bcs,
        lt_soli   TYPE soli_tab,
        lv_subj   TYPE so_obj_des,
        lv_gtext  TYPE c LENGTH 12,
        lv_sent   TYPE os_boolean,
        lv_to     TYPE string,
        lv_text   TYPE string,
        lv_sum    TYPE string,
        lv_det    TYPE string.

* Condicion de envio
  IF r_merr = 'X' AND gv_global <> gc_err.
    PERFORM add_result USING 'MAIL' gc_ok 'No se envio: no hubo errores'
      'Opcion elegida: enviar solo si hay errores'.
    RETURN.
  ENDIF.
  IF r_mwarn = 'X' AND gv_global = gc_ok.
    PERFORM add_result USING 'MAIL' gc_ok 'No se envio: todo OK'
      'Opcion elegida: enviar solo si hay errores, advertencias o incompletos'.
    RETURN.
  ENDIF.

  PERFORM status_text USING gv_global CHANGING lv_gtext.
  IF p_msubj IS INITIAL.
    lv_subj = |Health check { sy-sysid }/{ sy-mandt } { sy-datum DATE = USER } - { lv_gtext }|.
  ELSE.
    lv_subj = |{ p_msubj } - { lv_gtext }|.
  ENDIF.

  PERFORM build_mail_html CHANGING lt_soli.

  TRY.
      lo_send = cl_bcs=>create_persistent( ).
      lo_doc = cl_document_bcs=>create_document(
                 i_type    = 'HTM'
                 i_text    = lt_soli
                 i_subject = lv_subj ).
      lo_send->set_document( lo_doc ).

      IF p_mfrom IS NOT INITIAL.
        lo_sender = cl_cam_address_bcs=>create_internet_address( p_mfrom ).
        lo_send->set_sender( lo_sender ).
      ENDIF.

      LOOP AT s_mto WHERE sign = 'I' AND low IS NOT INITIAL.
        lo_rcp = cl_cam_address_bcs=>create_internet_address( s_mto-low ).
        lo_send->add_recipient( i_recipient = lo_rcp i_express = 'X' ).
        IF lv_to IS INITIAL.
          lv_to = s_mto-low.
        ELSE.
          lv_to = |{ lv_to }, { s_mto-low }|.
        ENDIF.
      ENDLOOP.
      LOOP AT s_mcc WHERE sign = 'I' AND low IS NOT INITIAL.
        lo_rcp = cl_cam_address_bcs=>create_internet_address( s_mcc-low ).
        lo_send->add_recipient( i_recipient = lo_rcp i_copy = 'X' ).
      ENDLOOP.

      lo_send->set_send_immediately( p_mimm ).
      lv_sent = lo_send->send( i_with_error_screen = space ).
      COMMIT WORK.

      IF lv_sent = 'X'.
        lv_sum = |Mail generado para { lv_to }|.
        IF p_mimm = 'X'.
          lv_det = |Asunto: { lv_subj } - salida inmediata; ver estado en SOST|.
        ELSE.
          lv_det = |Asunto: { lv_subj } - queda en cola hasta el proximo job de SCOT (SOST)|.
        ENDIF.
        PERFORM add_result USING 'MAIL' gc_ok lv_sum lv_det.
      ELSE.
        PERFORM add_result USING 'MAIL' gc_err 'No se pudo generar el mail'
          'CL_BCS->SEND devolvio falso. Revisar SOST / SCOT'.
      ENDIF.
    CATCH cx_bcs INTO lx_bcs.
      lv_text = lx_bcs->get_text( ).
      PERFORM add_result USING 'MAIL' gc_err 'Error al enviar el mail' lv_text.
  ENDTRY.
ENDFORM.

*======================================================================*
* Estado global y ALV
*======================================================================*
FORM calculate_global.
  DATA: ls_res  TYPE ty_result,
        lv_err  TYPE i,
        lv_warn TYPE i,
        lv_inc  TYPE i,
        lv_msg  TYPE string.

  CLEAR gv_cnt_ok.
  LOOP AT gt_result INTO ls_res.
    CASE ls_res-status.
      WHEN gc_err.  lv_err  = lv_err + 1.
      WHEN gc_warn. lv_warn = lv_warn + 1.
      WHEN gc_inc.  lv_inc  = lv_inc + 1.
      WHEN gc_ok.   gv_cnt_ok = gv_cnt_ok + 1.
    ENDCASE.
  ENDLOOP.
  gv_cnt_err  = lv_err.
  gv_cnt_warn = lv_warn.
  gv_cnt_inc  = lv_inc.

  IF lv_err > 0.
    gv_global = gc_err.
  ELSEIF lv_warn > 0.
    gv_global = gc_warn.
  ELSEIF lv_inc > 0.
    gv_global = gc_inc.
  ELSE.
    gv_global = gc_ok.
  ENDIF.

  IF sy-batch = 'X'.
    lv_msg = |Estado general: { gv_global } (E:{ lv_err } W:{ lv_warn } I:{ lv_inc })|.
    MESSAGE lv_msg TYPE 'S'.
  ENDIF.
ENDFORM.

FORM add_fc USING p_field TYPE any
                  p_text  TYPE any
                  p_len   TYPE i
                  p_key   TYPE c
                  p_icon  TYPE c
                  p_tech  TYPE c.
  DATA ls_fc TYPE slis_fieldcat_alv.

  ls_fc-fieldname    = p_field.
  ls_fc-seltext_l    = p_text.
  ls_fc-seltext_m    = p_text.
  ls_fc-seltext_s    = p_text.
  ls_fc-reptext_ddic = p_text.
  ls_fc-ddictxt      = 'L'.
  ls_fc-outputlen    = p_len.
  ls_fc-key          = p_key.
  ls_fc-icon         = p_icon.
  ls_fc-tech         = p_tech.
  IF p_icon = 'X'.
    ls_fc-just = 'C'.
  ENDIF.
  APPEND ls_fc TO gt_fieldcat.
ENDFORM.

FORM build_fieldcat.
  DATA ls_sort TYPE slis_sortinfo_alv.

  REFRESH: gt_fieldcat, gt_sort.
*                    campo         titulo          largo clave icono tecnico
  PERFORM add_fc USING 'ICON'       ' '              3   ' ' 'X' ' '.
  PERFORM add_fc USING 'TCODE'      'Transaccion'   10   'X' ' ' ' '.
  PERFORM add_fc USING 'CHECKDESC'  'Chequeo'       27   'X' ' ' ' '.
  PERFORM add_fc USING 'STATUS_TXT' 'Estado'        11   ' ' ' ' ' '.
  PERFORM add_fc USING 'SUMMARY'    'Resultado'     55   ' ' ' ' ' '.
  PERFORM add_fc USING 'DETAIL'     'Detalle'      110   ' ' ' ' ' '.
  PERFORM add_fc USING 'SEQ'        'Orden'          2   ' ' ' ' 'X'.
  PERFORM add_fc USING 'ROWNO'      'Fila'           4   ' ' ' ' 'X'.
  PERFORM add_fc USING 'CONTROL'    'Control'       15   ' ' ' ' 'X'.
  PERFORM add_fc USING 'STATUS'     'Estado int.'   10   ' ' ' ' 'X'.

* Orden por chequeo; transaccion y chequeo se muestran una sola vez
  ls_sort-spos = 1. ls_sort-fieldname = 'SEQ'.       ls_sort-up = 'X'. APPEND ls_sort TO gt_sort.
  ls_sort-spos = 2. ls_sort-fieldname = 'TCODE'.     ls_sort-up = 'X'. APPEND ls_sort TO gt_sort.
  ls_sort-spos = 3. ls_sort-fieldname = 'CHECKDESC'. ls_sort-up = 'X'. APPEND ls_sort TO gt_sort.
  ls_sort-spos = 4. ls_sort-fieldname = 'ROWNO'.     ls_sort-up = 'X'. APPEND ls_sort TO gt_sort.

  CLEAR gs_layout.
  gs_layout-zebra            = 'X'.
  gs_layout-coltab_fieldname = 'CELLCOLOR'.
  gs_layout-window_titlebar  = 'Health check diario'.
ENDFORM.

FORM status_text USING p_status TYPE c CHANGING p_text TYPE c.
  CASE p_status.
    WHEN gc_ok.   p_text = 'OK'.
    WHEN gc_warn. p_text = 'ADVERTENCIA'.
    WHEN gc_err.  p_text = 'ERROR'.
    WHEN OTHERS.  p_text = 'INCOMPLETO'.
  ENDCASE.
ENDFORM.

*----------------------------------------------------------------------*
* Encabezado en pantalla (HTML)
*----------------------------------------------------------------------*
FORM html_top_of_page USING p_doc TYPE REF TO cl_dd_document.
  DATA: lv_txt   TYPE sdydo_text_element,
        lv_icon  TYPE iconname,
        lv_gtext TYPE c LENGTH 12.

  PERFORM status_text USING gv_global CHANGING lv_gtext.

  lv_txt = 'SAP Daily Health Check'.
  CALL METHOD p_doc->add_text
    EXPORTING
      text      = lv_txt
      sap_style = cl_dd_area=>heading.
  CALL METHOD p_doc->new_line.

  lv_txt = |Sistema { sy-sysid }   -   Mandante { sy-mandt }   -   Host { sy-host }   -   | &&
           |{ sy-datum DATE = USER } { sy-uzeit TIME = USER }|.
  CALL METHOD p_doc->add_text
    EXPORTING
      text = lv_txt.
  CALL METHOD p_doc->new_line.
  CALL METHOD p_doc->new_line.

  CASE gv_global.
    WHEN gc_ok.   lv_icon = 'ICON_GREEN_LIGHT'.
    WHEN gc_warn. lv_icon = 'ICON_YELLOW_LIGHT'.
    WHEN gc_err.  lv_icon = 'ICON_RED_LIGHT'.
    WHEN OTHERS.  lv_icon = 'ICON_INFORMATION'.
  ENDCASE.
  CALL METHOD p_doc->add_icon
    EXPORTING
      sap_icon = lv_icon.

  lv_txt = |Estado general: { lv_gtext }|.
  CALL METHOD p_doc->add_text
    EXPORTING
      text         = lv_txt
      sap_emphasis = cl_dd_area=>strong.
  CALL METHOD p_doc->add_gap
    EXPORTING
      width = 8.

  lv_txt = |Errores: { gv_cnt_err }     Advertencias: { gv_cnt_warn }     | &&
           |Incompletos: { gv_cnt_inc }     OK: { gv_cnt_ok }|.
  CALL METHOD p_doc->add_text
    EXPORTING
      text = lv_txt.
ENDFORM.

*----------------------------------------------------------------------*
* Encabezado para impresion / spool del job
*----------------------------------------------------------------------*
FORM top_of_page.
  DATA: lt_head  TYPE slis_t_listheader,
        ls_head  TYPE slis_listheader,
        lv_gtext TYPE c LENGTH 12.

  PERFORM status_text USING gv_global CHANGING lv_gtext.

  ls_head-typ  = 'H'.
  ls_head-info = 'SAP Daily Health Check'.
  APPEND ls_head TO lt_head.

  CLEAR ls_head.
  ls_head-typ  = 'S'.
  ls_head-key  = 'Sistema:'.
  ls_head-info = |{ sy-sysid } / { sy-mandt }  ({ sy-host })|.
  APPEND ls_head TO lt_head.

  ls_head-key  = 'Fecha:'.
  ls_head-info = |{ sy-datum DATE = USER } { sy-uzeit TIME = USER }|.
  APPEND ls_head TO lt_head.

  ls_head-key  = 'Estado general:'.
  ls_head-info = lv_gtext.
  APPEND ls_head TO lt_head.

  ls_head-key  = 'Resumen:'.
  ls_head-info = |Errores { gv_cnt_err } - Advertencias { gv_cnt_warn } - | &&
                 |Incompletos { gv_cnt_inc } - OK { gv_cnt_ok }|.
  APPEND ls_head TO lt_head.

  CALL FUNCTION 'REUSE_ALV_COMMENTARY_WRITE'
    EXPORTING
      it_list_commentary = lt_head.
ENDFORM.

FORM display_report.
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program          = sy-repid
      i_callback_html_top_of_page = 'HTML_TOP_OF_PAGE'
      i_callback_top_of_page      = 'TOP_OF_PAGE'
      is_layout                   = gs_layout
      it_fieldcat                 = gt_fieldcat
      it_sort                     = gt_sort
      i_save                      = 'A'
    TABLES
      t_outtab                    = gt_result
    EXCEPTIONS
      program_error               = 1
      OTHERS                      = 2.

  IF sy-subrc <> 0.
    MESSAGE 'Error al generar el reporte ALV' TYPE 'I'.
  ENDIF.
ENDFORM.
