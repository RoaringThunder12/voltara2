Includes = {
	"voltara_dragon/jomini/texture_decals_base.fxh"
	"voltara_dragon/jomini/portrait_user_data.fxh"
	# MOD(agot)
	"voltara_dragon/standardfuncsgfx.fxh"
	"voltara_dragon/agot_portrait_decal_data.fxh"
	"voltara_dragon/agot_markers.fxh"
	"voltara_dragon/agot_constants.fxh"
	"voltara_dragon/agot_utils.fxh"
	# END MOD
}

Code
[[
	// ============================================================================
	// THE DECAL-BUFFER READER for "MIP smuggling"
	// ============================================================================
	//
	// The game streams every character's decal list to the shader as one flat
	// buffer (DecalDataBuffer): 15 numbers per decal, DecalCount decals. Each
	// record tells us which textures the decal uses and its weight (the 0-1
	// strength slider that genes/script control).
	//
	// This file knows how to read that buffer and search it for the colour codes
	// defined in agot_markers.fxh. Everything here is at "file scope", which
	// means both vertex and pixel shaders can use it.
	//
	// If you want to add a new smuggled PORTRAIT effect, add a field to
	// AGOT_SSmuggledPortraitData and pick it up in AGOT_GatherSmuggledPortraitData()
	// below - that one search runs in the vertex shader and its results reach the
	// pixel shaders as varyings. For one-off lookups elsewhere use
	// AGOT_FindDecalByMask(). Do not write a new buffer loop from scratch
	// (rules at the "Decal-buffer walks" section).
	// ============================================================================

	//
	// Types
	//

	// The minimal cut of a decal record: which diffuse texture it uses + its weight.
	struct AGOT_SReducedDecalData
	{
		uint  DiffuseIndex;
		uint  RawWeight;
		float Weight;
	};

	// A wider cut for the centre-mask system (adds the normal/properties texture
	// indices). Still only 5 buffer reads instead of vanilla GetDecalData()'s 15.
	struct AGOT_SMaskedDecalData
	{
		uint  DiffuseIndex;
		uint  NormalIndex;
		uint  PropertiesIndex;
		uint  RawWeight;
		float Weight;
	};

	//
	// Constants
	//

	// Where each field sits inside a 15-number decal record.
	// SYNC WARNING: copied from vanilla's GetDecalData() in jomini/portrait_decals.fxh -
	// if a CK3 patch changes that function, these must be updated to match.
	static const int AGOT_VANILLA_DIFFUSE_INDEX_DECAL_DATA_OFFSET    = 0;
	static const int AGOT_VANILLA_NORMAL_INDEX_DECAL_DATA_OFFSET     = 1;
	static const int AGOT_VANILLA_PROPERTIES_INDEX_DECAL_DATA_OFFSET = 2;
	static const int AGOT_VANILLA_DIFFUSE_BLEND_DECAL_DATA_OFFSET    = 4;
	static const int AGOT_VANILLA_RAW_WEIGHT_DECAL_DATA_OFFSET       = 7;

	// Blend-mode values, from vanilla's jomini/texture_decals_base.fxh (same
	// SYNC WARNING as above). A gene template's `blend_modes { diffuse = ... }`
	// lands here verbatim, which lets two templates sharing ONE decal texture
	// be told apart in the shader - gene_dragon_fire_color tags its
	// "automatic" template with replace and its "custom" template with
	// multiply. On an invisible control decal the mode never blends anything,
	// so it is a free template id.
	static const uint AGOT_DECAL_BLEND_OVERLAY    = 0;
	static const uint AGOT_DECAL_BLEND_REPLACE    = 1;
	static const uint AGOT_DECAL_BLEND_HARD_LIGHT = 2;
	static const uint AGOT_DECAL_BLEND_MULTIPLY   = 3;

	//
	// Service
	//

	int AGOT_DecalIndexToDataOffset(int DecalIndex)
	{
		return DecalIndex * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;
	}

	uint AGOT_GetDiffuseDecalTextureIndex(int DecalIndex)
	{
		return PdxReadBuffer(DecalDataBuffer, AGOT_DecalIndexToDataOffset(DecalIndex) + AGOT_VANILLA_DIFFUSE_INDEX_DECAL_DATA_OFFSET);
	}

	uint AGOT_GetRawDecalWeight(int DecalIndex)
	{
		return PdxReadBuffer(DecalDataBuffer, AGOT_DecalIndexToDataOffset(DecalIndex) + AGOT_VANILLA_RAW_WEIGHT_DECAL_DATA_OFFSET);
	}

	int AGOT_GetDynamicTerrainMarkerDecalIndex(int MarkerIndex)
	{
		// This function assumes that:
		//   1. All dynamic terrain marker decals are always present in DecalDataBuffer before DecalCount index.
		//   2. Said decals are contiguous in the buffer and ordered according to their intended index.
		//   3. Said ordered contiguous block immediately precedes DecalCount position in the buffer
		//      (i.e. there are no active decals located after terrain markers in the buffer).

		int MinMarkerDecalIndex = DecalCount - AGOT_DYNAMIC_TERRAIN_MARKERS_COUNT;

		return MinMarkerDecalIndex + MarkerIndex;
	}

	uint AGOT_GetDynamicTerrainMarkerBits(int MarkerIndex)
	{
		int  MarkerDecalIndex = AGOT_GetDynamicTerrainMarkerDecalIndex(MarkerIndex);
		uint MarkerRawWeight  = AGOT_GetRawDecalWeight(MarkerDecalIndex);

		return AGOT_DecodeDataMaskFromDecalRawWeight(MarkerRawWeight);
	}

	AGOT_SReducedDecalData AGOT_GetReducedDecalData(int DataOffset)
	{
		// DecalDataBuffer access pattern is based on vanilla pixel shader's GetDecalData().

		AGOT_SReducedDecalData Data;

		Data.DiffuseIndex = PdxReadBuffer(DecalDataBuffer, DataOffset + AGOT_VANILLA_DIFFUSE_INDEX_DECAL_DATA_OFFSET);
		Data.RawWeight    = PdxReadBuffer(DecalDataBuffer, DataOffset + AGOT_VANILLA_RAW_WEIGHT_DECAL_DATA_OFFSET);
		Data.Weight       = float(Data.RawWeight) / AGOT_VANILLA_DATA_MAX_VALUE;

		return Data;
	}

	AGOT_SMaskedDecalData AGOT_GetMaskedDecalData(int DataOffset)
	{
		AGOT_SMaskedDecalData Data;

		Data.DiffuseIndex    = PdxReadBuffer(DecalDataBuffer, DataOffset + AGOT_VANILLA_DIFFUSE_INDEX_DECAL_DATA_OFFSET);
		Data.NormalIndex     = PdxReadBuffer(DecalDataBuffer, DataOffset + AGOT_VANILLA_NORMAL_INDEX_DECAL_DATA_OFFSET);
		Data.PropertiesIndex = PdxReadBuffer(DecalDataBuffer, DataOffset + AGOT_VANILLA_PROPERTIES_INDEX_DECAL_DATA_OFFSET);
		Data.RawWeight       = PdxReadBuffer(DecalDataBuffer, DataOffset + AGOT_VANILLA_RAW_WEIGHT_DECAL_DATA_OFFSET);
		Data.Weight          = float(Data.RawWeight) / AGOT_VANILLA_DATA_MAX_VALUE;

		return Data;
	}

	//
	// Interface
	//

	// Convert "mip 6 of the full 1024px texture" into the mip index the shader must
	// actually sample. Needed because lower texture-quality settings shrink the
	// texture the shader sees: on Ultra a 1024px decal's 16x16 image is mip 6, but
	// on a halved texture it is mip 5, and so on. This measures the texture and
	// compensates, so the codes are found on every graphics setting.
	float AGOT_MipLevelToLod(float MipLevel)
	{
		#ifndef PDX_OPENGL
			float3 TextureSize;
			DecalDiffuseArray._Texture.GetDimensions( TextureSize.x , TextureSize.y , TextureSize.z );
		#else
			ivec3 TextureSize = textureSize(DecalDiffuseArray, 0);
		#endif

		// log2(size) is 10 for 1024px, 9 for 512px, ... - the difference from 10
		// is how many mips the texture has "lost" to the quality setting.
		return MipLevel - (10.0f - log2(TextureSize.x));
	}

	// The LOD at which the 16x16 marker/mask mip lives on the current decal atlas.
	// Hoist this ONCE before a decal-buffer walk instead of recomputing it per decal.
	int AGOT_MarkerLod()
	{
		return int(AGOT_MipLevelToLod(AGOT_MARKER_MIP_LEVEL));
	}

	// Read the marker pixels of a decal's 16x16 marker image. The BOTTOM two
	// corners are never loaded - nothing reads them in either stage, and this
	// runs once per decal per walk.
	AGOT_SMarkerTexels AGOT_ExtractMarkerTexels(uint DiffuseIndex, int MarkerLod)
	{
		static const int MAX_MARKER_PIXEL_COORD = 15; // the marker mip is 16x16, so corners are at 0 and 15

		static const int2 TOP_LEFT_UV     = int2(0, 0);
		static const int2 TOP_RIGHT_UV    = int2(MAX_MARKER_PIXEL_COORD, 0);

		AGOT_SMarkerTexels MarkerTexels;
		MarkerTexels.TopLeftTexel     = AGOT_PdxTex2DArrayLoad(DecalDiffuseArray, int3(TOP_LEFT_UV, DiffuseIndex), MarkerLod);
		MarkerTexels.TopRightTexel    = AGOT_PdxTex2DArrayLoad(DecalDiffuseArray, int3(TOP_RIGHT_UV, DiffuseIndex), MarkerLod);
		MarkerTexels.BottomRightTexel = float4(0.0f, 0.0f, 0.0f, 0.0f);
		MarkerTexels.BottomLeftTexel  = float4(0.0f, 0.0f, 0.0f, 0.0f);

		return MarkerTexels;
	}

	AGOT_SMarkerTexels AGOT_ExtractMarkerTexels(uint DiffuseIndex)
	{
		return AGOT_ExtractMarkerTexels(DiffuseIndex, AGOT_MarkerLod());
	}

	// Sample one mask texel of a decal's mip-6 image on the array selected by DecalType.
	float3 AGOT_LoadDecalMaskTexel(uint DecalType, AGOT_SMaskedDecalData Data, int2 Texel, int Lod)
	{
		if (DecalType == DIFFUSE_DECAL)
			return AGOT_PdxTex2DArrayLoad(DecalDiffuseArray, int3(Texel, int(Data.DiffuseIndex)), Lod).rgb;
		else if (DecalType == NORMAL_DECAL)
			return AGOT_PdxTex2DArrayLoad(DecalNormalArray, int3(Texel, int(Data.NormalIndex)), Lod).rgb;
		else
			return AGOT_PdxTex2DArrayLoad(DecalPropertiesArray, int3(Texel, int(Data.PropertiesIndex)), Lod).rgb;
	}

	// Local, not the engine RGBtoHSV / HSVtoRGB: vanilla uses those but ships no
	// definition of them, so their hue convention cannot be checked. Hue is 0-1.
	float3 AGOT_RgbToHsv(float3 C)
	{
		float4 K = float4(0.0f, -1.0f / 3.0f, 2.0f / 3.0f, -1.0f);
		float4 P = lerp(float4(C.bg, K.wz), float4(C.gb, K.xy), step(C.b, C.g));
		float4 Q = lerp(float4(P.xyw, C.r), float4(C.r, P.yzx), step(P.x, C.r));
		float D = Q.x - min(Q.w, Q.y);
		const float E = 1e-10f;
		return float3(abs(Q.z + (Q.w - Q.y) / (6.0f * D + E)), D / (Q.x + E), Q.x);
	}

	float3 AGOT_HsvToRgb(float3 C)
	{
		float4 K = float4(1.0f, 2.0f / 3.0f, 1.0f / 3.0f, 3.0f);
		float3 P = abs(frac(C.xxx + K.xyz) * 6.0f - K.www);
		return C.z * lerp(K.xxx, saturate(P - K.xxx), C.y);
	}

	// Repaint a shading decal instead of flooding it with a flat colour, so the
	// artwork can carry highlights and colour variation of its own.
	//
	// RED IS THE ANCHOR. The palette colour says where red lands and every other
	// hue rides the same rotation, so a cyan palette sends red to cyan, yellow to
	// blue and magenta to green - relative hue survives. Rotating by a whole
	// offset like this is safe; LERPING towards a hue is not, because hue is an
	// angle whose shortest arc reverses at a half turn (see PdxParticleApplyPalette).
	//
	// Saturation and value scale rather than replace, which keeps the artwork's
	// own shading and makes achromatic palette colours fall out for free: the
	// value term is gated on the texel's saturation, so a black palette colour
	// darkens the coloured parts to black while white highlights stay white.
	// Multiplicative saturation scale: 1.0 = the untouched colour, 0.0 = greyscale.
	// Runs in whatever space the caller hands it - the dragon palette path feeds it
	// GAMMA-space samples on purpose, because the customizer's GUI preview shader
	// (agot_customizer_gui.shader) applies the same scale to the same sRGB texture
	// sample, and the two must agree at every slider position.
	float3 AGOT_ScaleSaturation(float3 ColorRGB, float SaturationMultiplier)
	{
		float3 Hsv = AGOT_RgbToHsv(ColorRGB);
		Hsv.y *= SaturationMultiplier;
		return AGOT_HsvToRgb(Hsv);
	}

	float3 AGOT_TintDecalHue(float3 Sample, float3 Tint)
	{
		float3 Hsv = AGOT_RgbToHsv(Sample);
		float3 TintHsv = AGOT_RgbToHsv(Tint);

		float3 Out;
		Out.x = frac(Hsv.x + TintHsv.x);
		Out.y = Hsv.y * TintHsv.y;
		Out.z = Hsv.z * lerp(1.0f, TintHsv.z, Hsv.y);

		return saturate(AGOT_HsvToRgb(Out));
	}

	int AGOT_AvoidTerrainMarkerDecalIndices(int DecalIndex, bool IsDynamicTerrainLoaded)
	{
		int MinTerrainMarkerDecalIndex = DecalCount - AGOT_DYNAMIC_TERRAIN_MARKERS_COUNT;

		// This is a workaround for bookmark characters having broken decals.
		if (!IsDynamicTerrainLoaded)
			return DecalIndex;

		// We're allowing min marker index, since that corresponds
		// to vanilla logic for PreSkinColorDecalCount in calls to AddDecals().
		return min(DecalIndex, MinTerrainMarkerDecalIndex);
	}

	bool AGOT_AreTerrainMarkerDecalsLoaded()
	{
		// While we're in game, we expect the last decal in the buffer to always be a terrain marker.
		// If this isn't the case, we assume terrain markers are not available (this is the case for bookmark screen, for example),
		// which means we shouldn't try skipping over terrain marker decal index range (see AGOT_AvoidTerrainMarkerDecalIndices()).

		uint LastDecalDiffuseIndex = AGOT_GetDiffuseDecalTextureIndex(DecalCount - 1);

		AGOT_SMarkerTexels MarkerTexels = AGOT_ExtractMarkerTexels(LastDecalDiffuseIndex);

		return AGOT_ColorAlmostEquals(MarkerTexels.TopLeftTexel, AGOT_MARKER_TOP_LEFT_MAP_TERRAIN);
	}

	void AGOT_GetNonTerrainDecalDataTexelRange(out int FromDataTexel, out int ToDataTexel)
	{
		int From = 0;
		int To   = AGOT_AvoidTerrainMarkerDecalIndices(DecalCount, true);

		// ToDataTexel is one-past-the-last walkable position,
		// so loops over this range must use `i < ToDataTexel`.
		FromDataTexel = From * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;
		ToDataTexel   = To   * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;
	}

	//
	// Decal-buffer walks
	//
	// These are the ONLY functions that should loop over DecalDataBuffer looking
	// for smuggled codes. If you add a new walk, follow the same rules:
	//   - step by AGOT_VANILLA_TEXEL_COUNT_PER_DECAL, never a hardcoded number;
	//   - loop while `i < DecalCount * step` (going one past the end reads garbage);
	//   - call AGOT_MarkerLod() once before the loop, not once per decal;
	//   - check the record is in use (DiffuseIndex < AGOT_VANILLA_DATA_MAX_VALUE)
	//     before sampling any texture with it.
	//

	// Search the character's decals for the MatchIndex-th one tagged with DecalMask
	// (MatchIndex 0 = first tagged decal, 1 = second, ...). Returns an all-zero
	// record when nothing matches, so callers can treat Weight == 0 as "not found".
	//
	// IsDynamicTerrainLoaded is accepted but currently unused: the reserved
	// terrain-marker decals at the end of the buffer never match these colour tags
	// in practice, so the walk does not bother skipping them.
	AGOT_SMaskedDecalData AGOT_FindDecalByMask(float3 DecalMask, uint DecalType, int MatchIndex, bool IsDynamicTerrainLoaded = true)
	{
		int MatchCount  = 0;
		int MaskLod     = AGOT_MarkerLod();
		int ToDataTexel = DecalCount * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;

		AGOT_LOOP
		for (int i = 0; i < ToDataTexel; i += AGOT_VANILLA_TEXEL_COUNT_PER_DECAL)
		{
			AGOT_SMaskedDecalData Data = AGOT_GetMaskedDecalData(i);

			if (Data.DiffuseIndex >= AGOT_VANILLA_DATA_MAX_VALUE)
				continue;

			float3 MaskSample = AGOT_LoadDecalMaskTexel(DecalType, Data, AGOT_MASK_TEXEL_CONTROL, MaskLod);

			if (AGOT_ColorAlmostEquals(MaskSample, DecalMask))
			{
				if (MatchCount == MatchIndex)
					return Data;

				MatchCount++;
			}
		}

		AGOT_SMaskedDecalData EmptyData;
		EmptyData.DiffuseIndex    = 0;
		EmptyData.NormalIndex     = 0;
		EmptyData.PropertiesIndex = 0;
		EmptyData.RawWeight       = 0;
		EmptyData.Weight          = 0.0f;
		return EmptyData;
	}

	// All the smuggled per-character values the portrait pixel shaders use,
	// gathered in ONE pass over the decal buffer.
	//
	// Run this in the VERTEX shader and pass the results down as varyings
	// (see VS_standard in jomini/portrait.shader / court_scene.shader): the
	// values are identical for every pixel of a character, so searching the
	// buffer per pixel - hundreds of thousands of times - would be wasted work.
	struct AGOT_SSmuggledPortraitData
	{
		float SkinPaletteWeight;   // MAGENTA control: skin -> hair palette blend
		float DecayWeight;         // RED control: clothing wear/dirt/rust strength
		uint  DecayDiffuseIndex;   // RED control: which texture holds the decay masks
		float HairAgingWeight;     // GREEN control: salt-n-pepper hair
	};

	AGOT_SSmuggledPortraitData AGOT_GatherSmuggledPortraitData()
	{
		AGOT_SSmuggledPortraitData Result;
		Result.SkinPaletteWeight = 0.0f;
		Result.DecayWeight       = 0.0f;
		Result.DecayDiffuseIndex = 0;
		Result.HairAgingWeight   = 0.0f;

		bool FoundMagenta = false;
		bool FoundRed     = false;
		bool FoundGreen   = false;

		int MaskLod     = AGOT_MarkerLod();
		int ToDataTexel = DecalCount * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;

		AGOT_LOOP
		for (int i = 0; i < ToDataTexel; i += AGOT_VANILLA_TEXEL_COUNT_PER_DECAL)
		{
			AGOT_SMaskedDecalData Data = AGOT_GetMaskedDecalData(i);

			if (Data.DiffuseIndex >= AGOT_VANILLA_DATA_MAX_VALUE)
				continue;

			float3 Control = AGOT_LoadDecalMaskTexel(DIFFUSE_DECAL, Data, AGOT_MASK_TEXEL_CONTROL, MaskLod);

			if (!FoundMagenta && AGOT_ColorAlmostEquals(Control, AGOT_MASK_MAGENTA))
			{
				Result.SkinPaletteWeight = Data.Weight;
				FoundMagenta = true;
			}
			else if (!FoundRed && AGOT_ColorAlmostEquals(Control, AGOT_MASK_RED))
			{
				Result.DecayWeight       = Data.Weight;
				Result.DecayDiffuseIndex = Data.DiffuseIndex;
				FoundRed = true;
			}
			else if (!FoundGreen && AGOT_ColorAlmostEquals(Control, AGOT_MASK_GREEN))
			{
				Result.HairAgingWeight = Data.Weight;
				FoundGreen = true;
			}

			// Everything found - no point reading the rest of the buffer.
			if (FoundMagenta && FoundRed && FoundGreen)
				break;
		}

		return Result;
	}

	// Sum the weights of all camera-zoom / camera-raise marker decals.
	// x = zoom amount, y = raise amount. Called from the portrait vertex shader
	// via cw/agot_camera.fxh, so this must stay at file scope.
	float2 AGOT_GetCameraZoomFromMarkerDecals()
	{
		float2 ZoomHeight = float2(0.0f, 0.0f);

		int MarkerLod   = AGOT_MarkerLod();
		int ToDataTexel = DecalCount * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;

		AGOT_LOOP
		for (int i = 0; i < ToDataTexel; i += AGOT_VANILLA_TEXEL_COUNT_PER_DECAL)
		{
			AGOT_SReducedDecalData Data = AGOT_GetReducedDecalData(i);

			if (Data.DiffuseIndex >= AGOT_VANILLA_DATA_MAX_VALUE || Data.RawWeight == 0)
				continue;

			AGOT_SMarkerTexels MarkerTexels = AGOT_ExtractMarkerTexels(Data.DiffuseIndex, MarkerLod);
			if (AGOT_CheckMarkerTexels(MarkerTexels, AGOT_MARKER_TOP_LEFT_DECAL, AGOT_MARKER_TOP_RIGHT_DECAL_CAMERA_ZOOM))
				ZoomHeight.x += Data.Weight;

			if (AGOT_CheckMarkerTexels(MarkerTexels, AGOT_MARKER_TOP_LEFT_DECAL, AGOT_MARKER_TOP_RIGHT_DECAL_CAMERA_RAISE))
				ZoomHeight.y += Data.Weight;
		}

		return ZoomHeight;
	}
]]
