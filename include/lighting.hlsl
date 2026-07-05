float specular(float3 light_dir, float4 normal) {
	return pow(saturate(dot(light_dir, normal.xyz)), lerp(10, 210, (normal.w * normal.w)));
}