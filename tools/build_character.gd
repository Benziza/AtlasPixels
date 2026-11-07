extends SceneTree
## Offline sprite import and SpriteFrames authoring. No movement/controller code.
const FRAME := Vector2i(48, 64)
const PIXEL := 2
const DIRECTIONS := ["down", "left", "right", "up"]
const OUTPUT := "res://assets/characters/"

func _initialize() -> void:
	call_deferred("build")

func visible_bounds(img: Image, area: Rect2i = Rect2i()) -> Rect2i:
	if not area.has_area():
		area = Rect2i(Vector2i.ZERO, img.get_size())
	var lo := area.end
	var hi := area.position - Vector2i.ONE
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if img.get_pixel(x, y).a >= 0.5:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	assert(hi.x >= lo.x and hi.y >= lo.y, "Empty sprite cell")
	return Rect2i(lo, hi - lo + Vector2i.ONE)

func add_owned(parent: Node, child: Node, owner_: Node) -> void:
	parent.add_child(child)
	child.owner = owner_

func save_scene(root_: Node, path: String) -> void:
	var scene := PackedScene.new()
	assert(scene.pack(root_) == OK)
	assert(ResourceSaver.save(scene, path) == OK)

func build() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path("res://assets/source/farmer-moroccan.png"))
	assert(source != null)
	source.convert(Image.FORMAT_RGBA8)
	var cells: Array[Image] = []
	var bounds: Array[Rect2i] = []
	var max_height := 0
	for y in 4:
		for x in 4:
			var a := Vector2i(roundi(float(x * source.get_width()) / 4), roundi(float(y * source.get_height()) / 4))
			var b := Vector2i(roundi(float((x + 1) * source.get_width()) / 4), roundi(float((y + 1) * source.get_height()) / 4))
			var cell := source.get_region(Rect2i(a, b - a))
			var bound := visible_bounds(cell)
			max_height = maxi(max_height, bound.size.y)
			cells.append(cell)
			bounds.append(bound)
	var sheet := Image.create(FRAME.x * 4, FRAME.y * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	var logical := FRAME / PIXEL
	var scale_ := float(logical.y - 2) / max_height
	for i in cells.size():
		var cell := cells[i]
		var bound := bounds[i]
		# Align by hat center and feet, not moving arms/legs; one scale for all frames.
		var head := visible_bounds(cell, Rect2i(bound.position, Vector2i(bound.size.x, maxi(1, bound.size.y / 3))))
		var center_x := head.position.x + float(head.size.x) / 2
		var sprite := cell.get_region(bound)
		sprite.resize(maxi(1, roundi(bound.size.x * scale_)), maxi(1, roundi(bound.size.y * scale_)), Image.INTERPOLATE_NEAREST)
		var frame := Image.create(logical.x, logical.y, false, Image.FORMAT_RGBA8)
		frame.fill(Color.TRANSPARENT)
		var offset := Vector2i(roundi(logical.x / 2.0 - (center_x - bound.position.x) * scale_), logical.y - 1 - sprite.get_height())
		assert(offset.x >= 0 and offset.x + sprite.get_width() <= logical.x, "Sprite exceeds frame")
		frame.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), offset)
		frame.resize(FRAME.x, FRAME.y, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME), Vector2i(i % 4, i / 4) * FRAME)
	assert(sheet.save_png(OUTPUT + "farmer.png") == OK)
	var texture := ImageTexture.create_from_image(sheet)
	texture.take_over_path(OUTPUT + "farmer.png")
	var frames := SpriteFrames.new()
	frames.resource_name = "Moroccan Farmer"
	frames.remove_animation("default")
	for row in 4:
		var idle := StringName("idle_" + DIRECTIONS[row])
		var walk := StringName("walk_" + DIRECTIONS[row])
		frames.add_animation(idle)
		frames.add_animation(walk)
		frames.set_animation_speed(idle, 1.0)
		frames.set_animation_speed(walk, 7.0)
		frames.set_animation_loop(idle, true)
		frames.set_animation_loop(walk, true)
		var row_frames: Array[AtlasTexture] = []
		for column in 4:
			var tex := AtlasTexture.new()
			tex.atlas = texture
			tex.region = Rect2(Vector2(column * FRAME.x, row * FRAME.y), Vector2(FRAME))
			row_frames.append(tex)
		frames.add_frame(idle, row_frames[0])
		for column in [1, 2, 3, 2]:
			frames.add_frame(walk, row_frames[column])
	assert(ResourceSaver.save(frames, OUTPUT + "farmer_frames.tres") == OK)
	frames.take_over_path(OUTPUT + "farmer_frames.tres")

	var actor := Node2D.new()
	actor.name = "Farmer"
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.set_meta("frame_size", FRAME)
	actor.set_meta("pivot", "feet")
	actor.set_meta("description", "Farmer in a sand djellaba, red tarbouche and yellow balgha. Visual resource only; no controller or collisions.")
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = frames
	sprite.animation = "idle_down"
	sprite.centered = false
	sprite.position = Vector2(-FRAME.x / 2.0, -FRAME.y + PIXEL)
	add_owned(actor, sprite, actor)
	save_scene(actor, "res://characters/farmer.tscn")

	actor.free()
	print("Built farmer: 16 atlas frames, 8 directional animations, feet pivot. No gameplay scripts.")
	quit()
