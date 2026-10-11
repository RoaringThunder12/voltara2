# THIS IS A GENERATED FILE!
#
# Source template:
# ~DevFolders\DynamicTerrain\templates\gfx\FX\agot_dynamic_terrain_textures.fxh.jinja
#
# Please avoid making changes here directly, as they will get overwritten next time this file is regenerated.
# Instead edit the source template and/or variables it's based on, then regenerate it via render_templates.py .

#
# Textures
#

TextureSampler AGOT_DynamicTerrainRegionsMap
{
	Index = 31
	MagFilter = "Point"
	MinFilter = "Point"
	MipFilter = "Point"
	SampleModeU = "Clamp"
	SampleModeV = "Clamp"
	File = "map_data/agot_dynamic_terrain_regions.png"
}

TextureSampler AGOT_DynamicTerrainAdjacencyMap
{
	Index = 32
	MagFilter = "Point"
	MinFilter = "Point"
	MipFilter = "Point"
	SampleModeU = "Clamp"
	SampleModeV = "Clamp"
	File = "map_data/agot_dynamic_terrain_adjacency.png"
}

TextureSampler AGOT_DynamicTerrainProximityMap
{
	Index = 33
	MagFilter = "Linear"
	MinFilter = "Linear"
	MipFilter = "Linear"
	SampleModeU = "Clamp"
	SampleModeV = "Clamp"
	File = "map_data/agot_dynamic_terrain_proximity.png"
}

PixelShader =
{
	#
	# Textures
	#

	# Terrain variant textures start at 1 because 0 refers to default (base map) terrain
	# i.e. to DetailIndexTexture and DetailMaskTexture in pdxterrain.fxh .
	TextureSampler AGOT_TerrainVariantIndexTexture3
	{
		Index = 34
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		File = "gfx/map/terrain/agot_detail_index_arctic.png"
	}

	TextureSampler AGOT_TerrainVariantMaskTexture3
	{
		Index = 35
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		File = "gfx/map/terrain/agot_detail_intensity_arctic.png"
	}
	

	Code [[
		//
		// Macros
		//

		#define AGOT_MACRO_FOR_EACH_NON_DEFAULT_TERRAIN_VARIANT_INDEX(MACRO)\
			MACRO(3)

		//
		// Interface
		//

		float4 AGOT_TerrainVariantIndexPdxTex2D(int TerrainVariantIndex, PdxTextureSampler2D DefaultTexture, float2 UV)
		{
			#define AGOT_CASE_TERRAIN_VARIANT_INDEX_TEX_2D(INDEX) case INDEX: return PdxTex2D(AGOT_TerrainVariantIndexTexture##INDEX, UV);

			switch (TerrainVariantIndex)
			{
				default: return PdxTex2D(DefaultTexture, UV);
				AGOT_MACRO_FOR_EACH_NON_DEFAULT_TERRAIN_VARIANT_INDEX(AGOT_CASE_TERRAIN_VARIANT_INDEX_TEX_2D)
			}

			#undef AGOT_CASE_TERRAIN_VARIANT_INDEX_TEX_2D
		}

		float4 AGOT_TerrainVariantMaskPdxTex2D(int TerrainVariantIndex, PdxTextureSampler2D DefaultTexture, float2 UV)
		{
			#define AGOT_CASE_TERRAIN_VARIANT_MASK_TEX_2D(INDEX) case INDEX: return PdxTex2D(AGOT_TerrainVariantMaskTexture##INDEX, UV);

			switch (TerrainVariantIndex)
			{
				default: return PdxTex2D(DefaultTexture, UV);
				AGOT_MACRO_FOR_EACH_NON_DEFAULT_TERRAIN_VARIANT_INDEX(AGOT_CASE_TERRAIN_VARIANT_MASK_TEX_2D)
			}

			#undef AGOT_CASE_TERRAIN_VARIANT_MASK_TEX_2D
		}

		float4 AGOT_TerrainVariantIndexPdxTex2DLod0(int TerrainVariantIndex, PdxTextureSampler2D DefaultTexture, float2 UV)
		{
			#define AGOT_CASE_TERRAIN_VARIANT_INDEX_TEX_2D_LOD0(INDEX) case INDEX: return PdxTex2DLod0(AGOT_TerrainVariantIndexTexture##INDEX, UV);

			switch (TerrainVariantIndex)
			{
				default: return PdxTex2DLod0(DefaultTexture, UV);
				AGOT_MACRO_FOR_EACH_NON_DEFAULT_TERRAIN_VARIANT_INDEX(AGOT_CASE_TERRAIN_VARIANT_INDEX_TEX_2D_LOD0)
			}

			#undef AGOT_CASE_TERRAIN_VARIANT_INDEX_TEX_2D_LOD0
		}

		float4 AGOT_TerrainVariantMaskPdxTex2DLod0(int TerrainVariantIndex, PdxTextureSampler2D DefaultTexture, float2 UV)
		{
			#define AGOT_CASE_TERRAIN_VARIANT_MASK_TEX_2D_LOD0(INDEX) case INDEX: return PdxTex2DLod0(AGOT_TerrainVariantMaskTexture##INDEX, UV);

			switch (TerrainVariantIndex)
			{
				default: return PdxTex2DLod0(DefaultTexture, UV);
				AGOT_MACRO_FOR_EACH_NON_DEFAULT_TERRAIN_VARIANT_INDEX(AGOT_CASE_TERRAIN_VARIANT_MASK_TEX_2D_LOD0)
			}

			#undef AGOT_CASE_TERRAIN_VARIANT_MASK_TEX_2D_LOD0
		}
	]]
}