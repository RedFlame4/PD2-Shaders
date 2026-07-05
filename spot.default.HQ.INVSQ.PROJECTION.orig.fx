Texture2D albedo;
Texture2D depth;
Texture2D normal;
Texture2D ref_light_texture;

SamplerState albedo_sampler;
SamplerState depth_sampler;
SamplerState normal_sampler;
SamplerState ref_light_texture_sampler;

cbuffer Globals : register(b0)
{
	float4x4 camera_world_matrix[2]      : packoffset(c48);
	float3   ref_light_color             : packoffset(c17);
	float3   ref_light_direction         : packoffset(c20);
	float    ref_light_falloff           : packoffset(c23.x);
	float4x4 ref_light_matrix            : packoffset(c24);
	float3   ref_light_position          : packoffset(c19);
	float    ref_light_start             : packoffset(c23.z);
	float    ref_spot_angle_falloff_end  : packoffset(c16.x);
	float    ref_spot_projection_scale   : packoffset(c16.y);
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
	float4 o;

	float4 r0;
	float4 r1;
	float4 r2;
	float3 r3;
	r0.x = ref_light_falloff.x * ref_light_falloff.x;
	r0.y = 1 / i.texcoord1.w;
	r0.yzw = r0.yyy * i.texcoord1.xyz;
	r1.x = 1 / i.texcoord.w;
	r1.xy = r1.xx * i.texcoord.xy;
	r2 = depth.Sample(depth_sampler, r1.xy);
	r3.x = r0.y * r2.x + transpose(camera_world_matrix[i.eye])[0].w;
	r3.y = r0.z * r2.x + transpose(camera_world_matrix[i.eye])[1].w;
	r3.z = r0.w * r2.x + transpose(camera_world_matrix[i.eye])[2].w;
	r0.yzw = -r3.xyz + ref_light_position.xyz;
	r1.z = dot(r3.xyz, ref_light_direction.xyz);
	r1.z = r1.z + -i.texcoord2.x;
	r1.z = r1.z + -ref_light_start.x;
	r1.w = dot(r0.yzw, r0.yzw);
	r0.x = r0.x * r1.w;
	r0.x = r0.x * -r0.x + 1;
	r2.x = max(r0.x, 0);
	r0.x = r2.x * r2.x;
	r2.x = r1.w + 1;
	r1.w = 1 / sqrt(r1.w);
	r0.yzw = r0.yzw * r1.www;
	r1.w = 1 / r2.x;
	r0.x = r0.x * r1.w;
	r0.x = r0.x * 30000;
	r1.w = (-r1.z >= 0) ? 0 : 1;
	r1.z = (r1.z >= 0) ? -0 : -1;
	r1.z = r1.z + r1.w;
	r0.x = r0.x * r1.z;
	r1.z = dot(r0.yzw, -ref_light_direction.xyz);
	r1.z = -r1.z + 1;
	r1.z = r1.z + -ref_spot_angle_falloff_end.x;
	r1.z = saturate(r1.z * i.texcoord2.y);
	r1.z = r1.z * r1.z;
	r0.x = r0.x * r1.z;
	r2 = normal.Sample(normal_sampler, r1.xy);
	r1 = albedo.Sample(albedo_sampler, r1.xy);
	r2.xyz = r2.xyz + -0.5;
	r2.xyz = r2.xyz + r2.xyz;
	r1.w = saturate(dot(r0.yzw, r2.xyz));
	r0.x = r0.x * r1.w;
	r2.x = dot(r0.yzw, transpose(ref_light_matrix)[0].xyz);
	r2.y = dot(r0.yzw, transpose(ref_light_matrix)[1].xyz);
	r0.yz = r2.xy * ref_spot_projection_scale.xx;
	r0.yz = r0.yz * 0.5 + 0.5;
	r2 = ref_light_texture.Sample(ref_light_texture_sampler, r0.yz);
	r2 = r2.xyzz * ref_light_color.xyzz;
	r2 = r2 + r2;
	r0 = r0.x * r2;
	r0 = r0 * r1.xyzz;
	o = max(r0, 0);

	return o;
}
