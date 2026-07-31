CLASS zcl_se11_a2u5 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA mv_objname TYPE string.
    DATA mv_kind    TYPE string.
    DATA mv_mode    TYPE string.
    DATA mv_current TYPE string.
    DATA mv_message TYPE string.
    DATA mv_msgtype TYPE string.
    DATA mt_objects TYPE zcl_zlk05_sys_api=>ty_t_ddic_obj.
    DATA mt_fields  TYPE zcl_zlk05_sys_api=>ty_t_ddic_field.
    DATA mt_detail  TYPE zcl_zlk05_sys_api=>ty_t_kv.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS view_detail.
    METHODS on_event.
    METHODS do_search.
    METHODS do_open
      IMPORTING iv_name TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_se11_a2u5 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.

    IF client->check_on_init( ).
      mv_kind = `TABL`.
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

    CLEAR mt_objects.

    mt_objects = zcl_zlk05_sys_api=>search_ddic( iv_pattern = mv_objname
                                                 iv_kind    = mv_kind ).
    mv_mode = `LIST`.

    IF lines( mt_objects ) = 0.
      mv_message = `No dictionary objects found for the selection.`.
      mv_msgtype = `Warning`.
    ELSE.
      mv_message = |{ lines( mt_objects ) } object(s) found.|.
      mv_msgtype = `Success`.
    ENDIF.

  ENDMETHOD.


  METHOD do_open.

    CLEAR: mt_fields, mt_detail.
    mv_current = iv_name.

    IF mv_kind = `DTEL`.
      mt_detail = zcl_zlk05_sys_api=>get_dtel_detail( iv_name ).
      IF lines( mt_detail ) = 0.
        mv_message = |Data element { iv_name } could not be read.|.
        mv_msgtype = `Error`.
        RETURN.
      ENDIF.
    ELSE.
      mt_fields = zcl_zlk05_sys_api=>get_table_fields( iv_name ).
      IF lines( mt_fields ) = 0.
        mv_message = |Table { iv_name } has no active field list.|.
        mv_msgtype = `Warning`.
        RETURN.
      ENDIF.
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
            )->a( n = `title`          v = `ABAP Dictionary: Initial Screen`
            )->a( n = `showNavButton`  v = z2ui5_cl_ai_xml=>as_bool( client->check_app_prev_stack( ) )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    " ===== Selection screen =====
    DATA(sel) = page->open( `subHeader` )->open( `OverflowToolbar` ).
    sel->leaf( `Label`
        )->a( n = `text` v = `Object Name`
        )->leaf( `Input`
            )->a( n = `id`          v = `idObjName`
            )->a( n = `value`       v = client->_bind( mv_objname )
            )->a( n = `placeholder` v = `e.g. MARA or MAR*`
            )->a( n = `width`       v = `18rem`
            )->a( n = `submit`      v = client->_event( `EXECUTE` ) ).

    DATA(seg) = sel->open( `Select`
        )->a( n = `selectedKey` v = client->_bind( mv_kind )
        )->a( n = `width`       v = `13rem` ).
    DATA(segi) = seg->open( `items` ).
    segi->leaf( n = `Item` ns = `core`
        )->a( n = `xmlns:core` v = `sap.ui.core`
        )->a( n = `key`        v = `TABL`
        )->a( n = `text`       v = `Database Table / View`
        )->leaf( n = `Item` ns = `core`
            )->a( n = `key`  v = `DTEL`
            )->a( n = `text` v = `Data Element` ).
    seg->shut( ).

    sel->leaf( `Button`
        )->a( n = `text`  v = `Display`
        )->a( n = `icon`  v = `sap-icon://display`
        )->a( n = `type`  v = `Emphasized`
        )->a( n = `press` v = client->_event( `EXECUTE` ) ).

    client->follow_up_action(
        val   = client->cs_event-set_focus
        t_arg = VALUE #( ( `idObjName` ) ) ).

    IF mv_message IS NOT INITIAL.
      page->leaf( `MessageStrip`
          )->a( n = `text`     v = mv_message
          )->a( n = `type`     v = mv_msgtype
          )->a( n = `showIcon` v = `true`
          )->a( n = `class`    v = `sapUiTinyMargin` ).
    ENDIF.

    " ===== Result list =====
    DATA(tab) = page->open( `Table`
        )->a( n = `items`      v = client->_bind( mt_objects )
        )->a( n = `sticky`     v = `ColumnHeaders`
        )->a( n = `growing`    v = `true`
        )->a( n = `class`      v = `sapUiSizeCompact` ).

    DATA(cols) = tab->open( `columns` ).
    cols->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Name` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Type` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Short Description` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Last Changed By` )->shut(
        )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Changed On` )->shut( ).

    cols->shut( )->open( `items`
        )->open( `ColumnListItem`
            )->a( n = `type`  v = `Navigation`
            )->a( n = `press` v = client->_event( val   = `DISPLAY`
                                                 t_arg = VALUE #( ( `${NAME}` ) ) )
            )->open( `cells`
                )->leaf( `Text` )->a( n = `text` v = `{NAME}`
                )->leaf( `Text` )->a( n = `text` v = `{TABCLASS}`
                )->leaf( `Text` )->a( n = `text` v = `{DESCR}`
                )->leaf( `Text` )->a( n = `text` v = `{AUTHOR}`
                )->leaf( `Text` )->a( n = `text` v = `{CHDATE}` ).

    " ===== Status bar =====
    page->open( `footer` )->open( `OverflowToolbar`
        )->leaf( `ToolbarSpacer`
        )->leaf( `Label` )->a( n = `text` v = |System { sy-sysid } | &&
                                              |Client { sy-mandt } | &&
                                              |User { sy-uname }| ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD view_detail.

    DATA(view) = z2ui5_cl_ai_xml=>factory( ).

    DATA(lv_title) = COND string(
        WHEN mv_kind = `DTEL`
        THEN |Dictionary: Display Data Element { mv_current }|
        ELSE |Dictionary: Display Table { mv_current }| ).

    DATA(page) = view->open( n = `View` ns = `mvc`
        )->a( n = `xmlns`     v = `sap.m`
        )->a( n = `xmlns:mvc` v = `sap.ui.core.mvc`
        )->open( `Shell`
        )->open( `Page`
            )->a( n = `title`          v = lv_title
            )->a( n = `showNavButton`  v = `true`
            )->a( n = `navButtonPress` v = client->_event( `BACK_TO_LIST` ) ).

    IF mv_kind = `DTEL`.

      DATA(dtab) = page->open( `Table`
          )->a( n = `items` v = client->_bind( mt_detail )
          )->a( n = `class` v = `sapUiSizeCompact` ).
      dtab->open( `columns`
          )->open( `Column` )->a( n = `width` v = `18rem`
              )->leaf( `Text` )->a( n = `text` v = `Property` )->shut(
          )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Value` )->shut(
          )->shut( )->open( `items`
              )->open( `ColumnListItem` )->open( `cells`
                  )->leaf( `Text` )->a( n = `text` v = `{LABEL}`
                  )->leaf( `Text` )->a( n = `text` v = `{VALUE}` ).

    ELSE.

      DATA(ftab) = page->open( `Table`
          )->a( n = `items`   v = client->_bind( mt_fields )
          )->a( n = `sticky`  v = `ColumnHeaders`
          )->a( n = `growing` v = `true`
          )->a( n = `class`   v = `sapUiSizeCompact` ).

      DATA(fcols) = ftab->open( `columns` ).
      fcols->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Pos.` )->shut(
          )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Field` )->shut(
          )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Key` )->shut(
          )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Data Element` )->shut(
          )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Type` )->shut(
          )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Length` )->shut(
          )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Dec.` )->shut(
          )->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Short Description` )->shut( ).

      fcols->shut( )->open( `items`
          )->open( `ColumnListItem` )->open( `cells`
              )->leaf( `Text` )->a( n = `text` v = `{POS}`
              )->leaf( `Text` )->a( n = `text` v = `{FIELDNAME}`
              )->leaf( `Text` )->a( n = `text` v = `{KEYFLAG}`
              )->leaf( `Text` )->a( n = `text` v = `{ROLLNAME}`
              )->leaf( `Text` )->a( n = `text` v = `{DATATYPE}`
              )->leaf( `Text` )->a( n = `text` v = `{LENG}`
              )->leaf( `Text` )->a( n = `text` v = `{DECIMALS}`
              )->leaf( `Text` )->a( n = `text` v = `{DESCR}` ).

    ENDIF.

    page->open( `footer` )->open( `OverflowToolbar`
        )->leaf( `Button`
            )->a( n = `text`  v = `Back`
            )->a( n = `icon`  v = `sap-icon://nav-back`
            )->a( n = `press` v = client->_event( `BACK_TO_LIST` )
        )->leaf( `ToolbarSpacer`
        )->leaf( `Label` )->a( n = `text` v = |System { sy-sysid } | &&
                                              |Client { sy-mandt } | &&
                                              |User { sy-uname }| ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
