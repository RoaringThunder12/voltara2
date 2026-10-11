# THIS IS A GENERATED FILE!
#
# Source template:
# ~DevFolders\DynamicTerrain\templates\gfx\FX\agot_constants.fxh.jinja
#
# Please avoid making changes here directly, as they will get overwritten next time this file is regenerated.
# Instead edit the source template and/or variables it's based on, then regenerate it via render_templates.py .
Code [[
	//
	// Constants
	//

	// NOTE: The following constants were extracted from vanilla AddDecals() in portrait_decals.fxh
	//       and must be kept in sync with their vanilla counterparts on game updates.
	static const int  AGOT_VANILLA_TEXEL_COUNT_PER_DECAL = 15;    // TEXEL_COUNT_PER_DECAL
	static const uint AGOT_VANILLA_DATA_MAX_VALUE        = 65535; // MAX_VALUE
	// END NOTE

	static const int AGOT_TOTAL_BITS_PER_MARKER = 8;
	static const int AGOT_DATA_BITS_PER_MARKER  = 7; // Out of AGOT_TOTAL_BITS_PER_MARKER bits in the full marker mask.

	static const int AGOT_MAX_FULL_MARKER_MASK = 255;

	static const int AGOT_MARKERS_PER_TERRAIN_VARIANT_INDEX_BIT = 1;
	static const int AGOT_TERRAIN_VARIANTS_COUNT_LOG2           = 2; // Number of bits (per region), needed to encode an index for one of the 4 terrain variants (base map included).
	static const int AGOT_DYNAMIC_TERRAIN_MARKERS_COUNT         = 2; // AGOT_MARKERS_PER_TERRAIN_VARIANT_INDEX_BIT*AGOT_TERRAIN_VARIANTS_COUNT_LOG2;

	static const float AGOT_DYNAMIC_TERRAIN_MAX_SMOOTH_BORDERS_CAMERA_Y = 300.0f;

	static const float AGOT_VERTEX_YEET_POSITION_Y = -20000.0f;
]]