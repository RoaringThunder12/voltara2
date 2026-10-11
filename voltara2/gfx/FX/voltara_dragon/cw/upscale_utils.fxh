Includes = {
	"voltara_dragon/cw/camera.fxh"
}

Code
[[
	// These macros can be used as drop in replacements for their counterparts without the "Upscale" postfix.
	// They will take care of using the correct lod bias when sampling the textures to account for rendering happening in lower resolution. (See https://gsg.pages.build.paradox-interactive.com/tech/cw/develop/clausewitz/pdx_gfx/upscaling/ for more information)
	// Note that by default when using upscaling it will add an extra -1 lod bias, this is to try and boost the quality a bit, it works because the temporal anti aliasing component can take care of some of the aliasing artifacts that is introduced by the lod bias.
	// This might not always be preferrable, in those cases the "UpscaleBias" postfix versions can be used to undo the extra lod bias, the provided bias should most likely be in the range (0.0, 1.0), for example doing PdxTex2DUpscaleBias( Tex, Uv, 1.0 ) will net you the same texture quality you would get rendering in native resolution.
	// There is also a "UpscaleNative" that is basically the same as UpscaleBias with bias 1.0, but slightly more optimized.
	
	#ifdef PDX_UPSCALING_ENABLED
		float2 ApplyUpscaleLodBiasMultiplier( float2 Derivative ) { return Derivative * _UpscaleLodBiasMultiplier; }
		float2 ApplyUpscaleNativeLodBiasMultiplier( float2 Derivative ) { return Derivative * _UpscaleLodBiasMultiplierNative; }
		
		#define PdxTex2DUpscale( TextureSampler, Uv ) PdxTex2DBias( (TextureSampler), (Uv), _UpscaleLodBias )
		#define PdxTex2DUpscaleNative( TextureSampler, Uv ) PdxTex2DBias( (TextureSampler), (Uv), _UpscaleLodBiasNative )
		#define PdxTex2DUpscaleBias( TextureSampler, Uv, Bias ) PdxTex2DBias( (TextureSampler), (Uv), (_UpscaleLodBias + (Bias) * _UpscaleLodBiasEnabled) )
		
		#define PdxTex2DGradUpscale( TextureSampler, Uv, Ddx, Ddy ) PdxTex2DGrad( (TextureSampler), (Uv), ApplyUpscaleLodBiasMultiplier( Ddx ), ApplyUpscaleLodBiasMultiplier( Ddy ) )
		#define PdxTex2DGradUpscaleNative( TextureSampler, Uv, Ddx, Ddy ) PdxTex2DGrad( (TextureSampler), (Uv), ApplyUpscaleNativeLodBiasMultiplier( Ddx ), ApplyUpscaleNativeLodBiasMultiplier( Ddy ) )
		#define PdxTex2DGradUpscaleBias( TextureSampler, Uv, Ddx, Ddy, Bias ) PdxTex2DGrad( (TextureSampler), (Uv), ApplyUpscaleLodBiasMultiplier( Ddx ) * exp2( (Bias) * _UpscaleLodBiasEnabled ), ApplyUpscaleLodBiasMultiplier( Ddy ) * exp2( (Bias) * _UpscaleLodBiasEnabled ) )
	#else
		float2 ApplyUpscaleLodBiasMultiplier( float2 Derivative ) { return Derivative; }
		float2 ApplyUpscaleNativeLodBiasMultiplier( float2 Derivative ) { return Derivative; }
		
		#define PdxTex2DUpscale( TextureSampler, Uv ) PdxTex2D( (TextureSampler), (Uv) )
		#define PdxTex2DUpscaleNative( TextureSampler, Uv ) PdxTex2D( (TextureSampler), (Uv) )
		// We intentionally discard the Bias argument here since that is used to tweak the upscale added lodbias
		#define PdxTex2DUpscaleBias( TextureSampler, Uv, Bias ) PdxTex2D( (TextureSampler), (Uv) )
		
		#define PdxTex2DGradUpscale( TextureSampler, Uv, Ddx, Ddy ) PdxTex2DGrad( (TextureSampler), (Uv), Ddx, Ddy )
		#define PdxTex2DGradUpscaleNative( TextureSampler, Uv, Ddx, Ddy ) PdxTex2DGrad( (TextureSampler), (Uv), Ddx, Ddy )
		// We intentionally discard the Bias argument here since that is used to tweak the upscale added lodbias
		#define PdxTex2DGradUpscaleBias( TextureSampler, Uv, Ddx, Ddy, Bias ) PdxTex2DGrad( (TextureSampler), (Uv), Ddx, Ddy )
	#endif
]]
