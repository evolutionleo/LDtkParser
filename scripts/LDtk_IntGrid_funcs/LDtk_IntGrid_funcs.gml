/// @desc  Returns the id of a LDtk intGrid layer.
/// @param {string} ldtk_intgrid_layer_name  LDtk intGrid layer name to return the contents from.
/// @returns {array} Pointer to 1D array of intGrid values.
function ldtk_get_intgrid_id(ldtk_intgrid_layer_name){
    
    if( variable_struct_exists( global.ldtk_intgrids, ldtk_intgrid_layer_name)){
        return global.ldtk_intgrids[$ ldtk_intgrid_layer_name];
    }
    else {
        show_debug_message($"[LDtk] Couldn't find '{ldtk_intgrid_layer_name}' intGrid.");
    }
}

function ldtk_intgrid_get(intGrid_id, x, y){
    
    //
    x= x div intGrid_id.width;
    y= y div intGrid_id.height;
}