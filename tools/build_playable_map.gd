extends SceneTree
## Offline authoring: turns placed props into depth-sorted obstacles.
const TILE := 32
const WATER_STEP := 8
const WORLD_SIZE := Vector2i(1280, 896)
const DECOR_ONLY := ["footbridge", "wildflowers"]
var scene_root: Node2D
var world: Node2D
var art: Node2D
var tiles: TileSet
var manifest: Dictionary
var images: Dictionary = {}
var water_cells: Dictionary = {}
var obstacle_count := 0

func _initialize() -> void:
	call_deferred("build")

func own(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = scene_root

func rectangle(body: StaticBody2D, rect: Rect2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.position = rect.get_center()
	own(body, collision)

func make_body(name_: String) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = name_
	body.collision_layer = 1
	body.collision_mask = 2
	return body

func pattern_rect(name_: String) -> Rect2i:
	var values: Array = manifest.patterns[name_].atlas_rect_tiles
	return Rect2i(int(values[0]) * TILE, int(values[1]) * TILE, int(values[2]) * TILE, int(values[3]) * TILE)

func pattern_image(name_: String) -> Image:
	var source_id := int(manifest.patterns[name_].source_id)
	if not images.has(source_id):
		images[source_id] = (tiles.get_source(source_id) as TileSetAtlasSource).texture.get_image()
	return images[source_id].get_region(pattern_rect(name_))

func visible_bounds(image_: Image) -> Rect2:
	var lo := image_.get_size()
	var hi := -Vector2i.ONE
	for y in image_.get_height():
		for x in image_.get_width():
			if image_.get_pixel(x, y).a >= 0.5:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	assert(hi.x >= lo.x and hi.y >= lo.y)
	return Rect2(Vector2(lo), Vector2(hi - lo + Vector2i.ONE))

func erase_art(placement: Dictionary) -> void:
	var layer := art.get_node(placement.layer) as TileMapLayer
	var size_ := pattern_rect(placement.pattern).size / TILE
	var pos := Vector2i(int(placement.cell[0]), int(placement.cell[1]))
	for y in size_.y:
		for x in size_.x:
			layer.erase_cell(pos + Vector2i(x, y))

func make_obstacle(placement: Dictionary) -> void:
	var name_: String = placement.pattern
	var bounds := visible_bounds(pattern_image(name_))
	var anchor := Vector2(bounds.get_center().x, bounds.end.y - 2)
	var body := make_body(name_.to_pascal_case() + str(obstacle_count))
	body.position = Vector2(float(placement.cell[0]) * TILE, float(placement.cell[1]) * TILE) + anchor
	body.set_meta("pattern", name_)
	body.set_meta("cell", Vector2i(int(placement.cell[0]), int(placement.cell[1])))
	own(world, body)
	var texture := AtlasTexture.new()
	var source := tiles.get_source(int(manifest.patterns[name_].source_id)) as TileSetAtlasSource
	texture.atlas = source.texture
	texture.region = Rect2(pattern_rect(name_))
	var sprite := Sprite2D.new()
	sprite.name = "Artwork"
	sprite.centered = false
	sprite.position = -anchor
	sprite.texture = texture
	own(body, sprite)
	var footprint: Rect2
	match name_:
		"farmhouse", "hanout":
			footprint = Rect2(bounds.position.x + 6, bounds.position.y + bounds.size.y * 0.46, bounds.size.x - 12, bounds.size.y * 0.54 - 2)
		"well":
			footprint = Rect2(bounds.position.x + 4, bounds.end.y - 34, bounds.size.x - 8, 32)
		"olive_tree", "fig_tree":
			# The canopy is overhead; only the trunk/root area is solid.
			footprint = Rect2(anchor.x - 13, anchor.y - 18, 26, 18)
		"fence_vertical":
			footprint = Rect2(bounds.get_center().x - 5, bounds.position.y + 3, 10, bounds.size.y - 5)
		"fence_horizontal":
			footprint = Rect2(bounds.position.x + 2, bounds.end.y - 13, bounds.size.x - 4, 12)
		"flowering_hedge":
			footprint = Rect2(bounds.position.x + 4, bounds.end.y - 13, bounds.size.x - 8, 12)
		"sluice_gate":
			footprint = Rect2(bounds.position.x + 3, bounds.end.y - 15, bounds.size.x - 6, 14)
		_:
			footprint = Rect2(bounds.position.x + 2, bounds.position.y + bounds.size.y * 0.45, maxf(6, bounds.size.x - 4), bounds.size.y * 0.55 - 1)
	rectangle(body, Rect2(footprint.position - anchor, footprint.size))
	body.set_meta("footprint_local", Rect2(footprint.position - anchor, footprint.size))
	body.add_to_group("obstacles", true)
	obstacle_count += 1
	erase_art(placement)

func add_water(placement: Dictionary) -> void:
	var image_ := pattern_image(placement.pattern)
	var origin := Vector2i(int(placement.cell[0]), int(placement.cell[1])) * TILE
	for y in range(0, image_.get_height(), WATER_STEP):
		for x in range(0, image_.get_width(), WATER_STEP):
			var solid := false
			for offset in [Vector2i(2, 2), Vector2i(5, 2), Vector2i(2, 5), Vector2i(5, 5)]:
				if image_.get_pixel(x + offset.x, y + offset.y).a >= 0.5:
					solid = true
			if solid:
				water_cells[(origin + Vector2i(x, y)) / WATER_STEP] = true

func build_water() -> void:
	# Bridge decks carve walkable openings through both water and bank colliders.
	for placement: Dictionary in manifest.placements:
		if placement.pattern != "footbridge":
			continue
		var origin := Vector2i(int(placement.cell[0]), int(placement.cell[1])) * TILE / WATER_STEP
		var size_ := pattern_rect("footbridge").size / WATER_STEP
		for y in size_.y:
			for x in size_.x:
				water_cells.erase(origin + Vector2i(x, y))
	var body := make_body("SaqyaBanks")
	body.add_to_group("water_obstacles", true)
	own(scene_root, body)
	var pending: Dictionary = {}
	var rects: Array[Rect2i] = []
	for y in range(WORLD_SIZE.y / WATER_STEP):
		var runs: Dictionary = {}
		var x := 0
		while x < WORLD_SIZE.x / WATER_STEP:
			if not water_cells.has(Vector2i(x, y)):
				x += 1
				continue
			var start := x
			while water_cells.has(Vector2i(x, y)):
				x += 1
			var key := Vector2i(start, x - start)
			var rect := Rect2i(start, y, x - start, 1)
			if pending.has(key):
				rect = pending[key]
				rect.size.y += 1
			runs[key] = rect
		for key: Vector2i in pending:
			if not runs.has(key):
				rects.append(pending[key])
		pending = runs
	for rect: Rect2i in pending.values():
		rects.append(rect)
	for rect in rects:
		rectangle(body, Rect2(Vector2(rect.position * WATER_STEP), Vector2(rect.size * WATER_STEP)))
	body.set_meta("bridge_openings", 3)
	body.set_meta("collision_rectangles", rects.size())

func build() -> void:
	# Verify key constants against this engine, rather than relying on guessed codes.
	var expected := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN]}
	for action: String in expected:
		var events := InputMap.action_get_events(action)
		assert(events.size() == 2, "Missing movement input")
		for i in 2:
			assert(events[i].physical_keycode == expected[action][i], "Wrong input mapping for " + action)
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://maps/douar_farm.json"))
	assert(manifest.has("placements"), "Run build_resources.gd first")
	tiles = load("res://assets/tilesets/moroccan_farm.tres")
	scene_root = Node2D.new()
	scene_root.name = "DouarFarmPlayable"
	scene_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene_root.set_meta("description", "Walkable Moroccan farm: movement, solid obstacles and three usable bridges.")
	scene_root.set_meta("map_size_pixels", WORLD_SIZE)
	art = load("res://maps/douar_farm.tscn").instantiate()
	art.name = "Terrain"
	# This copy has lifted objects removed, so save independent editable layer data.
	art.scene_file_path = ""
	own(scene_root, art)
	for layer in art.get_children():
		layer.owner = scene_root
	world = Node2D.new()
	world.name = "DepthSort"
	world.y_sort_enabled = true
	own(scene_root, world)
	for placement: Dictionary in manifest.placements:
		if placement.layer == "Saqya":
			add_water(placement)
		elif placement.pattern not in DECOR_ONLY:
			make_obstacle(placement)
	build_water()
	var bounds := make_body("MapBoundary")
	own(scene_root, bounds)
	rectangle(bounds, Rect2(-32, -32, 32, WORLD_SIZE.y + 64))
	rectangle(bounds, Rect2(WORLD_SIZE.x, -32, 32, WORLD_SIZE.y + 64))
	rectangle(bounds, Rect2(0, -32, WORLD_SIZE.x, 32))
	rectangle(bounds, Rect2(0, WORLD_SIZE.y, WORLD_SIZE.x, 32))
	var player := load("res://characters/player.tscn").instantiate() as CharacterBody2D
	player.position = Vector2(864, 352)
	own(world, player)
	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = player.position
	own(scene_root, spawn)
	var scene := PackedScene.new()
	assert(scene.pack(scene_root) == OK)
	assert(ResourceSaver.save(scene, "res://maps/douar_farm_playable.tscn") == OK)
	print("Built playable farm: %d depth-sorted obstacles; 3 bridge openings; player at %s." % [obstacle_count, player.position])
	scene_root.free()
	quit()
