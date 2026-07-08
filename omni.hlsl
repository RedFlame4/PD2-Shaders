#include "include/common.hlsl"
#include "include/lighting.hlsl"

Texture2D normal;
Texture2D depth;
TextureCube ref_light_texture;
Texture2D albedo;

SamplerState normal_sampler;
SamplerState depth_sampler;
SamplerState ref_light_texture_sampler;
SamplerState albedo_sampler;

cbuffer Globals : register(b0)
{
	float4x4 camera_world_matrix[2]      : packoffset(c36);
	float    ref_light_falloff           : packoffset(c44.y);
	float    ref_light_falloff_exponent  : packoffset(c44.z);
	float3   ref_light_color             : packoffset(c45);
	float3   ref_light_position          : packoffset(c46);
}

struct PS_IN
{
	// Unused, but must stay first: the engine links VS->PS interpolants by
	// raw register slot, not semantic name, so this keeps every field below
	// at the same v-register the real shader expects.
	float4 pos : SV_Position;
	float4 texcoord : TEXCOORD;
	float4 texcoord1 : TEXCOORD1;
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
	float light_len = length(light_dir);
	float falloff_amount = saturate(1 - light_len * ref_light_falloff);

	light_dir /= light_len;// + 0.0001f;

	float light_amount = saturate(dot(light_dir, normal_s.xyz) * falloff_amount);

	clip(light_amount - 1E-05); // unlit

	#if defined(PROJECTION)
		float projection_depth = ref_light_texture.SampleLevel(ref_light_texture_sampler, light_dir, 0).w; // Mipmaps can cause aliasing on edges of objects

		light_amount *= saturate(min(falloff_amount - (projection_depth - 0.08), 0.06) / 0.06);

		clip(light_amount - 1E-05); // unlit
	#endif

	#if defined(PRERELEASE)
		float3 lighting = (albedo_s * albedo_s) * light_amount;
	#else
		float3 lighting = albedo_s * light_amount;
	#endif

	#if defined(SPECULAR) || defined(PROJECTION) // vanilla oddity, projection lights always have specular
		float3 look_vector = normalize(camera_world_matrix[i.eye]._m30_m31_m32 - world_pos);
		float3 half_vector = normalize(light_dir + look_vector);
		float3 specular_color = specular(half_vector, normal_s);

		#if defined(PRERELEASE)
			specular_color *= ref_light_falloff_exponent;
		#else
			specular_color *= (1 + saturate(ref_light_falloff_exponent - 1) * 0.33);
		#endif

		#if defined(SPECULAR) && defined(PROJECTION)
			float4 sample_pos;
			sample_pos.xyz = reflect(look_vector, normal_s.xyz);
			sample_pos.w = (1.0 - normal_s.w) * 4.0;

			specular_color += ref_light_texture.SampleLevel(ref_light_texture_sampler, sample_pos.xyz, sample_pos.w).xyz;
		#endif

		#if defined(PRERELEASE)
			lighting += specular_color * (pow(normal_s.w, 2) * light_amount);
		#else
			lighting += specular_color * dot(pow(normal_s.ww, 2), light_amount.xx);
		#endif
	#endif

	lighting *= ref_light_color;

	return lighting.xyzz;
}
