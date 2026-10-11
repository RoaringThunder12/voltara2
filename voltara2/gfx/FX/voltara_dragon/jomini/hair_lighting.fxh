PixelShader =
{
	Code
	[[
		struct SHairProperties
		{
			float2	_UVs;
			float3	_PrimaryTangent;
			float3	_SecondaryTangent;
			float3	_EdgeColor;
			float	_SpecularPower;
			float	_SmoothnessMin;
			float	_SmoothnessMax;
			float	_ColorMaskStrength;
		};

		struct SCharacterHairSettings
		{
			float4 _EdgeColor;
			float3 _StrandDirection;
			float _PrimaryHighlightShift;
			float2 _AnisotropyShiftScale;
			float _AnisotropySmoothnessMin;
			float _AnisotropySmoothnessMax;
			float _SecondaryHighlightShift;
			float _NormalStrength;
			float _SpecularPower;
			float _AlphaCutoffTreshold;
			float _RoughnessMin;
			float _RoughnessMax;
		};

		//Using the idea described in this presentation: https://web.engr.oregonstate.edu/~mjb/cs519/Projects/Papers/HairRendering.pdf
		float3 ShiftTangent( float3 T, float3 N, float Shift )
		{
			return normalize( T + N * Shift );
		}

		float3 GetHairSpecularDominantDir( float3 Normal, float3 Reflection, float SpecularExponent )
		{
			return normalize( lerp( Normal, Reflection, SpecularExponent ) );
		}

		float RoughnessToSpecularExponent( float Roughness )
		{
			return clamp( 2.0f * rcp( lerp( 0.03f, 1.0f, Roughness * Roughness ) ) - 2.0f, 1.19209290E-07F, rcp( 1.19209290E-07F ) );
		}

		void CalculateHairSpecularIBL( SMaterialProperties MaterialProps, SLightingProperties LightingProps, SHairProperties HairProps, PdxTextureSamplerCube EnvironmentMap, out float3 SpecularIBLOut )
		{
			float3 ReflectionVector = reflect( LightingProps._ToCameraDir, HairProps._PrimaryTangent );
			float Exponent = RoughnessToSpecularExponent( MaterialProps._Roughness );
			float3 DominantReflectionVector = GetHairSpecularDominantDir( HairProps._PrimaryTangent, ReflectionVector, Exponent );

			float NdotR = saturate( dot( HairProps._PrimaryTangent, DominantReflectionVector ) );
			float3 SpecularReflection = F_Schlick( MaterialProps._SpecularColor, MaterialProps._SpecularColor, NdotR );
			float SpecularFade = GetReductionInMicrofacets( MaterialProps._Roughness );

			float MipLevel = BurleyToMipSimple( MaterialProps._PerceptualRoughness );
			float3 RotatedSpecularCubemapUV = mul( CastTo3x3( LightingProps._CubemapYRotation ), DominantReflectionVector );
			float3 SpecularRad = PdxTexCubeLod( EnvironmentMap, RotatedSpecularCubemapUV, MipLevel ).rgb; 

			SpecularRad *= LightingProps._CubemapIntensity;

			SpecularIBLOut = SpecularRad * SpecularFade * SpecularReflection /** EdgeDarkening*/;
		}

		float D_Anisotropic( float3 T, float3 H, float Exponent )
		{
			float TdotH = dot( T, H );
			float DirectionAttenuation = saturate( TdotH + 1.0f ); //JLS: I think this looks neat but I'm not actually sure how badly we need it
			float f = ( TdotH * Exponent - TdotH ) * TdotH + 1.0f;
			return DirectionAttenuation * Exponent / ( PI * f * f );
		}

		void CalculateHairLightingFromLight( SMaterialProperties MaterialProps, float3 ToCameraDir, float3 ToLightDir, float3 LightIntensity, SHairProperties HairProps, out float3 DiffuseOut, out float3 SpecularOut)
		{
			float3 H = normalize( ToCameraDir + ToLightDir );
			float NdotV = saturate( dot( MaterialProps._Normal + 1e-5, ToCameraDir + 1e-5 ) );
			float NdotL = saturate( lerp ( 0.05f, 1.0f, dot( MaterialProps._Normal, ToLightDir ) ) ) + 1e-5; //Tweaked term according to https://web.engr.oregonstate.edu/~mjb/cs519/Projects/Papers/HairRendering.pdf
			float LdotH = saturate( dot( ToLightDir, H ) );
			float LdotV = dot( ToLightDir, ToCameraDir );
			float NdotH = saturate( dot( MaterialProps._Normal, H ) );
			float DiffuseBRDF = CalcDiffuseBRDF( NdotV, NdotL, LdotH, MaterialProps._Roughness );
			DiffuseOut = DiffuseBRDF * MaterialProps._DiffuseColor * LightIntensity * NdotL;

			//If this part is not hair but rather something like earrings, then we use the default calculation.
			if( HairProps._ColorMaskStrength == 0 )
			{
				float3 SpecularBRDF = CalcSpecularBRDF( MaterialProps._SpecularColor, LdotH, NdotH, NdotL, NdotV, MaterialProps._Roughness );
				SpecularOut = SpecularBRDF * LightIntensity * NdotL;
			}
			else
			{
				float Exponent = RoughnessToSpecularExponent( lerp( 0.0f, 0.6f, MaterialProps._Roughness ) );
				float Gradient = 1.0f - abs( HairProps._UVs.y - 0.5f ) * 2.0f;
				float3 EdgeDarkening = saturate( pow( lerp( HairProps._EdgeColor, 1.0f, Gradient ), 2.0f ) * 2.0f );
				NdotL = lerp( 0.05f, 1.0f, NdotL );
				float3 F = F_Schlick( LightIntensity * MaterialProps._SpecularColor, LightIntensity * MaterialProps._SpecularColor * 1.5f, NdotV ); //Acts as a sort of translucency as well as light scattering
				float Vis = V_Schlick( NdotL, NdotV, lerp( 0.8f, 1.0f, MaterialProps._PerceptualRoughness ) );

				float3 Specular1 = D_Anisotropic( HairProps._PrimaryTangent, H, lerp( 0.03f, 1.0f, Exponent ) ) * EdgeDarkening;
				float3 Specular2 = D_Anisotropic( HairProps._SecondaryTangent, H, lerp( 0.03f, 1.0f, Exponent ) ) * EdgeDarkening * MaterialProps._DiffuseColor;
				
				float3 Translucency = saturate( 1.0f - NdotV ) * saturate( -LdotV );
				SpecularOut = ( Specular1 + Specular2 + Translucency ) * F * Vis * NdotL * HairProps._SpecularPower;
			}
		}
		void CalculateHairLightingFromLight( SMaterialProperties MaterialProps, SLightingProperties LightingProps, SHairProperties HairProps, out float3 DiffuseOut, out float3 SpecularOut )
		{
			CalculateHairLightingFromLight( MaterialProps, LightingProps._ToCameraDir, LightingProps._ToLightDir, LightingProps._LightIntensity * LightingProps._ShadowTerm, HairProps, DiffuseOut, SpecularOut );
		}


		void CalculateHairLightingFromAreaLight( SMaterialProperties MaterialProps, float3 ToCameraDir, float3 ToLightDir, float3 LightIntensity, SHairProperties HairProps, out float3 DiffuseOut, out float3 SpecularOut, float3 SpecToLightDir )
		{
			float3 H = normalize( ToCameraDir + ToLightDir );
			float NdotV = saturate( dot( MaterialProps._Normal + 1e-5, ToCameraDir + 1e-5 ) );
			float NdotL = saturate( lerp ( 0.05f, 1.0f, dot( MaterialProps._Normal, ToLightDir ) ) ) + 1e-5;
			float LdotH = saturate( dot( ToLightDir, H ) );
			float LdotV = dot( ToLightDir, ToCameraDir );
			float NdotH = saturate( dot( MaterialProps._Normal, H ) );
			float DiffuseBRDF = CalcDiffuseBRDF( NdotV, NdotL, LdotH, MaterialProps._Roughness );
			DiffuseOut = DiffuseBRDF * MaterialProps._DiffuseColor * LightIntensity * NdotL;

			H = normalize( ToCameraDir + SpecToLightDir );
			NdotL = saturate( dot( MaterialProps._Normal, SpecToLightDir ) ) + 1e-5;
			NdotH = saturate( dot( MaterialProps._Normal, H ) );
			LdotH = saturate( dot( SpecToLightDir, H ) );
			//If this part is not hair but rather something like earrings, then we use the default calculation.
			if( HairProps._ColorMaskStrength == 0 )
			{
				float3 SpecularBRDF = CalcSpecularBRDF( MaterialProps._SpecularColor, LdotH, NdotH, NdotL, NdotV, MaterialProps._Roughness );
				SpecularOut = SpecularBRDF * LightIntensity * NdotL;
			}
			else
			{
				float Exponent = RoughnessToSpecularExponent( lerp( 0.0f, 0.6f, MaterialProps._Roughness ) );
				float Gradient = 1.0f - abs( HairProps._UVs.y - 0.5f ) * 2.0f;
				float3 EdgeDarkening = saturate( pow( lerp( HairProps._EdgeColor, 1.0f, Gradient ), 2.0f ) * 2.0f );
				NdotL = lerp( 0.05f, 1.0f, NdotL );
				float3 F = F_Schlick( LightIntensity * MaterialProps._SpecularColor, LightIntensity * MaterialProps._SpecularColor * 1.5f, NdotV ); //Acts as a sort of translucency as well as light scattering
				float Vis = V_Schlick( NdotL, NdotV, lerp( 0.8f, 1.0f, MaterialProps._PerceptualRoughness ) );

				float3 Specular1 = D_Anisotropic( HairProps._PrimaryTangent, H, lerp( 0.03f, 1.0f, Exponent ) ) * EdgeDarkening;
				float3 Specular2 = D_Anisotropic( HairProps._SecondaryTangent, H, lerp( 0.03f, 1.0f, Exponent ) ) * EdgeDarkening * MaterialProps._DiffuseColor;
				
				float3 Translucency = saturate( 1.0f - NdotV ) * saturate( -LdotV );
				SpecularOut = ( Specular1 + Specular2 + Translucency ) * F * Vis * NdotL * HairProps._SpecularPower;
			}
		}

		void CalculateHairLightingFromAreaLight( SMaterialProperties MaterialProps, SLightingProperties LightingProps, SHairProperties HairProps, out float3 DiffuseOut, out float3 SpecularOut, float3 SpecToLightDir )
		{
			CalculateHairLightingFromAreaLight( MaterialProps, LightingProps._ToCameraDir, LightingProps._ToLightDir, LightingProps._LightIntensity * LightingProps._ShadowTerm, HairProps, DiffuseOut, SpecularOut, SpecToLightDir );
		}


	]]
}
