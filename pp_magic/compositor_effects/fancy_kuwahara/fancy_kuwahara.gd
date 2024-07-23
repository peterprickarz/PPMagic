@tool
extends CompositorEffect
class_name FancyKuwahara

@export_range(1,30) var kuwahara_radius: int = 10
@export_range(1,15) var sharpness: float = 10
@export_range(0,10) var hardness: float = 10
@export_range(0,5) var alpha: float = .5
@export_range(0,10) var depth_scale: float = 1
@export_range(1,30) var min_radius: int = 2
@export_range(.5,10) var sigma: float = 2.5

const RESERVED: float = 0

var rd: RenderingDevice

var nearest_sampler : RID
var linear_sampler : RID

var sobel_shader: RID
var sobel_pipeline: RID

var eigenvectors_shader: RID
var eigenvectors_pipeline: RID

var kuwahara_shader: RID
var kuwahara_pipeline: RID

var context: StringName = "FancyKuwahara"
var sobel: StringName = "Sobel"
var kuwahara: StringName = "Kuwahara"
var eigenvectors: StringName = "EigenVectors"


func get_sampler_uniform(image : RID, binding : int = 0, linear : bool = true) -> RDUniform:
	var uniform : RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	if linear:
		uniform.add_id(linear_sampler)
	else:
		uniform.add_id(nearest_sampler)
	uniform.add_id(image)

	return uniform


func get_image_uniform(image : RID, binding : int = 0) -> RDUniform:
	var uniform : RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(image)

	return uniform


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)


# System notifications, we want to react on the notification that
# alerts us we are about to be destroyed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Freeing our shader will also free any dependents such as the pipeline!
		if sobel_shader.is_valid():
			RenderingServer.free_rid(sobel_shader)
		if kuwahara_shader.is_valid():
			RenderingServer.free_rid(kuwahara_shader)
		if eigenvectors_shader.is_valid():
			RenderingServer.free_rid(eigenvectors_shader)
		if nearest_sampler.is_valid():
			rd.free_rid(nearest_sampler)
		if linear_sampler.is_valid():
			rd.free_rid(linear_sampler)


# Code in this region runs on the rendering thread.
# Compile our shader at initialization.
func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return
	

	var sampler_state : RDSamplerState
	
	sampler_state = RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest_sampler = rd.sampler_create(sampler_state)
	
	sampler_state = RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear_sampler = rd.sampler_create(sampler_state)


	######### SOBEL
	var sobel_shader_file := load("res://addons/pp_magic/compositor_effects/fancy_kuwahara/shaders/generate_sobel.glsl")
	var sobel_shader_spirv: RDShaderSPIRV = sobel_shader_file.get_spirv()
	sobel_shader = rd.shader_create_from_spirv(sobel_shader_spirv)
	if sobel_shader.is_valid():
		sobel_pipeline = rd.compute_pipeline_create(sobel_shader)
	
	##### EIGENVECTORS
	var eigenvectors_shader_file := load("res://addons/pp_magic/compositor_effects/fancy_kuwahara/shaders/eigenvectors.glsl")
	var eigenvectors_shader_spirv: RDShaderSPIRV = eigenvectors_shader_file.get_spirv()
	eigenvectors_shader = rd.shader_create_from_spirv(eigenvectors_shader_spirv)
	if eigenvectors_shader.is_valid():
		eigenvectors_pipeline = rd.compute_pipeline_create(eigenvectors_shader)
	
	###### KUWAHARA
	var kuwahara_shader_file := load("res://addons/pp_magic/compositor_effects/fancy_kuwahara/shaders/kuwahara.glsl")
	var kuwahara_shader_spirv: RDShaderSPIRV = kuwahara_shader_file.get_spirv()
	kuwahara_shader = rd.shader_create_from_spirv(kuwahara_shader_spirv)
	if kuwahara_shader.is_valid():
		kuwahara_pipeline = rd.compute_pipeline_create(kuwahara_shader)


# Called by the rendering thread every frame.
func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if (
		!rd or
		p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or 
		!sobel_pipeline.is_valid() or
		!kuwahara_pipeline.is_valid() or 
		!eigenvectors_pipeline.is_valid()
	):
		return
	
	# Get our render scene buffers object, this gives us access to our render buffers.
	# Note that implementation differs per renderer hence the need for the cast.
	var render_scene_buffers := p_render_data.get_render_scene_buffers()
	if render_scene_buffers:
		# Get our render size, this is the 3D render resolution!
		var size: Vector2i = render_scene_buffers.get_internal_size()
		if size.x == 0 and size.y == 0:
			return
		
		# Calculate x groups("render tiles")
		@warning_ignore("integer_division")
		var x_groups := (size.x - 1) / 8 + 1
		@warning_ignore("integer_division")
		var y_groups := (size.y - 1) / 8 + 1
		var z_groups := 1

		## CREATE TEXTURES
		var usage_bits : int = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		## CREATE SOBEL TEXTURE
		render_scene_buffers.create_texture(
			context, 
			sobel, 
			RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, 
			usage_bits, 
			RenderingDevice.TEXTURE_SAMPLES_1, 
			size, 1, 1, true)
		
		## CREATE EIGENVECTORS TEXTURE
		render_scene_buffers.create_texture(
			context, 
			eigenvectors, 
			RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, 
			usage_bits, 
			RenderingDevice.TEXTURE_SAMPLES_1, 
			size, 1, 1, true)
		
		## CREATE PUSH CONSTANTS
		# Must be aligned to 16 bytes and be in the same order as defined in the shader.
		var sobel_push_constant := PackedFloat32Array([
			size.x,
			size.y,
			RESERVED,
			RESERVED,
		])
		
		var eigenvectors_push_constant := PackedFloat32Array([
			size.x,
			size.y,
			sigma,
			0.0,
		])
		
		var kuwahara_push_constant := PackedFloat32Array([
			size.x,
			size.y,
			float(kuwahara_radius),
			sharpness,
			hardness*10,
			alpha,
			depth_scale,
			float(min_radius)
		])
		
		## RUN SHADERS
		# Loop through views just in case we're doing stereo rendering(VR). No extra cost if this is mono.
		var view_count: int = render_scene_buffers.get_view_count()
		for view in view_count:
			
			var uniform: RDUniform
			
			############## SOBEL
			uniform = get_image_uniform(render_scene_buffers.get_color_layer(view))
			var sobel_in_color_uniform_set := UniformSetCacheRD.get_cache(sobel_shader, 0, [uniform])
			
			uniform = get_image_uniform(render_scene_buffers.get_texture_slice(context, sobel, view, 0, 1, 1))
			var sobel_out_uniform_set := UniformSetCacheRD.get_cache(sobel_shader, 1, [uniform])
			
			# Run Shader
			var compute_list := rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(compute_list, sobel_pipeline)
			rd.compute_list_bind_uniform_set(compute_list, sobel_in_color_uniform_set, 0)
			rd.compute_list_bind_uniform_set(compute_list, sobel_out_uniform_set, 1)
			rd.compute_list_set_push_constant(compute_list, sobel_push_constant.to_byte_array(), sobel_push_constant.size() * 4)
			rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
			rd.compute_list_end()
			
			
			
			#### EIGENVECTORS
			uniform = get_image_uniform(render_scene_buffers.get_texture_slice(context, sobel, view, 0, 1, 1))
			var eigenvectors_in_sobel_uniform_set = UniformSetCacheRD.get_cache(eigenvectors_shader, 1, [uniform])
			
			uniform = get_image_uniform(render_scene_buffers.get_texture_slice(context, eigenvectors, view, 0, 1, 1))
			var eigenvectors_out_uniform_set = UniformSetCacheRD.get_cache(eigenvectors_shader, 1, [uniform])
			
			# Run Shader
			compute_list = rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(compute_list, eigenvectors_pipeline)
			rd.compute_list_bind_uniform_set(compute_list, eigenvectors_in_sobel_uniform_set, 0)
			rd.compute_list_bind_uniform_set(compute_list, eigenvectors_out_uniform_set, 1)
			rd.compute_list_set_push_constant(compute_list, eigenvectors_push_constant.to_byte_array(), eigenvectors_push_constant.size() * 4)
			rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
			rd.compute_list_end()
			
			
			#### KUWAHARA
			uniform = get_image_uniform(render_scene_buffers.get_color_layer(view))
			var kuwahara_color_uniform_set = UniformSetCacheRD.get_cache(kuwahara_shader, 0, [uniform])
			
			uniform = get_image_uniform(render_scene_buffers.get_texture_slice(context, eigenvectors, view, 0, 1, 1))
			var kuwahara_in_eigenvectors_uniform_set = UniformSetCacheRD.get_cache(kuwahara_shader, 1, [uniform])
			
			uniform = get_sampler_uniform(render_scene_buffers.get_depth_layer(view))
			var kuwahara_in_depth_uniform_set = UniformSetCacheRD.get_cache(kuwahara_shader, 2, [uniform])
			
			# Run Shader
			compute_list = rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(compute_list, kuwahara_pipeline)
			rd.compute_list_bind_uniform_set(compute_list, kuwahara_color_uniform_set, 0)
			rd.compute_list_bind_uniform_set(compute_list, kuwahara_in_eigenvectors_uniform_set, 1)
			rd.compute_list_bind_uniform_set(compute_list, kuwahara_in_depth_uniform_set, 2)
			rd.compute_list_set_push_constant(compute_list, kuwahara_push_constant.to_byte_array(), kuwahara_push_constant.size() * 4)
			rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
			rd.compute_list_end()
