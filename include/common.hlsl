/*inline half3 normalize_half(float3 full) {
	return normalize(half3(full));
}*/

inline float3 decode_world_pos(float3 p, float depth, float4x4 camera_world) {
	return camera_world._m30_m31_m32 + p * depth;
}

inline float3 decode_world_pos(float4 p, float depth, float4x4 camera_world) {
	return camera_world._m30_m31_m32 + (p.xyz /  p.w) * depth;
}

// Written as (v-0.5)+(v-0.5) rather than v*2-1: same value, but matches the
// compiled instruction pattern exactly (two adds, not a mad).
inline float4 decode_signed_normal(float4 normal) {
	float3 shifted = normal.xyz - 0.5;
	normal.xyz = shifted + shifted;

	return normal;
}

inline float3 decode_signed_normal(float3 normal) {
	float3 shifted = normal - 0.5;
	return shifted + shifted;
}

inline float2 decode_signed_normal(float2 normal) {
	float2 shifted = normal - 0.5;
	return shifted + shifted;
}

inline float3 encode_signed_normal(float3 normal) {
	return (normal * 0.5) + 0.5;
}

inline float3 decode_normalmap_alt_channel(float4 bump_sample) {
	// Normal maps usually pack (x,y) in (g,r); some instead pack an alternate
	// encoding in (g,a), flagged by r == 1. Written to match the compiled form
	// exactly: convert the flag to 1.0/0.0 first, then a plain arithmetic
	// blend - a per-vector ternary (movc) compiles to different instructions
	// even though the value is identical.
	float alt_encoding = (bump_sample.r == 1) ? 1 : 0;
	float2 diff = bump_sample.ag - bump_sample.gr;
	float2 xy = decode_signed_normal(alt_encoding * diff + bump_sample.gr);

	float3 n;
	n.xy = xy;
	// z reconstruction as compiled: sqrt(1 + x*x - y*y), not the usual sqrt(1 - x*x - y*y).
	// Written as the original's 3 separate steps (mul, then mad, then add) rather than
	// algebraically fused - same value, but matches the compiled instructions exactly.
	float x2 = xy.x * xy.x;
	float y2_minus_x2 = xy.y * xy.y - x2;
	n.z = sqrt(1 - y2_minus_x2);
	return n;
}

inline float channel_sum(float3 c) {
	return c.x + c.y + c.z;
}

inline float channel_max(float3 c) {
	return max(max(c.x, c.y), c.z);
}