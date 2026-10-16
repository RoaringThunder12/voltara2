Includes = {
	"voltara_dragon/agot_utils.fxh"
}

Code [[
	// ============================================================================
	// MARKER VOCABULARY for "MIP smuggling"
	// ============================================================================
	//
	// The idea in one paragraph: the game gives shaders no way to pass custom
	// per-character data, but it DOES tell the shader which decals a character
	// wears and how strong each one is (its "weight", a 0-1 slider driven by
	// genes/script). So we paint a secret colour code into a tiny mip level of a
	// decal's texture - invisible in normal play - and when a shader spots that
	// code, it uses the decal's weight as a smuggled value to drive some effect
	// (hair aging, camera zoom, clothing decay, dragon colours, ...).
	//
	// This file only defines the COLOUR CODES and how to compare colours.
	// The code that actually searches a character's decals lives in
	// agot_portrait_decals_shared.fxh. See SHADERS.md for the full picture.
	//
	// There are two code layouts, both painted into mip level 6 (the 16x16
	// version of a 1024px decal texture):
	//
	//   1. CORNER MARKERS - the four corner pixels. Top-left picks an effect
	//      family, top-right picks a variant within it. Used for camera zoom,
	//      statue materials, the map terrain marker, etc.
	//
	//   2. CENTRE MASKS - solid 4x4 colour blocks at fixed spots inside the
	//      image (blocks of 4 because DDS compression works in 4x4 cells).
	//      Used for hair aging, clothing decay, facepaint, dragons, etc.
	// ============================================================================

	// Which mip level carries the codes (mip 6 = 16x16 for a 1024px texture).
	static const int AGOT_MARKER_MIP_LEVEL = 6;

	// How close a sampled colour must be to the reference colour to count as a
	// match, per channel. Texture compression shifts colours slightly, so an
	// exact compare would fail; this is the allowed slack.
	static const float AGOT_MARKER_CHECK_TOLERANCE = 0.02f;

	// True if two colours match within the tolerance (checked per channel).
	bool AGOT_ColorAlmostEquals(float3 Sample, float3 Reference)
	{
		return Sample.r >= (Reference.r - AGOT_MARKER_CHECK_TOLERANCE) &&
			Sample.r <= (Reference.r + AGOT_MARKER_CHECK_TOLERANCE) &&
			Sample.g >= (Reference.g - AGOT_MARKER_CHECK_TOLERANCE) &&
			Sample.g <= (Reference.g + AGOT_MARKER_CHECK_TOLERANCE) &&
			Sample.b >= (Reference.b - AGOT_MARKER_CHECK_TOLERANCE) &&
			Sample.b <= (Reference.b + AGOT_MARKER_CHECK_TOLERANCE);
	}

	bool AGOT_ColorAlmostEquals(float4 Sample, float4 Reference)
	{
		return AGOT_ColorAlmostEquals(Sample.rgb, Reference.rgb) &&
			Sample.a >= (Reference.a - AGOT_MARKER_CHECK_TOLERANCE) &&
			Sample.a <= (Reference.a + AGOT_MARKER_CHECK_TOLERANCE);
	}

	//
	// 1. CORNER MARKERS
	//
	// Top-left corner = effect family:

	static const float4 AGOT_MARKER_TOP_LEFT_FLAT            		= float4(1.0f, 0.0f, 0.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_LEFT_STATUE          		= float4(0.0f, 1.0f, 0.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_LEFT_STATUE_TEXTURED 		= float4(1.0f, 1.0f, 0.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_LEFT_MAP_TERRAIN     		= float4(0.0f, 0.0f, 1.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_LEFT_FULLSCREEN      		= float4(0.0f, 1.0f, 1.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_LEFT_DECAL          		= float4(1.0f, 0.0f, 1.0f, 0.0f);

	// Top-right corner = variant within the family:

	static const float4 AGOT_MARKER_TOP_RIGHT_FLAT_SHADE_BLACK   	= float4(1.0f, 0.0f, 0.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_RIGHT_FLAT_SHADE_VINDEON 	= float4(0.0f, 1.0f, 0.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_RIGHT_FLAT_SHADE_RED     	= float4(1.0f, 1.0f, 0.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_RIGHT_FLAT_SHADE_TRIPPY  	= float4(0.0f, 0.0f, 1.0f, 0.0f);

	static const float4 AGOT_MARKER_TOP_RIGHT_STATUE_GOLD        	= float4(1.0f, 0.0f, 0.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_RIGHT_STATUE_MARBLE      	= float4(0.0f, 1.0f, 0.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_RIGHT_STATUE_LIMESTONE   	= float4(1.0f, 1.0f, 0.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_RIGHT_STATUE_STONE       	= float4(0.0f, 0.0f, 1.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_RIGHT_STATUE_COPPER      	= float4(1.0f, 0.0f, 1.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_RIGHT_STATUE_COPPER_RUST 	= float4(0.0f, 1.0f, 1.0f, 0.0f);

	static const float4 AGOT_MARKER_TOP_RIGHT_FULLSCREEN_OVERLAY 	= float4(1.0f, 0.0f, 0.0f, 0.0f);

	static const float4 AGOT_MARKER_TOP_RIGHT_DECAL_PULSE 		= float4(1.0f, 0.0f, 0.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_RIGHT_DECAL_CAMERA_ZOOM 	= float4(0.0f, 1.0f, 0.0f, 0.0f);
	static const float4 AGOT_MARKER_TOP_RIGHT_DECAL_CAMERA_RAISE 	= float4(0.0f, 0.0f, 1.0f, 0.0f);

	// The four corner texels of a decal's mip-6 image, as read in one go by
	// AGOT_ExtractMarkerTexels() (agot_portrait_decals_shared.fxh).
	struct AGOT_SMarkerTexels
	{
		float4 TopLeftTexel;
		float4 TopRightTexel;
		// Always black - AGOT_ExtractMarkerTexels no longer loads them. Restore
		// the loads there if a marker ever needs a bottom corner.
		float4 BottomRightTexel;
		float4 BottomLeftTexel;
	};

	// Does this set of corner texels carry the given family + variant?
	bool AGOT_CheckMarkerTexels(AGOT_SMarkerTexels MarkerTexels, float4 TopLeftTexelReference, float4 TopRightTexelReference)
	{
		return AGOT_ColorAlmostEquals(MarkerTexels.TopLeftTexel,  TopLeftTexelReference)
			&& AGOT_ColorAlmostEquals(MarkerTexels.TopRightTexel, TopRightTexelReference);
	}

	//
	// 2. CENTRE MASKS
	//
	// The reference colours a decal can be tagged with:

	static const float3 AGOT_MASK_RED       = float3(1.0f, 0.0f, 0.0f);
	static const float3 AGOT_MASK_GREEN     = float3(0.0f, 1.0f, 0.0f);
	static const float3 AGOT_MASK_BLUE      = float3(0.0f, 0.0f, 1.0f);
	static const float3 AGOT_MASK_CYAN      = float3(0.0f, 1.0f, 1.0f);
	static const float3 AGOT_MASK_MAGENTA   = float3(1.0f, 0.0f, 1.0f);
	static const float3 AGOT_MASK_YELLOW    = float3(1.0f, 1.0f, 0.0f);
	static const float3 AGOT_MASK_HALF_RED  = float3(0.5f, 0.0f, 0.0f);
	static const float3 AGOT_MASK_HALF_BLUE = float3(0.0f, 0.0f, 0.5f);

	// Where each 4x4 block sits in the 16x16 mip-6 image (the coordinate is the
	// block's sampling point - see the diagram in jomini/portrait_decals.fxh):
	static const int2 AGOT_MASK_TEXEL_CONTROL   = int2(1, 1);   // what kind of decal this is / which effect it drives
	static const int2 AGOT_MASK_TEXEL_BODYPART  = int2(5, 1);   // restrict the decal to a custom body part (eyes, dragon...)
	static const int2 AGOT_MASK_TEXEL_SPLIT     = int2(9, 1);   // split/role: colour-channel split; dragon roles: RED wound, GREEN scar, MAGENTA scale-shadows AO, CYAN scale-highlights
	static const int2 AGOT_MASK_TEXEL_COLOR_OVR = int2(13, 1);  // recolour the decal (skin/hair/eye palette, painted palette...)
	static const int2 AGOT_MASK_TEXEL_BLENDMODE = int2(1, 5);   // pick a custom blend mode (screen, additive...)
	static const int2 AGOT_MASK_TEXEL_DRAGON_TINT = int2(5, 5); // RETIRED: dragon tint now comes from the gene's diffuse blend mode, not this texel
	static const int2 AGOT_MASK_TEXEL_PALETTE   = int2(1, 13);  // row holding a painted colour palette to sample from

	// Which of the three decal texture arrays a mask lookup samples:
	#define DIFFUSE_DECAL uint(0)
	#define NORMAL_DECAL uint(1)
	#define PROPERTIES_DECAL uint(2)

	// Body-part ids used by the decode / dragon code:
	#define BODYPART_EYES         1
	#define BODYPART_DRAGON       2
]]
