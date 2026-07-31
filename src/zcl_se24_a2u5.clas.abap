CLASS zcl_se24_a2u5 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA mv_clsname    TYPE string.
    DATA mv_mode       TYPE string.
    DATA mv_current    TYPE string.
    DATA mv_message    TYPE string.
    DATA mv_msgtype    TYPE string.
    DATA mt_classes    TYPE zcl_zlk05_sys_api=>ty_t_class.
    DATA mt_components TYPE zcl_zlk05_sys_api=>ty_t_component.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS view_detail.
    METHODS on_event.
    METHODS do_search.
    METHODS do_open
      IMPORTING iv_clsname TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_se24_a2u5 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.

    IF client->check_on_init( ).
      mv_mode = `LIST`.
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    DATA(lv_event) = client->get( )-event.
    DATA(lt_arg)   = client->get( )-t_event_arg.
    CLEAR: mv_message, mv_msgtype.

    CASE lv_event.
      WHEN 'EXECUTE'.
        do_search( ).
      WHEN 'DISPLAY'.
        IF lines( lt_arg ) > 0.
          do_open( lt_arg[ 1 ] ).
        ENDIF.
      WHEN 'BACK_TO_LIST'.
        mv_mode = `LIST`.
      WHEN OTHERS.
    ENDCASE.

    IF mv_mode = `DETAIL`.
      view_detail( ).
    ELSE.
      view_display( ).
    ENDIF.

  ENDMETHOD.


  METHOD do_search.

    CLEAR mt_classes.
    mt_classes = zcl_zlk05_sys_api=>search_classes( mv_clsname ).
    mv_mode    = `LIST`.

    IF lines( mt_classes ) = 0.
      mv_message = `No classes or interfaces found for the selection.`.
      mv_msgtype = `Warning`.
    ELSE.
      mv_message = |{ lines( mt_classes ) } object(s) found.|.
      mv_msgtype = `Success`.
    ENDIF.

  ENDMETHOD.


  METHOD do_open.

    CLEAR mt_components.
    mv_current    = iv_clsname.
    mt_components = zcl_zlk05_sys_api=>get_class_components( iv_clsname ).

    IF lines( mt_components ) = 0.
      mv_message = |{ iv_clsname } has no components.|.
      mv_msgtype = `Warning`.
      RETURN.
    ENDIF.

    mv_mode = `DETAIL`.

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ai_xml=>factory( ).

    DATA(page) = view->open( n = `View` ns = `mvc`
        )->a( n = `xmlns`     v = `sap.m`
        )->a( n = `xmlns:mvc` v = `sap.ui.core.mvc`
        )->open( `Shell`
        )->open( `Page`
            )->a( n = `title`          v = `Class Builder: Initial Screen`
            )->a( n = `showNavButton`  v = z2ui5_cl_ai_xml=>as_bool( client->check_app_prev_stack( ) )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    DATA(sel) = page->open( `subHeader` )->open( `OverflowToolbar` ).
    sel->leaf( `Label`
        )->a( n = `text` v = `Object Type`
        )->leaf( `Input`
            )->a( n = `id`          v = `idClsName`
            )->a( n = `value`       v = client->_bind( mv_clsname )
            )->a( n = `placeholder` v = `e.g. CL_GUI_ALV_GRID or ZCL_*`
            )->a( n = `width`       v = `24rem`
            )->a( n = `submit`      v = client->_event( `EXECUTE` )
        )->leaf( `Button`
            )->a( n = `text`  v = `Display`
            )->a( n = `icon`  v = `sap-icon://display`
            )->a( n = `type`  v = `Emphasized`
            )->a( n = `press` v = client->_event( `EXECUTE` ) ).

    client->follow_up_action(
        val   = client->cs_event-set_focus
        t_arg = VALUE #( ( `idClsName` ) ) ).

    IF mv_message IS NOT INITIAL.
      page->leaf( `MessageStrip`
          )->a( n = `text`     v = mv_message
          )->a( n = `type`     v = mv_msgtype
          )->a( n = `showIcon` v = `true`
          )->a( n = `class`    v = `sapUiTinyMargin` ).
    ENDIF.

    DATA(tab) = page->open( `Table`
        )->a( n = `items`   v = client->_bind( mt_classes )
        )->a( n = `sticky`  v = `ColumnHeaders`
        )->a( n = `growing` v = `true`
        )->a( n = `class`   v = `sapUiSizeCompact` ).

    DATA(cols) = tab->open( `columns` ).
    cols->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Object Name` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Type` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Description` )->shut( ).

    cols->shut( )->open( `items`
        )->open( `ColumnListItem`
            )->a( n = `type`  v = `Navigation`
            )->a( n = `press` v = client->_event( val   = `DISPLAY`
                                                 t_arg = VALUE #( ( `${CLSNAME}` ) ) )
            )->open( `cells`
                )->leaf( `Text` )->a( n = `text` v = `{CLSNAME}`
                )->leaf( `Text` )->a( n = `text` v = `{CLSTYPE}`
                )->leaf( `Text` )->a( n = `text` v = `{DESCR}` ).

    page->open( `footer` )->open( `OverflowToolbar`
        )->leaf( `ToolbarSpacer`
        )->leaf( `Label` )->a( n = `text` v = |System { sy-sysid } | &&
                                              |Client { sy-mandt } | &&
                                              |User { sy-uname }| ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD view_detail.

    DATA(view) = z2ui5_cl_ai_xml=>factory( ).

    DATA(page) = view->open( n = `View` ns = `mvc`
        )->a( n = `xmlns`     v = `sap.m`
        )->a( n = `xmlns:mvc` v = `sap.ui.core.mvc`
        )->open( `Shell`
        )->open( `Page`
            )->a( n = `title`          v = |Class Builder: Display { mv_current }|
            )->a( n = `showNavButton`  v = `true`
            )->a( n = `navButtonPress` v = client->_event( `BACK_TO_LIST` ) ).

    DATA(tab) = page->open( `Table`
        )->a( n = `items`   v = client->_bind( mt_components )
        )->a( n = `sticky`  v = `ColumnHeaders`
        )->a( n = `growing` v = `true`
        )->a( n = `class`   v = `sapUiSizeCompact` ).

    DATA(cols) = tab->open( `columns` ).
    cols->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Component` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Kind` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Method Type` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Visibility` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Redefined` )->shut( ).

    cols->shut( )->open( `items`
        )->open( `ColumnListItem` )->open( `cells`
            )->leaf( `Text` )->a( n = `text` v = `{CMPNAME}`
            )->leaf( `Text` )->a( n = `text` v = `{CMPTYPE}`
            )->leaf( `Text` )->a( n = `text` v = `{MTDTYPE}`
            )->leaf( `Text` )->a( n = `text` v = `{EXPOSURE}`
            )->leaf( `Text` )->a( n = `text` v = `{REDEFIN}` ).

    page->open( `footer` )->open( `OverflowToolbar`
        )->leaf( `Button`
            )->a( n = `text`  v = `Back`
            )->a( n = `icon`  v = `sap-icon://nav-back`
            )->a( n = `press` v = client->_event( `BACK_TO_LIST` )
        )->leaf( `ToolbarSpacer`
        )->leaf( `Label` )->a( n = `text` v = |{ lines( mt_components ) } component(s)| ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
