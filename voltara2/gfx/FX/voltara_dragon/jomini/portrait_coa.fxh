Includes = {
	"voltara_dragon/jomini/texture_decals_base.fxh"
	"voltara_dragon/jomini/portrait_user_data.fxh"
}

PixelShader =
{
	TextureSampler CoaPatternMask
	{
		Ref = PdxMeshCustomTexture5
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler CoaPatternShapeMask
	{
		Index = 8
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		File = "gfx/FX/jomini/coa_pattern_shape_mask.dds"
	}

	Code
	[[
		#ifdef COA_ENABLED
			void ApplyCoa( in VS_OUTPUT_PDXMESHPORTRAIT Input, inout float4 Diffuse, float4 Color1, float4 Color2, float4 Color3, float2 Offset, float2 Scale, PdxTextureSampler2D CoaTexture, float PatternAO ) 
			{
				// If effect only uses CoA without variation, then CoA pattern mask
				// ends up in another texture slot - first available custom texture
				#ifdef VARIATIONS_ENABLED
					float4 Mask = PdxTex2D( CoaPatternMask, Input.UV0 );
				#else
					float4 Mask = PdxTex2D( PatternMask, Input.UV0 );
				#endif

				// Check for coa first

				if ( Mask.r > 0.5f )
				{
					float3 Color = Color1.rgb * PatternAO;
					Diffuse.rgb = lerp( Diffuse.rgb, Color, Mask.r );
				} 
				if ( Mask.g > 0.5f ) 
				{
					float3 Color = Color2.rgb * PatternAO;
					Diffuse.rgb = lerp( Diffuse.rgb, Color, Mask.g );

				}
				if ( Mask.a > 0.5f )
				{
					float3 Color = Color3.rgb * PatternAO;
					Diffuse.rgb = lerp( Diffuse.rgb, Color, Mask.a );
				}
				if ( Mask.b > 0.5f ) 
				{
					SCoatOfArmsTileData CoatOfArmsTileData = GetCoatOfArmsTileData( Input.InstanceIndex );

					// If the tile and scale values haven't changed, skip the additional calculations.
					if( CoatOfArmsTileData._CoaPatternTile == 1.0f && CoatOfArmsTileData._CoaPatternScale == 1.0f )
					{
						float2 UV = Offset + Input.UV2 * Scale;
						float4 Coa = PdxTex2D( CoaTexture, UV );
						Diffuse.rgb = lerp( Diffuse.rgb, Coa.rgb * PatternAO, Mask.b );
						return;
					}
					// Using the color of the top-left pixel as the background color.
					float2 BackgroundUV = Offset + vec2( 0.005f );
					float3 BackgroundColor = PdxTex2D( CoaTexture, BackgroundUV ).rgb;
					const float Threshold = 0.38f;
					const float Softness = 0.03;
					float2 TileCount = float2( CoatOfArmsTileData._CoaPatternTile, CoatOfArmsTileData._CoaPatternTile );
					float2 NewUV = Input.UV2 * TileCount;
					float2 TileIndex = floor( NewUV );

					// Offset for rows/columns
					if ( mod( TileIndex.y, 2.0f ) == 0.0f )
					{
						NewUV.x += CoatOfArmsTileData._CoaStaggeredOffset.x;
					}
					if ( mod( TileIndex.x, 2.0f ) == 0.0f )
					{
						NewUV.y += CoatOfArmsTileData._CoaStaggeredOffset.y;
					}

					TileIndex = floor( NewUV );

					// Scale parameter (e.g., 0.8 means scale down to 80%)
					float TileScale = 1.0f / CoatOfArmsTileData._CoaPatternScale;

					// Calculate tile center point
					float2 TiledUV = frac( NewUV );
					float2 Center = float2( 0.5f, 0.5f );

					// Scale UV coordinates for each tile (with tile center as scaling center)
					TiledUV = ( TiledUV - Center ) * TileScale + Center;

					// Prevent over-sampling at boundaries
					const float SkipMin = 0.01f;
					const float SkipMax = 0.99f;

					// Prevent over-sampling at boundaries
					if ( TiledUV.x > SkipMin && TiledUV.x < SkipMax && TiledUV.y > SkipMin && TiledUV.y < SkipMax )
					{
						// Apply Offset and Scale
						float2 UV = Offset + TiledUV * Scale;
						float4 Coa = PdxTex2D( CoaTexture, UV );
						float3 Difference = Coa.rgb - BackgroundColor;
						float Dist = length( Difference );
						float Alpha = smoothstep( Threshold - Softness, Threshold + Softness, Dist );
						float ShapeMask = PdxTex2D( CoaPatternShapeMask, TiledUV )[ (int)CoatOfArmsTileData._CoaShapeMaskChannel ];
						Diffuse.rgb = lerp( Diffuse.rgb, vec3( 1.0f ) * PatternAO, Mask.b * ShapeMask * Alpha );
					}
				} 
			}
			

		#endif
	]]
}
