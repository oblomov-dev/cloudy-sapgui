CLASS zcl_cds_viewer_a2u5 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    " Limits
    CONSTANTS c_max_cols TYPE i VALUE 30.
    CONSTANTS c_max_rows TYPE i VALUE 100.

    " --- Step state ---
    " 1 = enter CDS view name
    " 2 = define filter criteria
    " 3 = display result data
    DATA mv_step          TYPE i VALUE 1.

    " --- Step 1 input ---
    DATA mv_cds_view_name TYPE string.

    " --- Step 2 filter table ---
    TYPES: BEGIN OF ty_s_filter,
             fname TYPE string,
             label TYPE string,
             ftype TYPE string,
             value TYPE string,
           END OF ty_s_filter,
           ty_t_filter TYPE STANDARD TABLE OF ty_s_filter WITH EMPTY KEY.
    DATA mt_filter TYPE ty_t_filter.

    " --- Step 3 column metadata + result rows ---
    TYPES: BEGIN OF ty_s_col,
             col_id TYPE string,
             fname  TYPE string,
             label  TYPE string,
           END OF ty_s_col,
           ty_t_col TYPE STANDARD TABLE OF ty_s_col WITH EMPTY KEY.
    DATA mt_cols TYPE ty_t_col.

    " Fixed-width row structure for serializable result data.
    " Up to c_max_cols (30) string columns C01 .. C30.
    TYPES: BEGIN OF ty_s_row,
             c01 TYPE string, c02 TYPE string, c03 TYPE string, c04 TYPE string, c05 TYPE string,
             c06 TYPE string, c07 TYPE string, c08 TYPE string, c09 TYPE string, c10 TYPE string,
             c11 TYPE string, c12 TYPE string, c13 TYPE string, c14 TYPE string, c15 TYPE string,
             c16 TYPE string, c17 TYPE string, c18 TYPE string, c19 TYPE string, c20 TYPE string,
             c21 TYPE string, c22 TYPE string, c23 TYPE string, c24 TYPE string, c25 TYPE string,
             c26 TYPE string, c27 TYPE string, c28 TYPE string, c29 TYPE string, c30 TYPE string,
           END OF ty_s_row,
           ty_t_row TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    DATA mt_rows       TYPE ty_t_row.
    DATA mv_total_rows TYPE i.

    " --- Status message ---
    DATA mv_message      TYPE string.
    DATA mv_message_type TYPE string VALUE `Information`.

  PROTECTED SECTION.

  PRIVATE SECTION.
    METHODS render_step_1
      IMPORTING client TYPE REF TO z2ui5_if_client.
    METHODS render_step_2
      IMPORTING client TYPE REF TO z2ui5_if_client.
    METHODS render_step_3
      IMPORTING client TYPE REF TO z2ui5_if_client.
    METHODS load_metadata.
    METHODS load_data.
    METHODS reset_state.
ENDCLASS.


CLASS zcl_cds_viewer_a2u5 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    " --- Event dispatcher ---
    IF client->check_on_init( ).
      mv_step = 1.

    ELSEIF client->check_on_event( `LOAD_METADATA` ).
      load_metadata( ).

    ELSEIF client->check_on_event( `LOAD_DATA` ).
      load_data( ).

    ELSEIF client->check_on_event( `BACK_TO_INPUT` ).
      reset_state( ).

    ELSEIF client->check_on_event( `BACK_TO_FILTER` ).
      mv_step = 2.
      CLEAR: mt_rows, mv_total_rows, mv_message.

    ENDIF.

    " --- Renderer dispatcher ---
    CASE mv_step.
      WHEN 1.
        render_step_1( client ).
      WHEN 2.
        render_step_2( client ).
      WHEN 3.
        render_step_3( client ).
      WHEN OTHERS.
        render_step_1( client ).
    ENDCASE.

  ENDMETHOD.


  METHOD reset_state.

    CLEAR: mv_cds_view_name, mt_filter, mt_cols, mt_rows,
           mv_message, mv_total_rows.
    mv_message_type = `Information`.
    mv_step         = 1.

  ENDMETHOD.


  METHOD load_metadata.

    DATA: lo_struct    TYPE REF TO cl_abap_structdescr,
          lo_table     TYPE REF TO cl_abap_tabledescr,
          lo_typedescr TYPE REF TO cl_abap_typedescr.

    CLEAR: mt_filter, mt_cols, mt_rows, mv_message.
    mv_total_rows = 0.

    " Trim and uppercase the CDS view name.
    CONDENSE mv_cds_view_name NO-GAPS.
    mv_cds_view_name = to_upper( mv_cds_view_name ).

    IF mv_cds_view_name IS INITIAL.
      mv_message      = `Please enter a CDS view, table, or structure name.`.
      mv_message_type = `Error`.
      RETURN.
    ENDIF.

    " Resolve the type via RTTI.
    TRY.
        lo_typedescr = cl_abap_typedescr=>describe_by_name( mv_cds_view_name ).
        CASE lo_typedescr->kind.
          WHEN cl_abap_typedescr=>kind_table.
            lo_table  ?= lo_typedescr.
            lo_struct ?= lo_table->get_table_line_type( ).
          WHEN cl_abap_typedescr=>kind_struct.
            lo_struct ?= lo_typedescr.
          WHEN OTHERS.
            mv_message      = |Object { mv_cds_view_name } is not a CDS view, table, or structure.|.
            mv_message_type = `Error`.
            RETURN.
        ENDCASE.
      CATCH cx_root INTO DATA(lx).
        mv_message      = |Cannot read structure of { mv_cds_view_name }: { lx->get_text( ) }|.
        mv_message_type = `Error`.
        RETURN.
    ENDTRY.

    " Build filter and column metadata tables.
    DATA(lt_components) = lo_struct->get_components( ).
    DATA lv_idx     TYPE i.
    DATA lv_type    TYPE string.

    LOOP AT lt_components ASSIGNING FIELD-SYMBOL(<comp>).
      lv_idx = sy-tabix.
      IF lv_idx > c_max_cols.
        EXIT.
      ENDIF.

      lv_type = COND #( WHEN <comp>-type IS BOUND
                        THEN <comp>-type->absolute_name
                        ELSE `?` ).

      APPEND VALUE #( fname = <comp>-name
                      label = <comp>-name
                      ftype = lv_type
                      value = `` ) TO mt_filter.

      APPEND VALUE #( col_id = |C{ lv_idx WIDTH = 2 PAD = '0' ALIGN = RIGHT }|
                      fname  = <comp>-name
                      label  = <comp>-name ) TO mt_cols.
    ENDLOOP.

    IF lines( mt_filter ) = 0.
      mv_message      = |No fields found for { mv_cds_view_name }.|.
      mv_message_type = `Error`.
      RETURN.
    ENDIF.

    DATA(lv_total_fields) = lines( lt_components ).
    DATA(lv_visible)      = lines( mt_filter ).

    IF lv_total_fields > c_max_cols.
      mv_message = |Loaded { lv_visible } of { lv_total_fields } fields (truncated to first { c_max_cols }). Define filters and click Search.|.
    ELSE.
      mv_message = |Loaded { lv_visible } fields. Define filters (leave empty to match all) and click Search.|.
    ENDIF.
    mv_message_type = `Information`.
    mv_step         = 2.

  ENDMETHOD.


  METHOD load_data.

    DATA: lr_data  TYPE REF TO data,
          lt_where TYPE STANDARD TABLE OF string,
          lv_where TYPE string.

    CLEAR: mt_rows, mv_message.
    mv_total_rows = 0.

    " Build dynamic WHERE clause from non-empty filter values.
    " Single quotes in user input are escaped.
    LOOP AT mt_filter ASSIGNING FIELD-SYMBOL(<filter>) WHERE value IS NOT INITIAL.
      DATA(lv_val) = <filter>-value.
      REPLACE ALL OCCURRENCES OF `'` IN lv_val WITH `''`.
      APPEND |{ <filter>-fname } = '{ lv_val }'| TO lt_where.
    ENDLOOP.

    IF lines( lt_where ) > 0.
      lv_where = concat_lines_of( table = lt_where sep = ` AND ` ).
    ELSE.
      lv_where = `1 = 1`.
    ENDIF.

    " Run dynamic SELECT *.
    TRY.
        CREATE DATA lr_data TYPE TABLE OF (mv_cds_view_name).
        ASSIGN lr_data->* TO FIELD-SYMBOL(<lt_data>).

        SELECT *
          FROM (mv_cds_view_name)
          WHERE (lv_where)
          INTO TABLE @<lt_data>
          UP TO @c_max_rows ROWS.

      CATCH cx_root INTO DATA(lx).
        mv_message      = |SELECT failed: { lx->get_text( ) }|.
        mv_message_type = `Error`.
        RETURN.
    ENDTRY.

    mv_total_rows = lines( <lt_data> ).

    " Convert each row to the fixed-width string structure.
    FIELD-SYMBOLS:
      <ls_data> TYPE any,
      <value>   TYPE any,
      <dest>    TYPE any.

    LOOP AT <lt_data> ASSIGNING <ls_data>.
      DATA ls_row TYPE ty_s_row.
      CLEAR ls_row.

      LOOP AT mt_cols ASSIGNING FIELD-SYMBOL(<col>).
        UNASSIGN: <value>, <dest>.
        ASSIGN COMPONENT <col>-fname  OF STRUCTURE <ls_data> TO <value>.
        ASSIGN COMPONENT <col>-col_id OF STRUCTURE ls_row    TO <dest>.
        IF <value> IS ASSIGNED AND <dest> IS ASSIGNED.
          <dest> = |{ <value> }|.
        ENDIF.
      ENDLOOP.

      APPEND ls_row TO mt_rows.
    ENDLOOP.

    mv_step    = 3.
    mv_message = |{ mv_total_rows } rows from { mv_cds_view_name } (max { c_max_rows }).|.
    IF mv_total_rows = 0.
      mv_message_type = `Warning`.
    ELSE.
      mv_message_type = `Success`.
    ENDIF.

  ENDMETHOD.


  METHOD render_step_1.

    DATA(view) = z2ui5_cl_xml_view=>factory( ).

    DATA(page) = view->shell( )->page(
        title          = `Generic CDS View Browser`
        navbuttonpress = client->_event_nav_app_leave( )
        shownavbutton  = client->check_app_prev_stack( ) ).

    IF mv_message IS NOT INITIAL.
      page->message_strip(
          text     = mv_message
          type     = mv_message_type
          showicon = abap_true ).
    ENDIF.

    page->simple_form(
        title    = `Step 1 of 3 - Enter CDS View Name`
        editable = abap_true
        )->content( `form`
        )->title( ns = `core` text = `Generic CDS View Browser`
        )->label( `CDS View / Table / Structure Name`
        )->input(
            placeholder = `e.g. I_PRODUCT, MARA, T001 ...`
            value       = client->_bind_edit( mv_cds_view_name )
        )->button(
            text  = `Load Metadata`
            type  = `Emphasized`
            press = client->_event( `LOAD_METADATA` ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD render_step_2.

    DATA(view) = z2ui5_cl_xml_view=>factory( ).

    DATA(page) = view->shell( )->page(
        title          = |Filter: { mv_cds_view_name }|
        navbuttonpress = client->_event( `BACK_TO_INPUT` )
        shownavbutton  = abap_true ).

    IF mv_message IS NOT INITIAL.
      page->message_strip(
          text     = mv_message
          type     = mv_message_type
          showicon = abap_true ).
    ENDIF.

    " Filter rows are rendered as a sap.m.Table with three columns:
    "   1) field name (read-only)
    "   2) field type (read-only)
    "   3) editable input bound to the row's VALUE field.
    DATA(filter_table) = page->table(
        items      = client->_bind_edit( mt_filter )
        headertext = |Step 2 of 3 - Filter criteria for { mv_cds_view_name } (leave blank to match all)|
        sticky     = `ColumnHeaders,HeaderToolbar` ).

    filter_table->columns(
        )->column( width = `30%` )->text( `Field`
        )->get_parent( )->column( width = `30%` )->text( `Type`
        )->get_parent( )->column( )->text( `Filter Value (equality match)` ).

    filter_table->items(
        )->column_list_item(
            )->cells(
                )->text( `{LABEL}`
                )->text( `{FTYPE}`
                )->input(
                    value       = `{VALUE}`
                    placeholder = `(no filter)` ).

    page->footer(
        )->overflow_toolbar(
            )->toolbar_spacer(
            )->button(
                text  = `Back`
                press = client->_event( `BACK_TO_INPUT` )
                icon  = `sap-icon://nav-back`
            )->button(
                text  = `Search`
                type  = `Emphasized`
                press = client->_event( `LOAD_DATA` )
                icon  = `sap-icon://search` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD render_step_3.

    DATA(view) = z2ui5_cl_xml_view=>factory( ).

    DATA(page) = view->shell( )->page(
        title          = |Data: { mv_cds_view_name }|
        navbuttonpress = client->_event( `BACK_TO_FILTER` )
        shownavbutton  = abap_true ).

    IF mv_message IS NOT INITIAL.
      page->message_strip(
          text     = mv_message
          type     = mv_message_type
          showicon = abap_true ).
    ENDIF.

    DATA(data_table) = page->table(
        items               = client->_bind( mt_rows )
        headertext          = |Step 3 of 3 - Result for { mv_cds_view_name } ({ mv_total_rows } rows, max { c_max_rows })|
        growing             = abap_true
        growingthreshold    = `25`
        growingscrolltoload = abap_true
        sticky              = `ColumnHeaders,HeaderToolbar` ).

    " Build column headers dynamically.
    DATA(columns) = data_table->columns( ).
    LOOP AT mt_cols ASSIGNING FIELD-SYMBOL(<col>).
      columns->column( )->text( <col>-label ).
    ENDLOOP.

    " Build cell template dynamically.
    " The text binding `{C01}` etc. is resolved per row by UI5
    " against the bound mt_rows model.
    DATA(cells) = data_table->items( )->column_list_item( )->cells( ).
    LOOP AT mt_cols ASSIGNING <col>.
      cells->text( |\{{ <col>-col_id }\}| ).
    ENDLOOP.

    page->footer(
        )->overflow_toolbar(
            )->toolbar_spacer(
            )->button(
                text  = `Back to Filter`
                press = client->_event( `BACK_TO_FILTER` )
                icon  = `sap-icon://nav-back`
            )->button(
                text  = `New Search`
                type  = `Emphasized`
                press = client->_event( `BACK_TO_INPUT` )
                icon  = `sap-icon://restart` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
