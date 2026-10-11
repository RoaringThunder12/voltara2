# SJominiEnvironmentValues
ConstantBuffer( JominiEnvironment )
{
	float3 	AmbientPosX;
	float	CubemapIntensity;
	float3 	AmbientNegX;
	float3 	AmbientPosY;
	float3 	AmbientNegY;
	float3 	AmbientPosZ;
	float3 	AmbientNegZ;
	float3 	ShadowAmbientPosX;
	float3 	ShadowAmbientNegX;
	float3 	ShadowAmbientPosY;
	float3 	ShadowAmbientNegY;
	float3 	ShadowAmbientPosZ;
	float3 	ShadowAmbientNegZ;
	float	FogMax;

	float3 DefaultEnvironmentSunDiffuse;
	float DefaultEnvironmentSunIntensity;
	float3 DefaultEnvironmentToSunDir;
	float DefaultEnvironmentCubemapIntensity;

	float3	SunDiffuse;
	float	SunIntensity;
	float3	ToSunDir;
	
	float	FogBegin2;
	float3	FogColor;
	float	FogEnd2;

	float3 ToTerrainSunnySunDir;
	float3 ToTerrainOvercastSunDir;
	float3 ToMapObjectsSunnySunDir;
	float3 ToMapObjectsOvercastSunDir;
	float3 ToWaterSunnySunDir;
	float3 ToWaterOvercastSunDir;

	# this rotation matrix is used to rotate cubemap sampling vectors, thus "faking" a rotation of the cubemap
	float4x4 CubemapYRotation;

	float TreeSwayLoopSpeed;
	float TreeSwayWindStrengthSpatialModifier;
	float TreeSwaySpeed;
	float TreeSwayWindClusterSizeModifier;
	float3 TreeSwayWorldDirection; //will be normalized
	float TreeHeightImpactOnSway;
	float TreeSwayScale;

	float3 RelativeFogColor;
	float RelativeFogBegin;
	float RelativeFogEnd;
	float RelativeFogHeightBegin;
	float RelativeFogHeightEnd;

	float MapObjectsDiffuseLightScale;
	float MapObjectsSpecularLightScale;
	float MapObjectsDiffuseIBLScale;
	float MapObjectsSpecularIBLScale;
};
