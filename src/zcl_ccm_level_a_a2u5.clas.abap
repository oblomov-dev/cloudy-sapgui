CLASS zcl_ccm_level_a_a2u5 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    " --- Configuration (from ARS_LANG_OBJTYPE, grouped by table) ---
    TYPES: BEGIN OF ty_s_config,
             table_name    TYPE string,
             types         TYPE string,
             field         TYPE string,
             handler_class TYPE string,
             z_filter      TYPE string,
           END OF ty_s_config,
           ty_t_config TYPE STANDARD TABLE OF ty_s_config WITH EMPTY KEY.

    " --- Result counters ---
    TYPES: BEGIN OF ty_s_counter,
             types  TYPE string,
             number TYPE i,
             source TYPE string,
           END OF ty_s_counter,
           ty_t_counter TYPE STANDARD TABLE OF ty_s_counter WITH EMPTY KEY.

    DATA mt_configs  TYPE ty_t_config.
    DATA mt_counters TYPE ty_t_counter.
    DATA mv_total    TYPE i.
    DATA mv_message  TYPE string.
    DATA mv_msg_type TYPE string VALUE `Information`.
    DATA mv_running  TYPE abap_bool.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS on_event.
    METHODS run_analysis.

  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_ccm_level_a_a2u5 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    CASE client->get( )-event.
      WHEN `RUN`.
        run_analysis( ).
        view_display( ).
    ENDCASE.

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_xml_view=>factory( ).

    DATA(page) = view->shell( )->page(
        title = `CCM - Level A Objects (ABAP Cloud Customer Objects)` ).

    IF mv_message IS NOT INITIAL.
      page->message_strip(
          text     = mv_message
          type     = mv_msg_type
          showicon = abap_true ).
    ENDIF.

    " --- Action bar ---
    DATA(toolbar) = page->_generic(
        name   = `Toolbar`
        t_prop = VALUE #( ( n = `class` v = `sapUiSmallMarginBottom` ) ) ).
    toolbar->_generic(
        name   = `Button`
        t_prop = VALUE #(
            ( n = `text`  v = `Run Analysis` )
            ( n = `icon`  v = `sap-icon://begin` )
            ( n = `type`  v = `Emphasized` )
            ( n = `press` v = client->_event( `RUN` ) ) ) ).
    toolbar->_generic(
        name   = `ToolbarSpacer`
        t_prop = VALUE #( ) ).
    toolbar->_generic(
        name   = `ObjectStatus`
        t_prop = VALUE #(
            ( n = `text`  v = |Total Level A objects: { mv_total }| )
            ( n = `state` v = COND #( WHEN mv_total > 0 THEN `Success` ELSE `None` ) ) ) ).

    " --- Info panel ---
    IF mt_counters IS INITIAL.
      page->_generic(
          name   = `IllustratedMessage`
          t_prop = VALUE #(
              ( n = `illustrationType`  v = `sapIllus-SimpleBalloon` )
              ( n = `title`            v = `No analysis run yet` )
              ( n = `description`      v = `Click "Run Analysis" to count all customer ABAP Cloud (Level A) objects.` ) ) ).
    ELSE.
      " --- Results table (sap.ui.table.Table for good layout) ---
      DATA(grid_table) = page->_generic(
          name   = `Table`
          ns     = `table`
          t_prop = VALUE #(
              ( n = `xmlns:table`         v = `sap.ui.table` )
              ( n = `rows`                v = client->_bind( mt_counters ) )
              ( n = `visibleRowCountMode` v = `Auto` )
              ( n = `visibleRowCount`     v = |{ lines( mt_counters ) }| )
              ( n = `selectionMode`       v = `None` )
              ( n = `rowHeight`           v = `32` )
              ( n = `minAutoRowCount`     v = `5` ) ) ).

      DATA(cols) = grid_table->_generic( name = `columns` ns = `table` ).

      " Column: Object Types
      DATA(col1) = cols->_generic(
          name = `Column` ns = `table`
          t_prop = VALUE #( ( n = `width` v = `40%` ) ) ).
      col1->_generic( name = `label` ns = `table`
          )->_generic( name = `Label` t_prop = VALUE #( ( n = `text` v = `Object Types` ) ) ).
      col1->_generic( name = `template` ns = `table`
          )->_generic( name = `Text` t_prop = VALUE #( ( n = `text` v = `{TYPES}` ) ( n = `wrapping` v = `true` ) ) ).

      " Column: Count
      DATA(col2) = cols->_generic(
          name = `Column` ns = `table`
          t_prop = VALUE #( ( n = `width` v = `15%` ) ) ).
      col2->_generic( name = `label` ns = `table`
          )->_generic( name = `Label` t_prop = VALUE #( ( n = `text` v = `Count` ) ) ).
      col2->_generic( name = `template` ns = `table`
          )->_generic( name = `ObjectNumber` t_prop = VALUE #(
              ( n = `number` v = `{NUMBER}` )
              ( n = `state`  v = `{= ${NUMBER} > 0 ? 'Success' : 'None' }` ) ) ).

      " Column: Source Table
      DATA(col3) = cols->_generic(
          name = `Column` ns = `table`
          t_prop = VALUE #( ( n = `width` v = `45%` ) ) ).
      col3->_generic( name = `label` ns = `table`
          )->_generic( name = `Label` t_prop = VALUE #( ( n = `text` v = `Source Table` ) ) ).
      col3->_generic( name = `template` ns = `table`
          )->_generic( name = `Text` t_prop = VALUE #( ( n = `text` v = `{SOURCE}` ) ) ).

    ENDIF.

    " --- Footer ---
    page->footer(
        )->overflow_toolbar(
            )->toolbar_spacer(
            )->button(
                text  = `Rerun`
                icon  = `sap-icon://refresh`
                type  = `Emphasized`
                press = client->_event( `RUN` ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD run_analysis.

    CLEAR: mt_configs, mt_counters, mv_total, mv_message.

    " --- Predefined filter table (from GitHub: Xexer/abap-ccm) ---
    TYPES: BEGIN OF ty_s_filter,
             table TYPE string,
             field TYPE string,
             query TYPE string,
           END OF ty_s_filter.
    DATA lt_filters TYPE SORTED TABLE OF ty_s_filter WITH UNIQUE KEY table.
    lt_filters = VALUE #(
        ( table = 'REPOSRC'        field = 'PROGNAME' )
        ( table = 'PROGDIR'        field = 'NAME' )
        ( table = 'KTD_W_HEADER'   field = 'NAME' )
        ( table = 'DD02L'          field = 'TABNAME' )
        ( table = 'DD40L'          field = 'TYPENAME' )
        ( table = 'DD04L'          field = 'ROLLNAME' )
        ( table = 'DD01L'          field = 'DOMNAME' )
        ( table = 'DDDDLSRC'       field = 'DDLNAME' )
        ( table = 'DDDRTY_SOURCE'  field = 'TYPE_NAME' )
        ( table = 'DDLXSRC'        field = 'DDLXNAME' )
        ( table = 'DDDSFD_SOURCE'  field = 'SCALAR_FUNCTION_NAME' )
        ( table = 'APJ_W_JCE_ROOT' field = 'JOB_CATALOG_ENTRY_NAME' )
        ( table = 'APJ_W_JT_ROOT'  field = 'JOB_TEMPLATE_NAME' )
        ( table = 'O2XSLTDESC'     field = 'XSLTDESC' )
        ( table = 'NONT_HEADER'    field = 'NONT_NAME' )
        ( table = 'RONT_HEADER'    field = 'RONT_NAME' )
        ( table = '/IWBEP/I_V4_MSGR' field = 'GROUP_ID' )
        ( table = '/IWBEP/I_MGW_OHD' field = 'TECHNICAL_NAME' )
        ( table = '/IWFND/I_MED_OHD' field = 'MODEL_IDENTIFIER' )
        ( table = '/IWFND/I_MED_SRH' field = 'SRV_IDENTIFIER' )
        ( table = '/IWBEP/I_MGW_SRH' field = 'TECHNICAL_NAME' )
        ( table = '/IWBEP/I_MGW_VAH' field = 'TECHNICAL_NAME' )
        ( table = 'ACMDCLSRC'      field = 'DCLNAME' )
        ( table = 'TCDRP'          field = 'OBJECT' )
        ( table = 'DDDESD_HEADER'  field = 'SCHEMA_NAME' )
        ( table = 'ABAP_DAEMON_DT' field = 'DAEMON_ID' )
        ( table = 'DDDRAS_SOURCE'  field = 'ASPECT_NAME' )
        ( table = 'DDDSFI_SOURCE'  field = 'IMPLEMENTATION_REFERENCE_NAME' )
        ( table = 'DDDTDC_SOURCE'  field = 'DTDC_NAME' )
        ( table = 'DDDTEB_HEADER'  field = 'BUFFER_NAME' )
        ( table = 'AMC_APPL'       field = 'APPLICATION_ID' )
        ( table = 'APC_APPL'       field = 'APPLICATION_ID' )
        ( table = 'SPRV_HEAD'      field = 'PRV_PRX_NAME' )
        ( table = 'SRVB_HEAD'      field = 'SRVB_NAME' )
        ( table = 'SRVDSRC'        field = 'SRVDNAME' )
        ( table = 'VEPHEADER'      field = 'VEPNAME' )
        ( table = 'WMPC_DT'        field = 'WMPC_ID' )
        ( table = 'ARCH_OBJ'       field = 'OBJECT' )
        ( table = 'ENHSPOTHEADER'  field = 'ENHSPOT' )
        ( table = 'GSM_MD_PRV_W'   field = 'PROVIDER_ID' )
        ( table = 'TDEVC'          field = 'DEVCLASS' )
        ( table = 'CDB_OBJH'       field = 'OBJ_NAME' )
        ( table = 'SPROXHDR'       field = 'OBJ_NAME' )
        ( table = 'DD12L'          field = 'SQLTAB' )
        ( table = 'USOB_SM'        query = | AND MODIFIER <> 'SAP' AND MODIFIER <> '!USOBHASH'| )
        ( table = 'SIT2_BT'        field = 'SITNBASETEMPLATEID' )
        ( table = 'SIT2_CT'        field = 'SITNCONFIGNTEMPLATEID' )
        ( table = 'TMC1'           field = 'GSTRU' )
        ( table = 'T681'           query = | AND SAPSY = 'CUSTOMER'| ) ).

    " --- Step 1: Read ARS_LANG_OBJTYPE, group by table ---
    DATA(lv_lang_version) = `5`.  " 5 = ABAP for Cloud Development

    SELECT FROM ars_lang_objtype
      FIELDS *
      WHERE supports_sap_cloud_platform    = @abap_true
        AND does_not_have_language_version = @abap_false
        AND table_name IS NOT INITIAL
      INTO TABLE @DATA(lt_ac_objects).

    IF lt_ac_objects IS INITIAL.
      mv_message  = `Table ARS_LANG_OBJTYPE returned no cloud objects.`.
      mv_msg_type = `Error`.
      RETURN.
    ENDIF.

    " Group by table
    LOOP AT lt_ac_objects INTO DATA(ls_obj).
      TRY.
          DATA(lr_cfg) = REF #( mt_configs[ table_name = ls_obj-table_name ] ).
          lr_cfg->types = |{ lr_cfg->types }, { ls_obj-object_type }|.
          CONTINUE.
        CATCH cx_sy_itab_line_not_found.
          APPEND VALUE #(
              table_name    = ls_obj-table_name
              types         = CONV string( ls_obj-object_type )
              handler_class = ls_obj-handler_class_name
              field         = ls_obj-column_name
          ) TO mt_configs REFERENCE INTO lr_cfg.
      ENDTRY.

      " Apply z_filter from predefined filter table
      lr_cfg->z_filter = VALUE #( lt_filters[ table = lr_cfg->table_name ]-field OPTIONAL ).

      " Special cases
      CASE lr_cfg->table_name.
        WHEN 'SMIMLOIO'.
          lr_cfg->field = 'PROP01'.
      ENDCASE.
    ENDLOOP.

    " --- Step 2: Count objects per grouped table ---
    LOOP AT mt_configs ASSIGNING FIELD-SYMBOL(<cfg>).
      DATA lv_condition TYPE string.
      lv_condition = |{ <cfg>-field } = '{ lv_lang_version }'|.

      " Z/Y customer name filter
      IF <cfg>-z_filter IS NOT INITIAL.
        lv_condition = |{ lv_condition } AND ( { <cfg>-z_filter } LIKE 'Z%' OR { <cfg>-z_filter } LIKE 'Y%' )|.
      ENDIF.

      " Additional query from filter table (e.g. USOB_SM, T681)
      DATA(lv_extra) = VALUE #( lt_filters[ table = <cfg>-table_name ]-query OPTIONAL ).
      IF lv_extra IS NOT INITIAL.
        lv_condition = |{ lv_condition }{ lv_extra }|.
      ENDIF.

      DATA lv_count TYPE i.
      TRY.
          SELECT COUNT( * )
            FROM (<cfg>-table_name)
            WHERE (lv_condition)
            INTO @lv_count.
        CATCH cx_root.
          lv_count = -1.
      ENDTRY.

      APPEND VALUE #(
          types  = <cfg>-types
          number = lv_count
          source = <cfg>-table_name
      ) TO mt_counters.
    ENDLOOP.

    " Remove zero-count entries, sort descending
    DELETE mt_counters WHERE number = 0.
    SORT mt_counters BY number DESCENDING.

    " Calculate total
    LOOP AT mt_counters ASSIGNING FIELD-SYMBOL(<cnt>) WHERE number > 0.
      mv_total = mv_total + <cnt>-number.
    ENDLOOP.

    mv_message  = |Analysis complete: { mv_total } customer Level A objects across { lines( mt_counters ) } source tables ({ lines( lt_ac_objects ) } object types scanned).|.
    mv_msg_type = `Success`.

  ENDMETHOD.

ENDCLASS.
