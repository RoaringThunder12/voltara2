Includes = {
	"voltara_dragon/jomini/translucency.fxh"
}

Code
[[
	#define LIGHT_COUNT 3
	#define LIGHT_TYPE_NONE 0
	#define LIGHT_TYPE_DIRECTIONAL 1
	#define LIGHT_TYPE_SPOTLIGHT 2
	#define LIGHT_TYPE_POINTLIGHT 3
]]
PixelShader =
{
	Code
	[[
		struct SPortraitPointLight
		{
			float3 _Position;
			float _Radius;
			float3 _Color;
			float _Falloff;
		};
		struct SPortraitSpotLight
		{
			SPortraitPointLight	_PointLight;
			float3 _ConeDirection;
			float _ConeInnerCosAngle;
			float _ConeOuterCosAngle;
		};

		SPortraitPointLight GetPortraitPointLight( float4 PositionAndRadius, float4 ColorAndFalloff )
		{
			SPortraitPointLight PointLight;
			PointLight._Position = PositionAndRadius.xyz;
			PointLight._Radius = PositionAndRadius.w;
			PointLight._Color = ColorAndFalloff.xyz;
			PointLight._Falloff = ColorAndFalloff.w;
			return PointLight;
		}
	
		SPortraitSpotLight GetPortraitSpotLight( float4 PositionAndRadius, float4 ColorAndFalloff, float3 Direction, float InnerCosAngle, float OuterCosAngle )
		{
			SPortraitSpotLight Ret;
			Ret._PointLight = GetPortraitPointLight( PositionAndRadius, ColorAndFalloff );
			Ret._ConeDirection = Direction;
			Ret._ConeInnerCosAngle = InnerCosAngle;
			Ret._ConeOuterCosAngle = OuterCosAngle;
			return Ret;
		}
		
		void GGXPointLight( SPortraitPointLight Pointlight, float3 WorldSpacePos, float ShadowTerm, SMaterialProperties MaterialProps, inout float3 DiffuseLightOut, inout float3 SpecularLightOut )
		{
			float3 PosToLight = Pointlight._Position - WorldSpacePos;
			float DistanceToLight = length( PosToLight );

			float LightIntensity = CalcLightFalloff( Pointlight._Radius, DistanceToLight, Pointlight._Falloff );
			if ( LightIntensity > 0.0f )
			{
				SLightingProperties LightingProps;
				LightingProps._ToCameraDir = normalize( CameraPosition - WorldSpacePos );
				LightingProps._ToLightDir = PosToLight / DistanceToLight;
				LightingProps._LightIntensity = Pointlight._Color * LightIntensity;
				LightingProps._ShadowTerm = ShadowTerm;
				LightingProps._CubemapIntensity = 0.0f;
				LightingProps._CubemapYRotation = Float4x4Identity();
				
				float3 DiffuseLight;
				float3 SpecularLight;
				CalculateLightingFromLight( MaterialProps, LightingProps, DiffuseLight, SpecularLight );
				DiffuseLightOut += DiffuseLight;
				SpecularLightOut += SpecularLight;
			}
		}
		
		void GGXSpotLight( SPortraitSpotLight Spot, float3 WorldSpacePos, float ShadowTerm, SMaterialProperties MaterialProps, inout float3 DiffuseLightOut, inout float3 SpecularLightOut )
		{
			float3 	PosToLight = Spot._PointLight._Position - WorldSpacePos;
			float 	DistanceToLight = length(PosToLight);
			float3	ToLightDir = PosToLight / DistanceToLight;
			
			float LightIntensity = CalcLightFalloff( Spot._PointLight._Radius, DistanceToLight, Spot._PointLight._Falloff );
			float PdotL = dot( -ToLightDir, Spot._ConeDirection );
			LightIntensity *= smoothstep( Spot._ConeOuterCosAngle, Spot._ConeInnerCosAngle, PdotL );
			if ( LightIntensity > 0.0f )
			{
				SLightingProperties LightingProps;
				LightingProps._ToCameraDir = normalize( CameraPosition - WorldSpacePos );
				LightingProps._ToLightDir = ToLightDir;
				LightingProps._LightIntensity = Spot._PointLight._Color * LightIntensity;
				LightingProps._ShadowTerm = ShadowTerm;
				LightingProps._CubemapIntensity = 0.0f;
				LightingProps._CubemapYRotation = Float4x4Identity();
				
				float3 DiffuseLight;
				float3 SpecularLight;
				CalculateLightingFromLight( MaterialProps, LightingProps, DiffuseLight, SpecularLight );
				DiffuseLightOut += DiffuseLight;
				SpecularLightOut += SpecularLight;
			}
		}

		void CalculatePortraitLights( float3 WorldSpacePos, float ShadowTerm, SMaterialProperties MaterialProps, inout float3 DiffuseLightOut, inout float3 SpecularLightOut )
		{
			for( int i = 0; i < LIGHT_COUNT; ++i )
			{
				float3 DiffuseLight = vec3( 0.0f );
				float3 SpecularLight = vec3( 0.0f );
				
				//Scale color by ShadowTerm
				float4 Color_Falloff = Light_Color_Falloff[ i ];
				float LightShadowTerm = Light_InnerCone_OuterCone_AffectedByShadows[ i ].z > 0.5f ? ShadowTerm : 1.0f;

				if( Light_Direction_Type[ i ].w == LIGHT_TYPE_SPOTLIGHT )
				{
					float InnerAngle = Light_InnerCone_OuterCone_AffectedByShadows[ i ].x;
					float OuterAngle = Light_InnerCone_OuterCone_AffectedByShadows[ i ].y;
					SPortraitSpotLight Spot = GetPortraitSpotLight( Light_Position_Radius[ i ], Color_Falloff, Light_Direction_Type[ i ].xyz, InnerAngle, OuterAngle );
					GGXSpotLight( Spot, WorldSpacePos, LightShadowTerm, MaterialProps, DiffuseLight, SpecularLight );
				}
				else if( Light_Direction_Type[ i ].w == LIGHT_TYPE_POINTLIGHT )
				{
					SPortraitPointLight Light = GetPortraitPointLight( Light_Position_Radius[ i ], Color_Falloff );
					GGXPointLight( Light, WorldSpacePos, LightShadowTerm, MaterialProps, DiffuseLight, SpecularLight );
				}
				else if( Light_Direction_Type[ i ].w == LIGHT_TYPE_DIRECTIONAL )
				{
					SLightingProperties LightingProps;
					LightingProps._ToCameraDir = normalize( CameraPosition - WorldSpacePos );
					LightingProps._ToLightDir = -Light_Direction_Type[ i ].xyz;
					LightingProps._LightIntensity = Color_Falloff.rgb;
					LightingProps._ShadowTerm = LightShadowTerm;
					LightingProps._CubemapIntensity = 0.0f;
					LightingProps._CubemapYRotation = Float4x4Identity();

					CalculateLightingFromLight( MaterialProps, LightingProps, DiffuseLight, SpecularLight );
				}
				
				DiffuseLightOut += DiffuseLight;
				SpecularLightOut += SpecularLight;
			}
		}

		float3 CalculatePortraitTranslucentLights( float3 WorldSpacePos, float ShadowTerm, SMaterialProperties MaterialProps, STranslucencyProperties TranslucencyProps, float3 DiffuseIBL )
		{
			float3 DiffuseTranslucencyOut = vec3( 0.0f );
			for( int i = 0; i < LIGHT_COUNT; ++i )
			{
				//Scale color by ShadowTerm
				float4 Color_Falloff = Light_Color_Falloff[ i ];
				float LightShadowTerm = Light_InnerCone_OuterCone_AffectedByShadows[ i ].z > 0.5f ? ShadowTerm : 1.0f;

				if( Light_Direction_Type[ i ].w == LIGHT_TYPE_SPOTLIGHT )
				{
					float InnerAngle = Light_InnerCone_OuterCone_AffectedByShadows[ i ].x;
					float OuterAngle = Light_InnerCone_OuterCone_AffectedByShadows[ i ].y;
					SPortraitSpotLight Spot = GetPortraitSpotLight( Light_Position_Radius[ i ], Color_Falloff, Light_Direction_Type[ i ].xyz, InnerAngle, OuterAngle );
					float3 	PosToLight = Spot._PointLight._Position - WorldSpacePos;
					float 	DistanceToLight = length(PosToLight);
					float3	ToLightDir = PosToLight / DistanceToLight;
					
					float LightIntensity = CalcLightFalloff( Spot._PointLight._Radius, DistanceToLight, Spot._PointLight._Falloff );
					float PdotL = dot( -ToLightDir, Spot._ConeDirection );
					LightIntensity *= smoothstep( Spot._ConeOuterCosAngle, Spot._ConeInnerCosAngle, PdotL );
					if ( LightIntensity > 0.0f )
					{
						SLightingProperties LightingProps;
						LightingProps._ToCameraDir = normalize( CameraPosition - WorldSpacePos );
						LightingProps._ToLightDir = ToLightDir;
						LightingProps._LightIntensity = Spot._PointLight._Color * LightIntensity;
						LightingProps._ShadowTerm = ShadowTerm;
						LightingProps._CubemapIntensity = 0.0f;
						LightingProps._CubemapYRotation = Float4x4Identity();

						DiffuseTranslucencyOut += CalculateLightingTranslucent( MaterialProps , LightingProps, TranslucencyProps, DiffuseIBL );
					}
				}
				else if( Light_Direction_Type[ i ].w == LIGHT_TYPE_POINTLIGHT )
				{
					SPortraitPointLight Pointlight = GetPortraitPointLight( Light_Position_Radius[ i ], Color_Falloff );
					float3 PosToLight = Pointlight._Position - WorldSpacePos;
					float DistanceToLight = length( PosToLight );

					float LightIntensity = CalcLightFalloff( Pointlight._Radius, DistanceToLight, Pointlight._Falloff );
					if ( LightIntensity > 0.0f )
					{
						SLightingProperties LightingProps;
						LightingProps._ToCameraDir = normalize( CameraPosition - WorldSpacePos );
						LightingProps._ToLightDir = PosToLight / DistanceToLight;
						LightingProps._LightIntensity = Pointlight._Color * LightIntensity;
						LightingProps._ShadowTerm = ShadowTerm;
						LightingProps._CubemapIntensity = 0.0f;
						LightingProps._CubemapYRotation = Float4x4Identity();

						DiffuseTranslucencyOut += CalculateLightingTranslucent( MaterialProps , LightingProps, TranslucencyProps, DiffuseIBL );
					}
				}
				else if( Light_Direction_Type[ i ].w == LIGHT_TYPE_DIRECTIONAL )
				{
					SLightingProperties LightingProps;
					LightingProps._ToCameraDir = normalize( CameraPosition - WorldSpacePos );
					LightingProps._ToLightDir = -Light_Direction_Type[ i ].xyz;
					LightingProps._LightIntensity = Color_Falloff.rgb;
					LightingProps._ShadowTerm = LightShadowTerm;
					LightingProps._CubemapIntensity = 0.0f;
					LightingProps._CubemapYRotation = Float4x4Identity();

					DiffuseTranslucencyOut += CalculateLightingTranslucent( MaterialProps , LightingProps, TranslucencyProps, DiffuseIBL );
				}
			}
			return DiffuseTranslucencyOut;
		}
	]]
}
