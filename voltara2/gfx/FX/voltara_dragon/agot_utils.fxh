Includes = {
	"voltara_dragon/agot_constants.fxh"
}

Code [[
	//
	// Macros
	//

	#ifndef PDX_OPENGL
		#define AGOT_LOOP [loop]
		#define AGOT_UNROLL [unroll]
		#define AGOT_UNROLL_EXACT(ITERATIONS_COUNT) [unroll(ITERATIONS_COUNT)]
	#else
		#define AGOT_LOOP
		#define AGOT_UNROLL
		#define AGOT_UNROLL_EXACT(ITERATIONS_COUNT)
	#endif

	#ifndef PDX_OPENGL
		#define AGOT_PdxTex2DArrayLoad(samp,uvi,lod) (samp)._Texture.Load( int4((uvi), (lod)) )
	#else
		#define AGOT_PdxTex2DArrayLoad texelFetch
	#endif

	//
	// Interface
	//

	int AGOT_DecodeIntFromRgba(float4 Rgba)
	{
		static const float THRESHOLD = 0.5f;

		// Decode Rgba into an integer between 0 and 15 inclusive
		return (int(step(THRESHOLD, Rgba.r)) << 0)
				| (int(step(THRESHOLD, Rgba.g)) << 1)
				| (int(step(THRESHOLD, Rgba.b)) << 2)
				| (int(step(THRESHOLD, Rgba.a)) << 3);
	}

	int AGOT_DecodeIntFromRgb(float3 Rgb)
	{
		// Decode Rgb into an integer between 0 and 7 inclusive
		return AGOT_DecodeIntFromRgba(float4(Rgb, 0.0f));
	}

	uint AGOT_DecodeFullMaskFromDecalRawWeight(uint DecalRawWeight)
	{
		static const uint DECAL_RAW_WEIGHT_MAX = AGOT_VANILLA_DATA_MAX_VALUE;

		return (DecalRawWeight * AGOT_MAX_FULL_MARKER_MASK) / DECAL_RAW_WEIGHT_MAX;
	}

	uint AGOT_DecodeDataMaskFromDecalRawWeight(uint DecalRawWeight)
	{
		// Only most significant AGOT_DATA_BITS_PER_MARKER from the full mask contain actual data.
		static const int NON_DATA_BITS_COUNT = AGOT_TOTAL_BITS_PER_MARKER - AGOT_DATA_BITS_PER_MARKER;

		uint FullMask = AGOT_DecodeFullMaskFromDecalRawWeight(DecalRawWeight);

		return FullMask >> NON_DATA_BITS_COUNT;
	}

	float3 AGOT_ToWorldSpace(float3 LocalSpacePos, float4x4 WorldMatrix)
	{
		float3 WorldSpacePos = mul(WorldMatrix, float4(LocalSpacePos, 1.0)).xyz;
		WorldSpacePos /= WorldMatrix[3][3];

		return WorldSpacePos;
	}
]]
