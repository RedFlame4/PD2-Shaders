
#include "include/common.hlsl"

Texture2D diffuse_texture;

SamplerState diffuse_texture_sampler;

#if defined(PDTH)
Texture2D self_illumination_texture;
SamplerState self_illumination_texture_sampler;
#endif

cbuffer Globals : register(b0)
{
  float camera_near_range : packoffset(c0);
  float3 camera_pos : packoffset(c0.y);
  float GLOBAL_fov_ratio : packoffset(c1);
  float GLOBAL_use_parallax : packoffset(c1.y);
  float4x4 view_proj_matrix : packoffset(c2);
  float3 render_target_size : packoffset(c6);
}

struct PS_IN
{
  float4 pos : SV_POSITION0;
  float2 texcoord : TEXCOORD;
};

float4 main(PS_IN i) : SV_Target
{
  float3 centerColor = diffuse_texture.Sample(diffuse_texture_sampler, i.texcoord).xyz;
  float centerSum = channel_sum(centerColor);

#if PDTH
  float3 illumColor = self_illumination_texture.Sample(self_illumination_texture_sampler, i.texcoord).xyz;

  // Original implementation:
  //   float roundedSum = ceil(diffuseSum);
  //   float3 result = illumColor * 1.5 - roundedSum.xxx;
  //   result = max(result, 0);
  // roundedSum was meant as a 0/1 mask (0 outside the contour, 1 inside it) to zero
  // out the interior, but it was subtracted rather than multiplied. That only zeroed
  // illumColor*1.5 when illumColor <= 0.667 (1.5*0.667 = 1) - past that brightness,
  // illumColor*1.5 - 1 stayed positive after the max(), so the interior lit up.
  //
  // Fix: mask multiplicatively instead, so brightness can never punch through.
  // centerSum is always >= 0 (sum of texture samples), so sign() gives a clean 0/1 mask.
  float contourMask = sign(centerSum);
  float3 result = illumColor * 1.5 * (1 - contourMask);

  return float4(result, 1);
#else
  float2 texelSize = float2(1, 1) / render_target_size.xy;

  float2 offsets[4] = {
    float2(texelSize.x, 0),
    float2(0, texelSize.y),
    float2(-texelSize.x, 0),
    float2(0, -texelSize.y)
  };

  float3 result = 0;

  [unroll]
  for (int j = 0; j < 4; j++) {
    float3 neighborColor = diffuse_texture.Sample(diffuse_texture_sampler, i.texcoord + offsets[j]).xyz;

    // mask is 1 where this neighbor is brighter than the center pixel, else 0.
    float mask = ceil(saturate(channel_sum(neighborColor) - centerSum));

    result += mask * neighborColor;
  }

  return float4(result, 0);
#endif
}
