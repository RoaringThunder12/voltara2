# EK2 file. The portrait features that jomini/portrait.shader and court_scene.shader share.
#
# The two shaders are twins: the portrait widget uses the first and the royal court uses the
# second. Both call these functions, so a change applies to both.
# jomini/portrait_accessory_variation.fxh uses the clothes decay too.
#
# Each feature reads a control decal. See "MIP-6 markers" in SHADERS.md for the marker codes.
# The weight of a control decal is the same for all pixels of a draw, so a branch on the
# weight is coherent and cheap.
#
# The shader that includes this file must have:
#   - Constant buffer 5 with vPaletteColorSkin, vPaletteColorHair, vPaletteColorEyes and
#     DecalCount.
#   - The samplers DecalDiffuseArray (from jomini/portrait_decals.fxh) and SSAOColorMap.

Includes = {
	"cw/utility.fxh"
	"ek2_portrait_decals.fxh"
}

PixelShader =
{
	Code
	[[
		// The skin color of the mesh.
		// SKIN_TO_HAIR_COLOR: the mesh uses the hair color, not the skin color (tails, horns).
		// Fur color transition: the weight of the MAGENTA control decal blends the skin color
		// to the hair color. It starts from the color above, so SKIN_TO_HAIR_COLOR stays.
		float3 EK2_GetSkinPaletteColor()
		{
			float3 SkinColorPalette = vPaletteColorSkin.rgb;
			#ifdef SKIN_TO_HAIR_COLOR
				SkinColorPalette = vPaletteColorHair.rgb;
			#endif

			DecalData Data = GetDecalData( MAGENTA, DIFFUSE_DECAL, DecalCount );
			return lerp( SkinColorPalette, vPaletteColorHair.rgb, Data._Weight );
		}

		// Skeleton transition. The control decal is YELLOW for the head and (0,0.5,0) for the
		// body. Its weight darkens the skin and then makes it transparent. The skeleton
		// accessory below shows through. Returns the alpha of the skin.
		float EK2_ApplySkeletonTransition( inout float4 Diffuse, float2 UV0 )
		{
			float3 DecalMarker = float3( 0.0f, 0.5f, 0.0f );
			#ifdef FACE_TEXTURE
				DecalMarker = YELLOW;
			#endif
			DecalData Data = GetDecalData( DecalMarker, DIFFUSE_DECAL, DecalCount );
			float Weight = Data._Weight;

			float SkinAlpha = 1.0f;
			if ( Weight > 0.0f )
			{
				// R - CURVATURE
				// G - THICKNESS
				// B - AO
				// A - GRUNGE
				float4 TransitionMask = PdxTex2D( DecalDiffuseArray, float3( UV0, Data._DiffuseIndex ) );

				float DarkenMask = Overlay(Overlay(Overlay(lerp(0.0f,1.0f,smoothstep(TransitionMask.g,TransitionMask.g+0.4f,Weight*1.3f)),TransitionMask.r),TransitionMask.a),1.0f-TransitionMask.b);
				Diffuse.rgb = lerp(Diffuse.rgb*0.25f, Diffuse.rgb,smoothstep(DarkenMask,DarkenMask+0.6f,1.0f-Weight));

				float WearMask = Overlay(Overlay(Overlay(lerp(0.0f,1.0f,smoothstep(TransitionMask.g,TransitionMask.g+0.3f,Weight)),TransitionMask.r),TransitionMask.a),1.0f-TransitionMask.b);
				SkinAlpha = smoothstep(WearMask, WearMask+0.1f,1.0f-Weight);
			}
			Diffuse.a = SkinAlpha;
			return SkinAlpha;
		}

		// Eye decals, part 1. Draw the decals that go below the eye color, and keep the base
		// diffuse where the base texture is opaque.
		void EK2_AddEyeDecalsBelowColor( inout float4 Diffuse, inout float3 NormalSample, inout float4 Properties, float2 UV0, uint InstanceIndex )
		{
			#ifdef EYE_DECAL
				float4 BaseDiffuse = Diffuse;
				AddDecals( Diffuse, NormalSample, Properties, UV0, InstanceIndex, 0, PreSkinColorDecalCount, BODYPART_EYES );
				Diffuse.rgb = lerp( Diffuse, BaseDiffuse, BaseDiffuse.a ).rgb;
			#endif
		}

		// Eye decals, part 2. Draw the decals that go above the eye color.
		void EK2_AddEyeDecalsAboveColor( inout float4 Diffuse, inout float3 NormalSample, inout float4 Properties, float2 UV0, uint InstanceIndex )
		{
			#ifdef EYE_DECAL
				AddDecals( Diffuse, NormalSample, Properties, UV0, InstanceIndex, PreSkinColorDecalCount, DecalCount, BODYPART_EYES );
			#endif
		}

		// The eye color of the mesh. HSV_SHIFT turns the hue around for beast eyes.
		float3 EK2_GetEyeColor()
		{
			float3 EyeColor = vPaletteColorEyes.rgb;
			#ifdef HSV_SHIFT
				EyeColor = RGBtoHSV( EyeColor );
				EyeColor.x = EyeColor.x + 0.5f;
				EyeColor = saturate( HSVtoRGB( EyeColor ) );
			#endif
			return EyeColor;
		}

		// Clothes decay. The weight of the RED control decal makes clothes dirty, worn and
		// rusty. The caller reads the decal and calls this only when the weight is above 0.
		//
		// The three call sites use different masks, so the caller gives them:
		//   UVOffset:        offset of the decay masks. Variations offset by the pattern
		//                    random number, so that two meshes do not decay the same way.
		//   RustFactor:      where rust and dirt can go. Cloth does not rust.
		//   RoughnessFactor: where the rust makes the surface rough.
		//   WearFactor:      where the fabric wears out and gets holes. Metal does not wear.
		//   FabricColor:     the color of the worn fabric.
		//   FabricWeight:    the strength of the worn fabric color.
		void EK2_ApplyClothesDecay(
			inout float4 Diffuse,
			inout float4 Properties,
			float3 NormalSample,
			float2 UV0,
			float2 UVOffset,
			DecalData Data,
			float RustFactor,
			float RoughnessFactor,
			float WearFactor,
			float3 FabricColor,
			float FabricWeight )
		{
			float Weight = Data._Weight;

			// R - WET MASK
			// G - THICK DIRT MASK
			// B - RUST MASK
			// A - WORN FABRIC MASK
			float4 DiffuseDecayMask2x = PdxTex2D( DecalDiffuseArray, float3( UVOffset + UV0 * 2.0f, Data._DiffuseIndex ) );
			float4 DiffuseDecayMask3x = PdxTex2D( DecalDiffuseArray, float3( UVOffset + UV0 * 3.0f, Data._DiffuseIndex ) );

			// Rust
			float3 RustMask = float3(0.4f,0.2f,0.13f);
			RustMask = RustMask * (DiffuseDecayMask3x.bbb);
			RustMask = Overlay( Diffuse.rgb, RustMask,1.0f );

			float RustRoughness = DiffuseDecayMask2x.b*DiffuseDecayMask3x.b;

			Diffuse.rgb = lerp(Diffuse.rgb,RustMask,smoothstep(DiffuseDecayMask2x.b,DiffuseDecayMask2x.b+0.2f,Weight*0.8f)*RustFactor);
			Properties.a = lerp(Properties.a,1.0f,smoothstep(RustRoughness,RustRoughness+0.3f,Weight*0.4)*RoughnessFactor);

			// Worn out fabrics
			float FabricMask = saturate(0.6f-DiffuseDecayMask2x.a);

			Diffuse.rgb = lerp(Diffuse.rgb,FabricColor,smoothstep(FabricMask,FabricMask+0.3f,(Weight*FabricWeight)*WearFactor*0.7f));

			Properties.b = lerp(Properties.b,0.0f,smoothstep(FabricMask,FabricMask+0.3f,(Weight*0.4f)*WearFactor));
			Properties.a = lerp(Properties.a,1.0f,smoothstep(FabricMask,FabricMask+0.3f,(Weight*0.4f)*WearFactor));

			// Holes in fabrics
			float WearMask = abs(0.8f-DiffuseDecayMask2x.a);
			Diffuse.a = lerp(Diffuse.a,0.0f,step(WearMask,Weight*0.3f)*WearFactor);

			// Stains in fabric
			float StainMask = saturate(DiffuseDecayMask3x.r*5.0f);
			Diffuse.rgb = Multiply(Diffuse.rgb,float3(StainMask,StainMask,StainMask), clamp(Weight*2.0f,0.0f,1.0f));

			// Layers of dirt
			float DirtMask = clamp( NormalSample.b * NormalSample.b, 0, 1 );
			DirtMask = max(DirtMask,DiffuseDecayMask3x.g*1.5f);
			float3 DirtDiffuse = float3(0.2f,0.1f,0.06f);

			DirtDiffuse *= Diffuse.rgb;
			Diffuse.rgb = lerp(Diffuse.rgb,DirtDiffuse,smoothstep(DirtMask*0.5f,DirtMask*1.5f,clamp(Weight*1.6f,0.0f,1.0f)));
		}

		// Salt and pepper hair. The weight of the GREEN control decal blends the colored hair
		// to the uncolored (white) hair texture.
		void EK2_ApplyHairAging( inout float4 Diffuse, float2 UV0, PdxTextureSampler2D DiffuseMap )
		{
			#ifdef HAIR_AGING_DECAL
				DecalData Data = GetDecalData( GREEN, DIFFUSE_DECAL, DecalCount );
				float Weight = Data._Weight;

				if ( Weight > 0.0f )
				{
					float4 BaseDiffuse = PdxTex2D( DiffuseMap, UV0 );
					Diffuse.rgb = lerp( Diffuse.rgb, BaseDiffuse.ggg, step( ( 1.0f - Weight ), saturate( BaseDiffuse.r ) ) * Diffuse.a * ( Weight ) * 0.7f );
				}
			#endif
		}

		// Emissive. The mask makes the light on the mesh give way to the diffuse color.
		// EMISSIVE_NORMAL_BLUE: the mask is the blue channel of the normal map.
		// EMISSIVE_PROPERTIES_RED: the mask is the red channel of the properties map.
		void EK2_ApplyEmissive( inout float3 Color, float3 DiffuseColor, float4 Properties, float2 UV0, PdxTextureSampler2D NormalMap )
		{
			#ifdef EMISSIVE_NORMAL_BLUE
			{
				float EmissiveMask = PdxTex2D( NormalMap, UV0 ).b;
				Color = lerp( Color, DiffuseColor, EmissiveMask );
			}
			#endif
			#ifdef EMISSIVE_PROPERTIES_RED
			{
				float EmissiveMask = Properties.r;
				Color = lerp( Color, DiffuseColor, EmissiveMask );
			}
			#endif
		}
	]]
}
