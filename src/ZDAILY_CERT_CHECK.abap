*&---------------------------------------------------------------------*
*& Report  ZDAILY_CERT_CHECK
*&
*& Control diario de certificados (STRUST), con el mismo criterio que
*& el chequeo de certificados de ZDAILY_HEALTH_CHECK V2:
*&   - Lee los PSE del directorio sec de la instancia (DIR_INSTANCE).
*&   - Certificado propio y lista de confianza de cada PSE.
*&   - Mismo criterio para propios y de confianza: vencido = ERROR,
*&     vence dentro de P_CDIAS dias = WARNING (o ERROR si P_CERR > 0 y
*&     vence dentro de P_CERR dias), resto = OK.
*&   - PSE de System PKI (sap_system_pki*): fila informativa, no se leen.
*& Agrega a lo del V2: emisor, numero de serie, fecha desde,
*& autofirmado, filtro por PSE y opcion de mostrar solo los avisos.
*&
*& Salida ALV tipo tablero y envio opcional por mail (tabla HTML en el
*& cuerpo, via CL_BCS / SAPconnect), igual que los otros controles.
*& Las FMs SSFC_* se llaman en forma dinamica: si algo no existe o
*& cambia de interfaz, la fila queda INCOMPLETO en lugar de dar dump.
*&---------------------------------------------------------------------*
REPORT zdaily_cert_check LINE-SIZE 255.

TYPE-POOLS: slis, abap, icon.

*----------------------------------------------------------------------*
* Pantalla de seleccion con 3 pestanas: Chequeos / Parametros / Mail
*  Una variante guarda las tres, pero SAP solo incluye las pestanas que
*  se abrieron antes de grabarla.
*----------------------------------------------------------------------*
TABLES sscrfields.
DATA: gv_email TYPE ad_smtpadr,           "referencia para S_MTO / S_MCC
      gv_psenm TYPE c LENGTH 60.          "referencia para S_PSE

*--- Pestana 1: chequeos a ejecutar -----------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 101 AS SUBSCREEN.
SELECTION-SCREEN BEGIN OF BLOCK b_chk WITH FRAME TITLE t_chk.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_own AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_own FOR FIELD x_own.
SELECTION-SCREEN COMMENT 14(50) d_own.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_trust AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_trust FOR FIELD x_trust.
SELECTION-SCREEN COMMENT 14(50) d_trust.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS x_pki AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(9) k_pki FOR FIELD x_pki.
SELECTION-SCREEN COMMENT 14(50) d_pki.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_chk.
SELECTION-SCREEN END OF SCREEN 101.

*--- Pestana 2: parametros ---------------------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 102 AS SUBSCREEN.
SELECTION-SCREEN BEGIN OF BLOCK b_crit WITH FRAME TITLE t_crit.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_cdias FOR FIELD p_cdias.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_cdias TYPE i DEFAULT 30.
SELECTION-SCREEN COMMENT 48(24) u_cdias.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_cerr FOR FIELD p_cerr.
SELECTION-SCREEN POSITION 33.
PARAMETERS p_cerr TYPE i DEFAULT 0.
SELECTION-SCREEN COMMENT 48(30) u_cerr.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b_crit.

SELECTION-SCREEN BEGIN OF BLOCK b_flt WITH FRAME TITLE t_flt.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(31) c_pse FOR FIELD s_pse.
SELECTION-SCREEN POSITION 33.
SELECT-OPTIONS s_pse FOR gv_psenm NO INTERVALS VISIBLE LENGTH 30.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN COMMENT /1(70) c_psenot.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_okrow AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(60) c_okrow FOR FIELD p_okrow.
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
SELECTION-SCREEN BEGIN OF TABBED BLOCK tabs FOR 22 LINES.
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
         is_sum     TYPE c LENGTH 1,          "X = fila de resumen (no se cuenta)
       END OF ty_result.

* Totales para la fila de resumen
TYPES: BEGIN OF ty_tot,
         npse    TYPE i,     "PSE leidos
         npki    TYPE i,     "PSE de System PKI (no se leen)
         nskip   TYPE i,     "PSE fuera del filtro
         nown    TYPE i,     "certificados propios
         ntrust  TYPE i,     "certificados de confianza
         nexp    TYPE i,     "vencidos
         ncrit   TYPE i,     "dentro de P_CERR dias (Error)
         nsoon   TYPE i,     "dentro de P_CDIAS dias (Advertencia)
         nself   TYPE i,     "autofirmados
         ninc    TYPE i,     "no se pudieron leer / interpretar
         nextexp TYPE d,     "proximo vencimiento (no vencido)
         nextcn  TYPE string,
       END OF ty_tot.

CONSTANTS: gc_ok    TYPE c LENGTH 10 VALUE 'OK',
           gc_warn  TYPE c LENGTH 10 VALUE 'WARNING',
           gc_err   TYPE c LENGTH 10 VALUE 'ERROR',
           gc_inc   TYPE c LENGTH 10 VALUE 'INCOMPLETO',
           gc_title TYPE c LENGTH 30 VALUE 'SAP Daily Certificate Check'.

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
      gv_sumrow   TYPE c LENGTH 1,
      gs_tot      TYPE ty_tot,
      gv_secdir   TYPE epsf-epsdirnam.

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
  t_chk   = 'Certificados del directorio sec de la instancia'.
  k_own   = 'STRUST'. d_own   = 'Certificado propio de cada PSE'.
  k_trust = 'STRUST'. d_trust = 'Lista de certificados de confianza de cada PSE'.
  k_pki   = 'STRUST'. d_pki   = 'PSE de System PKI (informativo, no se leen)'.

* Pestana Parametros
  t_crit  = 'Criterio de estado (propios y de confianza)'.
  c_cdias = 'Advertencia si vence dentro de'.
  u_cdias = 'dias'.
  c_cerr  = 'Error si vence dentro de'.
  u_cerr  = 'dias (0 = solo vencidos)'.
  t_flt   = 'Filtros y salida'.
  c_pse   = 'PSE (archivo)'.
  c_psenot = 'Ej.: SAPSSL* o SAPSYS.pse. Vacio = todos los PSE del directorio sec.'.
  c_okrow = 'Mostrar tambien los certificados en OK'.

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

*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
*----------------------------------------------------------------------*
  CASE sscrfields-ucomm.
    WHEN 'ONLI' OR 'PRIN' OR 'SJOB'.
      IF x_own IS INITIAL AND x_trust IS INITIAL AND x_pki IS INITIAL.
        MESSAGE 'Seleccione al menos un chequeo (pestana Chequeos)' TYPE 'E'.
      ENDIF.
      IF p_cdias < 0 OR p_cerr < 0.
        MESSAGE 'Los dias de aviso no pueden ser negativos' TYPE 'E'.
      ENDIF.
      IF p_cerr > p_cdias.
        MESSAGE 'Los dias de Error no pueden superar a los de Advertencia' TYPE 'E'.
      ENDIF.
      IF p_mail = 'X' AND s_mto[] IS INITIAL.
        MESSAGE 'Indique al menos un destinatario (pestana Envio por mail)' TYPE 'E'.
      ENDIF.
  ENDCASE.

*----------------------------------------------------------------------*
START-OF-SELECTION.
*----------------------------------------------------------------------*
  PERFORM check_certificates.

  PERFORM calculate_global.
  IF p_mail = 'X'.
    PERFORM send_mail.
    PERFORM calculate_global.         "incluye el resultado del envio
  ENDIF.
  PERFORM build_fieldcat.
  PERFORM display_report.

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
  ls_res-is_sum  = gv_sumrow.
  ls_res-summary = p_summary.
  ls_res-detail  = p_detail.
  CONDENSE ls_res-summary.

  gv_rowno = gv_rowno + 1.
  ls_res-rowno = gv_rowno.

  CASE ls_res-control.
    WHEN 'RESUMEN'.
      ls_res-seq = 1.  ls_res-tcode = 'STRUST'. ls_res-checkdesc = 'Resumen de certificados'.
    WHEN 'PROPIOS'.
      ls_res-seq = 2.  ls_res-tcode = 'STRUST'. ls_res-checkdesc = 'Certificados propios'.
    WHEN 'CONFIANZA'.
      ls_res-seq = 3.  ls_res-tcode = 'STRUST'. ls_res-checkdesc = 'Certificados de confianza'.
    WHEN 'PKI'.
      ls_res-seq = 4.  ls_res-tcode = 'STRUST'. ls_res-checkdesc = 'PSE de System PKI'.
    WHEN 'MAIL'.
      ls_res-seq = 9.  ls_res-tcode = 'SOST'.   ls_res-checkdesc = 'Envio del reporte por mail'.
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

*----------------------------------------------------------------------*
* Fila de resumen: repite lo que ya cuentan las filas de cada
* certificado (o es informativa), asi que no se cuenta en el encabezado.
*----------------------------------------------------------------------*
FORM add_summary USING p_control TYPE any
                       p_status  TYPE any
                       p_summary TYPE any
                       p_detail  TYPE any.
  gv_sumrow = 'X'.
  PERFORM add_result USING p_control p_status p_summary p_detail.
  CLEAR gv_sumrow.
ENDFORM.

*----------------------------------------------------------------------*
* Fecha AAAAMMDD a partir de un texto de fecha de certificado
*  (se toman solo los digitos: AAAAMMDDhhmmss o AAMMDDhhmmss)
*----------------------------------------------------------------------*
FORM cert_date USING    p_text TYPE string
               CHANGING p_date TYPE d
                        p_ok   TYPE c.
  DATA: lv_txt TYPE string,
        lv_len TYPE i.

  CLEAR: p_date, p_ok.
  lv_txt = p_text.
  REPLACE ALL OCCURRENCES OF REGEX '[^0-9]' IN lv_txt WITH ''.
  lv_len = strlen( lv_txt ).
  IF lv_len >= 14.
    p_date = lv_txt(8).
    p_ok = 'X'.
  ELSEIF lv_len = 12.
    CONCATENATE '20' lv_txt(6) INTO lv_txt.
    p_date = lv_txt(8).
    p_ok = 'X'.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* Un certificado: CN, emisor, serie, validez y estado
*  Mismo criterio para propios y de confianza (V2):
*    vencido = ERROR
*    vence dentro de P_CERR dias (si P_CERR > 0) = ERROR
*    vence dentro de P_CDIAS dias = WARNING
*    resto = OK (la fila solo se muestra si P_OKROW = 'X')
*----------------------------------------------------------------------*
FORM eval_cert USING p_pse  TYPE any
                     p_own  TYPE c
                     p_cert TYPE xstring.
  CONSTANTS lc_fm TYPE c LENGTH 30 VALUE 'SSFC_PARSE_CERTIFICATE'.

  DATA: lt_ptab   TYPE abap_func_parmbind_tab,
        lr_subj   TYPE REF TO data,
        lr_to     TYPE REF TO data,
        lr_from   TYPE REF TO data,
        lr_issuer TYPE REF TO data,
        lr_serial TYPE REF TO data,
        lv_found  TYPE c LENGTH 1,
        lv_subrc  TYPE i,
        lv_msg    TYPE c LENGTH 255,
        lv_ctrl   TYPE c LENGTH 15,
        lv_kind   TYPE string,
        lv_subj   TYPE string,
        lv_to     TYPE string,
        lv_from   TYPE string,
        lv_issuer TYPE string,
        lv_serial TYPE string,
        lv_cn     TYPE string,
        lv_icn    TYPE string,
        lv_cmp1   TYPE string,
        lv_cmp2   TYPE string,
        lv_date   TYPE d,
        lv_dfrom  TYPE d,
        lv_ok     TYPE c LENGTH 1,
        lv_okf    TYPE c LENGTH 1,
        lv_self   TYPE c LENGTH 1,
        lv_days   TYPE i,
        lv_status TYPE c LENGTH 10,
        lv_sum    TYPE string,
        lv_det    TYPE string.

  FIELD-SYMBOLS <lv_val> TYPE any.

  IF p_own = 'X'.
    lv_ctrl = 'PROPIOS'.
    lv_kind = 'propio'.
  ELSE.
    lv_ctrl = 'CONFIANZA'.
    lv_kind = 'confianza'.
  ENDIF.

  PERFORM fm_set   USING lc_fm 'CERTIFICATE' p_cert CHANGING lt_ptab lv_found.
  PERFORM fm_param USING lc_fm 'SUBJECT' 'STRING' CHANGING lt_ptab lr_subj lv_found.
  PERFORM fm_param USING lc_fm 'VALIDTO' 'STRING' CHANGING lt_ptab lr_to lv_found.
  IF lr_subj IS NOT BOUND OR lr_to IS NOT BOUND.
    gs_tot-ninc = gs_tot-ninc + 1.
    lv_sum = |{ p_pse } ({ lv_kind }): no se pudo interpretar|.
    PERFORM add_result USING lv_ctrl gc_inc lv_sum
      'SSFC_PARSE_CERTIFICATE sin SUBJECT/VALIDTO'.
    RETURN.
  ENDIF.
* Opcionales: si el release no los tiene, simplemente no se muestran
  PERFORM fm_param USING lc_fm 'VALIDFROM' 'STRING' CHANGING lt_ptab lr_from lv_found.
  PERFORM fm_param USING lc_fm 'ISSUER'    'STRING' CHANGING lt_ptab lr_issuer lv_found.
  PERFORM fm_param USING lc_fm 'SERIALNO'  'STRING' CHANGING lt_ptab lr_serial lv_found.

  PERFORM fm_call USING lc_fm CHANGING lt_ptab lv_subrc lv_msg.
  IF lv_subrc <> 0.
    gs_tot-ninc = gs_tot-ninc + 1.
    lv_sum = |{ p_pse } ({ lv_kind }): no se pudo interpretar|.
    PERFORM add_result USING lv_ctrl gc_inc lv_sum lv_msg.
    RETURN.
  ENDIF.

  ASSIGN lr_subj->* TO <lv_val>. lv_subj = <lv_val>.
  ASSIGN lr_to->*   TO <lv_val>. lv_to   = <lv_val>.
  IF lr_from IS BOUND.
    ASSIGN lr_from->* TO <lv_val>. lv_from = <lv_val>.
  ENDIF.
  IF lr_issuer IS BOUND.
    ASSIGN lr_issuer->* TO <lv_val>. lv_issuer = <lv_val>.
  ENDIF.
  IF lr_serial IS BOUND.
    ASSIGN lr_serial->* TO <lv_val>. lv_serial = <lv_val>.
    CONDENSE lv_serial NO-GAPS.
  ENDIF.

  FIND REGEX 'CN=([^,]+)' IN lv_subj SUBMATCHES lv_cn.
  IF sy-subrc <> 0.
    lv_cn = lv_subj.
  ENDIF.
  IF lv_issuer IS NOT INITIAL.
    FIND REGEX 'CN=([^,]+)' IN lv_issuer SUBMATCHES lv_icn.
    IF sy-subrc <> 0.
      lv_icn = lv_issuer.
    ENDIF.
*   Autofirmado: emisor = subject (sin espacios ni mayusculas)
    lv_cmp1 = lv_issuer.
    lv_cmp2 = lv_subj.
    REPLACE ALL OCCURRENCES OF ` ` IN lv_cmp1 WITH ``.
    REPLACE ALL OCCURRENCES OF ` ` IN lv_cmp2 WITH ``.
    TRANSLATE lv_cmp1 TO UPPER CASE.
    TRANSLATE lv_cmp2 TO UPPER CASE.
    IF lv_cmp1 = lv_cmp2.
      lv_self = 'X'.
      gs_tot-nself = gs_tot-nself + 1.
    ENDIF.
  ENDIF.

  PERFORM cert_date USING lv_to CHANGING lv_date lv_ok.
  IF lv_ok IS INITIAL.
    gs_tot-ninc = gs_tot-ninc + 1.
    lv_sum = |{ p_pse } ({ lv_kind }): CN={ lv_cn }|.
    lv_det = |No se pudo interpretar la fecha de vencimiento: { lv_to }|.
    PERFORM add_result USING lv_ctrl gc_inc lv_sum lv_det.
    RETURN.
  ENDIF.
  IF lv_from IS NOT INITIAL.
    PERFORM cert_date USING lv_from CHANGING lv_dfrom lv_okf.
  ENDIF.

  lv_days = lv_date - sy-datum.
  IF lv_days < 0.
    lv_status = gc_err.
    gs_tot-nexp = gs_tot-nexp + 1.
  ELSEIF p_cerr > 0 AND lv_days <= p_cerr.
    lv_status = gc_err.
    gs_tot-ncrit = gs_tot-ncrit + 1.
  ELSEIF lv_days <= p_cdias.
    lv_status = gc_warn.
    gs_tot-nsoon = gs_tot-nsoon + 1.
  ELSE.
    lv_status = gc_ok.
  ENDIF.

* Proximo vencimiento (entre los no vencidos)
  IF lv_days >= 0.
    IF gs_tot-nextexp IS INITIAL OR lv_date < gs_tot-nextexp.
      gs_tot-nextexp = lv_date.
      gs_tot-nextcn  = |{ lv_cn } ({ p_pse })|.
    ENDIF.
  ENDIF.

  IF lv_status = gc_ok AND p_okrow IS INITIAL.
    RETURN.
  ENDIF.

  lv_sum = |{ p_pse } ({ lv_kind }): CN={ lv_cn }|.
  IF lv_days < 0.
    lv_det = |VENCIDO el { lv_date DATE = USER } (hace { abs( lv_days ) } dias)|.
  ELSE.
    lv_det = |Vence { lv_date DATE = USER } ({ lv_days } dias)|.
  ENDIF.
  IF lv_okf = 'X'.
    lv_det = |{ lv_det } - desde { lv_dfrom DATE = USER }|.
  ENDIF.
  IF lv_self = 'X'.
    lv_det = |{ lv_det } - autofirmado|.
  ELSEIF lv_icn IS NOT INITIAL.
    lv_det = |{ lv_det } - emisor: { lv_icn }|.
  ENDIF.
  IF lv_serial IS NOT INITIAL.
    lv_det = |{ lv_det } - serie: { lv_serial }|.
  ENDIF.
  lv_det = |{ lv_det } - { lv_subj }|.
  PERFORM add_result USING lv_ctrl lv_status lv_sum lv_det.
ENDFORM.

*======================================================================*
* Certificados - PSE del directorio sec (como STRUST)
*======================================================================*
FORM check_certificates.
  DATA: lv_parname TYPE c LENGTH 60 VALUE 'DIR_INSTANCE',
        lv_dir     TYPE c LENGTH 200,
        lt_files   TYPE STANDARD TABLE OF epsfili,
        ls_file    TYPE epsfili,
        lv_pse     TYPE c LENGTH 255,
        lv_psenm   TYPE c LENGTH 60,
        lt_ptab    TYPE abap_func_parmbind_tab,
        lr_cert    TYPE REF TO data,
        lr_list    TYPE REF TO data,
        lv_found   TYPE c LENGTH 1,
        lv_subrc   TYPE i,
        lv_msg     TYPE c LENGTH 255,
        lv_xcert   TYPE xstring,
        lv_kind    TYPE c LENGTH 1,
        lv_status  TYPE c LENGTH 10,
        lv_days    TYPE i,
        lv_sum     TYPE string,
        lv_det     TYPE string.

  FIELD-SYMBOLS: <lv_cert> TYPE any,
                 <lt_list> TYPE ANY TABLE,
                 <ls_row>  TYPE any,
                 <lv_comp> TYPE any.

  CLEAR gs_tot.

* Directorio sec de la instancia
  CALL 'C_SAPGPARAM' ID 'NAME'  FIELD lv_parname
                     ID 'VALUE' FIELD lv_dir.
  IF lv_dir IS INITIAL.
    PERFORM add_result USING 'RESUMEN' gc_inc
      'No se pudo leer DIR_INSTANCE' 'Revisar parametros de perfil'.
    RETURN.
  ENDIF.
  IF lv_dir CA '\'.
    CONCATENATE lv_dir '\sec' INTO gv_secdir.
  ELSE.
    CONCATENATE lv_dir '/sec' INTO gv_secdir.
  ENDIF.

  CALL FUNCTION 'EPS_GET_DIRECTORY_LISTING'
    EXPORTING
      dir_name = gv_secdir
    TABLES
      dir_list = lt_files
    EXCEPTIONS
      OTHERS   = 1.
  IF sy-subrc <> 0.
    lv_det = |No se pudo listar { gv_secdir }|.
    PERFORM add_result USING 'RESUMEN' gc_inc
      'No se pudo leer el directorio sec' lv_det.
    RETURN.
  ENDIF.
  SORT lt_files BY name.

  LOOP AT lt_files INTO ls_file.
    IF ls_file-name NP '*.pse' AND ls_file-name NP '*.PSE'.
      CONTINUE.
    ENDIF.
    lv_pse   = ls_file-name.
    lv_psenm = ls_file-name.

*   Filtro por nombre de PSE (CP no distingue mayusculas)
    IF s_pse[] IS NOT INITIAL AND lv_psenm NOT IN s_pse.
      gs_tot-nskip = gs_tot-nskip + 1.
      CONTINUE.
    ENDIF.

*   PSE de System PKI (kernel/sapstartsrv): protegidos con PIN y
*   regenerados por el sistema, no se administran en STRUST.
    IF lv_pse CP 'sap_system_pki*'.
      gs_tot-npki = gs_tot-npki + 1.
      IF x_pki = 'X'.
        lv_sum = |{ lv_pse }: PSE de System PKI, gestionado por el kernel|.
        PERFORM add_result USING 'PKI' gc_ok lv_sum
          'No se revisa (no es un PSE de STRUST)'.
      ENDIF.
      CONTINUE.
    ENDIF.

    gs_tot-npse = gs_tot-npse + 1.

*   Certificado propio
    IF x_own = 'X'.
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
              gs_tot-nown = gs_tot-nown + 1.
              PERFORM eval_cert USING lv_pse 'X' lv_xcert.
            CATCH cx_root.
              gs_tot-ninc = gs_tot-ninc + 1.
              lv_sum = |{ lv_pse }: no se pudo leer el certificado propio|.
              PERFORM add_result USING 'PROPIOS' gc_inc lv_sum
                'El certificado devuelto no tiene el formato esperado'.
          ENDTRY.
        ELSE.
          gs_tot-ninc = gs_tot-ninc + 1.
          lv_sum = |{ lv_pse }: no se pudo leer el certificado propio|.
          PERFORM add_result USING 'PROPIOS' gc_inc lv_sum lv_msg.
        ENDIF.
      ELSE.
        gs_tot-ninc = gs_tot-ninc + 1.
        lv_sum = |{ lv_pse }: no se pudo leer el certificado propio|.
        PERFORM add_result USING 'PROPIOS' gc_inc lv_sum
          'SSFC_GET_OWNCERTIFICATE no disponible'.
      ENDIF.
    ENDIF.

*   Lista de certificados de confianza
    IF x_trust IS INITIAL.
      CONTINUE.
    ENDIF.
    REFRESH lt_ptab.
    PERFORM fm_set   USING 'SSFC_GET_CERTIFICATELIST' 'PROFILE' lv_pse
                     CHANGING lt_ptab lv_found.
    PERFORM fm_param USING 'SSFC_GET_CERTIFICATELIST' 'CERTIFICATELIST' 'STRING'
                     CHANGING lt_ptab lr_list lv_found.
    IF lv_found IS INITIAL.
      gs_tot-ninc = gs_tot-ninc + 1.
      lv_sum = |{ lv_pse }: no se pudo leer la lista de confianza|.
      PERFORM add_result USING 'CONFIANZA' gc_inc lv_sum
        'SSFC_GET_CERTIFICATELIST no disponible'.
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
      gs_tot-ntrust = gs_tot-ntrust + 1.
      PERFORM eval_cert USING lv_pse ' ' lv_xcert.
    ENDLOOP.
  ENDLOOP.

* Resumen
  IF gs_tot-npse = 0.
    IF gs_tot-nskip > 0.
      lv_det = |Ningun PSE cumple el filtro ({ gs_tot-nskip } fuera del filtro) en { gv_secdir }|.
    ELSEIF gs_tot-npki > 0.
      lv_det = |Solo hay PSE de System PKI en { gv_secdir }|.
    ELSE.
      lv_det = |No hay archivos .pse en { gv_secdir }|.
    ENDIF.
    PERFORM add_result USING 'RESUMEN' gc_inc 'No se encontraron PSE para revisar' lv_det.
    RETURN.
  ENDIF.

  IF gs_tot-nexp > 0 OR gs_tot-ncrit > 0.
    lv_status = gc_err.
  ELSEIF gs_tot-nsoon > 0.
    lv_status = gc_warn.
  ELSEIF gs_tot-ninc > 0.
    lv_status = gc_inc.
  ELSE.
    lv_status = gc_ok.
  ENDIF.

  lv_sum = |{ gs_tot-npse } PSE - { gs_tot-nown } certificado(s) propio(s) + | &&
           |{ gs_tot-ntrust } de confianza|.
  lv_det = |{ gs_tot-nexp } vencido(s)|.
  IF p_cerr > 0.
    lv_det = |{ lv_det }, { gs_tot-ncrit } vencen en { p_cerr } dias o menos|.
  ENDIF.
  lv_det = |{ lv_det }, { gs_tot-nsoon } por vencer en { p_cdias } dias|.
  IF gs_tot-ninc > 0.
    lv_det = |{ lv_det }, { gs_tot-ninc } sin leer|.
  ENDIF.
  IF gs_tot-nself > 0.
    lv_det = |{ lv_det } - { gs_tot-nself } autofirmado(s)|.
  ENDIF.
  IF gs_tot-npki > 0.
    lv_det = |{ lv_det } - { gs_tot-npki } PSE de System PKI sin leer|.
  ENDIF.
  IF gs_tot-nskip > 0.
    lv_det = |{ lv_det } - { gs_tot-nskip } PSE fuera del filtro|.
  ENDIF.
  lv_det = |{ lv_det } - directorio { gv_secdir }|.
  PERFORM add_summary USING 'RESUMEN' lv_status lv_sum lv_det.

* Proximo vencimiento (informativo)
  IF gs_tot-nextexp IS NOT INITIAL.
    lv_days = gs_tot-nextexp - sy-datum.
    lv_sum = |Proximo vencimiento: { gs_tot-nextexp DATE = USER } ({ lv_days } dias)|.
    lv_det = |CN={ gs_tot-nextcn }|.
    PERFORM add_summary USING 'RESUMEN' gc_ok lv_sum lv_det.
  ENDIF.

  IF p_okrow IS INITIAL AND gs_tot-nexp = 0 AND gs_tot-ncrit = 0
     AND gs_tot-nsoon = 0 AND gs_tot-ninc = 0.
    PERFORM add_result USING 'RESUMEN' gc_ok
      'Todos los certificados en OK'
      'Las filas en OK estan ocultas (pestana Parametros)'.
  ENDIF.
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
    lv_subj = |Certificados { sy-sysid }/{ sy-mandt } { sy-datum DATE = USER } - { lv_gtext }|.
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
*   Las filas de resumen repiten lo que ya cuentan las filas de detalle
    IF ls_res-is_sum = 'X'.
      CONTINUE.
    ENDIF.
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
  PERFORM add_fc USING 'SUMMARY'    'Resultado'     60   ' ' ' ' ' '.
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
  gs_layout-window_titlebar  = gc_title.
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

*----------------------------------------------------------------------*
* Encabezado para impresion / spool del job
*----------------------------------------------------------------------*
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
