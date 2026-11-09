extends SceneTree
## Author the small square from the existing farm atlas; no new bitmap assets.
const Layout = preload("res://maps/world_layout.gd")
var scene_root: Node2D
var depth: Node2D
var tiles: TileSet
var patterns: Dictionary

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

func prop(name_: String, pattern: String, cell: Vector2i) -> StaticBody2D:
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
	body.add_to_group("square_obstacles", true)
	own(depth, body)
	var sprite := Sprite2D.new()
	sprite.name = "Artwork"
	sprite.centered = false
	sprite.position = -anchor
	sprite.texture = texture
	own(body, sprite)
	var footprint := Rect2(bounds.position.x + 2, bounds.position.y + bounds.size.y * 0.45, bounds.size.x - 4, bounds.size.y * 0.55 - 1)
	if pattern in ["hanout", "farmhouse"]:
		footprint = Rect2(bounds.position.x + 6, bounds.position.y + bounds.size.y * 0.46, bounds.size.x - 12, bounds.size.y * 0.54 - 2)
	elif pattern in ["olive_tree", "fig_tree"]:
		footprint = Rect2(anchor.x - 13, anchor.y - 18, 26, 18)
	elif pattern == "well":
		footprint = Rect2(bounds.position.x + 4, bounds.end.y - 34, bounds.size.x - 8, 32)
	var local_rect := Rect2(footprint.position - anchor, footprint.size)
	body.set_meta("footprint_local", local_rect)
	rectangle(body, local_rect)
	return body

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
	var paving := TileMapLayer.new()
	paving.name = "Courtyard"
	paving.tile_set = tiles
	paving.collision_enabled = false
	own(scene_root, paving)
	var dirt: Dictionary = {}
	for rect in [Rect2i(0, 11, 32, 4), Rect2i(4, 7, 6, 5), Rect2i(16, 6, 7, 5)]:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				dirt[Vector2i(x, y)] = true
	for y in range(24):
		for x in range(32):
			var cell := Vector2i(x, y)
			var uv := Vector2i(1, 1)
			if dirt.has(cell):
				uv = Vector2i(3, 0)
			else:
				var n := dirt.has(cell + Vector2i.UP)
				var s := dirt.has(cell + Vector2i.DOWN)
				var w := dirt.has(cell + Vector2i.LEFT)
				var e := dirt.has(cell + Vector2i.RIGHT)
				uv = Vector2i(0 if w else (2 if e else 1), 0 if n else (2 if s else 1))
				if not (n or s or w or e) and (x * 23 + y * 11) % 17 == 0:
					uv = Vector2i(0, 3)
			ground.set_cell(cell, 0, uv)
			if Rect2i(10, 9, 14, 8).has_point(cell):
				paving.set_cell(cell, 0, Vector2i(3, 3))
	depth = Node2D.new()
	depth.name = "DepthSort"
	depth.y_sort_enabled = true
	own(scene_root, depth)
	var shop := prop("Hanout", "hanout", Vector2i(3, 2))
	prop("House", "farmhouse", Vector2i(15, 1))
	prop("Well", "well", Vector2i(22, 11))
	var tree_cells := [Vector2i(-2, -3), Vector2i(26, -3), Vector2i(27, 5), Vector2i(-2, 15), Vector2i(5, 19), Vector2i(26, 19)]
	for i in tree_cells.size():
		prop("Tree%d" % i, "olive_tree" if i % 2 == 0 else "fig_tree", tree_cells[i])
	for cell in [Vector2i(12, 6), Vector2i(23, 7), Vector2i(26, 14)]:
		prop("Jar%d" % cell.x, "terracotta_jar", cell)
	var sign := ColorRect.new()
	sign.name = "SignPlate"
	sign.layout_direction = Control.LAYOUT_DIRECTION_LTR
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own(shop.get_node("Artwork"), sign)
	sign.position = Vector2(76, 98)
	sign.size = Vector2(72, 14)
	var texture: AtlasTexture = shop.get_node("Artwork").texture
	sign.color = texture.atlas.get_image().get_pixelv(Vector2i(texture.region.position) + Vector2i(76, 110))
	text_label(sign, "Name", "The hanout", Rect2(0, -3, 72, 20), 14)
	var area_sign := ColorRect.new()
	area_sign.name = "AreaSign"
	area_sign.layout_direction = Control.LAYOUT_DIRECTION_LTR
	area_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area_sign.color = Color("a64d26")
	own(scene_root, area_sign)
	area_sign.position = Vector2(56, 312)
	area_sign.size = Vector2(176, 36)
	var paper := ColorRect.new()
	paper.layout_direction = Control.LAYOUT_DIRECTION_LTR
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.color = Color("ffda91")
	own(area_sign, paper)
	paper.position = Vector2(3, 3)
	paper.size = Vector2(170, 30)
	text_label(area_sign, "Name", "Douar square", Rect2(4, 2, 168, 32), 20)
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
	spawn.position = Vector2(112, 416)
	own(scene_root, spawn)
	var packed := PackedScene.new()
	assert(packed.pack(scene_root) == OK)
	assert(ResourceSaver.save(packed, "res://maps/douar_square.tscn") == OK)
	print("Built douar square: 32 x 24 tiles, 12 solid props and a clear western approach.")
	scene_root.free()
	quit()
