extends SceneTree
## Rebuild the approved village layout. The player's farmhouse stays on the farm.
const Layout = preload("res://maps/world_layout.gd")
var scene_root: Node2D
var depth: Node2D
var tiles: TileSet
var patterns: Dictionary
var paving: TileMapLayer

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

func text_label(parent: Node, name_: String, text: String, rect: Rect2, font_size: int) -> void:
	var label := Label.new()
	label.name = name_
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.language = "ar_MA"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_override("font", load("res://assets/ui/fonts/readex-pro.ttf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("5b2b19"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	own(parent, label)
	label.position = rect.position
	label.size = rect.size

func prop(name_: String, pattern: String, cell: Vector2i, solid: bool = true) -> StaticBody2D:
	assert(pattern != "farmhouse", "The player's unique home must not be reused in the village.")
	var spec: Dictionary = patterns[pattern]
	var rect: Array = spec.atlas_rect_tiles
	var region := Rect2(rect[0] * 32, rect[1] * 32, rect[2] * 32, rect[3] * 32)
	var texture := AtlasTexture.new()
	texture.atlas = (tiles.get_source(int(spec.source_id)) as TileSetAtlasSource).texture
	texture.region = region
	var bounds := Rect2(texture.atlas.get_image().get_region(Rect2i(region)).get_used_rect())
	var anchor := Vector2(bounds.get_center().x, bounds.end.y - 2)
	var body := StaticBody2D.new()
	body.name = name_
	body.position = Vector2(cell * 32) + anchor
	body.collision_mask = 2
	body.set_meta("pattern", pattern)
	if solid:
		body.add_to_group("square_obstacles", true)
	own(depth, body)
	var sprite := Sprite2D.new()
	sprite.name = "Artwork"
	sprite.centered = false
	sprite.position = -anchor
	sprite.texture = texture
	own(body, sprite)
	var footprint := Rect2(bounds.position.x + 2, bounds.position.y + bounds.size.y * 0.45, bounds.size.x - 4, bounds.size.y * 0.55 - 1)
	if pattern == "hanout":
		footprint = Rect2(bounds.position.x + 6, bounds.position.y + bounds.size.y * 0.46, bounds.size.x - 12, bounds.size.y * 0.54 - 2)
	elif pattern in ["olive_tree", "fig_tree"]:
		footprint = Rect2(anchor.x - 13, anchor.y - 18, 26, 18)
	elif pattern == "well":
		footprint = Rect2(bounds.position.x + 4, bounds.end.y - 34, bounds.size.x - 8, 32)
	var local_rect := Rect2(footprint.position - anchor, footprint.size)
	body.set_meta("footprint_local", local_rect)
	if solid:
		rectangle(body, local_rect)
	return body

func village_prop(name_: String, filename: String, cell: Vector2i, footprints: Array[Rect2], display_size: Vector2 = Vector2.ZERO) -> StaticBody2D:
	var texture := load("res://assets/village/" + filename) as Texture2D
	assert(texture != null)
	var size_ := texture.get_size() if display_size == Vector2.ZERO else display_size
	var anchor := Vector2(size_.x / 2.0, size_.y - 2)
	var body := StaticBody2D.new()
	body.name = name_
	body.position = Vector2(cell * 32) + anchor
	body.collision_mask = 2
	body.set_meta("pattern", filename.get_basename())
	body.add_to_group("square_obstacles", true)
	own(depth, body)
	var sprite := Sprite2D.new()
	sprite.name = "Artwork"
	sprite.centered = false
	sprite.position = -anchor
	sprite.texture = texture
	sprite.scale = size_ / texture.get_size()
	own(body, sprite)
	for footprint in footprints:
		rectangle(body, Rect2(footprint.position - anchor, footprint.size))
	body.set_meta("footprint_local", Rect2(footprints[0].position - anchor, footprints[0].size))
	return body

func soil_patch(rect: Rect2i, crop: String) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var uv := Vector2i(0 if x == rect.position.x else (2 if x == rect.end.x - 1 else 1), 0 if y == rect.position.y else (2 if y == rect.end.y - 1 else 1))
			paving.set_cell(Vector2i(x, y), 5, uv)
			if y > rect.position.y and y < rect.end.y - 1 and x > rect.position.x and x < rect.end.x - 1:
				prop("Crop%d_%d" % [x, y], crop, Vector2i(x, y), false)

func build() -> void:
	tiles = load("res://assets/tilesets/moroccan_farm.tres")
	patterns = JSON.parse_string(FileAccess.get_file_as_string("res://maps/douar_farm.json")).patterns
	scene_root = Node2D.new()
	scene_root.name = "DouarSquare"
	scene_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene_root.set_script(load("res://maps/douar_square.gd"))
	scene_root.set_meta("map_size_pixels", Layout.SQUARE_SIZE)
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tiles
	ground.collision_enabled = false
	own(scene_root, ground)
	paving = TileMapLayer.new()
	paving.name = "Courtyard"
	paving.tile_set = tiles
	paving.collision_enabled = false
	own(scene_root, paving)
	var dirt: Dictionary = {}
	for rect in [Rect2i(0, 14, 40, 3), Rect2i(5, 8, 3, 7), Rect2i(13, 8, 3, 7), Rect2i(30, 8, 3, 7), Rect2i(19, 0, 3, 13), Rect2i(19, 17, 3, 11), Rect2i(3, 23, 34, 3), Rect2i(1, 9, 7, 5), Rect2i(11, 9, 6, 4), Rect2i(29, 9, 8, 5), Rect2i(4, 16, 5, 10), Rect2i(29, 16, 5, 10)]:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				dirt[Vector2i(x, y)] = true
	var map_cells := Layout.SQUARE_SIZE / 32
	for y in range(map_cells.y):
		for x in range(map_cells.x):
			var cell := Vector2i(x, y)
			var uv := Vector2i(1, 1)
			if dirt.has(cell):
				uv = Vector2i(1, 3) if (x * 23 + y * 17) % 29 == 0 else Vector2i(3, 0)
			else:
				var n := dirt.has(cell + Vector2i.UP)
				var s := dirt.has(cell + Vector2i.DOWN)
				var w := dirt.has(cell + Vector2i.LEFT)
				var e := dirt.has(cell + Vector2i.RIGHT)
				uv = Vector2i(0 if w else (2 if e else 1), 0 if n else (2 if s else 1))
				if not (n or s or w or e) and (x * 23 + y * 11) % 13 == 0:
					uv = Vector2i(0, 3)
			ground.set_cell(cell, 0, uv)
			if y in range(11, 19):
				var inset := 2 if y in [11, 18] else (1 if y in [12, 17] else 0)
				if x >= 14 + inset and x < 26 - inset:
					paving.set_cell(cell, 0, Vector2i(3, 3))
	depth = Node2D.new()
	depth.name = "DepthSort"
	depth.y_sort_enabled = true
	own(scene_root, depth)
	var bakery := village_prop("Bakery", "bakery.tres", Vector2i(2, 2), [Rect2(8, 100, 176, 122)], Vector2(192, 224))
	bakery.position.x += 16
	text_label(bakery, "Name", "Bakery", Rect2(-50, -138, 92, 28), 14)
	village_prop("NeighborBlue", "neighbor-house-blue.png", Vector2i(26, 2), [Rect2(4, 100, 76, 100), Rect2(80, 96, 124, 88), Rect2(118, 184, 102, 22)])
	village_prop("NeighborEarth", "neighbor-house-earth.png", Vector2i(2, 17), [Rect2(6, 94, 70, 138), Rect2(28, 145, 174, 90)])
	var cafe := village_prop("Cafe", "village-cafe.png", Vector2i(28, 17), [Rect2(6, 94, 242, 110)])
	var grocer := village_prop("Greengrocer", "greengrocer.png", Vector2i(11, 2), [Rect2(4, 100, 184, 106)])
	text_label(cafe.get_node("Artwork"), "Name", "Village cafe", Rect2(32, 72, 76, 22), 14)
	text_label(grocer.get_node("Artwork"), "Name", "Greengrocer", Rect2(24, 84, 76, 18), 11)
	prop("Well", "well", Vector2i(34, 10))
	village_prop("Fountain", "fountain.png", Vector2i(18, 13), [Rect2(8, 44, 112, 66)])
	for x in range(0, map_cells.x, 2):
		prop("Channel%d" % x, "saqya_horizontal", Vector2i(x, 26), false)
	for x in range(19, 22):
		prop("Bridge%d" % x, "footbridge", Vector2i(x, 26), false)
	var water := StaticBody2D.new()
	water.name = "ChannelWater"
	water.collision_mask = 2
	own(scene_root, water)
	# The three existing footbridge sprites leave a 96px walkable crossing.
	rectangle(water, Rect2(0, 844, 608, 40))
	rectangle(water, Rect2(704, 844, Layout.SQUARE_SIZE.x - 704, 40))
	var tree_cells := [Vector2i(-1, -3), Vector2i(3, -3), Vector2i(13, -3), Vector2i(32, -3), Vector2i(36, -3), Vector2i(-2, 3), Vector2i(35, 3), Vector2i(37, 9), Vector2i(-2, 10), Vector2i(11, 15), Vector2i(24, 15), Vector2i(35, 20)]
	for i in tree_cells.size():
		prop("Tree%d" % i, "olive_tree" if i % 2 == 0 else "fig_tree", tree_cells[i])
	for cell in [Vector2i(4, 9), Vector2i(5, 9), Vector2i(10, 9), Vector2i(16, 9), Vector2i(24, 8), Vector2i(35, 9), Vector2i(9, 22), Vector2i(26, 22)]:
		prop("Jar%d_%d" % [cell.x, cell.y], "terracotta_jar", cell)
	for cell in [Vector2i(6, 9), Vector2i(11, 9)]:
		prop("Basket%d" % cell.x, "mint_basket", cell)
	prop("TomatoCrate", "tomato_crate", Vector2i(12, 9))
	prop("Chest", "chest", Vector2i(9, 9))
	for cell in [Vector2i(13, 9), Vector2i(23, 9), Vector2i(14, 20), Vector2i(16, 21), Vector2i(25, 20), Vector2i(34, 19)]:
		prop("Hedge%d_%d" % [cell.x, cell.y], "flowering_hedge", cell, false)
	for cell in [Vector2i(5, 12), Vector2i(17, 4), Vector2i(16, 8), Vector2i(24, 5), Vector2i(33, 7), Vector2i(10, 17), Vector2i(27, 19)]:
		prop("Flowers%d_%d" % [cell.x, cell.y], "wildflowers", cell, false)
	soil_patch(Rect2i(10, 21, 7, 4), "mint_mature")
	soil_patch(Rect2i(23, 21, 5, 4), "tomato_ripe")
	for x in range(10, 17, 2):
		prop("MintFence%d" % x, "fence_horizontal", Vector2i(x, 20))
	for x in range(23, 28, 2):
		prop("TomatoFence%d" % x, "fence_horizontal", Vector2i(x, 20))
	prop("MintSideFence", "fence_vertical", Vector2i(17, 22))
	prop("TomatoSideFence", "fence_vertical", Vector2i(22, 22))
	var route_sign: StaticBody2D = load("res://maps/route_sign.tscn").instantiate()
	route_sign.name = "ToFarm"
	route_sign.position = Vector2(80, 440)
	route_sign.destination = "Farm"
	route_sign.direction = -1
	own(depth, route_sign)
	var boundary := StaticBody2D.new()
	boundary.name = "MapBoundary"
	boundary.collision_mask = 2
	own(scene_root, boundary)
	rectangle(boundary, Rect2(-32, -32, 32, Layout.SQUARE_SIZE.y + 64))
	rectangle(boundary, Rect2(Layout.SQUARE_SIZE.x, -32, 32, Layout.SQUARE_SIZE.y + 64))
	rectangle(boundary, Rect2(0, -32, Layout.SQUARE_SIZE.x, 32))
	rectangle(boundary, Rect2(0, Layout.SQUARE_SIZE.y, Layout.SQUARE_SIZE.x, 32))
	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Layout.SQUARE_SPAWN
	own(scene_root, spawn)
	var packed := PackedScene.new()
	assert(packed.pack(scene_root) == OK)
	assert(ResourceSaver.save(packed, "res://maps/douar_square.tscn") == OK)
	print("Built douar square: ", map_cells, ", two unique homes, three shops, and no player-house copy.")
	scene_root.free()
	quit()
