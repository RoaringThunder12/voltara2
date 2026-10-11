# NOTE: The following sampler and buffer definitions are originally from PixelShader section of vanilla jomini/portrait_decals.fxh .
#       They were moved here to be shared between pixel and vertex shader code across multiple files.
#       Must be kept in sync with vanilla as future game patches come out.

TextureSampler DecalDiffuseArray
{
	Ref = JominiPortraitDecalDiffuseArray
	MagFilter = "Linear"
	MinFilter = "Linear"
	MipFilter = "Linear"
	SampleModeU = "Wrap"
	SampleModeV = "Wrap"
	type = "2darray"
}

TextureSampler DecalNormalArray
{
	Ref = JominiPortraitDecalNormalArray
	MagFilter = "Linear"
	MinFilter = "Linear"
	MipFilter = "Linear"
	SampleModeU = "Wrap"
	SampleModeV = "Wrap"
	type = "2darray"
}

TextureSampler DecalPropertiesArray
{
	Ref = JominiPortraitDecalPropertiesArray
	MagFilter = "Linear"
	MinFilter = "Linear"
	MipFilter = "Linear"
	SampleModeU = "Wrap"
	SampleModeV = "Wrap"
	type = "2darray"
}

BufferTexture DecalDataBuffer
{
	Ref = JominiPortraitDecalData
	type = uint
}

# END NOTE

Code
[[
	// This is a vanilla definition originally from jomini/portrait_decals.fxh, extracted here at
	// file scope so vertex shaders (camera zoom, dynamic terrain markers) can read the decal
	// buffer too. Merge any vanilla patch changes to this definition here.

	struct DecalData
	{
		uint _DiffuseIndex;
		uint _NormalIndex;
		uint _PropertiesIndex;
		uint _BodyPartIndex;

		uint _DiffuseBlendMode;
		uint _NormalBlendMode;
		uint _PropertiesBlendMode;
		float _Weight;

		uint2 _AtlasPos;
		float2 _UVOffset;
		uint2 _UVTiling;

		uint _AtlasSize;
	};
]]
