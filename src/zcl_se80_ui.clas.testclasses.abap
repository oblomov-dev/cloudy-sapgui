CLASS ltcl_se80_ui DEFINITION DEFERRED.
CLASS zcl_se80_ui DEFINITION LOCAL FRIENDS ltcl_se80_ui.

CLASS ltcl_se80_ui DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_se80_ui.
    DATA mo_dbl TYPE REF TO zcl_zlk05_client_dbl.

    METHODS setup.
    METHODS given_object_loaded.

    " --- main view ---
    METHODS view_wellformed      FOR TESTING.
    METHODS view_single_root     FOR TESTING.
    METHODS view_fullscreen      FOR TESTING.
    METHODS toolbars_are_filled  FOR TESTING.
    METHODS back_button_wired    FOR TESTING.

    " --- Where-Used / Used Objects popup ---
    METHODS popup_single_root    FOR TESTING.
    METHODS popup_wellformed     FOR TESTING.
    METHODS popup_without_usages FOR TESTING.
ENDCLASS.


CLASS ltcl_se80_ui IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
    mo_dbl = NEW #( ).
    mo_cut->client = mo_dbl.
  ENDMETHOD.

  METHOD given_object_loaded.
    mo_cut->mv_cur_package  = '$ZLK_05'.
    mo_cut->mv_cur_obj_name = 'ZCL_SE16N_A2U5'.
    mo_cut->mv_cur_obj_type = 'CLAS'.
    mo_cut->mv_object_title = `Class ZCL_SE16N_A2U5`.
    mo_cut->mv_status       = `Active`.
    mo_cut->mv_source       = |CLASS zcl_x DEFINITION PUBLIC.\nENDCLASS.|.
  ENDMETHOD.

  " ===================== main view =====================

  METHOD view_wellformed.
    given_object_loaded( ).
    mo_cut->view_display( ).

    cl_abap_unit_assert=>assert_initial(
        act = mo_dbl->get_xml_errors( )
        msg = 'the Object Navigator view is not well formed XML' ).
  ENDMETHOD.

  METHOD view_single_root.
    given_object_loaded( ).
    mo_cut->view_display( ).

    " stringify( ) always renders from the factory root - a second element
    " next to mvc:View would produce XML that UI5 cannot parse
    cl_abap_unit_assert=>assert_equals(
        exp = -1
        act = find( val = mo_dbl->get_root_name( ) sub = `ROOT ELEMENT` )
        msg = |expected exactly one root element, got: { mo_dbl->get_root_name( ) }| ).
  ENDMETHOD.

  METHOD view_fullscreen.
    " Full Screen On/Off hides the repository browser - both states must render
    given_object_loaded( ).
    mo_cut->mv_fullscreen = abap_true.
    mo_cut->view_display( ).

    cl_abap_unit_assert=>assert_initial(
        act = mo_dbl->get_xml_errors( )
        msg = 'the full screen view is not well formed XML' ).
  ENDMETHOD.

  METHOD toolbars_are_filled.
    given_object_loaded( ).
    mo_cut->view_display( ).

    " Every Toolbar has to carry its buttons. An empty Toolbar means the
    " return value of open( ) was dropped and the children ended up as
    " siblings of the toolbar instead of inside it.
    cl_abap_unit_assert=>assert_equals(
        exp = 0
        act = mo_dbl->count_empty_elements( `Toolbar` )
        msg = 'a Toolbar rendered without any child - toolbar nesting is broken' ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( mo_dbl->count_children( `Toolbar` ) > 0 )
        msg = 'the first Toolbar carries no child element' ).
  ENDMETHOD.

  METHOD back_button_wired.
    given_object_loaded( ).
    mo_dbl->mv_prev_stack = abap_true.
    mo_cut->view_display( ).

    " F3 / back arrow to the calling app (SAP Easy Access)
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `MOCK_NAV_LEAVE` ) >= 0 )
        msg = 'navButtonPress is not wired to _event_nav_app_leave( )' ).
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `showNavButton` ) >= 0 )
        msg = 'showNavButton is not bound to check_app_prev_stack( )' ).
  ENDMETHOD.

  " ===================== popup =====================

  METHOD popup_single_root.
    mo_cut->mv_popup_title = `Where-Used List`.
    mo_cut->mt_usages = VALUE #( ( object = 'CLAS' obj_name = 'ZCL_CALLER' ) ).

    DATA(lv_xml) = mo_cut->build_popup( ).

    cl_abap_unit_assert=>assert_equals(
        exp = -1
        act = find( val = mo_dbl->get_root_name( lv_xml ) sub = `ROOT ELEMENT` )
        msg = |popup needs exactly one root, got: { mo_dbl->get_root_name( lv_xml ) }| ).
  ENDMETHOD.

  METHOD popup_wellformed.
    mo_cut->mv_popup_title = `Where-Used List`.
    mo_cut->mt_usages = VALUE #( ( object = 'CLAS' obj_name = 'ZCL_CALLER' )
                                 ( object = 'PROG' obj_name = 'ZREPORT' ) ).

    cl_abap_unit_assert=>assert_initial(
        act = mo_dbl->get_xml_errors( mo_cut->build_popup( ) )
        msg = 'the Where-Used popup is not well formed XML' ).
  ENDMETHOD.

  METHOD popup_without_usages.
    " no hits: the popup shows a message strip and still has to be valid
    mo_cut->mv_popup_title = `Where-Used List`.
    CLEAR mo_cut->mt_usages.

    DATA(lv_xml) = mo_cut->build_popup( ).

    cl_abap_unit_assert=>assert_initial(
        act = mo_dbl->get_xml_errors( lv_xml )
        msg = 'the empty Where-Used popup is not well formed XML' ).
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = lv_xml sub = `No usage found.` ) >= 0 )
        msg = 'the empty popup does not tell the user that there are no hits' ).
  ENDMETHOD.

ENDCLASS.
