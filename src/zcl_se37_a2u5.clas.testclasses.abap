CLASS ltcl_se37_a2u5 DEFINITION DEFERRED.
CLASS zcl_se37_a2u5 DEFINITION LOCAL FRIENDS ltcl_se37_a2u5.

CLASS ltcl_se37_a2u5 DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_se37_a2u5.
    DATA mo_dbl TYPE REF TO zcl_zlk05_client_dbl.

    METHODS setup.
    METHODS given_hitlist.
    METHODS given_function_detail.
    METHODS assert_shell_sane
      IMPORTING iv_ctx TYPE string.

    METHODS list_is_sane           FOR TESTING.
    METHODS list_original_title    FOR TESTING.
    METHODS list_selection_screen  FOR TESTING.
    METHODS list_back_nav_wired    FOR TESTING.
    METHODS list_status_bar        FOR TESTING.
    METHODS list_empty_is_sane     FOR TESTING.
    METHODS message_reaches_view   FOR TESTING.

    METHODS detail_is_sane         FOR TESTING.
    METHODS detail_title           FOR TESTING.
    METHODS detail_all_param_kinds FOR TESTING.
    METHODS detail_back_to_list    FOR TESTING.
ENDCLASS.


CLASS ltcl_se37_a2u5 IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
    mo_dbl = NEW #( ).
    mo_cut->client = mo_dbl.
  ENDMETHOD.

  METHOD given_hitlist.
    mo_cut->mv_funcname  = `BAPI_*`.
    mo_cut->mt_functions = VALUE #(
        ( funcname = `BAPI_MATERIAL_GET_DETAIL` area = `MATERIAL_BAPI`
          stext = `Material Detail` rfc = `X` )
        ( funcname = `POPUP_TO_CONFIRM` area = `SPO1`
          stext = `Confirmation Popup` rfc = `` ) ).
  ENDMETHOD.

  METHOD given_function_detail.
    mo_cut->mv_mode    = `DETAIL`.
    mo_cut->mv_current = `BAPI_MATERIAL_GET_DETAIL`.
    " all four parameter kinds of the SE37 interface screen
    mo_cut->mt_params  = VALUE #(
        ( pos = `1` kind = `IMPORTING` parameter = `MATERIAL` typing = `TYPE`
          reference = `MATNR` optional = `` default = `` )
        ( pos = `2` kind = `EXPORTING` parameter = `RETURN` typing = `TYPE`
          reference = `BAPIRETURN` optional = `` default = `` )
        ( pos = `3` kind = `CHANGING`  parameter = `CS_DATA` typing = `TYPE`
          reference = `ANY` optional = `X` default = `` )
        ( pos = `4` kind = `TABLES`    parameter = `IT_LINES` typing = `STRUCTURE`
          reference = `BAPI_LINE` optional = `X` default = `` ) ).
  ENDMETHOD.

  METHOD assert_shell_sane.
    cl_abap_unit_assert=>assert_initial(
        act = mo_dbl->get_xml_errors( )
        msg = |{ iv_ctx }: view is not well formed XML| ).

    cl_abap_unit_assert=>assert_equals(
        exp = -1
        act = find( val = mo_dbl->get_root_name( ) sub = `ROOT ELEMENT` )
        msg = |{ iv_ctx }: expected exactly one root, got { mo_dbl->get_root_name( ) }| ).

    LOOP AT VALUE string_table( ( `columns` ) ( `items` ) ( `cells` )
                                ( `footer` ) ( `OverflowToolbar` ) )
         INTO DATA(lv_container).
      cl_abap_unit_assert=>assert_equals(
          exp = 0
          act = mo_dbl->count_empty_elements( lv_container )
          msg = |{ iv_ctx }: <{ lv_container }> rendered without any child| ).
    ENDLOOP.
  ENDMETHOD.

  " ===================== initial screen =====================

  METHOD list_is_sane.
    given_hitlist( ).
    mo_cut->view_display( ).

    assert_shell_sane( `SE37 initial screen` ).
  ENDMETHOD.

  METHOD list_original_title.
    given_hitlist( ).
    mo_cut->view_display( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view
                             sub = `Function Builder: Initial Screen` ) >= 0 )
        msg = 'the original SE37 screen title is missing' ).
  ENDMETHOD.

  METHOD list_selection_screen.
    given_hitlist( ).
    mo_cut->view_display( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( mo_dbl->count_children( `subHeader` ) > 0 )
        msg = 'the selection screen (subHeader) is empty' ).
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `Function Module` ) >= 0 )
        msg = 'the Function Module field label is missing' ).
    " the RFC flag is what SE37 users look for in the hit list
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `{RFC}` ) >= 0 )
        msg = 'the RFC column is not bound' ).
  ENDMETHOD.

  METHOD list_back_nav_wired.
    given_hitlist( ).
    mo_dbl->mv_prev_stack = abap_true.
    mo_cut->view_display( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `MOCK_NAV_LEAVE` ) >= 0
                   AND find( val = mo_dbl->mv_view sub = `showNavButton` ) >= 0 )
        msg = 'F3 back navigation to the calling app is not wired' ).
  ENDMETHOD.

  METHOD list_status_bar.
    given_hitlist( ).
    mo_cut->view_display( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = |System { sy-sysid }| ) >= 0
                   AND find( val = mo_dbl->mv_view sub = |Client { sy-mandt }| ) >= 0
                   AND find( val = mo_dbl->mv_view sub = |User { sy-uname }| ) >= 0 )
        msg = 'the status bar does not show system, client and user' ).
  ENDMETHOD.

  METHOD list_empty_is_sane.
    CLEAR mo_cut->mt_functions.
    mo_cut->view_display( ).

    assert_shell_sane( `SE37 initial screen without hits` ).
  ENDMETHOD.

  METHOD message_reaches_view.
    mo_cut->mv_message = `Function module Z_UNKNOWN does not exist.`.
    mo_cut->mv_msgtype = `Error`.
    mo_cut->view_display( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `MessageStrip` ) >= 0
                   AND find( val = mo_dbl->mv_view
                             sub = `Function module Z_UNKNOWN does not exist.` ) >= 0 )
        msg = 'the message text never reaches the selection screen' ).
  ENDMETHOD.

  " ===================== display screen =====================

  METHOD detail_is_sane.
    given_function_detail( ).
    mo_cut->view_detail( ).

    assert_shell_sane( `SE37 interface display` ).
  ENDMETHOD.

  METHOD detail_title.
    given_function_detail( ).
    mo_cut->view_detail( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view
                    sub = `Function Builder: Display BAPI_MATERIAL_GET_DETAIL` ) >= 0 )
        msg = 'the interface display does not carry the original SE37 title' ).
  ENDMETHOD.

  METHOD detail_all_param_kinds.
    " SE37 shows IMPORTING / EXPORTING / CHANGING / TABLES in one list -
    " the Kind column has to be bound, otherwise the kinds are indistinguishable
    given_function_detail( ).
    mo_cut->view_detail( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `{KIND}` ) >= 0
                   AND find( val = mo_dbl->mv_view sub = `{PARAMETER}` ) >= 0
                   AND find( val = mo_dbl->mv_view sub = `{OPTIONAL}` ) >= 0 )
        msg = 'the parameter list is not bound to the parameter structure' ).
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `Associated Type` ) >= 0 )
        msg = 'the Associated Type column is missing' ).
  ENDMETHOD.

  METHOD detail_back_to_list.
    given_function_detail( ).
    mo_cut->view_detail( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `navButtonPress` ) >= 0 )
        msg = 'the display screen has no back navigation' ).
    cl_abap_unit_assert=>assert_equals(
        exp = -1
        act = find( val = mo_dbl->mv_view sub = `MOCK_NAV_LEAVE` )
        msg = 'the display screen leaves the app instead of returning to the list' ).
  ENDMETHOD.

ENDCLASS.
