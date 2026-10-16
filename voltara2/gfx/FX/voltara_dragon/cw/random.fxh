Code
[[
	float CalcRandom( float Seed )
	{
		float DotProduct = float( Seed ) * 12.9898;
		return frac( sin( DotProduct ) * 43758.5453 );
	}
	
	float CalcRandom( float2 Seed )
	{
		float DotProduct = dot( Seed, float2( 12.9898, 78.233 ) );
		return frac( sin( DotProduct ) * 43758.5453 );
	}
	
	float CalcRandom( float3 Seed )
	{
		float DotProduct = dot( Seed, float3( 12.9898,78.233,144.7272 ) );
		return frac( sin( DotProduct ) * 43758.5453 );
	}
	
	float CalcNoise( float2 Pos ) 
	{
		int2 i = int2( floor( Pos ) );
		float2 f = frac( Pos );

		float a = CalcRandom( i );
		float b = CalcRandom( i + int2( 1, 0 ) );
		float c = CalcRandom( i + int2( 0, 1 ) );
		float d = CalcRandom( i + int2( 1, 1 ) );
		
		float2 u = f*f*(3.0-2.0*f);
		return lerp(a, b, u.x) + 
				(c - a)* u.y * (1.0 - u.x) + 
				(d - b) * u.x * u.y;
	}
]]