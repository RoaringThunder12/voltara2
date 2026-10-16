Includes = {
	"voltara_dragon/cw/camera.fxh"
	"voltara_dragon/cw/random.fxh"
	"voltara_dragon/cw/pdxmesh_buffers.fxh"
}

VertexShader =
{
	Code
	[[
		struct VS_OUTPUT_PDXMESH
		{
			float4 Position;
			float3 WorldSpacePos;
			float3 Normal;
			float3 Tangent;
			float3 Bitangent;
			float2 UV0;
			float2 UV1;
			float2 UV2;
		};
		
		struct VS_INPUT_PDXMESH
		{
			float3 Position;
			float3 Normal;
			float4 Tangent;
			float2 UV0;
		#ifdef PDX_MESH_UV1
			float2 UV1;
		#endif
		#ifdef PDX_MESH_UV2
			float2 UV2;
		#endif
		#ifdef PDX_MESH_SKINNED
			uint4 BoneIndex;
			float3 BoneWeight;
		#endif
		#ifdef PDX_MESH_BLENDSHAPES
			uint ObjectInstanceIndex;
			uint BlendShapeInstanceIndex;
			uint VertexID;
		#endif
		};
		
		VS_INPUT_PDXMESH PdxMeshConvertInput( in VS_INPUT_PDXMESHSTANDARD Input )
		{
			VS_INPUT_PDXMESH Out;
			Out.Position = Input.Position;
			Out.Normal = Input.Normal;
			Out.Tangent = Input.Tangent;
			Out.UV0 = Input.UV0;
		#ifdef PDX_MESH_UV1
			Out.UV1 = Input.UV1;
		#endif
		#ifdef PDX_MESH_UV2
			Out.UV2 = Input.UV2;
		#endif
		#ifdef PDX_MESH_SKINNED
			Out.BoneIndex = Input.BoneIndex;
			Out.BoneWeight = Input.BoneWeight;
		#endif
		#ifdef PDX_MESH_BLENDSHAPES
			Out.ObjectInstanceIndex = Input.InstanceIndices.y;
			Out.BlendShapeInstanceIndex = Input.InstanceIndices.z;
			Out.VertexID = Input.VertexID;
		#endif

			return Out;
		}
		
	// This depends on the heightmap.fxh, the shader that enables this define will need to include that fxh
	#ifdef PDX_MESH_SNAP_VERTICES_TO_TERRAIN
		float3 SnapVerticesToTerrain( float2 WorldSpacePosXZ, float VertexY, float4x4 WorldMatrix )
		{
			float YScale = length( float3( GetMatrixData( WorldMatrix, 0, 1 ), GetMatrixData( WorldMatrix, 1, 1 ), GetMatrixData( WorldMatrix, 2, 1 ) ) );
			return float3( WorldSpacePosXZ.x, GetHeight( WorldSpacePosXZ ) + VertexY * YScale, WorldSpacePosXZ.y );
		}
	#endif
		
	#ifdef PDX_MESH_SKINNED
		VS_OUTPUT_PDXMESH PdxMeshVertexShader( VS_INPUT_PDXMESH Input, uint JointsInstanceIndex, float4x4 WorldMatrix )
		{
			VS_OUTPUT_PDXMESH Out;

			float4 Position = float4( Input.Position.xyz, 1.0 );
			float3 BaseNormal = Input.Normal;
			float3 BaseTangent = Input.Tangent.xyz;

		#ifdef PDX_MESH_BLENDSHAPES
			ApplyBlendShapes( Position.xyz, BaseNormal, BaseTangent, Input.BlendShapeInstanceIndex, Input.ObjectInstanceIndex, Input.VertexID );
		#endif

			float4 SkinnedPosition = vec4( 0.0 );
			float3 SkinnedNormal = vec3( 0.0 );
			float3 SkinnedTangent = vec3( 0.0 );
			float3 SkinnedBitangent = vec3( 0.0 );

			float4 Weights = float4( Input.BoneWeight.xyz, 1.0 - Input.BoneWeight.x - Input.BoneWeight.y - Input.BoneWeight.z );
			for( int i = 0; i < PDXMESH_MAX_INFLUENCE; ++i )
			{
				uint BoneIndex = Input.BoneIndex[i];
				uint OffsetIndex = BoneIndex + JointsInstanceIndex;

				float4x4 VertexMatrix = PdxMeshGetJointVertexMatrix( OffsetIndex );

				SkinnedPosition += mul( VertexMatrix, Position ) * Weights[ i ];

				float3 XAxis = float3( GetMatrixData( VertexMatrix, 0, 0 ), GetMatrixData( VertexMatrix, 0, 1 ), GetMatrixData( VertexMatrix, 0, 2 ) );
				float3 YAxis = float3( GetMatrixData( VertexMatrix, 1, 0 ), GetMatrixData( VertexMatrix, 1, 1 ), GetMatrixData( VertexMatrix, 1, 2 ) );
				float3 ZAxis = float3( GetMatrixData( VertexMatrix, 2, 0 ), GetMatrixData( VertexMatrix, 2, 1 ), GetMatrixData( VertexMatrix, 2, 2 ) );
				
				float XSqMagnitude = dot( XAxis, XAxis );
				float YSqMagnitude = dot( YAxis, YAxis );
				float ZSqMagnitude = dot( ZAxis, ZAxis );
				
				float3 SqScale = float3( XSqMagnitude, YSqMagnitude, ZSqMagnitude );
				float3 SqScaleReciprocal = float3( 1.f, 1.f, 1.f ) / SqScale;
				
				float3 ScaledNormal = BaseNormal * SqScaleReciprocal;
				float3 ScaledTangent = BaseTangent * SqScaleReciprocal;
				
				float3x3 VertexRotationMatrix = CastTo3x3( VertexMatrix );
				
				float3 Normal = mul( VertexRotationMatrix, ScaledNormal );
				float3 Tangent = mul( VertexRotationMatrix, ScaledTangent );
				float3 Bitangent = cross( Normal, Tangent ) * Input.Tangent.w;

				Normal = normalize( Normal );
				Tangent = normalize( Tangent );
				Bitangent = normalize( Bitangent );

				SkinnedNormal += Normal * Weights[i];
				SkinnedTangent += Tangent * Weights[i];
				SkinnedBitangent += Bitangent * Weights[i];
			}

			Out.Position = mul( WorldMatrix, SkinnedPosition );

			// MOD(agot)
			#ifdef SHADOW_HACK
				float3 averageLightDirection = float3(0.0, 0.0, 0.0);
				float totalIntensity = 0.0;

				for (int i = 0; i < 3; ++i)
				{
					// Get the light type
					float lightType = Light_Direction_Type[i].w;
					
					// Ignore point lights
					if (lightType == LIGHT_TYPE_POINTLIGHT)
					{
						continue;
					}

					// Calculate the light direction and intensity
					float3 lightDirection = -Light_Direction_Type[i].xyz;
					float3 lightIntensity = Light_Color_Falloff[i].rgb;
					float intensity = length(lightIntensity);
					
					// Accumulate the weighted light direction
					averageLightDirection += lightDirection * intensity;
					totalIntensity += intensity;
				}

				// Normalize the average light direction
				if (totalIntensity > 0.0)
				{
					averageLightDirection = normalize(averageLightDirection / totalIntensity);
				}
				else
				{
					// Default light direction if no valid lights
					averageLightDirection = float3( 0.0, -1.0, -0.5);
				}

				// Define the floor normal and floor height
				float3 floorNormal = float3(0.0, 1.0, 0.0); // Floor normal (assuming the floor is flat on the XZ plane)
				float floorHeight = 0.0; // Floor height (assuming the floor is at y = 0)

				// Calculate the dot product between light direction and floor normal
				float dotLN = dot(averageLightDirection, floorNormal);

				// Calculate the projection factor
				float projectionFactor = (floorHeight - dot(Out.Position.xyz, floorNormal)) / dotLN;

				// Compute the projected position
				float3 projectedPosition = Out.Position.xyz + averageLightDirection * projectionFactor;

				// Set the output position to the projected position
				Out.Position = float4(projectedPosition, Out.Position.w);
			#endif
			// END MOD

			Out.WorldSpacePos = Out.Position.xyz;
			Out.WorldSpacePos /= WorldMatrix[3][3];
			Out.Position = FixProjectionAndMul( ViewProjectionMatrix, Out.Position );

			Out.Normal = normalize( mul( CastTo3x3(WorldMatrix), normalize( SkinnedNormal ) ) );
			Out.Tangent = normalize( mul( CastTo3x3(WorldMatrix), normalize( SkinnedTangent ) ) );
			Out.Bitangent = normalize( mul( CastTo3x3(WorldMatrix), normalize( SkinnedBitangent ) ) );

			Out.UV0 = Input.UV0;
		#ifdef PDX_MESH_UV1
			Out.UV1 = Input.UV1;
		#else
			Out.UV1 = vec2( 0.0 );
		#endif
		#ifdef PDX_MESH_UV2
			Out.UV2 = Input.UV2;
		#else
			Out.UV2 = vec2( 0.0 );
		#endif

			return Out;
		}
		
	#else
	
		VS_OUTPUT_PDXMESH PdxMeshVertexShader( VS_INPUT_PDXMESH Input, uint JointsInstanceIndex, float4x4 WorldMatrix )
		{
			VS_OUTPUT_PDXMESH Out;
	
			float4 Position = float4( Input.Position.xyz, 1.0 );
			float3 Normal = Input.Normal;
			float3 Tangent = Input.Tangent.xyz;

		#ifdef PDX_MESH_BLENDSHAPES
			ApplyBlendShapes( Position.xyz, Normal, Tangent, Input.BlendShapeInstanceIndex, Input.ObjectInstanceIndex, Input.VertexID );
		#endif

			Out.Normal = normalize( mul( CastTo3x3( WorldMatrix ), Normal ) );
			Out.Tangent = normalize( mul( CastTo3x3( WorldMatrix ), Tangent ) );
			Out.Bitangent = normalize( cross( Out.Normal, Out.Tangent ) * Input.Tangent.w );
			Out.Position = mul( WorldMatrix, Position );
			
		#ifdef PDX_MESH_SNAP_VERTICES_TO_TERRAIN
			Out.Position.xyz = SnapVerticesToTerrain( Out.Position.xz, Input.Position.y, WorldMatrix );
		#endif
		
			Out.WorldSpacePos = Out.Position.xyz;
			Out.WorldSpacePos /= WorldMatrix[3][3];
			Out.Position = FixProjectionAndMul( ViewProjectionMatrix, Out.Position );
	
			Out.UV0 = Input.UV0;
		#ifdef PDX_MESH_UV1
			Out.UV1 = Input.UV1;
		#else
			Out.UV1 = vec2( 0.0 );
		#endif
		#ifdef PDX_MESH_UV2
			Out.UV2 = Input.UV2;
		#else
			Out.UV2 = vec2( 0.0 );
		#endif
	
			return Out;
		}
		
	#endif
	
	VS_OUTPUT_PDXMESH PdxMeshVertexShaderStandard( VS_INPUT_PDXMESHSTANDARD Input )
	{
		return PdxMeshVertexShader( PdxMeshConvertInput( Input ), Input.InstanceIndices.x, PdxMeshGetWorldMatrix( Input.InstanceIndices.y ) );
	}
	
	VS_OUTPUT_PDXMESHSHADOW PdxMeshVertexShaderShadow( VS_INPUT_PDXMESH Input, uint JointsInstanceIndex, float4x4 WorldMatrix )
	{
		VS_OUTPUT_PDXMESHSHADOW Out;
				
		float4 Position = float4( Input.Position.xyz, 1.0 );

	#ifdef PDX_MESH_BLENDSHAPES
		ApplyBlendShapesPositionOnly( Position.xyz, Input.BlendShapeInstanceIndex, Input.ObjectInstanceIndex, Input.VertexID );
	#endif
		
	#ifdef PDX_MESH_SKINNED
		float4 vWeight = float4( Input.BoneWeight.xyz, 1.0 - Input.BoneWeight.x - Input.BoneWeight.y - Input.BoneWeight.z );
		float4 vSkinnedPosition = vec4( 0.0 );
		for( int i = 0; i < PDXMESH_MAX_INFLUENCE; ++i )
		{
			int nIndex = int( Input.BoneIndex[i] );
			float4x4 VertexMatrix = PdxMeshGetJointVertexMatrix( nIndex + JointsInstanceIndex );
			vSkinnedPosition += mul( VertexMatrix, Position ) * vWeight[ i ];
		}
		Out.Position = mul( WorldMatrix, vSkinnedPosition );
	#else
		Out.Position = mul( WorldMatrix, Position );
		
		#ifdef PDX_MESH_SNAP_VERTICES_TO_TERRAIN
			Out.Position.xyz = SnapVerticesToTerrain( Out.Position.xz, Input.Position.y, WorldMatrix );
		#endif
	#endif
		Out.Position = FixProjectionAndMul( ViewProjectionMatrix, Out.Position );
		Out.UV = Input.UV0;
		return Out;
	}
	VS_OUTPUT_PDXMESHSHADOWSTANDARD PdxMeshVertexShaderShadowStandard( VS_INPUT_PDXMESHSTANDARD Input )
	{
		VS_OUTPUT_PDXMESHSHADOW CommonOut = PdxMeshVertexShaderShadow( PdxMeshConvertInput(Input), Input.InstanceIndices.x, PdxMeshGetWorldMatrix( Input.InstanceIndices.y ) );
		VS_OUTPUT_PDXMESHSHADOWSTANDARD Out;
		Out.Position = CommonOut.Position;
		Out.UV_InstanceIndex.xy = CommonOut.UV;
		Out.UV_InstanceIndex.z = Input.InstanceIndices.y;
		return Out;
	}
	]]

	MainCode VertexPdxMeshStandardShadow
	{
		Input = "VS_INPUT_PDXMESHSTANDARD"
		Output = "VS_OUTPUT_PDXMESHSHADOWSTANDARD"
		Code
		[[
			PDX_MAIN
			{
				return PdxMeshVertexShaderShadowStandard( Input );
			}
		]]
	}
	
	MainCode VertexDebugNormal
	{
		Input = "VS_INPUT_DEBUGNORMAL"
		Output = "VS_OUTPUT_DEBUGNORMAL"
		Code
		[[
			PDX_MAIN
			{
				VS_OUTPUT_DEBUGNORMAL Out;
				
				float NormalOffset = float( Input.VertexID % 2 ) /* Multiply here to change the normal lengths*/; 
				
				float4x4 WorldMatrix = PdxMeshGetWorldMatrix( Input.InstanceIndices.y );
				
				Input.Position = Input.Position + Input.Normal * NormalOffset;

			#ifdef PDX_MESH_SKINNED
				float4 Position = float4( Input.Position.xyz, 1.0 );
				
				float4 vWeight = float4( Input.BoneWeight.xyz, 1.0 - Input.BoneWeight.x - Input.BoneWeight.y - Input.BoneWeight.z );
				float4 vSkinnedPosition = vec4( 0.0 );

				for( int i = 0; i < PDXMESH_MAX_INFLUENCE; ++i )
				{
					int nIndex = int( Input.BoneIndex[i] );
					float4x4 VertexMatrix = PdxMeshGetJointVertexMatrix( nIndex + Input.InstanceIndices.x );
					vSkinnedPosition += mul( VertexMatrix, Position ) * vWeight[ i ];
				}

				Out.Position = mul( WorldMatrix, vSkinnedPosition );
			#else
				Out.Position = mul( WorldMatrix, float4( Input.Position.xyz, 1.0 ) );
			#endif

				Out.Position = FixProjectionAndMul( ViewProjectionMatrix, Out.Position );

				return Out;
			}
		]]
	}
}


PixelShader =
{
	Code
	[[
		#ifndef PDXMESH_AlphaBlendShadowMap
			#define PDXMESH_AlphaBlendShadowMap DiffuseMap
		#endif
		
		#ifndef PDXMESH_DISABLE_DITHERED_OPACITY
			#define PDXMESH_USE_DITHERED_OPACITY
		#endif
		
		void PdxMeshApplyDitheredOpacity( in float Opacity, in float2 NoiseCoordinate )
		{
			#ifdef PDXMESH_SCREENDOOR_DITHER				
				const float4x4 ThresholdMatrix =
				{
					1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
					13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
					4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
					16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
				};
				float Factor = ThresholdMatrix[NoiseCoordinate.x % 4][NoiseCoordinate.y % 4];
			#else
				float Factor = CalcRandom( NoiseCoordinate );
			#endif
			
			clip( Opacity - Factor * sign( Opacity ) );
		}
		
		float PdxMeshApplyOpacity( in float Alpha, in float2 NoiseCoordinate, in float Opacity )
		{
			#ifdef PDXMESH_USE_DITHERED_OPACITY
				if( Opacity < 1.0f )
				{
					PdxMeshApplyDitheredOpacity( Opacity, NoiseCoordinate );
				}
			#endif
			return Alpha;
		}
	]]

	MainCode PixelPdxMeshStandardShadow
	{
		Input = "VS_OUTPUT_PDXMESHSHADOWSTANDARD"
		Output = "void"
		Code
		[[
			PDX_MAIN
			{
			#ifdef PDXMESH_USE_DITHERED_OPACITY
				float Opacity = PdxMeshGetOpacity( uint( Input.UV_InstanceIndex.z + 0.5 ) ); // +0.5 to "round", it seems floating point errors can sneak in when interpolating
				PdxMeshApplyDitheredOpacity( Opacity, Input.Position.xy );
			#endif
			}
		]]
	}
	
	MainCode PixelPdxMeshAlphaBlendShadow
	{
		Input = "VS_OUTPUT_PDXMESHSHADOWSTANDARD"
		Output = "void"
		Code 
		[[
			PDX_MAIN
			{
				float Alpha = PdxTex2D( PDXMESH_AlphaBlendShadowMap, Input.UV_InstanceIndex.xy ).a;
			#ifdef PDXMESH_USE_DITHERED_OPACITY
				float Opacity = PdxMeshGetOpacity( uint( Input.UV_InstanceIndex.z + 0.5 ) ); // +0.5 to "round", it seems floating point errors can sneak in when interpolating
				PdxMeshApplyDitheredOpacity( Opacity, Input.Position.xy );
			#endif
				clip( Alpha - 0.5 );
			}
		]]
	}
	
	MainCode PixelDebugNormal
	{
		Input = "VS_OUTPUT_DEBUGNORMAL"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				float4 vColor = float4( 0.f, 1.f, 0.25f, 1.f );
				return vColor;
			}
		]]
	}
}

Effect DebugNormal
{
	VertexShader = "VertexDebugNormal"
	PixelShader = "PixelDebugNormal"
}
