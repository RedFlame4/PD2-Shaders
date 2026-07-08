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
	float    ref_light_falloff_exponent  : packoffset(c23.y);
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
	float4 r3;
	float4 r4;
	r0.x = ref_light_falloff.x * ref_light_falloff.x;
	r0.y = 1 / i.texcoord1.w;
	r0.yzw = r0.yyy * i.texcoord1.xyz;
	r1.x = 1 / i.texcoord.w;
	r1.xy = r1.xx * i.texcoord.xy;
	r2 = depth.Sample(depth_sampler, r1.xy);
	r3.x = transpose(camera_world_matrix[i.eye])[0].w;
	r3.y = transpose(camera_world_matrix[i.eye])[1].w;
	r3.z = transpose(camera_world_matrix[i.eye])[2].w;
	r0.yzw = r0.yzw * r2.xxx + r3.xyz;
	r2.xyz = -r0.yzw + r3.xyz;
	r3.xyz = -r0.yzw + ref_light_position.xyz;
	r0.y = dot(r0.yzw, ref_light_direction.xyz);
	r0.y = r0.y + -i.texcoord2.x;
	r0.y = r0.y + -ref_light_start.x;
	r0.z = dot(r3.xyz, r3.xyz);
	r0.x = r0.z * r0.x;
	r0.x = r0.x * -r0.x + 1;
	r1.z = max(r0.x, 0);
	r0.x = r1.z * r1.z;
	r0.w = r0.z + 1;
	r0.z = 1 / sqrt(r0.z);
	r3.xyz = r0.zzz * r3.xyz;
	r0.z = 1 / r0.w;
	r0.x = r0.x * r0.z;
	r0.x = r0.x * 30000;
	r0.z = (-r0.y >= 0) ? 0 : 1;
	r0.y = (r0.y >= 0) ? -0 : -1;
	r0.y = r0.y + r0.z;
	r0.x = r0.y * r0.x;
	r0.y = dot(r3.xyz, -ref_light_direction.xyz);
	r0.y = -r0.y + 1;
	r0.y = r0.y + -ref_spot_angle_falloff_end.x;
	r0.y = saturate(r0.y * i.texcoord2.y);
	r0.y = r0.y * r0.y;
	r0.x = r0.y * r0.x;
	r4 = normal.Sample(normal_sampler, r1.xy);
	r1 = albedo.Sample(albedo_sampler, r1.xy);
	r0.yzw = r4.xyz + -0.5;
	r4.w = r4.w * r4.w;
	r0.yzw = r0.yzw + r0.yzw;
	r3.w = saturate(dot(r3.xyz, r0.yzw));
	r0.x = r0.x * r3.w;
	r2.w = dot(r4.ww, r0.xx) + 0;
	r3.w = dot(r2.xyz, r2.xyz);
	r3.w = 1 / sqrt(r3.w);
	r2.xyz = (half3)(r2.xyz * r3.www + r3.xyz);
	r4.xyz = normalize(r2.xyz);
	r0.y = saturate(dot(r4.xyz, r0.yzw));
	r0.z = lerp(10, 210, r4.w);
	r1.w = pow(r0.y, r0.z);
	r2.x = 1;
	r0.y = saturate(-r2.x + ref_light_falloff_exponent.x);
	r0.y = r0.y * 0.33 + 1;
	r0.y = r0.y * r1.w;
	r0.y = r2.w * r0.y;
	r2.x = dot(r3.xyz, transpose(ref_light_matrix)[0].xyz);
	r2.y = dot(r3.xyz, transpose(ref_light_matrix)[1].xyz);
	r0.zw = r2.xy * ref_spot_projection_scale.xx;
	r0.zw = r0.zw * 0.5 + 0.5;
	r2 = ref_light_texture.Sample(ref_light_texture_sampler, r0.zw);
	r2 = r2.xyzz * ref_light_color.xyzz;
	r2 = r2 + r2;
	r3 = r0.y * r2;
	r0 = r0.x * r2.xyww;
	r0 = r1.xyzz * r0 + r3;
	o = max(r0, 0);

	return o;
}
