/*inline half3 normalize_half(float3 full) {
	return normalize(half3(full));
}*/

inline float3 decode_world_pos(float3 p, float depth, float4x4 camera_world) {
	return camera_world._m30_m31_m32 + p * depth;
}

inline float3 decode_world_pos(float4 p, float depth, float4x4 camera_world) {
	return camera_world._m30_m31_m32 + (p.xyz /  p.w) * depth;
}

inline float4 decode_signed_normal(float4 normal) {
	normal.xyz = (normal.xyz * 2) - 1;
	
	return normal;
}