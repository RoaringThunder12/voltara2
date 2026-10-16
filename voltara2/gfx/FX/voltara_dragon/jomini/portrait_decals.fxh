includes = {
	"voltara_dragon/jomini/texture_decals_base.fxh"
	"voltara_dragon/jomini/portrait_user_data.fxh"
	# MOD(agot)
	"voltara_dragon/standardfuncsgfx.fxh"
	"voltara_dragon/agot_portrait_decals_shared.fxh"
	"voltara_dragon/agot_constants.fxh"
	"voltara_dragon/agot_utils.fxh"
	# END MOD
}

PixelShader =
{
	# MOD(agot)
	# Vanilla's DecalDiffuseArray/DecalNormalArray/DecalPropertiesArray samplers and the
	# DecalDataBuffer live in agot_portrait_decal_data.fxh (file scope, so vertex shaders can
	# read them too). Keep that file in sync with vanilla on patches. 
	# END MOD

	Code
	[[		
		// MOD(agot)
		// The colour codes (AGOT_MASK_*) and the decal-searching helpers
		// (AGOT_FindDecalByMask etc.) live in agot_markers.fxh and
		// agot_portrait_decals_shared.fxh. This file keeps vanilla's decal
		// blending plus our per-decal decode passes (DecodeDiffuseMIPs,
		// DecodePropertiesMIPs) and the dragon decal system.

		#define SKIN uint(0)
		#define EYE uint(1)
		#define HAIR uint(2)

		// Dragon colour-pipeline debug views. DIAGNOSTIC ONLY.
		// Toggle from the console with shader_debug (hot-reloads, no cache purge):
		//   shader_debug AGOT_DEBUG_DRAGON_VIEW_1
		// or uncomment one #define below and purge the shadercache.
		// For measurable output the portrait environment must be neutral: exposure 1.0,
		// tonemap_function "None", bloom_enabled no, ssao enabled no - then
		// screenshot_sRGB = pow(shown_value, 1/2.2) exactly.
		//
		//   _1 = raw DiffuseMap sample (the body texture as the GPU hands it to the shader)
		//   _2 = raw DecalDiffuseArray sample where a pattern decal covers (magenta = no decal)
		//   _3 = decoded DragonTertiaryColor (flat over the whole body)
		//   _4 = decoded DragonSecondaryColor
		//   _5 = AGOT_TintDecalHue(decal, tint) result (should equal _2 for a pure-red tint)
		//   _6 = final ColorPalette, the factor multiplied into the diffuse
		//   _7 = effective decal opacity, DecalSample.a * Weight, as greyscale (mip thinning
		//        shows up as this dropping when you zoom out)
		//   _8 = raw ColorMask (SSAOColorMap) sample
		//   _9 = constant (0.5, 0.25, 0.125) - calibrates the output chain: with the neutral
		//        environment the screenshot must pick (186, 136, 99); anything else means the
		//        display side is not neutral and the other views need that correction factored out
		//  _10 = DecalUV of the last pattern decal as colour (R=U, G=V)
		//  _11 = mesh UV0 as colour (R=U, G=V); subtracting _10 exposes any atlas/offset shift
		//        between where the decal is sampled and where the mesh point sits in the texture
		//  _12 = the smuggled tertiary palette coordinate (R=X, G=Y) - invert the display chain
		//        and that is the exact UV being read from the palette texture
		//  _13 = like _2 but ONLY the overlay-blend (tertiary) decal - the body-shading decal
		//        shares the tint path and contaminates _2/_5/_7 wherever the pattern is thin
		//  _14 = like _13 but captures the FIRST overlay decal instead of the last; if _13 and
		//        _14 differ, TWO overlay decals are in the buffer (e.g. a tertiary shading decal)
		//#define AGOT_DEBUG_DRAGON_VIEW_1
		#if defined( AGOT_DEBUG_DRAGON_VIEW_1 ) || defined( AGOT_DEBUG_DRAGON_VIEW_2 ) || defined( AGOT_DEBUG_DRAGON_VIEW_3 ) || defined( AGOT_DEBUG_DRAGON_VIEW_4 ) || defined( AGOT_DEBUG_DRAGON_VIEW_5 ) || defined( AGOT_DEBUG_DRAGON_VIEW_6 ) || defined( AGOT_DEBUG_DRAGON_VIEW_7 ) || defined( AGOT_DEBUG_DRAGON_VIEW_8 ) || defined( AGOT_DEBUG_DRAGON_VIEW_9 ) || defined( AGOT_DEBUG_DRAGON_VIEW_10 ) || defined( AGOT_DEBUG_DRAGON_VIEW_11 ) || defined( AGOT_DEBUG_DRAGON_VIEW_12 ) || defined( AGOT_DEBUG_DRAGON_VIEW_13 ) || defined( AGOT_DEBUG_DRAGON_VIEW_14 )
		#define AGOT_DEBUG_DRAGON_VIEW_ANY
		static float4 AGOT_DragonDebug = float4(1.0f, 0.0f, 1.0f, 0.0f); // a=0: nothing recorded yet
		#endif
		// END MOD

		// MOD(agot)
		// Vanilla's struct DecalData was extracted into agot_portrait_decal_data.fxh so it is
		// shared between pixel and vertex shaders. Merge vanilla patch changes there.
		// END MOD

		DecalData GetDecalData( int Index )
		{
			// Data for each decal is stored in multiple texels as specified by DecalData

			DecalData Data;

			Data._DiffuseIndex = PdxReadBuffer( DecalDataBuffer, Index );
			Data._NormalIndex = PdxReadBuffer( DecalDataBuffer, Index + 1 );
			Data._PropertiesIndex = PdxReadBuffer( DecalDataBuffer, Index + 2 );
			Data._BodyPartIndex = PdxReadBuffer( DecalDataBuffer, Index + 3 );

			Data._DiffuseBlendMode = PdxReadBuffer( DecalDataBuffer, Index + 4 );
			Data._NormalBlendMode = PdxReadBuffer( DecalDataBuffer, Index + 5 );
			if ( Data._NormalBlendMode == BLEND_MODE_OVERLAY )
			{
				Data._NormalBlendMode = BLEND_MODE_OVERLAY_NORMAL;
			}
			Data._PropertiesBlendMode = PdxReadBuffer( DecalDataBuffer, Index + 6 );
			Data._Weight = Unpack16BitUnorm( PdxReadBuffer( DecalDataBuffer, Index + 7 ) );

			Data._AtlasPos = uint2( PdxReadBuffer( DecalDataBuffer, Index + 8 ), PdxReadBuffer( DecalDataBuffer, Index + 9 ) );
			Data._UVOffset = float2( Unpack16BitUnorm( PdxReadBuffer( DecalDataBuffer, Index + 10 ) ), Unpack16BitUnorm( PdxReadBuffer( DecalDataBuffer, Index + 11 ) ) );
			Data._UVTiling = uint2( PdxReadBuffer( DecalDataBuffer, Index + 12 ), PdxReadBuffer( DecalDataBuffer, Index + 13 ) );

			Data._AtlasSize = PdxReadBuffer( DecalDataBuffer, Index + 14 );

			return Data;
		}

		// MOD(agot)
		void RGBA_To_Atlas(inout float4 Decal, inout float Weight )
		{
			//Below If statements normalize the weight value to 0.0 - 1.0 then tells which channel to use as alpha at increments of 25%.
			if (Weight < 0.25f)
			{
			Weight = Weight * 4.0f;
			Decal.a = Decal.r;
			}

			else if (Weight >= 0.25f && Weight < 0.5f)
			{
			Weight = (Weight - 0.25f) * 4.0f;
			Decal.a = Decal.g;
			}

			else if (Weight >= 0.5f && Weight < 0.75f)
			{
			Weight = (Weight - 0.5f) * 4.0f;
			Decal.a = Decal.b;
			}

			else
			{
			Weight = (Weight - 0.75f) * 4.0f;
			}
		}
		// END MOD

	//////////////////////////////////////////////////////////////////////////////
/////////////////////////			DECODE MIPS			///////////////////////////////
	//////////////////////////////////////////////////////////////////////////////

		// MaskLod is hoisted by the caller (one AGOT_MarkerLod() per decal walk, not one per decal).
		void DecodeDiffuseMIPs( uint InstanceIndex, inout float4 Sample, float2 UV , inout DecalData Data, inout float4x4 WeightMatrix , int CustomBodyPart, int MaskLod )
		{

			//  MIP6 of a typical decal 1024x1024 texture is a 16x16px texture.
			//  We "smuggle" data into the mip map by colouring in 4x4 px blocks a certain colour and later sample specific coordinate for a specific colour.
			//  This gives us 16 unique "bits" to sample from. 4x4 cells are due to DDS compression algorithms which work in blocks of 4 pixels.
			//  We can then use that decals weight to apply various shader effect.
			//	Below is a visual representation/guide of a MIP6 texture along with sampling coordinates for reference."+" Symbolizes the actual pixel being sampled.
			//
			//       _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ 
			//  0,0 |  1,1  |  5,1  |  9,1  |  13,1 | 15,0
			//      |  +    |  +    |  +    |  +    |
			//      |       |       |       |       |
			//      |_ _ _ _|_ _ _ _|_ _ _ _|_ _ _ _|
			//      |  1,5  |  5,5  |  9,5  |  13,5 |
			//      |  +    |  +    |  +    |  +    |
			//      |       |       |       |       |
			//      |_ _ _ _|_ _ _ _|_ _ _ _|_ _ _ _|
			//      |  1,9  |  5,9  |  9,9  |  13,9 |
			//      |  +    |  +    |  +    |  +    |
			//      |       |       |       |       |
			//      |_ _ _ _|_ _ _ _|_ _ _ _|_ _ _ _|
			//      |  1,13 |  5,13 |  9,13 | 13,13 |
			//      |  +    |  +    |  +    |  +    |
			//      |       |       |       |       |
			// 0,15 |_ _ _ _|_ _ _ _|_ _ _ _|_ _ _ _| 15,15

			
			///////// 1,1 SAMPLE (TOP LEFT BLOCK)/////////
            /////////////// CONTROL DECALS ///////////////

			// These are normally not actually displayed on the mesh. Most of the time alpha is set to 0 on the decal texture if it is only a marker texture.
			// If we do want to use that decal weight for some skin decal like body hair colour selection or facepaint colour selection then we store the weight into the weight matrix below.
			// Sometimes we do want to use the texture data for something so we force the texture weight to 0.0 below so it does not get rendered.

			// float3 (1.0f,0.0f,0.0f) - CLOTHES DECAY CONTROL
			// float3 (0.0f,1.0f,0.0f) - SALT AND PEPPER HAIR CONTROL
			// float3 (0.0f,0.0f,1.0f) - FACEPAINT SELECTION DECAL
			// float3 (0.0f,1.0f,1.0f) - ATTACHMENT PATTERN PALETTE SELECTION (OBSOLETE)
			// float3 (1.0f,0.0f,1.0f) - FUR COLOUR TRANSITION (legacy, unused in AGOT)
			// float3 (0.5f,0.0f,0.0f) - BODY HAIR COLOUR SELECTION
			// float3 (1.0f,1.0f,0.0f) - SKELETON TRANSITION EFFECT - HEAD (legacy, unused in AGOT)
			// float3 (0.0f,0.5f,0.0f) - SKELETON TRANSITION EFFECT - BODY (legacy, unused in AGOT)
			// float3 (0.0f,0.0f,0.5f) - DRAGON COLOR PALETTE MARKER

			float3 DecalMIP6_1_1_Sample = AGOT_PdxTex2DArrayLoad( DecalDiffuseArray, int3(1, 1, int(InstanceIndex)), MaskLod).rgb;

			// CLOTHES DECAY CONTROL
			if (AGOT_ColorAlmostEquals(DecalMIP6_1_1_Sample, AGOT_MASK_RED))
			{			
				WeightMatrix[0][0] = 0.0f;
				return;
			}

			if (AGOT_ColorAlmostEquals(DecalMIP6_1_1_Sample, AGOT_MASK_GREEN))
			{			
				WeightMatrix[0][0] = 0.0f;
				return;
			}

			// FACEPAINT SELECTION DECAL
			if (AGOT_ColorAlmostEquals(DecalMIP6_1_1_Sample, AGOT_MASK_BLUE))
			{	
			WeightMatrix[0][0] = 0.0f;		
			WeightMatrix[0][1] = Data._Weight;
			return;
			}			

			//BODY HAIR COLOR SELECTION
			else if (AGOT_ColorAlmostEquals(DecalMIP6_1_1_Sample,AGOT_MASK_HALF_RED))
			{	
			WeightMatrix[0][0] = 0.0f;		
			WeightMatrix[0][2] = Data._Weight;
			return;
			}		
	
			//DRAGON COLOR MARKER
			else if (AGOT_ColorAlmostEquals(DecalMIP6_1_1_Sample, AGOT_MASK_HALF_BLUE))
			{	
			WeightMatrix[0][0] = 0.0f;		
			return;
			}	
	

			///////// 5,1 SAMPLE (2ND ROW, 1ST COLUMN CELL)/////////
            ////////////////// CUSTOM BODY PARTS //////////////////

			float3 DecalMIP6_5_1_Sample = AGOT_PdxTex2DArrayLoad( DecalDiffuseArray, int3(5, 1, int(InstanceIndex)), MaskLod).rgb;

			//float3 (1.0f,0.0f,0.0f) - DRAGON BODY
			//float3 (0.0f,1.0f,0.0f) - EYE DECAL
			//float3 (0.0f,0.0f,1.0f) - DRAGON WINGS
			//float3 (1.0f,1.0f,0.0f) - DRAGON HORNS
			//float3 (0.0f,1.0f,1.0f) - DRAGON EYES

			//This sets custom body parts. At 0 decals are applied like normal.
			//If set at anything other than 0 it will override where the decal is supposed to show

			//If not using a custom body part, but decal is encoded to display only on custom body parts list above, hide the decal.
			if (CustomBodyPart == 0)
			{
				if (AGOT_ColorAlmostEquals(DecalMIP6_5_1_Sample, AGOT_MASK_GREEN))
				{			
					WeightMatrix[0][0] = 0.0f;
					return;
				}

				//Ignore dragon decals
				else if (AGOT_ColorAlmostEquals(DecalMIP6_5_1_Sample, AGOT_MASK_RED))
				{			
					WeightMatrix[0][0] = 0.0f;
					return;
				}

				else if (AGOT_ColorAlmostEquals(DecalMIP6_5_1_Sample, AGOT_MASK_BLUE))
				{			
					WeightMatrix[0][0] = 0.0f;
					return;
				}

				else if (AGOT_ColorAlmostEquals(DecalMIP6_5_1_Sample,AGOT_MASK_YELLOW))
				{			
					WeightMatrix[0][0] = 0.0f;
					return;
				}

				else if (AGOT_ColorAlmostEquals(DecalMIP6_5_1_Sample,AGOT_MASK_CYAN))
				{			
					WeightMatrix[0][0] = 0.0f;
					return;
				}
			}

			//If using custom body part, and the decal encoding matches the body part in the list, display the decal.
			else if (CustomBodyPart == BODYPART_EYES)
			{
				if (AGOT_ColorAlmostEquals(DecalMIP6_5_1_Sample, AGOT_MASK_GREEN))
				{			
					WeightMatrix[0][0] = Data._Weight ;
				}

				// Else if using custom body part, but the decal encoding doesn't match, hide decals.
				else
				{
					WeightMatrix[0][0] = 0.0f;
					return;
				}
			}


/////////////////////////// CUSTOM UV MAPPING AND CHANNEL SPLITTING //////////////////////////////////			
			//Sample bottom left corner pixel of decal MIP5.
			//Used to tell the shader how to split the decal:
			//R - SPLIT INTO 4 DECALS THAT CHANGE EVERY 25% USING RGBA AS MASKS
			//G - BLANK
			//B - BLANK
			float3 DecalMIP6_9_1_Sample = AGOT_PdxTex2DArrayLoad( DecalDiffuseArray, int3(9, 1, int(InstanceIndex)), MaskLod).rgb;

			// If bottom left corner pixel is RED - Split into 4 decals every 25% of weight slider masked by channel
			if ( AGOT_ColorAlmostEquals(DecalMIP6_9_1_Sample, AGOT_MASK_RED))
			{
				RGBA_To_Atlas(Sample, WeightMatrix[0][0] );
			}


/////////////////////////// CUSTOM COLOUR OVERRIDES //////////////////////////////////	

			//Sample top right corner pixel of decal MIP5.
			//For overwriting color of decal 
			//R - OVERRIDE COLOUR BY SAMPLING A COLOUR PALETTE, CHANGES COLOUR WITH WEIGHT OF DECAL - SETS WEIGHT TO 100%
			//G - OVERRIDE COLOUR TO CURRENT SKIN COLOUR PALETTE
			//B - OVERRIDE COLOUR TO CURRENT HAIR COLOUR PALETTE
			//Y - OVERRIDE COLOUR TO CURRENT EYE COLOUR PALETTE
			//C - OVERRIDE COLOUR BY SAMPLING TOP LEFT CORNER OF MIP WHICH STORES A COLOUR PALETTE, CHANGES COLOUR WITH WEIGHT OF DECAL - KEEPS WEIGHT AS IS (ALLOWS ADJUSTING TRASPARENCY)
			//M - REPLACES DECAL COLOR WITH SAMPLED PALETTE AND SETS OPACITY TO 100%
			//float3 (0.5f,0.0f,0.0f) - BODY HAIR DECAL COLOUR CHANGE
			
			float3 DecalMIP6_13_1_Sample = AGOT_PdxTex2DArrayLoad( DecalDiffuseArray, int3(13, 1, int(InstanceIndex)), MaskLod).rgb;

			// If top right corner pixel is RED - REPLACES DECAL COLOR WITH SAMPLED PALETTE FROM TOP LEFT OF THE DECAL AND SETS OPACITY TO 100%  - USE ANOTHER DECAL TO CONTROL THE STRENGTH
			if ( AGOT_ColorAlmostEquals(DecalMIP6_13_1_Sample, AGOT_MASK_RED))
			{
				//Sample top left corner pixels of the image MIP5 as makeshift color palette for the facepaint, then apply that color and the correct alpha and set Weight (transperancy to 100%)
				float3 DecalPaletteColor = AGOT_PdxTex2DArrayLoad( DecalDiffuseArray, int3(int(WeightMatrix[0][1]*16), 13, int(InstanceIndex)), MaskLod).rgb;
				Sample.rgb = DecalPaletteColor;
				WeightMatrix[0][0] = 1.0f;
			}

			// If top right corner pixel is GREEN - REPLACES DECAL COLOR WITH SKIN COLOR,
			else if ( AGOT_ColorAlmostEquals(DecalMIP6_13_1_Sample, AGOT_MASK_GREEN))
			{
				Sample.rgb = vPaletteColorSkin.rgb;
			}

			// If top right corner pixel is BLUE - REPLACES DECAL COLOR WITH HAIR COLOR
			else if ( AGOT_ColorAlmostEquals(DecalMIP6_13_1_Sample, AGOT_MASK_BLUE))
			{
				Sample.rgb = vPaletteColorHair.rgb;
			}

			// If top right corner pixel is YELLOW - REPLACES DECAL COLOR WITH EYE COLOR
			else if ( AGOT_ColorAlmostEquals(DecalMIP6_13_1_Sample, AGOT_MASK_YELLOW))
			{
				Sample.rgb = vPaletteColorEyes.rgb;
			}

			// If top right corner pixel is CYAN - REPLACES DECAL COLOR WITH SAMPLED COLOR FROM BOTTOM LEFT OF THE MIP6 AND LEAVE OPACITY NORMALISED PER DECAL
			else if ( AGOT_ColorAlmostEquals(DecalMIP6_13_1_Sample, AGOT_MASK_CYAN))
			{
				//Sample bottom left corner pixels of the image as color for the decal, then apply that color
				float3 DecalPaletteColor = AGOT_PdxTex2DArrayLoad( DecalDiffuseArray, int3(1, 13, int(InstanceIndex)), MaskLod).rgb;
				Sample.rgb = DecalPaletteColor;
			}

			// If top right corner pixel is MAGENTA - REPLACES DECAL COLOR WITH SAMPLED PALETTE FROM TOP LEFT OF THE DECAL AND SETS OPACITY TO 100%
			else if ( AGOT_ColorAlmostEquals(DecalMIP6_13_1_Sample, AGOT_MASK_MAGENTA))
			{

				//Sample top left corner pixels of the image MIP6 as makeshift color palette for the facepaint, then apply that color and the correct alpha and set Weight (transperancy to 100%)
				float3 DecalPaletteColor = AGOT_PdxTex2DArrayLoad( DecalDiffuseArray, int3(int(WeightMatrix[0][1]*16), 13, int(InstanceIndex)), MaskLod).rgb;
				Sample.rgb = DecalPaletteColor;
				WeightMatrix[0][0] = 1.0f;
			}

			// Interpolates between a black and hair colour, for body/facial hair decals.
			else if ( AGOT_ColorAlmostEquals(DecalMIP6_13_1_Sample,AGOT_MASK_HALF_RED))
			{
				Sample.rgb = lerp (lerp(vPaletteColorHair.rgb, vPaletteColorHair.rgb*vPaletteColorSkin.rgb, 0.8f), float3(0.0f,0.0f,0.0f), WeightMatrix[0][2]);
			}


/////////////////////////// CUSTOM BLEND MODES //////////////////////////////////	

			//Sample bottom right corner pixel of decal MIP5.
			//For assigning custom blendmodes
			//R - SCREEN 
			//G - ADDITIVE.
			float3 DecalMIP6_1_5_Sample = AGOT_PdxTex2DArrayLoad( DecalDiffuseArray, int3(1, 5, int(InstanceIndex)), MaskLod).rgb;

			// If bottom right corner pixel is RED - CHANGE BLEND MODE TO SCREEN - EYE GLOW DECAL
			if ( AGOT_ColorAlmostEquals(DecalMIP6_1_5_Sample, AGOT_MASK_RED))
			{
				Data._DiffuseBlendMode = BLEND_MODE_SCREEN;
			}

			// If bottom right corner pixel is GREEN - CHANGE BLEND MODE TO ADDITIVE - EYE WHITE GLOW DECAL
			else if ( AGOT_ColorAlmostEquals(DecalMIP6_1_5_Sample, AGOT_MASK_GREEN))
			{
				Data._DiffuseBlendMode = BLEND_MODE_ADDITIVE;
			}

			// If bottom right corner pixel is BLUE - CHANGE BLEND MODE TO MAX VALUE - KHAJIIT FUR
			else if ( AGOT_ColorAlmostEquals(DecalMIP6_1_5_Sample, AGOT_MASK_BLUE))
			{
				Data._DiffuseBlendMode = BLEND_MODE_MAX_VALUE;
			}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


			WeightMatrix[0][0] *= Sample.a;
		}



		void DecodePropertiesMIPs( uint InstanceIndex , inout DecalData Data, inout float Weight, int CustomBodyPart, int MaskLod )
		{


/////////////////////////// MIP SAMPLING //////////////////////////////////


			//Sample top right corner pixel of decal MIP6. - WIP
			//R - DO NOT DRAW THE DECAL - USED FOR DECALS THAT CONTROL EFFECTS LIKE SALT N' PEPPER HAIR, AND CLOTHES DECAY
			//G - EYE DECAL - SO DECAL IS ONLY DRAWN ON EYES - CustomBodyPart = 1
			//REST OF CHANNELS WILL BE USED TO ASSIGN DECALS TO OTHER TYPES OF ATTACHMENTS IF NEEDED.

			float3 DecalMIP6_5_1_Sample = AGOT_PdxTex2DArrayLoad( DecalPropertiesArray, int3(5, 1, int(InstanceIndex)), MaskLod).rgb;


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////			


 			if (AGOT_ColorAlmostEquals(DecalMIP6_5_1_Sample, AGOT_MASK_RED))
			{			
				Weight = 0.0f;
				return;
			}

			//If MIP6-TR is green, and bodypartindex is set to eyes apply decal.
			if (CustomBodyPart == 0)
			{
				if (AGOT_ColorAlmostEquals(DecalMIP6_5_1_Sample, AGOT_MASK_GREEN))
				{			
					Weight = 0.0f;
					return;
				}
			}

			//If using custom body part, and the decal encoding matches the body part in the list, display the decal.
			else if (CustomBodyPart == 2)
			{
				if (AGOT_ColorAlmostEquals(DecalMIP6_5_1_Sample, AGOT_MASK_GREEN))
				{			
					Weight = Data._Weight;
				}

				// Else if using custom body part, but the decal encoding doesn't match, hide decals.
				else
				{
					Weight = 0.0f;
			 		return;
				}
			}

		}

		void AddDecals( inout float4 Diffuse, inout float3 Normals, inout float4 Properties, float2 UV, uint InstanceIndex, int From, int To /* MOD(agot) - CUSTOM BODY PART */ , int CustomBodyPart, bool IsDynamicTerrainLoaded = true )
		{
			// Body part index is scripted on the mesh asset and should match ECharacterPortraitPart
			uint BodyPartIndex = GetBodyPartIndex( InstanceIndex );

			// MOD(agot)
			int FromDataTexel = From * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;
			int ToDataTexel = To * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;

			//int FromDataTexel = AGOT_AvoidTerrainMarkerDecalIndices(From, IsDynamicTerrainLoaded) * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;
			//int ToDataTexel   = AGOT_AvoidTerrainMarkerDecalIndices(To, IsDynamicTerrainLoaded)   * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;

			static const uint MAX_VALUE = AGOT_VANILLA_DATA_MAX_VALUE;

			// Hoisted once per walk instead of once per decal inside the Decode*MIPs calls.
			int MaskLod = AGOT_MarkerLod();
			// END MOD

			// MOD(agot)
			//Create a matrix for decal weights. Add more as needed (up to 16 in 4x4)
			//This is to allow using multiple genes to control a single effect.
			//For example x controls which facepaint design is used, and y will select a colour.

			//WeightMatrix[0][0] = Decal opacity
			//WeightMatrix[0][1] = Facepaint Selection
			//WeightMatrix[0][2] = Body Hair Colour
			//WeightMatrix[0][3] = UNUSED

			float4x4 WeightMatrix = Create4x4(
				float4 (0.0f, 0.0f, 0.0f, 0.0f),
				float4 (0.0f, 0.0f, 0.0f, 0.0f),
				float4 (0.0f, 0.0f, 0.0f, 0.0f),
				float4 (0.0f, 0.0f, 0.0f, 0.0f));
			// MOD(agot)

			// Sorted after priority
			// MOD(agot)
			AGOT_LOOP
			// END MOD
			for ( int i = FromDataTexel; i <= ToDataTexel; i += AGOT_VANILLA_TEXEL_COUNT_PER_DECAL )
			{
				DecalData Data = GetDecalData( i );

				// Max index => unused
				// MOD(agot)
				//if ( Data._BodyPartIndex == BodyPartIndex )
				if ( Data._BodyPartIndex == BodyPartIndex || CustomBodyPart != 0)
				// END MOD
				{
					// Assumes that the cropped area size corresponds to the atlas factor
					float AtlasFactor = 1.0f / Data._AtlasSize;
					if ( ( ( UV.x >= Data._UVOffset.x ) && ( UV.x < ( Data._UVOffset.x + AtlasFactor ) ) ) &&
						 ( ( UV.y >= Data._UVOffset.y ) && ( UV.y < ( Data._UVOffset.y + AtlasFactor ) ) ) )
					{
						float2 DecalUV;
						float TilingMaskSample = 1;
						//UVTiling is incompatible with Decal Atlases, so we only use one of them. 
						//If a tiling value is provided, the tiling feature will be used.
						if ( Data._UVTiling.x == 1 && Data._UVTiling.y == 1 )
						{
							DecalUV = ( UV - Data._UVOffset ) + ( Data._AtlasPos * AtlasFactor );
						} 
						else
						{
							DecalUV = UV * Data._UVTiling;
							float2 TilingMaskUV = ( UV - Data._UVOffset ) + ( Data._AtlasPos * AtlasFactor );
							TilingMaskSample = PdxTex2D( DecalPropertiesArray, float3( TilingMaskUV, Data._PropertiesIndex ) ).r;
						}


					// MOD(agot)
					WeightMatrix[0][0] = Data._Weight;
					// MOD(agot)
					
						if ( Data._DiffuseIndex < MAX_VALUE )
						{
							// MOD(agot)
							WeightMatrix[0][0] *= TilingMaskSample;
							// END MOD

							// MOD(agot)
							//Sample LOD0 for eyes to avoid fading problems. TODO: Encode Mips to lower level to avoid this hack.
							#ifdef EYE_DECAL
							float4 DiffuseSample = PdxTex2DLod0( DecalDiffuseArray, float3( DecalUV, Data._DiffuseIndex ) );
							#else

							float4 DiffuseSample = PdxTex2D( DecalDiffuseArray, float3( DecalUV, Data._DiffuseIndex ) );
							#endif
							

							DecodeDiffuseMIPs( Data._DiffuseIndex, DiffuseSample, DecalUV , Data, WeightMatrix, CustomBodyPart, MaskLod );

							Diffuse = BlendDecal( Data._DiffuseBlendMode, Diffuse, DiffuseSample, WeightMatrix[0][0] );
							// END MOD
						}

						if ( Data._NormalIndex < MAX_VALUE )
						{
							

							float3 NormalSample = UnpackDecalNormal( PdxTex2D( DecalNormalArray, float3( DecalUV, Data._NormalIndex ) ), WeightMatrix[0][0] );

							Normals = BlendDecal( Data._NormalBlendMode, float4( Normals, 0.0f ), float4( NormalSample, 0.0f ), WeightMatrix[0][0] ).xyz;
						}

						if ( Data._PropertiesIndex < MAX_VALUE )
						{
							// MOD(agot)
							//Sample LOD0 for eyes to avoid fading problems. TODO: Encode Mips to lower level to avoid this hack.
							#ifdef EYE_DECAL
							float4 PropertiesSample = PdxTex2DLod0( DecalPropertiesArray, float3( DecalUV, Data._PropertiesIndex ) );
							#else

							float4 PropertiesSample = PdxTex2D( DecalPropertiesArray, float3( DecalUV, Data._PropertiesIndex ) );
							#endif

							


							// MOD(agot)

							DecodePropertiesMIPs( Data._PropertiesIndex , Data, WeightMatrix[0][0], CustomBodyPart, MaskLod );

							// END MOD
							Properties = BlendDecal( Data._PropertiesBlendMode, Properties, PropertiesSample, WeightMatrix[0][0] );
						}
					}
				}
			}

			Normals = normalize( Normals );
		}

		#ifdef DRAGON_BODYPART_MARKER
		void ApplyDragonDamageDecal(inout float4 Texture, uint DecalType, float Weight, float3 RandomSeed, bool Accumulative, float2 UV, int TextureIndex, uint BlendMode)
		{
			float TileScale = 0.25f;
			const uint MaxNumIterations = 20u; // Total number of possible decals
			const float AtlasTileSize = 1.0f / 3.0f;

			uint numDecalsPerIncrement = 2u; // Number of decals to add per 10% weight increment
			uint currentIncrement = (uint)(floor(Weight * 10.0f)); // Number of 10% increments
			uint numDecalsToShow = currentIncrement * numDecalsPerIncrement; // Total decals to show

			// Ensure we don't exceed MaxNumIterations
			numDecalsToShow = min(numDecalsToShow, MaxNumIterations);

			// Loop over a fixed number of iterations
			[unroll]
			for (uint i = 0u; i < MaxNumIterations; ++i)
			{
				bool shouldExecute = false;

				if (Accumulative)
				{
					// Accumulative mode: show all decals up to numDecalsToShow
					shouldExecute = (i < numDecalsToShow);
				}
				else
				{
					// Non-accumulative mode: show decals for the current increment only
					if (currentIncrement == 0u)
					{
						shouldExecute = false; // No decals to show if weight is less than 10%
					}
					else
					{
						uint startIndex = (currentIncrement - 1u) * numDecalsPerIncrement;
						uint endIndex = currentIncrement * numDecalsPerIncrement - 1u;
						shouldExecute = (i >= startIndex && i <= endIndex);
					}
				}

				if (shouldExecute)
				{
					uint tileIndex = uint(CalcRandom(RandomSeed.x + float(i) * 23.456f) * 9.0f);

					float2 baseTileUVOffset = float2(
						(tileIndex % 3u) * AtlasTileSize,
						(tileIndex / 3u) * AtlasTileSize
					);

					float decalHalfSize = TileScale * 0.5f;
					float2 randomValue = float2(
						CalcRandom(RandomSeed.x + float(i) * 12.345f),
						CalcRandom(RandomSeed.y + float(i) * 67.890f)
					);

					// Adjust random center position to ensure decals are within UV space
					float2 centerUV = randomValue * (1.0f - 2.0f * decalHalfSize) + decalHalfSize;

					float2 decalMin = centerUV - decalHalfSize;
					float2 decalMax = centerUV + decalHalfSize;

					if (UV.x >= decalMin.x && UV.x <= decalMax.x &&
						UV.y >= decalMin.y && UV.y <= decalMax.y)
					{
						float2 decalUV = (UV - decalMin) / (2.0f * decalHalfSize);

						// Adjust decalUV to stay within [0.05, 0.95] to avoid edge bleeding
						decalUV = decalUV * 0.9f + 0.05f;

						// Map decalUV directly to the current tile in the atlas
						float2 newUV = decalUV * AtlasTileSize + baseTileUVOffset;
						float4 DecalSample;

						if (DecalType == DIFFUSE_DECAL)
						{
							DecalSample = PdxTex2D(DecalDiffuseArray, float3(newUV, TextureIndex));
							Texture.rgb = lerp(Texture.rgb, DecalSample.rgb, DecalSample.a);
						}
						else if (DecalType == NORMAL_DECAL)
						{
							DecalSample = PdxTex2D(DecalNormalArray, float3(newUV, TextureIndex));
							float3 NormalSample = UnpackDecalNormal(DecalSample, 1.0f);
							Texture.rgb = lerp(Texture.rgb, NormalSample, DecalSample.b);
						}
						else
						{
							DecalSample = PdxTex2D(DecalPropertiesArray, float3(newUV, TextureIndex));
							// Handle other decal types as needed
						}
					}
				}
			}
		}
		
		// MOD(agot) The palette-smuggler decals' alpha curves span [0.01, 0.99]: a decal with
		// weight 0.0 is dropped from the decal buffer entirely, which would break the
		// order-dependent palette decode. That crop means the smuggled palette UV can never
		// reach the texture edges - on a wrapping hue axis the pure-red endpoints become
		// unreachable (~+/-3.6 degrees of hue). Undo the crop here so gene strength 0..1
		// spans the full palette again. KEEP IN SYNC with the alpha_curve endpoints in the
		// dragon palette genes.
		float2 AGOT_RemapPaletteUV( float X, float Y )
		{
			static const float WEIGHT_MIN = 0.01f;
			static const float WEIGHT_MAX = 0.99f;
			// Half-texel inset: the decal array sampler is deliberately Wrap (attachment-decay
			// tiling), so sampling at UV 0.0/1.0 bilinearly averages OPPOSITE edges of the
			// palette (black bleeding into the value axis at strength 0%). Sampling edge texel
			// CENTERS keeps the full range without ever touching the wrap seam.
			static const float TEXEL_INSET = 0.5f / 1024.0f; // palette textures are 1024x1024
			float2 T = saturate( ( float2( X, Y ) - WEIGHT_MIN ) / ( WEIGHT_MAX - WEIGHT_MIN ) );
			return lerp( vec2( TEXEL_INSET ), vec2( 1.0f - TEXEL_INSET ), T );
		}
		// END MOD

		void AddDragonDecals( inout float4 Diffuse, inout float3 Normals, inout float4 Properties, inout float4 ColorMask, float2 UV0, float2 UV1, uint InstanceIndex )
		{
			int MaskLod = AGOT_MarkerLod();
			DecalData Data;

			int PreSkinColorDecalDataTexel = PreSkinColorDecalCount * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;
			int TotalDecalDataTexel = DecalCount * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;

			static const uint MAX_VALUE = AGOT_VANILLA_DATA_MAX_VALUE;

			// Variables to store intermediate weights
			float DragonPrimaryColorX = 0.0f;
			float DragonPrimaryColorY = 0.0f;
			float DragonSecondaryColorX = 0.0f;
			float DragonSecondaryColorY = 0.0f;
			float DragonTertiaryColorX = 0.0f;
			float DragonTertiaryColorY = 0.0f;
			float DragonHornColorX = 0.0f;
			float DragonHornColorY = 0.0f;
			float DragonEyeColorX = 0.0f;
			float DragonEyeColorY = 0.0f;

			float3 DragonPrimaryColor = 	  float3(0.0f,0.0f,0.0f);
			float3 DragonSecondaryColor = 	  float3(0.0f,0.0f,0.0f);
			float3 DragonTertiaryColor = 	  float3(0.0f,0.0f,0.0f);
			float3 DragonHornColor =          float3(0.0f,0.0f,0.0f);
			float3 DragonEyeColor =           float3(0.0f,0.0f,0.0f);
			// Saturation multipliers - palette-marker decals 11-15 (pre-skin priorities
			// 10-14, between the colour pairs and the shading/pattern decals). DNA from
			// before the saturation genes shipped has no such decals; this init of 1.0 IS
			// the backwards compatibility - cases 11-15 never run and nothing is rescaled.
			float DragonPrimarySat =          1.0f;
			float DragonSecondarySat =        1.0f;
			float DragonTertiarySat =         1.0f;
			float DragonEyeSat =              1.0f;
			float DragonHornSat =             1.0f;
			float3 ColorPalette =             float3(1.0f,1.0f,1.0f);
			// The body stack: skin colour with pattern decals composited over it at their own
			// full opacity. ColorMask.r gates the finished stack ONCE at the apply point below -
			// gating each decal individually as well double-applied the mask and read as the
			// pattern rendering at reduced opacity wherever the mask is soft.
			float3 BodyColor =                float3(1.0f,1.0f,1.0f);

			// Counter to track the number of matches
			int matchCount = 0;
			float Weight = 0.0f;

			//PRE SKIN COLOUR DECALS
			AGOT_LOOP
			for ( int i = 0; i < TotalDecalDataTexel; i += AGOT_VANILLA_TEXEL_COUNT_PER_DECAL )
			{
				Data = GetDecalData( i );
				Weight = Data._Weight;

				// Assumes that the cropped area size corresponds to the atlas factor
				float AtlasFactor = 1.0f / Data._AtlasSize;
				if ( ( ( UV0.x >= Data._UVOffset.x ) && ( UV0.x < ( Data._UVOffset.x + AtlasFactor ) ) ) &&
						( ( UV0.y >= Data._UVOffset.y ) && ( UV0.y < ( Data._UVOffset.y + AtlasFactor ) ) ) )
				{
					float2 DecalUV;
					float TilingMaskSample = 1;
					//UVTiling is incompatible with Decal Atlases, so we only use one of them. 
					//If a tiling value is provided, the tiling feature will be used.
					if ( Data._UVTiling.x == 1 && Data._UVTiling.y == 1 )
					{
						DecalUV = ( UV0 - Data._UVOffset ) + ( Data._AtlasPos * AtlasFactor );
					} 
					else
					{
						DecalUV = UV0 * Data._UVTiling;
						float2 TilingMaskUV = ( UV0 - Data._UVOffset ) + ( Data._AtlasPos * AtlasFactor );
						TilingMaskSample = PdxTex2D( DecalPropertiesArray, float3( TilingMaskUV, Data._PropertiesIndex ) ).r;
					}

					//Sample dragon colours
					if (AGOT_ColorAlmostEquals(AGOT_PdxTex2DArrayLoad(DecalDiffuseArray, int3(1, 1, int(Data._DiffuseIndex)), MaskLod).rgb, AGOT_MASK_HALF_BLUE))
					{
						matchCount++;
						switch (matchCount)
						{
							case 1:
								DragonPrimaryColorX = Data._Weight;
								break;
							case 2:
								DragonPrimaryColorY = Data._Weight;
								DragonPrimaryColor = ToLinear( PdxTex2DLod(DecalDiffuseArray, float3(AGOT_RemapPaletteUV(DragonPrimaryColorX, DragonPrimaryColorY), Data._DiffuseIndex), 0.0f).rgb );
								BodyColor = DragonPrimaryColor;
								break;
							case 3:
								DragonSecondaryColorX = Data._Weight;
								break;
							case 4:
								DragonSecondaryColorY = Data._Weight;
								DragonSecondaryColor = ToLinear( PdxTex2DLod(DecalDiffuseArray, float3(AGOT_RemapPaletteUV(DragonSecondaryColorX, DragonSecondaryColorY), Data._DiffuseIndex), 0.0f).rgb );
								break;
							case 5:
								DragonTertiaryColorX = Data._Weight;
								break;
							case 6:
								DragonTertiaryColorY = Data._Weight;
								DragonTertiaryColor = ToLinear( PdxTex2DLod(DecalDiffuseArray, float3(AGOT_RemapPaletteUV(DragonTertiaryColorX, DragonTertiaryColorY), Data._DiffuseIndex), 0.0f).rgb );
								break;	
							case 7:
								DragonEyeColorX = Data._Weight;
								break;
							case 8:
								DragonEyeColorY = Data._Weight;
								DragonEyeColor = ToLinear( PdxTex2DLod(DecalDiffuseArray, float3(AGOT_RemapPaletteUV(DragonEyeColorX, DragonEyeColorY), Data._DiffuseIndex), 0.0f).rgb );
								break;
							case 9:
								DragonHornColorX = Data._Weight;
								break;
							case 10:
								DragonHornColorY = Data._Weight;
								DragonHornColor = ToLinear( PdxTex2DLod(DecalDiffuseArray, float3(AGOT_RemapPaletteUV(DragonHornColorX, DragonHornColorY), Data._DiffuseIndex), 0.0f).rgb );
								break;
							// Cases 11-15: the five saturation genes, in the colour-pair order
							// (primary/secondary/tertiary/eye/horn). The weight still carries the
							// alpha_curve's 0.01-0.99 remap; undo it here (same constants as
							// AGOT_RemapPaletteUV).
							// ORDER CONTRACT: the flame's walk in agot_particle_card.fxh counts
							// these same palette-marker decals by position (sats 11-15, fire
							// colour 16, fire smoke 17). Insert a new control gene at the END
							// and extend BOTH walks, or the later slots silently misread.
							case 11:
								DragonPrimarySat = saturate( ( Data._Weight - 0.01f ) / 0.98f );
								break;
							case 12:
								DragonSecondarySat = saturate( ( Data._Weight - 0.01f ) / 0.98f );
								break;
							case 13:
								DragonTertiarySat = saturate( ( Data._Weight - 0.01f ) / 0.98f );
								break;
							case 14:
								DragonEyeSat = saturate( ( Data._Weight - 0.01f ) / 0.98f );
								break;
							case 15:
								DragonHornSat = saturate( ( Data._Weight - 0.01f ) / 0.98f );
								// All five saturation weights are in. Re-derive the colours with the
								// scale applied to the RAW palette sample - gamma space, matching the
								// customizer's preview shader (agot_customizer_gui.shader) exactly -
								// then linearise as the original decode does. Runs before any
								// shading/pattern decal (their priorities sort after 14), so
								// re-seeding the body stack here is safe.
								DragonPrimaryColor = ToLinear( AGOT_ScaleSaturation( PdxTex2DLod(DecalDiffuseArray, float3(AGOT_RemapPaletteUV(DragonPrimaryColorX, DragonPrimaryColorY), Data._DiffuseIndex), 0.0f).rgb, DragonPrimarySat ) );
								BodyColor = DragonPrimaryColor;
								DragonSecondaryColor = ToLinear( AGOT_ScaleSaturation( PdxTex2DLod(DecalDiffuseArray, float3(AGOT_RemapPaletteUV(DragonSecondaryColorX, DragonSecondaryColorY), Data._DiffuseIndex), 0.0f).rgb, DragonSecondarySat ) );
								DragonTertiaryColor = ToLinear( AGOT_ScaleSaturation( PdxTex2DLod(DecalDiffuseArray, float3(AGOT_RemapPaletteUV(DragonTertiaryColorX, DragonTertiaryColorY), Data._DiffuseIndex), 0.0f).rgb, DragonTertiarySat ) );
								DragonEyeColor = ToLinear( AGOT_ScaleSaturation( PdxTex2DLod(DecalDiffuseArray, float3(AGOT_RemapPaletteUV(DragonEyeColorX, DragonEyeColorY), Data._DiffuseIndex), 0.0f).rgb, DragonEyeSat ) );
								DragonHornColor = ToLinear( AGOT_ScaleSaturation( PdxTex2DLod(DecalDiffuseArray, float3(AGOT_RemapPaletteUV(DragonHornColorX, DragonHornColorY), Data._DiffuseIndex), 0.0f).rgb, DragonHornSat ) );
								break;
						}
					}	

					float3 RandomSeed = DragonPrimaryColor - DragonSecondaryColor + DragonEyeColor - DragonHornColor;

					//Diffuse Decal
					if (AGOT_ColorAlmostEquals(AGOT_PdxTex2DArrayLoad(DecalDiffuseArray, int3(5, 1, int(Data._DiffuseIndex)), MaskLod).rgb, DRAGON_BODYPART_MARKER) )
					{
						//Dragon wound decal
						if (AGOT_ColorAlmostEquals(AGOT_PdxTex2DArrayLoad(DecalDiffuseArray, int3(9, 1, int(Data._DiffuseIndex)), MaskLod).rgb, AGOT_MASK_RED) )
						{
							ApplyDragonDamageDecal(Diffuse, DIFFUSE_DECAL, Weight, RandomSeed, 0, UV1, int(Data._DiffuseIndex),Data._DiffuseBlendMode);
						}
						//Dragon scar decal
						else if (AGOT_ColorAlmostEquals(AGOT_PdxTex2DArrayLoad(DecalDiffuseArray, int3(9, 1, int(Data._DiffuseIndex)), MaskLod).rgb, AGOT_MASK_GREEN) )
						{
							ApplyDragonDamageDecal(Diffuse, DIFFUSE_DECAL, Weight, RandomSeed, 1, UV1, int(Data._DiffuseIndex),Data._DiffuseBlendMode);
						}
						//Dragon scale-shadows AO decal, routed by its MIP-6 (9,1) MAGENTA marker (see
						//mark_decal.py). One texture authored at full strength; the gene slider drives
						//opacity AND a Photoshop-style levels midtone together so the shadows grow
						//instead of just fading in:
						//  0.00-0.15  fade in (0 -> full opacity) while the midtone stays at maximum
						//             brightening (pow 0.1 ~ Photoshop mid-slider at its far left)
						//  0.15-1.00  midtone eases back to 1.0 = the original texture
						//The decal is post_skin_color, so this multiplies AFTER ColorPalette is applied.
						//Levels run on the raw gamma-space sample (matching Photoshop) and the result is
						//used as the multiply factor DIRECTLY - deliberately NOT linearised: ToLinear on
						//the factor gave sample^(2.2*gamma), which sailed past the original texture's
						//darkness at ~half slider. This way 100% = exactly the original decal, the
						//darkest the effect can go.
						else if (AGOT_ColorAlmostEquals(AGOT_PdxTex2DArrayLoad(DecalDiffuseArray, int3(9, 1, int(Data._DiffuseIndex)), MaskLod).rgb, AGOT_MASK_MAGENTA) )
						{
							float ShadowOpacity = saturate( Weight / 0.15f );
							float ShadowLevels  = saturate( ( Weight - 0.15f ) / 0.85f );
							float ShadowGamma   = lerp( 0.1f, 1.0f, ShadowLevels );

							float4 DiffuseSample = PdxTex2D( DecalDiffuseArray, float3( DecalUV, Data._DiffuseIndex ) );
							float3 ShadowAO = pow( saturate( DiffuseSample.rgb ), float3( ShadowGamma, ShadowGamma, ShadowGamma ) );
							Diffuse.rgb *= lerp( float3( 1.0f, 1.0f, 1.0f ), ShadowAO, DiffuseSample.a * ShadowOpacity );
						}
						//Dragon scale-highlights decal, routed by its MIP-6 (9,1) CYAN marker. A plain
						//alpha-over blend - the generic BlendDecal path below ignores texture alpha, so
						//it cannot be used for this. post_skin_color -> draws over the finished body.
						else if (AGOT_ColorAlmostEquals(AGOT_PdxTex2DArrayLoad(DecalDiffuseArray, int3(9, 1, int(Data._DiffuseIndex)), MaskLod).rgb, AGOT_MASK_CYAN) )
						{
							float4 DiffuseSample = PdxTex2D( DecalDiffuseArray, float3( DecalUV, Data._DiffuseIndex ) );
							Diffuse.rgb = lerp( Diffuse.rgb, ToLinear( DiffuseSample.rgb ), DiffuseSample.a * Weight );
						}
						else if (i < PreSkinColorDecalDataTexel && Data._DiffuseBlendMode <= BLEND_MODE_MULTIPLY)
						{
							//Dragon shading/pattern decal that keeps its own shading. One shared texture
							//per pattern: the gene's diffuse blend mode is repurposed as the tint selector
							//(the decal is hue-rotated, not blended) -
							//  replace    -> black
							//  multiply   -> white
							//  hard_light -> secondary colour
							//  overlay    -> tertiary colour
							//Blend modes above BLEND_MODE_MULTIPLY fall through to the generic
							//BlendDecal branch below for raw pre-skin blending.
							float3 Tint = float3(0.0f, 0.0f, 0.0f);
							if (Data._DiffuseBlendMode == BLEND_MODE_MULTIPLY)
							{
								Tint = float3(1.0f, 1.0f, 1.0f);
							}
							else if (Data._DiffuseBlendMode == BLEND_MODE_HARD_LIGHT)
							{
								Tint = DragonSecondaryColor;
							}
							else if (Data._DiffuseBlendMode == BLEND_MODE_OVERLAY)
							{
								Tint = DragonTertiaryColor;
							}

							float4 DiffuseSample = PdxTex2D( DecalDiffuseArray, float3( DecalUV, Data._DiffuseIndex ) );
							// MOD(agot) The decal array is NOT sRGB-decoded on sampling (measured in-game:
							// authored G=72 arrived as 72/255 linear, i.e. raw bytes). The body DiffuseMap IS
							// decoded, so without this the pattern/palette factors are gamma-space values
							// multiplied into a linear diffuse - brighter and less saturated than authored,
							// with orange tints amplified ~4x. Decode manually here.
							DiffuseSample.rgb = ToLinear( DiffuseSample.rgb );
							// END MOD
							BodyColor = lerp(BodyColor,AGOT_TintDecalHue(DiffuseSample.rgb, Tint),DiffuseSample.a*Weight);
							#ifdef AGOT_DEBUG_DRAGON_VIEW_2
							if (DiffuseSample.a > 0.004f) AGOT_DragonDebug = float4(DiffuseSample.rgb, 1.0f);
							#endif
							#ifdef AGOT_DEBUG_DRAGON_VIEW_5
							if (DiffuseSample.a > 0.004f) AGOT_DragonDebug = float4(AGOT_TintDecalHue(DiffuseSample.rgb, Tint), 1.0f);
							#endif
							#ifdef AGOT_DEBUG_DRAGON_VIEW_7
							AGOT_DragonDebug = float4(vec3(DiffuseSample.a * Weight), 1.0f);
							#endif
							#ifdef AGOT_DEBUG_DRAGON_VIEW_10
							AGOT_DragonDebug = float4(DecalUV, 0.0f, 1.0f);
							#endif
							#ifdef AGOT_DEBUG_DRAGON_VIEW_13
							if (Data._DiffuseBlendMode == BLEND_MODE_OVERLAY && DiffuseSample.a > 0.004f)
								AGOT_DragonDebug = float4(DiffuseSample.rgb, 1.0f);
							#endif
							#ifdef AGOT_DEBUG_DRAGON_VIEW_14
							if (Data._DiffuseBlendMode == BLEND_MODE_OVERLAY && DiffuseSample.a > 0.004f && AGOT_DragonDebug.a < 0.5f)
								AGOT_DragonDebug = float4(DiffuseSample.rgb, 1.0f);
							#endif
						}
						else
						{
							Weight *= TilingMaskSample;
							float4 DiffuseSample = PdxTex2D( DecalDiffuseArray, float3( DecalUV, Data._DiffuseIndex ) );
							Diffuse = BlendDecal( Data._DiffuseBlendMode, Diffuse, DiffuseSample, Weight );
						}
					}

					//Normal Decal
					if (AGOT_ColorAlmostEquals(AGOT_PdxTex2DArrayLoad(DecalNormalArray, int3(5, 1, int(Data._NormalIndex)), MaskLod).rgb, DRAGON_BODYPART_MARKER) )
					{
						//Dragon wound decal
						if (AGOT_ColorAlmostEquals(AGOT_PdxTex2DArrayLoad(DecalNormalArray, int3(9, 1, int(Data._NormalIndex)), MaskLod).rgb, AGOT_MASK_RED) )
						{
							float4 DamageNormals = float4( Normals, 0.0f );
							ApplyDragonDamageDecal(DamageNormals, NORMAL_DECAL, Weight, RandomSeed, 0, UV1, int(Data._NormalIndex),Data._NormalBlendMode);
							Normals = DamageNormals.xyz;
						}
						//Dragon scar decal
						else if (AGOT_ColorAlmostEquals(AGOT_PdxTex2DArrayLoad(DecalNormalArray, int3(9, 1, int(Data._NormalIndex)), MaskLod).rgb, AGOT_MASK_GREEN) )
						{
							float4 DamageNormals = float4( Normals, 0.0f );
							ApplyDragonDamageDecal(DamageNormals, NORMAL_DECAL, Weight, RandomSeed, 1, UV1, int(Data._NormalIndex),Data._NormalBlendMode);
							Normals = DamageNormals.xyz;
						}
						else
						{
							float3 NormalSample = UnpackDecalNormal( PdxTex2D( DecalNormalArray, float3( DecalUV, Data._NormalIndex ) ), Weight );
							Normals = BlendDecal( Data._NormalBlendMode, float4( Normals, 0.0f ), float4( NormalSample, 0.0f ), Weight ).xyz;
						}

					}

					//Properties Decals
					if (AGOT_ColorAlmostEquals(AGOT_PdxTex2DArrayLoad(DecalPropertiesArray, int3(5, 1, int(Data._PropertiesIndex)), MaskLod).rgb, DRAGON_BODYPART_MARKER) )
					{
						//Dragon wound decal
						if (AGOT_ColorAlmostEquals(AGOT_PdxTex2DArrayLoad(DecalPropertiesArray, int3(9, 1, int(Data._PropertiesIndex)), MaskLod).rgb, AGOT_MASK_RED) )
						{
							ApplyDragonDamageDecal(Properties, PROPERTIES_DECAL, Weight, RandomSeed, 0, UV1, int(Data._PropertiesIndex),Data._PropertiesBlendMode);
						}
						else
						{
							float4 PropertiesSample = PdxTex2D( DecalPropertiesArray, float3( DecalUV, Data._PropertiesIndex ) );
							Properties = BlendDecal( Data._PropertiesBlendMode, Properties, PropertiesSample, Weight );
						}
					}
				}

				//Apply dragon colours: the body stack (skin colour + pattern decals) is gated by
				//the mask ONCE here, then the other zones layer over it. Zone lerps are gated on
				//their colour pair actually having been decoded so an absent colour cannot bleed
				//black through a non-zero mask channel.
				if (i == PreSkinColorDecalDataTexel-AGOT_VANILLA_TEXEL_COUNT_PER_DECAL)
				{
					ColorPalette = lerp(ColorPalette, BodyColor, ColorMask.r);
					if (matchCount >= 4)
						ColorPalette = lerp(ColorPalette, DragonSecondaryColor, ColorMask.b);
					if (matchCount >= 8)
						ColorPalette = lerp(ColorPalette, DragonEyeColor, ColorMask.a);
					if (matchCount >= 10)
						ColorPalette = lerp(ColorPalette, DragonHornColor, ColorMask.g);
					#ifdef AGOT_DEBUG_DRAGON_VIEW_3
					AGOT_DragonDebug = float4(DragonTertiaryColor, 1.0f);
					#endif
					#ifdef AGOT_DEBUG_DRAGON_VIEW_4
					AGOT_DragonDebug = float4(DragonSecondaryColor, 1.0f);
					#endif
					#ifdef AGOT_DEBUG_DRAGON_VIEW_6
					AGOT_DragonDebug = float4(ColorPalette, 1.0f);
					#endif
					#ifdef AGOT_DEBUG_DRAGON_VIEW_12
					AGOT_DragonDebug = float4(DragonTertiaryColorX, DragonTertiaryColorY, 0.0f, 1.0f);
					#endif
					Diffuse.rgb *= ColorPalette;
				}
			}
			Normals = normalize( Normals );
		}
		#endif
	]]
}
