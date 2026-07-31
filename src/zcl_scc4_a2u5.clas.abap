CLASS zcl_scc4_a2u5 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA mv_message TYPE string.
    DATA mv_msgtype TYPE string.
    DATA mt_clients TYPE zcl_zlk05_sys_api=>ty_t_client.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS on_event.
    METHODS do_refresh.

  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_scc4_a2u5 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.

    IF client->check_on_init( ).
      do_refresh( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    CLEAR: mv_message, mv_msgtype.

    CASE client->get( )-event.
      WHEN 'REFRESH'.
        do_refresh( ).
      WHEN OTHERS.
    ENDCASE.

    view_display( ).

  ENDMETHOD.


  METHOD do_refresh.

    CLEAR mt_clients.
    mt_clients = zcl_zlk05_sys_api=>get_clients( ).

    IF lines( mt_clients ) = 0.
      mv_message = `No clients could be read from table T000.`.
      mv_msgtype = `Error`.
    ELSE.
      mv_message = |{ lines( mt_clients ) } client(s) defined in this system.|.
      mv_msgtype = `Information`.
    ENDIF.

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ai_xml=>factory( ).

    DATA(page) = view->open( n = `View` ns = `mvc`
        )->a( n = `xmlns`     v = `sap.m`
        )->a( n = `xmlns:mvc` v = `sap.ui.core.mvc`
        )->open( `Shell`
        )->open( `Page`
            )->a( n = `title`          v = `Display View "Clients": Overview`
            )->a( n = `showNavButton`  v = z2ui5_cl_ai_xml=>as_bool( client->check_app_prev_stack( ) )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->open( `subHeader` )->open( `OverflowToolbar`
        )->leaf( `Label`
            )->a( n = `text` v = `Client maintenance - display only`
        )->leaf( `ToolbarSpacer`
        )->leaf( `Button`
            )->a( n = `text`  v = `Refresh`
            )->a( n = `icon`  v = `sap-icon://refresh`
            )->a( n = `press` v = client->_event( `REFRESH` ) ).

    IF mv_message IS NOT INITIAL.
      page->leaf( `MessageStrip`
          )->a( n = `text`     v = mv_message
          )->a( n = `type`     v = mv_msgtype
          )->a( n = `showIcon` v = `true`
          )->a( n = `class`    v = `sapUiTinyMargin` ).
    ENDIF.

    DATA(tab) = page->open( `Table`
        )->a( n = `items`   v = client->_bind( mt_clients )
        )->a( n = `sticky`  v = `ColumnHeaders`
        )->a( n = `growing` v = `true`
        )->a( n = `class`   v = `sapUiSizeCompact` ).

    DATA(cols) = tab->open( `columns` ).
    cols->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Client` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Name` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `City` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Currency` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Role` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Changes and Transports` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Changed By` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Changed On` )->shut( ).

    cols->shut( )->open( `items`
        )->open( `ColumnListItem` )->open( `cells`
            )->leaf( `Text` )->a( n = `text` v = `{MANDT}`
            )->leaf( `Text` )->a( n = `text` v = `{MTEXT}`
            )->leaf( `Text` )->a( n = `text` v = `{ORT01}`
            )->leaf( `Text` )->a( n = `text` v = `{MWAER}`
            )->leaf( `Text` )->a( n = `text` v = `{CATTXT}`
            )->leaf( `Text` )->a( n = `text` v = `{CORACTTXT}`
            )->leaf( `Text` )->a( n = `text` v = `{CHANGEUSER}`
            )->leaf( `Text` )->a( n = `text` v = `{CHANGEDATE}` ).

    page->open( `footer` )->open( `OverflowToolbar`
        )->leaf( `ToolbarSpacer`
        )->leaf( `Label` )->a( n = `text` v = |Logged on to client { sy-mandt } | &&
                                              |in system { sy-sysid }| ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
