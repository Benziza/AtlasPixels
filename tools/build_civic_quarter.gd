extends "res://tools/build_douar_square.gd"
## Reuse the village tiles and prop helpers for a distinct northern map.

func build() -> void:
	tiles = load("res://assets/tilesets/moroccan_farm.tres")
	patterns = JSON.parse_string(FileAccess.get_file_as_string("res://maps/douar_farm.json")).patterns
	scene_root = Node2D.new()
	scene_root.name = "CivicQuarter"
	scene_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene_root.set_script(load("res://maps/civic_quarter.gd"))
	scene_root.set_meta("map_size_pixels", Layout.CIVIC_SIZE)
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tiles
	ground.collision_enabled = false
	own(scene_root, ground)
	var dirt: Dictionary = {}
	for rect in [Rect2i(14, 7, 4, 17), Rect2i(4, 11, 9, 4), Rect2i(19, 11, 9, 4), Rect2i(12, 12, 8, 3)]:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				dirt[Vector2i(x, y)] = true
	var map_cells := Layout.CIVIC_SIZE / Layout.TILE_SIZE
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
	depth = Node2D.new()
	depth.name = "DepthSort"
	depth.y_sort_enabled = true
	own(scene_root, depth)
	var caidat := village_prop("Caidat", "caidat.tres", Vector2i(4, 3), [Rect2(4, 118, 280, 140), Rect2(76, 258, 136, 14)], Vector2(288, 272))
	caidat.position.y += 16
	text_label(caidat, "Name", "Caidat", Rect2(-45, -172, 90, 28), 15)
	var hospital := village_prop("Hospital", "hospital.tres", Vector2i(19, 4), [Rect2(4, 88, 280, 132), Rect2(84, 220, 120, 20)], Vector2(288, 240))
	hospital.position.y += 16
	text_label(hospital, "Name", "Hospital", Rect2(-50, -176, 100, 28), 15)
	var tree_cells := [Vector2i(-1, -2), Vector2i(6, -3), Vector2i(14, -3), Vector2i(22, -3), Vector2i(29, -2), Vector2i(-2, 7), Vector2i(29, 8), Vector2i(3, 16), Vector2i(24, 16), Vector2i(-1, 21), Vector2i(29, 21)]
	for i in tree_cells.size():
		prop("Tree%d" % i, "olive_tree" if i % 2 == 0 else "fig_tree", tree_cells[i])
	for cell in [Vector2i(2, 13), Vector2i(12, 15), Vector2i(20, 16), Vector2i(28, 14), Vector2i(9, 22), Vector2i(21, 22)]:
		prop("Flowers%d_%d" % [cell.x, cell.y], "wildflowers", cell, false)
	var route: StaticBody2D = load("res://maps/route_sign.tscn").instantiate()
	route.name = "ToDouar"
	route.position = Vector2(672, 688)
	route.direction = -2
	own(depth, route)
	var boundary := StaticBody2D.new()
	boundary.name = "MapBoundary"
	boundary.collision_mask = 2
	own(scene_root, boundary)
	var size_ := Vector2(Layout.CIVIC_SIZE)
	rectangle(boundary, Rect2(-32, -32, 32, size_.y + 64))
	rectangle(boundary, Rect2(size_.x, -32, 32, size_.y + 64))
	rectangle(boundary, Rect2(0, -32, size_.x, 32))
	rectangle(boundary, Rect2(0, size_.y, size_.x, 32))
	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Layout.CIVIC_SPAWN
	own(scene_root, spawn)
	var packed := PackedScene.new()
	assert(packed.pack(scene_root) == OK)
	assert(ResourceSaver.save(packed, "res://maps/civic_quarter.tscn") == OK)
	print("Built civic quarter: ", map_cells, ", caidat, hospital and southern return path.")
	scene_root.free()
	quit()
