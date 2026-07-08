#include "include/common.hlsl"
#include "include/lighting.hlsl"

Texture2D normal;
Texture2D depth;
Texture2D albedo;
Texture2D ref_light_texture;

SamplerState normal_sampler;
SamplerState depth_sampler;
SamplerState albedo_sampler;
SamplerState ref_light_texture_sampler;

cbuffer Globals : register(b0)
{
#if defined(INVSQ)
	float    ref_spot_angle_falloff_end  : packoffset(c16.x);
	float    ref_spot_projection_scale   : packoffset(c16.y);
	float3   ref_light_color             : packoffset(c17);
	float3   ref_light_position          : packoffset(c19);
	float3   ref_light_direction         : packoffset(c20);
	float    ref_light_falloff           : packoffset(c23.x);
	float    ref_light_falloff_exponent  : packoffset(c23.y);
	float    ref_light_start             : packoffset(c23.z);
	float4x4 ref_light_matrix            : packoffset(c24);
	float4x4 camera_world_matrix[2]      : packoffset(c48);
#else
	float    ref_spot_angle_falloff      : packoffset(c15.w);
	float    ref_spot_projection_scale   : packoffset(c16.x);
	float3   ref_light_color             : packoffset(c16.y);
	float3   ref_light_position          : packoffset(c18);
	float3   ref_light_direction         : packoffset(c19);
	float    ref_light_falloff           : packoffset(c22.x);
	float    ref_light_falloff_exponent  : packoffset(c22.y);
	float    ref_light_start             : packoffset(c22.z);
	float4x4 ref_light_matrix            : packoffset(c23);
	float4x4 camera_world_matrix[2]      : packoffset(c47);
#endif
}

struct PS_IN
{
	// Unused, but must stay first: the engine links VS->PS interpolants by
	// raw register slot, not semantic name, so this keeps every field below
	// at the same v-register the real shader expects.
	float4 pos : SV_Position;
	float4 texcoord : TEXCOORD;
	float4 texcoord1 : TEXCOORD1;
	float2 texcoord2 : TEXCOORD2;
	nointerpolation uint eye : TEXCOORD15;
};

float4 main(PS_IN i) : SV_Target
{
	float2 screen_uv = i.texcoord.xy / i.texcoord.ww;
	float depth_s = depth.Sample(depth_sampler, screen_uv).x;
	float3 albedo_s = albedo.Sample(albedo_sampler, screen_uv).xyz;
	float4 normal_s = decode_signed_normal(normal.Sample(normal_sampler, screen_uv));

	float3 world_pos = decode_world_pos(i.texcoord1, depth_s, camera_world_matrix[i.eye]);

	float3 light_dir = ref_light_position - world_pos;

#if defined(INVSQ)
	float light_len_sq = dot(light_dir, light_dir);
	float range_falloff = max(1 - pow(light_len_sq * ref_light_falloff * ref_light_falloff, 2), 0);
	float falloff_amount = pow(range_falloff, 2) / (light_len_sq + 1) * 30000;

	light_dir *= rsqrt(light_len_sq);
#else
	float light_len = length(light_dir);
	float falloff_amount = sqrt(saturate(1 - light_len * ref_light_falloff));

	light_dir /= light_len;// + 0.0001f;
#endif

	float range_step = sign(dot(world_pos, ref_light_direction) - i.texcoord2.x - ref_light_start);

	float light_amount = range_step * falloff_amount;

	float spot_angle = 1 - dot(-light_dir, ref_light_direction);

#if defined(INVSQ)
	float angle_falloff = saturate((spot_angle - ref_spot_angle_falloff_end) * i.texcoord2.y);
	light_amount *= pow(angle_falloff, 2);
#else
	light_amount *= saturate(1 - (spot_angle / ref_spot_angle_falloff));
#endif

	light_amount *= saturate(dot(light_dir, normal_s.xyz));

	clip(light_amount - 1E-05); // unlit

#if defined(PRERELEASE)
	float3 lighting = (albedo_s * albedo_s) * light_amount;
#else
	float3 lighting = albedo_s * light_amount;
#endif

	#if defined(SPECULAR)
		float3 look_vector = normalize(camera_world_matrix[i.eye]._m30_m31_m32 - world_pos);
		float3 half_vector = normalize(light_dir + look_vector);
		float specular_color = specular(half_vector, normal_s);

		#if defined(PRERELEASE)
			specular_color *= ref_light_falloff_exponent;
		#else
			specular_color *= (1 + saturate(ref_light_falloff_exponent - 1) * 0.33);
		#endif

		#if defined(PRERELEASE)
			specular_color *= pow(normal_s.w, 2) * light_amount;
		#else
			specular_color *= dot(pow(normal_s.ww, 2), light_amount.xx);
		#endif

		lighting += specular_color.xxx;
	#endif

	#if defined(PROJECTION)
		float2 light_uv = (mul(light_dir, (float3x3)ref_light_matrix).xy * ref_spot_projection_scale) * 0.5 + 0.5;
		#if defined(PRERELEASE)
			lighting *= ref_light_texture.Sample(ref_light_texture_sampler, light_uv).xyz;
		#else
			lighting *= ref_light_texture.Sample(ref_light_texture_sampler, light_uv).xyz * 2;
		#endif
	#endif

	lighting *= ref_light_color;

	return lighting.xyzz;
}
