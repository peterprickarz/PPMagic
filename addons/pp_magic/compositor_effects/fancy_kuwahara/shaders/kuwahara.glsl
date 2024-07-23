#[compute]
#version 450

#define PI 3.14159265358979323846f

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(rgba16f, set = 1, binding = 0) uniform image2D blur_pass_2_image;
layout(set = 2, binding = 0) uniform sampler2D depth_sampler;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float radius; 
    float sharpness;
    float hardness;
    float alpha;
    float depth_scale;
    float min_radius;
} params;

const int N = 8;
const float HALF_SQRT2 = 0.7071067811865475244f;



// The code we want to execute in each invocation
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	// Prevent reading/writing out of bounds.
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

    float alpha = params.alpha;
    vec4 t = imageLoad(blur_pass_2_image, uv);

    float radius = params.radius;

    float depth = clamp(textureLod(depth_sampler, vec2(uv)/size, 0).r*params.depth_scale*100,0,1);
    radius = clamp(radius*depth,params.min_radius,radius);
    
    

    float a = float((radius)) * clamp((alpha + t.w) / alpha, 0.1f, 2.0f);
    float b = float((radius)) * clamp(alpha / (alpha + t.w), 0.1f, 2.0f);

    float cos_phi = cos(t.z);
    float sin_phi = sin(t.z);


    mat2 SR = mat2(cos_phi/a, -sin_phi/b, sin_phi/a, cos_phi/b);

    float aa = a * a;
	float bb = b * b;
	float coscos_phi = cos_phi * cos_phi;
	float sinsin_phi = sin_phi * sin_phi;
	
	int max_x = int(sqrt(aa * coscos_phi + bb * sinsin_phi));
	int max_y = int(sqrt(aa * sinsin_phi + bb * coscos_phi));


    int k;
    vec4 m[8];
    vec3 s[8];
    {
    	vec3 c = imageLoad(color_image, uv).rgb;
        float w = 1.0f / float(N);
        for (int k = 0; k < N; ++k) {
            m[k] =  vec4(c * w, w);
            s[k] = c * c * w;
        }
    }

    for (int j = 0; j <= max_y; ++j)  {
        for (int i = -max_x; i <= max_x; ++i) {
            if ((j !=0) || (i > 0)) {
                vec2 v = SR * vec2(i,j);
                
                float dotv = dot(v,v);

                if (dotv <= 1.0f) {
                    vec3 c0 = imageLoad(color_image, uv + ivec2(i,j)).rgb;
                    vec3 c1 = imageLoad(color_image, uv - ivec2(i,j)).rgb;

                    vec3 cc0 = c0 * c0;
                    vec3 cc1 = c1 * c1;

                    float sum = 0.0f;
					float w[8];
					float z, vxx, vyy;
					
					vxx = 0.33f - 3.77f * v.x * v.x;
					vyy = 0.33f - 3.77f * v.y * v.y;
					z = max(0.0f,  v.y + vxx); sum += w[0] = z * z;
					z = max(0.0f, -v.x + vyy); sum += w[2] = z * z;
					z = max(0.0f, -v.y + vxx); sum += w[4] = z * z;
					z = max(0.0f,  v.x + vyy); sum += w[6] = z * z;

					v = HALF_SQRT2 * vec2( v.x - v.y, v.x + v.y );

					vxx = 0.33f - 3.77f * v.x * v.x;
					vyy = 0.33f - 3.77f * v.y * v.y;
					z = max(0.0f,  v.y + vxx); sum += w[1] = z * z;
					z = max(0.0f, -v.x + vyy); sum += w[3] = z * z;
					z = max(0.0f, -v.y + vxx); sum += w[5] = z * z;
					z = max(0.0f,  v.x + vyy); sum += w[7] = z * z;

					float g = exp(-3.125f * dotv) / sum;
					
					for (int k = 0; k < N; ++k) {
						float wk = w[k] * g;
						m[k] += vec4(c0 * wk, wk);
						s[k] += cc0 * wk;
						m[(k+4)&7] += vec4(c1 * wk, wk);
						s[(k+4)&7] += cc1 * wk;
					}
                }
            }
        }
    }

    vec4 color_output = vec4(0);
    for (k = 0; k < N; ++k) {
        m[k].rgb /= m[k].w;
        s[k] = abs(s[k] / m[k].w - m[k].rgb * m[k].rgb);

        float sigma2 = s[k].r + s[k].g + s[k].b;
        float w = 1.0f / (1.0f + pow(params.hardness * 1000.0f * sigma2, 0.5f * params.sharpness));

        color_output += vec4(m[k].rgb * w, w);
    }

    color_output = clamp(color_output/color_output.w,0,1);

    

    imageStore(color_image, uv, color_output);
}