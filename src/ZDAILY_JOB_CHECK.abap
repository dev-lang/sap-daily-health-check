*&---------------------------------------------------------------------*
*& Report  ZDAILY_JOB_CHECK
*&
*& Control diario de jobs de fondo (SM37), un chequeo por status:
*&   Progr.     P  programados (no liberados)
*&   Liberado   S  liberados (aviso si su inicio previsto ya paso)
*&   Listo      Y  esperando un WP de fondo libre
*&   Activa     R  en ejecucion
*&   Finaliz.   F  terminados bien, desde una fecha/hora
*&   Cancelado  A  terminados con error, desde una fecha/hora
*& Por defecto se ejecutan Activa y Cancelado.
*&
*& Salida ALV tipo tablero y envio opcional por mail (tabla HTML en el
*& cuerpo, via CL_BCS / SAPconnect), igual que ZDAILY_HEALTH_CHECK.
*&---------------------------------------------------------------------*
REPORT zdaily_job_check LINE-SIZE 255.

TYPE-POOLS: slis, abap, icon.

*----------------------------------------------------------------------*
* Pantalla de seleccion con 3 pestanas: Chequeos / Parametros / Mail
*  Una variante guarda las tres, pero SAP solo incluye las pestanas que
*  se abrieron antes de grabarla.
*  Ojo: los campos TYPE i ocupan hasta la columna ~45; las unidades van
*  en la 48 para no superponerse (sino da GEN_SELECTION_SCREEN_ERROR).
*----------------------------------------------------------------------*
TABLES sscrfields.
DATA: gv_email TYPE ad_smtpadr,            "referencia para S_MTO / S_MCC
      gv_jobn  TYPE tbtco-jobname.         "referencia para S_JOBN

*--- Pestana 1: chequeos a ejecutar -----------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 101 AS SUBSCREEN.
SELECTION-SCREEN BEGIN OF BLOCK b_chk WITH FRAME TITLE t_chk.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_sched AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN COMMENT 4(9) k_sched FOR FIELD x_sched.
SELECTION-SCREEN COMMENT 14(50) d_sched.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_rel AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN COMMENT 4(9) k_rel FOR FIELD x_rel.
SELECTION-SCREEN COMMENT 14(50) d_rel.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_ready AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN COMMENT 4(9) k_ready FOR FIELD x_ready.
SELECTION-SCREEN COMMENT 14(50) d_ready.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_act AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_act FOR FIELD x_act.
SELECTION-SCREEN COMMENT 14(50) d_act.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_fin AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN COMMENT 4(9) k_fin FOR FIELD x_fin.
SELECTION-SCREEN COMMENT 14(50) d_fin.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_canc AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_canc FOR FIELD x_canc.
SELECTION-SCREEN COMMENT 14(50) d_canc.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_chk.
SELECTION-SCREEN END OF SCREEN 101.

*--- Pestana 2: parametros ---------------------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 102 AS SUBSCREEN.
SELECTION-SCREEN BEGIN OF BLOCK b_act WITH FRAME TITLE t_act.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_maxrm FOR FIELD p_maxrm.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_maxrm TYPE i DEFAULT 60.
SELECTION-SCREEN COMMENT 48(24) u_maxrm.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_readm FOR FIELD p_readm.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_readm TYPE i DEFAULT 10.
SELECTION-SCREEN COMMENT 48(24) u_readm.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_act.

SELECTION-SCREEN BEGIN OF BLOCK b_can WITH FRAME TITLE t_can.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_cdat FOR FIELD p_cdat.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_cdat TYPE sy-datum.           "DATS: F4 con calendario
SELECTION-SCREEN POSITION 46.
PARAMETERS p_ctim TYPE sy-uzeit.           "TIMS: F4 de hora
SELECTION-SCREEN COMMENT 57(16) u_cdat.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_log AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 36(36) c_log FOR FIELD p_log.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_can.

SELECTION-SCREEN BEGIN OF BLOCK b_flt WITH FRAME TITLE t_flt.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_jobn FOR FIELD s_jobn.
SELECTION-SCREEN POSITION 33.
SELECT-OPTIONS s_jobn FOR gv_jobn NO INTERVALS VISIBLE LENGTH 24.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_nosap AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN COMMENT 36(36) c_nosap FOR FIELD p_nosap.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_flt.
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

*--- Pantalla 1000: las tres pestanas ----------------------------------*
SELECTION-SCREEN BEGIN OF TABBED BLOCK tabs FOR 24 LINES.
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

TYPES: BEGIN OF ty_job,
         jobname   TYPE tbtco-jobname,
         jobcount  TYPE tbtco-jobcount,
         status    TYPE tbtco-status,
         sdlstrtdt TYPE tbtco-sdlstrtdt,
         sdlstrttm TYPE tbtco-sdlstrttm,
         strtdate  TYPE tbtco-strtdate,
         strttime  TYPE tbtco-strttime,
         enddate   TYPE tbtco-enddate,
         endtime   TYPE tbtco-endtime,
         sdluname  TYPE tbtco-sdluname,
         reaxserver TYPE tbtco-reaxserver,
         authckman TYPE tbtco-authckman,
       END OF ty_job.

CONSTANTS: gc_ok    TYPE c LENGTH 10 VALUE 'OK',
           gc_warn  TYPE c LENGTH 10 VALUE 'WARNING',
           gc_err   TYPE c LENGTH 10 VALUE 'ERROR',
           gc_inc   TYPE c LENGTH 10 VALUE 'INCOMPLETO',
           gc_title TYPE c LENGTH 30 VALUE 'SAP Daily Job Check'.

DATA: gt_result   TYPE STANDARD TABLE OF ty_result,
      gt_fieldcat TYPE slis_t_fieldcat_alv,
      gs_layout   TYPE slis_layout_alv,
      gt_sort     TYPE slis_t_sortinfo_alv,
      gv_global   TYPE c LENGTH 10,
      gv_rowno    TYPE i,
      gv_cnt_err  TYPE i,
      gv_cnt_warn TYPE i,
      gv_cnt_inc  TYPE i,
      gv_cnt_ok   TYPE i,
      gv_own_jobname  TYPE tbtco-jobname,  "job propio (si corre en fondo)
      gv_own_jobcount TYPE tbtco-jobcount.

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
  t_chk  = 'Status de SM37 a revisar'.
  k_sched = 'Progr.'.    d_sched = 'Jobs programados, no liberados'.
  k_rel   = 'Liberado'.  d_rel   = 'Jobs liberados (aviso si el inicio ya paso)'.
  k_ready = 'Listo'.     d_ready = 'Jobs esperando un WP de fondo libre'.
  k_act   = 'Activa'.    d_act   = 'Jobs en ejecucion'.
  k_fin   = 'Finaliz.'.  d_fin   = 'Jobs terminados bien (desde fecha/hora)'.
  k_canc  = 'Cancelado'. d_canc  = 'Jobs cancelados (desde fecha/hora)'.

* Pestana Parametros
  t_act   = 'Activa / Listo / Liberado'.
  c_maxrm = 'Activa: avisar si corre mas de'.
  u_maxrm = 'minutos'.
  c_readm = 'Inicio demorado: avisar tras'.
  u_readm = 'minutos'.

  t_can   = 'Finalizados y cancelados'.
  c_cdat  = 'Buscar terminados desde'.
  u_cdat  = 'vacio = ult. 24h'.
  c_log   = 'Cancelados: mostrar error del log'.

  t_flt   = 'Filtros'.
  c_jobn  = 'Nombre de job (ej. Z*)'.
  c_nosap = 'Excluir jobs estandar SAP_*'.

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

* Cancelados: por defecto, ultimas 24 h
  p_cdat = sy-datum - 1.
  p_ctim = sy-uzeit.

*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
*----------------------------------------------------------------------*
  CASE sscrfields-ucomm.
    WHEN 'ONLI' OR 'PRIN' OR 'SJOB'.
      IF x_sched IS INITIAL AND x_rel IS INITIAL AND x_ready IS INITIAL
         AND x_act IS INITIAL AND x_fin IS INITIAL AND x_canc IS INITIAL.
        MESSAGE 'Seleccione al menos un chequeo (pestana Chequeos)' TYPE 'E'.
      ENDIF.
      IF p_mail = 'X' AND s_mto[] IS INITIAL.
        MESSAGE 'Indique al menos un destinatario (pestana Envio por mail)' TYPE 'E'.
      ENDIF.
  ENDCASE.

*----------------------------------------------------------------------*
START-OF-SELECTION.
*----------------------------------------------------------------------*
  PERFORM get_own_job.

* Mismo orden que los status de SM37
  IF x_sched = 'X'. PERFORM check_status USING 'P'. ENDIF.
  IF x_rel   = 'X'. PERFORM check_status USING 'S'. ENDIF.
  IF x_ready = 'X'. PERFORM check_status USING 'Y'. ENDIF.
  IF x_act   = 'X'. PERFORM check_status USING 'R'. ENDIF.
  IF x_fin   = 'X'. PERFORM check_status USING 'F'. ENDIF.
  IF x_canc  = 'X'. PERFORM check_status USING 'A'. ENDIF.

  PERFORM calculate_global.
  IF p_mail = 'X'.
    PERFORM send_mail.
    PERFORM calculate_global.         "incluye el resultado del envio
  ENDIF.
  PERFORM build_fieldcat.
  PERFORM display_report.

*======================================================================*
* Utilidades
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

  CASE ls_res-control.
    WHEN 'P'.
      ls_res-seq = 1.  ls_res-tcode = 'SM37'. ls_res-checkdesc = 'Programados (Progr.)'.
    WHEN 'S'.
      ls_res-seq = 2.  ls_res-tcode = 'SM37'. ls_res-checkdesc = 'Liberados'.
    WHEN 'Y'.
      ls_res-seq = 3.  ls_res-tcode = 'SM37'. ls_res-checkdesc = 'Listos (esperando WP)'.
    WHEN 'R'.
      ls_res-seq = 4.  ls_res-tcode = 'SM37'. ls_res-checkdesc = 'Activos (en ejecucion)'.
    WHEN 'F'.
      ls_res-seq = 5.  ls_res-tcode = 'SM37'. ls_res-checkdesc = 'Finalizados'.
    WHEN 'A'.
      ls_res-seq = 6.  ls_res-tcode = 'SM37'. ls_res-checkdesc = 'Cancelados'.
    WHEN 'MAIL'.
      ls_res-seq = 9.  ls_res-tcode = 'SOST'. ls_res-checkdesc = 'Envio del reporte por mail'.
    WHEN OTHERS.
      ls_res-seq = 99. ls_res-tcode = ls_res-control. ls_res-checkdesc = ls_res-control.
  ENDCASE.

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
  CONCATENATE lv_icon(3) '\Q' ls_res-status_txt '@' INTO ls_res-icon.

  ls_col-fieldname = 'STATUS_TXT'.
  ls_col-color-int = 0.
  APPEND ls_col TO ls_res-cellcolor.

  APPEND ls_res TO gt_result.
ENDFORM.

* "2 h 05 min" a partir de segundos
FORM fmt_duration USING p_sec TYPE i CHANGING p_txt TYPE string.
  DATA: lv_h TYPE i,
        lv_m TYPE i,
        lv_d TYPE i.

  IF p_sec < 0.
    p_txt = '?'.
    RETURN.
  ENDIF.
  lv_d = p_sec DIV 86400.
  lv_h = ( p_sec MOD 86400 ) DIV 3600.
  lv_m = ( p_sec MOD 3600 ) DIV 60.
  IF lv_d > 0.
    p_txt = |{ lv_d } d { lv_h } h { lv_m } min|.
  ELSEIF lv_h > 0.
    p_txt = |{ lv_h } h { lv_m } min|.
  ELSE.
    p_txt = |{ lv_m } min|.
  ENDIF.
ENDFORM.

* Programa del primer paso y usuario de ejecucion
FORM job_step USING ps_job TYPE ty_job CHANGING p_prog TYPE string p_user TYPE string.
  DATA: lv_prog TYPE tbtcp-progname,
        lv_user TYPE tbtcp-authcknam.

  CLEAR: p_prog, p_user.
  SELECT SINGLE progname authcknam FROM tbtcp INTO (lv_prog, lv_user)
    WHERE jobname   = ps_job-jobname
      AND jobcount  = ps_job-jobcount
      AND stepcount = 1.
  IF sy-subrc = 0.
    p_prog = lv_prog.
    p_user = lv_user.
  ENDIF.
ENDFORM.

* Job propio (si el programa corre como job, no se lista a si mismo)
FORM get_own_job.
  CONSTANTS lc_fm TYPE c LENGTH 30 VALUE 'GET_JOB_RUNTIME_INFO'.
  DATA: lt_ptab  TYPE abap_func_parmbind_tab,
        lr_name  TYPE REF TO data,
        lr_count TYPE REF TO data,
        lv_found TYPE c LENGTH 1,
        lv_subrc TYPE i,
        lv_msg   TYPE c LENGTH 255.
  FIELD-SYMBOLS <lv_v> TYPE any.

  CLEAR: gv_own_jobname, gv_own_jobcount.
  IF sy-batch IS INITIAL.
    RETURN.
  ENDIF.
  PERFORM fm_param USING lc_fm 'JOBNAME'  'STRING' CHANGING lt_ptab lr_name  lv_found.
  PERFORM fm_param USING lc_fm 'JOBCOUNT' 'STRING' CHANGING lt_ptab lr_count lv_found.
  IF lr_name IS NOT BOUND OR lr_count IS NOT BOUND.
    RETURN.
  ENDIF.
  PERFORM fm_call USING lc_fm CHANGING lt_ptab lv_subrc lv_msg.
  IF lv_subrc = 0.
    ASSIGN lr_name->* TO <lv_v>.
    gv_own_jobname = <lv_v>.
    ASSIGN lr_count->* TO <lv_v>.
    gv_own_jobcount = <lv_v>.
  ENDIF.
ENDFORM.

* Mensaje de error real del log del job (BP_JOBLOG_READ)
*  El log de un cancelado termina con "Job cancelled" (o "Job cancelled
*  after system exception ..."), que no dice la causa. Se toma el ultimo
*  mensaje de error (E/A/X) que NO sea esa linea generica; si no hay
*  otro, se muestra la generica.
FORM job_error USING ps_job TYPE ty_job CHANGING p_text TYPE string.
  CONSTANTS lc_fm TYPE c LENGTH 30 VALUE 'BP_JOBLOG_READ'.
  DATA: lt_ptab    TYPE abap_func_parmbind_tab,
        lr_log     TYPE REF TO data,
        lv_found   TYPE c LENGTH 1,
        lv_subrc   TYPE i,
        lv_msg     TYPE c LENGTH 255,
        lv_type    TYPE string,
        lv_line    TYPE string,
        lv_last    TYPE string,
        lv_err     TYPE string,
        lv_generic TYPE string.
  FIELD-SYMBOLS: <lt_log> TYPE ANY TABLE,
                 <ls_log> TYPE any.

  CLEAR p_text.
  PERFORM fm_set   USING lc_fm 'CLIENT'   ps_job-authckman CHANGING lt_ptab lv_found.
  PERFORM fm_set   USING lc_fm 'JOBNAME'  ps_job-jobname   CHANGING lt_ptab lv_found.
  PERFORM fm_set   USING lc_fm 'JOBCOUNT' ps_job-jobcount  CHANGING lt_ptab lv_found.
  PERFORM fm_param USING lc_fm 'JOBLOGTBL' 'STRING' CHANGING lt_ptab lr_log lv_found.
  IF lr_log IS NOT BOUND.
    RETURN.
  ENDIF.
  PERFORM fm_call USING lc_fm CHANGING lt_ptab lv_subrc lv_msg.
  IF lv_subrc <> 0.
    p_text = '(log no disponible)'.
    RETURN.
  ENDIF.

  ASSIGN lr_log->* TO <lt_log>.
  LOOP AT <lt_log> ASSIGNING <ls_log>.
    PERFORM get_comp USING <ls_log> 'TEXT'    CHANGING lv_line.
    PERFORM get_comp USING <ls_log> 'MSGTYPE' CHANGING lv_type.
    IF lv_line IS INITIAL.
      CONTINUE.
    ENDIF.
    lv_last = lv_line.
    IF lv_type = 'E' OR lv_type = 'A' OR lv_type = 'X'.
*     Linea generica de cancelacion (ingles o espanol)
      IF lv_line CP 'Job cancel*' OR lv_line CP 'Job anulad*'.
        lv_generic = lv_line.
      ELSE.
        lv_err = lv_line.                 "queda el ultimo error real
      ENDIF.
    ENDIF.
  ENDLOOP.

  IF lv_err IS NOT INITIAL.
    p_text = lv_err.
  ELSEIF lv_generic IS NOT INITIAL.
    p_text = lv_generic.
  ELSE.
    p_text = lv_last.                     "ultima linea del log
  ENDIF.
ENDFORM.

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

FORM job_filtered USING ps_job TYPE ty_job CHANGING p_skip TYPE c.
  CLEAR p_skip.
  IF ps_job-jobname = gv_own_jobname AND ps_job-jobcount = gv_own_jobcount.
    p_skip = 'X'.                         "este mismo programa
  ELSEIF p_nosap = 'X' AND ps_job-jobname CP 'SAP_*'.
    p_skip = 'X'.
  ENDIF.
ENDFORM.

*======================================================================*
* Chequeo generico por status de SM37 (TBTCO-STATUS)
*  P Programado : informativo (no liberado)
*  S Liberado   : aviso si el inicio previsto ya paso hace > P_READM min
*  Y Listo      : aviso si espera un WP hace > P_READM min
*  R Activo     : aviso si corre hace > P_MAXRM min
*  F Finalizado : informativo, terminados desde P_CDAT / P_CTIM
*  A Cancelado  : error, terminados desde P_CDAT / P_CTIM (+ error del log)
*  Se muestran como maximo 200 jobs por status.
*======================================================================*
FORM check_status USING p_stat TYPE c.
  CONSTANTS lc_max TYPE i VALUE 200.

  DATA: lt_job    TYPE STANDARD TABLE OF ty_job,
        ls_job    TYPE ty_job,
        lv_skip   TYPE c LENGTH 1,
        lv_from   TYPE d,
        lv_ftime  TYPE t,
        lv_secs   TYPE i,
        lv_dur    TYPE string,
        lv_prog   TYPE string,
        lv_user   TYPE string,
        lv_err    TYPE string,
        lv_n      TYPE i,
        lv_nwarn  TYPE i,
        lv_name   TYPE string,
        lv_sum    TYPE string,
        lv_det    TYPE string,
        lv_head   TYPE c LENGTH 10,
        lt_rows   TYPE STANDARD TABLE OF ty_result,
        ls_row    TYPE ty_result.

* Periodo para finalizados / cancelados
  IF p_cdat IS INITIAL.
    lv_from  = sy-datum - 1.
    lv_ftime = sy-uzeit.
  ELSE.
    lv_from  = p_cdat.
    lv_ftime = p_ctim.
  ENDIF.

  IF p_stat = 'F' OR p_stat = 'A'.
    SELECT jobname jobcount status sdlstrtdt sdlstrttm strtdate strttime
           enddate endtime sdluname reaxserver authckman
      FROM tbtco INTO TABLE lt_job
      WHERE status   = p_stat
        AND enddate >= lv_from
        AND jobname IN s_jobn.
    SORT lt_job BY enddate DESCENDING endtime DESCENDING.
  ELSE.
    SELECT jobname jobcount status sdlstrtdt sdlstrttm strtdate strttime
           enddate endtime sdluname reaxserver authckman
      FROM tbtco INTO TABLE lt_job
      WHERE status = p_stat
        AND jobname IN s_jobn.
    SORT lt_job BY sdlstrtdt sdlstrttm strtdate strttime.
  ENDIF.

  LOOP AT lt_job INTO ls_job.
    IF ( p_stat = 'F' OR p_stat = 'A' )
       AND ls_job-enddate = lv_from AND ls_job-endtime < lv_ftime.
      CONTINUE.
    ENDIF.
    PERFORM job_filtered USING ls_job CHANGING lv_skip.
    IF lv_skip = 'X'.
      CONTINUE.
    ENDIF.
    lv_n = lv_n + 1.
    IF lv_n > lc_max.
      CONTINUE.                           "solo se cuentan
    ENDIF.

    PERFORM job_step USING ls_job CHANGING lv_prog lv_user.
    CLEAR ls_row.
    ls_row-status = gc_ok.

    CASE p_stat.
      WHEN 'P'.
        ls_row-summary = |{ ls_job-jobname }: programado, sin liberar|.
        ls_row-detail  = |Programa: { lv_prog } - Usuario: { lv_user } - Creado por { ls_job-sdluname } | &&
                         |- Mandante { ls_job-authckman }|.

      WHEN 'S'.
        IF ls_job-sdlstrtdt IS INITIAL.
          ls_row-summary = |{ ls_job-jobname }: liberado, espera un evento|.
        ELSE.
          lv_secs = ( sy-datum - ls_job-sdlstrtdt ) * 86400 + ( sy-uzeit - ls_job-sdlstrttm ).
          IF lv_secs > p_readm * 60.
            PERFORM fmt_duration USING lv_secs CHANGING lv_dur.
            ls_row-status  = gc_warn.
            ls_row-summary = |{ ls_job-jobname }: liberado, su inicio paso hace { lv_dur } y no arranco|.
          ELSE.
            ls_row-summary = |{ ls_job-jobname }: liberado, inicia el | &&
                             |{ ls_job-sdlstrtdt DATE = USER } { ls_job-sdlstrttm TIME = USER }|.
          ENDIF.
        ENDIF.
        ls_row-detail = |Programa: { lv_prog } - Usuario: { lv_user } - Mandante { ls_job-authckman }|.

      WHEN 'Y'.
        IF ls_job-sdlstrtdt IS INITIAL.
          lv_secs = -1.
        ELSE.
          lv_secs = ( sy-datum - ls_job-sdlstrtdt ) * 86400 + ( sy-uzeit - ls_job-sdlstrttm ).
        ENDIF.
        PERFORM fmt_duration USING lv_secs CHANGING lv_dur.
        IF lv_secs > p_readm * 60.
          ls_row-status = gc_warn.
        ENDIF.
        ls_row-summary = |{ ls_job-jobname }: listo, esperando WP de fondo hace { lv_dur }|.
        ls_row-detail  = |Programa: { lv_prog } - Usuario: { lv_user } | &&
                         |- Inicio previsto: { ls_job-sdlstrtdt DATE = USER } { ls_job-sdlstrttm TIME = USER } | &&
                         |- Mandante { ls_job-authckman }|.

      WHEN 'R'.
        lv_secs = ( sy-datum - ls_job-strtdate ) * 86400 + ( sy-uzeit - ls_job-strttime ).
        PERFORM fmt_duration USING lv_secs CHANGING lv_dur.
        IF lv_secs > p_maxrm * 60.
          ls_row-status = gc_warn.
        ENDIF.
        ls_row-summary = |{ ls_job-jobname }: en ejecucion hace { lv_dur }|.
        ls_row-detail  = |Programa: { lv_prog } - Usuario: { lv_user } - Servidor: { ls_job-reaxserver } | &&
                         |- Inicio: { ls_job-strtdate DATE = USER } { ls_job-strttime TIME = USER } | &&
                         |- Mandante { ls_job-authckman }|.

      WHEN 'F'.
        lv_secs = ( ls_job-enddate - ls_job-strtdate ) * 86400 + ( ls_job-endtime - ls_job-strttime ).
        PERFORM fmt_duration USING lv_secs CHANGING lv_dur.
        ls_row-summary = |{ ls_job-jobname }: finalizado el { ls_job-enddate DATE = USER } | &&
                         |{ ls_job-endtime TIME = USER } (duro { lv_dur })|.
        ls_row-detail  = |Programa: { lv_prog } - Usuario: { lv_user } - Servidor: { ls_job-reaxserver } | &&
                         |- Mandante { ls_job-authckman }|.

      WHEN 'A'.
        ls_row-status  = gc_err.
        ls_row-summary = |{ ls_job-jobname }: cancelado el { ls_job-enddate DATE = USER } | &&
                         |{ ls_job-endtime TIME = USER }|.
        ls_row-detail  = |Programa: { lv_prog } - Usuario: { lv_user } - Servidor: { ls_job-reaxserver } | &&
                         |- Mandante { ls_job-authckman }|.
        IF p_log = 'X'.
          PERFORM job_error USING ls_job CHANGING lv_err.
          IF lv_err IS NOT INITIAL.
            ls_row-detail = |{ ls_row-detail } - Error: { lv_err }|.
          ENDIF.
        ENDIF.
    ENDCASE.

    IF ls_row-status <> gc_ok.
      lv_nwarn = lv_nwarn + 1.
    ENDIF.
    APPEND ls_row TO lt_rows.
  ENDLOOP.

* Fila de resumen
  CASE p_stat.
    WHEN 'P'. lv_name = 'programado(s) sin liberar'.
    WHEN 'S'. lv_name = 'liberado(s)'.
    WHEN 'Y'. lv_name = 'listo(s) esperando WP de fondo'.
    WHEN 'R'. lv_name = 'en ejecucion'.
    WHEN 'F'. lv_name = 'finalizado(s)'.
    WHEN 'A'. lv_name = 'cancelado(s)'.
  ENDCASE.
  lv_sum = |{ lv_n } job(s) { lv_name }|.
  lv_head = gc_ok.

  CASE p_stat.
    WHEN 'F' OR 'A'.
      lv_sum = |{ lv_sum } desde { lv_from DATE = USER } { lv_ftime TIME = USER }|.
      lv_det = |Periodo: { lv_from DATE = USER } { lv_ftime TIME = USER } a | &&
               |{ sy-datum DATE = USER } { sy-uzeit TIME = USER }|.
      IF p_stat = 'A' AND lv_n > 0.
        lv_head = gc_err.
      ENDIF.
    WHEN 'R'.
      lv_det = |Aviso si corre mas de { p_maxrm } min|.
    WHEN 'S' OR 'Y'.
      lv_det = |Aviso si el inicio se demora mas de { p_readm } min|.
    WHEN OTHERS.
      lv_det = 'Informativo'.
  ENDCASE.
  IF lv_nwarn > 0 AND lv_head = gc_ok.
    lv_head = gc_warn.
    lv_det  = |{ lv_nwarn } con aviso - { lv_det }|.
  ENDIF.
  IF lv_n > lc_max.
    lv_det = |{ lv_det } - se muestran { lc_max } de { lv_n }|.
  ENDIF.

  PERFORM add_result USING p_stat lv_head lv_sum lv_det.
  LOOP AT lt_rows INTO ls_row.
    PERFORM add_result USING p_stat ls_row-status ls_row-summary ls_row-detail.
  ENDLOOP.
ENDFORM.

*======================================================================*
* Llamadas dinamicas a FMs (tipos leidos de FUPARAREF)
*======================================================================*
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


*======================================================================*
* Envio del reporte por mail (pestana 3)
*======================================================================*
FORM status_text USING p_status TYPE c CHANGING p_text TYPE c.
  CASE p_status.
    WHEN gc_ok.   p_text = 'OK'.
    WHEN gc_warn. p_text = 'ADVERTENCIA'.
    WHEN gc_err.  p_text = 'ERROR'.
    WHEN OTHERS.  p_text = 'INCOMPLETO'.
  ENDCASE.
ENDFORM.

FORM status_colors USING p_status TYPE c CHANGING p_bg TYPE string p_fg TYPE string.
  CASE p_status.
    WHEN gc_ok.   p_bg = '#d4edda'. p_fg = '#155724'.
    WHEN gc_warn. p_bg = '#fff3cd'. p_fg = '#856404'.
    WHEN gc_err.  p_bg = '#f8d7da'. p_fg = '#721c24'.
    WHEN OTHERS.  p_bg = '#ffe5cc'. p_fg = '#8a4b08'.
  ENDCASE.
ENDFORM.

FORM html_escape CHANGING p_text TYPE string.
  REPLACE ALL OCCURRENCES OF '&' IN p_text WITH '&amp;'.
  REPLACE ALL OCCURRENCES OF '<' IN p_text WITH '&lt;'.
  REPLACE ALL OCCURRENCES OF '>' IN p_text WITH '&gt;'.
  REPLACE ALL OCCURRENCES OF '"' IN p_text WITH '&quot;'.
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
            |<h2 style="margin:0 0 4px 0;">{ gc_title }</h2>| &&
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
    lv_subj = |Jobs { sy-sysid }/{ sy-mandt } { sy-datum DATE = USER } - { lv_gtext }|.
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
  PERFORM add_fc USING 'SUMMARY'    'Resultado'    100   ' ' ' ' ' '.
  PERFORM add_fc USING 'DETAIL'     'Detalle'      255   ' ' ' ' ' '.
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
  gs_layout-colwidth_optimize = 'X'.          "ancho segun el contenido (sin cortar)
  gs_layout-window_titlebar  = gc_title.
ENDFORM.

FORM html_top_of_page USING p_doc TYPE REF TO cl_dd_document.
  DATA: lv_txt   TYPE sdydo_text_element,
        lv_icon  TYPE iconname,
        lv_gtext TYPE c LENGTH 12.

  PERFORM status_text USING gv_global CHANGING lv_gtext.

  lv_txt = gc_title.
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

FORM top_of_page.
  DATA: lt_head  TYPE slis_t_listheader,
        ls_head  TYPE slis_listheader,
        lv_gtext TYPE c LENGTH 12.

  PERFORM status_text USING gv_global CHANGING lv_gtext.

  ls_head-typ  = 'H'.
  ls_head-info = gc_title.
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

