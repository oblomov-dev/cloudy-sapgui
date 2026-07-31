CLASS zcl_su01_a2u5 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA mv_pattern TYPE string.
    DATA mv_mode    TYPE string.
    DATA mv_current TYPE string.
    DATA mv_message TYPE string.
    DATA mv_msgtype TYPE string.
    DATA mt_users   TYPE zcl_zlk05_sys_api=>ty_t_user.
    DATA mt_roles   TYPE zcl_zlk05_sys_api=>ty_t_role.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS view_detail.
    METHODS on_event.
    METHODS do_search.
    METHODS do_open
      IMPORTING iv_bname TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_su01_a2u5 IMPLEMENTATION.

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

    CLEAR mt_users.
    mt_users = zcl_zlk05_sys_api=>search_users( iv_pattern = mv_pattern ).
    mv_mode  = `LIST`.

    IF lines( mt_users ) = 0.
      mv_message = `No users found for the selection.`.
      mv_msgtype = `Warning`.
    ELSE.
      mv_message = |{ lines( mt_users ) } user(s) found.|.
      mv_msgtype = `Success`.
    ENDIF.

  ENDMETHOD.


  METHOD do_open.

    CLEAR mt_roles.
    mv_current = iv_bname.
    mt_roles   = zcl_zlk05_sys_api=>get_user_roles( iv_bname ).
    mv_mode    = `DETAIL`.

    IF lines( mt_roles ) = 0.
      mv_message = |User { iv_bname } has no roles assigned.|.
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
            )->a( n = `title`          v = `User Maintenance: Initial Screen`
            )->a( n = `showNavButton`  v = z2ui5_cl_ai_xml=>as_bool( client->check_app_prev_stack( ) )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    DATA(sel) = page->open( `subHeader` )->open( `OverflowToolbar` ).
    sel->leaf( `Label`
        )->a( n = `text` v = `User`
        )->leaf( `Input`
            )->a( n = `id`          v = `idUserName`
            )->a( n = `value`       v = client->_bind( mv_pattern )
            )->a( n = `placeholder` v = `* for all users`
            )->a( n = `width`       v = `18rem`
            )->a( n = `submit`      v = client->_event( `EXECUTE` )
        )->leaf( `Button`
            )->a( n = `text`  v = `Display`
            )->a( n = `icon`  v = `sap-icon://display`
            )->a( n = `type`  v = `Emphasized`
            )->a( n = `press` v = client->_event( `EXECUTE` ) ).

    client->follow_up_action(
        val   = client->cs_event-set_focus
        t_arg = VALUE #( ( `idUserName` ) ) ).

    IF mv_message IS NOT INITIAL.
      page->leaf( `MessageStrip`
          )->a( n = `text`     v = mv_message
          )->a( n = `type`     v = mv_msgtype
          )->a( n = `showIcon` v = `true`
          )->a( n = `class`    v = `sapUiTinyMargin` ).
    ENDIF.

    DATA(tab) = page->open( `Table`
        )->a( n = `items`   v = client->_bind( mt_users )
        )->a( n = `sticky`  v = `ColumnHeaders`
        )->a( n = `growing` v = `true`
        )->a( n = `class`   v = `sapUiSizeCompact` ).

    DATA(cols) = tab->open( `columns` ).
    cols->open( `Column` )->leaf( `Text` )->a( n = `text` v = `User` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Name` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `User Type` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Lock Status` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Valid To` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Last Logon` )->shut( ).

    cols->shut( )->open( `items`
        )->open( `ColumnListItem`
            )->a( n = `type`  v = `Navigation`
            )->a( n = `press` v = client->_event( val   = `DISPLAY`
                                                 t_arg = VALUE #( ( `${BNAME}` ) ) )
            )->open( `cells`
                )->leaf( `Text` )->a( n = `text` v = `{BNAME}`
                )->leaf( `Text` )->a( n = `text` v = `{FULLNAME}`
                )->leaf( `Text` )->a( n = `text` v = `{USTYPTXT}`
                )->leaf( `Text` )->a( n = `text` v = `{LOCKSTATE}`
                )->leaf( `Text` )->a( n = `text` v = `{VALIDTO}`
                )->leaf( `Text` )->a( n = `text` v = `{LASTLOGON}` ).

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
            )->a( n = `title`          v = |Display User { mv_current }: Roles|
            )->a( n = `showNavButton`  v = `true`
            )->a( n = `navButtonPress` v = client->_event( `BACK_TO_LIST` ) ).

    IF mv_message IS NOT INITIAL.
      page->leaf( `MessageStrip`
          )->a( n = `text`     v = mv_message
          )->a( n = `type`     v = mv_msgtype
          )->a( n = `showIcon` v = `true`
          )->a( n = `class`    v = `sapUiTinyMargin` ).
    ENDIF.

    DATA(tab) = page->open( `Table`
        )->a( n = `items`   v = client->_bind( mt_roles )
        )->a( n = `sticky`  v = `ColumnHeaders`
        )->a( n = `growing` v = `true`
        )->a( n = `class`   v = `sapUiSizeCompact` ).

    tab->open( `columns`
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Role` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Valid From` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Valid To` )->shut(
        )->shut( )->open( `items`
            )->open( `ColumnListItem` )->open( `cells`
                )->leaf( `Text` )->a( n = `text` v = `{AGR_NAME}`
                )->leaf( `Text` )->a( n = `text` v = `{FROM_DAT}`
                )->leaf( `Text` )->a( n = `text` v = `{TO_DAT}` ).

    page->open( `footer` )->open( `OverflowToolbar`
        )->leaf( `Button`
            )->a( n = `text`  v = `Back`
            )->a( n = `icon`  v = `sap-icon://nav-back`
            )->a( n = `press` v = client->_event( `BACK_TO_LIST` )
        )->leaf( `ToolbarSpacer`
        )->leaf( `Label` )->a( n = `text` v = |{ lines( mt_roles ) } role(s) assigned| ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
