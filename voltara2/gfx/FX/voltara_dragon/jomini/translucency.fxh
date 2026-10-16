PixelShader =
{
	Code
	[[
		struct STranslucencyProperties
		{
			float	_NormalDistortion;
			float	_ViewAndHelfAngleExponent;
			float	_TranslucencyStrength;
			float	_AmbientStrength;
			float	_DiffuseWrap;
			float	_ThicknessValue;
			float3 	_TranslucencyColor;
		};

		STranslucencyProperties GetDefaultTranslucencyProperties()
		{
			STranslucencyProperties TranslucencyProps;

			TranslucencyProps._NormalDistortion = 0.3f;
			TranslucencyProps._ViewAndHelfAngleExponent = 1.5f;
			TranslucencyProps._TranslucencyStrength = 1.0f;
			TranslucencyProps._AmbientStrength = 1.0f;
			TranslucencyProps._DiffuseWrap = 0.2f;
			TranslucencyProps._ThicknessValue = 0.5f;
			TranslucencyProps._TranslucencyColor = float3( 0.8f, 0.8f, 0.8f );

			return TranslucencyProps;
		}

		STranslucencyProperties GetTranslucencyProperties( float NormalDistortion, float ViewAndHelfAngleExponent, float TranslucencyStrength, float AmbientStrength, float DiffuseWrap, float ThicknessValue, float3 TranslucencyColor)
		{
			STranslucencyProperties TranslucencyProps;

			TranslucencyProps._NormalDistortion = NormalDistortion;
			TranslucencyProps._ViewAndHelfAngleExponent = ViewAndHelfAngleExponent;
			TranslucencyProps._TranslucencyStrength = TranslucencyStrength;
			TranslucencyProps._AmbientStrength = AmbientStrength;
			TranslucencyProps._DiffuseWrap = DiffuseWrap;
			TranslucencyProps._ThicknessValue = ThicknessValue;
			TranslucencyProps._TranslucencyColor = TranslucencyColor;

			return TranslucencyProps;
		}

		float3 CalculateLightingTranslucent( SMaterialProperties MaterialProps, SLightingProperties LightingProps, STranslucencyProperties TranslucencyProps, float3 DiffuseIBL )
		{ 
			float3 ToLightDir = LightingProps._ToLightDir;
			float3 ToCameraDir = LightingProps._ToCameraDir;
			float3 SurfaceNormal  = MaterialProps._Normal;
			float3 HalfVector  = normalize( ToLightDir + SurfaceNormal  * TranslucencyProps._NormalDistortion );
			float NdotL = max( 0.0f ,( dot( SurfaceNormal , ToLightDir ) + TranslucencyProps._DiffuseWrap ) / ( 1.0f + TranslucencyProps._DiffuseWrap ) );
			float VdotH = pow( saturate( dot( ToCameraDir, -HalfVector  ) ), TranslucencyProps._ViewAndHelfAngleExponent + 1e-5 );
			float3 LightAttenuation = LightingProps._LightIntensity * saturate( LightingProps._ShadowTerm + TranslucencyProps._DiffuseWrap * TranslucencyProps._ThicknessValue * 0.2f );
			float3 IndirectLighting = ( VdotH + DiffuseIBL * TranslucencyProps._AmbientStrength );

			float3 TranslucentOut = TranslucencyProps._TranslucencyStrength * ( ( IndirectLighting + NdotL ) * LightAttenuation * TranslucencyProps._ThicknessValue ) * MaterialProps._DiffuseColor * TranslucencyProps._TranslucencyColor.rgb;

			return TranslucentOut;
		}
	]]
}