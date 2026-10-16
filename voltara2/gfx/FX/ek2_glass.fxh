# EK2 file. Glass shader for jomini/portrait.shader and court_scene.shader.
#
# The glass has two layers:
#   1. An outer layer. It refracts and reflects the environment cube map.
#   2. An inner layer. Multi-layer parallax, from the NifSkope Skyrim shader.
# A fresnel term blends the inner layer into the outer one, so the inner layer shows at
# straight angles and the reflection takes over at grazing angles.
#
# GlassMask (sampler index 5) controls the layers:
#   R = outer layer mask. 1 makes the outer layer full refraction and reflection.
#   G = inner layer mask. 1 makes the inner layer show the parallax texture.
#   B = inner layer depth. It scales INNER_THICKNESS for each pixel.
#   A = layer blend. 0 keeps the outer layer only.
# This is the same layout as the AGOT glass mask, so a mask works in both mods.
# InnerMap (sampler index 6):
#   RGB = the color inside the glass.
#   A   = parallax strength. The shader samples it without the offset. 0 pins the texel to
#         the surface, and 1 gives the full parallax travel.
#
# The asset file sets the values. Put them in the meshsettings block:
#   additional_shader_defines = {
#       "GLASS"
#       "GLASS_TILING float2(2.0f,2.0f)"
#       "OUTER_REFRACTION float(0.2f)"
#       "INNER_THICKNESS float(350.0f)"
#   }
# Each one has a fallback below, so an asset only needs the values that it changes.
#
# The portrait and the court use different lights, so the two shaders calculate the light
# themselves. Use the functions in this order:
#   1. EK2_GetGlassSurface()
#   2. Light _OuterMaterial, then EK2_GetGlassOuterColor().
#   3. Light _InnerMaterial, then EK2_BlendGlassLayers().

Includes = {
	"cw/utility.fxh"
	"jomini/jomini_lighting.fxh"
}

PixelShader =
{
	TextureSampler GlassMask
	{
		Index = 5
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}

	TextureSampler InnerMap
	{
		Index = 6
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}

	Code
	[[
		// Asset defines and their fallbacks. Each value is in one place only.

		// Tiling factor of the inner texture.
		float2 EK2_GlassTiling()
		{
			#ifdef GLASS_TILING
				return GLASS_TILING;
			#else
				return float2( 2.0f, 2.0f );
			#endif
		}

		// How much the normal map bends the parallax. 0.0 gives a flat inner layer, and
		// 1.0 makes the inner layer follow the normal map.
		float EK2_GlassOuterRefraction()
		{
			#ifdef OUTER_REFRACTION
				return OUTER_REFRACTION;
			#else
				return 0.2f;
			#endif
		}

		// Maximum depth of the parallax. The mask blue channel scales it per pixel.
		float EK2_GlassInnerThickness()
		{
			#ifdef INNER_THICKNESS
				return INNER_THICKNESS;
			#else
				return 350.0f;
			#endif
		}

		// Tightness of the rim reflection. Higher values keep the reflection at the edges.
		float EK2_GlassFresnelPower()
		{
			#ifdef GLASS_FRESNEL_POWER
				return GLASS_FRESNEL_POWER;
			#else
				return 1.5f;
			#endif
		}

		// Strength of the rim reflection.
		float EK2_GlassFresnelBrightness()
		{
			#ifdef GLASS_FRESNEL_BRIGHTNESS
				return GLASS_FRESNEL_BRIGHTNESS;
			#else
				return 1.0f;
			#endif
		}

		// Index of refraction. Glass is 1.52, water is 1.33 and diamond is 2.42.
		float EK2_GlassIOR()
		{
			#ifdef GLASS_IOR
				return GLASS_IOR;
			#else
				return 1.52f;
			#endif
		}

		// Flattens the normal of the inner layer to soften its light. 0.0 keeps the normal
		// map, and 1.0 makes the inner layer almost fullbright.
		float EK2_GlassNormalSmoothing()
		{
			#ifdef GLASS_NORMAL_SMOOTHING
				return GLASS_NORMAL_SMOOTHING;
			#else
				return 0.0f;
			#endif
		}

		// Parallax calculation based on NifScope implementation
		// Compute inner layer's texture coordinate
		// vTexCoord: Outer layer's texture coordinate
		// vInnerScale: Tiling of inner texture
		// vViewTS: View vector in tangent space
		// vNormalTS: Normal in tangent space (sampled normal map)
		// fLayerThickness: Distance from outer layer to inner layer
		float3 ParallaxOffset( float2 vTexCoord, float2 vInnerScale, float3 vViewTS, float3 vNormalTS, float fLayerThickness , float2 UV , float2 GlassMaskSize)
		{
			// Sample the non-parallax offset alpha channel of the inner map
			// Used to modulate the InnerThickness
			float InnerMapAlpha = PdxTex2D( InnerMap, UV * vInnerScale).a;
			// Tangent space reflection vector
			float3 vReflectionTS = reflect( -vViewTS, vNormalTS );
			// Tangent space transmission vector (reflect about surface plane)
			float3 vTransTS = float3(vReflectionTS.x, vReflectionTS.y, -vReflectionTS.z);
			// Distance along transmission vector to intersect inner layer
			float fTransDist = fLayerThickness / abs(vTransTS.z);

			float2 vTexelSize = float2( 1.0f/(GlassMaskSize.x * vInnerScale.x ), 1.0f/(GlassMaskSize.y * vInnerScale.y ) );

			// Inner layer's texture coordinate due to parallax
			float2 vOffset = vTexelSize * fTransDist * vTransTS.xy * InnerMapAlpha;
			float2 vOffsetTexCoord = vTexCoord + vOffset;

			// Return offset texture coordinate
			return float3( vOffsetTexCoord, fTransDist );
		}

		// Everything that the two glass layers need, except the light.
		struct SGlassSurface
		{
			float4 _Masks;					// The GlassMask sample
			float3 _OuterAlbedo;			// Refraction and reflection of the outer layer
			float _FresnelTerm;
			SMaterialProperties _OuterMaterial;
			SLightingProperties _OuterLighting;
			SMaterialProperties _InnerMaterial;
			SLightingProperties _InnerLighting;
		};

		// Normal is the shaded normal, from the normal map. VertexNormal, Tangent and
		// Bitangent come from the vertex shader and build the tangent frame.
		SGlassSurface EK2_GetGlassSurface(
			float4 Diffuse,
			float4 Properties,
			float3 Normal,
			float3 VertexNormal,
			float3 Tangent,
			float3 Bitangent,
			float3 WorldSpacePos,
			float2 UV0,
			float3 CameraPos,
			SMaterialProperties MaterialProps,
			SLightingProperties LightingProps,
			PdxTextureSamplerCube EnvironmentMap )
		{
			SGlassSurface Glass;
			Glass._Masks = PdxTex2D( GlassMask, UV0 );

			float3 ToCameraDir = normalize( CameraPos - WorldSpacePos );
			float NdotV = saturate( dot( ToCameraDir, Normal ) );
			Glass._FresnelTerm = pow( 1.0f - NdotV, EK2_GlassFresnelPower() ) * EK2_GlassFresnelBrightness();

			// Environment reflection
			float3 ReflectVector = reflect( ToCameraDir, Normal );
			ReflectVector.y = -ReflectVector.y;
			float4 CubeMap = PdxTexCube( EnvironmentMap, ReflectVector );

			// Refraction, tinted by the diffuse color
			float3 RefractVector = refract( ToCameraDir, -Normal, 1.0f / EK2_GlassIOR() );
			RefractVector.y = -RefractVector.y;
			RefractVector.z = -RefractVector.z;
			float4 RefractColor = PdxTexCube( EnvironmentMap, RefractVector );
			RefractColor.rgb *= Diffuse.rgb;

			Glass._OuterAlbedo = lerp( RefractColor, CubeMap, Glass._FresnelTerm * Properties.a ).rgb;

			// Outer layer material. Where the mask is white: no metalness, a white base color
			// and a smoother shadow.
			float OuterBlend = 1.0f - Glass._Masks.r;
			Glass._OuterMaterial = MaterialProps;
			Glass._OuterLighting = LightingProps;
			Glass._OuterLighting._ShadowTerm = lerp( 1.0f, LightingProps._ShadowTerm, OuterBlend );
			Glass._OuterMaterial._Metalness = lerp( 0.0f, MaterialProps._Metalness, OuterBlend );
			Glass._OuterMaterial._DiffuseColor = lerp( float3( 1.0f, 1.0f, 1.0f ), MaterialProps._DiffuseColor, OuterBlend );
			Glass._OuterMaterial._SpecularColor = lerp( float3( 1.0f, 1.0f, 1.0f ), MaterialProps._SpecularColor, OuterBlend );

			// Inner layer. Parallax, based on the NifSkope Skyrim multi-layer parallax shader.
			float3x3 TBN = Create3x3( normalize( Tangent ), normalize( Bitangent ), normalize( VertexNormal ) );
			float3x3 iTBN = transpose( TBN );
			float3 ToCameraDirTS = normalize( mul( ToCameraDir, iTBN ) );

			// Texel size
			float2 GlassMaskSize;
			float2 InnerSize;
			PdxTex2DSize( GlassMask, GlassMaskSize );
			PdxTex2DSize( InnerMap, InnerSize );
			float2 InnerScale = EK2_GlassTiling() * ( GlassMaskSize / InnerSize );

			// The shaded normal in tangent space. The tangent frame comes from the vertex
			// normal, so this is the tilt that the normal map adds. OUTER_REFRACTION mixes
			// it with the flat normal and bends the parallax by that much.
			float3 NormalTS = normalize( mul( Normal, iTBN ) );
			float3 MixedNormal = lerp( float3( 0.0f, 0.0f, 1.0f ), NormalTS, saturate( EK2_GlassOuterRefraction() ) );

			float InnerThickness = EK2_GlassInnerThickness();
			float3 Parallax = ParallaxOffset( UV0, InnerScale, ToCameraDirTS, MixedNormal, InnerThickness * Glass._Masks.b, UV0, GlassMaskSize );

			// Sample the inner map at the offset coords
			float3 Inner = PdxTex2D( InnerMap, Parallax.xy * InnerScale ).rgb;

			// Mix inner/outer layer based on fresnel
			float OuterMix = max( Glass._FresnelTerm * Glass._FresnelTerm * 2.0f, 1.0f - Glass._Masks.g );
			float3 InnerAlbedo = lerp( Inner, Diffuse.rgb, OuterMix );

			// Environment reflections
			InnerAlbedo += CubeMap.rgb * Properties.a;

			float InnerBlend = 1.0f - Glass._Masks.g;
			Glass._InnerMaterial = MaterialProps;
			Glass._InnerLighting = LightingProps;
			Glass._InnerMaterial._Metalness = lerp( 0.0f, MaterialProps._Metalness, InnerBlend );
			Glass._InnerMaterial._DiffuseColor = lerp( InnerAlbedo, MaterialProps._DiffuseColor, InnerBlend );
			Glass._InnerMaterial._SpecularColor = lerp( Diffuse.rgb, MaterialProps._SpecularColor, InnerBlend );
			// A flatter normal softens the light and makes the glass look translucent
			Glass._InnerMaterial._Normal = lerp( MaterialProps._Normal, float3( 0.0f, 0.0f, 1.0f ), min( EK2_GlassNormalSmoothing(), Glass._Masks.g ) );
			Glass._InnerLighting._ShadowTerm = lerp( 1.0f, LightingProps._ShadowTerm, InnerBlend );

			return Glass;
		}

		// OuterLighting is the light on Glass._OuterMaterial.
		float3 EK2_GetGlassOuterColor( SGlassSurface Glass, float3 OuterLighting )
		{
			float3 Albedo = lerp( Glass._OuterAlbedo, Glass._OuterAlbedo * 3.0f, OuterLighting );
			return lerp( Albedo, OuterLighting, 1.0f - Glass._Masks.r );
		}

		// InnerLighting is the light on Glass._InnerMaterial.
		float3 EK2_BlendGlassLayers( SGlassSurface Glass, float3 OuterColor, float3 InnerLighting )
		{
			return lerp( OuterColor, InnerLighting, saturate( Glass._FresnelTerm * 5.0f ) * Glass._Masks.a );
		}
	]]
}
