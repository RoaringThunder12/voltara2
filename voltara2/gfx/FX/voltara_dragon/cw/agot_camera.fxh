Includes = {
	"voltara_dragon/cw/pdxmesh_buffers.fxh"
	"voltara_dragon/agot_portrait_decals_shared.fxh"
	"voltara_dragon/agot_markers.fxh"
}

# ============================================================================
# PORTRAIT CAMERA ZOOM, driven by MIP-smuggled decals
# ============================================================================
#
# The game gives us no way to move the portrait camera from script. Instead:
# script applies invisible "camera zoom" / "camera raise" decals to the
# character, and this file makes the portrait VERTEX SHADER read their weights
# (via AGOT_GetCameraZoomFromMarkerDecals) and move the camera itself.
#
# How the takeover works: below is a copy of the vanilla camera constants under
# RENAMED names (Camera_Position instead of CameraPosition, etc.). Then, only
# when PORTRAIT_WIDGET is defined, the vanilla names are redefined as macros
# that call our _Mod() functions - so all existing vanilla code silently gets
# the moved camera without being edited.
#
# KEEP THE MEMBER LIST IN SYNC with vanilla cw/camera.fxh on CK3 patches.
ConstantBuffer( PdxCamera )
{
	float4x4	View_Projection_Matrix;
	float4x4	Inv_View_Projection_Matrix;
	float4x4	View_Matrix;
	float4x4	Inv_View_Matrix;
	float4x4	Projection_Matrix;
	float4x4	Inv_Projection_Matrix;

	float4x4 	Shadow_Map_Texture_Matrix;
	
	float3		Camera_Position;
	float		Z_Near;
	float3		Camera_Look_At_Dir;
	float		Z_Far;
	float3		Camera_Up_Dir;
	float 		Camera_FoV;
	float3		Camera_Right_Dir;
	float 		_Upscale_Lod_Bias;
	float 		_Upscale_Lod_Bias_Native;
	float 		_Upscale_Lod_Bias_Multiplier;
	float 		_Upscale_Lod_Bias_Multiplier_Native;
	float 		_Upscale_Lod_Bias_Enabled;
}


Code
[[
	// Macros that replace references to vanilla camera constants with functions for modifying them
	#ifdef PORTRAIT_WIDGET
		#define CameraPosition 				Camera_Position_Mod()
		#define ViewMatrix 					View_Matrix_Mod()
		#define	ViewProjectionMatrix 		View_Projection_Matrix_Mod()
		#define ShadowMapTextureMatrix 		Shadow_Map_Texture_Matrix
	#endif

	static const float  MAX_ZOOM_DISTANCE	= 	7500.0f; // The maximum distance you'd like to move the camera back for max zoom.
	static const float  MAX_RAISE_HEIGHT	= 	1500.0f; // The maximum distance you'd like to move the camera back for max zoom.

	// Takes the decal reading rather than doing its own: the walk is expensive
	// and the callers below need the same answer more than once.
	float3 Camera_Position_From( float2 ZoomHeight )
	{
		float ZoomFactor = lerp(0.0f, MAX_ZOOM_DISTANCE, ZoomHeight.x);
		float AddCameraHeight = lerp(0.0f, MAX_RAISE_HEIGHT, ZoomHeight.y);
		// Compute the new camera position
		float3 NewCameraPos = Camera_Position - Camera_Look_At_Dir * ZoomFactor;

		//Raise Camera
		NewCameraPos.y += AddCameraHeight;

		return NewCameraPos;
	}

	float3 Camera_Position_Mod()
	{
		return Camera_Position_From( AGOT_GetCameraZoomFromMarkerDecals() );
	}

	// The pixel shader's camera. Same answer as Camera_Position_Mod(), resolved
	// once per invocation rather than once per spelling - the pixel stage names
	// CameraPosition 13 times and each one is a decal-buffer walk. It must be
	// this value and NOT the raw unzoomed constant; see the README.
	//
	// static is a mutable per-invocation global in both backends: HLSL has it,
	// and cw/defines_glsl4.fxh defines it away leaving a plain GLSL global.
	static bool   AGOT_CameraPosResolved = false;
	static float3 AGOT_CameraPosCache;

	float3 Camera_Position_Pixel()
	{
		if ( !AGOT_CameraPosResolved )
		{
			AGOT_CameraPosCache = Camera_Position_From( AGOT_GetCameraZoomFromMarkerDecals() );
			AGOT_CameraPosResolved = true;
		}

		return AGOT_CameraPosCache;
	}

	// Generate new View Matrix using new camera
	float4x4 View_Matrix_From( float3 NewCameraPos )
	{
		float3 zaxis = Camera_Look_At_Dir;    // The "forward" vector.
		float3 xaxis = Camera_Right_Dir;     // The "right" vector.
		float3 yaxis = Camera_Up_Dir;        // The "up" vector.

		float4 newViewMatrix0 = float4(xaxis.x, yaxis.x, zaxis.x, 0);
		float4 newViewMatrix1 = float4(xaxis.y, yaxis.y, zaxis.y, 0);
		float4 newViewMatrix2 = float4(xaxis.z, yaxis.z, zaxis.z, 0);
		float4 newViewMatrix3 = float4(-dot(xaxis, NewCameraPos), -dot(yaxis, NewCameraPos), -dot(zaxis, NewCameraPos), 1);

		return float4x4 (Create4x4( newViewMatrix0, newViewMatrix1, newViewMatrix2, newViewMatrix3 ));
	}

	float4x4 View_Matrix_Mod()
	{
		return View_Matrix_From( Camera_Position_Mod() );
	}

	// Push the far plane back with the camera, or the zoom clips the subject away
	// instead of shrinking it. Only ROW 2 depends on near and far, so the image
	// is untouched. Far only - moving near too would hold depth precision but
	// clips whatever is closest. Standard D3D depth, not reverse-Z:
	//   Row 2 = ( 0, 0, Zf / (Zf - Zn), -Zn * Zf / (Zf - Zn) )
	float4x4 Projection_Matrix_From( float2 ZoomHeight )
	{
		float4x4 NewProjection = Projection_Matrix;

		float ZoomFactor = lerp(0.0f, MAX_ZOOM_DISTANCE, ZoomHeight.x);
		float ZNear = Z_Near;
		float ZFar  = Z_Far + ZoomFactor;
		float Range = max( ZFar - ZNear, 1e-4f );

		GetMatrixData( NewProjection, 2, 2 ) = ZFar / Range;
		GetMatrixData( NewProjection, 2, 3 ) = -ZNear * ZFar / Range;

		return NewProjection;
	}

	// Create new ViewProjectionMatrix using new ViewMatrix
	float4x4 View_Projection_Matrix_Mod()
	{
		float2 ZoomHeight = AGOT_GetCameraZoomFromMarkerDecals();

		return float4x4 (mul( Projection_Matrix_From( ZoomHeight ),
		                      View_Matrix_From( Camera_Position_From( ZoomHeight ) ) ));
	}
]]

# An OVERRIDE, not a stage-only definition: the macros above must stay in the
# global block, because jomini_fog.fxh and cw/camera.fxh spell CameraPosition at
# global scope where a stage block cannot reach them. ViewMatrix and
# ViewProjectionMatrix are never named in the pixel stage, so they are left alone.
PixelShader =
{
	Code
	[[
	#ifdef PORTRAIT_WIDGET
		#undef CameraPosition
		#define CameraPosition 				Camera_Position_Pixel()
	#endif
	]]
}
