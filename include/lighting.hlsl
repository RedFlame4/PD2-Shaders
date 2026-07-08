float specular(float3 light_dir, float4 normal) {
	float specular_amount;
	#if defined(PRERELEASE)
		specular_amount = lerp(10, 90, normal.w);
	#else
		specular_amount = lerp(10, 210, (normal.w * normal.w));
	#endif

	return pow(saturate(dot(light_dir, normal.xyz)), specular_amount);
}