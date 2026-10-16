PixelShader =
{
	Code
	[[
		// Implements https://medium.com/@bgolus/anti-aliased-alpha-test-the-esoteric-alpha-to-coverage-8b177335ae4f

		float CalcMipLevel(float2 texture_coord)
		{
			float2 dx = ddx(texture_coord);
			float2 dy = ddy(texture_coord);
			float delta_max_sqr = max(dot(dx, dx), dot(dy, dy));
			return max(0.0, 0.5 * log2(delta_max_sqr));
		}

		float RescaleAlphaByMipLevel( float Alpha, float2 UV, PdxTextureSampler2D Sampler )
		{
			// 0.25 approximates the loss of density from mip mapping
			const float MIP_SCALE = 0.25f;
			float2 TextureSize;
			PdxTex2DSize( Sampler, TextureSize );
			float2 Scaled_UV = UV * TextureSize;
			return Alpha * ( 1.0f + ( CalcMipLevel( Scaled_UV ) * MIP_SCALE ) );
		}

		// This `Cutoff` value (between [0.0, 1.0]) can be tweaked to change the "thickness"
		// of the edges where the transparency is, lower value -> thicker edge
		float SharpenAlpha( float Alpha, float Cutoff )
		{
			float Result = ( ( Alpha - Cutoff ) / max( fwidth( Alpha ), 0.0001f ) ) + 0.5f;
			return saturate( Result );
		}
	]]
}
