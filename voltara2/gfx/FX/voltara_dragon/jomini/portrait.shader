Includes = {
	"voltara_dragon/cw/pdxmesh_blendshapes.fxh"
	"voltara_dragon/cw/pdxmesh.fxh"
	"voltara_dragon/cw/utility.fxh"
	"voltara_dragon/cw/shadow.fxh"
	# MOD(agot)
	# agot_camera.fxh adds the camera-zoom system on top of the vanilla camera
	# (which arrives via cw/pdxmesh.fxh above). KEEP THIS ORDER: agot_camera.fxh
	# must come after cw/pdxmesh.fxh or the portrait camera breaks.
	"voltara_dragon/cw/agot_camera.fxh"
	"voltara_dragon/agot_glass.fxh"
	# END MOD
	"voltara_dragon/cw/alpha_to_coverage.fxh"
	"voltara_dragon/jomini/jomini_lighting.fxh"
	"voltara_dragon/jomini/jomini_fog.fxh"
	"voltara_dragon/jomini/portrait_accessory_variation.fxh"
	"voltara_dragon/jomini/portrait_coa.fxh"
	"voltara_dragon/jomini/portrait_decals.fxh"
	"voltara_dragon/jomini/portrait_user_data.fxh"
	"voltara_dragon/jomini/portrait_hair_lighting.fxh"
	"voltara_dragon/jomini/portrait_lighting.fxh"
	"voltara_dragon/jomini/shader_utility.fxh"
	"voltara_dragon/constants.fxh"
	# MOD(agot)
	"voltara_dragon/standardfuncsgfx.fxh"
	"voltara_dragon/agot_portrait_constants.fxh"
	"voltara_dragon/agot_portrait_decals_shared.fxh"
	# END MOD
	# MOD(agot) baked-mesh particle cards
	"voltara_dragon/agot_particle_card.fxh"
	# END MOD
}

PixelShader =
{
	TextureSampler DiffuseMap
	{
		Index = 0
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler PropertiesMap
	{
		Index = 1
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler NormalMap
	{
		Index = 2
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler SSAOColorMap
	{
		Index = 3
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler EnvironmentMap
	{
		Ref = JominiEnvironmentMap
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		Type = "Cube"
	}
	TextureSampler DiffuseMapOverride
	{
		Index = 9
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler NormalMapOverride
	{
		Index = 10
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler PropertiesMapOverride
	{
		Index = 11
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler CoaTexture 
	{
		Index = 12
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler AnisotropyHairMap
	{
		Index = 13
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	

	VertexStruct PS_COLOR_SSAO
	{
		float4 Color : PDX_COLOR0;
		float4 SSAOColor : PDX_COLOR1;
	};
}

VertexStruct VS_OUTPUT_PDXMESHPORTRAIT
{
    float4 	Position		: PDX_POSITION;
	float3 	Normal			: TEXCOORD0;
	float3 	Tangent			: TEXCOORD1;
	float3 	Bitangent		: TEXCOORD2;
	float2 	UV0				: TEXCOORD3;
	float2 	UV1				: TEXCOORD4;
	float2 	UV2				: TEXCOORD5;
	float3 	WorldSpacePos	: TEXCOORD6;
	float4 	ShadowProj		: TEXCOORD7;
	# This instance index is used to fetch custom user data from the Data[] array (see pdxmesh.fxh)
	uint 	InstanceIndex	: TEXCOORD8;
	# MOD(agot)
	# Cannot use bool because OpenGL doesn't support it, apparently.
	uint AGOT_IsDynamicTerrainLoaded : TEXCOORD9;
	# Smuggled per-character values, searched once in the vertex shader instead of
	# per pixel (see AGOT_GatherSmuggledPortraitData in agot_portrait_decals_shared.fxh):
	# x = skin palette (MAGENTA), y = clothing decay (RED), z = salt-n-pepper hair (GREEN).
	float3 AGOT_SmuggledWeights : TEXCOORD10;
	uint AGOT_DecayDiffuseIndex : TEXCOORD11;
	# END MOD
};

VertexStruct VS_INPUT_PDXMESHSTANDARD_ID
{
    float3 Position			: POSITION;
	float3 Normal      		: TEXCOORD0;
	float4 Tangent			: TEXCOORD1;
	float2 UV0				: TEXCOORD2;
@ifdef PDX_MESH_UV1     	
	float2 UV1				: TEXCOORD3;
@endif
@ifdef PDX_MESH_UV2
	float2 UV2				: TEXCOORD4;
@endif


	uint2 InstanceIndices 	: TEXCOORD5;
	
@ifdef PDX_MESH_SKINNED
	uint4 BoneIndex 		: TEXCOORD6;
	float3 BoneWeight		: TEXCOORD7;
@endif

	uint VertexID			: PDX_VertexID;
};

# MOD(agot)
# This definition has been moved to agot_portrait_constants.fxh because
# it's also needed by terrain shaders.
# Any changes to this definition should also be applied to that file.

# Portrait constants (SPortraitConstants)
#ConstantBuffer( 5 )
#{
#	float4 		vPaletteColorSkin;
#	float4 		vPaletteColorEyes;
#	float4 		vPaletteColorHair;
#	float4		vSkinPropertyMult;
#	float4		vEyesPropertyMult;
#	float4		vHairPropertyMult;
#	
#	float4 		Light_Color_Falloff[3];
#	float4 		Light_Position_Radius[3]
#	float4 		Light_Direction_Type[3];
#	float4 		Light_InnerCone_OuterCone_AffectedByShadows[3];
#	
#	int			DecalCount;
#	int         PreSkinColorDecalCount
#	int			TotalDecalCount;
#	int 		_; // Alignment
#
#	float4 		PatternColorOverrides[64];
#	float4		CoaColor1;
#	float4		CoaColor2;
#	float4		CoaColor3;
#	float4		CoaOffsetAndScale;
#
#	float		HasDiffuseMapOverride;
#	float		HasNormalMapOverride;
#	float		HasPropertiesMapOverride;
#};
	
# END MOD

VertexShader = {

	Code
	[[
		VS_OUTPUT_PDXMESHPORTRAIT ConvertOutput( VS_OUTPUT_PDXMESH In )
		{
			VS_OUTPUT_PDXMESHPORTRAIT Out;
			
			Out.Position = In.Position;
			Out.Normal = In.Normal;
			Out.Tangent = In.Tangent;
			Out.Bitangent = In.Bitangent;
			Out.UV0 = In.UV0;
			Out.UV1 = In.UV1;
			Out.UV2 = In.UV2;
			Out.WorldSpacePos = In.WorldSpacePos;
			return Out;
		}
	]]
	
	
	MainCode VS_standard
	{
		Input = "VS_INPUT_PDXMESHSTANDARD"
		Output = "VS_OUTPUT_PDXMESHPORTRAIT"
		Code
		[[

			PDX_MAIN
			{
				VS_OUTPUT_PDXMESHPORTRAIT Out = ConvertOutput( PdxMeshVertexShaderStandard( Input ) );
				Out.InstanceIndex = Input.InstanceIndices.y;

				// MOD(agot)
				#ifdef AGOT_PORTRAIT_SKIN
					Out.AGOT_IsDynamicTerrainLoaded = AGOT_AreTerrainMarkerDecalsLoaded() ? 1 : 0;
				#else
					Out.AGOT_IsDynamicTerrainLoaded = 1;
				#endif // !AGOT_PORTRAIT_SKIN

				AGOT_SSmuggledPortraitData Smuggled = AGOT_GatherSmuggledPortraitData();
				Out.AGOT_SmuggledWeights = float3( Smuggled.SkinPaletteWeight, Smuggled.DecayWeight, Smuggled.HairAgingWeight );
				Out.AGOT_DecayDiffuseIndex = Smuggled.DecayDiffuseIndex;
				// END MOD

				return Out;
			}
		]]
	}

	# MOD(agot) baked-mesh particle cards - see agot_particle_card.fxh
	#
	# Replaces the skinning rather than post-processing it: scale.z carries
	# opacity, so skinning would stretch each card along its own normal in
	# proportion to how transparent it is.
	MainCode VS_particle_card
	{
		Input = "VS_INPUT_PDXMESHSTANDARD"
		Output = "VS_OUTPUT_PDXMESHPORTRAIT"
		Code
		[[
			PDX_MAIN
			{
				VS_OUTPUT_PDXMESHPORTRAIT Out;

				uint JointIndex = Input.BoneIndex[0] + Input.InstanceIndices.x;
				SParticleCard Card = PdxReadParticleCard( JointIndex );

				// ONE decal-buffer walk for the whole vertex: ViewMatrix and
				// ViewProjectionMatrix are macros that each rebuild the zoomed
				// camera, so naming either costs a walk every time.
				float2 ZoomHeight = AGOT_GetCameraZoomFromMarkerDecals();
				float4x4 View = View_Matrix_From( Camera_Position_From( ZoomHeight ) );
				float4x4 ViewProj = mul( Projection_Matrix_From( ZoomHeight ), View );

				float3 CardNormal;
				float3 LocalOffset = PdxParticleCornerOffset( Card, View, Input.Position.xy, CardNormal );

				float LayerVisibility = 1.0f;
			#ifdef PARTICLE_DRAGON_DARK_GATE
				// One answer per draw, so this branch is uniform across the
				// whole layer. A closed gate collapses the quad to a point:
				// zero-area triangles never reach the rasterizer, so a
				// light-coloured dragon pays the vertex cost and NO fill cost.
				// That is the win worth having - these cards are almost
				// entirely overdraw.
				LayerVisibility = PdxParticleDarkGate();
				LocalOffset *= ( LayerVisibility > PARTICLE_DARK_CULL ) ? 1.0f : 0.0f;
			#endif

				// The world matrix carries the dragon size, including the 0.06 root
				// scale of an infant.
				float4x4 World = PdxMeshGetWorldMatrix( Input.InstanceIndices.y );
				float4 WorldOrigin = mul( World, float4( Card._Origin, 1.0f ) );
				float3 OriginWS = WorldOrigin.xyz / max( WorldOrigin.w, 1e-6f );

				// Probe the scale rather than deriving it: column 0 over [3][3]
				// agrees only under one homogeneous convention, and pdxmesh/scale
				// can reach either place.
				float4 WorldProbe = mul( World, float4( Card._Origin + float3( 1.0f, 0.0f, 0.0f ), 1.0f ) );
				float WorldScale = length( WorldProbe.xyz / max( WorldProbe.w, 1e-6f ) - OriginWS );

				// Size in world space, do not transform by World: a rotated parent
				// bone would shear the quad out of the screen plane.
				float3 WorldSpacePos = OriginWS + LocalOffset * WorldScale;

				Out.WorldSpacePos = WorldSpacePos;
				Out.Position = FixProjectionAndMul( ViewProj, float4( WorldSpacePos, 1.0f ) );

				// The gate rides the opacity rather than its own interpolator:
				// it is constant across the card, so folding it in here is
				// exact and costs nothing.
				float Opacity = Card._Opacity * PARTICLE_OPACITY_MULT * LayerVisibility;

			#ifdef PARTICLE_PARENT_SCALE_OPACITY
				// MULTIPLIES the per-card opacity from this rig's own bones - the
				// dragon fades the whole plume, the plume still fades its own
				// cards. Uniform per draw, so it costs two probe transforms.
				Opacity *= PdxParticleParentScale( World, Card._Origin, OriginWS );
			#endif

				Out.UV0 = PdxParticleAtlasUV( Input.UV0, PdxParticleAgeCell( Card._Age ) );
				Out.UV1 = Out.UV0;
				Out.UV2 = float2( 0.0f, saturate( Opacity ) );

			#ifdef PARTICLE_DRAGON_PALETTE
				// Normal and Tangent carry shading data here, not a basis: this
				// path is unlit and reads no basis.
				float3 ColorBirth;
				float PaletteStrength;
				float FireHue;
				PdxParticlePaletteColors( ColorBirth, PaletteStrength, FireHue );

				PARTICLE_COLOR_BIRTH_OUT( Out ) = ColorBirth;
				PARTICLE_AGE_OUT( Out ) = float3( Card._Age, PaletteStrength, FireHue );
				Out.Bitangent = float3( 0.0f, 0.0f, 0.0f );
			#else
				// SCENE-STABLE, not camera-facing. Bending the dome around the
				// card normal - which for a billboard always faces the camera,
				// while the portrait lights stay fixed in the scene - swings the
				// whole card's brightness with the viewpoint: light grey head-on,
				// black from behind. Smoke is an object in the scene; its bright
				// side must be the side the LIGHTS see.
				//
				// Base: outward from the emitter mouth, in entity space, so it
				// turns with the dragon. Cards still at the mouth have no travel
				// to point along - fall back to up.
				float3 FromEmitter = Card._Origin - PARTICLE_OFFSET;
				float3 BaseDir = ( dot( FromEmitter, FromEmitter ) > 1e-6f )
				               ? normalize( FromEmitter )
				               : float3( 0.0f, 1.0f, 0.0f );
				// Normalize BEFORE the up pull: World carries pdxmesh scale, and
				// 40x one term would swamp the other.
				float3 BaseWorld = normalize( mul( CastTo3x3( World ), BaseDir ) );
				BaseWorld = normalize( BaseWorld + float3( 0.0f, PARTICLE_NORMAL_UP, 0.0f ) );

				// The dome bend uses the in-plane corner offset, which is world
				// space here. It swings with the camera, but only as a symmetric
				// modulation around the stable base.
				Out.Normal = PdxParticlePuffNormal( BaseWorld, LocalOffset );

				// PdxParticleViewBasis, NEVER CameraRightDir / CameraUpDir - the
				// AGOT portrait camera renames those away, and one reference
				// here kills the effect with a clean error.log.
				float3 BasisRight;
				float3 BasisUp;
				PdxParticleViewBasis( Card, View, BasisRight, BasisUp );
				Out.Tangent   = BasisRight;
				Out.Bitangent = BasisUp;
			#endif

				// Every member of the output struct must be written or it
				// interpolates undefined values, even where nothing reads it.
				Out.ShadowProj = float4( 0.0f, 0.0f, 0.0f, 1.0f );
				Out.InstanceIndex = Input.InstanceIndices.y;
				Out.AGOT_IsDynamicTerrainLoaded = 1;
				Out.AGOT_SmuggledWeights = float3( 0.0f, 0.0f, 0.0f );
				Out.AGOT_DecayDiffuseIndex = 0;

				return Out;
			}
		]]
	}
	# END MOD
}

PixelShader =
{
	Code
	[[
		void DebugReturn( inout float3 Out, SMaterialProperties MaterialProps, SLightingProperties LightingProps, PdxTextureSamplerCube EnvironmentMap, float3 ScatteringColor, float ScatteringMask, float3 DiffuseTranslucency )
		{
			#if defined( PDX_DEBUG_PORTRAIT_SCATTERING_MASK )
				Out = ScatteringMask;
			#elif defined( PDX_DEBUG_PORTRAIT_SCATTERING_COLOR )
				Out = ScatteringColor;
			#elif defined( PDX_DEBUG_TRANSLUCENCY )
				Out = DiffuseTranslucency;
			#else
				DebugReturn( Out, MaterialProps, LightingProps, EnvironmentMap );
			#endif
		}	

		float3 TangentSpaceToWorldNormal( in VS_OUTPUT_PDXMESHPORTRAIT Input, float3 NormalSample )
		{
			float3x3 TBN = Create3x3( normalize( Input.Tangent ), normalize( Input.Bitangent ), normalize( Input.Normal ) );
			return normalize( mul( NormalSample, TBN ) );
		}

		float3 TangentSpaceToWorldNormalWithTwoNormal( in VS_OUTPUT_PDXMESHPORTRAIT Input, float3 FirstNormalSample, float3 SecondNormalSample, float NormalUVChannel )
		{
			float3x3 TBN = Create3x3( normalize( Input.Tangent ), normalize( Input.Bitangent ), normalize( Input.Normal ) );
			float3 BaseWorldNormal  = normalize( mul( FirstNormalSample, TBN ) );
			float3x3 TBN2 = BuildTangentFrame( BaseWorldNormal , Input.WorldSpacePos, Input.UV1 );
			float3 LayeredNormal = normalize( mul( SecondNormalSample, TBN2 ) );
			return lerp( BaseWorldNormal , LayeredNormal, NormalUVChannel );
		}

		float3 CommonPixelShaderColor( float4 Diffuse, float4 Properties, float3 Normal, in VS_OUTPUT_PDXMESHPORTRAIT Input )
		{
			GetSpecularAA( Normal, 1.0f, 1.0f, Properties.a );
			
			SMaterialProperties MaterialProps = GetMaterialProperties( Diffuse.rgb, Normal, saturate( Properties.a ), Properties.g, Properties.b );
			SLightingProperties LightingProps = GetSunLightingProperties( Input.WorldSpacePos, 1.0 );
			
			float3 DiffuseIBL;
			float3 SpecularIBL;
			CalculateLightingFromIBL( MaterialProps, LightingProps, EnvironmentMap, DiffuseIBL, SpecularIBL );
			
			float3 DiffuseLight = vec3(0.0);
			float3 SpecularLight = vec3(0.0);
			CalculatePortraitLights( Input.WorldSpacePos, LightingProps._ShadowTerm, MaterialProps, DiffuseLight, SpecularLight );
			
			float3 Color = DiffuseIBL + SpecularIBL + DiffuseLight + SpecularLight;
			
			#ifdef VARIATIONS_ENABLED
				ApplyClothFresnel( Input, CameraPosition, Normal, Color );
			#endif

			float3 ScatteringColor = vec3(0.0f);
			float ScatteringMask = Properties.r;
			#ifdef FAKE_SCATTERING_EMISSIVE
				float3 SkinColor = RGBtoHSV( Diffuse.rgb );
				SkinColor.z = 1.0f;
				ScatteringColor = HSVtoRGB(SkinColor) * ScatteringMask * 0.5f * MaterialProps._DiffuseColor;
				Color += ScatteringColor;
			#endif

			float3 DiffuseTranslucency = vec3( 0.0f );
			#ifdef TRANSLUCENCY
				STranslucencyProperties TranslucencyProps;
				#if defined( SKIN_SCATTERING )
					float3 SkinColor = RGBtoHSV( Diffuse.rgb );
					SkinColor.z = 1.0f;
					ScatteringColor = HSVtoRGB( SkinColor ) * MaterialProps._DiffuseColor;
					TranslucencyProps = GetTranslucencyProperties( 0.3f, 2.0f, 1.0f, 1.0f, 0.2f, ScatteringMask, ScatteringColor );
				#elif defined( THICKNESS_MAP )
					TranslucencyProps = GetTranslucencyProperties( 0.3f, 1.5f, 1.0f, 1.0f, 0.2f, Properties.r, Diffuse.rgb );
				#else
					TranslucencyProps = GetTranslucencyProperties( 0.3f, 1.5f, 1.0f, 1.0f, 0.2f, 0.5f, Diffuse.rgb );
				#endif
				DiffuseTranslucency = CalculatePortraitTranslucentLights( Input.WorldSpacePos, LightingProps._ShadowTerm, MaterialProps, TranslucencyProps, DiffuseIBL );
				Color += DiffuseTranslucency;
			#endif
			
			// MOD(agot) EMISSIVE SHADER
			//Use for emissive in normal BLUE channel.
			#ifdef EMISSIVE_NORMAL_BLUE

				float EmissiveStrength = 1.0f;
				float emissiveMask = PdxTex2D( NormalMap, Input.UV0 ).b;
				float3 emissiveColor = Diffuse.rgb * EmissiveStrength;
				Color = lerp(Color, emissiveColor, emissiveMask);

			#endif

			//Use for emissive in properties RED channel.
			#ifdef EMISSIVE_PROPERTIES_RED

				float EmissiveStrength = 1.0f;
				float emissiveMask = Properties.r;
				float3 emissiveColor = Diffuse.rgb * EmissiveStrength;
				Color = lerp(Color, emissiveColor, emissiveMask);
			#endif
			// MOD(agot) EMISSIVE SHADER

			#ifdef GLASS
				//Bring in defines from Asset file and define fallbacks to stop compile errors.
				#if defined( GLASS_TILING )
					float2 TilingFactor = GLASS_TILING;
				#else
					float2 TilingFactor = float2(1.0f,1.0f);
				#endif

				#if defined( OUTER_REFRACTION )
					float OuterRefraction = OUTER_REFRACTION;
				#else
					float OuterRefraction = 0.5f;
				#endif

				#if defined( INNER_THICKNESS )
					float InnerThickness = INNER_THICKNESS;
				#else
					float InnerThickness = 1000.0f;
				#endif

				float3 CameraPos = CameraPosition; //To get around our camera zoom macro which turns CameraPosition into "CameraPosition()" function which we can't pass as a parameter to a function
				// MOD(agot)
				// TBN was referenced here but never declared in CommonPixelShaderColor's scope, so
				// every GLASS material failed to compile (PS_skin / PS_attachment, X3004).
				// Built the same way as the other tangent frames in this file (see ~line 290).
				float3x3 TBN = Create3x3( normalize( Input.Tangent ), normalize( Input.Bitangent ), normalize( Input.Normal ) );
				// END MOD
				float3 GlassColor = ComputeGlassShading(
					Diffuse.rgb,
					Properties,
					Normal,
					TBN,
					CameraPos,
					Input,
					MaterialProps,
					LightingProps,
					TilingFactor,
					OuterRefraction,
					InnerThickness
				);
				Color = lerp(Color,GlassColor,Properties.b);
			#endif



			DebugReturn( Color, MaterialProps, LightingProps, EnvironmentMap, ScatteringColor, ScatteringMask, DiffuseTranslucency );
			return Color;
		}

		float3 CommonPixelShader( float4 Diffuse, float4 Properties, float3 NormalSample, in VS_OUTPUT_PDXMESHPORTRAIT Input )
		{
			float3 Normal = TangentSpaceToWorldNormal( Input, NormalSample );
			return CommonPixelShaderColor( Diffuse, Properties, Normal, Input );
		}

		float3 CommonPixelShaderWithTwoNormal( float4 Diffuse, float4 Properties, float3 FirstNormalSample, float3 SecondNormalSample, float NormalUVChannel, in VS_OUTPUT_PDXMESHPORTRAIT Input )
		{
			float3 Normal = TangentSpaceToWorldNormalWithTwoNormal( Input, FirstNormalSample, SecondNormalSample, NormalUVChannel );
			return CommonPixelShaderColor( Diffuse, Properties, Normal, Input );
		}

		// Remaps Value to [IntervalStart, IntervalEnd]
		// Assumes Value is in [0,1] and that 0 <= IntervalStart < IntervalEnd <= 1
		float RemapToInterval( float Value, float IntervalStart, float IntervalEnd )
		{
			return IntervalStart + Value * ( IntervalEnd - IntervalStart );
		}

		// The skin, eye and hair assets come with a special texture  (the "Color Mask", typically packed into 
		// another texture) that determines the Diffuse-PaletteColor blend. Artists also supply a remap interval 
		// used to bias this texture's values; essentially allowing the texture's full range of values to be 
		// mapped into a small interval of the diffuse lerp (e.g. [0.8, 1]).
		// If the texture value is 0.0, that is a special case indicating there shouldn't be any palette color, 
		// (it is used for non-hair things such as hair bands, earrings etc)
		float3 GetColorMaskColorBLend( float3 DiffuseColor, float3 PaletteColor, uint InstanceIndex, float ColorMaskStrength )
		{
			if ( ColorMaskStrength == 0.0 )
			{
				return DiffuseColor;
			}
			else
			{
				float2 Interval = GetColorMaskRemapInterval( InstanceIndex );
				float LerpTarget = RemapToInterval( ColorMaskStrength, Interval.x, Interval.y );
				return lerp( DiffuseColor.rgb, DiffuseColor.rgb * PaletteColor, LerpTarget );
			}
		}
	]]

	MainCode PS_skin
	{
		Input = "VS_OUTPUT_PDXMESHPORTRAIT"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			PDX_MAIN
			{			
				PS_COLOR_SSAO Out;

				float2 UV0 = Input.UV0;
				float4 Diffuse;
				float4 Properties;
				float3 NormalSample;

				// MOD(agot)
				float3 SkinColorPalette = vPaletteColorSkin.rgb;

				#ifdef SKIN_TO_HAIR_COLOR
				SkinColorPalette = vPaletteColorHair.rgb;
				#endif
				// END MOD

            #ifdef ENABLE_TEXTURE_OVERRIDE
				if ( HasDiffuseMapOverride > 0.5f )
				{
                    Diffuse = PdxTex2D( DiffuseMapOverride, UV0 );
				}
				else
				{
					Diffuse = PdxTex2D( DiffuseMap, UV0 );
				}
				if ( HasPropertiesMapOverride > 0.5f )
				{
                    Properties = PdxTex2D( PropertiesMapOverride, UV0 );
				}
				else
				{
					Properties = PdxTex2D( PropertiesMap, UV0 );
				}
				if ( HasNormalMapOverride > 0.5f )
				{
                    NormalSample = UnpackRRxGNormal( PdxTex2D( NormalMapOverride, UV0 ) );
				}
				else
				{
					NormalSample = UnpackRRxGNormal( PdxTex2D( NormalMap, UV0 ) );
				}
            #else
				Diffuse = PdxTex2D( DiffuseMap, UV0 );
				Properties = PdxTex2D( PropertiesMap, UV0 );
				NormalSample = UnpackRRxGNormal( PdxTex2D( NormalMap, UV0 ) );
			#endif


				// MOD(agot)
				
				float ColorMaskStrength = Diffuse.a;
				#ifndef NO_DECAL
					AddDecals( Diffuse, NormalSample, Properties, UV0, Input.InstanceIndex, 0, PreSkinColorDecalCount,0 );
				#endif

				//Skin palette blend strength, searched once in the vertex shader (MAGENTA control decal).
				float Weight = Input.AGOT_SmuggledWeights.x;

				SkinColorPalette = lerp(vPaletteColorSkin.rgb,vPaletteColorHair.rgb,Weight);


				//Diffuse.rgb = GetColorMaskColorBLend( Diffuse.rgb, vPaletteColorSkin.rgb, Input.InstanceIndex, ColorMaskStrength );
				Diffuse.rgb = GetColorMaskColorBLend( Diffuse.rgb, SkinColorPalette, Input.InstanceIndex, ColorMaskStrength );
				// END MOD


				// MOD(agot)
				#ifndef NO_DECAL
					AddDecals( Diffuse, NormalSample, Properties, UV0, Input.InstanceIndex, PreSkinColorDecalCount, DecalCount,0 );
				#endif
				// MOD(agot)
				
				float3 Color = CommonPixelShader( Diffuse, Properties, NormalSample, Input );
				Out.Color = float4( Color, 1.0f );

				Out.SSAOColor = PdxTex2D( SSAOColorMap, UV0 );

				// MOD(agot)
				//Out.SSAOColor.rgb *= vPaletteColorSkin.rgb;
				Out.SSAOColor.rgb *= SkinColorPalette;
				// END MOD
				return Out;
			}
			
		]]
	}
	
	MainCode PS_eye
	{
		Input = "VS_OUTPUT_PDXMESHPORTRAIT"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			PDX_MAIN
			{
				PS_COLOR_SSAO Out;

				float2 UV0 = Input.UV0;
				float4 Diffuse = PdxTex2D( DiffuseMap, UV0 );								
				float4 Properties = PdxTex2D( PropertiesMap, UV0 );
				float3 NormalSample = UnpackRRxGNormal( PdxTex2D( NormalMap, UV0 ) );
				
				// MOD(agot)
				#ifdef EYE_DECAL

					float4 BaseDiffuse = Diffuse;

					AddDecals( Diffuse, NormalSample, Properties, UV0, Input.InstanceIndex, 0, PreSkinColorDecalCount, BODYPART_EYES, Input.AGOT_IsDynamicTerrainLoaded != 0);

					Diffuse.rgb = lerp(Diffuse,BaseDiffuse,BaseDiffuse.a).rgb;
				#endif
				
				float3 EyeColor = vPaletteColorEyes.rgb;

				#ifdef HSV_SHIFT
					EyeColor = RGBtoHSV(EyeColor);
					EyeColor.x = EyeColor.x + 0.5f;
					EyeColor = saturate(HSVtoRGB(EyeColor));
				#endif

				float ColorMaskStrength = Diffuse.a;

				#ifndef EYE_BLIND
				
					Diffuse.rgb = GetColorMaskColorBLend( Diffuse.rgb, EyeColor.rgb, Input.InstanceIndex, ColorMaskStrength );

					#ifdef EYE_DECAL
						AddDecals( Diffuse, NormalSample, Properties, UV0, Input.InstanceIndex, PreSkinColorDecalCount, DecalCount, BODYPART_EYES, Input.AGOT_IsDynamicTerrainLoaded != 0);
					#endif
					
				#endif
				// END MOD
				
				float3 Color = CommonPixelShader( Diffuse, Properties, NormalSample, Input );
				Out.Color = float4( Color, 1.0f );
				
				Out.SSAOColor = PdxTex2D( SSAOColorMap, UV0 );
				Out.SSAOColor.rgb *= vPaletteColorEyes.rgb;
	
				return Out;
			}
		]]
	}

	# MOD(agot)
		MainCode PS_skin_alpha
	{
		Input = "VS_OUTPUT_PDXMESHPORTRAIT"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			PDX_MAIN
			{
				PS_COLOR_SSAO Out;

				float2 UV0 = Input.UV0;
				float4 Diffuse = PdxTex2D( DiffuseMap, UV0 );								
				float4 Properties = PdxTex2D( PropertiesMap, UV0 );
				float3 NormalSample = UnpackRRxGNormal( PdxTex2D( NormalMap, UV0 ) );

				float ColorMaskStrength = Diffuse.a;
				Diffuse.rgb = GetColorMaskColorBLend( Diffuse.rgb, vPaletteColorSkin.rgb, Input.InstanceIndex, ColorMaskStrength );
				
				float3 Color = CommonPixelShader( Diffuse, Properties, NormalSample, Input );
				Out.Color = float4( Color, 1.0f );
				
				Out.SSAOColor = PdxTex2D( SSAOColorMap, UV0 );
				Out.SSAOColor.rgb *= vPaletteColorSkin.rgb;
	
				return Out;
			}
		]]
	}
	# END MOD

	MainCode PS_attachment
	{		
		Input = "VS_OUTPUT_PDXMESHPORTRAIT"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			PDX_MAIN
			{
				PS_COLOR_SSAO Out;

				float2 UV0 = Input.UV0;
				float4 Diffuse = PdxTex2D( DiffuseMap, UV0 );								
				float4 Properties = PdxTex2D( PropertiesMap, UV0 );
				float4 NormalSampleRaw = PdxTex2D( NormalMap, UV0 );
				#ifdef DOUBLE_SIDED_ENABLED
					float3 NormalSample = UnpackRRxGNormal( NormalSampleRaw ) * ( PDX_IsFrontFace ? 1 : -1 );
				#else
					float3 NormalSample = UnpackRRxGNormal( NormalSampleRaw );
				#endif

				#ifdef VARIATIONS_ENABLED
					float4 SecondColorMask = vec4( 0.0f );
					SecondColorMask.r = Properties.r;
					SecondColorMask.g =  NormalSampleRaw.b;
					float3 PatternNormal = NormalSample;
					float NormalUVChannel = 0.0f;
					ApplyVariationPatterns( Input, Diffuse, Properties, PatternNormal, SecondColorMask, NormalUVChannel );

				// MOD(agot)
				#else
					#ifdef ATTACHEMENT_DECAY

					//Clothing decay strength + mask texture, searched once in the vertex shader (RED control decal).
					float Weight = Input.AGOT_SmuggledWeights.y;
					uint DiffuseIndex = Input.AGOT_DecayDiffuseIndex;

					//R - WET MASK
					//G - THICK DIRT MASK
					//B - RUST MASK
					//A - WORN FABRIC MASK
					float4 DiffuseDecayMask2x = PdxTex2D( DecalDiffuseArray, float3( Input.UV0*2.0f, DiffuseIndex ) );
					float4 DiffuseDecayMask3x = PdxTex2D( DecalDiffuseArray, float3( Input.UV0*3.0f, DiffuseIndex ) );

					//RUST
					float3 RustMask = float3(0.4f,0.2f,0.13f);
					RustMask = RustMask * (DiffuseDecayMask3x.bbb);
					RustMask = Overlay( Diffuse.rgb, RustMask,1.0f );

					float ClothMask = smoothstep(1.0f-float(Properties.b*2.0f),1.0f-Properties.b,0.8f);
					float RustRoughness = DiffuseDecayMask2x.b*DiffuseDecayMask3x.b;

					Diffuse.rgb = lerp(Diffuse.rgb,RustMask,smoothstep(DiffuseDecayMask2x.b,DiffuseDecayMask2x.b+0.2f,Weight*0.8f)*ClothMask);
					Properties.a = lerp(Properties.a,1.0f,smoothstep(RustRoughness,RustRoughness+0.3f,Weight*0.4)*smoothstep(1.0f-float(Properties.a*2.0f),1.0f-Properties.a,0.8f)*ClothMask);

					//Worn out fabrics
					 float FabricMask = saturate(0.6f-DiffuseDecayMask2x.a);

					 Diffuse.rgb = lerp(Diffuse.rgb,float3(0.9f,0.75f,0.6f),smoothstep(FabricMask,FabricMask+0.3f,(Weight*0.34f)*(1.0f-ClothMask)*0.7f));
					
					 Properties.b = lerp(Properties.b,0.0f,smoothstep(FabricMask,FabricMask+0.3f,(Weight*0.4f)*(1.0f-ClothMask)));
					 Properties.a = lerp(Properties.a,1.0f,smoothstep(FabricMask,FabricMask+0.3f,(Weight*0.4f)*(1.0f-ClothMask)));

					//Holes in fabrics
					 float WearMask = abs(0.8f-DiffuseDecayMask2x.a);
					 Diffuse.a = lerp(Diffuse.a,0.0f,step(WearMask,Weight*0.3f)*(1.0f-ClothMask));

					//Stains in fabric
					float StainMask = saturate(DiffuseDecayMask3x.r*5.0f);
					Diffuse.rgb = Multiply(Diffuse.rgb,float3(StainMask,StainMask,StainMask), clamp(Weight*2.0f,0.0f,1.0f));


					//Layers of dirt
					float DirtMask = clamp( NormalSample.b * NormalSample.b, 0, 1 );
					DirtMask = max(DirtMask,DiffuseDecayMask3x.g*1.5);
					float3 DirtDiffuse = float3(0.2f,0.1f,0.06f);
				
					
					DirtDiffuse *= Diffuse.rgb;
					Diffuse.rgb = lerp(Diffuse.rgb,DirtDiffuse,smoothstep(DirtMask*0.5f,DirtMask*1.5f,clamp(Weight*1.6f,0.0f,1.0f)));

					#endif
					// MOD(agot)

				#endif
				#ifdef COA_ENABLED
					Properties.r = 1.0;
					ApplyCoa( Input, Diffuse, CoaColor1, CoaColor2, CoaColor3, CoaOffsetAndScale.xy, CoaOffsetAndScale.zw, CoaTexture, Properties.r );
				#endif

				#ifdef VARIATIONS_ENABLED
					float3 Color = CommonPixelShaderWithTwoNormal( Diffuse, Properties, NormalSample, PatternNormal, NormalUVChannel, Input );
				#else 
					float3 Color = CommonPixelShader( Diffuse, Properties, NormalSample, Input );
				#endif


				// MOD(agot)
				//Out.Color = float4( Color, Diffuse.a );
				#if defined PARALLAX || defined REFRACT
					Out.Color = float4( Color, 1.0f );
				#else
					Out.Color = float4( Color, Diffuse.a );
				#endif
				// END MOD

				Out.SSAOColor = float4( vec3( 0.0f ), 1.0f );

				return Out;
			}
		]]
	}
	MainCode PS_portrait_hair_backface
	{
		Input = "VS_OUTPUT_PDXMESHPORTRAIT"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{			
				return float4( vec3( 0.0f ), 1.0f );
			}
		]]
	}
	MainCode PS_hair
	{
		Input = "VS_OUTPUT_PDXMESHPORTRAIT"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			PDX_MAIN
			{
				PS_COLOR_SSAO Out;

				float2 UV0 = Input.UV0;
				float4 Diffuse = PdxTex2D( DiffuseMap, UV0 );								
				clip( Diffuse.a - 1e-5 );
				float4 Properties = PdxTex2D( PropertiesMap, UV0 );
				Properties *= vHairPropertyMult;
				float4 NormalSampleRaw = PdxTex2D( NormalMap, UV0 );
				float3 NormalSample = UnpackRRxGNormal( NormalSampleRaw ) * ( PDX_IsFrontFace ? 1 : -1 );

				float ColorMaskStrength = NormalSampleRaw.b;
				Diffuse.rgb = GetColorMaskColorBLend( Diffuse.rgb, vPaletteColorHair.rgb, Input.InstanceIndex, ColorMaskStrength );
				
				//Hair Decals
				#ifdef HAIR_AGING_DECAL
					//Salt n' Pepper Hair strength, searched once in the vertex shader (GREEN control decal).
					float Weight = Input.AGOT_SmuggledWeights.z;

					//Get base hair texture
					float4 BaseDiffuse = PdxTex2D( DiffuseMap, UV0 );	

					// //Interpolate between the original white hair texture and the final coloured texture using Weight as strength value to create salt and pepper effect.
					Diffuse.rgb = lerp (Diffuse.rgb, BaseDiffuse.ggg, step((1.0f - Weight) , saturate(BaseDiffuse.r)) * Diffuse.a * (Weight ) * 0.7f);
				#endif
				// END MOD

				float3 Color = CommonPixelShader( Diffuse, Properties, NormalSample, Input );

				#ifdef ALPHA_TO_COVERAGE
					Diffuse.a = RescaleAlphaByMipLevel( Diffuse.a, UV0, DiffuseMap );

					const float CUTOFF = 0.5f;
					Diffuse.a = SharpenAlpha( Diffuse.a, CUTOFF );
				#endif

				#ifdef WRITE_ALPHA_ONE
					Out.Color = float4( Color, 1.0f );
				#else
					#ifdef HAIR_TRANSPARENCY_HACK
						// TODO [HL]: Hack to stop clothing fragments from being discarded by transparent hair,
						// proper fix is to ensure that hair is drawn after clothes
						// https://beta.paradoxplaza.com/browse/PSGE-3103
						clip( Diffuse.a - 0.5f );
					#endif

					Out.Color = float4( Color, Diffuse.a );
				#endif

				Out.SSAOColor = PdxTex2D( SSAOColorMap, UV0 );
				Out.SSAOColor.rgb *= vPaletteColorHair.rgb;

				return Out;
			}
		]]
	}
	MainCode PS_hair_double_sided
	{
		Input = "VS_OUTPUT_PDXMESHPORTRAIT"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			PDX_MAIN
			{
				PS_COLOR_SSAO Out;

				float2 UV0 = Input.UV0;
				float4 Diffuse = PdxTex2D( DiffuseMap, UV0 );
				#ifdef ALPHA_TEST
				clip( Diffuse.a - 0.5f );
				Diffuse.a = 1.0f;
				#endif
				float4 Properties = PdxTex2D( PropertiesMap, UV0 );
				float3 NormalSample = UnpackRRxGNormal( PdxTex2D( NormalMap, UV0 ) );

				Properties *= vHairPropertyMult;
				Diffuse.rgb *= vPaletteColorHair.rgb;

				float3 Color = CommonPixelShader( Diffuse, Properties, NormalSample, Input );

				Out.Color = float4( Color, Diffuse.a );
				
				Out.SSAOColor = PdxTex2D( SSAOColorMap, UV0 );
				Out.SSAOColor.rgb *= vPaletteColorHair.rgb;

				return Out;
			}
		]]
	}

	MainCode PS_anisotropic_hair
	{
		Input = "VS_OUTPUT_PDXMESHPORTRAIT"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			#ifndef DIFFUSE_UV_SET
			#define DIFFUSE_UV_SET Input.UV0
			#endif
			#ifndef NORMAL_UV_SET
			#define NORMAL_UV_SET Input.UV0
			#endif
			#ifndef PROPERTIES_UV_SET
			#define PROPERTIES_UV_SET Input.UV0
			#endif	
			#ifndef ANISOTROPY_UV_SET
			#define ANISOTROPY_UV_SET Input.UV0
			#endif
			#ifndef FLOWMAP_UV_SET
			#define FLOWMAP_UV_SET Input.UV0
			#endif
			
			SCharacterHairSettings GetCharacterHairSettings()
			{
				SCharacterHairSettings HairSettings;
				HairSettings._EdgeColor = float4( vPaletteColorHair.rgb * 0.1f, 1.0f );
				HairSettings._StrandDirection = float3( 0.0f, -1.0f, 0.0f );
				HairSettings._PrimaryHighlightShift = -0.5f;
				HairSettings._AnisotropyShiftScale = float2( 1.0f, 1.0f );
				HairSettings._AnisotropySmoothnessMin = 0.0f;
				HairSettings._AnisotropySmoothnessMax = 1.0f;
				HairSettings._SecondaryHighlightShift = -0.9f;
				HairSettings._NormalStrength = 1.0f;
				float SpecularPowerScale = ( vPaletteColorHair.r + vPaletteColorHair.g + vPaletteColorHair.b ) / 3;
				SpecularPowerScale = lerp( 1.0f ,3.0f , SpecularPowerScale );
				HairSettings._SpecularPower = 5.0f * SpecularPowerScale;
				HairSettings._AlphaCutoffTreshold = 0.5f;
				HairSettings._RoughnessMin = 0.0f;
				HairSettings._RoughnessMax = 1.0f;
				return HairSettings;
			}

			PDX_MAIN
			{
				float4 NormalSampleRaw = PdxTex2D( NormalMap, NORMAL_UV_SET );
				float3 UnpackedNormal = UnpackRRxGNormal( NormalSampleRaw ) * ( PDX_IsFrontFace ? 1 : -1 );
				float3x3 TBN = Create3x3( normalize( Input.Tangent ), normalize( Input.Bitangent ), normalize( Input.Normal ) );
				float3 Normal = normalize( mul( UnpackedNormal, TBN ) );

				SCharacterHairSettings HairSettings = GetCharacterHairSettings();

				float4 Diffuse = PdxTex2D( DiffuseMap, DIFFUSE_UV_SET );

				float3 HairBaseDiffuse;

				float ColorMaskStrength = NormalSampleRaw.b;
				HairBaseDiffuse.rgb = GetColorMaskColorBLend( Diffuse.rgb, vPaletteColorHair.rgb, Input.InstanceIndex, ColorMaskStrength );

				float4 Properties = PdxTex2D( PropertiesMap, PROPERTIES_UV_SET );
				Properties *= vHairPropertyMult;
				float AnisotropyShift = PdxTex2D( AnisotropyHairMap, ANISOTROPY_UV_SET * HairSettings._AnisotropyShiftScale ).b;
				AnisotropyShift = lerp( HairSettings._AnisotropySmoothnessMin, HairSettings._AnisotropySmoothnessMax, AnisotropyShift );

				SMaterialProperties MaterialProps = GetMaterialProperties( HairBaseDiffuse, Normal, saturate( lerp( HairSettings._RoughnessMin, HairSettings._RoughnessMax, Properties.a ) ), Properties.g + 0.01f, Properties.b );
				SLightingProperties LightingProps = GetSunLightingProperties( Input.WorldSpacePos, 1.0 );

				//The specular will stretch along the input tangent. This can be provided via a flowmap or a vector.
				#ifdef USE_FLOWMAP
					float3 Flow = float3( PdxTex2D( AnisotropyHairMap, FLOWMAP_UV_SET ).rg, 0.0f );
					Flow.rg = Flow.rg * 2.0f - 1.0f;
					Flow.g = -Flow.g;
					float3 T = normalize( mul( Flow, TBN ) );
				#else
					float3 T = normalize( mul( HairSettings._StrandDirection, TBN ) );
				#endif

				float3 N = lerp( Input.Normal, Normal, HairSettings._NormalStrength );

				//Hair mainly produces two highlights. The primary highlight which reflects the light color and the secondary highlight which also reflects some of the hair color in addition to the light color.
				//We shift them slightly manually to fake the light scattering effect.
				float3 T1 = ShiftTangent( T, N, HairSettings._PrimaryHighlightShift + AnisotropyShift );
				float3 T2 = ShiftTangent( T, N, HairSettings._SecondaryHighlightShift + AnisotropyShift );

				SHairProperties HairProps;
				HairProps._UVs = DIFFUSE_UV_SET;
				HairProps._PrimaryTangent = T1;
				HairProps._SecondaryTangent = T2;
				HairProps._EdgeColor = HairSettings._EdgeColor.rgb;
				HairProps._SpecularPower = HairSettings._SpecularPower;
				HairProps._SmoothnessMin = HairSettings._AnisotropySmoothnessMin;
				HairProps._SmoothnessMax = HairSettings._AnisotropySmoothnessMax;
				HairProps._ColorMaskStrength = ColorMaskStrength;

				float3 Color = CalculateHairLighting( Input.Position.xy, Input.WorldSpacePos, MaterialProps, LightingProps, HairProps, EnvironmentMap );

				#ifdef ALPHA_TO_COVERAGE
					Diffuse.a = RescaleAlphaByMipLevel( Diffuse.a, DIFFUSE_UV_SET, DiffuseMap );
					Diffuse.a = SharpenAlpha( Diffuse.a, HairSettings._AlphaCutoffTreshold );
				#endif
				#ifdef HAIR_TRANSPARENCY_HACK
					clip( Diffuse.a - 0.5f );
				#endif

				float Alpha = Diffuse.a;

				PS_COLOR_SSAO Out;
				Out.Color = float4( Color.rgb, Alpha );
				Out.SSAOColor = PdxTex2D( SSAOColorMap, DIFFUSE_UV_SET );
				Out.SSAOColor.rgb *= vPaletteColorHair.rgb;
				return Out;
			}
		]]
	}

	# MOD(agot)
	MainCode PS_dragon
	{
		Input = "VS_OUTPUT_PDXMESHPORTRAIT"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			PDX_MAIN
			{
				PS_COLOR_SSAO Out;

				float2 UV0 = Input.UV0;
				float2 UV1 = Input.UV1;
				float4 Diffuse = PdxTex2D( DiffuseMap, UV0 );								
				float4 Properties = PdxTex2D( PropertiesMap, UV0 );
				float4 NormalSampleRaw = PdxTex2D( NormalMap, UV0 );
				float3 NormalSample = UnpackRRxGNormal( NormalSampleRaw ) * ( PDX_IsFrontFace ? 1 : -1 );
				float4 ColorMask = PdxTex2D( SSAOColorMap, UV0 );

				// float3 DragonSkinColor = 		float3(0.0f,0.0f,0.0f);
				// float3 DragonHighlightColor = 	float3(0.0f,0.0f,0.0f);
				// float3 DragonEyeColor = 		float3(0.0f,0.0f,0.0f);
				// float3 DragonHornColor = 		float3(0.0f,0.0f,0.0f);

				// GetDragonPalettes( DragonSkinColor, DragonHighlightColor, DragonHornColor, DragonEyeColor );

				// float3 ColorPalette = float3(1.0f,1.0f,1.0f);

				// ColorPalette = lerp(ColorPalette,DragonSkinColor,ColorMask.r);
				// ColorPalette = lerp(ColorPalette,DragonHornColor,ColorMask.g);
				// ColorPalette = lerp(ColorPalette,DragonHighlightColor,ColorMask.b);
				// ColorPalette = lerp(ColorPalette,DragonEyeColor,ColorMask.a);

				// ColorMask.a = 1.0f;

				// Diffuse.rgb = GetColorMaskColorBLend( Diffuse.rgb, ColorPalette, Input.InstanceIndex, ColorMask.a );
				#ifdef DECALS
					AddDragonDecals( Diffuse, NormalSample, Properties, ColorMask, UV0, UV1, Input.InstanceIndex );
				#endif

				// MOD(agot) Debug views - see AGOT_DEBUG_DRAGON_VIEW_* in portrait_decals.fxh.
				// Bypasses lighting entirely; with a neutral portrait environment the screenshot
				// pick is pow(value, 1/2.2). Toggle from console: shader_debug AGOT_DEBUG_DRAGON_VIEW_1
				#ifdef AGOT_DEBUG_DRAGON_VIEW_ANY
					float3 AGOT_DebugOut = AGOT_DragonDebug.rgb;
					#ifdef AGOT_DEBUG_DRAGON_VIEW_1
						AGOT_DebugOut = PdxTex2D( DiffuseMap, UV0 ).rgb;
					#endif
					#ifdef AGOT_DEBUG_DRAGON_VIEW_8
						AGOT_DebugOut = ColorMask.rgb;
					#endif
					#ifdef AGOT_DEBUG_DRAGON_VIEW_9
						AGOT_DebugOut = float3( 0.5f, 0.25f, 0.125f );
					#endif
					#ifdef AGOT_DEBUG_DRAGON_VIEW_11
						AGOT_DebugOut = float3( UV0, 0.0f );
					#endif
					Out.Color = float4( AGOT_DebugOut, 1.0f );
					Out.SSAOColor = float4( 0.0f, 0.0f, 0.0f, 0.0f );
					return Out;
				#endif
				// END MOD

				float3 Color = CommonPixelShader( Diffuse, Properties, NormalSample, Input );

				#ifdef ALPHA_TO_COVERAGE
					Diffuse.a = RescaleAlphaByMipLevel( Diffuse.a, UV0, DiffuseMap );

					const float CUTOFF = 0.5f;
					Diffuse.a = SharpenAlpha( Diffuse.a, CUTOFF );
				#endif

				#ifdef WRITE_ALPHA_ONE
					Out.Color = float4( Color, 1.0f );
				#else
					#ifdef HAIR_TRANSPARENCY_HACK
						// TODO [HL]: Hack to stop clothing fragments from being discarded by transparent hair,
						// proper fix is to ensure that hair is drawn after clothes
						// https://beta.paradoxplaza.com/browse/PSGE-3103
						clip( Diffuse.a - 0.5f );
					#endif

					Out.Color = float4( Color, Diffuse.a );
				#endif

				Out.SSAOColor = float4(0.0f,0.0f,0.0f,0.0f);
				return Out;
			}
		]]
	}

	MainCode PS_dragon_shadow
	{
		Input = "VS_OUTPUT_PDXMESHPORTRAIT"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			PDX_MAIN
			{
				PS_COLOR_SSAO Out;
				Out.Color = float4( 0.0f,0.0f,0.0f,0.5f);
				Out.SSAOColor = float4(0.0f,0.0f,0.0f,0.0f);
				return Out;
			}
		]]
	}

	# MOD(agot) baked-mesh particle cards
	#
	# Unlit on purpose: fire emits light and does not receive it, and the PBR
	# path would let the scene key light set the brightness of the flame.
	MainCode PS_particle_card
	{
		Input = "VS_OUTPUT_PDXMESHPORTRAIT"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			PDX_MAIN
			{
				float4 Diffuse = PdxTex2D( DiffuseMap, Input.UV0 );

				// UV2.y holds the opacity from the bone Z scale.
				float Alpha = Diffuse.a * Input.UV2.y;

				if ( Alpha <= PARTICLE_ALPHA_CLIP )
				{
					discard;
				}

				// The palette fades OUT with age, so a card ends as the flipbook.
				float Age = PARTICLE_AGE_IN( Input );
				float PaletteStrength = PARTICLE_STRENGTH_IN( Input )
				                      * ( 1.0f - PdxParticleRampT( Age ) );

				Diffuse.rgb = PdxParticleApplyPalette( Diffuse.rgb,
				                                       PARTICLE_COLOR_BIRTH_IN( Input ),
				                                       PaletteStrength );

				// gene_dragon_fire_color_custom: the player's own colour, as a
				// turn of the hue wheel. The custom template already zeroed
				// PaletteStrength in the vertex shader, so this spins the plain
				// sheet colour - 0 and 1 are both the stock orange, as a hue
				// wheel wraps.
				//
				// The fade is a lerp in RGB of the FULLY rotated colour, never a
				// scaled hue angle, which would march the plume through every
				// hue in between (blue fire fading through green).
				float FireHue = PARTICLE_FIRE_HUE_IN( Input );
				if ( FireHue > 0.0f )
				{
					float3 FlameHSV = RGBtoHSV( Diffuse.rgb );
					FlameHSV.x = frac( FlameHSV.x + FireHue );
					Diffuse.rgb = lerp( Diffuse.rgb, HSVtoRGB( FlameHSV ),
					                    1.0f - PdxParticleRampT( Age ) );
				}

				PS_COLOR_SSAO Out;
				Out.Color = float4( Diffuse.rgb * PARTICLE_TINT, Alpha );
				// Out of ambient occlusion, or the flame darkens the face behind it.
				Out.SSAOColor = float4( 0.0f, 0.0f, 0.0f, 0.0f );
				return Out;
			}
		]]
	}

	# Lit twin of PS_particle_card, for smoke and anything else that takes light
	# rather than emitting it. Fire is unlit because it is its own light source;
	# smoke is not, and an unlit black card just reads as a hole in the portrait.
	MainCode PS_particle_card_lit
	{
		Input = "VS_OUTPUT_PDXMESHPORTRAIT"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			PDX_MAIN
			{
				float4 Diffuse = PdxTex2D( DiffuseMap, Input.UV0 );

				// UV2.y holds the opacity, already multiplied by the dark gate.
				float Alpha = Diffuse.a * Input.UV2.y;

				if ( Alpha <= PARTICLE_ALPHA_CLIP )
				{
					discard;
				}

				// The sheet supplies the SHAPE; PARTICLE_TINT supplies the
				// colour. Multiplying by the sheet's own greys as well would
				// drag a near-black tint back towards whatever the artist
				// happened to paint.
				//
				// EnvironmentMap is passed rather than referenced: this file's
				// samplers are declared AFTER the includes are concatenated, so
				// an fxh-level function cannot see them. Same reason vanilla's
				// CalculateLightingFromIBL takes one.
				float3 Color = PdxParticleLighting( PARTICLE_TINT,
				                                    normalize( Input.Normal ),
				                                    Input.WorldSpacePos,
				                                    EnvironmentMap );

				PS_COLOR_SSAO Out;
				Out.Color = float4( Color, Alpha );
				// Out of ambient occlusion, like the unlit twin.
				Out.SSAOColor = float4( 0.0f, 0.0f, 0.0f, 0.0f );
				return Out;
			}
		]]
	}
	# END MOD
	#END-MOD
}

BlendState hair_alpha_blend
{
	BlendEnable = yes
	SourceBlend = "SRC_ALPHA"
	DestBlend = "INV_SRC_ALPHA"
	SourceAlpha = "ONE"
	DestAlpha = "INV_SRC_ALPHA"
	WriteMask = "RED|GREEN|BLUE|ALPHA"
}

DepthStencilState hair_alpha_blend
{
	DepthWriteEnable = no
}

BlendState alpha_to_coverage
{
	BlendEnable = yes
	SourceBlend = "SRC_ALPHA"
	DestBlend = "INV_SRC_ALPHA"
	WriteMask = "RED|GREEN|BLUE|ALPHA"
	SourceAlpha = "ONE"
	DestAlpha = "INV_SRC_ALPHA"
	AlphaToCoverage = yes
}

BlendState no_blend_alpha_to_coverage
{
	BlendEnable = no
	AlphaToCoverage = yes
}

# MOD(agot)
DepthStencilState DepthStencilDragon
{
	DepthEnable = yes
	DepthWriteEnable = no
}

# Baked-mesh particle cards.
BlendState particle_card_alpha
{
	BlendEnable = yes
	SourceBlend = "SRC_ALPHA"
	DestBlend = "INV_SRC_ALPHA"
	SourceAlpha = "ONE"
	DestAlpha = "INV_SRC_ALPHA"
	WriteMask = "RED|GREEN|BLUE|ALPHA"
}

# No depth write, or cards occlude each other and leave a hole where two cross.
DepthStencilState particle_card
{
	DepthEnable = yes
	DepthWriteEnable = no
}

#End Mod

RasterizerState rasterizer_no_culling
{
	CullMode = "none"
}
RasterizerState rasterizer_back_culling
{
	CullMode = "back"
}
RasterizerState rasterizer_backfaces
{
	FrontCCW = yes
}
RasterizerState ShadowRasterizerState
{
	#Don't go higher than 10000 as it will make the shadows fall through the mesh
	#AGOT MODIFIED
	# DepthBias = 1000
	# SlopeScaleDepthBias = 10
	DepthBias = 500
	SlopeScaleDepthBias = 2
}
RasterizerState ShadowRasterizerStateBackfaces
{
	DepthBias = 1000
	SlopeScaleDepthBias = 2
	FrontCCW = yes
}

Effect voltara_isolated_portrait_skin
{
	VertexShader = "VS_standard"
	PixelShader = "PS_skin"
	# MOD(agot)
	#Defines = { "SKIN_SCATTERING" "TRANSLUCENCY" "PDX_MESH_BLENDSHAPES" }
	Defines = { "SKIN_SCATTERING" "TRANSLUCENCY" "PDX_MESH_BLENDSHAPES" "AGOT_PORTRAIT_SKIN" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_skinShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_teeth
{
	VertexShader = "VS_standard"
	PixelShader = "PS_skin"
	# MOD(agot)
	# Vanilla also declares a second, earlier portrait_teeth without PDX_MESH_BLENDSHAPES;
	# that duplicate is deliberately dropped here (it lacks PORTRAIT_WIDGET and cannot compile in this TU).
	#Defines = { "SKIN_SCATTERING" "TRANSLUCENCY" "PDX_MESH_BLENDSHAPES" }
	Defines = { "SKIN_SCATTERING" "TRANSLUCENCY" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_skin_face
{
	VertexShader = "VS_standard"
	PixelShader = "PS_skin"
	# MOD(agot)
	#Defines = { "SKIN_SCATTERING" "TRANSLUCENCY" "ENABLE_TEXTURE_OVERRIDE" "PDX_MESH_BLENDSHAPES" }
	Defines = { "SKIN_SCATTERING" "TRANSLUCENCY" "ENABLE_TEXTURE_OVERRIDE" "PDX_MESH_BLENDSHAPES" "AGOT_PORTRAIT_SKIN" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_skin_faceShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_eye
{
	VertexShader = "VS_standard"
	PixelShader = "PS_eye"
	# MOD(agot)
	Defines = { "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment
{
	VertexShader = "VS_standard"
	PixelShader = "PS_attachment"
	# MOD(agot)
	#Defines = { "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachmentShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_pattern
{
	VertexShader = "VS_standard"
	PixelShader = "PS_attachment"
	# MOD(agot)
	#Defines = { "VARIATIONS_ENABLED" "PDX_MESH_BLENDSHAPES" }
	Defines = { "VARIATIONS_ENABLED" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_patternShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_pattern_alpha_to_coverage
{
	VertexShader = "VS_standard"
	PixelShader = "PS_attachment"
	BlendState = "alpha_to_coverage"
	# MOD(agot)
	#Defines = { "VARIATIONS_ENABLED" "PDX_MESH_BLENDSHAPES" }
	Defines = { "VARIATIONS_ENABLED" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_pattern_alpha_to_coverageShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_pattern_no_blend_alpha_to_coverage
{
	VertexShader = "VS_standard"
	PixelShader = "PS_attachment"
	BlendState = "no_blend_alpha_to_coverage"
	# MOD(agot)
	#Defines = { "VARIATIONS_ENABLED" "PDX_MESH_BLENDSHAPES" }
	Defines = { "VARIATIONS_ENABLED" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_pattern_no_blend_alpha_to_coverageShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_variedShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_alpha_to_coverage
{
	VertexShader = "VS_standard"
	PixelShader = "PS_attachment"
	BlendState = "alpha_to_coverage"
	# MOD(agot)
	#Defines = { "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_alpha_to_coverageShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_with_coa
{
	VertexShader = "VS_standard"
	PixelShader = "PS_attachment"
	# MOD(agot)
	#Defines = { "COA_ENABLED" "PDX_MESH_BLENDSHAPES" }
	Defines = { "COA_ENABLED" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_with_coaShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_alpha_to_coverage_with_coa
{
	VertexShader = "VS_standard"
	PixelShader = "PS_attachment"
	BlendState = "alpha_to_coverage"
	# MOD(agot)
	#Defines = { "COA_ENABLED" "PDX_MESH_BLENDSHAPES" }
	Defines = { "COA_ENABLED" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_alpha_to_coverage_with_coaShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET" }
	# END MOD
}

Effect voltara_isolated_portrait_attachment_with_coa_and_variations
{
	VertexShader = "VS_standard"
	PixelShader = "PS_attachment"
	# MOD(agot)
	#Defines = { "COA_ENABLED" "VARIATIONS_ENABLED" "PDX_MESH_BLENDSHAPES" }
	Defines = { "COA_ENABLED" "VARIATIONS_ENABLED" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_with_coa_and_variationsShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_alpha_to_coverage_with_coa_and_variations
{
	VertexShader = "VS_standard"
	PixelShader = "PS_attachment"
	BlendState = "alpha_to_coverage"
	# MOD(agot)
	#Defines = { "COA_ENABLED" "VARIATIONS_ENABLED" "PDX_MESH_BLENDSHAPES" }
	Defines = { "COA_ENABLED" "VARIATIONS_ENABLED" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_alpha_to_coverage_with_coa_and_variationsShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_hair
{
	VertexShader = "VS_standard"
	PixelShader = "PS_hair"
	BlendState = "alpha_to_coverage"
	RasterizerState = "rasterizer_no_culling"
	# MOD(agot)
	#Defines = { "ALPHA_TO_COVERAGE" "PDX_MESH_BLENDSHAPES" }
	Defines = { "ALPHA_TO_COVERAGE" "PDX_MESH_BLENDSHAPES" "HAIR_AGING_DECAL" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_hair_transparency_hack
{
	VertexShader = "VS_standard"
	PixelShader = "PS_hair"
	BlendState = "alpha_to_coverage"
	RasterizerState = "rasterizer_no_culling"
	# MOD(agot)
	#Defines = { "HAIR_TRANSPARENCY_HACK" "PDX_MESH_BLENDSHAPES" }
	Defines = { "HAIR_TRANSPARENCY_HACK" "PDX_MESH_BLENDSHAPES" "HAIR_AGING_DECAL" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_hairShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" }
	Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_hair_double_sided
{
	VertexShader = "VS_standard"
	PixelShader = "PS_hair_double_sided"
	BlendState = "alpha_to_coverage"
	#DepthStencilState = "test_and_write"
	RasterizerState = "rasterizer_no_culling"
	# MOD(agot)
	#Defines = { "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDX_MESH_BLENDSHAPES" "HAIR_AGING_DECAL" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_hair_alpha
{
	VertexShader = "VS_standard"
	PixelShader = "PS_hair"
	BlendState = "hair_alpha_blend"
	DepthStencilState = "hair_alpha_blend"
	# MOD(agot)
	#Defines = { "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDX_MESH_BLENDSHAPES" "HAIR_AGING_DECAL" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_hair_decrease_specular_light_alpha
{
	VertexShader = "VS_standard"
	PixelShader = "PS_hair"
	BlendState = "hair_alpha_blend"
	DepthStencilState = "hair_alpha_blend"
	Defines = { "PDX_MESH_BLENDSHAPES" "PDX_DECREASE_SPECULAR_LIGHT" }
}

Effect voltara_isolated_portrait_hair_opaque
{
	VertexShader = "VS_standard"
	PixelShader = "PS_hair"
	
	# MOD(agot)
	#Defines = { "WRITE_ALPHA_ONE" "PDX_MESH_BLENDSHAPES" }
	Defines = { "WRITE_ALPHA_ONE" "PDX_MESH_BLENDSHAPES" "HAIR_AGING_DECAL" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_hair_opaqueShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" }
	Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_alpha
{
	VertexShader = "VS_standard"
	PixelShader = "PS_attachment"
	BlendState = "hair_alpha_blend"
	DepthStencilState = "hair_alpha_blend"
	# MOD(agot)
	Defines = { "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_attachment_alphaShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	# MOD(agot)
	#Defines = { "PDX_MESH_BLENDSHAPES" }
	Defines = { "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_hair_backside
{
	VertexShader = "VS_standard"
	PixelShader = "PS_portrait_hair_backface"
	RasterizerState = "rasterizer_backfaces"
	# MOD(agot)
	Defines = { "HAIR_AGING_DECAL" "PORTRAIT_WIDGET"}
	# END MOD
}

Effect voltara_isolated_portrait_anisotropic_hair
{
	VertexShader = "VS_standard"
	PixelShader = "PS_anisotropic_hair"
	BlendState = "alpha_to_coverage"
	RasterizerState = "rasterizer_no_culling"
	Defines = { "ALPHA_TO_COVERAGE" "PDX_MESH_BLENDSHAPES" "USE_FLOWMAP" }
}

Effect voltara_isolated_portrait_anisotropic_hairShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" }
}

Effect voltara_isolated_portrait_anisotropic_hair_no_flow
{
	VertexShader = "VS_standard"
	PixelShader = "PS_anisotropic_hair"
	BlendState = "alpha_to_coverage"
	RasterizerState = "rasterizer_no_culling"
	Defines = { "ALPHA_TO_COVERAGE" "PDX_MESH_BLENDSHAPES" }
}

Effect voltara_isolated_portrait_anisotropic_hair_no_flowShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = "ShadowRasterizerState"
	Defines = { "PDXMESH_DISABLE_DITHERED_OPACITY" }
}
# MOD(agot)
Effect voltara_isolated_portrait_skin_no_decal
{
	VertexShader = "VS_standard"
	PixelShader = "PS_skin"
	Defines = { "FAKE_SSS_EMISSIVE" "PDX_MESH_BLENDSHAPES" "NO_DECAL"}
}
# END MOD

# MOD(agot)
Effect voltara_isolated_skin_alpha
{
	VertexShader = "VS_standard"
	PixelShader = "PS_skin_alpha"
	Defines = {"PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
}

Effect voltara_isolated_portrait_skin_hair_color
{
	VertexShader = "VS_standard"
	PixelShader = "PS_skin"
	Defines = {"PDX_MESH_BLENDSHAPES" "FAKE_SSS_EMISSIVE" "SKIN_TO_HAIR_COLOR" "AGOT_PORTRAIT_SKIN" "PORTRAIT_WIDGET"}
}

Effect voltara_isolated_portrait_eye_no_decal
{
	VertexShader = "VS_standard"
	PixelShader = "PS_eye"
	Defines = {"PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
}

Effect voltara_isolated_portrait_eye_shift
{
	VertexShader = "VS_standard"
	PixelShader = "PS_eye"
	Defines = {"PDX_MESH_BLENDSHAPES" "EYE_DECAL" "HSV_SHIFT" "PORTRAIT_WIDGET"}
}

Effect voltara_isolated_portrait_eye_blind
{
	VertexShader = "VS_standard"
	PixelShader = "PS_eye"
	Defines = {"PDX_MESH_BLENDSHAPES" "EYE_DECAL" "EYE_BLIND" "PORTRAIT_WIDGET"}
}

Effect voltara_isolated_portrait_attachment_refract
{
	VertexShader = "VS_standard"
	PixelShader = "PS_attachment"
	#BlendState = "hair_alpha_blend"
	#DepthStencilState = "hair_alpha_blend"
	Defines = { "PDX_MESH_BLENDSHAPES" "ATTACHEMENT_DECAY" "REFRACT" "PORTRAIT_WIDGET"}
}

Effect voltara_isolated_portrait_attachment_pattern_refract
{
	VertexShader = "VS_standard"
	PixelShader = "PS_attachment"
	#BlendState = "hair_alpha_blend"
	#DepthStencilState = "hair_alpha_blend"
	Defines = {"PDX_MESH_BLENDSHAPES" "VARIATIONS_ENABLED" "ATTACHEMENT_DECAY" "REFRACT" "PORTRAIT_WIDGET"}
}
# END MOD

# MOD(agot)
Effect voltara_isolated_portrait_dragon
{
	VertexShader = "VS_standard"
	PixelShader = "PS_dragon"
	Defines = { "ALPHA_TO_COVERAGE" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET"}
}

Effect voltara_isolated_portrait_dragon_shadow
{
	VertexShader = "VS_standard"
	PixelShader = "PS_dragon_shadow"
	RasterizerState = "ShadowRasterizerState"
	DepthStencilState = DepthStencilDragon
	Defines = { "ALPHA_TO_COVERAGE" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET" "SHADOW_HACK"}
}

Effect voltara_isolated_portrait_dragon_decals
{
	VertexShader = "VS_standard"
	PixelShader = "PS_dragon"
	Defines = { "ALPHA_TO_COVERAGE" "PDX_MESH_BLENDSHAPES" "DECALS" "PORTRAIT_WIDGET"}
}

Effect voltara_isolated_portrait_dragon_decals_shadow
{
	VertexShader = "VS_standard"
	PixelShader = "PS_dragon_shadow"
	RasterizerState = "ShadowRasterizerState"
	DepthStencilState = DepthStencilDragon
	Defines = { "ALPHA_TO_COVERAGE" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET" "SHADOW_HACK"}
}

Effect voltara_isolated_portrait_dragon_wing_decals
{
	VertexShader = "VS_standard"
	PixelShader = "PS_dragon"
	RasterizerState = "rasterizer_no_culling"
	Defines = { "ALPHA_TO_COVERAGE" "PDX_MESH_BLENDSHAPES" "DECALS" "PORTRAIT_WIDGET"}
}

Effect voltara_isolated_portrait_dragon_wing_decals_shadow
{
	VertexShader = "VS_standard"
	PixelShader = "PS_dragon_shadow"
	RasterizerState = "ShadowRasterizerState"
	DepthStencilState = DepthStencilDragon
	Defines = { "ALPHA_TO_COVERAGE" "PDX_MESH_BLENDSHAPES" "PORTRAIT_WIDGET" "SHADOW_HACK"}
}
#END-MOD

#MOD-AGOT baked-mesh particle cards - see agot/gfx/FX/agot_particle_card.fxh
#
# EVERY effect here needs a matching one in court_scene.shader - <name>,
# <name>_selection, and <name>_shadow if a Shadow variant is ever added. Miss any
# and no material builds, so the mesh never draws at all.
#
# No Shadow variant is declared, which keeps the fire out of the shadow pass.
#
# Per-mesh controls go in meshsettings/additional_shader_defines.

# Unlit and tinted by the wearer's dragon palette. For fire, which is its own
# light source.
Effect voltara_isolated_portrait_particle_card_dragon
{
	VertexShader = "VS_particle_card"
	PixelShader = "PS_particle_card"
	BlendState = "particle_card_alpha"
	DepthStencilState = "particle_card"
	RasterizerState = "rasterizer_no_culling"
	Defines = { "PORTRAIT_WIDGET" "PARTICLE_BILLBOARD" "PARTICLE_DRAGON_PALETTE" }
}

# Lit, and shown only on a dark dragon. For smoke: it takes light instead of
# emitting it, so it sits in the scene rather than glowing out of it.
#
# PARTICLE_DRAGON_DARK_GATE instead of PARTICLE_DRAGON_PALETTE - the two are
# mutually exclusive. The palette spends Normal/Tangent/Bitangent on colour,
# and a lit card needs that basis for its normal. The gate needs no
# interpolator at all: it rides the opacity, and closes by collapsing the quad
# in the vertex shader so a pale dragon costs no fill.
Effect voltara_isolated_portrait_particle_card_dragon_lit
{
	VertexShader = "VS_particle_card"
	PixelShader = "PS_particle_card_lit"
	BlendState = "particle_card_alpha"
	DepthStencilState = "particle_card"
	RasterizerState = "rasterizer_no_culling"
	Defines = { "PORTRAIT_WIDGET" "PARTICLE_BILLBOARD" "PARTICLE_LIT" "PARTICLE_DRAGON_DARK_GATE" }
}
#END-MOD
