CLASS zcl_zlk05_tmp_probe DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.


CLASS zcl_zlk05_tmp_probe IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    " Scratch class used to probe read only system APIs while developing
    " the $ZLK_05 apps. It currently verifies the reworked RZ11 access.

    LOOP AT VALUE string_table( ( `login/*` ) ( `rdisp/wp_no_*` ) ( `zzz/*` ) )
         INTO DATA(lv_pattern).

      DATA(lt_par) = zcl_zlk05_sys_api=>search_parameters( iv_pattern = lv_pattern ).
      out->write( |pattern { lv_pattern } -> { lines( lt_par ) } row(s)| ).

      LOOP AT lt_par INTO DATA(ls_par) TO 4.
        out->write( |    { ls_par-paraname } = [{ ls_par-value }] | &&
                    |grp={ ls_par-grp } type={ ls_par-ptype } | &&
                    |dyn={ ls_par-dynamic }| ).
      ENDLOOP.
    ENDLOOP.

    out->write( |--- detail of rdisp/wp_no_dia ---| ).
    LOOP AT zcl_zlk05_sys_api=>get_parameter_detail( `rdisp/wp_no_dia` ) INTO DATA(ls_kv).
      out->write( |{ ls_kv-label }: { ls_kv-value }| ).
    ENDLOOP.

    out->write( |--- detail of an unknown parameter ---| ).
    LOOP AT zcl_zlk05_sys_api=>get_parameter_detail( `zzz/nonsense` ) INTO ls_kv.
      out->write( |{ ls_kv-label }: { ls_kv-value }| ).
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
