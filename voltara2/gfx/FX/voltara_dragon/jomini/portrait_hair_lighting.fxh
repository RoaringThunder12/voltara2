Includes = {
	"voltara_dragon/jomini/portrait_lighting.fxh"
	"voltara_dragon/jomini/hair_lighting.fxh"
}

PixelShader =
{
	Code
	[[
		void CalculateHairLights( float3 WorldSpacePos, float ShadowTerm, SMaterialProperties MaterialProps, SHairProperties HairProps, inout float3 DiffuseLightOut, inout float3 SpecularLightOut )
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
						CalculateHairLightingFromLight( MaterialProps, LightingProps, HairProps, DiffuseLight, SpecularLight);
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
						CalculateHairLightingFromLight( MaterialProps, LightingProps, HairProps, DiffuseLight, SpecularLight);
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
					CalculateHairLightingFromLight( MaterialProps, LightingProps, HairProps, DiffuseLight, SpecularLight);
				}
				DiffuseLightOut += DiffuseLight;
				SpecularLightOut += SpecularLight;
			}
		}

		void CalculateHairLightingFromLights( float3 WorldSpacePosition, SMaterialProperties MaterialProps, SLightingProperties LightingProps, SHairProperties HairProps, out float3 DiffuseOut, out float3 SpecularOut)
		{
			CalculateHairLights( WorldSpacePosition, LightingProps._ShadowTerm, MaterialProps, HairProps, DiffuseOut, SpecularOut);
		}

		void CalculateDiffuseIBL( SMaterialProperties MaterialProps, SLightingProperties LightingProps, PdxTextureSamplerCube EnvironmentMap, out float3 DiffuseIBLOut )
		{
			float3 RotatedDiffuseCubemapUV = mul( CastTo3x3( LightingProps._CubemapYRotation ), MaterialProps._Normal );
			float3 DiffuseRad = PdxTexCubeLod( EnvironmentMap, RotatedDiffuseCubemapUV, ( PDX_NumMips - 1 - PDX_MipOffset ) ).rgb * LightingProps._CubemapIntensity; // TODO, maybe we should split diffuse and spec intensity?
			DiffuseIBLOut = DiffuseRad * MaterialProps._DiffuseColor;
		}

		float3 CalculateHairLighting(float3 WorldSpacePosition, SMaterialProperties MaterialProps, SLightingProperties LightingProps, SHairProperties HairProps, PdxTextureSamplerCube EnvironmentMap )
		{
			float3 DiffuseLight = vec3( 0.0f );
			float3 SpecularLight = vec3( 0.0f );
			CalculateHairLightingFromLights( WorldSpacePosition, MaterialProps, LightingProps, HairProps,  DiffuseLight, SpecularLight );
			
			float3 DiffuseIBL;
			float3 SpecularIBL;
			CalculateDiffuseIBL( MaterialProps, LightingProps, EnvironmentMap, DiffuseIBL );
			CalculateHairSpecularIBL( MaterialProps, LightingProps, HairProps, EnvironmentMap, SpecularIBL );

			return DiffuseIBL + SpecularIBL + DiffuseLight + SpecularLight;
		}

		float3 CalculateHairLighting( float2 PixelPosition, float3 WorldSpacePosition, SMaterialProperties MaterialProps, SLightingProperties LightingProps, SHairProperties HairProps, PdxTextureSamplerCube EnvironmentMap )
		{
			float3 Lighting = CalculateHairLighting( WorldSpacePosition, MaterialProps, LightingProps, HairProps, EnvironmentMap );	
			return Lighting;
		}
	]]
}
