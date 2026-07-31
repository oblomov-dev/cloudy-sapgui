CLASS ltcl_se24_a2u5 DEFINITION DEFERRED.
CLASS zcl_se24_a2u5 DEFINITION LOCAL FRIENDS ltcl_se24_a2u5.

CLASS ltcl_se24_a2u5 DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_se24_a2u5.
    DATA mo_dbl TYPE REF TO zcl_zlk05_client_dbl.

    METHODS setup.
    METHODS given_hitlist.
    METHODS given_class_detail.
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
    METHODS detail_components      FOR TESTING.
    METHODS detail_back_to_list    FOR TESTING.
ENDCLASS.


CLASS ltcl_se24_a2u5 IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
    mo_dbl = NEW #( ).
    mo_cut->client = mo_dbl.
  ENDMETHOD.

  METHOD given_hitlist.
    mo_cut->mv_clsname = `ZCL_*`.
    mo_cut->mt_classes = VALUE #(
        ( clsname = `ZCL_SE11_A2U5` clstype = `Class`     descr = `ABAP Dictionary (abap2UI5)` )
        ( clsname = `ZIF_DEMO`      clstype = `Interface` descr = `Demo Interface` ) ).
  ENDMETHOD.

  METHOD given_class_detail.
    mo_cut->mv_mode       = `DETAIL`.
    mo_cut->mv_current    = `ZCL_SE11_A2U5`.
    mo_cut->mt_components = VALUE #(
        ( cmpname = `VIEW_DISPLAY` cmptype = `Method`    mtdtype = `Instance Method`
          exposure = `Protected` redefin = `` )
        ( cmpname = `MV_OBJNAME`   cmptype = `Attribute` mtdtype = ``
          exposure = `Public`    redefin = `` ) ).
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

    assert_shell_sane( `SE24 initial screen` ).
  ENDMETHOD.

  METHOD list_original_title.
    given_hitlist( ).
    mo_cut->view_display( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view
                             sub = `Class Builder: Initial Screen` ) >= 0 )
        msg = 'the original SE24 screen title is missing' ).
  ENDMETHOD.

  METHOD list_selection_screen.
    given_hitlist( ).
    mo_cut->view_display( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( mo_dbl->count_children( `subHeader` ) > 0 )
        msg = 'the selection screen (subHeader) is empty' ).
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `Object Type` ) >= 0 )
        msg = 'the Object Type field label is missing' ).
  ENDMETHOD.

  METHOD list_back_nav_wired.
    given_hitlist( ).
    mo_dbl->mv_prev_stack = abap_true.
    mo_cut->view_display( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `MOCK_NAV_LEAVE` ) >= 0 )
        msg = 'navButtonPress is not wired to _event_nav_app_leave( )' ).
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `showNavButton` ) >= 0 )
        msg = 'showNavButton is not bound to check_app_prev_stack( )' ).
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
    CLEAR mo_cut->mt_classes.
    mo_cut->view_display( ).

    assert_shell_sane( `SE24 initial screen without hits` ).
  ENDMETHOD.

  METHOD message_reaches_view.
    mo_cut->mv_message = `Class ZCL_UNKNOWN does not exist.`.
    mo_cut->mv_msgtype = `Error`.
    mo_cut->view_display( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `MessageStrip` ) >= 0
                   AND find( val = mo_dbl->mv_view
                             sub = `Class ZCL_UNKNOWN does not exist.` ) >= 0 )
        msg = 'the message text never reaches the selection screen' ).
  ENDMETHOD.

  " ===================== display screen =====================

  METHOD detail_is_sane.
    given_class_detail( ).
    mo_cut->view_detail( ).

    assert_shell_sane( `SE24 class display` ).
  ENDMETHOD.

  METHOD detail_title.
    given_class_detail( ).
    mo_cut->view_detail( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view
                             sub = `Class Builder: Display ZCL_SE11_A2U5` ) >= 0 )
        msg = 'the class display does not carry the original SE24 title' ).
  ENDMETHOD.

  METHOD detail_components.
    " the component list is the payload of the class display
    given_class_detail( ).
    mo_cut->view_detail( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `{CMPNAME}` ) >= 0
                   AND find( val = mo_dbl->mv_view sub = `{EXPOSURE}` ) >= 0 )
        msg = 'the component list is not bound to the component structure' ).
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `Visibility` ) >= 0 )
        msg = 'the visibility column is missing' ).
  ENDMETHOD.

  METHOD detail_back_to_list.
    given_class_detail( ).
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
