CLASS zcl_sapgui_a2ui5 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_tcode,
        tcode TYPE string,
        text  TYPE string,
        icon  TYPE string,
        class TYPE string,
      END OF ty_s_tcode.
    TYPES ty_t_tcode TYPE STANDARD TABLE OF ty_s_tcode WITH EMPTY KEY.

    DATA mv_command   TYPE string.
    DATA mt_favorites TYPE ty_t_tcode.
    DATA mt_all_tcodes TYPE ty_t_tcode.
    DATA mv_message   TYPE string.
    DATA mv_msg_type  TYPE string.
    DATA mv_username  TYPE string.
    DATA mv_sysid     TYPE string.
    DATA mv_client    TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    METHODS view_display.
    METHODS on_event.
    METHODS navigate_to_tcode IMPORTING iv_tcode TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_sapgui_a2ui5 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.
    me->client = client.

    IF client->check_on_init( ).
      mv_username = CONV string( sy-uname ).
      mv_sysid = CONV string( sy-sysid ).
      mv_client = CONV string( sy-mandt ).

      " Define available transactions
      mt_all_tcodes = VALUE #(
        ( tcode = `SE80`  text = `Object Navigator`           icon = `sap-icon://course-book`   class = `ZCL_SE80_UI` )
        ( tcode = `SE16N` text = `General Table Display`      icon = `sap-icon://grid`          class = `ZCL_SE16N_A2U5` )
        ( tcode = `SE11`  text = `CDS View Browser`           icon = `sap-icon://database`      class = `ZCL_CDS_VIEWER_A2U5` )
        ( tcode = `SE38`  text = `ABAP Editor`                icon = `sap-icon://document-text` class = `ZCL_SE80_UI` )
        ( tcode = `SE24`  text = `Class Builder`              icon = `sap-icon://course-book`   class = `ZCL_SE80_UI` )
        ( tcode = `SE37`  text = `Function Builder`           icon = `sap-icon://wrench`        class = `ZCL_SE80_UI` )
        ( tcode = `SE93`  text = `Transaction Maintenance`    icon = `sap-icon://action-settings` class = `` )
        ( tcode = `SM30`  text = `Table Maintenance`          icon = `sap-icon://grid`          class = `` )
        ( tcode = `SU01`  text = `User Maintenance`           icon = `sap-icon://person-placeholder` class = `` )
        ( tcode = `ST22`  text = `ABAP Dump Analysis`         icon = `sap-icon://alert`         class = `` )
      ).

      mt_favorites = VALUE #(
        ( tcode = `SE80`  text = `Object Navigator`           icon = `sap-icon://course-book`   class = `ZCL_SE80_UI` )
        ( tcode = `SE16N` text = `General Table Display`      icon = `sap-icon://grid`          class = `ZCL_SE16N_A2U5` )
        ( tcode = `SE11`  text = `CDS View Browser`           icon = `sap-icon://database`      class = `ZCL_CDS_VIEWER_A2U5` )
      ).

      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.
  ENDMETHOD.


  METHOD on_event.
    DATA(lv_event) = client->get( )-event.
    DATA(lt_arg) = client->get( )-t_event_arg.
    CLEAR: mv_message, mv_msg_type.

    CASE lv_event.
      WHEN 'EXECUTE'.
        IF mv_command IS NOT INITIAL.
          navigate_to_tcode( to_upper( mv_command ) ).
        ENDIF.

      WHEN 'TCODE_CLICK'.
        IF lines( lt_arg ) > 0.
          navigate_to_tcode( lt_arg[ 1 ] ).
        ENDIF.

      WHEN OTHERS.
    ENDCASE.
    view_display( ).
  ENDMETHOD.


  METHOD navigate_to_tcode.
    " Find the class for this transaction
    READ TABLE mt_all_tcodes WITH KEY tcode = iv_tcode ASSIGNING FIELD-SYMBOL(<tc>).
    IF sy-subrc = 0.
      IF <tc>-class IS NOT INITIAL.
        TRY.
            DATA lo_app TYPE REF TO z2ui5_if_app.
            CREATE OBJECT lo_app TYPE (<tc>-class).
            client->nav_app_call( lo_app ).
          CATCH cx_root INTO DATA(lx).
            mv_message = |Error starting { iv_tcode }: { lx->get_text( ) }|.
            mv_msg_type = `Error`.
        ENDTRY.
      ELSE.
        mv_message = |Transaction { iv_tcode } is not yet implemented.|.
        mv_msg_type = `Warning`.
      ENDIF.
    ELSE.
      " Try to find a class directly (ZCL_<tcode>_A2UI5)
      mv_message = |Transaction { iv_tcode } not found.|.
      mv_msg_type = `Error`.
    ENDIF.
  ENDMETHOD.


  METHOD view_display.
    DATA(view) = z2ui5_cl_ai_xml=>factory( ).

    " Level 1: View
    view->open( n = `View` ns = `mvc`
        )->a( n = `xmlns` v = `sap.m`
        )->a( n = `xmlns:mvc` v = `sap.ui.core.mvc`
        )->a( n = `xmlns:core` v = `sap.ui.core`
        )->a( n = `height` v = `100%` ).

    " Level 2: Page
    view->open( `Page`
        )->a( n = `title` v = |SAP Easy Access - { mv_sysid }/{ mv_client }| ).

    " Command toolbar
    view->open( `subHeader` ).
    view->open( `Toolbar` ).
    view->leaf( `Label` )->a( n = `text` v = `Transaction:` ).
    view->leaf( `Input`
        )->a( n = `value` v = client->_bind( mv_command )
        )->a( n = `width` v = `200px`
        )->a( n = `placeholder` v = `TCode...`
        )->a( n = `submit` v = client->_event( `EXECUTE` ) ).
    view->leaf( `Button`
        )->a( n = `text` v = `Go`
        )->a( n = `press` v = client->_event( `EXECUTE` )
        )->a( n = `type` v = `Emphasized` ).
    view->leaf( `ToolbarSpacer` ).
    view->leaf( `Text` )->a( n = `text` v = |{ mv_username } @ { mv_sysid }| ).
    view->shut( ). " Toolbar
    view->shut( ). " subHeader

    " Message
    IF mv_message IS NOT INITIAL.
      view->leaf( `MessageStrip`
          )->a( n = `text` v = mv_message
          )->a( n = `type` v = mv_msg_type ).
    ENDIF.

    " Favorites List
    view->open( `List`
        )->a( n = `headerText` v = `Favorites`
        )->a( n = `items` v = client->_bind( mt_favorites ) ).
    view->open( `items` ).
    view->open( `StandardListItem`
        )->a( n = `title` v = `{TEXT}`
        )->a( n = `description` v = `{TCODE}`
        )->a( n = `icon` v = `{ICON}`
        )->a( n = `type` v = `Active`
        )->a( n = `press` v = client->_event( val = `TCODE_CLICK` t_arg = VALUE #( ( `${TCODE}` ) ) ) ).
    view->shut( ). " StandardListItem
    view->shut( ). " items
    view->shut( ). " List

    " All Transactions List
    view->open( `List`
        )->a( n = `headerText` v = |All Transactions ({ lines( mt_all_tcodes ) })|
        )->a( n = `items` v = client->_bind( mt_all_tcodes ) ).
    view->open( `items` ).
    view->open( `StandardListItem`
        )->a( n = `title` v = `{TCODE}`
        )->a( n = `description` v = `{TEXT}`
        )->a( n = `icon` v = `{ICON}`
        )->a( n = `type` v = `Active`
        )->a( n = `press` v = client->_event( val = `TCODE_CLICK` t_arg = VALUE #( ( `${TCODE}` ) ) ) ).
    view->shut( ). " StandardListItem
    view->shut( ). " items
    view->shut( ). " List

    " Close Page + View
    view->shut( ). " Page
    view->shut( ). " View

    client->view_display( view->stringify( ) ).
  ENDMETHOD.

ENDCLASS.
