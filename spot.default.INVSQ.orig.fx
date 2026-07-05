Texture2D depth;
Texture2D normal;

SamplerState depth_sampler;
SamplerState normal_sampler;

cbuffer Globals : register(b0)
{
	float4x4 camera_world_matrix[2]      : packoffset(c48);
	float3   ref_light_color             : packoffset(c17);
	float3   ref_light_direction         : packoffset(c20);
	float    ref_light_falloff           : packoffset(c23.x);
	float3   ref_light_position          : packoffset(c19);
	float    ref_light_start             : packoffset(c23.z);
	float    ref_spot_angle_falloff_end  : packoffset(c16.x);
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
	float3 r2;
	float r3;
	r0.x = 1 / i.texcoord.w;
	r0.xy = r0.xx * i.texcoord.xy;
	r1 = depth.Sample(depth_sampler, r0.xy);
	r0 = normal.Sample(normal_sampler, r0.xy);
	r0.xyz = r0.xyz + -0.5;
	r0.xyz = r0.xyz + r0.xyz;
	r0.w = 1 / i.texcoord1.w;
	r1.yzw = r0.www * i.texcoord1.xyz;
	r2.x = r1.y * r1.x + transpose(camera_world_matrix[i.eye])[0].w;
	r2.y = r1.z * r1.x + transpose(camera_world_matrix[i.eye])[1].w;
	r2.z = r1.w * r1.x + transpose(camera_world_matrix[i.eye])[2].w;
	r0.w = dot(r2.xyz, ref_light_direction.xyz);
	r1.xyz = -r2.xyz + ref_light_position.xyz;
	r0.w = r0.w + -i.texcoord2.x;
	r0.w = r0.w + -ref_light_start.x;
	r1.w = (-r0.w >= 0) ? 0 : 1;
	r0.w = (r0.w >= 0) ? -0 : -1;
	r0.w = r0.w + r1.w;
	r1.w = dot(r1.xyz, r1.xyz);
	r2.x = ref_light_falloff.x * ref_light_falloff.x;
	r2.x = r1.w * r2.x;
	r2.x = r2.x * -r2.x + 1;
	r3.x = max(r2.x, 0);
	r2.x = r3.x * r3.x;
	r2.y = r1.w + 1;
	r1.w = 1 / sqrt(r1.w);
	r1.xyz = r1.www * r1.xyz;
	r1.w = 1 / r2.y;
	r1.w = r2.x * r1.w;
	r1.w = r1.w * 30000;
	r0.w = r0.w * r1.w;
	r1.w = dot(r1.xyz, -ref_light_direction.xyz);
	r0.x = dot(r1.xyz, r0.xyz);
	r0.y = -r1.w + 1;
	r0.y = r0.y + -ref_spot_angle_falloff_end.x;
	r0.y = saturate(r0.y * i.texcoord2.y);
	r0.y = r0.y * r0.y;
	r0.y = r0.y * r0.w;
	r0.x = r0.y * r0.x;
	o = r0.x * ref_light_color.xyzz;

	return o;
}
