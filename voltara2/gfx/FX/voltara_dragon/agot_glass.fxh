Includes = {
	"voltara_dragon/cw/lighting.fxh"
	"voltara_dragon/cw/lighting_util.fxh"
	"voltara_dragon/jomini/portrait_lighting.fxh"
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

		float3 ComputeGlassShading(
		float3 Diffuse,
		float4 Properties,
		float3 Normal,
		float3x3 TBN,
		float3 CameraPos,
		in VS_OUTPUT_PDXMESHPORTRAIT Input,
		SMaterialProperties MaterialProps,
		SLightingProperties LightingProps,
		float2 TilingFactor,
		float OuterRefraction,
		float InnerThickness
		)
	{

		float3 DiffuseIBL = vec3(0.0);
		float3 SpecularIBL = vec3(0.0);
		float3 DiffuseLight = vec3(0.0);
		float3 SpecularLight = vec3(0.0);

		float4 GlassMasks = PdxTex2D( GlassMask, Input.UV0 );
		float3 ToCameraDir = normalize(CameraPos - Input.WorldSpacePos);

		//Convert CameraDir to Tangent Space with inverted TBN
		float3x3 iTBN = transpose( TBN );
		float3 ToCameraDirTS = normalize(mul(ToCameraDir, iTBN));

		float2 GlassMaskSize;
		float2 InnerSize;
		PdxTex2DSize(GlassMask, GlassMaskSize);
		PdxTex2DSize(InnerMap, InnerSize);
		TilingFactor *= GlassMaskSize / InnerSize;

		float3 NormalTS = normalize(mul(normalize(Input.Normal), iTBN));
		float3 MixedNormal = lerp(float3(0.0f,0.0f,1.0f), NormalTS, clamp(OuterRefraction, 0.0, 1.0));
		float3 Parallax = ParallaxOffset(Input.UV0, TilingFactor, ToCameraDirTS, MixedNormal, InnerThickness * GlassMasks.g, Input.UV0, GlassMaskSize);

		float3 Inner = PdxTex2D(InnerMap, Parallax.xy * TilingFactor).rgb;
        //float DepthHighlight = 1.0f-PdxTex2D(GlassMask,Parallax.xy).g;
        //Inner += DepthHighlight*0.5f;
		float DepthMultiplier = 0.75f;
		float SurfaceFactor = 1.0 - saturate(Parallax.z / InnerThickness*DepthMultiplier);
		Inner.rgb += SurfaceFactor;

		// Prepare material for parallax pass
		SMaterialProperties MaterialPropsParallax = MaterialProps;
		SLightingProperties LightingPropsParallax = LightingProps;

		MaterialPropsParallax._Metalness = 0.0f;
		MaterialPropsParallax._DiffuseColor = Inner;
		MaterialPropsParallax._SpecularColor = Inner;

		// Recompute lighting
		CalculateLightingFromIBL(MaterialPropsParallax, LightingPropsParallax, EnvironmentMap, DiffuseIBL, SpecularIBL);
		CalculatePortraitLights(Input.WorldSpacePos, LightingPropsParallax._ShadowTerm, MaterialPropsParallax, DiffuseLight, SpecularLight);

		float3 Color2 = DiffuseIBL + SpecularIBL + DiffuseLight + SpecularLight;
        return Color2;
	}	
	]]
}