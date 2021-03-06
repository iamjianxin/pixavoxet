tool
extends Sprite3D

export var export_directory = "res://renders"
export var frame_size = 32
export var outline_color = Color(0,0,0,1)
export var remove_jags = false
export var render_inner_outline = true
export var inner_outline_intensity = .5
export var inner_outline_depth_check = 2.0
export var inner_outline_depth_intensity = false
export var normal_map_preview = false
export(NodePath) var camera_path

var frame_count = 0
var last_position = 0
var last_image = null
var rendered_frames = {}


func _process(delta):
	$Viewport.size = Vector2(frame_size,frame_size)
	$Viewport/Sideview.size = frame_size
	if(visible):
		outline_pass()

func get_visible_voxels():
	var camera = get_node(camera_path)
	var h = frame_size
	var w = frame_size
	var _voxels = []
	for x in range(0,w+1):
		for y in range(0,h+1):
			var pos = Vector2(x,y)
			var ray_origin = camera.project_ray_origin(pos)
			var ray_direction = camera.project_ray_normal(pos)
			var from = ray_origin - Vector3(.5,.25,.5)
			var to = ray_origin + ray_direction * 1000000.0
			var state = camera.get_world().direct_space_state
			var hit = state.intersect_ray(from,to,[],4)
			if(!hit.empty()):
				if(hit.collider.get_parent().is_visible_in_tree() || hit.collider.get_parent().get_parent().get_parent().always_render):
					_voxels.append(hit.collider.get_parent())
	return _voxels

func outline_pass():
	var camera = get_node(camera_path)
	var image = Image.new()
	image.create(frame_size,frame_size,false,5)
	var h = frame_size
	var w = frame_size
	image.lock()
	var image_dic = {}
	var outline = []
	for x in range(0,w+1):
		for y in range(0,h+1):
			var pos = Vector2(x,y)
			var ray_origin = camera.project_ray_origin(pos)
			var ray_direction = camera.project_ray_normal(pos)
			var from = ray_origin - Vector3(.5,.25,.5)
			var to = ray_origin + ray_direction * 1000000.0
			var state = camera.get_world().direct_space_state
			var hit = state.intersect_ray(from,to,[],12)
			if(!hit.empty()):
				if(hit.collider.get_parent().is_visible_in_tree() && !hit.collider.get_parent().get_parent().get_parent().is_mask || hit.collider.get_parent().get_parent().get_parent().always_render):
					var color = hit.collider.get_parent().material_override.albedo_color
					if(normal_map_preview):
						var xyz = hit.collider.get_parent().translation + hit.collider.get_parent().get_parent().translation + hit.collider.get_parent().get_parent().get_parent().translation
						xyz = hit.position
						xyz.x = xyz.x*xyz.x
						#xyz.y = stepify(xyz.y,1)
						#xyz.z = stepify(xyz.z,1)
						#print(hit.position)
						color.r = range_lerp(xyz.z,-14,14,0.0,1.0)
						color.g = range_lerp(xyz.y,0,32,0.0,1.0)
						color.b = range_lerp(xyz.x,-5,5,0.0,1.0)
					image.set_pixel(pos.x,h-pos.y,color)
					image_dic[Vector2(pos.x,h-pos.y)] = hit.collider.get_parent().get_parent().get_parent()
					if(hit.collider.get_parent().get_parent().get_parent().render_inner_outline && render_inner_outline && !normal_map_preview):
						var checks = [Vector2(x+1,y), Vector2(x-1,y), Vector2(x,y+1), Vector2(x,y-1)]
						for p in checks:
							ray_origin = camera.project_ray_origin(p)
							ray_direction = camera.project_ray_normal(p)
							from = ray_origin - Vector3(.5,.25,.5)
							to = ray_origin + ray_direction * 1000000.0
							var hit2 = state.intersect_ray(from,to,[],4)
							if(!hit2.empty()):
								if(hit2.collider.get_parent().is_visible_in_tree() || hit.collider.get_parent().get_parent().get_parent().always_render):
									if(hit.collider.get_parent().get_parent() != hit2.collider.get_parent().get_parent() && hit.position.x - hit2.position.x > inner_outline_depth_check ||
										hit.collider.get_parent() != hit2.collider.get_parent() && hit.position.x - hit2.position.x > inner_outline_depth_check + 1):
										var c = image.get_pixel(pos.x,h-pos.y)
										if(c.a != 0):
											var intensity = inner_outline_intensity
											if(inner_outline_depth_intensity):
												var delta = hit.position.x - hit2.position.x
												intensity = intensity * delta
											image.set_pixel(pos.x,h-pos.y,c.darkened(intensity))
											break
	if(remove_jags):
		var remove = []
		for x in range(0,w):
			for y in range(0,h):
				var c = image.get_pixel(x,y)
				var bordering = 0
				var u; var d; var l; var r;
				if(y-1 >= 0):
					u = image.get_pixel(x,y-1)
					if(u.a != 0):
						bordering += 1
				if(y+1 < h):
					d = image.get_pixel(x,y+1)
					if(d.a != 0):
						bordering += 1
				if(x-1 >= 0):
					l = image.get_pixel(x-1,y)
					if(l.a != 0):
						bordering += 1
				if(x+1 < w):
					r = image.get_pixel(x+1,y)
					if(r.a != 0):
						bordering += 1
				if(bordering < 2 && image_dic.has(Vector2(x,y)) && image_dic[Vector2(x,y)].remove_jags || bordering < 2 && !image_dic.has(Vector2(x,y))):
					remove.append(Vector2(x,y))
		for xy in remove:
			image.set_pixel(xy.x,xy.y,Color(0,0,0,0))
	if(!normal_map_preview):
		for x in range(0,w):
			for y in range(0,h):
				var c = image.get_pixel(x,y)
				if(c.a == 0):
					var bordering = 0
					var u; var d; var l; var r;
					if(y-1 >= 0):
						u = image.get_pixel(x,y-1)
						if(u.a != 0):
							bordering += 1
					if(y+1 < h):
						d = image.get_pixel(x,y+1)
						if(d.a != 0):
							bordering += 1
					if(x-1 >= 0):
						l = image.get_pixel(x-1,y)
						if(l.a != 0):
							bordering += 1
					if(x+1 < w):
						r = image.get_pixel(x+1,y)
						if(r.a != 0):
							bordering += 1
					if(u && u.a != 0 || d && d.a != 0 || l && l.a != 0 || r && r.a != 0 || bordering > 0):
						outline.append(Vector2(x,y))
				else:
					if(x == 0 || x == w-1 || y == h-1):
						outline.append(Vector2(x,y))
	for xy in outline:
		image.set_pixel(xy.x,xy.y,outline_color)
	image.flip_y()
	image.unlock()
	var tex = ImageTexture.new()
	tex.create_from_image(image,2)
	texture = tex
#	var frame = float($"../AnimationPlayer".current_animation_position)
#	rendered_frames[frame] = image
	return image

func save_start(save_all):
	var animation_player = get_tree().get_nodes_in_group("frame_by_frame_helper")[0]
	animation_player.stop(false)
	animation_player.rendering = true
	yield(get_tree(),"idle_frame")
	var animation_list = animation_player.get_animation_list()
	if(save_all):
		for anim in animation_list:
			rendered_frames = {}
			animation_player.play = false
			animation_player.wait = 0.0
			animation_player.next_frame = false
			animation_player.rendering = false
			animation_player.elapsed = 0.0
			animation_player.animation_name = anim
			animation_player.play(anim)
			animation_player.playback_speed = 0
			animation_player.frame = animation_player.current_animation_length - animation_player.frame_step
			animation_player.next_frame()
			animation_player.update()
			for i in range(0,2):
				yield(get_tree(),"idle_frame")
			for i in range(0, animation_player.current_animation_length / animation_player.frame_step):
				save(anim, animation_player)
				animation_player.next_frame()
				yield(get_tree(),"idle_frame")
			save_spritesheet(animation_player, anim)
			frame_count = 0
	else:
		rendered_frames = {}
		animation_player.play(animation_player.animation_name)
		animation_player.playback_speed = 0
		animation_player.frame = animation_player.current_animation_length - animation_player.frame_step
		animation_player.next_frame()
		animation_player.update()
		for i in range(0,2):
			yield(get_tree(),"idle_frame")
		for i in range(0, animation_player.current_animation_length / animation_player.frame_step):
			save(animation_player.animation_name, animation_player)
			animation_player.next_frame()
			yield(get_tree(),"idle_frame")
		save_spritesheet(animation_player, animation_player.animation_name)
		frame_count = 0
	animation_player.stop(false)
	animation_player.rendering = false
	yield(get_tree(),"idle_frame")

func save_spritesheet(player,animation_name):
	var dir = Directory.new()
	var directories = export_directory
	dir.make_dir_recursive(directories)
	var colrow = ceil(sqrt(player.current_animation_length / player.frame_step))
	var xinc = rendered_frames[0].get_width()
	var yinc = rendered_frames[0].get_height()
	var w = rendered_frames[0].get_width() * colrow
	var h = rendered_frames[0].get_height() * colrow
	var image = Image.new()
	image.create(w,h,false,Image.FORMAT_RGBA8)
	var i = 0
	for y in range(0,colrow):
		for x in range(0,colrow):
			if(i < rendered_frames.keys().size()):
				image.blit_rect(rendered_frames[i],Rect2(0,0, xinc, yinc),Vector2(x * xinc, y * yinc))
			i += player.frame_step
	if(normal_map_preview):
		animation_name += "_normal"
	print("saving: ", directories + "/" + animation_name +".png")
	image.save_png(directories + "/" + animation_name +".png")

func save(name, player):
	var image = outline_pass()
	#image.save_png(directories + "/" +name + "_" + str(frame_count)+".png")
	rendered_frames[frame_count] = image
	frame_count += player.frame_step