
VertexStruct VS_INPUT_PDXMESHSTANDARD
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

	# Instance array offset indices, [JointDataIndex][ObjectDataIndex][BlendShapeDataIndex][Unused]
	uint4 InstanceIndices 	: TEXCOORD5;

@ifdef PDX_MESH_SKINNED
	uint4 BoneIndex 		: TEXCOORD6;
	float3 BoneWeight		: TEXCOORD7;
@endif

#ifdef PDX_MESH_BLENDSHAPES
	uint VertexID			: PDX_VertexID;
#endif
};

VertexStruct VS_OUTPUT_PDXMESHSHADOW
{
    float4 Position			: PDX_POSITION;
	float2 UV				: TEXCOORD0;
};
VertexStruct VS_OUTPUT_PDXMESHSHADOWSTANDARD
{
	float4 Position				: PDX_POSITION;
	float3 UV_InstanceIndex		: TEXCOORD0;
};

VertexStruct VS_INPUT_DEBUGNORMAL
{
    float3 Position			: POSITION;
	float3 Normal 			: TEXCOORD0
@ifdef PDX_MESH_SKINNED
	uint4 BoneIndex 		: TEXCOORD1;
	float3 BoneWeight		: TEXCOORD2;
@endif
	uint2 InstanceIndices 	: TEXCOORD4;
	
	uint VertexID           : PDX_VertexID;
};

VertexStruct VS_OUTPUT_DEBUGNORMAL
{
    float4 Position 	: PDX_POSITION;
};

ConstantBuffer( PdxMeshInstanceData )
{
	float4 Data[2]; # TODO, setting to 4096 makes hlsl compile take ages, and this seems to produce the same code
};

ConstantBuffer( PdxMeshJointVertexInstanceData )
{
	# Stored as 34 matrices
	float4 JointVertexMatrices[3];
};

Code
[[
	static const int PDXMESH_MAX_INFLUENCE = 4;
	static const int PDXMESH_WORLD_MATRIX_OFFSET = 0;
	static const int PDXMESH_CONSTANTS_OFFSET = 4;
	static const int PDXMESH_USER_DATA_OFFSET = 5;
	
	float4x4 PdxMeshGetWorldMatrix( uint nIndex )
	{
		return Create4x4( 
			Data[nIndex + PDXMESH_WORLD_MATRIX_OFFSET + 0], 
			Data[nIndex + PDXMESH_WORLD_MATRIX_OFFSET + 1], 
			Data[nIndex + PDXMESH_WORLD_MATRIX_OFFSET + 2], 
			Data[nIndex + PDXMESH_WORLD_MATRIX_OFFSET + 3] );
	}

	// OffsetJointIndex -> JointsInstanceIndex + JointIndex
	float4x4 PdxMeshGetJointVertexMatrix( uint OffsetJointIndex )
	{
		uint BeginIndex = OffsetJointIndex * 3;

		float4 XAxis = float4( JointVertexMatrices[ BeginIndex ].x, JointVertexMatrices[ BeginIndex ].y, JointVertexMatrices[ BeginIndex ].z, 0.0f );
		float4 YAxis = float4( JointVertexMatrices[ BeginIndex ].w, JointVertexMatrices[ BeginIndex + 1 ].x, JointVertexMatrices[ BeginIndex + 1 ].y, 0.0f );
		float4 ZAxis = float4( JointVertexMatrices[ BeginIndex + 1 ].z, JointVertexMatrices[ BeginIndex + 1 ].w, JointVertexMatrices[ BeginIndex + 2 ].x, 0.0f );
		float4 Translation = float4( JointVertexMatrices[ BeginIndex + 2 ].y, JointVertexMatrices[ BeginIndex + 2 ].z, JointVertexMatrices[ BeginIndex + 2 ].w, 1.0f );

		return Create4x4( XAxis, YAxis, ZAxis, Translation );
	}

	float PdxMeshGetOpacity( uint ObjectInstanceIndex )
	{
		return Data[ ObjectInstanceIndex + PDXMESH_CONSTANTS_OFFSET ].x;
	} 
	
	uint GetActiveBlendShapes( uint ObjectInstanceIndex )
	{
		return uint( Data[ ObjectInstanceIndex + PDXMESH_CONSTANTS_OFFSET ].y );
	}

	uint GetActiveDecals( uint ObjectInstanceIndex ) 
	{
		return uint( Data[ ObjectInstanceIndex + PDXMESH_CONSTANTS_OFFSET ].z );
	}

	float PdxMeshGetMeshDummyValue( uint ObjectInstanceIndex ) 
	{
		return Data[ ObjectInstanceIndex + PDXMESH_CONSTANTS_OFFSET ].w;
	}
]]
