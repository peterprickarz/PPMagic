#[compute]
#version 450

#define PI 3.14159265358979323846f

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D sobel_image;
layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2D eigenvector_image;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float sigma;
    float smooth_tensor;
} params;

vec3 gauss(ivec2 uv, float sigma){
    
    float two_sigma_squared = 2.0 * sigma * sigma;
    int half_width = int(ceil( 2.0 * sigma ));
    
    vec3 sum = vec3(0.0);
    float norm = 0.0;
    if (half_width > 0) {
        for ( int i = -half_width; i <= half_width; ++i ) {
            for ( int j = -half_width; j <= half_width; ++j ) {
                float d = length(vec2(i,j));
                float kernel = exp( -d *d / two_sigma_squared );
                vec3 c = imageLoad(sobel_image, uv + ivec2(i,j) ).rgb;
                sum += kernel * c;
                norm += kernel;
            }
        }
    } else {
        sum = imageLoad(sobel_image, uv).rgb;
        norm = 1.0;
    }
    return sum / norm;
    
}


// The code we want to execute in each invocation
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	// Prevent reading/writing out of bounds.
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

    vec3 g = gauss(uv, params.sigma);

    float lambda1 = 0.5 * (g.y + g.x +
        sqrt(g.y*g.y - 2.0*g.x*g.y + g.x*g.x + 4.0*g.z*g.z));
    float lambda2 = 0.5 * (g.y + g.x -
        sqrt(g.y*g.y - 2.0*g.x*g.y + g.x*g.x + 4.0*g.z*g.z));

    vec2 v = vec2(lambda1 - g.x, -g.z);
    vec2 t;
    if (length(v) > 0.0) { 
        t = normalize(v);
    } else {
        t = vec2(0.0, 1.0);
    }

    float phi = atan(t.y, t.x);

    float A = (lambda1 + lambda2 > 0.0)?
        (lambda1 - lambda2) / (lambda1 + lambda2) : 0.0;



	imageStore(eigenvector_image, uv, vec4(t, phi, A));
}