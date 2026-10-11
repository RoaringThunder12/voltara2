PixelShader =
{
	Code
	[[
		float3x3 BuildTangentFrame( float3 WorldNormal, float3 Position, float2 UV )
		{
			// Get edge vectors of the pixel triangle
			float3 PositionGradientX  = ddx( Position );
			float3 PositionGradientY = ddy( Position );
			float2 UVGradientX = ddx( UV );
			float2 UVGradientY = ddy( UV );

			// Avoid very small UV derivatives
			if ( length( UVGradientX ) < 1e-5 || length( UVGradientY ) < 1e-5 )
			{
				// Fallback: use orthogonal coordinate system (assume +X and +Y as Tangent and Bitangent)
				float3 Tangent = normalize( cross( float3( 0.0f, 1.0f, 0.0f ), WorldNormal ) );
				if ( length( Tangent ) < 1e-5 ) 
				{
					Tangent = float3( 1.0f, 0.0f, 0.0f );
				}
				float3 Bitangent = normalize( cross( WorldNormal, Tangent ) );
				return float3x3( Tangent, Bitangent, WorldNormal );
			}

			// Solve the linear system
			float3 TangentBasisY = cross( PositionGradientY, WorldNormal );
			float3 TangentBasisX = cross( WorldNormal, PositionGradientX );
			float3 Tangent = TangentBasisY * UVGradientX.x + TangentBasisX * UVGradientY.x;
			float3 Bitangent = TangentBasisY * UVGradientX.y + TangentBasisX * UVGradientY.y;

			float InvMax = rsqrt( max( dot( Tangent, Tangent ), dot( Bitangent, Bitangent ) ) );
			return float3x3( Tangent * InvMax, Bitangent * InvMax, WorldNormal );
		}
	]]
}