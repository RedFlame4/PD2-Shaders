#include "include/common.hlsl"
#include "include/lighting.hlsl"

Texture2D albedo;
Texture2D diffuse_texture;
Texture2D depth;
Texture2D temp;
Texture2D self_illumination_texture;
Texture2D filter_color_texture;
TextureCube reflection_texture;

SamplerState albedo_sampler;
SamplerState diffuse_texture_sampler;
SamplerState depth_sampler;
SamplerState temp_sampler;
SamplerState self_illumination_texture_sampler;
SamplerState filter_color_texture_sampler;
SamplerState reflection_texture_sampler;

cbuffer Globals : register(b0)
{
	float4x4 camera_world_matrix[2]     : packoffset(c23);
	float3   ref_dome_occ_pos           : packoffset(c42);
	float3   ref_dome_occ_size          : packoffset(c43);
	float    ref_ambient_scale          : packoffset(c43.w);
	float    ref_ambient_falloff_scale  : packoffset(c44.x);
	float3   ref_ambient_color          : packoffset(c44.y);
	float3   ref_sky_top_color          : packoffset(c45);
	float3   ref_sky_bottom_color       : packoffset(c46);
	float3   global_light_dir           : packoffset(c48);
	float3   global_light_col           : packoffset(c49);
	float3   ref_fog_start_color        : packoffset(c52);
	float3   ref_fog_far_low_color      : packoffset(c53);
	float    ref_fog_min_range          : packoffset(c56.x);
	float    ref_fog_max_range          : packoffset(c56.y);
	float    ref_fog_max_density        : packoffset(c56.z);
	float    ref_use_ssao               : packoffset(c57.y);
	float    ref_bloom_threshold        : packoffset(c57.z);
}

struct PS_IN
{
	// Unused, but must stay first: the engine links VS->PS interpolants by
	// raw register slot, not semantic name, so this keeps every field below
	// at the same v-register the real shader expects (v0 is implicitly
	// consumed by the rasterizer for SV_Position regardless).
	float4 pos : SV_Position;
	float2 texcoord : TEXCOORD;
	float3 texcoord1 : TEXCOORD1;
	nointerpolation uint eye : TEXCOORD15;
};

float4 main(PS_IN i) : SV_Target
{
	float4 o;

	float depth_s = depth.Sample(depth_sampler, i.texcoord).x;
	float4 light_s = temp.Sample(temp_sampler, i.texcoord);
	float4 albedo_s = albedo.Sample(albedo_sampler, i.texcoord);
	float4 normal_s = decode_signed_normal(diffuse_texture.Sample(diffuse_texture_sampler, i.texcoord));
	light_s.xyz *= 2;

	// Dome occlusion
	float3 world_pos = decode_world_pos(i.texcoord1, depth_s, camera_world_matrix[i.eye]);

	float3 dome_occ_pos = world_pos - ref_dome_occ_pos; // Local-space relative to dome occlusion origin

	float3 dome_sample_pos = dome_occ_pos / ref_dome_occ_size; // Local-space -> Texture-space

	float2 dome_occ_s = filter_color_texture.Sample(filter_color_texture_sampler, dome_sample_pos.xy).xy;

	float dome_occ_amount = (dome_occ_s.x + dome_occ_s.y) / 2;
	dome_occ_amount = 1 - (dome_occ_amount * dome_occ_amount);

	// Apply dome occlusion based on depth
	dome_occ_amount = 1 - saturate(dome_occ_amount - dome_sample_pos.z);
	dome_occ_amount = saturate((dome_occ_amount - ref_ambient_scale) / (1 - ref_ambient_scale));

	// AMBIENT LIGHTING
	float3 ambient_colour = ref_ambient_color;

	// Sky top colour
	float sky_top_amount = (normal_s.z + 1) * 0.5;
	ambient_colour += (ref_sky_top_color * sky_top_amount) * dome_occ_amount;

	// Sky bottom colour
	float sky_bottom_amount = 1 - sky_top_amount;
	ambient_colour += (ref_sky_bottom_color * sky_bottom_amount) * (dome_occ_amount * dome_occ_amount);

	// SSAO
	if (ref_use_ssao) {
		ambient_colour *= self_illumination_texture.Sample(self_illumination_texture_sampler, i.texcoord).x;
	}

	// GLOBAL LIGHTING
	float global_lighting_amount = saturate(dot(-global_light_dir, normal_s.xyz) * light_s.w);

	float3 global_lighting_colour = light_s.xyz;
	float3 sun_colour = ((global_light_col * global_lighting_amount) + ambient_colour);

	// Specular
	float3 look_vector = normalize(camera_world_matrix[i.eye]._m30_m31_m32 - world_pos);

	#if defined(HQ)
		global_lighting_colour += albedo_s.xyz * sun_colour;

		float specular_amount = specular(normalize(-global_light_dir + look_vector), normal_s);

		global_lighting_colour += (global_light_col * (pow(normal_s.w, 2) * (global_lighting_amount * 4))) * specular_amount;

		// AMBIENT FALLOFF SCALE
		float4 reflection_sample_pos;
		reflection_sample_pos.xyz = reflect(look_vector, normal_s.xyz);
		reflection_sample_pos.w = (1 - pow(normal_s.w, 2)) * 4;

		float3 reflection_colour = reflection_texture.SampleLevel(reflection_texture_sampler, reflection_sample_pos.xyz, reflection_sample_pos.w).xyz;

		global_lighting_colour += reflection_colour * (((normal_s.w * ref_ambient_falloff_scale) * saturate(normal_s.z)) * dome_occ_amount);
	#else
		// TODO: output of omni/spot shaders shouldn't be multiplied with albedo for this to work right
		global_lighting_colour += sun_colour;
		global_lighting_colour = (global_lighting_colour * albedo_s.xyz) + global_lighting_colour * pow(saturate(dot(normal_s.xyz, look_vector)), 0.2 + (200 * normal_s.w)) * normal_s.w;
	#endif

	// BLOOM
	float3 bloom_amount = global_lighting_colour * 11.2;

	global_lighting_colour = (
		((bloom_amount * ((1.68 * global_lighting_colour) + 0.05)) + 0.004) / // ogl shaders do this differently but get the same result, neat
		((bloom_amount * ((1.68 * global_lighting_colour) + 0.5)) + 0.06)
	) - 0.06666666;

	// FOG
	float fog_amount = 1 - clamp((depth_s - ref_fog_min_range) / ref_fog_max_range, 0, ref_fog_max_density);
	fog_amount = pow(fog_amount, 3);

	o.xyz = lerp(lerp(ref_fog_far_low_color, ref_fog_start_color, fog_amount), global_lighting_colour, fog_amount);
	o.w = pow(saturate(dot(global_lighting_colour, 0.37) - ref_bloom_threshold) / ((1.0 - ref_bloom_threshold) + 0.0001), 3) * fog_amount;

	return o;
}
