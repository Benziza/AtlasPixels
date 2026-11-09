extends Node2D
## A small eastern clearing built from the existing farm tiles.
const Layout = preload("res://maps/world_layout.gd")

func _ready() -> void:
	var farm := get_parent()
	farm.set_meta("map_size_pixels", Layout.FARM_SIZE)
	var ground: TileMapLayer = farm.get_node("Terrain/Ground")
	var channels: TileMapLayer = farm.get_node("Terrain/Saqya")
	var vegetation: TileMapLayer = farm.get_node("Terrain/Vegetation")
	var dirt: Dictionary = {}
	for rect in [Rect2i(39, 11, 10, 3), Rect2i(42, 18, 5, 6)]:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				dirt[Vector2i(x, y)] = true
	for y in range(Layout.FARM_SIZE.y / Layout.TILE_SIZE):
		for x in range(Layout.ORIGINAL_FARM_SIZE.x / Layout.TILE_SIZE, Layout.FARM_SIZE.x / Layout.TILE_SIZE):
			var cell := Vector2i(x, y)
			var uv := Vector2i(1, 1)
			if dirt.has(cell):
				uv = Vector2i(3, 0)
			else:
				var n := dirt.has(cell + Vector2i.UP)
				var s := dirt.has(cell + Vector2i.DOWN)
				var w := dirt.has(cell + Vector2i.LEFT)
				var e := dirt.has(cell + Vector2i.RIGHT)
				uv.x = 0 if w else (2 if e else 1)
				uv.y = 0 if n else (2 if s else 1)
				if not (n or s or w or e) and (x * 23 + y * 11) % 17 == 0:
					uv = Vector2i(0, 3)
			ground.set_cell(cell, 0, uv)
			if y in [14, 15]:
				channels.set_cell(cell, 4, Vector2i(x % 2, y - 14))
	for cell in [Vector2i(41, 4), Vector2i(45, 5), Vector2i(44, 8), Vector2i(46, 19), Vector2i(41, 24), Vector2i(46, 25)]:
		vegetation.set_cell(cell, 3, Vector2i(10, 2))
	# Continue the saqya and its banks; there is no new bridge in this strip.
	var water := StaticBody2D.new()
	water.name = "ExtensionWater"
	water.collision_mask = 2
	add_child(water)
	add_rectangle(water, Rect2(1280, 456, 256, 48))
	# Replace the old perimeter, rather than leaving a wall inside the new land.
	var boundary: StaticBody2D = farm.get_node("MapBoundary")
	for child in boundary.get_children():
		boundary.remove_child(child)
		child.queue_free()
	var size_ := Vector2(Layout.FARM_SIZE)
	add_rectangle(boundary, Rect2(-32, -32, 32, size_.y + 64))
	add_rectangle(boundary, Rect2(size_.x, -32, 32, size_.y + 64))
	add_rectangle(boundary, Rect2(0, -32, size_.x, 32))
	add_rectangle(boundary, Rect2(0, size_.y, size_.x, 32))

func add_rectangle(body: StaticBody2D, rect: Rect2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.position = rect.get_center()
	body.add_child(collision)
