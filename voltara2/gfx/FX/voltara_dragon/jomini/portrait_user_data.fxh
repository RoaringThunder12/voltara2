Code
[[
	// The C++ layout is SVariationRenderConstants followed by CDecalEntityData::SMeshData followed by SColorMaskRemapInterval
	//	struct SVariationRenderConstants
	//	{
	//		struct STransform
	//		{
	//			float		_Scale = 1.0f;
	//			float		_Rotation = 0.0f;
	//			CVector2f	_Offset = CVector2f::Zero();
	//		};
	//		STransform	_Transforms[4];
	//		CVector4f	_ColorMaskIndices;
	//		CVector4f	_NormalMapIndices;
	//		CVector4f	_PropertyIndices;
	//		float		_RandomNumber;
	//		float		_ColorOverrideOffset; // -1 = no override; 0/4/8/12 = block start
	//	};
	//	struct SColorMaskRemapInterval
	//	{
	//		CVector2f _Interval = CVector2f{ 0.0f, 1.0f };
	//	};
	//	struct SMeshData
	//	{
	//		float _BodyPartIndex = 0.0f;
	//	};

	// Also, note thata the Data[] array is of type float4.

	struct SPatternDesc
	{
		float 	_Scale;
		float	_Rotation;
		float2	_Offset;
		float	_InnerExp;
		float	_InnerScale;
		float	_RimExp;
		float	_RimScale;
		float	_ColorMaskIndex;
		float	_NormalMapIndex;
		float	_PropertyMapIndex;
		bool	_UseColorOverrides;
		bool	_UseOpacity;
	};

	struct SCoatOfArmsTileData
	{
		float2 _CoaStaggeredOffset;
		float _CoaPatternTile;
		float _CoaPatternScale;
		float _CoaShapeMaskChannel;
	};

	SPatternDesc GetPatternDesc( uint InstanceIndex, uint PatternIndex )
	{
		SPatternDesc Desc;
		uint Offset = InstanceIndex + PDXMESH_USER_DATA_OFFSET;
		Desc._Scale = Data[Offset + PatternIndex].r;
		Desc._Rotation = Data[Offset + PatternIndex].g;
		Desc._Offset = Data[Offset + PatternIndex].ba;
		Desc._InnerExp = Data[Offset + 8 + PatternIndex].r;
		Desc._InnerScale = Data[Offset + 8 + PatternIndex].g;
		Desc._RimExp = Data[Offset + 8 + PatternIndex].b;
		Desc._RimScale = Data[Offset + 8 + PatternIndex].a;

		Desc._ColorMaskIndex = Data[Offset + 16][PatternIndex];
		Desc._NormalMapIndex = Data[Offset + 18][PatternIndex];
		Desc._PropertyMapIndex = Data[Offset + 20][PatternIndex];
		Desc._UseOpacity = Data[Offset + 22][PatternIndex] > 0.0f;
		int ColorOverrideOffset = int( Data[Offset + 24].g );
		Desc._UseColorOverrides = ColorOverrideOffset > 0;

		return Desc;
	}

	SPatternDesc GetSecondPatternDesc( uint InstanceIndex, uint PatternIndex )
	{
		SPatternDesc Desc;
		uint Offset = InstanceIndex + PDXMESH_USER_DATA_OFFSET;
		Desc._Scale = Data[Offset + 4 + PatternIndex].r;
		Desc._Rotation = Data[Offset + 4 + PatternIndex].g;
		Desc._Offset = Data[Offset + 4 + PatternIndex].ba;
		Desc._InnerExp = Data[Offset + 12 + PatternIndex].r;
		Desc._InnerScale = Data[Offset + 12 + PatternIndex].g;
		Desc._RimExp = Data[Offset + 12 + PatternIndex].b;
		Desc._RimScale = Data[Offset + 12 + PatternIndex].a;

		Desc._ColorMaskIndex = Data[Offset + 17][PatternIndex];
		Desc._NormalMapIndex = Data[Offset + 19][PatternIndex];
		Desc._PropertyMapIndex = Data[Offset + 21][PatternIndex];
		Desc._UseOpacity = Data[Offset + 23][PatternIndex] > 0.0f;
		int ColorOverrideOffset = int( Data[Offset + 24].g );
		Desc._UseColorOverrides = ColorOverrideOffset > 0;

		return Desc;
	}

	float GetRandomNumber( uint InstanceIndex )
	{
		uint Offset = InstanceIndex + PDXMESH_USER_DATA_OFFSET + 24;
		return Data[Offset].r;
	}

	int GetColorOverrideOffset( uint InstanceIndex )
	{
		uint Offset = InstanceIndex + PDXMESH_USER_DATA_OFFSET + 24;
		int ColorIndex = int( Data[Offset].g );
		return ColorIndex > 0 ? (ColorIndex - 1) * 4 : -1;
	}

	float2 GetColorMaskRemapInterval( uint InstanceIndex )
	{
		uint Offset = InstanceIndex + PDXMESH_USER_DATA_OFFSET + 24;
		return Data[Offset].ba;
	}

	uint GetBodyPartIndex( uint InstanceIndex )
	{
		uint Offset = InstanceIndex + PDXMESH_USER_DATA_OFFSET + 25;
		return uint( Data[Offset].r );
	}

	SCoatOfArmsTileData GetCoatOfArmsTileData( uint InstanceIndex )
	{
		uint Offset = InstanceIndex + PDXMESH_USER_DATA_OFFSET + 25;
		SCoatOfArmsTileData CoatOfArmsTileData;
		CoatOfArmsTileData._CoaStaggeredOffset = Data[Offset].gb;
		CoatOfArmsTileData._CoaPatternTile = Data[Offset].a;
		CoatOfArmsTileData._CoaPatternScale = Data[Offset + 1].r;
		CoatOfArmsTileData._CoaShapeMaskChannel = Data[Offset + 1].g;

		return CoatOfArmsTileData;
	}
]]
