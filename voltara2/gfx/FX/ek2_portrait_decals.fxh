# EK2 file. The EK2 decal code. It adds to the vanilla file jomini/portrait_decals.fxh,
# which this file includes. The vanilla file is not copied, so a CK3 update needs no compatch
# here.
#
# Two parts:
#   1. MIP-6 marker decoding. EK2 hides control data in MIP 6 of the decal textures. See
#      "MIP-6 markers" in SHADERS.md for the marker table.
#   2. An AddDecals() overload. The vanilla one takes a float3 diffuse and cannot change the
#      alpha, and it cannot draw a decal on a body part that is not scripted on the mesh.
#      The EK2 one takes a float4 diffuse and a custom body part. It is an overload, not a
#      replacement, so the vanilla function stays for the shaders that use it.
#
# The shader that includes this file must have vPaletteColorSkin, vPaletteColorHair and
# vPaletteColorEyes in a constant buffer.

Includes = {
	"jomini/portrait_decals.fxh"
}

PixelShader =
{
	Code
	[[
		// CustomBodyPart value for AddDecals(). 0 = the scripted body part, as in vanilla.
		#define BODYPART_EYES 1

		// Color codes for the MIP 6 marker blocks
		static const float3 RED 	= 	float3(1.0f,0.0f,0.0f);
		static const float3 GREEN 	= 	float3(0.0f,1.0f,0.0f);
		static const float3 BLUE 	= 	float3(0.0f,0.0f,1.0f);
		static const float3 CYAN 	=	float3(0.0f,1.0f,1.0f);
		static const float3 MAGENTA =	float3(1.0f,0.0f,1.0f);
		static const float3 YELLOW 	=	float3(1.0f,1.0f,0.0f);

		// DecalType for GetDecalData( DecalMask, DecalType, To )
		#define DIFFUSE_DECAL uint(0)
		#define NORMAL_DECAL uint(1)
		#define PROPERTIES_DECAL uint(2)

		// Texture array load and size, for DirectX and OpenGL/Vulkan
		#ifndef PDX_OPENGL
			#define GH_PdxTex2DArrayLoad(samp,uvi,lod) (samp)._Texture.Load( int4((uvi), (lod)) )
			#define EK2_PdxTex2DArraySize(samp,size) (samp)._Texture.GetDimensions( (size).x, (size).y, (size).z )
		#else
			#define GH_PdxTex2DArrayLoad texelFetch
			#define EK2_PdxTex2DArraySize(samp,size) size = textureSize((samp), 0)
		#endif

		//
		// EK2 hides control data in MIP 6 (16x16 px for a 1024 px decal) of the decal textures.
		// The centre texels of the 4x4 blocks carry color codes:
		//   (1,1)  CONTROL:   the decal controls an effect (clothes decay, hair aging, skeleton, etc.)
		//   (5,1)  BODYPART:  RED = do not draw, GREEN = draw only on eyes
		//   (9,1)  SPLIT:     split one texture into 4 or 16 decals, selected by the weight
		//   (13,1) COLOR:     replace the decal color (palette, skin, hair, eye color)
		//   (1,5)  BLENDMODE: screen, additive or max value blending
		//   (x,13) PALETTE:   a row of palette colors for the COLOR block
		// The weight of a decal (0-1, set by genes) is the value that the effect uses.

		// Lower texture quality settings drop the top mips, so MIP 6 of the source texture
		// is not always MIP 6 of the loaded texture. This gives the loaded mip level that is
		// 16x16 px: 1024 px -> 6, 512 px -> 5, 2048 px -> 7.
		uint GetMIP6Level()
		{
			float3 TextureSize;
			EK2_PdxTex2DArraySize(DecalDiffuseArray, TextureSize);

			// log2 of the loaded size is 10 for 1024 px, 9 for 512 px, etc.
			uint MIP = uint(6.0f-(10.0f - log2(TextureSize.x)));
			return MIP;
		}

		// Compares a marker texel with a color code. The tolerance allows for compression error.
		bool AlmostEquals(float3 Sample, float3 Mask)
		{
			static const float MaskTolerance = 0.02f;
			float3 Difference = abs( Sample - Mask );
			return max( max( Difference.r, Difference.g ), Difference.b ) <= MaskTolerance;
		}

		// Returns decal data with weight 0 and no textures. GetDecalData() returns this when no decal matches.
		DecalData GetEmptyDecalData()
		{
			static const uint MAX_VALUE = 65535;

			DecalData Data;
			Data._DiffuseIndex = MAX_VALUE;
			Data._NormalIndex = MAX_VALUE;
			Data._PropertiesIndex = MAX_VALUE;
			Data._BodyPartIndex = MAX_VALUE;
			Data._DiffuseBlendMode = 0;
			Data._NormalBlendMode = 0;
			Data._PropertiesBlendMode = 0;
			Data._Weight = 0.0f;
			Data._AtlasPos = uint2( 0, 0 );
			Data._UVOffset = float2( 0.0f, 0.0f );
			Data._UVTiling = uint2( 1, 1 );
			Data._AtlasSize = 1;
			return Data;
		}

		// Finds the first decal with a weight above 0 whose CONTROL texel (1,1) in MIP 6 matches DecalMask.
		// Effects outside of AddDecals() use this, for example clothes decay and hair aging.
		// If no decal matches, the result has weight 0. Earlier versions returned the last decal
		// of the walk in that case, so a non-matching decal could drive the effect.
		DecalData GetDecalData(float3 DecalMask, uint DecalType, int To)
		{
			const int TEXEL_COUNT_PER_DECAL = 15;
			static const uint MAX_VALUE = 65535;
			int ToDataTexel = To * TEXEL_COUNT_PER_DECAL;
			int CurrentLOD = int( GetMIP6Level() );

			// Same range as vanilla AddDecals()
			for ( int i = 0; i <= ToDataTexel; i += TEXEL_COUNT_PER_DECAL )
			{
				DecalData Data = GetDecalData( i );

				uint TextureIndex = Data._DiffuseIndex;
				if ( DecalType == NORMAL_DECAL )
				{
					TextureIndex = Data._NormalIndex;
				}
				else if ( DecalType == PROPERTIES_DECAL )
				{
					TextureIndex = Data._PropertiesIndex;
				}

				// Skip unused slots and zero-weight decals before the texture load
				if ( TextureIndex >= MAX_VALUE || Data._Weight <= 0.0f )
				{
					continue;
				}

				float3 DecalMIP6_1_1_Sample;
				if ( DecalType == NORMAL_DECAL )
				{
					DecalMIP6_1_1_Sample = GH_PdxTex2DArrayLoad( DecalNormalArray, int3(1, 1, int(TextureIndex)), CurrentLOD ).rgb;
				}
				else if ( DecalType == PROPERTIES_DECAL )
				{
					DecalMIP6_1_1_Sample = GH_PdxTex2DArrayLoad( DecalPropertiesArray, int3(1, 1, int(TextureIndex)), CurrentLOD ).rgb;
				}
				else
				{
					DecalMIP6_1_1_Sample = GH_PdxTex2DArrayLoad( DecalDiffuseArray, int3(1, 1, int(TextureIndex)), CurrentLOD ).rgb;
				}

				if ( AlmostEquals( DecalMIP6_1_1_Sample, DecalMask ) )
				{
					return Data;
				}
			}

			return GetEmptyDecalData();
		}


		void SPlitDecalRGBA(inout float4 Decal, inout float Weight )
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

		void SPlitDecal512(inout float4 Decal, inout float Weight, float2 UV , float DiffuseIndex )
		{
			//Below If statements normalize the weight value to 0.0 - 1.0 then tells which channel to use as alpha at increments of 25%.
			if (Weight < 0.25f)
			{
			Weight = Weight * 4.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) , (UV.y / 2.0f) , DiffuseIndex ) );
			}

			else if (Weight >= 0.25f && Weight < 0.5f)
			{
			Weight = (Weight - 0.25f) * 4.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) + 0.5f , (UV.y / 2.0f) , DiffuseIndex ) );
			}

			else if (Weight >= 0.5f && Weight < 0.75f)
			{
			Weight = (Weight - 0.5f) * 4.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) , (UV.y / 2.0f) + 0.5f , DiffuseIndex ) );
			}

			else
			{
			Weight = (Weight - 0.75f) * 4.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) + 0.5f , (UV.y / 2.0f) + 0.5f , DiffuseIndex ) );
			}
		}

		void SPlitDecalRGBA512(inout float4 Decal, inout float Weight, float2 UV , float DiffuseIndex )
		{
			//Below If statements normalize the weight value to 0.0 - 1.0 then tells which channel to use as alpha at increments of 6.25%.
			if (Weight < 0.0625f)
			{
			Weight = Weight * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) , (UV.y / 2.0f) , DiffuseIndex ) );
			Decal.a = Decal.r;
			}

			else if (Weight >= 0.0625f && Weight < 0.125f)
			{
			Weight = (Weight - 0.0625f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) + 0.5f , (UV.y / 2.0f) , DiffuseIndex ) );
			Decal.a = Decal.r;
			}

			else if (Weight >= 0.125f && Weight < 0.1875f)
			{
			Weight = (Weight - 0.125f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) , (UV.y / 2.0f) + 0.5f , DiffuseIndex ) );
			Decal.a = Decal.r;
			}

			else if (Weight >= 0.1875f && Weight < 0.25f)
			{
			Weight = (Weight - 0.1875f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) + 0.5f , (UV.y / 2.0f) + 0.5f , DiffuseIndex ) );
			Decal.a = Decal.r;
			}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

			else if (Weight >= 0.25f && Weight < 0.3125f)
			{
			Weight = (Weight - 0.25f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) , (UV.y / 2.0f) , DiffuseIndex ) );
			Decal.a = Decal.g;
			}

			else if (Weight >= 0.3125f && Weight < 0.375f)
			{
			Weight = (Weight - 0.3125f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) + 0.5f , (UV.y / 2.0f) , DiffuseIndex ) );
			Decal.a = Decal.g;
			}

			else if (Weight >= 0.375f && Weight < 0.4375f)
			{
			Weight = (Weight - 0.375f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) , (UV.y / 2.0f) + 0.5f , DiffuseIndex ) );
			Decal.a = Decal.g;
			}

			else if (Weight >= 0.4375f && Weight < 0.5f)
			{
			Weight = (Weight - 0.4375f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) + 0.5f , (UV.y / 2.0f) + 0.5f , DiffuseIndex ) );
			Decal.a = Decal.g;
			}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

			else if (Weight >= 0.5f && Weight < 0.5625f)
			{
			Weight = (Weight - 0.5f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) , (UV.y / 2.0f) , DiffuseIndex ) );
			Decal.a = Decal.b;
			}

			else if (Weight >= 0.5625f && Weight < 0.625f)
			{
			Weight = (Weight - 0.5625) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) + 0.5f , (UV.y / 2.0f) , DiffuseIndex ) );
			Decal.a = Decal.b;
			}

			else if (Weight >= 0.625f && Weight < 0.6875f)
			{
			Weight = (Weight - 0.625f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) , (UV.y / 2.0f) + 0.5f , DiffuseIndex ) );
			Decal.a = Decal.b;
			}

			else if (Weight >= 0.6875f && Weight < 0.75f)
			{
			Weight = (Weight - 0.6875f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) + 0.5f , (UV.y / 2.0f) + 0.5f , DiffuseIndex ) );
			Decal.a = Decal.b;
			}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

			else if (Weight >= 0.75f && Weight < 0.8125f)
			{
			Weight = (Weight - 0.75f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) , (UV.y / 2.0f) , DiffuseIndex ) );
			}

			else if (Weight >= 0.8125f && Weight < 0.875f)
			{
			Weight = (Weight - 0.8125f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) + 0.5f , (UV.y / 2.0f) , DiffuseIndex ) );
			}

			else if (Weight >= 0.875f && Weight < 0.9375f)
			{
			Weight = (Weight - 0.875f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) , (UV.y / 2.0f) + 0.5f , DiffuseIndex ) );
			}

			else
			{
			Weight = (Weight - 0.9375f) * 16.0f;
			Decal = PdxTex2D( DecalDiffuseArray, float3( (UV.x / 2.0f) + 0.5f , (UV.y / 2.0f) + 0.5f , DiffuseIndex ) );
			}
		}

		// Color code for the body hair control and color blocks
		static const float3 HALF_RED = float3(0.5f,0.0f,0.0f);

		// Palette texel in row 13 of MIP 6, selected by a 0-1 weight. Weight 1 selects the last texel (15), not texel 16.
		float3 GetMIP6PaletteColor( uint DiffuseIndex, float Selection, int CurrentLOD )
		{
			int PaletteX = min( int( Selection * 16.0f ), 15 );
			return GH_PdxTex2DArrayLoad( DecalDiffuseArray, int3(PaletteX, 13, int(DiffuseIndex)), CurrentLOD ).rgb;
		}

		// Reads the MIP 6 marker blocks of a diffuse decal and changes how AddDecals() draws it.
		// WeightMatrix.x = opacity of this decal
		// WeightMatrix.y = facepaint color selection (weight of the last BLUE control decal)
		// WeightMatrix.z = body hair color selection (weight of the last HALF_RED control decal)
		void DecodeDiffuseMIPs( uint DiffuseIndex, inout float4 Sample, float2 UV, inout DecalData Data, inout float3 WeightMatrix, int CustomBodyPart )
		{
			int CurrentLOD = int( GetMIP6Level() );

			/////////////////////////// CONTROL BLOCK (1,1) ///////////////////////////
			// Control decals are not drawn. Other effects use their weight:
			//   RED       - clothes decay (GetDecalData in PS_attachment)
			//   GREEN     - salt and pepper hair (GetDecalData in PS_hair)
			//   BLUE      - facepaint color selection (WeightMatrix.y, read here)
			//   MAGENTA   - fur color transition (GetDecalData in PS_skin)
			//   HALF_RED  - body hair color selection (WeightMatrix.z, read here)
			//   YELLOW    - skeleton transition, head (GetDecalData in PS_skin with FACE_TEXTURE)
			//   (0,0.5,0) - skeleton transition, body (GetDecalData in PS_skin)
			// Only BLUE and HALF_RED are handled here. The other control decals use BODYPART RED to stay hidden.
			float3 DecalMIP6_1_1_Sample = GH_PdxTex2DArrayLoad( DecalDiffuseArray, int3(1, 1, int(DiffuseIndex)), CurrentLOD ).rgb;

			if (AlmostEquals(DecalMIP6_1_1_Sample,BLUE))
			{
				WeightMatrix.x = 0.0f;
				WeightMatrix.y = Data._Weight;
				return;
			}
			else if (AlmostEquals(DecalMIP6_1_1_Sample,HALF_RED))
			{
				WeightMatrix.x = 0.0f;
				WeightMatrix.z = Data._Weight;
				return;
			}

			/////////////////////////// BODYPART BLOCK (5,1) ///////////////////////////
			//   RED   - do not draw. Use this for decals that control an effect.
			//   GREEN - draw only on eyes (CustomBodyPart == BODYPART_EYES)
			// CustomBodyPart 0 draws decals on their scripted body part, as in vanilla.
			float3 DecalMIP6_5_1_Sample = GH_PdxTex2DArrayLoad( DecalDiffuseArray, int3(5, 1, int(DiffuseIndex)), CurrentLOD ).rgb;

			if (AlmostEquals(DecalMIP6_5_1_Sample,RED))
			{
				WeightMatrix.x = 0.0f;
				return;
			}

			if (CustomBodyPart == 0)
			{
				// Eye decals are not drawn on the normal body parts
				if (AlmostEquals(DecalMIP6_5_1_Sample,GREEN))
				{
					WeightMatrix.x = 0.0f;
					return;
				}
			}
			else if (CustomBodyPart == BODYPART_EYES)
			{
				// On eyes, draw only eye decals
				if (AlmostEquals(DecalMIP6_5_1_Sample,GREEN))
				{
					WeightMatrix.x = Data._Weight;
				}
				else
				{
					WeightMatrix.x = 0.0f;
					return;
				}
			}

			/////////////////////////// SPLIT BLOCK (9,1) ///////////////////////////
			// One texture holds more than one decal. The weight selects which one to draw.
			//   RED   - 4 decals, one for each RGBA channel, a new one every 25% of weight
			//   GREEN - 4 decals in a 2x2 atlas of 512 px, a new one every 25% of weight
			//   BLUE  - 16 decals, the two methods together, a new one every 6.25% of weight
			float3 DecalMIP6_9_1_Sample = GH_PdxTex2DArrayLoad( DecalDiffuseArray, int3(9, 1, int(DiffuseIndex)), CurrentLOD ).rgb;

			if ( AlmostEquals(DecalMIP6_9_1_Sample, RED))
			{
				SPlitDecalRGBA(Sample, WeightMatrix.x );
			}
			else if ( AlmostEquals(DecalMIP6_9_1_Sample, GREEN))
			{
				SPlitDecal512(Sample, WeightMatrix.x , UV , DiffuseIndex );
			}
			else if ( AlmostEquals(DecalMIP6_9_1_Sample, BLUE))
			{
				SPlitDecalRGBA512(Sample, WeightMatrix.x , UV , DiffuseIndex );
			}

			/////////////////////////// COLOR BLOCK (13,1) ///////////////////////////
			//   RED      - palette color from row 13, selected by WeightMatrix.y. Opacity 100%.
			//   GREEN    - skin color
			//   BLUE     - hair color
			//   YELLOW   - eye color
			//   CYAN     - palette texel (1,13). The decal weight stays as opacity.
			//   MAGENTA  - same as RED
			//   HALF_RED - hair color, darker with WeightMatrix.z (body and facial hair)
			float3 DecalMIP6_13_1_Sample = GH_PdxTex2DArrayLoad( DecalDiffuseArray, int3(13, 1, int(DiffuseIndex)), CurrentLOD ).rgb;

			if ( AlmostEquals(DecalMIP6_13_1_Sample,RED) || AlmostEquals(DecalMIP6_13_1_Sample,MAGENTA) )
			{
				// Another decal (BLUE control) selects the color, so this decal is always at full strength
				Sample.rgb = GetMIP6PaletteColor( DiffuseIndex, WeightMatrix.y, CurrentLOD );
				WeightMatrix.x = 1.0f;
			}
			else if ( AlmostEquals(DecalMIP6_13_1_Sample,GREEN))
			{
				Sample.rgb = vPaletteColorSkin.rgb;
			}
			else if ( AlmostEquals(DecalMIP6_13_1_Sample,BLUE))
			{
				Sample.rgb = vPaletteColorHair.rgb;
			}
			else if ( AlmostEquals(DecalMIP6_13_1_Sample,YELLOW))
			{
				Sample.rgb = vPaletteColorEyes.rgb;
			}
			else if ( AlmostEquals(DecalMIP6_13_1_Sample,CYAN))
			{
				Sample.rgb = GH_PdxTex2DArrayLoad( DecalDiffuseArray, int3(1, 13, int(DiffuseIndex)), CurrentLOD ).rgb;
			}
			else if ( AlmostEquals(DecalMIP6_13_1_Sample,HALF_RED))
			{
				Sample.rgb = lerp (lerp(vPaletteColorHair.rgb, vPaletteColorHair.rgb*vPaletteColorSkin.rgb, 0.8f), float3(0.0f,0.0f,0.0f), WeightMatrix.z);
			}

			/////////////////////////// BLENDMODE BLOCK (1,5) ///////////////////////////
			//   RED   - screen (eye glow)
			//   GREEN - additive (eye white glow)
			//   BLUE  - max value (Khajiit fur)
			float3 DecalMIP6_1_5_Sample = GH_PdxTex2DArrayLoad( DecalDiffuseArray, int3(1, 5, int(DiffuseIndex)), CurrentLOD ).rgb;

			if ( AlmostEquals(DecalMIP6_1_5_Sample, RED))
			{
				Data._DiffuseBlendMode = BLEND_MODE_SCREEN;
			}
			else if ( AlmostEquals(DecalMIP6_1_5_Sample, GREEN))
			{
				Data._DiffuseBlendMode = BLEND_MODE_ADDITIVE;
			}
			else if ( AlmostEquals(DecalMIP6_1_5_Sample, BLUE))
			{
				Data._DiffuseBlendMode = BLEND_MODE_MAX_VALUE;
			}

			WeightMatrix.x *= Sample.a;
		}

		// Reads the BODYPART block (5,1) of a properties decal. Same rules as in DecodeDiffuseMIPs().
		void DecodePropertiesMIPs( uint PropertiesIndex, inout DecalData Data, inout float Weight, int CustomBodyPart )
		{
			int CurrentLOD = int( GetMIP6Level() );

			float3 DecalMIP6_5_1_Sample = GH_PdxTex2DArrayLoad( DecalPropertiesArray, int3(5, 1, int(PropertiesIndex)), CurrentLOD ).rgb;

			if (AlmostEquals(DecalMIP6_5_1_Sample, RED))
			{
				Weight = 0.0f;
				return;
			}

			if (CustomBodyPart == 0)
			{
				if (AlmostEquals(DecalMIP6_5_1_Sample,GREEN))
				{
					Weight = 0.0f;
					return;
				}
			}
			else if (CustomBodyPart == BODYPART_EYES)
			{
				if (AlmostEquals(DecalMIP6_5_1_Sample,GREEN))
				{
					Weight = Data._Weight;
				}
				else
				{
					Weight = 0.0f;
					return;
				}
			}
		}

		// MOD(ek2) Diffuse is float4 (vanilla: float3) so that decals can change the alpha.
		// CustomBodyPart: 0 = vanilla behavior, BODYPART_EYES = draw eye decals on the eye mesh.
		//void AddDecals( inout float3 Diffuse, inout float3 Normals, inout float4 Properties, float2 UV, uint InstanceIndex, int From, int To )
		void AddDecals( inout float4 Diffuse, inout float3 Normals, inout float4 Properties, float2 UV, uint InstanceIndex, int From, int To, int CustomBodyPart )
		// END MOD
		{
			// Body part index is scripted on the mesh asset and should match ECharacterPortraitPart
			uint BodyPartIndex = GetBodyPartIndex( InstanceIndex );

			const int TEXEL_COUNT_PER_DECAL = 15;
			int FromDataTexel = From * TEXEL_COUNT_PER_DECAL;
			int ToDataTexel = To * TEXEL_COUNT_PER_DECAL;

			static const uint MAX_VALUE = 65535;

			// MOD(ek2)
			// Decal weights. More than one gene can control one effect.
			// x = opacity of the current decal (vanilla: Weight)
			// y = facepaint color selection
			// z = body hair color selection
			float3 WeightMatrix = float3 (0.0f, 0.0f, 0.0f);
			// END MOD

			// Sorted after priority
			for ( int i = FromDataTexel; i <= ToDataTexel; i += TEXEL_COUNT_PER_DECAL )
			{
				DecalData Data = GetDecalData( i );

				// Max index => unused
				// MOD(ek2) with a custom body part, DecodeDiffuseMIPs() selects the decals
				//if ( Data._BodyPartIndex == BodyPartIndex )
				if ( Data._BodyPartIndex == BodyPartIndex || CustomBodyPart != 0 )
				// END MOD
				{
					// MOD(ek2)
					//float Weight = Data._Weight;
					WeightMatrix.x = Data._Weight;
					// END MOD

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

						if ( Data._DiffuseIndex < MAX_VALUE )
						{
							// MOD(ek2)
							//float4 DiffuseSample = PdxTex2D( DecalDiffuseArray, float3( DecalUV, Data._DiffuseIndex ) );
							//Weight = DiffuseSample.a * Weight * TilingMaskSample;
							//Diffuse = BlendDecal( Data._DiffuseBlendMode, float4( Diffuse, 0.0f ), DiffuseSample, Weight ).rgb;
							WeightMatrix.x *= TilingMaskSample;

							// Eyes sample LOD0 to stop the decal from fading. TODO: encode the mips at a lower level and remove this.
							#ifdef EYE_DECAL
								float4 DiffuseSample = PdxTex2DLod0( DecalDiffuseArray, float3( DecalUV, Data._DiffuseIndex ) );
							#else
								float4 DiffuseSample = PdxTex2D( DecalDiffuseArray, float3( DecalUV, Data._DiffuseIndex ) );
							#endif

							// Multiplies WeightMatrix.x by DiffuseSample.a, as vanilla does with Weight
							DecodeDiffuseMIPs( Data._DiffuseIndex, DiffuseSample, DecalUV, Data, WeightMatrix, CustomBodyPart );

							Diffuse = BlendDecal( Data._DiffuseBlendMode, Diffuse, DiffuseSample, WeightMatrix.x );
							// END MOD
						}

						if ( Data._NormalIndex < MAX_VALUE )
						{
							// MOD(ek2) Weight -> WeightMatrix.x
							float3 NormalSample = UnpackDecalNormal( PdxTex2D( DecalNormalArray, float3( DecalUV, Data._NormalIndex ) ), WeightMatrix.x );
							Normals = BlendDecal( Data._NormalBlendMode, float4( Normals, 0.0f ), float4( NormalSample, 0.0f ), WeightMatrix.x ).xyz;
							// END MOD
						}

						if ( Data._PropertiesIndex < MAX_VALUE )
						{
							// MOD(ek2)
							//float4 PropertiesSample = PdxTex2D( DecalPropertiesArray, float3( DecalUV, Data._PropertiesIndex ) );
							//Properties = BlendDecal( Data._PropertiesBlendMode, Properties, PropertiesSample, Weight );
							#ifdef EYE_DECAL
								float4 PropertiesSample = PdxTex2DLod0( DecalPropertiesArray, float3( DecalUV, Data._PropertiesIndex ) );
							#else
								float4 PropertiesSample = PdxTex2D( DecalPropertiesArray, float3( DecalUV, Data._PropertiesIndex ) );
							#endif

							DecodePropertiesMIPs( Data._PropertiesIndex, Data, WeightMatrix.x, CustomBodyPart );

							Properties = BlendDecal( Data._PropertiesBlendMode, Properties, PropertiesSample, WeightMatrix.x );
							// END MOD
						}
					}
				}
			}

			Normals = normalize( Normals );
		}
	]]
}
