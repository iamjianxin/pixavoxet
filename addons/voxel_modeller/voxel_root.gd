tool
extends Path

export var model_index = 0
export var path_length_limit_multiplier = 1.5
export var curve_rotation = true
export var is_mask = false
export var always_render = false
export var remove_jags = true
export var render_inner_outline = true
var voxel_index = 0
var current_model = null
var points = []
var pf1
var pf2
var s

signal transform_pass_complete

func _ready():
	if(!is_in_group("voxel_root")):
		add_to_group("voxel_root",true)
	for model in get_children():
		if(model.is_in_group("voxel_model")):
			if(!visible && !always_render):
				model.visible = false
				for voxel in model.get_children():
					voxel.get_child(0).collision_layer = 2
					if(voxel.is_in_group("voxel_visible")):
						voxel.remove_from_group("voxel_visible")
			elif(visible || always_render):
				model.visible = true
				for voxel in model.get_children():
					voxel.get_child(0).collision_layer = 4
					voxel.add_to_group("voxel_visible")
			if(model.get_position_in_parent() == model_index):
				current_model = model

func _process(delta):
	if(is_mask):
		for model in get_children():
			if(model.is_in_group("voxel_model")):
				for voxel in model.get_children():
					voxel.get_child(0).collision_layer = 8
#					if(voxel.is_in_group("voxel_visible")):
#						voxel.remove_from_group("voxel_visible")
	if(!visible && current_model && current_model.visible && !always_render):
		current_model.visible = false
		for voxel in current_model.get_children():
			voxel.get_child(0).collision_layer = 2
			if(voxel.is_in_group("voxel_visible")):
				voxel.remove_from_group("voxel_visible")
		return
	elif(!visible && !always_render || is_mask):
		return
	if(pf1 == null):
		pf1 = PathFollow.new()
		pf2 = PathFollow.new()
		s = Spatial.new()
		pf1.rotation_mode = PathFollow.ROTATION_NONE
		pf2.rotation_mode = PathFollow.ROTATION_NONE
		pf1.loop = false
		pf2.loop = false
		add_child(pf1)
		add_child(pf2)
		pf1.add_child(s)
	if(curve):
		curve.clear_points()
	points = []
	var paths = []
	var length_dictionary = {}
	var index = 0
	for model in get_children():
		if(model.is_in_group("voxel_model")):
			if(model.get_position_in_parent() != model_index && model.visible || !visible && !always_render):
				model.visible = false
				for voxel in model.get_children():
					voxel.get_child(0).collision_layer = 2
					if(voxel.is_in_group("voxel_visible")):
						voxel.remove_from_group("voxel_visible")
			elif(model.get_position_in_parent() == model_index && !model.visible && visible || always_render):
				model.visible = true
				for voxel in model.get_children():
					voxel.get_child(0).collision_layer = 4
					voxel.add_to_group("voxel_visible")
			if(model.get_position_in_parent() == model_index):
				current_model = model
		elif(model.get_class() == "Position3D"):
			var point = model
			points.append(point)
			if(index == 0):
				point.translation = Vector3()
			var _in = Vector3(0,0,0)
			var _out = Vector3(0,0,0)
			var children = point.get_children()
			if(children.size() >= 1):
				_in = children[0].translation
			if(children.size() >= 2):
				_out = children[1].translation
			if(point.translation != Vector3() || index == 0):
				curve.add_point(point.translation, _in, _out, index)
				length_dictionary[curve.get_point_count()-1] = curve.get_baked_length()
				index += 1
	if(curve && curve.get_point_count() > 1):
		for voxel in current_model.get_children():
			calculate_transform([voxel,length_dictionary])
	else:
		if(current_model && curve && curve.get_point_count() <= 1):
			for voxel in current_model.get_children():
				if(voxel.is_in_group("voxel")):
					voxel.rotation_degrees = Vector3(0,0,0)
					voxel.scale = Vector3(1,1,1)
					voxel.translation = voxel.initial_position

func calculate_transform(data):
	var voxel = data[0]
	var length_dictionary = data[1]
	if(voxel.is_in_group("voxel")):
		s.translation = Vector3(0,0,0)
		s.rotation_degrees = Vector3(0,0,0)
		voxel.rotation_degrees = Vector3(0,0,0)
		voxel.scale = Vector3(1,1,1)
		#voxel.scale = Vector3(1,1,1)
		voxel.translation = voxel.initial_position
		var length = curve.get_baked_length()
		length = min(length, current_model.size.y * path_length_limit_multiplier)
		var position = voxel.initial_position
		s.translation = Vector3(position.z+.5+(position.y*.01),-position.x-.5+(position.y*.01),0)
		var offset = range_lerp(position.y+current_model.pivot.y,current_model.pivot.y-1,current_model.size.y,0,length)
		var offset2 = range_lerp(position.y+current_model.pivot.y+.5,current_model.pivot.y-1,current_model.size.y,0,length)
		pf1.offset = offset
		pf2.offset = offset2
		if(pf1.transform.origin != pf2.translation && curve_rotation):
			pf1.transform = pf1.transform.looking_at(pf2.translation,Vector3(0,1,0))
		voxel.global_transform = s.global_transform
		if(curve_rotation):
			var offset3 = range_lerp(position.y+current_model.pivot.y-1,current_model.pivot.y-1,current_model.size.y,0,length)
			pf2.offset = offset3
			var distance = pf1.translation.distance_to(pf2.translation)
			var idx = get_look_at_point_idx(offset,length_dictionary)
			var p1 = points[idx]
			var p2 = points[idx-1]
			var point_distance = p2.translation.distance_to(p1.translation)
			var self_distance = pf1.translation.distance_to(p2.translation)
			var lerp_amount = range_lerp(self_distance, 0, point_distance, 0, 1)
			var scale_factor = p2.scale.linear_interpolate(p1.scale,lerp_amount)
			if(is_nan(scale_factor.x)):
				scale_factor = Vector3(1,1,1)
			if(voxel.scale != Vector3(scale_factor.x,scale_factor.y,distance + scale_factor.z)):
				voxel.scale = Vector3(scale_factor.x,scale_factor.y,distance + scale_factor.z)

func get_look_at_point_idx(offset,dic):
	for key in dic.keys():
		var length = dic[key]
		if(offset < length):
			return key
	return 0

