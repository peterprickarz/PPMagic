#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2D sobel_image;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved; 
} params;

// The code we want to execute in each invocation
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	// Prevent reading/writing out of bounds.
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	// Read from our color buffer.
	vec4 color = imageLoad(color_image, uv);

	vec3 Sx = (
		1.0 * imageLoad(color_image, uv + ivec2(-1, -1)).rgb +
		2.0 * imageLoad(color_image, uv + ivec2(-1, 0)).rgb +
		1.0 * imageLoad(color_image, uv + ivec2(-1, 1)).rgb +
		-1.0 * imageLoad(color_image, uv + ivec2(1, -1)).rgb +
		-2.0 * imageLoad(color_image, uv + ivec2(1, 0)).rgb +
		-1.0 * imageLoad(color_image, uv + ivec2(1, 1)).rgb
	) / 4.0;
 
	vec3 Sy = (
		1.0 * imageLoad(color_image, uv + ivec2(-1, -1)).rgb +
		2.0 * imageLoad(color_image, uv + ivec2(0, -1)).rgb +
		1.0 * imageLoad(color_image, uv + ivec2(1, -1)).rgb +
		-1.0 * imageLoad(color_image, uv + ivec2(-1, 1)).rgb + 
		-2.0 * imageLoad(color_image, uv + ivec2(0, 1)).rgb +
		-1.0 * imageLoad(color_image, uv + ivec2(1, 1)).rgb
	) / 4.0;

	vec4 sobel = vec4(dot(Sx, Sx), dot(Sy,Sy),dot(Sx,Sy),1.0);

	// uncomment to preview in editor
	//imageStore(color_image, uv, clamp(sobel,0,1));
	imageStore(sobel_image, uv, sobel);
}