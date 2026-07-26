CLASS zcl_se80_ui DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA mt_tree         TYPE zcl_se80_api=>ty_t_tree.
    DATA mv_cur_package  TYPE devclass VALUE '$ZLK'.
    DATA mv_cur_obj_name TYPE sobj_name.
    DATA mv_cur_obj_type TYPE trobjtype.
    DATA mv_source       TYPE string.
    DATA mv_source_local TYPE string.
    DATA mv_source_test  TYPE string.
    DATA mv_search       TYPE string.
    DATA mv_search_type  TYPE string.
    DATA mv_object_title TYPE string.
    DATA mv_active_tab   TYPE string VALUE 'SRC'.
    DATA mt_methods      TYPE zcl_se80_api=>ty_t_method.
    DATA mt_fields       TYPE zcl_se80_api=>ty_t_field.
    DATA mt_usages       TYPE zcl_se80_api=>ty_t_usage.
    DATA mt_props        TYPE zcl_se80_api=>ty_t_prop.
    DATA mv_edit_mode    TYPE abap_bool.
    DATA mv_message      TYPE string.
    DATA mv_msg_type     TYPE string.
    DATA mv_show_whereu  TYPE abap_bool.
    DATA mv_syntax_mode  TYPE string VALUE 'abap'.
    DATA mv_text_elem    TYPE string.
    DATA mv_docu         TYPE string.
    DATA mv_status       TYPE string.

    " Navigation history
    TYPES:
      BEGIN OF ty_s_history,
        obj_name TYPE sobj_name,
        obj_type TYPE trobjtype,
      END OF ty_s_history.
    DATA mt_history TYPE STANDARD TABLE OF ty_s_history WITH EMPTY KEY.
    DATA mv_hist_pos TYPE i VALUE 0.
    DATA mv_find TYPE string.
    DATA mv_replace TYPE string.
    DATA mv_goto_line TYPE string.
    DATA mv_fullscreen TYPE abap_bool.
    DATA mv_dark_theme TYPE abap_bool.
    DATA mv_quick_nav  TYPE string.
    DATA mv_breadcrumb TYPE string.
    DATA mv_lock_info  TYPE string.

    " Recent objects
    TYPES:
      BEGIN OF ty_s_recent,
        text  TYPE string,
        key   TYPE string,
        otype TYPE string,
      END OF ty_s_recent.
    DATA mt_recent TYPE STANDARD TABLE OF ty_s_recent WITH EMPTY KEY.

    " Bottom log panel
    TYPES:
      BEGIN OF ty_s_log,
        icon    TYPE string,
        type    TYPE string,
        line    TYPE string,
        message TYPE string,
      END OF ty_s_log.
    TYPES ty_t_log TYPE STANDARD TABLE OF ty_s_log WITH EMPTY KEY.
    DATA mt_log TYPE ty_t_log.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    DATA mo_api TYPE REF TO zcl_se80_api.
    METHODS view_display.
    METHODS on_event.
    METHODS load_object.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_se80_ui IMPLEMENTATION.

  METHOD z2ui5_if_app~main.
    me->client = client.
    IF mo_api IS NOT BOUND.
      mo_api = NEW zcl_se80_api( ).
    ENDIF.
    IF client->check_on_init( ).
      mt_tree = mo_api->get_package_tree( mv_cur_package ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.
  ENDMETHOD.


  METHOD on_event.
    DATA(lv_event) = client->get( )-event.
    DATA(lt_arg) = client->get( )-t_event_arg.
    CLEAR: mv_message, mv_msg_type, mt_log.

    CASE lv_event.
      WHEN 'TREE_CLICK'.
        IF lines( lt_arg ) >= 2.
          IF lt_arg[ 2 ] = 'DEVC'.
            mv_cur_package = CONV devclass( lt_arg[ 1 ] ).
            mt_tree = mo_api->get_package_tree( mv_cur_package ).
            mt_props = mo_api->get_package_info( mv_cur_package ).
            mv_object_title = |Package: { mv_cur_package }|.
            mv_active_tab = 'INFO'.
            CLEAR: mv_source, mv_source_local, mv_source_test, mv_cur_obj_name, mt_methods, mt_fields.
          ELSEIF lt_arg[ 2 ] = 'METH'.
            " Method clicked - navigate to class and show signature
            DATA(lv_meth_key) = lt_arg[ 1 ].
            SPLIT lv_meth_key AT '=>' INTO DATA(lv_cls) DATA(lv_mtd).
            mv_cur_obj_name = CONV sobj_name( lv_cls ).
            mv_cur_obj_type = 'CLAS'.
            load_object( ).
            " Get method signature and show in fields
            mt_fields = mo_api->get_method_signature(
              iv_classname = mv_cur_obj_name iv_methodname = CONV #( lv_mtd ) ).
            " Find method line in source
            DATA(lv_search) = |method { to_lower( lv_mtd ) }|.
            DATA(lv_pos) = find( val = to_lower( mv_source ) sub = lv_search ).
            IF lv_pos >= 0.
              DATA(lv_line) = 1.
              DATA(lv_cnt) = 0.
              DO lv_pos TIMES.
                IF mv_source+lv_cnt(1) = cl_abap_char_utilities=>newline.
                  lv_line = lv_line + 1.
                ENDIF.
                lv_cnt = lv_cnt + 1.
              ENDDO.
              mv_message = |Method { lv_mtd } at line { lv_line }|.
            ELSE.
              mv_message = |Method { lv_mtd } - signature shown in Properties|.
            ENDIF.
            mv_msg_type = `Information`.
            mv_active_tab = 'INFO'.
          ELSE.
            mv_cur_obj_name = CONV sobj_name( lt_arg[ 1 ] ).
            mv_cur_obj_type = CONV trobjtype( lt_arg[ 2 ] ).
            load_object( ).
          ENDIF.
        ENDIF.
      WHEN 'NAV_BACK'.
        IF mv_hist_pos > 1.
          mv_hist_pos = mv_hist_pos - 1.
          mv_cur_obj_name = mt_history[ mv_hist_pos ]-obj_name.
          mv_cur_obj_type = mt_history[ mv_hist_pos ]-obj_type.
          load_object( ).
        ENDIF.
      WHEN 'NAV_FORWARD'.
        IF mv_hist_pos < lines( mt_history ).
          mv_hist_pos = mv_hist_pos + 1.
          mv_cur_obj_name = mt_history[ mv_hist_pos ]-obj_name.
          mv_cur_obj_type = mt_history[ mv_hist_pos ]-obj_type.
          load_object( ).
        ENDIF.
      WHEN 'NAV_UP'.
        SELECT SINGLE parentcl FROM tdevc WHERE devclass = @mv_cur_package INTO @DATA(lv_p).
        IF sy-subrc = 0 AND lv_p IS NOT INITIAL.
          mv_cur_package = lv_p.
          mt_tree = mo_api->get_package_tree( mv_cur_package ).
          CLEAR: mv_source, mv_source_local, mv_source_test, mv_cur_obj_name, mv_object_title, mt_methods, mt_fields, mt_props.
        ENDIF.
      WHEN 'SEARCH'.
        IF mv_search IS NOT INITIAL.
          DATA lv_tf TYPE trobjtype.
          IF mv_search_type IS NOT INITIAL AND mv_search_type <> 'ALL'.
            lv_tf = CONV trobjtype( mv_search_type ).
          ENDIF.
          mt_tree = mo_api->search_objects( iv_pattern = mv_search iv_type = lv_tf ).
          mv_object_title = |Search: { lines( mt_tree ) } hits|.
          CLEAR: mv_source, mv_source_local, mv_source_test.
        ENDIF.
      WHEN 'TOGGLE_EDIT'.
        mv_edit_mode = xsdbool( mv_edit_mode = abap_false ).
      WHEN 'SAVE'.
        IF mv_source IS INITIAL.
          mv_message = `Source is empty.`. mv_msg_type = `Error`.
        ELSE.
          DATA(ls_s) = mo_api->save_source( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type iv_source = mv_source ).
          mv_message = ls_s-message. mv_msg_type = COND #( WHEN ls_s-success = abap_true THEN `Success` ELSE `Error` ).
          APPEND VALUE ty_s_log(
            icon = COND #( WHEN ls_s-success = abap_true THEN `sap-icon://sys-enter-2` ELSE `sap-icon://error` )
            type = COND #( WHEN ls_s-success = abap_true THEN `Success` ELSE `Error` )
            message = ls_s-message ) TO mt_log.
        ENDIF.
      WHEN 'ACTIVATE'.
        DATA(ls_a) = mo_api->activate_object( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type ).
        mv_message = ls_a-message. mv_msg_type = COND #( WHEN ls_a-success = abap_true THEN `Success` ELSE `Error` ).
        APPEND VALUE ty_s_log(
          icon = COND #( WHEN ls_a-success = abap_true THEN `sap-icon://sys-enter-2` ELSE `sap-icon://error` )
          type = COND #( WHEN ls_a-success = abap_true THEN `Success` ELSE `Error` )
          message = ls_a-message ) TO mt_log.
        IF ls_a-success = abap_true. load_object( ). ENDIF.
      WHEN 'CHECK'.
        DATA(lt_c) = mo_api->check_syntax( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type iv_source = mv_source ).
        IF lt_c IS NOT INITIAL.
          mv_message = lt_c[ 1 ]-message.
          mv_msg_type = COND #( WHEN lt_c[ 1 ]-type = 'E' THEN `Error` ELSE `Warning` ).
          " Fill log panel
          LOOP AT lt_c ASSIGNING FIELD-SYMBOL(<chk>).
            APPEND VALUE ty_s_log(
              icon    = COND #( WHEN <chk>-type = 'E' THEN `sap-icon://error`
                                WHEN <chk>-type = 'W' THEN `sap-icon://alert` ELSE `sap-icon://sys-enter-2` )
              type    = COND #( WHEN <chk>-type = 'E' THEN `Error` WHEN <chk>-type = 'W' THEN `Warning` ELSE `Success` )
              line    = COND #( WHEN <chk>-line > 0 THEN |Ln { <chk>-line }| )
              message = <chk>-message
            ) TO mt_log.
          ENDLOOP.
        ELSE.
          mv_message = `Syntax OK.`.
          mv_msg_type = `Success`.
          APPEND VALUE ty_s_log( icon = `sap-icon://sys-enter-2` type = `Success` message = `Syntax check passed.` ) TO mt_log.
        ENDIF.
      WHEN 'PRETTY_PRINT'.
        mv_source = mo_api->pretty_print( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type iv_source = mv_source ).
        mv_message = `Formatted.`. mv_msg_type = `Success`.
      WHEN 'WHERE_USED'.
        mt_usages = mo_api->get_where_used( mv_cur_obj_name ). mv_show_whereu = abap_true.
      WHEN 'CLOSE_WHEREU'.
        mv_show_whereu = abap_false.
      WHEN 'USAGE_CLICK'.
        IF lines( lt_arg ) >= 2.
          mv_cur_obj_name = CONV sobj_name( lt_arg[ 1 ] ). mv_cur_obj_type = CONV trobjtype( lt_arg[ 2 ] ).
          mv_show_whereu = abap_false. load_object( ).
        ENDIF.
      WHEN 'CREATE_OBJ'.
        " Create program or class (based on search type filter)
        IF mv_search IS NOT INITIAL.
          DATA(lv_new_name) = CONV sobj_name( to_upper( mv_search ) ).
          DATA ls_cr TYPE zcl_se80_api=>ty_s_result.
          IF mv_search_type = 'CLAS'.
            ls_cr = mo_api->create_class( iv_name = lv_new_name iv_package = mv_cur_package ).
            IF ls_cr-success = abap_true.
              mv_cur_obj_type = 'CLAS'.
            ENDIF.
          ELSEIF mv_search_type = 'INTF'.
            ls_cr = mo_api->create_interface( iv_name = lv_new_name iv_package = mv_cur_package ).
            IF ls_cr-success = abap_true.
              mv_cur_obj_type = 'INTF'.
            ENDIF.
          ELSE.
            ls_cr = mo_api->create_program( iv_name = lv_new_name iv_package = mv_cur_package ).
            IF ls_cr-success = abap_true.
              mv_cur_obj_type = 'PROG'.
            ENDIF.
          ENDIF.
          mv_message = ls_cr-message.
          mv_msg_type = COND #( WHEN ls_cr-success = abap_true THEN `Success` ELSE `Error` ).
          IF ls_cr-success = abap_true.
            mt_tree = mo_api->get_package_tree( mv_cur_package ).
            mv_cur_obj_name = lv_new_name.
            load_object( ).
          ENDIF.
        ELSE.
          mv_message = `Enter name in search field, select type.`.
          mv_msg_type = `Warning`.
        ENDIF.
      WHEN 'CONFIRM_DELETE'.
        " Actually delete after confirmation
        DATA(ls_del) = mo_api->delete_object( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type ).
        mv_message = ls_del-message.
        mv_msg_type = COND #( WHEN ls_del-success = abap_true THEN `Success` ELSE `Error` ).
        APPEND VALUE ty_s_log(
          icon = COND #( WHEN ls_del-success = abap_true THEN `sap-icon://sys-enter-2` ELSE `sap-icon://error` )
          type = COND #( WHEN ls_del-success = abap_true THEN `Success` ELSE `Error` )
          message = ls_del-message ) TO mt_log.
        IF ls_del-success = abap_true.
          CLEAR: mv_source, mv_source_local, mv_source_test, mv_cur_obj_name, mv_object_title, mt_methods, mt_fields, mt_props, mv_status.
          mt_tree = mo_api->get_package_tree( mv_cur_package ).
        ENDIF.
      WHEN 'QUICK_NAV'.
        IF mv_quick_nav IS NOT INITIAL.
          " Try to load object directly by name
          DATA(lv_qn) = to_upper( mv_quick_nav ).
          SELECT SINGLE object, obj_name FROM tadir
            WHERE pgmid = 'R3TR' AND obj_name = @lv_qn
            INTO @DATA(ls_qn).
          IF sy-subrc = 0.
            mv_cur_obj_name = ls_qn-obj_name.
            mv_cur_obj_type = ls_qn-object.
            load_object( ).
          ELSE.
            mv_message = |Object "{ mv_quick_nav }" not found.|.
            mv_msg_type = `Warning`.
          ENDIF.
        ENDIF.
      WHEN 'TOGGLE_THEME'.
        mv_dark_theme = xsdbool( mv_dark_theme = abap_false ).
      WHEN 'GOTO_LINE'.
        IF mv_goto_line IS NOT INITIAL.
          mv_message = |Go to line { mv_goto_line } (use browser Ctrl+G in editor).|.
          mv_msg_type = `Information`.
        ENDIF.
      WHEN 'FULLSCREEN'.
        mv_fullscreen = xsdbool( mv_fullscreen = abap_false ).
      WHEN 'EXPAND_ALL'.
        " Handled client-side via tree ID
      WHEN 'COLLAPSE_ALL'.
        " Handled client-side via tree ID
      WHEN 'REPLACE_ALL'.
        IF mv_find IS NOT INITIAL AND mv_edit_mode = abap_true.
          DATA lv_rep_count TYPE i.
          mo_api->search_replace_source(
            EXPORTING iv_source = mv_source iv_search = mv_find iv_replace = mv_replace
            IMPORTING ev_source = mv_source ev_count = lv_rep_count ).
          mv_message = |Replaced { lv_rep_count } occurrence(s).|.
          mv_msg_type = COND #( WHEN lv_rep_count > 0 THEN `Success` ELSE `Warning` ).
        ENDIF.
      WHEN 'COMPARE'.
        DATA(lv_diff) = mo_api->compare_versions( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type ).
        IF lv_diff IS NOT INITIAL.
          mv_source = lv_diff.
          mv_active_tab = 'SRC'.
          mv_message = `Showing version comparison.`.
          mv_msg_type = `Information`.
        ENDIF.
      WHEN 'FIND_IN_SOURCE'.
        IF mv_find IS NOT INITIAL AND mv_source IS NOT INITIAL.
          DATA(lv_fl) = to_lower( mv_find ).
          DATA(lv_sl) = to_lower( mv_source ).
          DATA lv_cnt2 TYPE i.
          DATA lv_fline TYPE i.
          DATA lv_o TYPE i.
          DO.
            FIND lv_fl IN SECTION OFFSET lv_o OF lv_sl MATCH OFFSET DATA(lv_mo).
            IF sy-subrc <> 0. EXIT. ENDIF.
            lv_cnt2 = lv_cnt2 + 1.
            IF lv_fline = 0.
              DATA lv_nl TYPE i.
              FIND ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_sl(lv_mo) MATCH COUNT lv_nl.
              lv_fline = lv_nl + 1.
            ENDIF.
            lv_o = lv_mo + 1.
          ENDDO.
          mv_message = COND #( WHEN lv_cnt2 > 0 THEN |Found { lv_cnt2 }x, first at line { lv_fline }| ELSE |"{ mv_find }" not found.| ).
          mv_msg_type = COND #( WHEN lv_cnt2 > 0 THEN `Success` ELSE `Warning` ).
        ENDIF.
      WHEN 'RECENT_CLICK'.
        " Recent object selected from dropdown
        IF lines( lt_arg ) > 0.
          DATA(lv_rkey) = lt_arg[ 1 ].
          READ TABLE mt_recent WITH KEY key = lv_rkey ASSIGNING FIELD-SYMBOL(<recent>).
          IF sy-subrc = 0.
            mv_cur_obj_name = CONV sobj_name( <recent>-key ).
            mv_cur_obj_type = CONV trobjtype( <recent>-otype ).
            load_object( ).
          ENDIF.
        ENDIF.
      WHEN 'DELETE_OBJ'.
        " Show confirmation - just set flag, actual delete in CONFIRM_DELETE
        mv_message = |Delete { mv_cur_obj_name }? Click Delete again to confirm.|.
        mv_msg_type = `Warning`.
      WHEN 'SHOW_DEPS'.
        " Show object dependencies
        mt_usages = mo_api->get_object_dependencies( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type ).
        mv_show_whereu = abap_true.
      WHEN 'SHOW_HELP'.
        mv_message = |Shortcuts: Enter in Find=Search, Enter in Replace=Replace All, Enter in Line=Goto, Enter in Jump=Navigate|.
        mv_msg_type = `Information`.
      WHEN 'REFRESH'.
        mt_tree = mo_api->get_package_tree( mv_cur_package ).
      WHEN OTHERS.
    ENDCASE.
    view_display( ).
  ENDMETHOD.


  METHOD load_object.
    mv_object_title = |{ mv_cur_obj_type } - { mv_cur_obj_name }|.
    " Add to recent objects (max 20, no duplicates)
    DELETE mt_recent WHERE key = CONV string( mv_cur_obj_name ).
    INSERT VALUE ty_s_recent(
      text  = |{ mv_cur_obj_name } [{ mv_cur_obj_type }]|
      key   = CONV string( mv_cur_obj_name )
      otype = CONV string( mv_cur_obj_type )
    ) INTO mt_recent INDEX 1.
    IF lines( mt_recent ) > 20.
      DELETE mt_recent FROM 21.
    ENDIF.
    " Add to navigation history
    IF mv_hist_pos = 0 OR
       ( mv_hist_pos > 0 AND mt_history[ mv_hist_pos ]-obj_name <> mv_cur_obj_name ).
      " Truncate forward history
      IF mv_hist_pos < lines( mt_history ).
        DELETE mt_history FROM mv_hist_pos + 1.
      ENDIF.
      APPEND VALUE ty_s_history( obj_name = mv_cur_obj_name obj_type = mv_cur_obj_type ) TO mt_history.
      mv_hist_pos = lines( mt_history ).
    ENDIF.
    DATA(ls) = mo_api->load_source( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type ).
    mv_source = ls-source. mv_source_local = ls-source_local. mv_source_test = ls-source_test. mv_syntax_mode = ls-syntax_mode.
    IF ls-success = abap_false AND ls-message IS NOT INITIAL.
      mv_message = ls-message. mv_msg_type = `Warning`.
    ENDIF.
    mo_api->get_metadata( EXPORTING iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type
                          IMPORTING et_methods = mt_methods et_fields = mt_fields ).
    mt_props = mo_api->get_properties( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type iv_source = mv_source ).
    " Add program attributes for PROG
    IF mv_cur_obj_type = 'PROG' OR mv_cur_obj_type = 'FUGR'.
      DATA(lt_pattr) = mo_api->get_program_attributes( mv_cur_obj_name ).
      LOOP AT lt_pattr ASSIGNING FIELD-SYMBOL(<pa>).
        APPEND VALUE zcl_se80_api=>ty_s_field( name = <pa>-name type = <pa>-type ) TO mt_fields.
      ENDLOOP.
      " Variants
      DATA(lt_vars) = mo_api->get_variants( mv_cur_obj_name ).
      LOOP AT lt_vars ASSIGNING FIELD-SYMBOL(<var>).
        APPEND VALUE zcl_se80_api=>ty_s_field(
          name = <var>-name keyflag = `VAR` type = <var>-type ) TO mt_fields.
      ENDLOOP.
    ENDIF.
    " Add events + constants for classes
    IF mv_cur_obj_type = 'CLAS' OR mv_cur_obj_type = 'INTF'.
      DATA(lt_events) = mo_api->get_class_events( mv_cur_obj_name ).
      LOOP AT lt_events ASSIGNING FIELD-SYMBOL(<evt>).
        APPEND VALUE zcl_se80_api=>ty_s_field(
          name = <evt>-name keyflag = <evt>-keyflag type = <evt>-type ) TO mt_fields.
      ENDLOOP.
      DATA(lt_const) = mo_api->get_class_constants( mv_cur_obj_name ).
      LOOP AT lt_const ASSIGNING FIELD-SYMBOL(<co2>).
        APPEND VALUE zcl_se80_api=>ty_s_field(
          name = <co2>-name keyflag = <co2>-keyflag
          typtype = <co2>-typtype type = <co2>-type ) TO mt_fields.
      ENDLOOP.
    ENDIF.
    " FM exceptions
    IF mv_cur_obj_type = 'FUNC'.
      DATA(lt_exc) = mo_api->get_fm_exceptions( mv_cur_obj_name ).
      LOOP AT lt_exc ASSIGNING FIELD-SYMBOL(<exc>).
        APPEND VALUE zcl_se80_api=>ty_s_field(
          name = <exc>-name keyflag = <exc>-keyflag type = <exc>-type ) TO mt_fields.
      ENDLOOP.
    ENDIF.
    " Table foreign keys + append structures
    IF mv_cur_obj_type = 'TABL'.
      DATA(lt_fk) = mo_api->get_table_foreign_keys( mv_cur_obj_name ).
      LOOP AT lt_fk ASSIGNING FIELD-SYMBOL(<fk2>).
        APPEND VALUE zcl_se80_api=>ty_s_field(
          name = <fk2>-name keyflag = <fk2>-keyflag type = <fk2>-type ) TO mt_fields.
      ENDLOOP.
      DATA(lt_app) = mo_api->get_table_append_structures( mv_cur_obj_name ).
      LOOP AT lt_app ASSIGNING FIELD-SYMBOL(<app2>).
        APPEND VALUE zcl_se80_api=>ty_s_field(
          name = <app2>-name keyflag = <app2>-keyflag type = <app2>-type ) TO mt_fields.
      ENDLOOP.
    ENDIF.
    " Class friends + redefined methods
    IF mv_cur_obj_type = 'CLAS'.
      DATA(lt_fr) = mo_api->get_class_friends( mv_cur_obj_name ).
      LOOP AT lt_fr ASSIGNING FIELD-SYMBOL(<fr2>).
        APPEND VALUE zcl_se80_api=>ty_s_field(
          name = <fr2>-name type = <fr2>-type ) TO mt_fields.
      ENDLOOP.
      DATA(lt_red) = mo_api->get_redefined_methods( mv_cur_obj_name ).
      LOOP AT lt_red ASSIGNING FIELD-SYMBOL(<red>).
        APPEND VALUE zcl_se80_api=>ty_s_field(
          name = <red>-name keyflag = <red>-keyflag type = <red>-type ) TO mt_fields.
      ENDLOOP.
    ENDIF.
    " Class types
    IF mv_cur_obj_type = 'CLAS' OR mv_cur_obj_type = 'INTF'.
      DATA(lt_types) = mo_api->get_class_types( mv_cur_obj_name ).
      LOOP AT lt_types ASSIGNING FIELD-SYMBOL(<tp>).
        APPEND VALUE zcl_se80_api=>ty_s_field(
          name = <tp>-name keyflag = <tp>-keyflag type = <tp>-type ) TO mt_fields.
      ENDLOOP.
    ENDIF.
    " Table content preview
    IF mv_cur_obj_type = 'TABL' AND mv_source IS INITIAL.
      mv_source = mo_api->get_table_content( iv_name = mv_cur_obj_name iv_maxrows = 10 ).
      mv_syntax_mode = `text`.
    ENDIF.
    " Source statistics
    IF mv_source IS NOT INITIAL.
      DATA(lt_stats) = mo_api->get_source_statistics( mv_source ).
      LOOP AT lt_stats ASSIGNING FIELD-SYMBOL(<st>).
        APPEND VALUE zcl_se80_api=>ty_s_field( name = <st>-name type = <st>-type ) TO mt_fields.
      ENDLOOP.
    ENDIF.
    mv_text_elem = mo_api->get_text_elements( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type ).
    mv_docu = mo_api->get_documentation( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type ).
    mv_status = mo_api->get_object_status( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type ).
    mv_lock_info = mo_api->get_lock_info( iv_name = mv_cur_obj_name iv_type = mv_cur_obj_type ).
    mv_breadcrumb = mo_api->get_package_path( mv_cur_package ).
    mv_active_tab = 'SRC'.
  ENDMETHOD.


  METHOD view_display.
    DATA(view) = z2ui5_cl_ai_xml=>factory( ).

    DATA(page) = view->open( n = `View` ns = `mvc`
        )->a( n = `xmlns`      v = `sap.m`
        )->a( n = `xmlns:mvc`  v = `sap.ui.core.mvc`
        )->a( n = `xmlns:ce`   v = `sap.ui.codeeditor`
        )->a( n = `xmlns:core` v = `sap.ui.core`
        )->a( n = `height`     v = `100%`
        )->open( `App`
        )->open( `Page`
            )->a( n = `title` v = `Object Navigator`
            )->a( n = `showHeader` v = `true`
            )->a( n = `enableScrolling` v = `false` ).

    DATA(flex) = page->open( `HBox`
        )->a( n = `height` v = `100%`
        )->a( n = `width` v = `100%`
        )->a( n = `alignItems` v = `Stretch` ).

    " ===== LEFT: Repository Browser =====
    IF mv_fullscreen = abap_false.
    DATA(lo_l) = flex->open( `VBox` )->a( n = `width` v = `320px` ).

    " Package path with navigation
    lo_l->open( `Toolbar` )->a( n = `height` v = `2.5rem` ).
    lo_l->leaf( `Button`
        )->a( n = `icon` v = `sap-icon://nav-back`
        )->a( n = `press` v = client->_event( `NAV_UP` )
        )->a( n = `type` v = `Transparent` ).
    lo_l->leaf( `Input`
        )->a( n = `value` v = client->_bind( mv_cur_package )
        )->a( n = `submit` v = client->_event( `REFRESH` )
        )->a( n = `width` v = `200px`
        )->a( n = `placeholder` v = `Package` ).
    lo_l->leaf( `Button`
        )->a( n = `icon` v = `sap-icon://display`
        )->a( n = `press` v = client->_event( `REFRESH` )
        )->a( n = `type` v = `Transparent` ).
    lo_l->shut( ).

    " Search
    lo_l->open( `HBox` )->a( n = `width` v = `100%` ).
    lo_l->leaf( `SearchField`
        )->a( n = `placeholder` v = `Object name...`
        )->a( n = `value` v = client->_bind( mv_search )
        )->a( n = `search` v = client->_event( `SEARCH` )
        )->a( n = `width` v = `210px` ).
    DATA(lo_sel) = lo_l->open( `Select`
        )->a( n = `selectedKey` v = client->_bind( mv_search_type )
        )->a( n = `width` v = `105px` ).
    lo_sel->open( `items` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `ALL` )->a( n = `text` v = `All` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `CLAS` )->a( n = `text` v = `Class` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `PROG` )->a( n = `text` v = `Prog` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `FUGR` )->a( n = `text` v = `FuGr` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `TABL` )->a( n = `text` v = `Table` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `DDLS` )->a( n = `text` v = `CDS` ).
    lo_sel->shut( )->shut( ).
    lo_l->shut( ).

    " Recent objects + Tree toolbar
    lo_l->open( `Toolbar` )->a( n = `height` v = `2rem` ).
    IF mt_recent IS NOT INITIAL.
      DATA(lo_rec) = lo_l->open( `Select`
          )->a( n = `width` v = `160px`
          )->a( n = `change` v = client->_event( val = `RECENT_CLICK` t_arg = VALUE #( ( `${$parameters>/selectedItem}` ) ) ) ).
      lo_rec->open( `items` ).
      LOOP AT mt_recent ASSIGNING FIELD-SYMBOL(<rc>).
        lo_rec->leaf( n = `Item` ns = `core`
            )->a( n = `key` v = <rc>-key
            )->a( n = `text` v = <rc>-text ).
      ENDLOOP.
      lo_rec->shut( ).
      lo_rec->shut( ).
    ENDIF.
    lo_l->shut( ).

    " Tree toolbar (Expand/Collapse)
    lo_l->open( `Toolbar` )->a( n = `height` v = `2rem` ).
    lo_l->leaf( `Button`
        )->a( n = `icon` v = `sap-icon://expand-group`
        )->a( n = `tooltip` v = `Expand All`
        )->a( n = `type` v = `Transparent`
        )->a( n = `press` v = client->_event_client(
            val = client->cs_event-control_by_id
            t_arg = VALUE #( ( `se80Tree` ) ( `expandToLevel` ) ( `3` ) ) ) ).
    lo_l->leaf( `Button`
        )->a( n = `icon` v = `sap-icon://collapse-group`
        )->a( n = `tooltip` v = `Collapse All`
        )->a( n = `type` v = `Transparent`
        )->a( n = `press` v = client->_event_client(
            val = client->cs_event-control_by_id
            t_arg = VALUE #( ( `se80Tree` ) ( `collapseAll` ) ) ) ).
    lo_l->shut( ).

    " Tree in ScrollContainer (fixed height, scrolls internally)
    DATA(lv_path) = client->_bind( val = mt_tree path = `X` ).
    DATA lv_bind TYPE string.
    CONCATENATE `{path:'` lv_path `', parameters:{arrayNames:['NODES']}}` INTO lv_bind.

    DATA(lo_sc) = lo_l->open( `ScrollContainer`
        )->a( n = `height` v = `calc(100vh - 110px)`
        )->a( n = `vertical` v = `true` ).
    lo_sc->open( `Tree`
        )->a( n = `id` v = `se80Tree`
        )->a( n = `items` v = lv_bind
        )->open( `StandardTreeItem`
            )->a( n = `title` v = `{TEXT}`
            )->a( n = `icon` v = `{ICON}`
            )->a( n = `type` v = `Active`
            )->a( n = `press` v = client->_event( val = `TREE_CLICK` t_arg = VALUE #( ( `${KEY}` ) ( `${OTYPE}` ) ) )
        )->shut(
    )->shut( ).
    lo_sc->shut( ).
    lo_l->shut( ).
    ENDIF. " fullscreen check

    " ===== RIGHT =====
    DATA(lv_right_width) = COND #( WHEN mv_fullscreen = abap_true THEN `100%` ELSE `100%` ).
    DATA(lo_r) = flex->open( `VBox` )->a( n = `height` v = `100%` )->a( n = `width` v = lv_right_width ).
    DATA(lv_has) = COND #( WHEN mv_cur_obj_name IS NOT INITIAL THEN `true` ELSE `false` ).
    DATA(lv_edit) = COND #( WHEN mv_edit_mode = abap_true THEN `true` ELSE `false` ).

    lo_r->open( `Toolbar`
        )->leaf( `Title` )->a( n = `text` v = COND #( WHEN mv_object_title IS NOT INITIAL THEN mv_object_title ELSE `Object Navigator` )
        )->leaf( `ObjectStatus`
            )->a( n = `text` v = mv_status
            )->a( n = `state` v = COND #( WHEN mv_status = `Active` THEN `Success` WHEN mv_status = `Inactive` THEN `Warning` ELSE `None` )
        )->leaf( `ToolbarSpacer`
        )->leaf( `Button` )->a( n = `text` v = COND #( WHEN mv_edit_mode = abap_true THEN `Display` ELSE `Edit` )
            )->a( n = `icon` v = COND #( WHEN mv_edit_mode = abap_true THEN `sap-icon://display` ELSE `sap-icon://edit` )
            )->a( n = `press` v = client->_event( `TOGGLE_EDIT` ) )->a( n = `type` v = COND #( WHEN mv_edit_mode = abap_true THEN `Emphasized` ELSE `Transparent` ) )->a( n = `enabled` v = lv_has
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://save` )->a( n = `press` v = client->_event( `SAVE` ) )->a( n = `type` v = `Transparent` )->a( n = `enabled` v = lv_edit
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://syntax` )->a( n = `press` v = client->_event( `CHECK` ) )->a( n = `type` v = `Transparent` )->a( n = `enabled` v = lv_has
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://activate` )->a( n = `press` v = client->_event( `ACTIVATE` ) )->a( n = `type` v = `Transparent` )->a( n = `enabled` v = lv_has
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://text-formatting` )->a( n = `press` v = client->_event( `PRETTY_PRINT` ) )->a( n = `type` v = `Transparent` )->a( n = `enabled` v = lv_has
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://compare` )->a( n = `press` v = client->_event( `COMPARE` ) )->a( n = `type` v = `Transparent` )->a( n = `enabled` v = lv_has
        )->leaf( `ToolbarSeparator`
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://nav-back` )->a( n = `press` v = client->_event( `NAV_BACK` ) )->a( n = `type` v = `Transparent`
            )->a( n = `enabled` v = COND #( WHEN mv_hist_pos > 1 THEN `true` ELSE `false` )
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://nav-forward` )->a( n = `press` v = client->_event( `NAV_FORWARD` ) )->a( n = `type` v = `Transparent`
            )->a( n = `enabled` v = COND #( WHEN mv_hist_pos < lines( mt_history ) THEN `true` ELSE `false` )
        )->leaf( `ToolbarSeparator`
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://search` )->a( n = `press` v = client->_event( `WHERE_USED` ) )->a( n = `type` v = `Transparent` )->a( n = `enabled` v = lv_has
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://chain-link` )->a( n = `press` v = client->_event( `SHOW_DEPS` ) )->a( n = `type` v = `Transparent` )->a( n = `enabled` v = lv_has )->a( n = `tooltip` v = `Dependencies`
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://refresh` )->a( n = `press` v = client->_event( `REFRESH` ) )->a( n = `type` v = `Transparent`
        )->leaf( `ToolbarSeparator`
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://create` )->a( n = `press` v = client->_event( `CREATE_OBJ` ) )->a( n = `type` v = `Transparent` )->a( n = `tooltip` v = `Create`
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://delete`
            )->a( n = `press` v = COND #( WHEN mv_msg_type = `Warning` AND mv_message CS `Delete`
                THEN client->_event( `CONFIRM_DELETE` ) ELSE client->_event( `DELETE_OBJ` ) )
            )->a( n = `type` v = `Transparent` )->a( n = `enabled` v = lv_has
        )->leaf( `ToolbarSeparator`
        )->leaf( `Button` )->a( n = `icon` v = `sap-icon://copy` )->a( n = `press` v = client->_event_client(
            val = client->cs_event-clipboard_copy t_arg = VALUE #( ( client->_bind( val = mv_source path = `X` ) ) ) )
            )->a( n = `type` v = `Transparent` )->a( n = `tooltip` v = `Copy source to clipboard`
        )->leaf( `Button` )->a( n = `icon` v = COND #( WHEN mv_fullscreen = abap_true THEN `sap-icon://exit-full-screen` ELSE `sap-icon://full-screen` )
            )->a( n = `press` v = client->_event( `FULLSCREEN` ) )->a( n = `type` v = `Transparent` )->a( n = `tooltip` v = `Toggle Fullscreen`
    )->shut( ).

    " Quick nav + Breadcrumb + Lock info bar
    lo_r->open( `Toolbar` )->a( n = `height` v = `2rem` ).
    lo_r->leaf( `Input`
        )->a( n = `value` v = client->_bind( mv_quick_nav )
        )->a( n = `width` v = `160px`
        )->a( n = `placeholder` v = `Jump to object...`
        )->a( n = `submit` v = client->_event( `QUICK_NAV` ) ).
    IF mv_breadcrumb IS NOT INITIAL.
      lo_r->leaf( `Text` )->a( n = `text` v = mv_breadcrumb ).
    ENDIF.
    IF mv_lock_info IS NOT INITIAL.
      lo_r->leaf( `ObjectStatus`
          )->a( n = `text` v = mv_lock_info
          )->a( n = `state` v = `Warning` ).
    ENDIF.
    lo_r->leaf( `ToolbarSpacer` ).
    lo_r->leaf( `Button`
        )->a( n = `icon` v = COND #( WHEN mv_dark_theme = abap_true THEN `sap-icon://lightbulb` ELSE `sap-icon://darkmode` )
        )->a( n = `press` v = client->_event( `TOGGLE_THEME` )
        )->a( n = `type` v = `Transparent`
        )->a( n = `tooltip` v = `Toggle Dark/Light Theme` ).
    lo_r->shut( ).

    " Find & Replace + Goto Line bar
    lo_r->open( `Toolbar` )->a( n = `height` v = `2rem` ).
    lo_r->leaf( `Label` )->a( n = `text` v = `Find:` ).
    lo_r->leaf( `Input`
        )->a( n = `value` v = client->_bind( mv_find )
        )->a( n = `width` v = `130px`
        )->a( n = `placeholder` v = `Search...`
        )->a( n = `submit` v = client->_event( `FIND_IN_SOURCE` ) ).
    lo_r->leaf( `Button`
        )->a( n = `icon` v = `sap-icon://search`
        )->a( n = `press` v = client->_event( `FIND_IN_SOURCE` )
        )->a( n = `type` v = `Transparent` ).
    lo_r->leaf( `Label` )->a( n = `text` v = `Repl:` ).
    lo_r->leaf( `Input`
        )->a( n = `value` v = client->_bind( mv_replace )
        )->a( n = `width` v = `130px`
        )->a( n = `placeholder` v = `Replace...`
        )->a( n = `submit` v = client->_event( `REPLACE_ALL` ) ).
    lo_r->leaf( `Button`
        )->a( n = `text` v = `All`
        )->a( n = `press` v = client->_event( `REPLACE_ALL` )
        )->a( n = `type` v = `Transparent`
        )->a( n = `enabled` v = lv_edit ).
    lo_r->leaf( `ToolbarSeparator` ).
    lo_r->leaf( `Label` )->a( n = `text` v = `Line:` ).
    lo_r->leaf( `Input`
        )->a( n = `value` v = client->_bind( mv_goto_line )
        )->a( n = `width` v = `60px`
        )->a( n = `type` v = `Number`
        )->a( n = `submit` v = client->_event( `GOTO_LINE` ) ).
    lo_r->shut( ).

    IF mv_message IS NOT INITIAL.
      lo_r->leaf( `MessageStrip` )->a( n = `text` v = mv_message )->a( n = `type` v = mv_msg_type )->a( n = `showCloseButton` v = `true` ).
    ENDIF.

    " === Tabs ===
    DATA(lo_tabs) = lo_r->open( `IconTabBar`
        )->a( n = `selectedKey` v = client->_bind( mv_active_tab )
        )->a( n = `expandable` v = `false`
        )->a( n = `stretchContentHeight` v = `true`
        )->open( `items` ).

    " Tab: Source Code (like SE80: "Class Source" / "Source Code")
    DATA(lo_t1) = lo_tabs->open( `IconTabFilter`
        )->a( n = `text` v = `Source Code`
        )->a( n = `key` v = `SRC`
        )->a( n = `icon` v = `sap-icon://syntax` ).
    DATA(lo_c1) = lo_t1->open( `content` ).
    IF mv_edit_mode = abap_true.
      lo_c1->leaf( `TextArea` )->a( n = `value` v = client->_bind( mv_source ) )->a( n = `height` v = `calc(100vh - 150px)` )->a( n = `width` v = `100%` )->a( n = `growing` v = `false` ).
    ELSE.
      lo_c1->leaf( n = `CodeEditor` ns = `ce`
          )->a( n = `value` v = client->_bind( mv_source )
          )->a( n = `type` v = mv_syntax_mode
          )->a( n = `height` v = `calc(100vh - 150px)`
          )->a( n = `width` v = `100%`
          )->a( n = `editable` v = `false`
          )->a( n = `colorTheme` v = COND #( WHEN mv_dark_theme = abap_true THEN `tomorrow_night` ELSE `tomorrow` ) ).
    ENDIF.
    lo_c1->shut( ). lo_t1->shut( ).

    " Tab: Local Definitions/Implementations
    DATA(lo_t2) = lo_tabs->open( `IconTabFilter`
        )->a( n = `text` v = `Local Definitions` )->a( n = `key` v = `LOC`
        )->a( n = `icon` v = `sap-icon://detail-view` ).
    DATA(lo_c2) = lo_t2->open( `content` ).
    IF mv_edit_mode = abap_true.
      lo_c2->leaf( `TextArea`
          )->a( n = `value` v = client->_bind( mv_source_local )
          )->a( n = `height` v = `calc(100vh - 150px)`
          )->a( n = `width` v = `100%`
          )->a( n = `growing` v = `false` ).
    ELSE.
      lo_c2->leaf( n = `CodeEditor` ns = `ce`
          )->a( n = `value` v = client->_bind( mv_source_local )
          )->a( n = `type` v = `abap`
          )->a( n = `height` v = `calc(100vh - 150px)`
          )->a( n = `width` v = `100%`
          )->a( n = `editable` v = `false`
          )->a( n = `colorTheme` v = COND #( WHEN mv_dark_theme = abap_true THEN `tomorrow_night` ELSE `tomorrow` ) ).
    ENDIF.
    lo_c2->shut( ). lo_t2->shut( ).

    " Tab: Test Classes
    DATA(lo_t3) = lo_tabs->open( `IconTabFilter`
        )->a( n = `text` v = `Test Classes` )->a( n = `key` v = `TST`
        )->a( n = `icon` v = `sap-icon://lab` ).
    DATA(lo_c3) = lo_t3->open( `content` ).
    IF mv_edit_mode = abap_true.
      lo_c3->leaf( `TextArea`
          )->a( n = `value` v = client->_bind( mv_source_test )
          )->a( n = `height` v = `calc(100vh - 150px)`
          )->a( n = `width` v = `100%`
          )->a( n = `growing` v = `false` ).
    ELSE.
      lo_c3->leaf( n = `CodeEditor` ns = `ce`
          )->a( n = `value` v = client->_bind( mv_source_test )
          )->a( n = `type` v = `abap`
          )->a( n = `height` v = `calc(100vh - 150px)`
          )->a( n = `width` v = `100%`
          )->a( n = `editable` v = `false`
          )->a( n = `colorTheme` v = COND #( WHEN mv_dark_theme = abap_true THEN `tomorrow_night` ELSE `tomorrow` ) ).
    ENDIF.
    lo_c3->shut( ). lo_t3->shut( ).

    " Tab: Text Elements (like SE80)
    DATA(lo_t5) = lo_tabs->open( `IconTabFilter`
        )->a( n = `text` v = `Text Elements`
        )->a( n = `key` v = `TXT`
        )->a( n = `icon` v = `sap-icon://text` ).
    lo_t5->open( `content`
        )->leaf( n = `CodeEditor` ns = `ce`
            )->a( n = `value` v = client->_bind( mv_text_elem )
            )->a( n = `type` v = `text`
            )->a( n = `height` v = `calc(100vh - 150px)`
            )->a( n = `width` v = `100%`
            )->a( n = `editable` v = `false`
    )->shut( ).
    lo_t5->shut( ).

    " Tab: Documentation (like SE80 "Class documentation")
    DATA(lo_t6) = lo_tabs->open( `IconTabFilter`
        )->a( n = `text` v = `Documentation`
        )->a( n = `key` v = `DOC`
        )->a( n = `icon` v = `sap-icon://document` ).
    lo_t6->open( `content`
        )->leaf( n = `CodeEditor` ns = `ce`
            )->a( n = `value` v = client->_bind( mv_docu )
            )->a( n = `type` v = `text`
            )->a( n = `height` v = `calc(100vh - 150px)`
            )->a( n = `width` v = `100%`
            )->a( n = `editable` v = `false`
    )->shut( ).
    lo_t6->shut( ).

    " Tab: Properties (like SE80 "Properties" / "Attributes")
    DATA(lo_t4) = lo_tabs->open( `IconTabFilter`
        )->a( n = `text` v = `Properties`
        )->a( n = `key` v = `INFO`
        )->a( n = `icon` v = `sap-icon://hint` ).
    DATA(lo_info) = lo_t4->open( `content` ).

    IF mt_props IS NOT INITIAL.
      DATA(lo_pl) = lo_info->open( `List` )->a( n = `headerText` v = `Properties` )->a( n = `items` v = client->_bind( mt_props ) ).
      lo_pl->open( `items` )->open( `DisplayListItem` )->a( n = `label` v = `{LABEL}` )->a( n = `value` v = `{VALUE}` )->shut( )->shut( ).
      lo_pl->shut( ).
    ENDIF.

    IF mt_methods IS NOT INITIAL.
      DATA(lo_mt) = lo_info->open( `Table` )->a( n = `headerText` v = |Methods ({ lines( mt_methods ) })| )->a( n = `items` v = client->_bind( mt_methods ) ).
      DATA(lo_mc) = lo_mt->open( `columns` ).
      lo_mc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Name` )->shut( ).
      lo_mc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Vis` )->shut( ).
      lo_mc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Type` )->shut( ).
      lo_mc->shut( ).
      lo_mt->open( `items` )->open( `ColumnListItem` )->open( `cells`
          )->leaf( `Text` )->a( n = `text` v = `{CMPNAME}`
          )->leaf( `Text` )->a( n = `text` v = `{EXPOSURE}`
          )->leaf( `Text` )->a( n = `text` v = `{MTDTYPE}`
      )->shut( )->shut( )->shut( ).
      lo_mt->shut( ).
    ENDIF.

    IF mt_fields IS NOT INITIAL.
      DATA(lo_ft) = lo_info->open( `Table` )->a( n = `headerText` v = |Fields ({ lines( mt_fields ) })| )->a( n = `items` v = client->_bind( mt_fields ) ).
      DATA(lo_fc) = lo_ft->open( `columns` ).
      lo_fc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Name` )->shut( ).
      lo_fc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Key` )->shut( ).
      lo_fc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Type` )->shut( ).
      lo_fc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Detail` )->shut( ).
      lo_fc->shut( ).
      lo_ft->open( `items` )->open( `ColumnListItem` )->open( `cells`
          )->leaf( `Text` )->a( n = `text` v = `{NAME}`
          )->leaf( `Text` )->a( n = `text` v = `{KEYFLAG}`
          )->leaf( `Text` )->a( n = `text` v = `{TYPTYPE}`
          )->leaf( `Text` )->a( n = `text` v = `{TYPE}`
      )->shut( )->shut( )->shut( ).
      lo_ft->shut( ).
    ENDIF.

    lo_info->shut( ). lo_t4->shut( ).
    lo_tabs->shut( )->shut( ).

    " === BOTTOM LOG PANEL ===
    IF mt_log IS NOT INITIAL.
      DATA(lo_log) = lo_r->open( `Panel`
          )->a( n = `headerText` v = |Messages ({ lines( mt_log ) })|
          )->a( n = `expandable` v = `true`
          )->a( n = `expanded`   v = `true`
          )->a( n = `height`     v = `150px` ).
      DATA(lo_lt) = lo_log->open( `List`
          )->a( n = `items` v = client->_bind( mt_log ) ).
      lo_lt->open( `items`
          )->open( `StandardListItem`
              )->a( n = `title` v = `{MESSAGE}`
              )->a( n = `info`  v = `{LINE}`
              )->a( n = `icon`  v = `{ICON}`
              )->a( n = `infoState` v = `{TYPE}`
          )->shut( )->shut( ).
      lo_lt->shut( ).
      lo_log->shut( ).
    ENDIF.

    lo_r->shut( )->shut( )->shut( )->shut( )->shut( ).

    " === WHERE-USED DIALOG ===
    IF mv_show_whereu = abap_true.
      DATA(lo_d) = view->open( `Dialog` )->a( n = `title` v = |Where-Used: { mv_cur_obj_name }| )->a( n = `contentWidth` v = `500px` )->a( n = `contentHeight` v = `400px` ).
      IF mt_usages IS NOT INITIAL.
        lo_d->open( `List` )->a( n = `items` v = client->_bind( mt_usages )
            )->open( `items` )->open( `StandardListItem`
                )->a( n = `title` v = `{OBJ_NAME}` )->a( n = `description` v = `{OBJECT}` )->a( n = `type` v = `Active`
                )->a( n = `press` v = client->_event( val = `USAGE_CLICK` t_arg = VALUE #( ( `${OBJ_NAME}` ) ( `${OBJECT}` ) ) )
            )->shut( )->shut( )->shut( ).
      ELSE.
        lo_d->leaf( `MessageStrip` )->a( n = `text` v = `No usages found.` )->a( n = `type` v = `Information` ).
      ENDIF.
      lo_d->open( `beginButton` )->leaf( `Button` )->a( n = `text` v = `Close` )->a( n = `press` v = client->_event( `CLOSE_WHEREU` ) )->shut( ).
      lo_d->shut( ).
      client->popup_display( view->stringify( ) ).
    ELSE.
      client->view_display( view->stringify( ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
