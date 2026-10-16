Includes = {
	"voltara_dragon/cw/pdxmesh_buffers.fxh"
}

ConstantBuffer( PdxMeshBlendShapeInstanceData )
{
	# Layout per instance [Indices...][Weights...]
	float4 BlendShapeDataInstanced[2];
};

ConstantBuffer( PdxMeshBlendShapeConstants )
{
	# The vertex count corresponds to the total number of vertices in one (1) set of blendshape data in 
	# the blendshape buffer texture
	uint 	BlendShapeVertexCount;

	# The blendshape buffer holds vertex data of submeshes, lods etc. This vertex offset corresponds to the offset of 
	# the first vertex of the current submesh
	uint 	BlendShapesVertexOffset;
};

VertexShader = {
	BufferTexture BlendShapeDataBuffer
	{
		Ref = PdxMeshBlendShapeTexture
		type = float #TODO [FM]: PSGE-3910 change to float3 format
	}

	Code
	[[
		float GetFloatAt( uint FloatIndex )
		{
			uint VectorIndex = FloatIndex / 4;
			uint ComponentIndex = FloatIndex % 4;

			return BlendShapeDataInstanced[ VectorIndex ][ ComponentIndex ];
		}

		uint GetUintAt( uint LookupIndex )
		{
			return uint( GetFloatAt( LookupIndex ) );
		}

		uint CalcLinearBlendBufferIndex( uint VertexIndex, uint VertexDataIndex )
		{
			return ( VertexDataIndex * BlendShapeVertexCount + VertexIndex );
		}
		
		float3 ReadBlendBufferTextureFloat3( uint AtVectorIndex )
		{
			int AtFloat = int( AtVectorIndex ) * 3;
			float X = PdxReadBuffer( BlendShapeDataBuffer, AtFloat );
			float Y = PdxReadBuffer( BlendShapeDataBuffer, AtFloat + 1 );
			float Z = PdxReadBuffer( BlendShapeDataBuffer, AtFloat + 2 );
			
			return float3( X, Y, Z );
		}
		
		void ApplyBlendShapes( inout float3 PositionOut, inout float3 NormalOut, inout float3 TangentOut, in uint BlendShapeInstanceIndex, in uint ObjectInstanceIndex, in uint VertexID )
		{
			uint VertexIndex = VertexID + BlendShapesVertexOffset;
					
			uint VectorIndex = 0;
			uint VectorElement = 0;

			uint ActiveBlendShapes = GetActiveBlendShapes( ObjectInstanceIndex );

			uint IndicesOffset = BlendShapeInstanceIndex;
			uint WeightsOffset = IndicesOffset + ActiveBlendShapes;

			for (uint CurrentBlendShapeIndex = 0; CurrentBlendShapeIndex < ActiveBlendShapes; ++CurrentBlendShapeIndex) 
			{
				float Weight = GetFloatAt( WeightsOffset + CurrentBlendShapeIndex );
				uint BlendShapeOffsetIndex = GetUintAt( IndicesOffset + CurrentBlendShapeIndex );

				uint VertexDataIndex = BlendShapeOffsetIndex * 3;
					
				PositionOut += ReadBlendBufferTextureFloat3( CalcLinearBlendBufferIndex( VertexIndex, VertexDataIndex ) ).xyz * Weight;
				++VertexDataIndex;
				NormalOut += ReadBlendBufferTextureFloat3( CalcLinearBlendBufferIndex( VertexIndex, VertexDataIndex ) ).xyz * Weight;
				++VertexDataIndex;
				TangentOut += ReadBlendBufferTextureFloat3( CalcLinearBlendBufferIndex( VertexIndex, VertexDataIndex ) ).xyz * Weight;
				++VertexDataIndex;
				++VectorElement;
				if (VectorElement == 4)
				{
					VectorElement = 0;
					++VectorIndex;
				}
			}

			NormalOut = normalize( NormalOut );
			TangentOut = normalize( TangentOut );
		}
		
		void ApplyBlendShapesPositionOnly( inout float3 PositionOut, in uint BlendShapeInstanceIndex, in uint ObjectInstanceIndex, in uint VertexID )
		{
			uint VertexIndex = VertexID + BlendShapesVertexOffset;
			uint VectorIndex = 0; 
			uint VectorElement = 0;

			uint ActiveBlendShapes = GetActiveBlendShapes( ObjectInstanceIndex );

			uint IndicesOffset = BlendShapeInstanceIndex;
			uint WeightsOffset = IndicesOffset + ActiveBlendShapes;

			for ( uint CurrentBlendShapeIndex = 0; CurrentBlendShapeIndex < ActiveBlendShapes; ++CurrentBlendShapeIndex )
			{
				float Weight = GetFloatAt( WeightsOffset + CurrentBlendShapeIndex );
				uint BlendShapeOffsetIndex = GetUintAt( IndicesOffset + CurrentBlendShapeIndex );

				uint VertexDataIndex = BlendShapeOffsetIndex * 3;

				PositionOut += ReadBlendBufferTextureFloat3( CalcLinearBlendBufferIndex( VertexIndex, VertexDataIndex ) ).xyz * Weight;
				++VectorElement;
				if ( VectorElement == 4 )
				{
					VectorElement = 0;
					++VectorIndex;
				}
			}
		}
	]]
}
