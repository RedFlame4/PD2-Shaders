#include "include/common.hlsl"

#if defined(DIFFUSE_TEXTURE)
Texture2D diffuse_texture;
SamplerState diffuse_texture_sampler;
#endif

#if defined(OPACITY_TEXTURE)
Texture2D opacity_texture; // separate alpha-test source and UV set from diffuse_texture
SamplerState opacity_texture_sampler;
#endif

#if defined(DETAIL_TEXTURE_2)
Texture2D diffuse_layer1_texture; // tiled overlay multiplied onto albedo, green channel only
SamplerState diffuse_layer1_texture_sampler;
#endif

#if defined(GSMA_TEXTURE)
Texture2D material_texture; // .x -> albedo.w (replaces the 0.4 constant), .y -> normal.w (replaces diffuse alpha)
SamplerState material_texture_sampler;
#endif

#if defined(NORMALMAP)
Texture2D bump_normal_texture;
SamplerState bump_normal_texture_sampler;
#endif

#if defined(CUBE_ENVIRONMENT_MAPPING)
TextureCube reflection_texture; // slot order verified after diffuse_texture/material_texture/bump_normal_texture
SamplerState reflection_texture_sampler;
#endif

#if defined(DETAIL_RGB_MASK)
Texture2D diffuse_layer0_texture; // RGB mask: red/green/blue channels gate the matching DETAIL_*_RED/GREEN/BLUE blend amounts
SamplerState diffuse_layer0_texture_sampler;
#endif

#if defined(DETAIL_NORMAL_TEXTURE_RED)
Texture2D normal_layer0_texture; // secondary tiled normal map, screen-blended into the main normal
SamplerState normal_layer0_texture_sampler;
#endif

#if defined(DETAIL_NORMAL_TEXTURE_GREEN)
Texture2D normal_layer1_texture;
SamplerState normal_layer1_texture_sampler;
#endif

#if defined(DETAIL_NORMAL_TEXTURE_BLUE)
Texture2D normal_layer2_texture;
SamplerState normal_layer2_texture_sampler;
#endif

#if defined(DETAIL_DIFFUSE_TEXTURE_RED)
Texture2D diffuse_layer1_texture; // tiled overlay multiplied toward white, weighted by the RGB mask's red channel
SamplerState diffuse_layer1_texture_sampler;
#endif

#if defined(DETAIL_DIFFUSE_TEXTURE_GREEN)
Texture2D diffuse_layer2_texture; // tiled overlay multiplied toward white, weighted by the RGB mask's green channel
SamplerState diffuse_layer2_texture_sampler;
#endif

#if defined(DETAIL_DIFFUSE_TEXTURE_BLUE)
Texture2D diffuse_layer3_texture; // same as DETAIL_DIFFUSE_TEXTURE_GREEN but blue channel
SamplerState diffuse_layer3_texture_sampler;
#endif

#if defined(PARALLAX_ANIMATION)
Texture2D parallax_animation_texture;
SamplerState parallax_animation_texture_sampler;
#endif

#if defined(PARALLAX) || defined(SIMPLE_TINT) || defined(GLOSS_CONTROL_VALUE) || defined(EXTERNAL_ALPHA_REF) \
	|| defined(DETAIL_NORMAL_TEXTURE_RED) || defined(DETAIL_NORMAL_TEXTURE_GREEN) || defined(DETAIL_NORMAL_TEXTURE_BLUE) \
	|| defined(CUBE_ENVIRONMENT_MAPPING)
// Not packoffset-pinned to the real game's cbuffer layout: that requires per-combo dump
// verification (the real cbuffer also holds a bunch of matrices/arrays this shader never
// reads, purely to keep later fields' offsets aligned) and got fragile/bloated fast as more
// combos came in. Each field here is declared only when the define that reads it is active,
// letting fxc auto-assign registers - this won't match the real game's cb0[N] indices, but
// needs far less upkeep. Revisit if/when byte-exact cbuffer layout actually matters.
cbuffer Globals : register(b0)
{
#if defined(PARALLAX)
	float GLOBAL_use_parallax;
	float ref_parallax_scale;
	float ref_parallax_layers;
#endif
#if defined(PARALLAX_ANIMATION)
	float ref_parallax_animation_scale;
#endif
#if defined(PARALLAX_ANIMATION) && defined(NORMALMAP_DEPTH_TEXTURE)
	float3 ref_parallax_animation_normal_settings;
#endif
#if defined(SIMPLE_TINT)
	float3 ref_tint_color;
#endif
#if defined(GLOSS_CONTROL_VALUE)
	float ref_glossiness_control;
#endif
#if defined(EXTERNAL_ALPHA_REF)
	float ref_alpha_ref;
#endif
#if defined(DETAIL_NORMAL_TEXTURE_RED)
	float3 ref_red_detail_scale;
	float ref_red_detail_intensity;
#endif
#if defined(DETAIL_NORMAL_TEXTURE_GREEN)
	float3 ref_green_detail_scale;
	float ref_green_detail_intensity;
#endif
#if defined(DETAIL_NORMAL_TEXTURE_BLUE)
	float3 ref_blue_detail_scale;
	float ref_blue_detail_intensity;
#endif
#if defined(CUBE_ENVIRONMENT_MAPPING)
	// Indexed by i.eye (a per-object environment-probe index); only the position
	// (the last column of each entry) is read here, matching the compiled
	// dynamic-index pattern (ishl by 4 registers = sizeof(float4x4)/16, then
	// reading the .w component of 3 consecutive rows - the classic row-major
	// "translation lives in the last column" layout). Needs explicit row_major:
	// HLSL's default cbuffer matrix packing is column-major, which packs
	// _m03/_m13/_m23 into one register (a whole column) instead of one per row -
	// same value, wrong instructions. Array size is a guess (not dump-verified)
	// since we don't try to match the real cbuffer layout.
	row_major float4x4 ref_environment_settings[2];
#endif
};
#endif

struct PS_IN
{
	// Unused, but must stay first: the engine links VS->PS interpolants by
	// raw register slot, not semantic name, so this keeps every field below
	// at the same v-register the real shader expects.
	float4 pos : SV_Position;
	float depth : TEXCOORD1;

#if defined(NORMALMAP)
	float3 tangent : TEXCOORD2;
	float4 texcoord : TEXCOORD0; // xy = diffuse_texture uv, zw = bump_normal_texture uv (unless NORMALMAP_UV1 or PARALLAX)
	#if defined(PARALLAX)
	float3 bitangent : TEXCOORD3;
	float parallax_fade : TEXCOORD10; // gates + blends the parallax ray march below some distance/LOD threshold
	#else
	float4 bitangent : TEXCOORD3;
	#endif
	float4 normal : TEXCOORD4;
	#if defined(CUBE_ENVIRONMENT_MAPPING)
	float3 world_pos : TEXCOORD16;
	#endif
	#if defined(OPACITY_TEXTURE)
	float2 opacity_uv : TEXCOORD17; // separate UV set from texcoord.xy; placement here not dump-verified for NORMALMAP
	#endif
	#if defined(PARALLAX)
	float4 view_dir_tangent : TEXCOORD8; // tangent-space eye vector, precomputed per-vertex
	#endif
	#if defined(PARALLAX_ANIMATION_UV2)
	float2 parallax_animation_uv : TEXCOORD11;
	#endif
	#if defined(VERTEX_COLOR)
	float4 color : COLOR0;
	#endif
#elif defined(DIFFUSE_TEXTURE)
	float2 texcoord : TEXCOORD0;
	#if defined(VERTEX_COLOR)
	float3 normal : TEXCOORD2;
	#if defined(CUBE_ENVIRONMENT_MAPPING)
	float3 world_pos : TEXCOORD16;
	#endif
	#if defined(OPACITY_TEXTURE)
	float2 opacity_uv : TEXCOORD17; // placement here (after world_pos) not dump-verified when both are active
	#endif
	float4 color : COLOR0;
	#else
	float4 normal : TEXCOORD2;
	#if defined(CUBE_ENVIRONMENT_MAPPING)
	float3 world_pos : TEXCOORD16;
	#endif
	#if defined(OPACITY_TEXTURE)
	float2 opacity_uv : TEXCOORD17; // verified: right after normal for plain DIFFUSE_TEXTURE+OPACITY_TEXTURE
	#endif
	#endif
#elif defined(VERTEX_COLOR) || defined(VERTEX_COLOR_ALPHA)
	float3 normal : TEXCOORD2;
	#if defined(CUBE_ENVIRONMENT_MAPPING)
	float3 world_pos : TEXCOORD16;
	#endif
	float4 color : COLOR0;
#else
	// Base case: no diffuse texture or vertex color at all, just a flat white
	// albedo (see the DIFFUSE_TEXTURE #else branch below) and a plain vertex normal.
	float3 normal : TEXCOORD2;
	#if defined(CUBE_ENVIRONMENT_MAPPING)
	float3 world_pos : TEXCOORD16;
	#endif
#endif

	nointerpolation uint eye : TEXCOORD15;

#if defined(DOUBLE_SIDED)
	bool is_front_face : SV_IsFrontFace;
#endif
};

struct PS_OUT
{
	float4 albedo : SV_Target0;
	float4 normal : SV_Target1;
	float4 depth  : SV_Target2;
};

#if defined(CUBE_ENVIRONMENT_MAPPING)
// Shared by the non-NORMALMAP and NORMALMAP paths in main() below, which call this with
// different shading normals (raw i.normal.xyz vs the TBN-decoded world_normal) at two
// different points in the function - HLSL always inlines non-entry functions in a pixel
// shader, so factoring this out doesn't change the compiled instructions, verified.
// reflection_mask is material_s.z (a reflection-intensity mask) when GLOSS_BLURS_CUBEMAP
// combines with GSMA_TEXTURE, or 1 otherwise (fxc constant-folds the *1 away).
float3 cube_environment_reflection(float3 shading_normal, float3 world_pos, uint eye,
                                    float albedo_w, float alpha_source, float reflection_mask) {
	// ref_environment_settings[eye] is a per-object environment probe; only its position
	// (last column) is read. n_dot_l and its doubled form are each computed once and
	// reused (matching the reference exactly, not just algebraically) since fxc doesn't
	// always re-derive one from the other identically.
	float3 probe_pos = ref_environment_settings[eye]._m03_m13_m23;
	float3 dir_to_probe = normalize(probe_pos - world_pos);
	float n_dot_l = dot(shading_normal, dir_to_probe);
	float two_n_dot_l = n_dot_l + n_dot_l;
	// Fresnel-ish falloff term: written as a genuine 2-component dot (matches the
	// compiled dp2), not the algebraically-equivalent "x*x*2".
	float one_minus_sat = 1 - saturate(n_dot_l);
	float fresnel = dot(one_minus_sat.xx, one_minus_sat.xx) + 0.25;
	float3 reflect_dir = dir_to_probe - two_n_dot_l * shading_normal;
	#if defined(GLOSS_BLURS_CUBEMAP)
	// Rougher surfaces sample a blurrier mip: round_ni (HLSL's floor(), not round())
	// of (1-gloss)*7, using whatever albedo.w already resolved to (GSMA_TEXTURE's
	// material_s.x, GLOSS_CONTROL_VALUE's ref_glossiness_control, or the 0.4 default).
	float reflection_lod = floor((1 - albedo_w) * 7);
	float3 reflection_s = reflection_texture.SampleLevel(reflection_texture_sampler, reflect_dir, reflection_lod).xyz;
	#else
	float3 reflection_s = reflection_texture.Sample(reflection_texture_sampler, reflect_dir).xyz;
	#endif
	fresnel *= alpha_source;
	return reflection_s * fresnel * reflection_mask;
}
#endif

PS_OUT main(PS_IN i)
{
	PS_OUT o;

#if defined(DIFFUSE_TEXTURE) || defined(NORMALMAP)
	float2 uv = i.texcoord.xy;
	float parallax_anim_amount = 0; // how much the animation texture is displacing height at this pixel; feeds the normal perturbation below

	#if defined(PARALLAX)
	if (GLOBAL_use_parallax > 0) {
		float2 parallax_uv = uv;

		// The fade-gated ray march itself (view direction, layer count/step, steep search,
		// optional relief refinement) is core to PARALLAX regardless of PARALLAX_ANIMATION -
		// confirmed by a PARALLAX+PARALLAX_RELIEF (no ANIMATION) dump showing the identical
		// structure, just without any animation-texture height term.
		if (i.parallax_fade < 1) {
			float3 view_dir = normalize(i.view_dir_tangent.xyz);

			#if defined(PARALLAX_ANIMATION)
				#if defined(PARALLAX_ANIMATION_UV2)
					float anim_s = parallax_animation_texture.Sample(parallax_animation_texture_sampler, i.parallax_animation_uv).x;
				#else
					float anim_s = parallax_animation_texture.Sample(parallax_animation_texture_sampler, uv).x;
				#endif
				// Pre-existing gap, not related to CUBE_ENVIRONMENT_MAPPING: this unconditionally
				// read i.color.w, which only compiles when VERTEX_COLOR/VERTEX_COLOR_ALPHA is also
				// active. Every previously-tested PARALLAX_ANIMATION combo happened to have one of
				// those, so this never surfaced. No dump to check the no-vertex-color behavior
				// against; treating the vertex-alpha factor as 1 (no masking) is an assumption,
				// not verified.
				#if defined(VERTEX_COLOR) || defined(VERTEX_COLOR_ALPHA)
				parallax_anim_amount = (1 - anim_s) * i.color.w;
				#else
				parallax_anim_amount = 1 - anim_s;
				#endif
				float uv_scale = 1 + ref_parallax_animation_scale;
			#else
				float uv_scale = 1;
			#endif

			float layer_count = abs(view_dir.z) * (5 - ref_parallax_layers) + ref_parallax_layers;
			float layer_step = uv_scale / layer_count;
			float2 uv_step = ((ref_parallax_scale * uv_scale) * view_dir.xy) / view_dir.z / layer_count;

			float2 ddx_uv = ddx_coarse(uv);
			float2 ddy_uv = ddy_coarse(uv);

			float cur_layer = 0;
			float2 cur_uv = uv;
			#if defined(PARALLAX_ANIMATION)
				float cur_height = 1 + (parallax_anim_amount * ref_parallax_animation_scale
					- bump_normal_texture.SampleGrad(bump_normal_texture_sampler, uv, ddx_uv.x, ddy_uv.x).z);
			#else
				float cur_height = 1 - bump_normal_texture.SampleGrad(bump_normal_texture_sampler, uv, ddx_uv.x, ddy_uv.x).z;
			#endif

			// Steep parallax: linear search for the first layer that's below the height surface.
			float layer_i = 0;
			[loop]
			while (cur_layer < cur_height && layer_i < 10) {
				cur_layer += layer_step;
				cur_uv -= uv_step;
				float h = bump_normal_texture.SampleGrad(bump_normal_texture_sampler, cur_uv, ddx_uv.x, ddy_uv.x).z;
				#if defined(PARALLAX_ANIMATION)
					cur_height = 1 + (parallax_anim_amount * ref_parallax_animation_scale - h);
				#else
					cur_height = 1 - h;
				#endif
				layer_i = layer_i + 1;
			}

			float2 search_uv = cur_uv + 0.5 * uv_step;
			float search_layer = cur_layer - 0.5 * layer_step;
			float2 search_step = 0.5 * uv_step;
			float search_layer_step = 0.5 * layer_step;

			#if defined(PARALLAX_RELIEF)
			// Relief mapping: binary-search refinement between the last two steep-parallax samples.
			float refine_i = 0;
			[loop]
			while ((int)refine_i < 5) {
				float2 next_step = 0.5 * search_step;
				float next_layer_step = 0.5 * search_layer_step;

				float h = bump_normal_texture.SampleGrad(bump_normal_texture_sampler, search_uv, ddx_uv.x, ddy_uv.x).z;
				#if defined(PARALLAX_ANIMATION)
					bool below_surface = search_layer < 1 + (parallax_anim_amount * ref_parallax_animation_scale - h);
				#else
					bool below_surface = search_layer < 1 - h;
				#endif

				search_uv += below_surface ? -next_step : next_step;
				search_layer += below_surface ? next_layer_step : -next_layer_step;

				refine_i = (int)refine_i + 1;
				search_step = next_step;
				search_layer_step = next_layer_step;
			}
			#endif

			parallax_uv = search_uv;
		}

		// Same pre-existing gap as parallax_anim_amount above: PARALLAX_ANIMATION_VERTEX_ALPHA_MASK
		// unconditionally read i.color.w, only compiling when VERTEX_COLOR/VERTEX_COLOR_ALPHA is
		// also active. No dump to check the no-vertex-color behavior against; treating the
		// vertex-alpha term as 0 (no subtraction) is an assumption, not verified.
		#if defined(PARALLAX_ANIMATION_VERTEX_ALPHA_MASK) && (defined(VERTEX_COLOR) || defined(VERTEX_COLOR_ALPHA))
			// As compiled, this saturate(...) evaluates to exactly 1 whenever the ray march above
			// was skipped (i.parallax_fade >= 1), which zeroes out the otherwise-uninitialized
			// parallax_uv term below — matches an "uninitialized variable" warning from fxc.
			float parallax_blend = saturate(1 + i.parallax_fade - i.color.w);
		#else
			float parallax_blend = saturate(i.parallax_fade);
		#endif
		uv = lerp(parallax_uv, uv, parallax_blend);
	}
	#endif
#endif

#if defined(DETAIL_RGB_MASK)
	float3 detail_mask_s = diffuse_layer0_texture.Sample(diffuse_layer0_texture_sampler, i.texcoord.zw).xyz;
#endif

#if defined(SIMPLE_TINT) && defined(VERTEX_COLOR)
	// Computed here, ahead of any texture sample, as one expression independent of
	// the diffuse sample - this is what lets fxc's scheduler hoist the tint/vertex_color
	// math ahead of the texture sample to hide its latency, matching the reference's
	// register allocation. As compiled, combining with VERTEX_COLOR doubles the tint
	// multiplier again (tint*4 here vs tint*2 in the SIMPLE_TINT-alone case below).
	float3 vertex_tint = i.color.xyz * ref_tint_color.xyz;
	vertex_tint *= 4;
#endif

#if defined(GSMA_TEXTURE)
	#if defined(CUBE_ENVIRONMENT_MAPPING) && defined(GLOSS_BLURS_CUBEMAP) && defined(GSMA_ALPHA_MASKING) && !defined(OPACITY_TEXTURE)
	// Both the reflection-intensity mask (.z) and the alpha-test source (.w) are needed
	// at once here, so all 4 channels get sampled instead of a 3-component swizzle.
	float4 material_s = material_texture.Sample(material_texture_sampler, uv);
	#elif defined(CUBE_ENVIRONMENT_MAPPING) && defined(GLOSS_BLURS_CUBEMAP)
	// material_s.z is only read (as a reflection-intensity mask, see below) when
	// GLOSS_BLURS_CUBEMAP is active; the plain GSMA_TEXTURE case never samples it.
	float3 material_s = material_texture.Sample(material_texture_sampler, uv).xyz;
	#elif defined(GSMA_ALPHA_MASKING) && !defined(OPACITY_TEXTURE)
	// material_s.z here is material_texture's alpha channel (.w swizzled in), used as
	// the alpha-test source below instead of diffuse_s.w - only when OPACITY_TEXTURE
	// isn't also present (OPACITY_TEXTURE takes priority over GSMA_ALPHA_MASKING when
	// both are active, verified via a combo with both defined).
	float3 material_s = material_texture.Sample(material_texture_sampler, uv).xyw;
	#else
	float2 material_s = material_texture.Sample(material_texture_sampler, uv).xy;
	#endif
	o.albedo.w = material_s.x;
#elif defined(GLOSS_CONTROL_VALUE)
	o.albedo.w = ref_glossiness_control;
#else
	o.albedo.w = 0.4;
#endif

#if defined(DIFFUSE_TEXTURE)
	#if defined(ALPHA_MASKED)
	// Threshold is shared by whichever alpha source below actually applies.
	#if defined(EXTERNAL_ALPHA_REF)
	float alpha_threshold = ref_alpha_ref;
	#else
	float alpha_threshold = 0.00390625;
	#endif

	// Alpha source priority: OPACITY_TEXTURE (own texture/UV set, sampled and tested
	// before diffuse_texture is even sampled) > GSMA_ALPHA_MASKING (material_texture's
	// alpha channel, see material_s above - lands in .w when all 4 channels were
	// sampled for the GLOSS_BLURS_CUBEMAP case, .z otherwise) > plain diffuse alpha.
	#if defined(OPACITY_TEXTURE)
	float alpha_s = opacity_texture.Sample(opacity_texture_sampler, i.opacity_uv).x;
	#elif defined(GSMA_TEXTURE) && defined(GSMA_ALPHA_MASKING)
	#if defined(CUBE_ENVIRONMENT_MAPPING) && defined(GLOSS_BLURS_CUBEMAP)
	float alpha_s = material_s.w;
	#else
	float alpha_s = material_s.z;
	#endif
	#endif
	#endif

	float4 diffuse_s = diffuse_texture.Sample(diffuse_texture_sampler, uv);
	#if defined(ALPHA_MASKED)
	#if !defined(OPACITY_TEXTURE) && !(defined(GSMA_TEXTURE) && defined(GSMA_ALPHA_MASKING))
	float alpha_s = diffuse_s.w;
	#endif
	if (alpha_s < alpha_threshold) {
		discard;
	}
	#endif
	#if defined(CUBE_ENVIRONMENT_MAPPING) && !defined(NORMALMAP)
		// The reflection contribution is only added to albedo at the very end (after
		// SIMPLE_TINT/VERTEX_COLOR) - it's not itself tinted/vertex-colored, only the
		// diffuse base is. With NORMALMAP this same computation happens later instead
		// (see world_normal below), since it needs the TBN-decoded world normal, not
		// the raw vertex normal used here.
		float3 reflection_contribution = cube_environment_reflection(i.normal.xyz, i.world_pos, i.eye,
			o.albedo.w,
			#if defined(GSMA_TEXTURE)
			material_s.y,
			#else
			diffuse_s.w,
			#endif
			#if defined(GLOSS_BLURS_CUBEMAP) && defined(GSMA_TEXTURE)
			material_s.z
			#else
			1
			#endif
		);
	#endif
	o.albedo.xyz = diffuse_s.xyz;
	#if defined(GSMA_TEXTURE)
		o.normal.w = material_s.y;
	#else
		o.normal.w = diffuse_s.w;
	#endif
#else
	// VERTEX_COLOR_ALPHA alone contributes no math here — it only means the
	// material needs the vertex color interpolant declared (COLOR0 below),
	// presumably read elsewhere for alpha blending/testing.
	o.albedo.xyz = float3(1, 1, 1);
	o.normal.w = 1;
#endif

#if defined(DETAIL_TEXTURE_2)
	float detail_s = diffuse_layer1_texture.Sample(diffuse_layer1_texture_sampler, uv * 8).y;
	o.albedo.xyz *= detail_s + detail_s;
#endif

#if defined(DETAIL_DIFFUSE_TEXTURE_RED)
	float3 red_diffuse_s = diffuse_layer1_texture.Sample(diffuse_layer1_texture_sampler, ref_red_detail_scale.xy * i.texcoord.xy).xyz;
	o.albedo.xyz *= detail_mask_s.x * (red_diffuse_s - 1) + 1;
#endif

#if defined(DETAIL_DIFFUSE_TEXTURE_GREEN)
	float3 green_diffuse_s = diffuse_layer2_texture.Sample(diffuse_layer2_texture_sampler, ref_green_detail_scale.xy * i.texcoord.xy).xyz;
	o.albedo.xyz *= detail_mask_s.y * (green_diffuse_s - 1) + 1;
#endif

#if defined(DETAIL_DIFFUSE_TEXTURE_BLUE)
	float3 blue_diffuse_s = diffuse_layer3_texture.Sample(diffuse_layer3_texture_sampler, ref_blue_detail_scale.xy * i.texcoord.xy).xyz;
	o.albedo.xyz *= detail_mask_s.z * (blue_diffuse_s - 1) + 1;
#endif

#if defined(SIMPLE_TINT) && defined(VERTEX_COLOR)
	o.albedo.xyz *= vertex_tint;
#elif defined(SIMPLE_TINT)
	o.albedo.xyz *= ref_tint_color.xyz + ref_tint_color.xyz;
#elif defined(VERTEX_COLOR)
	o.albedo.xyz *= i.color.xyz;
#endif

#if defined(VERTEX_COLOR) && defined(VERTEX_ALPHA)
	o.albedo.xyz *= i.color.w;
#endif

#if defined(CUBE_ENVIRONMENT_MAPPING) && !defined(NORMALMAP)
	// With NORMALMAP this combine happens later instead (see world_normal below),
	// alongside where reflection_contribution gets computed there.
	o.albedo.xyz += reflection_contribution;
#endif

#if defined(NORMALMAP)
	#if defined(PARALLAX)
		float2 bump_uv = uv;
	#elif defined(NORMALMAP_UV1)
		float2 bump_uv = i.texcoord.xy;
	#else
		float2 bump_uv = i.texcoord.zw;
	#endif

	float4 bump_s = bump_normal_texture.Sample(bump_normal_texture_sampler, bump_uv);

	#if defined(NORMALMAP_DEPTH_TEXTURE)
		// Height (for parallax) is packed into this texture's own blue channel, so the format
		// is unambiguous: no need for the alt-encoding flag used in the non-height format below.
		float2 normal_xy = decode_signed_normal(bump_s.xy);
		float bump_height = bump_s.z;

		float3 tangent_normal;
		tangent_normal.x = normal_xy.x;
		// z reconstruction as compiled: sqrt(1 + x*x - y*y), not the usual sqrt(1 - x*x - y*y).
		// Written as 3 separate steps (mul, mad, add) rather than algebraically fused -
		// same value, but matches the compiled instructions exactly.
		{
			float x2 = normal_xy.x * normal_xy.x;
			float y2_minus_x2 = normal_xy.y * normal_xy.y - x2;
			tangent_normal.z = sqrt(1 - y2_minus_x2);
		}

		#if defined(PARALLAX_ANIMATION)
			// The animated parallax height perturbs the normal's tangent-space y component,
			// smoothed off via a classic 3t^2-2t^3 curve.
			float normal_t = saturate((bump_height * parallax_anim_amount) / ref_parallax_animation_normal_settings.x);
			float normal_smooth_t = normal_t * normal_t * (3 - 2 * normal_t);
			tangent_normal.y = (normal_xy.y * normal_smooth_t) * ref_parallax_animation_normal_settings.y + normal_xy.y;
		#else
			tangent_normal.y = normal_xy.y;
		#endif

		// Unlike the non-depth-texture format, this one re-normalizes tangent_normal before
		// transforming it into world space (on top of the final normalize below).
		tangent_normal = normalize(tangent_normal);
	#else
		float3 tangent_normal = decode_normalmap_alt_channel(bump_s);
	#endif

	#if defined(DETAIL_NORMAL_TEXTURE_RED) || defined(DETAIL_NORMAL_TEXTURE_GREEN) || defined(DETAIL_NORMAL_TEXTURE_BLUE)
		// Detail normals are composited red-under-green-under-blue (standard "over" compositing:
		// combo = weight*N + (1-weight)*combo_so_far), then screen-blended onto the main normal.
		float3 detail_normal_combo = 0;

		#if defined(DETAIL_NORMAL_TEXTURE_RED)
			float2 red_detail_uv = ref_red_detail_scale.xy * bump_uv;
			float3 red_detail_normal = decode_normalmap_alt_channel(normal_layer0_texture.Sample(normal_layer0_texture_sampler, red_detail_uv));
			float red_detail_weight = ref_red_detail_intensity * detail_mask_s.x;
			detail_normal_combo = red_detail_weight * red_detail_normal + (1 - red_detail_weight) * detail_normal_combo;
		#endif

		#if defined(DETAIL_NORMAL_TEXTURE_GREEN)
			float2 green_detail_uv = ref_green_detail_scale.xy * bump_uv;
			float3 green_detail_normal = decode_normalmap_alt_channel(normal_layer1_texture.Sample(normal_layer1_texture_sampler, green_detail_uv));
			float green_detail_weight = ref_green_detail_intensity * detail_mask_s.y;
			detail_normal_combo = green_detail_weight * green_detail_normal + (1 - green_detail_weight) * detail_normal_combo;
		#endif

		#if defined(DETAIL_NORMAL_TEXTURE_BLUE)
			float2 blue_detail_uv = ref_blue_detail_scale.xy * bump_uv;
			float3 blue_detail_normal = decode_normalmap_alt_channel(normal_layer2_texture.Sample(normal_layer2_texture_sampler, blue_detail_uv));
			float blue_detail_weight = ref_blue_detail_intensity * detail_mask_s.z;
			detail_normal_combo = blue_detail_weight * blue_detail_normal + (1 - blue_detail_weight) * detail_normal_combo;
		#endif

		// Screen blend: 1 - (1-main)*(1-detail_combo), then re-normalize since the blend doesn't preserve unit length.
		tangent_normal = 1 - (1 - tangent_normal) * (1 - detail_normal_combo);
		tangent_normal = normalize(tangent_normal);
	#endif

	float3 world_normal;
	world_normal.x = dot(tangent_normal, i.tangent);
	world_normal.y = dot(tangent_normal, i.bitangent.xyz);
	world_normal.z = dot(tangent_normal, i.normal.xyz);
	world_normal = normalize(world_normal);
	#if defined(DOUBLE_SIDED)
		// As compiled: flip after the normalize above, then normalize again (redundant -
		// flipping a unit vector can't change its length - but that's what's there).
		world_normal = i.is_front_face ? world_normal : -world_normal;
		world_normal = normalize(world_normal);
	#endif

	#if defined(CUBE_ENVIRONMENT_MAPPING)
		// Same computation as the non-NORMALMAP case above, but using the TBN-decoded
		// world_normal instead of the raw vertex normal - verified this has to happen
		// here (after world_normal is finalized), not where the non-NORMALMAP version
		// sits, matching the reference's instruction order exactly. DOUBLE_SIDED+
		// CUBE_ENVIRONMENT_MAPPING+NORMALMAP combos aren't dump-verified (whether the
		// pre- or post-flip world_normal is used here) - this uses the final one as
		// the most semantically sensible guess.
		o.albedo.xyz += cube_environment_reflection(world_normal, i.world_pos, i.eye,
			o.albedo.w,
			#if defined(GSMA_TEXTURE)
			material_s.y,
			#else
			diffuse_s.w,
			#endif
			#if defined(GLOSS_BLURS_CUBEMAP) && defined(GSMA_TEXTURE)
			material_s.z
			#else
			1
			#endif
		);
	#endif
#else
	// Unlike the NORMALMAP path above, this one has no pre-normalize before the flip:
	// as compiled, DOUBLE_SIDED flips the raw vertex normal first, then normalizes once.
	#if defined(DOUBLE_SIDED)
		float3 world_normal = i.is_front_face ? i.normal.xyz : -i.normal.xyz;
	#else
		float3 world_normal = i.normal.xyz;
	#endif
	world_normal = normalize(world_normal);
#endif

	o.normal.xyz = encode_signed_normal(world_normal);

	o.depth = i.depth.xxxx;

	return o;
}
