CLASS zcl_se80_a2ui5 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    " --- Tree data model (2 levels) ---
    TYPES:
      BEGIN OF ty_s_tree_child,
        text  TYPE string,
        icon  TYPE string,
        key   TYPE string,
        otype TYPE string,
      END OF ty_s_tree_child.
    TYPES:
      BEGIN OF ty_s_tree_node,
        text  TYPE string,
        icon  TYPE string,
        key   TYPE string,
        otype TYPE string,
        nodes TYPE STANDARD TABLE OF ty_s_tree_child WITH EMPTY KEY,
      END OF ty_s_tree_node.
    TYPES ty_t_tree TYPE STANDARD TABLE OF ty_s_tree_node WITH EMPTY KEY.

    " --- Methods metadata ---
    TYPES:
      BEGIN OF ty_s_method,
        cmpname  TYPE string,
        exposure TYPE string,
        mtdtype  TYPE string,
      END OF ty_s_method.
    TYPES ty_t_method TYPE STANDARD TABLE OF ty_s_method WITH EMPTY KEY.

    " --- Attributes / Fields metadata ---
    TYPES:
      BEGIN OF ty_s_field,
        name     TYPE string,
        exposure TYPE string,
        typtype  TYPE string,
        type     TYPE string,
        keyflag  TYPE string,
      END OF ty_s_field.
    TYPES ty_t_field TYPE STANDARD TABLE OF ty_s_field WITH EMPTY KEY.

    " --- Where-Used results ---
    TYPES:
      BEGIN OF ty_s_usage,
        object   TYPE string,
        obj_name TYPE string,
      END OF ty_s_usage.
    TYPES ty_t_usage TYPE STANDARD TABLE OF ty_s_usage WITH EMPTY KEY.

    " --- Object Properties ---
    TYPES:
      BEGIN OF ty_s_prop,
        label TYPE string,
        value TYPE string,
      END OF ty_s_prop.
    TYPES ty_t_prop TYPE STANDARD TABLE OF ty_s_prop WITH EMPTY KEY.

    " --- State ---
    DATA mt_tree          TYPE ty_t_tree.
    DATA mv_cur_package   TYPE devclass VALUE '$ZLK'.
    DATA mv_cur_obj_name  TYPE sobj_name.
    DATA mv_cur_obj_type  TYPE trobjtype.
    DATA mv_source        TYPE string.
    DATA mv_source_local  TYPE string.
    DATA mv_source_test   TYPE string.
    DATA mv_search        TYPE string.
    DATA mv_search_type   TYPE string.
    DATA mv_object_title  TYPE string.
    DATA mv_active_tab    TYPE string VALUE 'SRC'.
    DATA mt_methods       TYPE ty_t_method.
    DATA mt_fields        TYPE ty_t_field.
    DATA mt_usages        TYPE ty_t_usage.
    DATA mt_props         TYPE ty_t_prop.
    DATA mv_show_whereu   TYPE abap_bool.
    DATA mv_edit_mode     TYPE abap_bool.
    DATA mv_message       TYPE string.
    DATA mv_msg_type      TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS on_event.
    METHODS build_tree.
    METHODS load_source.
    METHODS load_metadata.
    METHODS load_where_used.
    METHODS load_properties.
    METHODS load_table_fields.
    METHODS save_source.
    METHODS activate_object.
    METHODS get_object_icon
      IMPORTING iv_type       TYPE trobjtype
      RETURNING VALUE(result) TYPE string.
    METHODS get_obj_description
      IMPORTING iv_type       TYPE trobjtype
                iv_name       TYPE sobj_name
      RETURNING VALUE(result) TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_se80_a2ui5 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.
    me->client = client.
    IF client->check_on_init( ).
      build_tree( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.
  ENDMETHOD.


  METHOD on_event.
    DATA(lv_event) = client->get( )-event.
    DATA(lt_arg) = client->get( )-t_event_arg.

    CASE lv_event.

      WHEN 'TREE_CLICK'.
        IF lines( lt_arg ) >= 2.
          DATA(lv_key) = lt_arg[ 1 ].
          DATA(lv_otype) = lt_arg[ 2 ].
          IF lv_otype = 'DEVC'.
            mv_cur_package = CONV devclass( lv_key ).
            build_tree( ).
            CLEAR: mv_source, mv_source_local, mv_source_test,
                   mv_cur_obj_name, mv_object_title, mt_methods, mt_fields, mt_props.
          ELSE.
            mv_cur_obj_name = CONV sobj_name( lv_key ).
            mv_cur_obj_type = CONV trobjtype( lv_otype ).
            mv_object_title = |{ mv_cur_obj_type } - { mv_cur_obj_name }|.
            load_source( ).
            load_metadata( ).
            load_properties( ).
            mv_active_tab = 'SRC'.
          ENDIF.
        ENDIF.
        view_display( ).

      WHEN 'NAV_UP'.
        SELECT SINGLE parentcl FROM tdevc
          WHERE devclass = @mv_cur_package INTO @DATA(lv_parent).
        IF sy-subrc = 0 AND lv_parent IS NOT INITIAL.
          mv_cur_package = lv_parent.
          build_tree( ).
          CLEAR: mv_source, mv_source_local, mv_source_test,
                 mv_cur_obj_name, mv_object_title, mt_methods, mt_fields, mt_props.
        ENDIF.
        view_display( ).

      WHEN 'SEARCH'.
        IF mv_search IS NOT INITIAL.
          DATA(lv_pat) = |%{ to_upper( mv_search ) }%|.
          DATA lv_type_filter TYPE trobjtype.
          IF mv_search_type IS NOT INITIAL AND mv_search_type <> 'ALL'.
            lv_type_filter = CONV trobjtype( mv_search_type ).
          ENDIF.
          IF lv_type_filter IS NOT INITIAL.
            SELECT object, obj_name FROM tadir
              WHERE obj_name LIKE @lv_pat AND pgmid = 'R3TR'
              AND object = @lv_type_filter
              ORDER BY object, obj_name
              INTO TABLE @DATA(lt_found) UP TO 50 ROWS.
          ELSE.
            SELECT object, obj_name FROM tadir
              WHERE obj_name LIKE @lv_pat AND pgmid = 'R3TR'
              ORDER BY object, obj_name
              INTO TABLE @lt_found UP TO 50 ROWS.
          ENDIF.
          CLEAR mt_tree.
          LOOP AT lt_found ASSIGNING FIELD-SYMBOL(<f>).
            APPEND VALUE #(
              text  = |{ <f>-obj_name } [{ <f>-object }]|
              icon  = get_object_icon( <f>-object )
              key   = CONV string( <f>-obj_name )
              otype = CONV string( <f>-object )
            ) TO mt_tree.
          ENDLOOP.
          mv_object_title = |Search: { lines( mt_tree ) } hits|.
          CLEAR: mv_source, mv_source_local, mv_source_test.
        ENDIF.
        view_display( ).

      WHEN 'WHERE_USED'.
        load_where_used( ).
        mv_show_whereu = abap_true.
        view_display( ).

      WHEN 'CLOSE_WHEREU'.
        mv_show_whereu = abap_false.
        view_display( ).

      WHEN 'USAGE_CLICK'.
        IF lines( lt_arg ) >= 2.
          mv_cur_obj_name = CONV sobj_name( lt_arg[ 1 ] ).
          mv_cur_obj_type = CONV trobjtype( lt_arg[ 2 ] ).
          mv_object_title = |{ mv_cur_obj_type } - { mv_cur_obj_name }|.
          mv_show_whereu = abap_false.
          load_source( ).
          load_metadata( ).
          load_properties( ).
        ENDIF.
        view_display( ).

      WHEN 'TOGGLE_EDIT'.
        mv_edit_mode = xsdbool( mv_edit_mode = abap_false ).
        CLEAR: mv_message, mv_msg_type.
        view_display( ).

      WHEN 'SAVE'.
        save_source( ).
        view_display( ).

      WHEN 'ACTIVATE'.
        activate_object( ).
        view_display( ).

      WHEN 'REFRESH'.
        build_tree( ).
        view_display( ).

      WHEN OTHERS.
        view_display( ).
    ENDCASE.
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
        )->open( `Page` )->a( n = `title` v = `SE80 Lite`
            )->a( n = `showHeader` v = `true` ).

    " === MAIN LAYOUT ===
    DATA(flex) = page->open( `HBox`
        )->a( n = `height` v = `100%`
        )->a( n = `width`  v = `100%`
        )->a( n = `alignItems` v = `Stretch` ).

    " ============================
    " LEFT PANE
    " ============================
    DATA(lo_left) = flex->open( `VBox`
        )->a( n = `width` v = `340px` ).

    " Toolbar
    lo_left->open( `Toolbar`
        )->leaf( `Button`
            )->a( n = `icon`  v = `sap-icon://nav-back`
            )->a( n = `press` v = client->_event( `NAV_UP` )
            )->a( n = `type`  v = `Transparent`
        )->leaf( `Title`
            )->a( n = `text`  v = CONV string( mv_cur_package )
            )->a( n = `level` v = `H5`
    )->shut( ).

    " Search with type filter
    lo_left->open( `HBox` )->a( n = `width` v = `100%` ).
    lo_left->leaf( `SearchField`
        )->a( n = `placeholder` v = `Search...`
        )->a( n = `value`  v = client->_bind( mv_search )
        )->a( n = `search` v = client->_event( `SEARCH` )
        )->a( n = `width`  v = `240px` ).
    DATA(lo_sel) = lo_left->open( `Select`
        )->a( n = `selectedKey` v = client->_bind( mv_search_type )
        )->a( n = `width` v = `95px` ).
    lo_sel->open( `items` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `ALL` )->a( n = `text` v = `All` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `CLAS` )->a( n = `text` v = `Class` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `INTF` )->a( n = `text` v = `Intf` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `PROG` )->a( n = `text` v = `Prog` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `FUGR` )->a( n = `text` v = `FuGr` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `TABL` )->a( n = `text` v = `Table` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `DDLS` )->a( n = `text` v = `CDS` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `DTEL` )->a( n = `text` v = `DtEl` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `DOMA` )->a( n = `text` v = `Doma` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `WAPA` )->a( n = `text` v = `BSP` ).
    lo_sel->leaf( n = `Item` ns = `core` )->a( n = `key` v = `MSAG` )->a( n = `text` v = `MsgCl` ).
    lo_sel->shut( )->shut( ).
    lo_left->shut( ).

    " Tree
    DATA(lv_path) = client->_bind( val = mt_tree path = `X` ).
    DATA lv_items TYPE string.
    CONCATENATE `{path:'` lv_path `', parameters:{arrayNames:['NODES']}}` INTO lv_items.

    lo_left->open( `Tree`
        )->a( n = `items` v = lv_items
        )->open( `StandardTreeItem`
            )->a( n = `title` v = `{TEXT}`
            )->a( n = `icon`  v = `{ICON}`
            )->a( n = `type`  v = `Active`
            )->a( n = `press` v = client->_event( val = `TREE_CLICK` t_arg = VALUE #( ( `${KEY}` ) ( `${OTYPE}` ) ) )
        )->shut(
    )->shut( ).

    lo_left->shut( ).

    " ============================
    " RIGHT PANE
    " ============================
    DATA(lo_right) = flex->open( `VBox`
        )->a( n = `height` v = `100%`
        )->a( n = `width`  v = `100%` ).

    " Header toolbar
    lo_right->open( `Toolbar`
        )->leaf( `Title`
            )->a( n = `text` v = COND #( WHEN mv_object_title IS NOT INITIAL
                                          THEN mv_object_title ELSE `Select an object` )
        )->leaf( `ToolbarSpacer`
        )->leaf( `Button`
            )->a( n = `text`    v = COND #( WHEN mv_edit_mode = abap_true THEN `Display` ELSE `Edit` )
            )->a( n = `icon`    v = COND #( WHEN mv_edit_mode = abap_true
                                             THEN `sap-icon://display` ELSE `sap-icon://edit` )
            )->a( n = `press`   v = client->_event( `TOGGLE_EDIT` )
            )->a( n = `type`    v = COND #( WHEN mv_edit_mode = abap_true
                                             THEN `Emphasized` ELSE `Transparent` )
            )->a( n = `enabled` v = COND #( WHEN mv_cur_obj_name IS NOT INITIAL
                                             THEN `true` ELSE `false` )
        )->leaf( `Button`
            )->a( n = `text`    v = `Save`
            )->a( n = `icon`    v = `sap-icon://save`
            )->a( n = `press`   v = client->_event( `SAVE` )
            )->a( n = `type`    v = `Transparent`
            )->a( n = `enabled` v = COND #( WHEN mv_edit_mode = abap_true
                                             THEN `true` ELSE `false` )
        )->leaf( `Button`
            )->a( n = `text`    v = `Activate`
            )->a( n = `icon`    v = `sap-icon://activate`
            )->a( n = `press`   v = client->_event( `ACTIVATE` )
            )->a( n = `type`    v = `Transparent`
            )->a( n = `enabled` v = COND #( WHEN mv_cur_obj_name IS NOT INITIAL
                                             THEN `true` ELSE `false` )
        )->leaf( `ToolbarSeparator`
        )->leaf( `Button`
            )->a( n = `icon`    v = `sap-icon://search`
            )->a( n = `press`   v = client->_event( `WHERE_USED` )
            )->a( n = `tooltip` v = `Where-Used`
            )->a( n = `type`    v = `Transparent`
            )->a( n = `enabled` v = COND #( WHEN mv_cur_obj_name IS NOT INITIAL
                                             THEN `true` ELSE `false` )
        )->leaf( `Button`
            )->a( n = `icon`  v = `sap-icon://refresh`
            )->a( n = `press` v = client->_event( `REFRESH` )
            )->a( n = `type`  v = `Transparent`
    )->shut( ).

    " Message strip for save/activate feedback
    IF mv_message IS NOT INITIAL.
      lo_right->leaf( `MessageStrip`
          )->a( n = `text` v = mv_message
          )->a( n = `type` v = mv_msg_type
          )->a( n = `showCloseButton` v = `true` ).
    ENDIF.

    " === IconTabBar ===
    DATA(lo_tabs) = lo_right->open( `IconTabBar`
        )->a( n = `selectedKey` v = client->_bind( mv_active_tab )
        )->a( n = `expandable` v = `false`
        )->a( n = `stretchContentHeight` v = `true`
        )->open( `items` ).

    " Determine syntax mode based on object type
    DATA(lv_syntax) = SWITCH string( mv_cur_obj_type
      WHEN 'DDLS' THEN `sql`
      WHEN 'WAPA' THEN `html`
      ELSE `abap` ).

    " -- Tab: Source --
    DATA(lo_t1) = lo_tabs->open( `IconTabFilter`
        )->a( n = `text` v = `Source` )->a( n = `key` v = `SRC`
        )->a( n = `icon` v = `sap-icon://syntax` ).
    DATA(lv_editable) = COND #( WHEN mv_edit_mode = abap_true THEN `true` ELSE `false` ).
    lo_t1->open( `content`
        )->leaf( n = `CodeEditor` ns = `ce`
            )->a( n = `value`    v = client->_bind( mv_source )
            )->a( n = `type`     v = lv_syntax
            )->a( n = `height`   v = `calc(100vh - 140px)`
            )->a( n = `width`    v = `100%`
            )->a( n = `editable` v = lv_editable
    )->shut( ).
    lo_t1->shut( ).

    " -- Tab: Local Types --
    DATA(lo_t2) = lo_tabs->open( `IconTabFilter`
        )->a( n = `text` v = `Local Types` )->a( n = `key` v = `LOC`
        )->a( n = `icon` v = `sap-icon://detail-view` ).
    lo_t2->open( `content`
        )->leaf( n = `CodeEditor` ns = `ce`
            )->a( n = `value`    v = client->_bind( mv_source_local )
            )->a( n = `type`     v = `abap`
            )->a( n = `height`   v = `calc(100vh - 140px)`
            )->a( n = `width`    v = `100%`
            )->a( n = `editable` v = `false`
    )->shut( ).
    lo_t2->shut( ).

    " -- Tab: Test Classes --
    DATA(lo_t3) = lo_tabs->open( `IconTabFilter`
        )->a( n = `text` v = `Tests` )->a( n = `key` v = `TST`
        )->a( n = `icon` v = `sap-icon://lab` ).
    lo_t3->open( `content`
        )->leaf( n = `CodeEditor` ns = `ce`
            )->a( n = `value`    v = client->_bind( mv_source_test )
            )->a( n = `type`     v = `abap`
            )->a( n = `height`   v = `calc(100vh - 140px)`
            )->a( n = `width`    v = `100%`
            )->a( n = `editable` v = `false`
    )->shut( ).
    lo_t3->shut( ).

    " -- Tab: Info (Properties + Methods/Fields) --
    DATA(lo_t4) = lo_tabs->open( `IconTabFilter`
        )->a( n = `text` v = `Info` )->a( n = `key` v = `INFO`
        )->a( n = `icon` v = `sap-icon://hint` ).
    DATA(lo_info) = lo_t4->open( `content` ).

    " Properties section
    IF mt_props IS NOT INITIAL.
      DATA(lo_plist) = lo_info->open( `List`
          )->a( n = `headerText` v = `Properties`
          )->a( n = `items` v = client->_bind( mt_props ) ).
      lo_plist->open( `items`
          )->open( `DisplayListItem`
              )->a( n = `label` v = `{LABEL}`
              )->a( n = `value` v = `{VALUE}`
          )->shut(
      )->shut( ).
      lo_plist->shut( ).
    ENDIF.

    " Methods section
    IF mt_methods IS NOT INITIAL.
      DATA(lo_mtab) = lo_info->open( `Table`
          )->a( n = `headerText` v = |Methods ({ lines( mt_methods ) })|
          )->a( n = `items` v = client->_bind( mt_methods ) ).
      DATA(lo_mc) = lo_mtab->open( `columns` ).
      lo_mc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Name` )->shut( ).
      lo_mc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Visibility` )->shut( ).
      lo_mc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Type` )->shut( ).
      lo_mc->shut( ).
      lo_mtab->open( `items`
          )->open( `ColumnListItem`
              )->open( `cells`
                  )->leaf( `Text` )->a( n = `text` v = `{CMPNAME}`
                  )->leaf( `Text` )->a( n = `text` v = `{EXPOSURE}`
                  )->leaf( `Text` )->a( n = `text` v = `{MTDTYPE}`
              )->shut(
          )->shut(
      )->shut( ).
      lo_mtab->shut( ).
    ENDIF.

    " Fields/Attributes section
    IF mt_fields IS NOT INITIAL.
      DATA(lo_ftab) = lo_info->open( `Table`
          )->a( n = `headerText` v = |Fields ({ lines( mt_fields ) })|
          )->a( n = `items` v = client->_bind( mt_fields ) ).
      DATA(lo_fc) = lo_ftab->open( `columns` ).
      lo_fc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Name` )->shut( ).
      lo_fc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Key` )->shut( ).
      lo_fc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Type` )->shut( ).
      lo_fc->open( `Column` )->leaf( `Text` )->a( n = `text` v = `Data Type` )->shut( ).
      lo_fc->shut( ).
      lo_ftab->open( `items`
          )->open( `ColumnListItem`
              )->open( `cells`
                  )->leaf( `Text` )->a( n = `text` v = `{NAME}`
                  )->leaf( `Text` )->a( n = `text` v = `{KEYFLAG}`
                  )->leaf( `Text` )->a( n = `text` v = `{TYPTYPE}`
                  )->leaf( `Text` )->a( n = `text` v = `{TYPE}`
              )->shut(
          )->shut(
      )->shut( ).
      lo_ftab->shut( ).
    ENDIF.

    lo_info->shut( ).
    lo_t4->shut( ).

    " Close items + IconTabBar
    lo_tabs->shut( )->shut( ).

    " Close right, HBox, Page, App, View
    lo_right->shut( )->shut( )->shut( )->shut( )->shut( ).

    " === WHERE-USED DIALOG ===
    IF mv_show_whereu = abap_true.
      DATA(lo_dlg) = view->open( `Dialog`
          )->a( n = `title`         v = |Where-Used: { mv_cur_obj_name }|
          )->a( n = `contentWidth`  v = `500px`
          )->a( n = `contentHeight` v = `400px` ).
      IF mt_usages IS NOT INITIAL.
        lo_dlg->open( `List`
            )->a( n = `items` v = client->_bind( mt_usages )
            )->open( `items`
                )->open( `StandardListItem`
                    )->a( n = `title` v = `{OBJ_NAME}`
                    )->a( n = `description` v = `{OBJECT}`
                    )->a( n = `type` v = `Active`
                    )->a( n = `press` v = client->_event( val = `USAGE_CLICK`
                        t_arg = VALUE #( ( `${OBJ_NAME}` ) ( `${OBJECT}` ) ) )
                )->shut(
            )->shut(
        )->shut( ).
      ELSE.
        lo_dlg->leaf( `MessageStrip`
            )->a( n = `text` v = `No usages found.`
            )->a( n = `type` v = `Information` ).
      ENDIF.
      lo_dlg->open( `beginButton`
          )->leaf( `Button`
              )->a( n = `text`  v = `Close`
              )->a( n = `press` v = client->_event( `CLOSE_WHEREU` )
      )->shut( ).
      lo_dlg->shut( ).
      client->popup_display( view->stringify( ) ).
    ELSE.
      client->view_display( view->stringify( ) ).
    ENDIF.
  ENDMETHOD.


  METHOD build_tree.
    CLEAR mt_tree.

    " Sub-packages
    SELECT d~devclass, t~ctext
      FROM tdevc AS d
      LEFT JOIN tdevct AS t ON t~devclass = d~devclass AND t~spras = 'E'
      WHERE d~parentcl = @mv_cur_package
      ORDER BY d~devclass
      INTO TABLE @DATA(lt_pkgs) UP TO 50 ROWS.

    " All objects in sub-packages (one query)
    DATA lt_pkg_range TYPE RANGE OF devclass.
    LOOP AT lt_pkgs ASSIGNING FIELD-SYMBOL(<pkg>).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = <pkg>-devclass ) TO lt_pkg_range.
    ENDLOOP.

    DATA lt_all_objs TYPE STANDARD TABLE OF tadir WITH EMPTY KEY.
    IF lt_pkg_range IS NOT INITIAL.
      SELECT object, obj_name, devclass FROM tadir
        WHERE devclass IN @lt_pkg_range AND pgmid = 'R3TR'
        ORDER BY devclass, object, obj_name
        INTO TABLE @lt_all_objs UP TO 500 ROWS.
    ENDIF.

    " Build package nodes with children
    LOOP AT lt_pkgs ASSIGNING <pkg>.
      DATA(ls_node) = VALUE ty_s_tree_node(
        text  = COND #( WHEN <pkg>-ctext IS NOT INITIAL
                        THEN |{ <pkg>-devclass } ({ <pkg>-ctext })|
                        ELSE CONV string( <pkg>-devclass ) )
        icon  = `sap-icon://folder-blank`
        key   = CONV string( <pkg>-devclass )
        otype = `DEVC` ).

      LOOP AT lt_all_objs ASSIGNING FIELD-SYMBOL(<obj>) WHERE devclass = <pkg>-devclass.
        APPEND VALUE #(
          text  = CONV string( <obj>-obj_name )
          icon  = get_object_icon( <obj>-object )
          key   = CONV string( <obj>-obj_name )
          otype = CONV string( <obj>-object )
        ) TO ls_node-nodes.
      ENDLOOP.
      APPEND ls_node TO mt_tree.
      CLEAR ls_node.
    ENDLOOP.

    " Objects directly in current package - GROUPED BY TYPE
    SELECT object, obj_name FROM tadir
      WHERE devclass = @mv_cur_package AND pgmid = 'R3TR'
      ORDER BY object, obj_name
      INTO TABLE @DATA(lt_cur) UP TO 200 ROWS.

    " Get distinct types
    DATA lt_types TYPE SORTED TABLE OF trobjtype WITH UNIQUE KEY table_line.
    LOOP AT lt_cur ASSIGNING FIELD-SYMBOL(<co>).
      INSERT <co>-object INTO TABLE lt_types.
    ENDLOOP.

    " Create a group node per type if more than 5 objects total
    IF lines( lt_cur ) > 5 AND lines( lt_types ) > 1.
      LOOP AT lt_types ASSIGNING FIELD-SYMBOL(<type>).
        DATA(ls_grp) = VALUE ty_s_tree_node(
          text  = CONV string( <type> )
          icon  = get_object_icon( <type> )
          key   = CONV string( mv_cur_package )
          otype = `DEVC` ).
        LOOP AT lt_cur ASSIGNING <co> WHERE object = <type>.
          APPEND VALUE #(
            text  = CONV string( <co>-obj_name )
            icon  = get_object_icon( <co>-object )
            key   = CONV string( <co>-obj_name )
            otype = CONV string( <co>-object )
          ) TO ls_grp-nodes.
        ENDLOOP.
        ls_grp-text = |{ <type> } ({ lines( ls_grp-nodes ) })|.
        APPEND ls_grp TO mt_tree.
        CLEAR ls_grp.
      ENDLOOP.
    ELSE.
      " Few objects - show flat
      LOOP AT lt_cur ASSIGNING <co>.
        APPEND VALUE #(
          text  = CONV string( <co>-obj_name )
          icon  = get_object_icon( <co>-object )
          key   = CONV string( <co>-obj_name )
          otype = CONV string( <co>-object )
        ) TO mt_tree.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD load_source.
    DATA lt_source TYPE STANDARD TABLE OF string.
    DATA lt_local TYPE STANDARD TABLE OF string.
    DATA lt_test TYPE STANDARD TABLE OF string.
    CLEAR: mv_source, mv_source_local, mv_source_test.

    CASE mv_cur_obj_type.
      WHEN 'PROG'.
        READ REPORT mv_cur_obj_name INTO lt_source.

      WHEN 'CLAS' OR 'INTF'.
        TRY.
            DATA(lo_settings) = cl_oo_clif_source_settings=>create_instance( ).
            DATA(lo_src) = cl_oo_clif_source=>create_instance(
              clif_name = CONV #( mv_cur_obj_name )
              version   = 'A'
              settings  = lo_settings ).
            lo_src->if_oo_clif_source~get_source( IMPORTING source = lt_source ).
            IF lt_source IS INITIAL.
              APPEND |* No source found| TO lt_source.
            ENDIF.
            " Local types
            DATA(lv_cls) = CONV seoclsname( mv_cur_obj_name ).
            DATA(lv_ccdef) = cl_oo_classname_service=>get_ccdef_name( lv_cls ).
            DATA(lv_ccimp) = cl_oo_classname_service=>get_ccimp_name( lv_cls ).
            READ REPORT lv_ccdef INTO lt_local.
            DATA lt_imp TYPE STANDARD TABLE OF string.
            READ REPORT lv_ccimp INTO lt_imp.
            IF lt_imp IS NOT INITIAL.
              IF lt_local IS NOT INITIAL.
                APPEND `` TO lt_local.
              ENDIF.
              APPEND LINES OF lt_imp TO lt_local.
            ENDIF.
            IF lt_local IS INITIAL.
              APPEND `* No local types defined.` TO lt_local.
            ENDIF.
            " Test classes
            DATA(lv_tst) = cl_oo_classname_service=>get_local_testclasses_include( lv_cls ).
            READ REPORT lv_tst INTO lt_test.
            IF lt_test IS INITIAL.
              APPEND `* No test classes defined.` TO lt_test.
            ENDIF.
          CATCH cx_root INTO DATA(lx).
            APPEND |* Error: { lx->get_text( ) }| TO lt_source.
        ENDTRY.

      WHEN 'FUGR'.
        " Show the function group main include + list FMs in source
        DATA(lv_fugr) = CONV syrepid( |SAPL{ mv_cur_obj_name }| ).
        READ REPORT lv_fugr INTO lt_source.
        IF sy-subrc <> 0.
          APPEND |* Could not read { mv_cur_obj_name }| TO lt_source.
        ENDIF.

      WHEN 'FUNC'.
        " Individual Function Module source
        SELECT SINGLE include FROM tfdir
          WHERE funcname = @mv_cur_obj_name
          INTO @DATA(lv_fm_incl).
        IF sy-subrc = 0 AND lv_fm_incl IS NOT INITIAL.
          READ REPORT lv_fm_incl INTO lt_source.
        ENDIF.
        IF lt_source IS INITIAL.
          APPEND |* Could not read FM { mv_cur_obj_name }| TO lt_source.
        ENDIF.

      WHEN 'WAPA'.
        " BSP Application - list pages and show first page content
        TRY.
            SELECT applname, pagekey, pagename FROM o2pagdir
              WHERE applname = @mv_cur_obj_name
              ORDER BY pagename
              INTO TABLE @DATA(lt_bsp_pages).
            IF lt_bsp_pages IS NOT INITIAL.
              " Try to load first page content
              DATA lo_page TYPE REF TO cl_o2_api_pages.
              DATA(ls_key) = VALUE o2pagkey(
                applname = lt_bsp_pages[ 1 ]-applname
                pagekey  = lt_bsp_pages[ 1 ]-pagekey ).
              cl_o2_api_pages=>load(
                EXPORTING p_pagekey = ls_key
                          p_version = 'A'
                IMPORTING p_page = lo_page
                EXCEPTIONS OTHERS = 1 ).
              IF sy-subrc = 0 AND lo_page IS BOUND.
                DATA lt_bsp_content TYPE o2pageline_table.
                lo_page->get_page(
                  IMPORTING p_content = lt_bsp_content
                  EXCEPTIONS OTHERS = 0 ).
                LOOP AT lt_bsp_content ASSIGNING FIELD-SYMBOL(<bsp_line>).
                  APPEND CONV string( <bsp_line>-line ) TO lt_source.
                ENDLOOP.
              ENDIF.
              IF lt_source IS INITIAL.
                APPEND |* BSP App: { mv_cur_obj_name }| TO lt_source.
                APPEND |* Pages:| TO lt_source.
                LOOP AT lt_bsp_pages ASSIGNING FIELD-SYMBOL(<bp>).
                  APPEND |*   { <bp>-pagename }| TO lt_source.
                ENDLOOP.
              ENDIF.
            ELSE.
              APPEND |* No pages found for BSP App { mv_cur_obj_name }| TO lt_source.
            ENDIF.
          CATCH cx_root INTO DATA(lx_bsp).
            APPEND |* Error reading BSP: { lx_bsp->get_text( ) }| TO lt_source.
        ENDTRY.

      WHEN 'DDLS'.
        SELECT SINGLE source FROM ddddlsrc
          WHERE ddlname = @mv_cur_obj_name AND as4local = 'A'
          INTO @DATA(lv_ddl).
        IF sy-subrc = 0.
          SPLIT lv_ddl AT cl_abap_char_utilities=>newline INTO TABLE lt_source.
        ELSE.
          APPEND |* CDS not found: { mv_cur_obj_name }| TO lt_source.
        ENDIF.

      WHEN 'ENHO'.
        " Enhancement implementation - try to read its include
        DATA(lv_enho_incl) = CONV syrepid( mv_cur_obj_name ).
        READ REPORT lv_enho_incl INTO lt_source.
        IF sy-subrc <> 0.
          APPEND |* Enhancement Impl: { mv_cur_obj_name }| TO lt_source.
          APPEND |* (Source may be embedded in target object)| TO lt_source.
        ENDIF.

      WHEN 'TTYP'.
        " Table Type - show definition info
        SELECT SINGLE rowtype, accessmode, keydef, keykind FROM dd40l
          WHERE typename = @mv_cur_obj_name AND as4local = 'A'
          INTO @DATA(ls_ttyp).
        IF sy-subrc = 0.
          APPEND |* Table Type: { mv_cur_obj_name }| TO lt_source.
          APPEND |* Row Type: { ls_ttyp-rowtype }| TO lt_source.
          APPEND |* Access: { ls_ttyp-accessmode }| TO lt_source.
          APPEND |* Key Def: { ls_ttyp-keydef }| TO lt_source.
        ELSE.
          APPEND |* Table Type not found| TO lt_source.
        ENDIF.

      WHEN OTHERS.
        DATA(lv_rep) = CONV syrepid( mv_cur_obj_name ).
        READ REPORT lv_rep INTO lt_source.
        IF sy-subrc <> 0.
          APPEND |* No source for type { mv_cur_obj_type }| TO lt_source.
        ENDIF.
    ENDCASE.

    mv_source = concat_lines_of( table = lt_source sep = cl_abap_char_utilities=>newline ).
    mv_source_local = concat_lines_of( table = lt_local sep = cl_abap_char_utilities=>newline ).
    mv_source_test = concat_lines_of( table = lt_test sep = cl_abap_char_utilities=>newline ).
  ENDMETHOD.


  METHOD load_metadata.
    CLEAR: mt_methods, mt_fields.

    CASE mv_cur_obj_type.
      WHEN 'CLAS' OR 'INTF'.
        " Methods
        SELECT cmpname, exposure, mtddecltyp FROM seocompodf
          WHERE clsname = @mv_cur_obj_name AND version = 1
          AND mtddecltyp > 0
          ORDER BY exposure DESCENDING, cmpname
          INTO TABLE @DATA(lt_m).
        LOOP AT lt_m ASSIGNING FIELD-SYMBOL(<m>).
          APPEND VALUE #(
            cmpname  = CONV string( <m>-cmpname )
            exposure = SWITCH #( <m>-exposure WHEN 0 THEN `Priv` WHEN 1 THEN `Prot` WHEN 2 THEN `Pub` ELSE `?` )
            mtdtype  = SWITCH #( <m>-mtddecltyp WHEN 0 THEN `Inst` WHEN 1 THEN `Static` ELSE `` )
          ) TO mt_methods.
        ENDLOOP.
        " Attributes
        SELECT cmpname, exposure, typtype, type FROM seocompodf
          WHERE clsname = @mv_cur_obj_name AND version = 1
          AND attdecltyp > 0
          ORDER BY exposure DESCENDING, cmpname
          INTO TABLE @DATA(lt_a).
        LOOP AT lt_a ASSIGNING FIELD-SYMBOL(<a>).
          APPEND VALUE #(
            name     = CONV string( <a>-cmpname )
            exposure = SWITCH #( <a>-exposure WHEN 0 THEN `Priv` WHEN 1 THEN `Prot` WHEN 2 THEN `Pub` ELSE `?` )
            typtype  = SWITCH #( <a>-typtype WHEN 1 THEN `TYPE` WHEN 3 THEN `REF TO` ELSE `` )
            type     = CONV string( <a>-type )
          ) TO mt_fields.
        ENDLOOP.

      WHEN 'TABL'.
        load_table_fields( ).

      WHEN 'WAPA'.
        " BSP pages list
        SELECT pagename, implclass FROM o2pagdir
          WHERE applname = @mv_cur_obj_name
          ORDER BY pagename
          INTO TABLE @DATA(lt_bpg).
        LOOP AT lt_bpg ASSIGNING FIELD-SYMBOL(<bpg>).
          APPEND VALUE #(
            name    = CONV string( <bpg>-pagename )
            keyflag = ``
            typtype = COND #( WHEN <bpg>-implclass IS NOT INITIAL
                              THEN CONV string( <bpg>-implclass ) ELSE `` )
            type    = `BSP Page`
          ) TO mt_fields.
        ENDLOOP.

      WHEN 'FUNC'.
        " Function Module Parameters
        SELECT parameter, paramtype, structure, optional FROM fupararef
          WHERE funcname = @mv_cur_obj_name AND r3state = 'A'
          ORDER BY paramtype, pposition
          INTO TABLE @DATA(lt_par).
        LOOP AT lt_par ASSIGNING FIELD-SYMBOL(<par>).
          APPEND VALUE #(
            name    = CONV string( <par>-parameter )
            keyflag = SWITCH #( <par>-paramtype
                        WHEN 'I' THEN `IMP` WHEN 'E' THEN `EXP`
                        WHEN 'C' THEN `CHG` WHEN 'T' THEN `TBL` ELSE <par>-paramtype )
            typtype = COND #( WHEN <par>-optional = 'X' THEN `Optional` ELSE `` )
            type    = CONV string( <par>-structure )
          ) TO mt_fields.
        ENDLOOP.

      WHEN 'MSAG'.
        " Message class - show messages
        SELECT msgnr, text FROM t100
          WHERE sprsl = 'E' AND arbgb = @mv_cur_obj_name
          ORDER BY msgnr
          INTO TABLE @DATA(lt_msg).
        LOOP AT lt_msg ASSIGNING FIELD-SYMBOL(<msg>).
          APPEND VALUE #(
            name    = CONV string( <msg>-msgnr )
            keyflag = ``
            typtype = ``
            type    = CONV string( <msg>-text )
          ) TO mt_fields.
        ENDLOOP.

      WHEN 'FUGR'.
        " Function Group: list Function Modules
        SELECT funcname FROM enlfdir
          WHERE area = @mv_cur_obj_name
          ORDER BY funcname
          INTO TABLE @DATA(lt_fms).
        LOOP AT lt_fms ASSIGNING FIELD-SYMBOL(<fm>).
          APPEND VALUE #(
            name    = CONV string( <fm>-funcname )
            keyflag = ``
            typtype = `FUNC`
            type    = `Function Module`
          ) TO mt_fields.
        ENDLOOP.

      WHEN 'DTEL'.
        " Data Element details
        SELECT SINGLE domname, routputlen, memoryid FROM dd04l
          WHERE rollname = @mv_cur_obj_name AND as4local = 'A'
          INTO @DATA(ls_dtel).
        IF sy-subrc = 0.
          APPEND VALUE #( name = `Domain`       type = CONV string( ls_dtel-domname ) ) TO mt_fields.
          APPEND VALUE #( name = `Output Len`   type = CONV string( ls_dtel-routputlen ) ) TO mt_fields.
          APPEND VALUE #( name = `Parameter ID` type = CONV string( ls_dtel-memoryid ) ) TO mt_fields.
        ENDIF.
        " Labels
        SELECT SINGLE ddtext, reptext, scrtext_s, scrtext_m, scrtext_l FROM dd04t
          WHERE rollname = @mv_cur_obj_name AND ddlanguage = 'E' AND as4local = 'A'
          INTO @DATA(ls_dtelt).
        IF sy-subrc = 0.
          APPEND VALUE #( name = `Description`  type = CONV string( ls_dtelt-ddtext ) ) TO mt_fields.
          APPEND VALUE #( name = `Heading`      type = CONV string( ls_dtelt-reptext ) ) TO mt_fields.
          APPEND VALUE #( name = `Short`        type = CONV string( ls_dtelt-scrtext_s ) ) TO mt_fields.
          APPEND VALUE #( name = `Medium`       type = CONV string( ls_dtelt-scrtext_m ) ) TO mt_fields.
          APPEND VALUE #( name = `Long`         type = CONV string( ls_dtelt-scrtext_l ) ) TO mt_fields.
        ENDIF.

      WHEN 'DOMA'.
        " Domain - show fixed values
        SELECT SINGLE datatype, leng, decimals, outputlen FROM dd01l
          WHERE domname = @mv_cur_obj_name AND as4local = 'A'
          INTO @DATA(ls_dom).
        IF sy-subrc = 0.
          APPEND VALUE #( name = `Data Type`   type = CONV string( ls_dom-datatype ) ) TO mt_fields.
          APPEND VALUE #( name = `Length`      type = CONV string( ls_dom-leng ) ) TO mt_fields.
          APPEND VALUE #( name = `Decimals`    type = CONV string( ls_dom-decimals ) ) TO mt_fields.
          APPEND VALUE #( name = `Output Len`  type = CONV string( ls_dom-outputlen ) ) TO mt_fields.
        ENDIF.
        " Fixed values
        SELECT domvalue_l, ddtext FROM dd07t
          WHERE domname = @mv_cur_obj_name AND ddlanguage = 'E' AND as4local = 'A'
          ORDER BY valpos
          INTO TABLE @DATA(lt_fv).
        LOOP AT lt_fv ASSIGNING FIELD-SYMBOL(<fv>).
          APPEND VALUE #(
            name = CONV string( <fv>-domvalue_l )
            type = CONV string( <fv>-ddtext )
          ) TO mt_fields.
        ENDLOOP.

      WHEN 'ENHO'.
        " Enhancement Implementation - basic info
        APPEND VALUE #( name = `Type` type = `Enhancement Implementation` ) TO mt_fields.
        APPEND VALUE #( name = `Name` type = CONV string( mv_cur_obj_name ) ) TO mt_fields.

      WHEN OTHERS.
        " No metadata for this type
    ENDCASE.
  ENDMETHOD.


  METHOD load_table_fields.
    CLEAR mt_fields.
    SELECT fieldname, keyflag, datatype, rollname, leng FROM dd03l
      WHERE tabname = @mv_cur_obj_name
      AND as4local = 'A'
      AND fieldname NOT LIKE '.%'
      ORDER BY position
      INTO TABLE @DATA(lt_fld).
    LOOP AT lt_fld ASSIGNING FIELD-SYMBOL(<fld>).
      APPEND VALUE #(
        name    = CONV string( <fld>-fieldname )
        keyflag = COND #( WHEN <fld>-keyflag = 'X' THEN `🔑` ELSE `` )
        typtype = CONV string( <fld>-datatype )
        type    = COND #( WHEN <fld>-rollname IS NOT INITIAL
                          THEN CONV string( <fld>-rollname )
                          ELSE |{ <fld>-datatype }({ <fld>-leng })| )
      ) TO mt_fields.
    ENDLOOP.
  ENDMETHOD.


  METHOD load_properties.
    CLEAR mt_props.
    SELECT SINGLE author, devclass, created_on, object FROM tadir
      WHERE pgmid = 'R3TR'
      AND object = @mv_cur_obj_type
      AND obj_name = @mv_cur_obj_name
      INTO @DATA(ls_tadir).
    IF sy-subrc = 0.
      APPEND VALUE #( label = `Package`  value = CONV string( ls_tadir-devclass ) ) TO mt_props.
      APPEND VALUE #( label = `Author`   value = CONV string( ls_tadir-author ) ) TO mt_props.
      APPEND VALUE #( label = `Created`  value = CONV string( ls_tadir-created_on ) ) TO mt_props.
      APPEND VALUE #( label = `Type`     value = CONV string( ls_tadir-object ) ) TO mt_props.
    ENDIF.

    " Description
    DATA(lv_desc) = get_obj_description( iv_type = mv_cur_obj_type iv_name = mv_cur_obj_name ).
    IF lv_desc IS NOT INITIAL.
      INSERT VALUE #( label = `Description` value = lv_desc ) INTO mt_props INDEX 1.
    ENDIF.

    " Transport info
    SELECT SINGLE trkorr FROM e071
      WHERE pgmid = 'R3TR'
      AND object = @mv_cur_obj_type
      AND obj_name = @mv_cur_obj_name
      INTO @DATA(lv_trkorr).
    IF sy-subrc = 0 AND lv_trkorr IS NOT INITIAL.
      APPEND VALUE #( label = `Transport` value = CONV string( lv_trkorr ) ) TO mt_props.
    ENDIF.

    " Class-specific: superclass + interfaces
    IF mv_cur_obj_type = 'CLAS'.
      SELECT SINGLE refclsname FROM seometarel
        WHERE clsname = @mv_cur_obj_name AND version = 1 AND state = 1
        INTO @DATA(lv_super).
      IF sy-subrc = 0 AND lv_super IS NOT INITIAL.
        APPEND VALUE #( label = `Superclass` value = CONV string( lv_super ) ) TO mt_props.
      ENDIF.
      " Interfaces
      SELECT refclsname FROM vseoimplem
        WHERE clsname = @mv_cur_obj_name AND version = 1
        INTO TABLE @DATA(lt_intf).
      IF lt_intf IS NOT INITIAL.
        DATA(lv_intfs) = ``.
        LOOP AT lt_intf ASSIGNING FIELD-SYMBOL(<intf>).
          IF lv_intfs IS NOT INITIAL.
            lv_intfs = lv_intfs && `, `.
          ENDIF.
          lv_intfs = lv_intfs && <intf>-refclsname.
        ENDLOOP.
        APPEND VALUE #( label = `Interfaces` value = lv_intfs ) TO mt_props.
      ENDIF.
    ENDIF.

    " Line count for source
    IF mv_source IS NOT INITIAL.
      DATA(lv_lines) = lines( VALUE string_table( ) ).
      FIND ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN mv_source MATCH COUNT lv_lines.
      lv_lines = lv_lines + 1.
      APPEND VALUE #( label = `Lines` value = CONV string( lv_lines ) ) TO mt_props.
    ENDIF.
  ENDMETHOD.


  METHOD load_where_used.
    CLEAR mt_usages.
    CHECK mv_cur_obj_name IS NOT INITIAL.
    DATA(lv_like) = |%{ mv_cur_obj_name }%|.
    SELECT otype, include FROM wbcrossgt
      WHERE name LIKE @lv_like
      ORDER BY otype, include
      INTO TABLE @DATA(lt_refs) UP TO 100 ROWS.
    LOOP AT lt_refs ASSIGNING FIELD-SYMBOL(<r>).
      APPEND VALUE #(
        object   = CONV string( <r>-otype )
        obj_name = CONV string( <r>-include )
      ) TO mt_usages.
    ENDLOOP.
    SORT mt_usages BY obj_name.
    DELETE ADJACENT DUPLICATES FROM mt_usages COMPARING obj_name.
  ENDMETHOD.


  METHOD get_obj_description.
    " Try to get description based on type
    CASE iv_type.
      WHEN 'CLAS' OR 'INTF'.
        SELECT SINGLE descript FROM seoclasstx
          WHERE clsname = @iv_name AND langu = 'E'
          INTO @result.
      WHEN 'PROG'.
        SELECT SINGLE text FROM trdirt
          WHERE name = @iv_name AND sprsl = 'E'
          INTO @result.
      WHEN 'TABL' OR 'VIEW'.
        SELECT SINGLE ddtext FROM dd02t
          WHERE tabname = @iv_name AND ddlanguage = 'E'
          INTO @result.
      WHEN 'DTEL'.
        SELECT SINGLE ddtext FROM dd04t
          WHERE rollname = @iv_name AND ddlanguage = 'E'
          INTO @result.
      WHEN 'DOMA'.
        SELECT SINGLE ddtext FROM dd01t
          WHERE domname = @iv_name AND ddlanguage = 'E'
          INTO @result.
      WHEN 'FUGR'.
        SELECT SINGLE areat FROM tlibt
          WHERE area = @iv_name AND spras = 'E'
          INTO @result.
      WHEN 'MSAG'.
        SELECT SINGLE stext FROM t100a
          WHERE arbgb = @iv_name
          INTO @result.
      WHEN 'WAPA'.
        SELECT SINGLE applname FROM o2appl
          WHERE applname = @iv_name
          INTO @result.
        IF sy-subrc = 0.
          result = |BSP Application: { iv_name }|.
        ENDIF.
      WHEN OTHERS.
        CLEAR result.
    ENDCASE.
  ENDMETHOD.


  METHOD save_source.
    DATA lt_source TYPE STANDARD TABLE OF string.
    CLEAR: mv_message, mv_msg_type.

    CHECK mv_cur_obj_name IS NOT INITIAL.
    CHECK mv_source IS NOT INITIAL.

    " Split source string back into internal table
    SPLIT mv_source AT cl_abap_char_utilities=>newline INTO TABLE lt_source.

    CASE mv_cur_obj_type.

      WHEN 'CLAS' OR 'INTF'.
        TRY.
            DATA(lo_settings) = cl_oo_clif_source_settings=>create_instance( ).
            DATA(lo_src) = cl_oo_clif_source=>create_instance(
              clif_name = CONV #( mv_cur_obj_name )
              version   = 'I'
              settings  = lo_settings ).
            lo_src->access_permission( access_mode = seok_access_modify ).
            lo_src->if_oo_clif_source~set_source( lt_source ).
            lo_src->if_oo_clif_source~save( ).
            mv_message = |Source saved successfully for { mv_cur_obj_name }.|.
            mv_msg_type = `Success`.
          CATCH cx_root INTO DATA(lx_cls).
            mv_message = |Save error: { lx_cls->get_text( ) }|.
            mv_msg_type = `Error`.
        ENDTRY.

      WHEN 'PROG' OR 'FUNC'.
        DATA lv_repname TYPE syrepid.
        IF mv_cur_obj_type = 'FUNC'.
          SELECT SINGLE include FROM tfdir
            WHERE funcname = @mv_cur_obj_name INTO @lv_repname.
        ELSE.
          lv_repname = mv_cur_obj_name.
        ENDIF.
        IF lv_repname IS NOT INITIAL.
          INSERT REPORT lv_repname FROM lt_source.
          IF sy-subrc = 0.
            mv_message = |Source saved for { mv_cur_obj_name }.|.
            mv_msg_type = `Success`.
          ELSE.
            mv_message = |Save failed (sy-subrc={ sy-subrc }).|.
            mv_msg_type = `Error`.
          ENDIF.
        ELSE.
          mv_message = `Could not determine report name.`.
          mv_msg_type = `Error`.
        ENDIF.

      WHEN OTHERS.
        mv_message = |Save not supported for type { mv_cur_obj_type }.|.
        mv_msg_type = `Warning`.

    ENDCASE.
  ENDMETHOD.


  METHOD activate_object.
    CLEAR: mv_message, mv_msg_type.
    CHECK mv_cur_obj_name IS NOT INITIAL.

    DATA lt_objects TYPE STANDARD TABLE OF dwinactiv.
    DATA ls_obj TYPE dwinactiv.

    CASE mv_cur_obj_type.
      WHEN 'CLAS'.
        ls_obj-object = 'CLAS'.
        ls_obj-obj_name = mv_cur_obj_name.
      WHEN 'INTF'.
        ls_obj-object = 'INTF'.
        ls_obj-obj_name = mv_cur_obj_name.
      WHEN 'PROG'.
        ls_obj-object = 'REPS'.
        ls_obj-obj_name = mv_cur_obj_name.
      WHEN 'FUNC'.
        ls_obj-object = 'FUNC'.
        ls_obj-obj_name = mv_cur_obj_name.
      WHEN OTHERS.
        ls_obj-object = mv_cur_obj_type.
        ls_obj-obj_name = mv_cur_obj_name.
    ENDCASE.

    APPEND ls_obj TO lt_objects.

    CALL FUNCTION 'RS_WORKING_OBJECTS_ACTIVATE'
      EXPORTING
        activate_ddic_objects  = abap_true
        with_popup             = abap_false
      TABLES
        objects                = lt_objects
      EXCEPTIONS
        excecution_error       = 1
        cancelled              = 2
        OTHERS                 = 3.

    IF sy-subrc = 0.
      mv_message = |{ mv_cur_obj_name } activated successfully.|.
      mv_msg_type = `Success`.
      " Reload source to show active version
      load_source( ).
    ELSE.
      mv_message = |Activation failed (rc={ sy-subrc }). Check syntax.|.
      mv_msg_type = `Error`.
    ENDIF.
  ENDMETHOD.


  METHOD get_object_icon.
    result = SWITCH #( iv_type
      WHEN 'CLAS' THEN `sap-icon://course-book`
      WHEN 'INTF' THEN `sap-icon://interface`
      WHEN 'PROG' THEN `sap-icon://document-text`
      WHEN 'FUGR' THEN `sap-icon://group`
      WHEN 'TABL' THEN `sap-icon://grid`
      WHEN 'DTEL' THEN `sap-icon://detail-view`
      WHEN 'DOMA' THEN `sap-icon://value-help`
      WHEN 'DDLS' THEN `sap-icon://database`
      WHEN 'SRVD' THEN `sap-icon://connected`
      WHEN 'SRVB' THEN `sap-icon://world`
      WHEN 'DEVC' THEN `sap-icon://folder-blank`
      WHEN 'MSAG' THEN `sap-icon://message-popup`
      WHEN 'TTYP' THEN `sap-icon://table-view`
      WHEN 'XSLT' THEN `sap-icon://syntax`
      WHEN 'ENHO' THEN `sap-icon://add-activity`
      WHEN 'BDEF' THEN `sap-icon://action-settings`
      WHEN 'DDLX' THEN `sap-icon://customize`
      ELSE `sap-icon://document` ).
  ENDMETHOD.

ENDCLASS.
