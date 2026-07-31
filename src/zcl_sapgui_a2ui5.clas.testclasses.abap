CLASS ltcl_launcher DEFINITION DEFERRED.
CLASS zcl_sapgui_a2ui5 DEFINITION LOCAL FRIENDS ltcl_launcher.

CLASS ltcl_launcher DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_sapgui_a2ui5.
    DATA mo_dbl TYPE REF TO zcl_zlk05_client_dbl.

    METHODS setup.

    " --- command field ---
    METHODS cmd_plain            FOR TESTING.
    METHODS cmd_slash_prefixes   FOR TESTING.
    METHODS cmd_spaces_and_case  FOR TESTING.

    " --- starting transactions ---
    METHODS every_menu_app_starts FOR TESTING.
    METHODS favorites_are_startable FOR TESTING.
    METHODS unknown_tcode         FOR TESTING.
    METHODS listed_but_no_app     FOR TESTING.
    METHODS core_tcodes_implemented FOR TESTING.

    " --- view ---
    METHODS view_wellformed      FOR TESTING.
    METHODS view_shows_status    FOR TESTING.
ENDCLASS.


CLASS ltcl_launcher IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
    mo_dbl = NEW #( ).
    mo_cut->client = mo_dbl.
    mo_cut->init_menu( ).
  ENDMETHOD.

  " ===================== command field =====================

  METHOD cmd_plain.
    cl_abap_unit_assert=>assert_equals(
        exp = `SE80` act = mo_cut->normalize_command( `SE80` ) ).
  ENDMETHOD.

  METHOD cmd_slash_prefixes.
    " SAP GUI command field syntax
    cl_abap_unit_assert=>assert_equals(
        exp = `SE80` act = mo_cut->normalize_command( `/nSE80` ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = `SE80` act = mo_cut->normalize_command( `/oSE80` ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = `SE80` act = mo_cut->normalize_command( `/SE80` ) ).
  ENDMETHOD.

  METHOD cmd_spaces_and_case.
    cl_abap_unit_assert=>assert_equals(
        exp = `SE16N` act = mo_cut->normalize_command( `  se16n  ` ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = `SE16N` act = mo_cut->normalize_command( `/n se16n` ) ).
  ENDMETHOD.

  " ===================== starting transactions =====================

  METHOD every_menu_app_starts.
    " Each menu entry that names a class must really be instantiable and must
    " navigate to exactly that app - a typo in the class name would only show
    " up at runtime otherwise.
    LOOP AT mo_cut->mt_all_tcodes INTO DATA(ls_tc) WHERE class IS NOT INITIAL.
      mo_dbl->reset( ).

      cl_abap_unit_assert=>assert_equals(
          exp = abap_true
          act = mo_cut->start_transaction( ls_tc-tcode )
          msg = |transaction { ls_tc-tcode } does not start| ).

      cl_abap_unit_assert=>assert_equals(
          exp = to_upper( ls_tc-class )
          act = mo_dbl->mv_nav_call
          msg = |transaction { ls_tc-tcode } navigates to the wrong app| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD favorites_are_startable.
    " every favorite must also exist in the SAP menu and carry an app
    LOOP AT mo_cut->mt_favorites INTO DATA(ls_fav).
      cl_abap_unit_assert=>assert_not_initial(
          act = ls_fav-class
          msg = |favorite { ls_fav-tcode } has no app assigned| ).

      cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mo_cut->mt_all_tcodes[ tcode = ls_fav-tcode ] ) )
          msg = |favorite { ls_fav-tcode } is missing in the SAP menu| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD unknown_tcode.
    cl_abap_unit_assert=>assert_equals(
        exp = abap_false
        act = mo_cut->start_transaction( `ZZUNKNOWN` ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = `Error` act = mo_cut->mv_msg_type ).
    cl_abap_unit_assert=>assert_initial(
        act = mo_dbl->mv_nav_call
        msg = 'an unknown transaction must not navigate anywhere' ).
  ENDMETHOD.

  METHOD listed_but_no_app.
    " SE93 is listed in the SAP menu but has no app behind it
    cl_abap_unit_assert=>assert_equals(
        exp = abap_false
        act = mo_cut->start_transaction( `SE93` ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = `Warning` act = mo_cut->mv_msg_type ).
    cl_abap_unit_assert=>assert_initial(
        act = mo_dbl->mv_nav_call
        msg = 'a listed but unimplemented transaction must not navigate' ).
  ENDMETHOD.

  METHOD core_tcodes_implemented.
    " Regression guard: these classic transactions must stay wired up,
    " otherwise the SAP menu silently loses an app.
    DATA(lt_expected) = VALUE string_table(
      ( `SE80` ) ( `SE38` ) ( `SE11` ) ( `SE24` ) ( `SE37` ) ( `SE16N` )
      ( `SM21` ) ( `SM37` ) ( `SM50` ) ( `SM12` ) ( `ST22` ) ( `ST02` )
      ( `ST05` ) ( `SU01` ) ( `SCC4` ) ( `RZ11` ) ( `STMS` ) ).

    LOOP AT lt_expected INTO DATA(lv_tcode).
      READ TABLE mo_cut->mt_all_tcodes INTO DATA(ls_tc)
           WITH KEY tcode = lv_tcode.
      cl_abap_unit_assert=>assert_subrc(
          exp = 0
          msg = |transaction { lv_tcode } is missing from the SAP menu| ).
      cl_abap_unit_assert=>assert_not_initial(
          act = ls_tc-class
          msg = |transaction { lv_tcode } has no implementing app| ).
    ENDLOOP.
  ENDMETHOD.

  " ===================== view =====================

  METHOD view_wellformed.
    mo_cut->view_display( ).
    cl_abap_unit_assert=>assert_initial(
        act = mo_dbl->get_xml_errors( )
        msg = 'the SAP Easy Access view is not well formed XML' ).
  ENDMETHOD.

  METHOD view_shows_status.
    " the status bar shows system / client / user - it used to be dead code
    mo_cut->mv_sysid    = `S4H`.
    mo_cut->mv_client   = `100`.
    mo_cut->mv_username = `TESTUSER`.
    mo_cut->view_display( ).

    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `S4H` ) >= 0 )
        msg = 'the status bar does not show the system id' ).
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `TESTUSER` ) >= 0 )
        msg = 'the status bar does not show the user name' ).
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( find( val = mo_dbl->mv_view sub = `100` ) >= 0 )
        msg = 'the status bar does not show the client' ).
  ENDMETHOD.

ENDCLASS.
