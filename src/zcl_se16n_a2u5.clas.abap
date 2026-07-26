CLASS zcl_se16n_a2u5 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    CONSTANTS c_max_cols    TYPE i VALUE 50.
    CONSTANTS c_default_max TYPE i VALUE 200.
    CONSTANTS c_max_cap     TYPE i VALUE 10000.

    " Step state: 1=name input, 2=selection screen, 3=result
    DATA mv_step       TYPE i VALUE 1.

    " --- Step 1 ---
    DATA mv_table_name TYPE string.
    DATA mv_max_hits   TYPE string VALUE `200`.

    " --- Step 2: Field metadata ---
    TYPES: BEGIN OF ty_s_field,
             fname   TYPE string,
             label   TYPE string,
             ftype   TYPE string,
             col_id  TYPE string,
             visible TYPE abap_bool,
             sort    TYPE string,
           END OF ty_s_field,
           ty_t_field TYPE STANDARD TABLE OF ty_s_field WITH EMPTY KEY.
    DATA mt_fields TYPE ty_t_field.

    " --- Step 2: Selection criteria ---
    TYPES: BEGIN OF ty_s_crit,
             key   TYPE string,
             fname TYPE string,
             sign  TYPE string,
             opt   TYPE string,
             low   TYPE string,
             high  TYPE string,
           END OF ty_s_crit,
           ty_t_crit TYPE STANDARD TABLE OF ty_s_crit WITH EMPTY KEY.
    DATA mt_crit TYPE ty_t_crit.

    " --- Dropdown key/text ---
    TYPES: BEGIN OF ty_s_kt,
             key  TYPE string,
             text TYPE string,
           END OF ty_s_kt,
           ty_t_kt TYPE STANDARD TABLE OF ty_s_kt WITH EMPTY KEY.
    DATA mt_signs     TYPE ty_t_kt.
    DATA mt_opts      TYPE ty_t_kt.
    DATA mt_sort_opts TYPE ty_t_kt.

    " --- Step 3: Result (fixed-width 50 string columns) ---
    TYPES: BEGIN OF ty_s_row,
             c01 TYPE string, c02 TYPE string, c03 TYPE string, c04 TYPE string, c05 TYPE string,
             c06 TYPE string, c07 TYPE string, c08 TYPE string, c09 TYPE string, c10 TYPE string,
             c11 TYPE string, c12 TYPE string, c13 TYPE string, c14 TYPE string, c15 TYPE string,
             c16 TYPE string, c17 TYPE string, c18 TYPE string, c19 TYPE string, c20 TYPE string,
             c21 TYPE string, c22 TYPE string, c23 TYPE string, c24 TYPE string, c25 TYPE string,
             c26 TYPE string, c27 TYPE string, c28 TYPE string, c29 TYPE string, c30 TYPE string,
             c31 TYPE string, c32 TYPE string, c33 TYPE string, c34 TYPE string, c35 TYPE string,
             c36 TYPE string, c37 TYPE string, c38 TYPE string, c39 TYPE string, c40 TYPE string,
             c41 TYPE string, c42 TYPE string, c43 TYPE string, c44 TYPE string, c45 TYPE string,
             c46 TYPE string, c47 TYPE string, c48 TYPE string, c49 TYPE string, c50 TYPE string,
           END OF ty_s_row,
           ty_t_row TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    DATA mt_rows       TYPE ty_t_row.
    DATA mv_total_rows TYPE i.

    " --- Status message ---
    DATA mv_message      TYPE string.
    DATA mv_message_type TYPE string VALUE `Information`.

    " --- Value help suggestions ---
    TYPES: BEGIN OF ty_s_suggest,
             tabname TYPE string,
             ddtext  TYPE string,
           END OF ty_s_suggest,
           ty_t_suggest TYPE STANDARD TABLE OF ty_s_suggest WITH EMPTY KEY.
    DATA mt_suggestions TYPE ty_t_suggest.

    " --- Search in results ---
    DATA mv_search   TYPE string.
    DATA mv_show_shell TYPE abap_bool VALUE abap_true.

    " --- Variants ---
    TYPES: BEGIN OF ty_s_variant_list,
             id   TYPE string,
             name TYPE string,
           END OF ty_s_variant_list,
           ty_t_variant_list TYPE STANDARD TABLE OF ty_s_variant_list WITH EMPTY KEY.
    DATA mv_variant_name TYPE string.
    DATA mt_variant_list TYPE ty_t_variant_list.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_step_1.
    METHODS view_step_2.
    METHODS view_step_3.
    METHODS on_event.
    METHODS load_metadata.
    METHODS execute_query.
    METHODS init_dropdowns.
    METHODS search_tables
      IMPORTING iv_term TYPE string.
    METHODS variant_save.
    METHODS variant_load
      IMPORTING iv_id TYPE string.
    METHODS variant_delete
      IMPORTING iv_id TYPE string.
    METHODS variant_list_refresh.

  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_se16n_a2u5 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      init_dropdowns( ).
      view_step_1( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    CASE client->get( )-event.

      WHEN `LOAD_METADATA`.
        load_metadata( ).
        IF mv_step = 2.
          variant_list_refresh( ).
          view_step_2( ).
        ELSE.
          view_step_1( ).
        ENDIF.

      WHEN `ADD_CRIT`.
        TRY.
            DATA(lv_uuid) = cl_system_uuid=>create_uuid_c32_static( ).
          CATCH cx_uuid_error.
            lv_uuid = |{ sy-uzeit }{ lines( mt_crit ) }|.
        ENDTRY.
        APPEND VALUE #(
            key  = lv_uuid
            sign = `I`
            opt  = `EQ` ) TO mt_crit.
        client->view_model_update( ).

      WHEN `DEL_CRIT`.
        DATA(lv_key) = client->get_event_arg( ).
        DELETE mt_crit WHERE key = lv_key.
        client->view_model_update( ).

      WHEN `EXECUTE`.
        execute_query( ).
        IF mv_step = 3.
          view_step_3( ).
        ELSE.
          client->view_model_update( ).
        ENDIF.

      WHEN `COUNT`.
        DATA lv_where TYPE string.
        DATA lv_count TYPE i.
        lv_where = ``.
        LOOP AT mt_crit ASSIGNING FIELD-SYMBOL(<c>) WHERE fname IS NOT INITIAL AND low IS NOT INITIAL.
          DATA(lv_val) = <c>-low.
          REPLACE ALL OCCURRENCES OF `'` IN lv_val WITH `''`.
          IF lv_where IS NOT INITIAL.
            lv_where = |{ lv_where } AND |.
          ENDIF.
          lv_where = |{ lv_where }{ <c>-fname } = '{ lv_val }'|.
        ENDLOOP.
        IF lv_where IS INITIAL.
          lv_where = `1 = 1`.
        ENDIF.
        TRY.
            SELECT COUNT(*) FROM (mv_table_name) WHERE (lv_where) INTO @lv_count.
            mv_message      = |Number of entries: { lv_count }|.
            mv_message_type = `Success`.
          CATCH cx_root INTO DATA(lx_cnt).
            mv_message      = |COUNT failed: { lx_cnt->get_text( ) }|.
            mv_message_type = `Error`.
        ENDTRY.
        view_step_2( ).

      WHEN `SUGGEST`.
        DATA(lv_term) = client->get_event_arg( ).
        search_tables( lv_term ).
        client->view_model_update( ).

      WHEN `SEARCH_RESULT`.
        DATA(lv_search) = to_upper( mv_search ).
        " Re-run query to get full data, then filter client-side
        execute_query( ).
        IF lv_search IS NOT INITIAL.
          DATA lt_keep TYPE ty_t_row.
          LOOP AT mt_rows ASSIGNING FIELD-SYMBOL(<row>).
            DATA lv_found TYPE abap_bool.
            lv_found = abap_false.
            LOOP AT mt_fields ASSIGNING FIELD-SYMBOL(<sf>).
              ASSIGN COMPONENT <sf>-col_id OF STRUCTURE <row> TO FIELD-SYMBOL(<cv>).
              IF <cv> IS ASSIGNED AND <cv> CS lv_search.
                lv_found = abap_true.
                EXIT.
              ENDIF.
              UNASSIGN <cv>.
            ENDLOOP.
            IF lv_found = abap_true.
              APPEND <row> TO lt_keep.
            ENDIF.
          ENDLOOP.
          mt_rows = lt_keep.
          mv_total_rows = lines( mt_rows ).
        ENDIF.
        client->view_model_update( ).

      WHEN `TOGGLE_SHELL`.
        IF mv_show_shell = abap_true.
          mv_show_shell = abap_false.
        ELSE.
          mv_show_shell = abap_true.
        ENDIF.
        view_step_3( ).

      WHEN `SAVE_VARIANT`.
        variant_save( ).
        client->view_model_update( ).

      WHEN `LOAD_VARIANT`.
        DATA(lv_var_id) = client->get_event_arg( ).
        variant_load( lv_var_id ).
        view_step_2( ).

      WHEN `DEL_VARIANT`.
        DATA(lv_del_id) = client->get_event_arg( ).
        variant_delete( lv_del_id ).
        client->view_model_update( ).

      WHEN `BACK_TO_INPUT`.
        CLEAR: mt_fields, mt_crit, mt_rows, mv_message, mv_total_rows.
        mv_message_type = `Information`.
        mv_step         = 1.
        view_step_1( ).

      WHEN `BACK_TO_SEL`.
        mv_step = 2.
        CLEAR: mt_rows, mv_total_rows, mv_message.
        view_step_2( ).

    ENDCASE.

  ENDMETHOD.


  METHOD view_step_1.

    DATA(view) = z2ui5_cl_xml_view=>factory( ).

    DATA(page) = view->shell( )->page(
        title = `SE16N - Generic Data Browser` ).

    IF mv_message IS NOT INITIAL.
      page->message_strip(
          text     = mv_message
          type     = mv_message_type
          showicon = abap_true ).
    ENDIF.

    DATA(form) = page->simple_form(
        editable = abap_true
        )->content( `form` ).

    form->label( `Table / CDS View` ).
    form->input(
        id              = `idTableInput`
        value           = client->_bind( mv_table_name )
        placeholder     = `e.g. MARA, T001, I_PRODUCT ...`
        showsuggestion  = abap_true
        suggestionitems = client->_bind( mt_suggestions )
        suggest         = client->_event( val = `SUGGEST`
                              t_arg = VALUE #( ( `${$parameters>/suggestValue}` ) ) )
        submit          = client->_event( `LOAD_METADATA` )
    )->get(
    )->suggestion_items( )->get(
        )->list_item(
            text           = `{TABNAME}`
            additionaltext = `{DDTEXT}` ).

    " Set focus to table input on init
    client->follow_up_action(
        val   = client->cs_event-set_focus
        t_arg = VALUE #( ( `idTableInput` ) ) ).

    form->label( `Maximum number of hits` ).
    form->input(
        value       = client->_bind( mv_max_hits )
        placeholder = |Default { c_default_max }, max { c_max_cap }| ).

    " --- Footer ---
    page->footer(
        )->overflow_toolbar(
            )->toolbar_spacer(
            )->button(
                text  = `Execute`
                type  = `Emphasized`
                icon  = `sap-icon://initiative`
                press = client->_event( `LOAD_METADATA` ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD view_step_2.

    " Use the classic z2ui5_cl_xml_view builder for step 2 because it
    " requires dynamic loops (field dropdown items) which don't work
    " well with the generic z2ui5_cl_ai_xml builder's chain-breaking.
    DATA(view) = z2ui5_cl_xml_view=>factory( ).

    DATA(page) = view->shell( )->page(
        title = |Selection: { mv_table_name }| ).

    IF mv_message IS NOT INITIAL.
      page->message_strip(
          text     = mv_message
          type     = mv_message_type
          showicon = abap_true ).
    ENDIF.

    " --- Variant toolbar ---
    DATA(var_bar) = page->_generic(
        name   = `Toolbar`
        t_prop = VALUE #( ( n = `class` v = `sapUiSmallMarginBottom` ) ) ).
    var_bar->_generic(
        name   = `Input`
        t_prop = VALUE #(
            ( n = `value`       v = client->_bind( mv_variant_name ) )
            ( n = `placeholder` v = `Variant name...` )
            ( n = `width`       v = `200px` ) ) ).
    var_bar->_generic(
        name   = `Button`
        t_prop = VALUE #(
            ( n = `text`  v = `Save` )
            ( n = `icon`  v = `sap-icon://save` )
            ( n = `type`  v = `Emphasized` )
            ( n = `press` v = client->_event( `SAVE_VARIANT` ) ) ) ).
    var_bar->_generic(
        name   = `ToolbarSpacer`
        t_prop = VALUE #( ) ).
    " Variant dropdown for loading
    DATA(var_sel) = var_bar->_generic(
        name   = `Select`
        t_prop = VALUE #(
            ( n = `width`    v = `250px` )
            ( n = `change`   v = client->_event( val = `LOAD_VARIANT`
                                  t_arg = VALUE #( ( `${$source>/selectedItem/key}` ) ) ) ) ) ).
    DATA(var_items) = var_sel->_generic( `items` ).
    var_items->_generic(
        name   = `Item`
        ns     = `core`
        t_prop = VALUE #(
            ( n = `xmlns:core` v = `sap.ui.core` )
            ( n = `key`        v = `` )
            ( n = `text`       v = `-- Load Variant --` ) ) ).
    LOOP AT mt_variant_list ASSIGNING FIELD-SYMBOL(<vl>).
      var_items->_generic(
          name   = `Item`
          ns     = `core`
          t_prop = VALUE #(
              ( n = `xmlns:core` v = `sap.ui.core` )
              ( n = `key`        v = <vl>-id )
              ( n = `text`       v = <vl>-name ) ) ).
    ENDLOOP.

    " --- Panel: Output fields ---
    DATA(field_panel) = page->panel(
        headertext = `Output Fields & Sort`
        expandable = abap_true
        expanded   = abap_true ).

    DATA(field_table) = field_panel->table(
        items  = client->_bind( mt_fields )
        sticky = `ColumnHeaders` ).

    field_table->columns(
        )->column( width = `35%` )->text( `Field`
        )->get_parent( )->column( width = `30%` )->text( `Type`
        )->get_parent( )->column( width = `12%` )->text( `Output`
        )->get_parent( )->column( )->text( `Sort` ).

    DATA(field_cells) = field_table->items( )->column_list_item( )->cells( ).
    field_cells->text( `{LABEL}` ).
    field_cells->text( `{FTYPE}` ).
    field_cells->checkbox( selected = `{VISIBLE}` ).
    DATA(sort_sel) = field_cells->select( selectedkey = `{SORT}` ).
    sort_sel->item( key = `` text = `(none)` ).
    sort_sel->item( key = `A` text = `Ascending` ).
    sort_sel->item( key = `D` text = `Descending` ).

    " --- Panel: Selection criteria ---
    DATA(crit_panel) = page->panel(
        headertext = `Selection Criteria`
        expandable = abap_true
        expanded   = abap_true ).

    DATA(crit_table) = crit_panel->table(
        items  = client->_bind( mt_crit )
        sticky = `ColumnHeaders` ).

    crit_table->columns(
        )->column( width = `22%` )->text( `Field`
        )->get_parent( )->column( width = `10%` )->text( `Sign`
        )->get_parent( )->column( width = `14%` )->text( `Operator`
        )->get_parent( )->column( )->text( `Low`
        )->get_parent( )->column( )->text( `High`
        )->get_parent( )->column( width = `5%` )->text( `` ).

    DATA(crit_cells) = crit_table->items( )->column_list_item( )->cells( ).

    " Field dropdown - built dynamically from mt_fields
    DATA(fname_sel) = crit_cells->select( selectedkey = `{FNAME}` ).
    LOOP AT mt_fields ASSIGNING FIELD-SYMBOL(<fld>).
      fname_sel->item( key = <fld>-fname text = <fld>-label ).
    ENDLOOP.

    " Sign dropdown
    DATA(sign_sel) = crit_cells->select( selectedkey = `{SIGN}` ).
    sign_sel->item( key = `I` text = `Include` ).
    sign_sel->item( key = `E` text = `Exclude` ).

    " Operator dropdown
    DATA(opt_sel) = crit_cells->select( selectedkey = `{OPT}` ).
    opt_sel->item( key = `EQ` text = `=` ).
    opt_sel->item( key = `NE` text = `<>` ).
    opt_sel->item( key = `BT` text = `Between` ).
    opt_sel->item( key = `CP` text = `Pattern (*)` ).
    opt_sel->item( key = `GT` text = `>` ).
    opt_sel->item( key = `LT` text = `<` ).
    opt_sel->item( key = `GE` text = `>=` ).
    opt_sel->item( key = `LE` text = `<=` ).

    " Low / High / Delete button
    crit_cells->input( value = `{LOW}` ).
    crit_cells->input( value = `{HIGH}` ).
    crit_cells->button(
        icon  = `sap-icon://decline`
        type  = `Transparent`
        press = client->_event( val = `DEL_CRIT` t_arg = VALUE #( ( `${KEY}` ) ) ) ).

    " Add-row button below the table
    crit_panel->button(
        text  = `Add row`
        icon  = `sap-icon://add`
        press = client->_event( `ADD_CRIT` ) ).

    " --- Footer ---
    page->footer(
        )->overflow_toolbar(
            )->toolbar_spacer(
            )->button(
                text  = `Back`
                icon  = `sap-icon://nav-back`
                press = client->_event( `BACK_TO_INPUT` )
            )->button(
                text  = `Number of Entries`
                icon  = `sap-icon://number-sign`
                press = client->_event( `COUNT` )
            )->button(
                text  = `Execute`
                type  = `Emphasized`
                icon  = `sap-icon://search`
                press = client->_event( `EXECUTE` ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD view_step_3.

    " Use classic builder for dynamic column generation via loops
    DATA(view) = z2ui5_cl_xml_view=>factory( ).

    DATA(lo_root) = COND #(
        WHEN mv_show_shell = abap_true
        THEN view->shell( )
        ELSE view ).
    DATA(page) = lo_root->page(
        title = |Result: { mv_table_name } ({ mv_total_rows } rows)| ).

    IF mv_message IS NOT INITIAL.
      page->message_strip(
          text     = mv_message
          type     = mv_message_type
          showicon = abap_true ).
    ENDIF.

    " Determine which fields to show
    DATA(lv_any_visible) = abap_false.
    LOOP AT mt_fields TRANSPORTING NO FIELDS WHERE visible = abap_true.
      lv_any_visible = abap_true.
      EXIT.
    ENDLOOP.

    " Count visible columns
    DATA(lv_vis_cols) = 0.
    LOOP AT mt_fields ASSIGNING FIELD-SYMBOL(<fc>).
      IF lv_any_visible = abap_true AND <fc>-visible = abap_false.
        CONTINUE.
      ENDIF.
      lv_vis_cols = lv_vis_cols + 1.
    ENDLOOP.

    " --- Search bar + Shell toggle ---
    DATA(search_bar) = page->_generic(
        name   = `Toolbar`
        t_prop = VALUE #( ( n = `class` v = `sapUiSmallMarginBottom` ) ) ).
    search_bar->_generic(
        name   = `SearchField`
        t_prop = VALUE #(
            ( n = `value`       v = client->_bind( mv_search ) )
            ( n = `placeholder` v = `Search in results...` )
            ( n = `width`       v = `300px` )
            ( n = `liveChange`  v = client->_event( `SEARCH_RESULT` ) ) ) ).
    search_bar->_generic(
        name   = `ToolbarSpacer`
        t_prop = VALUE #( ) ).
    search_bar->_generic(
        name   = `Label`
        t_prop = VALUE #(
            ( n = `text` v = |{ mv_total_rows } rows| ) ) ).
    search_bar->_generic(
        name   = `ToolbarSeparator`
        t_prop = VALUE #( ) ).
    search_bar->_generic(
        name   = `Label`
        t_prop = VALUE #(
            ( n = `text` v = `Shell` ) ) ).
    search_bar->_generic(
        name   = `Switch`
        t_prop = VALUE #(
            ( n = `state` v = client->_bind( mv_show_shell ) )
            ( n = `change` v = client->_event( `TOGGLE_SHELL` ) ) ) ).

    " Use sap.ui.table.Table for proper horizontal scrolling (like ALV)
    " visibleRowCountMode=Auto fills the available page height
    DATA(lv_row_count) = COND string(
        WHEN mv_total_rows < 20 THEN |{ mv_total_rows }|
        ELSE `20` ).

    DATA(grid_table) = page->_generic(
        name   = `Table`
        ns     = `table`
        t_prop = VALUE #(
            ( n = `xmlns:table`          v = `sap.ui.table` )
            ( n = `rows`                 v = client->_bind( mt_rows ) )
            ( n = `visibleRowCountMode`  v = `Auto` )
            ( n = `visibleRowCount`      v = lv_row_count )
            ( n = `selectionMode`        v = `None` )
            ( n = `rowHeight`            v = `32` )
            ( n = `minAutoRowCount`      v = `10` ) ) ).

    " Build columns dynamically with sap.ui.table.Column
    DATA(grid_cols) = grid_table->_generic( name = `columns` ns = `table` ).
    LOOP AT mt_fields ASSIGNING FIELD-SYMBOL(<col>).
      IF lv_any_visible = abap_true AND <col>-visible = abap_false.
        CONTINUE.
      ENDIF.
      DATA(grid_col) = grid_cols->_generic(
          name   = `Column`
          ns     = `table`
          t_prop = VALUE #(
              ( n = `width`    v = `8rem` )
              ( n = `sortProperty` v = <col>-col_id )
              ( n = `filterProperty` v = <col>-col_id ) ) ).
      " Label
      grid_col->_generic( name = `label` ns = `table`
          )->_generic( name = `Label` t_prop = VALUE #( ( n = `text` v = <col>-fname ) ) ).
      " Template
      grid_col->_generic( name = `template` ns = `table`
          )->_generic( name = `Text` t_prop = VALUE #(
              ( n = `text`     v = |\{{ <col>-col_id }\}| )
              ( n = `wrapping` v = `false` ) ) ).
    ENDLOOP.

    " --- Footer ---
    page->footer(
        )->overflow_toolbar(
            )->toolbar_spacer(
            )->button(
                text  = `Back to Selection`
                icon  = `sap-icon://nav-back`
                press = client->_event( `BACK_TO_SEL` )
            )->button(
                text  = `New Search`
                type  = `Emphasized`
                icon  = `sap-icon://restart`
                press = client->_event( `BACK_TO_INPUT` ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD load_metadata.

    DATA: lo_struct    TYPE REF TO cl_abap_structdescr,
          lo_table     TYPE REF TO cl_abap_tabledescr,
          lo_typedescr TYPE REF TO cl_abap_typedescr.

    CLEAR: mt_fields, mt_crit, mt_rows, mv_message.
    mv_total_rows = 0.

    CONDENSE mv_table_name NO-GAPS.
    mv_table_name = to_upper( mv_table_name ).

    IF mv_table_name IS INITIAL.
      mv_message      = `Please enter a table or CDS view name.`.
      mv_message_type = `Error`.
      RETURN.
    ENDIF.

    TRY.
        lo_typedescr = cl_abap_typedescr=>describe_by_name( mv_table_name ).
        CASE lo_typedescr->kind.
          WHEN cl_abap_typedescr=>kind_table.
            lo_table  ?= lo_typedescr.
            lo_struct ?= lo_table->get_table_line_type( ).
          WHEN cl_abap_typedescr=>kind_struct.
            lo_struct ?= lo_typedescr.
          WHEN OTHERS.
            mv_message      = |{ mv_table_name } is not a table or structure.|.
            mv_message_type = `Error`.
            RETURN.
        ENDCASE.
      CATCH cx_root INTO DATA(lx).
        mv_message      = |Cannot resolve { mv_table_name }: { lx->get_text( ) }|.
        mv_message_type = `Error`.
        RETURN.
    ENDTRY.

    " Use get_ddic_field_list to flatten includes and get field texts
    DATA lv_idx TYPE i.
    TRY.
        DATA(lt_ddic) = lo_struct->get_ddic_field_list( ).
        LOOP AT lt_ddic ASSIGNING FIELD-SYMBOL(<dd>).
          IF <dd>-fieldname CP `.INCLUDE*` OR <dd>-fieldname CP `.INCLU*`.
            CONTINUE.
          ENDIF.
          lv_idx = lv_idx + 1.
          IF lv_idx > c_max_cols.
            EXIT.
          ENDIF.
          DATA(lv_label) = COND string(
              WHEN <dd>-scrtext_m IS NOT INITIAL THEN <dd>-scrtext_m
              WHEN <dd>-scrtext_s IS NOT INITIAL THEN <dd>-scrtext_s
              WHEN <dd>-fieldtext IS NOT INITIAL THEN <dd>-fieldtext
              ELSE <dd>-fieldname ).
          APPEND VALUE #(
              fname   = <dd>-fieldname
              label   = |{ <dd>-fieldname } ({ lv_label })|
              ftype   = |{ <dd>-datatype }({ <dd>-leng })|
              col_id  = |C{ lv_idx WIDTH = 2 PAD = '0' ALIGN = RIGHT }|
              visible = abap_true
              sort    = `` ) TO mt_fields.
        ENDLOOP.
      CATCH cx_root.
        " Fallback for non-DDIC objects: flatten includes manually
        DATA(lt_comp) = lo_struct->get_components( ).
        LOOP AT lt_comp ASSIGNING FIELD-SYMBOL(<comp>).
          IF <comp>-type IS NOT BOUND.
            CONTINUE.
          ENDIF.
          IF <comp>-type->kind = cl_abap_typedescr=>kind_struct.
            DATA(lo_nested) = CAST cl_abap_structdescr( <comp>-type ).
            LOOP AT lo_nested->get_components( ) ASSIGNING FIELD-SYMBOL(<nc>).
              lv_idx = lv_idx + 1.
              IF lv_idx > c_max_cols. EXIT. ENDIF.
              APPEND VALUE #(
                  fname   = <nc>-name
                  label   = <nc>-name
                  ftype   = COND #( WHEN <nc>-type IS BOUND THEN <nc>-type->absolute_name ELSE `?` )
                  col_id  = |C{ lv_idx WIDTH = 2 PAD = '0' ALIGN = RIGHT }|
                  visible = abap_true
                  sort    = `` ) TO mt_fields.
            ENDLOOP.
          ELSE.
            lv_idx = lv_idx + 1.
            IF lv_idx > c_max_cols. EXIT. ENDIF.
            APPEND VALUE #(
                fname   = <comp>-name
                label   = <comp>-name
                ftype   = <comp>-type->absolute_name
                col_id  = |C{ lv_idx WIDTH = 2 PAD = '0' ALIGN = RIGHT }|
                visible = abap_true
                sort    = `` ) TO mt_fields.
          ENDIF.
        ENDLOOP.
    ENDTRY.

    IF mt_fields IS INITIAL.
      mv_message      = |No fields found for { mv_table_name }.|.
      mv_message_type = `Error`.
      RETURN.
    ENDIF.

    mv_message = |Loaded { lines( mt_fields ) } fields. Add selection criteria and execute.|.
    mv_message_type = `Success`.
    mv_step         = 2.

  ENDMETHOD.


  METHOD execute_query.

    DATA: lr_data  TYPE REF TO data,
          lv_where TYPE string,
          lv_max   TYPE i.

    CLEAR: mt_rows, mv_message.
    mv_total_rows = 0.

    " Build WHERE clause from criteria
    DATA lt_where TYPE STANDARD TABLE OF string.
    LOOP AT mt_crit ASSIGNING FIELD-SYMBOL(<c>) WHERE fname IS NOT INITIAL.
      IF <c>-low IS INITIAL AND <c>-high IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_low) = <c>-low.
      REPLACE ALL OCCURRENCES OF `'` IN lv_low WITH `''`.

      CASE <c>-opt.
        WHEN `EQ`.
          APPEND |{ <c>-fname } = '{ lv_low }'| TO lt_where.
        WHEN `NE`.
          APPEND |{ <c>-fname } <> '{ lv_low }'| TO lt_where.
        WHEN `GT`.
          APPEND |{ <c>-fname } > '{ lv_low }'| TO lt_where.
        WHEN `GE`.
          APPEND |{ <c>-fname } >= '{ lv_low }'| TO lt_where.
        WHEN `LT`.
          APPEND |{ <c>-fname } < '{ lv_low }'| TO lt_where.
        WHEN `LE`.
          APPEND |{ <c>-fname } <= '{ lv_low }'| TO lt_where.
        WHEN `CP`.
          DATA(lv_like) = lv_low.
          REPLACE ALL OCCURRENCES OF `*` IN lv_like WITH `%`.
          REPLACE ALL OCCURRENCES OF `+` IN lv_like WITH `_`.
          APPEND |{ <c>-fname } LIKE '{ lv_like }'| TO lt_where.
        WHEN `BT`.
          DATA(lv_high) = <c>-high.
          REPLACE ALL OCCURRENCES OF `'` IN lv_high WITH `''`.
          APPEND |{ <c>-fname } BETWEEN '{ lv_low }' AND '{ lv_high }'| TO lt_where.
        WHEN OTHERS.
          APPEND |{ <c>-fname } = '{ lv_low }'| TO lt_where.
      ENDCASE.
    ENDLOOP.

    IF lt_where IS NOT INITIAL.
      lv_where = concat_lines_of( table = lt_where sep = ` AND ` ).
    ELSE.
      lv_where = `1 = 1`.
    ENDIF.

    " Max hits
    TRY.
        lv_max = mv_max_hits.
      CATCH cx_root.
        lv_max = c_default_max.
    ENDTRY.
    IF lv_max <= 0. lv_max = c_default_max. ENDIF.
    IF lv_max > c_max_cap. lv_max = c_max_cap. ENDIF.

    " Build ORDER BY
    DATA lt_order TYPE STANDARD TABLE OF string.
    LOOP AT mt_fields ASSIGNING FIELD-SYMBOL(<sf>) WHERE sort = 'A' OR sort = 'D'.
      APPEND |{ <sf>-fname } { COND #( WHEN <sf>-sort = 'A' THEN `ASCENDING` ELSE `DESCENDING` ) }| TO lt_order.
    ENDLOOP.
    DATA(lv_order) = concat_lines_of( table = lt_order sep = `, ` ).

    " Execute dynamic SELECT
    TRY.
        CREATE DATA lr_data TYPE TABLE OF (mv_table_name).
        ASSIGN lr_data->* TO FIELD-SYMBOL(<lt_data>).

        IF lv_order IS INITIAL.
          SELECT * FROM (mv_table_name) WHERE (lv_where)
            INTO TABLE @<lt_data> UP TO @lv_max ROWS.
        ELSE.
          SELECT * FROM (mv_table_name) WHERE (lv_where) ORDER BY (lv_order)
            INTO TABLE @<lt_data> UP TO @lv_max ROWS.
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        mv_message      = |SELECT failed: { lx->get_text( ) }|.
        mv_message_type = `Error`.
        RETURN.
    ENDTRY.

    mv_total_rows = lines( <lt_data> ).

    " Map result to fixed-width string structure
    LOOP AT <lt_data> ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA ls_out TYPE ty_s_row.
      CLEAR ls_out.
      LOOP AT mt_fields ASSIGNING FIELD-SYMBOL(<fld>).
        ASSIGN COMPONENT <fld>-fname  OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<val>).
        ASSIGN COMPONENT <fld>-col_id OF STRUCTURE ls_out   TO FIELD-SYMBOL(<dst>).
        IF <val> IS ASSIGNED AND <dst> IS ASSIGNED.
          <dst> = |{ <val> }|.
        ENDIF.
        UNASSIGN: <val>, <dst>.
      ENDLOOP.
      APPEND ls_out TO mt_rows.
    ENDLOOP.

    mv_step         = 3.
    mv_message      = |{ mv_total_rows } rows retrieved (max { lv_max }).|.
    mv_message_type = COND #( WHEN mv_total_rows = 0 THEN `Warning` ELSE `Success` ).

  ENDMETHOD.


  METHOD search_tables.

    CLEAR mt_suggestions.
    IF iv_term IS INITIAL OR strlen( iv_term ) < 2.
      RETURN.
    ENDIF.

    DATA(lv_pattern) = |{ to_upper( iv_term ) }%|.

    SELECT dd~tabname, dt~ddtext
      FROM dd02l AS dd
      LEFT OUTER JOIN dd02t AS dt
        ON dt~tabname    = dd~tabname
       AND dt~ddlanguage = @sy-langu
       AND dt~as4local   = 'A'
      WHERE dd~tabname  LIKE @lv_pattern
        AND dd~as4local = 'A'
        AND dd~tabclass IN ( 'TRANSP', 'VIEW', 'CLUSTER', 'POOL' )
      ORDER BY dd~tabname
      INTO TABLE @DATA(lt_result)
      UP TO 20 ROWS.

    LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<r>).
      APPEND VALUE #(
          tabname = <r>-tabname
          ddtext  = COND #( WHEN <r>-ddtext IS NOT INITIAL THEN <r>-ddtext ELSE <r>-tabname )
      ) TO mt_suggestions.
    ENDLOOP.

  ENDMETHOD.


  METHOD init_dropdowns.

    mt_signs = VALUE #(
        ( key = `I` text = `Include` )
        ( key = `E` text = `Exclude` ) ).

    mt_opts = VALUE #(
        ( key = `EQ` text = `=` )
        ( key = `NE` text = `<>` )
        ( key = `BT` text = `Between` )
        ( key = `GT` text = `>` )
        ( key = `GE` text = `>=` )
        ( key = `LT` text = `<` )
        ( key = `LE` text = `<=` )
        ( key = `CP` text = `Pattern (*)` ) ).

    mt_sort_opts = VALUE #(
        ( key = ``  text = `(none)` )
        ( key = `A` text = `Ascending` )
        ( key = `D` text = `Descending` ) ).

  ENDMETHOD.


  METHOD variant_save.

    IF mv_variant_name IS INITIAL.
      mv_message      = `Please enter a variant name.`.
      mv_message_type = `Error`.
      RETURN.
    ENDIF.

    " Serialize current criteria + field settings to JSON
    TYPES: BEGIN OF ty_s_var_data,
             table_name TYPE string,
             max_hits   TYPE string,
             fields     TYPE ty_t_field,
             criteria   TYPE ty_t_crit,
           END OF ty_s_var_data.

    DATA(ls_data) = VALUE ty_s_var_data(
        table_name = mv_table_name
        max_hits   = mv_max_hits
        fields     = mt_fields
        criteria   = mt_crit ).

    " Build unique key: user + table + variant name
    DATA lv_key TYPE indx-srtfd.
    lv_key = |{ sy-uname }_{ mv_table_name }_{ mv_variant_name }|.

    " Store via EXPORT TO DATABASE
    TRY.
        EXPORT data = ls_data TO DATABASE indx(zv) ID lv_key.
        mv_message      = |Variant "{ mv_variant_name }" saved.|.
        mv_message_type = `Success`.
      CATCH cx_root INTO DATA(lx).
        mv_message      = |Save failed: { lx->get_text( ) }|.
        mv_message_type = `Error`.
    ENDTRY.

    variant_list_refresh( ).

  ENDMETHOD.


  METHOD variant_load.

    IF iv_id IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_s_var_data,
             table_name TYPE string,
             max_hits   TYPE string,
             fields     TYPE ty_t_field,
             criteria   TYPE ty_t_crit,
           END OF ty_s_var_data.

    DATA ls_data TYPE ty_s_var_data.
    DATA lv_id TYPE indx-srtfd.
    lv_id = iv_id.

    TRY.
        IMPORT data = ls_data FROM DATABASE indx(zv) ID lv_id.
        IF ls_data-table_name IS NOT INITIAL.
          mv_table_name = ls_data-table_name.
          mv_max_hits   = ls_data-max_hits.
          mt_fields     = ls_data-fields.
          mt_crit       = ls_data-criteria.
          mv_message      = |Variant loaded.|.
          mv_message_type = `Success`.
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        mv_message      = |Load failed: { lx->get_text( ) }|.
        mv_message_type = `Error`.
    ENDTRY.

  ENDMETHOD.


  METHOD variant_delete.

    IF iv_id IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_id TYPE indx-srtfd.
    lv_id = iv_id.
    DELETE FROM DATABASE indx(zv) ID lv_id.
    mv_message      = `Variant deleted.`.
    mv_message_type = `Success`.
    variant_list_refresh( ).

  ENDMETHOD.


  METHOD variant_list_refresh.

    CLEAR mt_variant_list.

    " Read all variants for current user + table from INDX
    DATA(lv_pattern) = |{ sy-uname }_{ mv_table_name }%|.

    SELECT srtfd
      FROM indx
      WHERE relid = 'ZV'
        AND srtfd LIKE @lv_pattern
      INTO TABLE @DATA(lt_keys).

    DATA(lv_prefix_len) = strlen( |{ sy-uname }_{ mv_table_name }_| ).

    LOOP AT lt_keys ASSIGNING FIELD-SYMBOL(<k>).
      DATA(lv_srtfd) = CONV string( <k>-srtfd ).
      DATA lv_vname TYPE string.
      IF strlen( lv_srtfd ) > lv_prefix_len.
        lv_vname = lv_srtfd+lv_prefix_len.
      ELSE.
        lv_vname = lv_srtfd.
      ENDIF.
      APPEND VALUE #(
          id   = lv_srtfd
          name = lv_vname
      ) TO mt_variant_list.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
