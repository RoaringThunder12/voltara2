#####################################################################
# Baked-mesh particle cards. Shared by jomini/portrait.shader and
# court_scene.shader. See "CK3 Model Particle System/README.md".
#
# A skinned quad soup: one bone per card, every vertex weighted 1.0 to its own
# bone. Per bone per frame, from the .anim:
#
#   translation   particle position, entity-local
#   rotation      roll about the card normal
#   scale.x       card width
#   scale.y       card height
#   scale.z       opacity
#
# Rest matrices are identity, so the joint vertex matrix is the pose matrix.
#####################################################################

Includes = {
	"voltara_dragon/cw/pdxmesh_buffers.fxh"
}

Code
[[
	// --- flipbook atlas -------------------------------------------------
	#ifndef PARTICLE_ATLAS_COLUMNS
		#define PARTICLE_ATLAS_COLUMNS 1
	#endif
	#ifndef PARTICLE_ATLAS_ROWS
		#define PARTICLE_ATLAS_ROWS 1
	#endif
	// Fraction of a cell to pull the UVs inward, against filter bleed.
	#ifndef PARTICLE_ATLAS_INSET
		#define PARTICLE_ATLAS_INSET 0.002f
	#endif

	// --- look -----------------------------------------------------------
	#ifndef PARTICLE_TINT
		#define PARTICLE_TINT float3( 1.0f, 1.0f, 1.0f )
	#endif
	#ifndef PARTICLE_OPACITY_MULT
		#define PARTICLE_OPACITY_MULT 1.0f
	#endif
	// Cards only. Use pdxmesh/scale for the whole rig.
	#ifndef PARTICLE_SIZE_MULT
		#define PARTICLE_SIZE_MULT 1.0f
	#endif
	#ifndef PARTICLE_ALPHA_CLIP
		#define PARTICLE_ALPHA_CLIP 0.004f
	#endif

	// Moves the emitter, in the parent bone's space.
	#ifndef PARTICLE_OFFSET
		#define PARTICLE_OFFSET float3( 0.0f, 0.0f, 0.0f )
	#endif

	// Travel that counts as a full life, measured from the emitter. Rig units
	// AFTER pdxmesh/scale, so rescale it whenever that changes. Sets the
	// flipbook playback rate as well as the palette ramp.
	#ifndef PARTICLE_AGE_DISTANCE
		#define PARTICLE_AGE_DISTANCE 6.0f
	#endif

	static const float PARTICLE_ATLAS_CELLS =
		float( PARTICLE_ATLAS_COLUMNS ) * float( PARTICLE_ATLAS_ROWS );

	struct SParticleCard
	{
		float3 _Origin;
		float3 _Right;
		float3 _Up;
		float  _Width;
		float  _Height;
		float  _Roll;      // radians about the card normal
		float  _Opacity;
		float  _Age;       // 0 at birth, 1 at death
	};

	SParticleCard PdxReadParticleCard( uint OffsetJointIndex )
	{
		float4x4 M = PdxMeshGetJointVertexMatrix( OffsetJointIndex );

		// Columns, not rows: a vertex goes through mul( M, v ), so local axis k is
		// COLUMN k. cw/pdxmesh.fxh reads rows, which is safe only for a uniform
		// scale, and this mesh does not carry one.
		float3 AxisX = float3( GetMatrixData( M, 0, 0 ), GetMatrixData( M, 1, 0 ), GetMatrixData( M, 2, 0 ) );
		float3 AxisY = float3( GetMatrixData( M, 0, 1 ), GetMatrixData( M, 1, 1 ), GetMatrixData( M, 2, 1 ) );
		float3 AxisZ = float3( GetMatrixData( M, 0, 2 ), GetMatrixData( M, 1, 2 ), GetMatrixData( M, 2, 2 ) );

		SParticleCard Card;
		Card._Origin  = float3( GetMatrixData( M, 0, 3 ), GetMatrixData( M, 1, 3 ), GetMatrixData( M, 2, 3 ) )
		              + PARTICLE_OFFSET;
		Card._Width   = length( AxisX );
		Card._Height  = length( AxisY );
		Card._Opacity = saturate( length( AxisZ ) );

		// Guard before normalizing: a card can be baked to zero size, and
		// atan2( 0, 0 ) returns a NaN that eats the whole quad.
		float SafeWidth  = max( Card._Width,  1e-6f );
		float SafeHeight = max( Card._Height, 1e-6f );
		float3 UnitX = AxisX / SafeWidth;

		Card._Roll = ( Card._Width > 1e-6f ) ? atan2( UnitX.y, UnitX.x ) : 0.0f;

		// Subtract PARTICLE_OFFSET back out: it moves the emitter, it is not
		// travel, so counting it would report every card as born old.
		Card._Age = saturate( length( Card._Origin - PARTICLE_OFFSET )
		                    * ( 1.0f / PARTICLE_AGE_DISTANCE ) );

		Card._Right = UnitX;
		Card._Up    = AxisY / SafeHeight;

		return Card;
	}

	// The camera axes for a billboard, as world-space vectors.
	//
	// Takes the view matrix rather than naming ViewMatrix: under PORTRAIT_WIDGET
	// that is a macro which rebuilds the camera, and every spelling costs a
	// decal-buffer walk. The caller resolves it once per vertex.
	//
	// From the VIEW MATRIX, never from CameraRightDir / CameraUpDir. In
	// portrait.shader, cw/agot_camera.fxh lays a PdxCamera buffer with RENAMED
	// members over the vanilla one, and its PORTRAIT_WIDGET macros restore the
	// vanilla spelling for only four names - CameraRightDir and CameraUpDir are
	// not among them. An effect that references either never survives to the
	// screen, and error.log says nothing: the mesh is simply absent.
	//
	// Rows, not columns: Create4x4 takes columns, so a view matrix's rows are
	// the camera axes in world space.
	void PdxParticleViewBasis( SParticleCard Card, float4x4 View, out float3 Right, out float3 Up )
	{
		Right = float3( GetMatrixData( View, 0, 0 ), GetMatrixData( View, 0, 1 ), GetMatrixData( View, 0, 2 ) );
		Up    = float3( GetMatrixData( View, 1, 0 ), GetMatrixData( View, 1, 1 ), GetMatrixData( View, 1, 2 ) );

		// A degenerate row means the buffer is not what we think it is - fall
		// back to the authored axes rather than collapse the card.
		if ( dot( Right, Right ) < 0.25f || dot( Up, Up ) < 0.25f )
		{
			Right = Card._Right;
			Up    = Card._Up;
		}
	}

#ifdef PARTICLE_PARENT_SCALE_OPACITY
	// Opacity driven by the scale of the bone this entity hangs off, on the
	// PARENT skeleton - so the dragon's own animation can fade the plume.
	//
	// The drive must be ANISOTROPIC. The parent bone's scale reaches us only
	// inside the world matrix, multiplied by pdxmesh/scale and the dragon's own
	// size, with no rest value to divide by. Measuring the RATIO of two axes
	// cancels every uniform factor, so it reads 1.0 at rest on a hatchling and
	// an adult alike.
	//
	// Needs a dedicated attach bone that nothing is skinned to, or the drive
	// deforms the parent mesh along with the plume.
	#ifndef PARTICLE_PARENT_SCALE_AXIS
		#define PARTICLE_PARENT_SCALE_AXIS float3( 0.0f, 0.0f, 1.0f )
	#endif
	// Must be an axis the drive never touches, or the ratio cancels the signal
	// along with the dragon size.
	#ifndef PARTICLE_PARENT_SCALE_REF_AXIS
		#define PARTICLE_PARENT_SCALE_REF_AXIS float3( 1.0f, 0.0f, 0.0f )
	#endif
	// Ratio window mapped onto 0..1 opacity.
	#ifndef PARTICLE_PARENT_SCALE_MIN
		#define PARTICLE_PARENT_SCALE_MIN 0.0f
	#endif
	#ifndef PARTICLE_PARENT_SCALE_MAX
		#define PARTICLE_PARENT_SCALE_MAX 1.0f
	#endif

	// Probe points rather than read matrix columns: column-over-[3][3] agrees
	// only under one homogeneous convention, and pdxmesh/scale can land in
	// either place.
	float PdxParticleParentScale( float4x4 World, float3 Origin, float3 OriginWS )
	{
		float4 Driven = mul( World, float4( Origin + PARTICLE_PARENT_SCALE_AXIS, 1.0f ) );
		float4 Ref    = mul( World, float4( Origin + PARTICLE_PARENT_SCALE_REF_AXIS, 1.0f ) );

		float DrivenLen = length( Driven.xyz / max( Driven.w, 1e-6f ) - OriginWS );
		float RefLen    = length( Ref.xyz    / max( Ref.w,    1e-6f ) - OriginWS );

		float Ratio = DrivenLen / max( RefLen, 1e-6f );

		return saturate( ( Ratio - PARTICLE_PARENT_SCALE_MIN )
		               / max( PARTICLE_PARENT_SCALE_MAX - PARTICLE_PARENT_SCALE_MIN, 1e-4f ) );
	}
#endif

	float3 PdxParticleCornerOffset( SParticleCard Card, float4x4 View, float2 Corner, out float3 CardNormal )
	{
		float3 BaseRight;
		float3 BaseUp;
		PdxParticleViewBasis( Card, View, BaseRight, BaseUp );

		float SinRoll, CosRoll;
		sincos( Card._Roll, SinRoll, CosRoll );

		float3 Right =  BaseRight * CosRoll + BaseUp * SinRoll;
		float3 Up    = -BaseRight * SinRoll + BaseUp * CosRoll;

		CardNormal = normalize( cross( Right, Up ) );

		return Right * ( Corner.x * Card._Width  * PARTICLE_SIZE_MULT )
		     + Up    * ( Corner.y * Card._Height * PARTICLE_SIZE_MULT );
	}

	// Resolve per VERTEX and interpolate. A cell UV built per pixel gives the
	// hardware a derivative that does not match the cell, and it picks a far too
	// coarse mip.
	float2 PdxParticleAtlasUV( float2 UV, float Cell )
	{
		float Columns = float( PARTICLE_ATLAS_COLUMNS );
		float2 CellSize = float2( 1.0f / Columns, 1.0f / float( PARTICLE_ATLAS_ROWS ) );

		float Column = Cell - Columns * floor( Cell / Columns );
		float Row    = floor( Cell / Columns );

		float2 Base  = float2( Column, Row ) * CellSize;
		float2 Inset = CellSize * PARTICLE_ATLAS_INSET;

		return Base + Inset + saturate( UV ) * ( CellSize - 2.0f * Inset );
	}

	// One shot over the card's life, from cell 0, and NO WRAP: rolling back to
	// cell 0 at the end of a birth-to-death sheet pops.
	//
	// Scale by the CELL COUNT, not by the last index. Scaling by the index gives
	// every cell but the last 1/63 of the life and the last one only the single
	// instant Age == 1, so the sheet's final frame is never actually seen.
	float PdxParticleAgeCell( float Age )
	{
		return min( floor( saturate( Age ) * PARTICLE_ATLAS_CELLS ),
		            PARTICLE_ATLAS_CELLS - 1.0f );
	}

	// Per-card shading rides interpolators the particle path does not otherwise
	// use. Use these macros, not the struct members, so both shader files agree.
	#define PARTICLE_COLOR_BIRTH_OUT( Out )  Out.Tangent
	#define PARTICLE_AGE_OUT( Out )          Out.Normal

	#define PARTICLE_COLOR_BIRTH_IN( In )    ( In.Tangent )
	#define PARTICLE_AGE_IN( In )            ( In.Normal.x )
	#define PARTICLE_STRENGTH_IN( In )       ( In.Normal.y )
	// gene_dragon_fire_color_custom's hue turn. Rides the spare z.
	#define PARTICLE_FIRE_HUE_IN( In )       ( In.Normal.z )

	// Part of a card life over which the palette fades back to the flipbook.
	#ifndef PARTICLE_RAMP_START
		#define PARTICLE_RAMP_START 0.0f
	#endif
	#ifndef PARTICLE_RAMP_END
		#define PARTICLE_RAMP_END 1.0f
	#endif

	// How far to carry the palette's saturation onto the flame.
	#ifndef PARTICLE_PALETTE_SAT
		#define PARTICLE_PALETTE_SAT 0.65f
	#endif

	// Lifts the blend midpoint so it passes through white, not gray.
	#ifndef PARTICLE_PALETTE_MID_LIFT
		#define PARTICLE_PALETTE_MID_LIFT 0.5f
	#endif

	// Below this palette chroma the recolor fades out. Gate on CHROMA, not HSV
	// saturation: saturation is scale invariant, so a black hide of
	// (0.03, 0.03, 0.035) scores 0.14 there and passes, but 0.005 chroma.
	#ifndef PARTICLE_PALETTE_MIN_CHROMA
		#define PARTICLE_PALETTE_MIN_CHROMA 0.04f
	#endif

	// Lifts hide colors to flame brightness.
	#ifndef PARTICLE_PALETTE_BOOST
		#define PARTICLE_PALETTE_BOOST 1.0f
	#endif

	float PdxParticleRampT( float Age )
	{
		return saturate( ( Age - PARTICLE_RAMP_START )
		               / max( PARTICLE_RAMP_END - PARTICLE_RAMP_START, 1e-4f ) );
	}

	// Local, not the engine RGBtoHSV / HSVtoRGB: those are pixel-shader-only in
	// practice and this file compiles into both stages.
	float3 PdxParticleRgbToHsv( float3 C )
	{
		float4 K = float4( 0.0f, -1.0f / 3.0f, 2.0f / 3.0f, -1.0f );
		float4 P = lerp( float4( C.bg, K.wz ), float4( C.gb, K.xy ), step( C.b, C.g ) );
		float4 Q = lerp( float4( P.xyw, C.r ), float4( C.r, P.yzx ), step( P.x, C.r ) );
		float D = Q.x - min( Q.w, Q.y );
		const float E = 1e-10f;
		return float3( abs( Q.z + ( Q.w - Q.y ) / ( 6.0f * D + E ) ), D / ( Q.x + E ), Q.x );
	}

	float3 PdxParticleHsvToRgb( float3 C )
	{
		float4 K = float4( 1.0f, 2.0f / 3.0f, 1.0f / 3.0f, 3.0f );
		float3 P = abs( frac( C.xxx + K.xyz ) * 6.0f - K.www );
		return C.z * lerp( K.xxx, saturate( P - K.xxx ), C.y );
	}

	float PdxParticleMaxRgb( float3 C ) { return max( max( C.r, C.g ), C.b ); }
	float PdxParticleChroma( float3 C ) { return PdxParticleMaxRgb( C ) - min( min( C.r, C.g ), C.b ); }

	// Build the recolored flame ONCE, then blend to it in rgb. Walking the hue
	// part way round the wheel does not work here: hue is an ANGLE whose
	// shortest arc REVERSES at a half turn, so neighboring texels take opposite
	// arcs and arrive at different colors.
	float3 PdxParticleApplyPalette( float3 Diffuse, float3 Target, float Strength )
	{
		float3 D = PdxParticleRgbToHsv( Diffuse );
		float3 T = PdxParticleRgbToHsv( Target );

		// Boost V alone. Scaling rgb clips the brightest channel first, which
		// drags a strong color towards white.
		T.z = saturate( T.z * PARTICLE_PALETTE_BOOST );

		// Measured on the raw rgb, before the boost.
		float Meaningful = saturate( PdxParticleChroma( Target )
		                           / max( PARTICLE_PALETTE_MIN_CHROMA, 1e-4f ) );

		float3 Full = float3( T.x, lerp( D.y, T.y, saturate( PARTICLE_PALETTE_SAT ) ), D.z );
		float3 FullRgb = PdxParticleHsvToRgb( Full );

		float Blend = saturate( Strength ) * Meaningful;
		float3 Result = lerp( Diffuse, FullRgb, Blend );

		// Rescale rather than add, so hue and saturation stay where the blend
		// put them.
		float Mid = 4.0f * Blend * ( 1.0f - Blend );
		float VWant = lerp( PdxParticleMaxRgb( Diffuse ), PdxParticleMaxRgb( FullRgb ), Blend )
		            * ( 1.0f + PARTICLE_PALETTE_MID_LIFT * Mid );
		return Result * ( VWant / max( PdxParticleMaxRgb( Result ), 1e-5f ) );
	}

	#if defined( PARTICLE_DRAGON_PALETTE ) || defined( PARTICLE_DRAGON_DARK_GATE )
	// ====================================================================
	// Dragon palette
	//
	// AGOT stores each dragon color as a PAIR of decals whose weights are the X
	// and Y of a lookup into that decal's own diffuse. Same unpack as
	// AddDragonDecals() in jomini/portrait_decals.fxh, minus the UV gate.
	//
	// Runs in the VERTEX shader: one answer per draw, and this effect is mostly
	// overdraw. The including shader must pull agot_portrait_decals_shared.fxh
	// first - directly or through jomini/portrait_decals.fxh - for the decal
	// buffer and the AGOT_* helpers this block reads.
	// ====================================================================

	// Texel (1,1) at the 16x16 mip marks a palette decal.
	#ifndef PARTICLE_PALETTE_MARKER
		#define PARTICLE_PALETTE_MARKER float3( 0.0f, 0.0f, 0.5f )
	#endif
	#ifndef PARTICLE_PALETTE_TOLERANCE
		#define PARTICLE_PALETTE_TOLERANCE 0.03f
	#endif

	// ---- coverage model -------------------------------------------------
	//   coverage(secondary) = BASE_SECONDARY + sum( weight * part area * cover )
	//   coverage(tertiary)  = sum( weight * part area * cover )   decals only
	//   coverage(primary)   = 1 - secondary - tertiary - opaque
	//   score               = vividness * coverage * bias
	//
	// Markers at mip 6: texel (5,1) body part, texel (9,1) color source. Only
	// _secondary and _tertiary carry a color marker, so _black and _white are
	// identified by EXCLUSION - safe, because every such texel is near gray and
	// no marker is.
	#ifndef PARTICLE_PALETTE_AREA_BODY
		#define PARTICLE_PALETTE_AREA_BODY 0.62f
	#endif
	#ifndef PARTICLE_PALETTE_AREA_WING
		#define PARTICLE_PALETTE_AREA_WING 0.30f
	#endif
	#ifndef PARTICLE_PALETTE_DECAL_COVER
		#define PARTICLE_PALETTE_DECAL_COVER 0.5f
	#endif
	// Secondary also paints wing shading and the neck and spine webs from the
	// mesh color mask, with no decal involved. Tertiary reaches the dragon
	// through decals ONLY.
	#ifndef PARTICLE_PALETTE_BASE_SECONDARY
		#define PARTICLE_PALETTE_BASE_SECONDARY 0.25f
	#endif

	#ifndef PARTICLE_PALETTE_BIAS_PRIMARY
		#define PARTICLE_PALETTE_BIAS_PRIMARY 1.35f
	#endif
	#ifndef PARTICLE_PALETTE_BIAS_SECONDARY
		#define PARTICLE_PALETTE_BIAS_SECONDARY 1.10f
	#endif
	#ifndef PARTICLE_PALETTE_BIAS_TERTIARY
		#define PARTICLE_PALETTE_BIAS_TERTIARY 0.80f
	#endif

	#ifndef PARTICLE_DECAL_PART_BODY
		#define PARTICLE_DECAL_PART_BODY float3( 1.0f, 0.0f, 0.0f )
	#endif
	#ifndef PARTICLE_DECAL_PART_WING
		#define PARTICLE_DECAL_PART_WING float3( 0.0f, 0.0f, 1.0f )
	#endif
	#ifndef PARTICLE_DECAL_SRC_SECONDARY
		#define PARTICLE_DECAL_SRC_SECONDARY float3( 0.0f, 0.0f, 1.0f )
	#endif
	#ifndef PARTICLE_DECAL_SRC_TERTIARY
		#define PARTICLE_DECAL_SRC_TERTIARY float3( 1.0f, 1.0f, 0.0f )
	#endif
	#ifndef PARTICLE_DECAL_SRC_WOUND
		#define PARTICLE_DECAL_SRC_WOUND float3( 1.0f, 0.0f, 0.0f )
	#endif
	#ifndef PARTICLE_DECAL_SRC_SCAR
		#define PARTICLE_DECAL_SRC_SCAR float3( 0.0f, 1.0f, 0.0f )
	#endif

	// Bit mask of pickable slots: 1 primary, 2 secondary, 4 tertiary. 7 is all
	// three hide colors. Eye and horn are never scored - they are small, and
	// scoring lets a striking eye beat the whole hide.
	#ifndef PARTICLE_PALETTE_SELECT_SLOTS
		#define PARTICLE_PALETTE_SELECT_SLOTS 7
	#endif

	#ifndef PARTICLE_PALETTE_STRENGTH
		#define PARTICLE_PALETTE_STRENGTH 1.0f
	#endif

	// Used when the scan finds no palette.
	static const float3 PARTICLE_PALETTE_FALLBACK = float3( 1.0f, 1.0f, 1.0f );

	struct SParticlePalette
	{
		float3 _Primary;
		float3 _Secondary;
		float3 _Tertiary;
		float  _Found;
		float  _CoverPrimary;
		float  _CoverSecondary;
		float  _CoverTertiary;
		// gene_dragon_fire_color. _FireAuto scales the automatic recolor
		// (0 plain orange, 1 full); _FireHue is the custom template's turn of
		// the hue wheel, and forces _FireAuto to 0 when present.
		float  _FireAuto;
		float  _FireHue;
		// gene_dragon_fire_smoke. _custom hands the dark gate to the player:
		// _SmokeCustom flags it, _SmokeOverride is the visibility, 0 hidden
		// to 1 full. The _automatic template is a placeholder that only holds
		// its place in the marker order, and leaves both untouched.
		float  _SmokeCustom;
		float  _SmokeOverride;
	};

	// Chroma decides, brightness breaks the tie. Chroma is zero for white and
	// for black, so neither wins while a real color exists.
	float PdxParticlePaletteScore( float3 C )
	{
		return PdxParticleChroma( C ) * ( 0.25f + 0.75f * PdxParticleMaxRgb( C ) );
	}

	// Most vivid, weighted by how much of the dragon actually WEARS it.
	float3 PdxParticlePaletteBest( SParticlePalette Palette )
	{
		float3 Best = PARTICLE_PALETTE_FALLBACK;
		float BestScore = -1.0f;
		float S;

		if ( ( PARTICLE_PALETTE_SELECT_SLOTS & 1 ) != 0 )
		{
			S = PdxParticlePaletteScore( Palette._Primary )
			  * Palette._CoverPrimary * PARTICLE_PALETTE_BIAS_PRIMARY;
			if ( S > BestScore ) { BestScore = S; Best = Palette._Primary; }
		}
		if ( ( PARTICLE_PALETTE_SELECT_SLOTS & 2 ) != 0 )
		{
			S = PdxParticlePaletteScore( Palette._Secondary )
			  * Palette._CoverSecondary * PARTICLE_PALETTE_BIAS_SECONDARY;
			if ( S > BestScore ) { BestScore = S; Best = Palette._Secondary; }
		}
		if ( ( PARTICLE_PALETTE_SELECT_SLOTS & 4 ) != 0 )
		{
			S = PdxParticlePaletteScore( Palette._Tertiary )
			  * Palette._CoverTertiary * PARTICLE_PALETTE_BIAS_TERTIARY;
			if ( S > BestScore ) { BestScore = S; Best = Palette._Tertiary; }
		}

		// Nothing is both visible and colorful. Fall back to the most visible
		// slot rather than to white.
		if ( BestScore <= 0.0f )
		{
			Best = Palette._Primary;
			if ( Palette._CoverSecondary > Palette._CoverPrimary ) { Best = Palette._Secondary; }
		}
		return Best;
	}

	// AlmostEquals in jomini/portrait_decals.fxh is pixel-shader only.
	bool PdxParticleIsMarker( float3 Sample, float3 Marker )
	{
		return all( abs( Sample - Marker ) <= PARTICLE_PALETTE_TOLERANCE );
	}

	SParticlePalette PdxParticleReadDragonPalette()
	{
		SParticlePalette Palette;
		Palette._Primary   = PARTICLE_PALETTE_FALLBACK;
		Palette._Secondary = PARTICLE_PALETTE_FALLBACK;
		Palette._Tertiary  = PARTICLE_PALETTE_FALLBACK;
		Palette._Found     = 0.0f;
		Palette._CoverPrimary   = 1.0f;
		Palette._CoverSecondary = 0.0f;
		Palette._CoverTertiary  = 0.0f;
		// No gene decal in the buffer = the behaviour from before the gene
		// existed: full automatic recolor, no manual hue, gate on darkness.
		Palette._FireAuto      = 1.0f;
		Palette._FireHue       = 0.0f;
		Palette._SmokeCustom   = 0.0f;
		Palette._SmokeOverride = 0.0f;

		int MarkerLod = int( AGOT_MipLevelToLod( 6.0f ) );
		int ToDataTexel = DecalCount * AGOT_VANILLA_TEXEL_COUNT_PER_DECAL;

		// Entries arrive as ordered PAIRS: odd match is the lookup X, even is the
		// Y and names the texture to sample.
		float2 Pair = float2( 0.0f, 0.0f );
		int Match = 0;

		// Opaque means a black or white decal: hides hide, lends no color.
		float CoverSecondary = 0.0f;
		float CoverTertiary  = 0.0f;
		float CoverOpaque    = 0.0f;

		// Colour saturation genes (walk positions 11-13). 1.0 = untouched, which
		// is also what pre-saturation DNA gets when the decals are absent.
		float SatPrimary   = 1.0f;
		float SatSecondary = 1.0f;
		float SatTertiary  = 1.0f;

		// `i < ToDataTexel`, not `<=`: ToDataTexel is one PAST the last record,
		// so `<=` walks an extra one and reads garbage. The rule is stated at
		// agot_portrait_decals_shared.fxh, above the decal-buffer walks.
		//
		// The walk cannot stop at the twelfth marker either, because the decals
		// the coverage model counts sit further down the buffer.
		AGOT_LOOP
		for ( int i = 0; i < ToDataTexel; i += AGOT_VANILLA_TEXEL_COUNT_PER_DECAL )
		{
			uint DiffuseIndex = PdxReadBuffer( DecalDataBuffer,
			                                   i + AGOT_VANILLA_DIFFUSE_INDEX_DECAL_DATA_OFFSET );
			if ( DiffuseIndex >= AGOT_VANILLA_DATA_MAX_VALUE )
			{
				continue;
			}

			// Unpack16BitUnorm is pixel-shader only, so divide by hand as
			// AGOT_GetReducedDecalData does.
			float Weight = float( PdxReadBuffer( DecalDataBuffer,
			                                     i + AGOT_VANILLA_RAW_WEIGHT_DECAL_DATA_OFFSET ) )
			             / float( AGOT_VANILLA_DATA_MAX_VALUE );

			float3 Marker = AGOT_PdxTex2DArrayLoad( DecalDiffuseArray,
			                                      int3( 1, 1, int( DiffuseIndex ) ),
			                                      MarkerLod ).rgb;
			if ( !PdxParticleIsMarker( Marker, PARTICLE_PALETTE_MARKER ) )
			{
				float3 Part = AGOT_PdxTex2DArrayLoad( DecalDiffuseArray,
				                                    int3( 5, 1, int( DiffuseIndex ) ),
				                                    MarkerLod ).rgb;
				float Area = 0.0f;
				if ( PdxParticleIsMarker( Part, PARTICLE_DECAL_PART_BODY ) )
				{
					Area = PARTICLE_PALETTE_AREA_BODY;
				}
				else if ( PdxParticleIsMarker( Part, PARTICLE_DECAL_PART_WING ) )
				{
					Area = PARTICLE_PALETTE_AREA_WING;
				}

				if ( Area > 0.0f )
				{
					float Cover = Weight * Area * PARTICLE_PALETTE_DECAL_COVER;
					float3 Src = AGOT_PdxTex2DArrayLoad( DecalDiffuseArray,
					                                   int3( 9, 1, int( DiffuseIndex ) ),
					                                   MarkerLod ).rgb;

					if ( PdxParticleIsMarker( Src, PARTICLE_DECAL_SRC_SECONDARY ) )
					{
						CoverSecondary += Cover;
					}
					else if ( PdxParticleIsMarker( Src, PARTICLE_DECAL_SRC_TERTIARY ) )
					{
						CoverTertiary += Cover;
					}
					else if ( PdxParticleIsMarker( Src, PARTICLE_DECAL_SRC_WOUND )
					       || PdxParticleIsMarker( Src, PARTICLE_DECAL_SRC_SCAR ) )
					{
						// Damage. Marks the surface, lends no palette color.
					}
					else
					{
						CoverOpaque += Cover;
					}
				}
				continue;
			}

			Match++;

			// Marker decals past the ten palette pairs are GENE CONTROLS, one
			// per priority slot, identified by position. Their DIFFUSE BLEND
			// MODE is the template id: replace = _automatic, multiply =
			// _custom. Same texture, same marker - the mode is the only
			// difference between a gene's two templates, and on a control
			// decal it never actually blends anything.
			//
			//   11th-15th (priorities 10-14)  the colour saturation genes, in
			//                                 pair order (primary, secondary,
			//                                 tertiary, eye, horn)
			//   16th      (priority 15)       gene_dragon_fire_color
			//   17th      (priority 16)       gene_dragon_fire_smoke
			//
			// A new control gene takes priority 17 and a Match == 18 branch
			// here - inserting one lower shifts everything after it. This walk
			// MUST stay in step with the matchCount switch in
			// portrait_decals.fxh's AddDragonDecals().
			if ( Match > 10 )
			{
				uint Blend = PdxReadBuffer( DecalDataBuffer,
				                            i + AGOT_VANILLA_DIFFUSE_BLEND_DECAL_DATA_OFFSET );
				// Undo the gene's alpha_curve endpoints (0.01 / 0.99) so the
				// slider's full span maps to 0..1.
				float Value = saturate( ( Weight - 0.01f ) / 0.98f );

				if ( Match == 11 )
				{
					SatPrimary = Value;
				}
				else if ( Match == 12 )
				{
					SatSecondary = Value;
				}
				else if ( Match == 13 )
				{
					SatTertiary = Value;
				}
				else if ( Match == 14 || Match == 15 )
				{
					// Eye and horn saturation: the flame borrows neither
					// colour; the slots only hold the order.
				}
				else if ( Match == 16 )
				{
					if ( Blend == AGOT_DECAL_BLEND_MULTIPLY )
					{
						// _custom: the player picked a hue; the automatic
						// recolor bows out entirely.
						Palette._FireAuto = 0.0f;
						Palette._FireHue  = Value;
					}
					else
					{
						// _automatic: plain orange at 0, the full automatic
						// recolor at 1.
						Palette._FireAuto = Value;
					}
				}
				else if ( Match == 17 )
				{
					if ( Blend == AGOT_DECAL_BLEND_MULTIPLY )
					{
						// _custom: the player's own valve on the smoke.
						Palette._SmokeCustom   = 1.0f;
						Palette._SmokeOverride = Value;
					}
					// _automatic: deliberately nothing. It exists so the
					// marker order stays fixed for whatever comes after.
				}
				continue;
			}

			if ( ( Match & 1 ) == 1 )
			{
				Pair.x = Weight;
				continue;
			}

			Pair.y = Weight;

			// Explicit LOD 0: a vertex shader has no derivatives to pick a mip
			// from. Vanilla does the same at portrait_decals.fxh:679.
			float3 Color = PdxTex2DLod0( DecalDiffuseArray,
			                             float3( Pair, float( DiffuseIndex ) ) ).rgb;

			int Slot = ( Match / 2 ) - 1;
			if      ( Slot == 0 ) { Palette._Primary   = Color; }
			else if ( Slot == 1 ) { Palette._Secondary = Color; }
			else if ( Slot == 2 ) { Palette._Tertiary  = Color; }
			Palette._Found = 1.0f;
		}

		// The saturation genes scale the palette colours the flame borrows -
		// same gamma-space HSV scale as the body decode in AddDragonDecals(),
		// so a desaturated dragon breathes matching fire.
		Palette._Primary   = AGOT_ScaleSaturation( Palette._Primary,   SatPrimary );
		Palette._Secondary = AGOT_ScaleSaturation( Palette._Secondary, SatSecondary );
		Palette._Tertiary  = AGOT_ScaleSaturation( Palette._Tertiary,  SatTertiary );

		Palette._CoverSecondary = saturate( PARTICLE_PALETTE_BASE_SECONDARY + CoverSecondary );
		Palette._CoverTertiary  = saturate( CoverTertiary );
		Palette._CoverPrimary = saturate( 1.0f - Palette._CoverSecondary
		                                       - Palette._CoverTertiary - CoverOpaque );
		return Palette;
	}

	// Resolved once per vertex.
	void PdxParticlePaletteColors( out float3 Birth, out float Strength, out float FireHue )
	{
		SParticlePalette Palette = PdxParticleReadDragonPalette();

		// Raw. PARTICLE_PALETTE_BOOST is applied by PdxParticleApplyPalette,
		// which knows the color space.
		Birth = saturate( PdxParticlePaletteBest( Palette ) );

		// No palette found renders as the plain effect. The fire-colour gene
		// then scales what remains: _automatic dials the recolor between
		// plain orange and full, _custom zeroes it and hands over the hue.
		Strength = Palette._Found * PARTICLE_PALETTE_STRENGTH * Palette._FireAuto;
		FireHue  = Palette._FireHue;
	}

	#ifdef PARTICLE_DRAGON_DARK_GATE
	// ---- darkness gate --------------------------------------------------
	//
	// How much of this layer to show, decided by how BLACK the dragon is. Soot
	// reads as smoke on a black dragon and as dirt on a red one.
	//
	// THE THRESHOLDS ARE DARKNESS, NOT BRIGHTNESS. _FULL 0.8 means a hide whose
	// value sits at 0.2 or below.
	#ifndef PARTICLE_DARK_FULL
		#define PARTICLE_DARK_FULL 0.8f
	#endif
	#ifndef PARTICLE_DARK_NONE
		#define PARTICLE_DARK_NONE 0.6f
	#endif
	// At or below this gate the card is collapsed to a point in the vertex
	// shader instead of being drawn transparent.
	#ifndef PARTICLE_DARK_CULL
		#define PARTICLE_DARK_CULL 0.0f
	#endif

	// Coverage-weighted mean VALUE of the three hide colors, inverted. Weighting
	// by coverage is what makes it mean "mostly black" rather than "has a black
	// slot somewhere": a black tertiary that no decal applies scores zero
	// coverage and cannot darken the answer.
	float PdxParticleDragonDarkness( SParticlePalette Palette )
	{
		float CoverP = Palette._CoverPrimary;
		float CoverS = Palette._CoverSecondary;
		float CoverT = Palette._CoverTertiary;
		float Total  = max( CoverP + CoverS + CoverT, 1e-4f );

		// Raw hide values. NOT boosted: PARTICLE_PALETTE_BOOST exists to lift a
		// black hide up to flame brightness, which is the exact signal being
		// measured here. Applying it would report every dragon as pale.
		float Value = ( PdxParticleMaxRgb( Palette._Primary )   * CoverP
		              + PdxParticleMaxRgb( Palette._Secondary ) * CoverS
		              + PdxParticleMaxRgb( Palette._Tertiary )  * CoverT ) / Total;

		// No palette found is not a black dragon, it is not a dragon at all.
		return Palette._Found * saturate( 1.0f - Value );
	}

	// 0 hides the layer entirely, 1 shows it in full.
	float PdxParticleDarkGate()
	{
		SParticlePalette Palette = PdxParticleReadDragonPalette();

		// gene_dragon_fire_smoke_custom: the player's own valve, replacing
		// the darkness reading outright - any dragon can smoke, or none.
		if ( Palette._SmokeCustom > 0.5f )
		{
			return Palette._SmokeOverride;
		}

		return saturate( ( PdxParticleDragonDarkness( Palette ) - PARTICLE_DARK_NONE )
		               / max( PARTICLE_DARK_FULL - PARTICLE_DARK_NONE, 1e-4f ) );
	}
	#endif // PARTICLE_DRAGON_DARK_GATE
	#endif // PARTICLE_DRAGON_PALETTE || PARTICLE_DRAGON_DARK_GATE

	// A flat camera-facing quad lit by its own normal shades dead flat. Bending
	// the normal outward across the card fakes a rounded puff. 0 is the true
	// card normal, 1 a full dome.
	#ifndef PARTICLE_NORMAL_BULGE
		#define PARTICLE_NORMAL_BULGE 1.0f
	#endif

	// How strongly the lit puff's base normal is pulled toward world up before
	// the bulge is applied. Portrait key lights sit high, so this keeps a plume
	// aimed away from the key from going uniformly black.
	#ifndef PARTICLE_NORMAL_UP
		#define PARTICLE_NORMAL_UP 0.75f
	#endif

	float3 PdxParticlePuffNormal( float3 CardNormal, float3 PlaneOffset )
	{
		// PlaneOffset lies in the card plane, so its direction is "outward from
		// the card centre" and is perpendicular to CardNormal. The sum can
		// therefore never be zero, whatever the bulge.
		float Extent = length( PlaneOffset );
		float3 Outward = ( Extent > 1e-6f ) ? ( PlaneOffset / Extent )
		                                    : float3( 0.0f, 0.0f, 0.0f );
		return normalize( CardNormal + Outward * PARTICLE_NORMAL_BULGE );
	}
]]

# PARTICLE_LIT only. The portrait light rig is declared in
# agot_portrait_constants.fxh, which only jomini/portrait.shader includes, and
# CalcLightFalloff is pixel-stage. court_scene.shader includes this file too and
# never defines PARTICLE_LIT, so the guard is what keeps it building.
PixelShader =
{
	Code
	[[
	#ifdef PARTICLE_LIT
		// How far light bleeds past the terminator. 0 is hard lambert, which on
		// a puff reads as a solid ball; smoke scatters, so it wants a soft wrap.
		#ifndef PARTICLE_LIGHT_WRAP
			#define PARTICLE_LIGHT_WRAP 0.5f
		#endif

		// Wrapped lambert against the three portrait lights, plus diffuse IBL
		// for ambient. Deliberately NOT CommonPixelShaderColor: that costs a
		// shadow-map sample, a second cubemap fetch at a roughness-varying mip
		// and a GGX evaluation per light, PER FRAGMENT - across 64 alpha-blended
		// cards that all overlap. A fully rough puff uses almost none of it.
		float3 PdxParticleLighting( float3 Albedo, float3 Normal, float3 WorldSpacePos,
		                            PdxTextureSamplerCube EnvironmentMap )
		{
			// Diffuse IBL: one fetch at a fixed mip near the top of the chain,
			// so no derivative and no mip select. CubemapIntensity and
			// CubemapYRotation are scene constants - GetSunLightingProperties
			// would only add the shadow sample this is avoiding.
			float3 CubemapUV = mul( CastTo3x3( CubemapYRotation ), Normal );
			float3 Light = PdxTexCubeLod( EnvironmentMap, CubemapUV,
			                              ( PDX_NumMips - 1 - PDX_MipOffset ) ).rgb
			             * CubemapIntensity;

			for ( int i = 0; i < LIGHT_COUNT; ++i )
			{
				float4 DirType = Light_Direction_Type[ i ];
				float4 ColorFalloff = Light_Color_Falloff[ i ];

				// Directional needs no position; the other two share the falloff
				// and differ only by the cone. LIGHT_TYPE_NONE falls through all
				// three and contributes nothing, as in CalculatePortraitLights.
				float3 ToLight = -DirType.xyz;
				float Intensity = 0.0f;

				if ( DirType.w == LIGHT_TYPE_DIRECTIONAL )
				{
					Intensity = 1.0f;
				}
				else if ( DirType.w == LIGHT_TYPE_POINTLIGHT
				       || DirType.w == LIGHT_TYPE_SPOTLIGHT )
				{
					float4 PosRadius = Light_Position_Radius[ i ];
					float3 PosToLight = PosRadius.xyz - WorldSpacePos;
					float Distance = length( PosToLight );

					ToLight = PosToLight / max( Distance, 1e-6f );
					// The same falloff the full path uses, so the lights' reach
					// does not move.
					Intensity = CalcLightFalloff( PosRadius.w, Distance, ColorFalloff.w );

					if ( DirType.w == LIGHT_TYPE_SPOTLIGHT )
					{
						float4 Cone = Light_InnerCone_OuterCone_AffectedByShadows[ i ];
						Intensity *= smoothstep( Cone.y, Cone.x, dot( -ToLight, DirType.xyz ) );
					}
				}

				float NdotL = dot( Normal, ToLight );
				float Wrapped = saturate( ( NdotL + PARTICLE_LIGHT_WRAP )
				                        / ( 1.0f + PARTICLE_LIGHT_WRAP ) );

				Light += ColorFalloff.rgb * Intensity * Wrapped;
			}

			return Albedo * Light;
		}
	#endif
	]]
}
