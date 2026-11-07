extends SceneTree
## Offline art compiler. No script is attached to the static scene.
const TILE := 32
const PIXEL := 2
const MAP_SIZE := Vector2i(40, 28)
const OUT := "res://assets/tilesets/"
const FLIP_H := 4096
const FLIP_V := 8192
const TRANSPOSE := 16384
var atlas_set := TileSet.new()
var catalog: Dictionary = {}
var layers: Dictionary = {}
var map_root: Node2D
var dirt: Dictionary = {}
var placements: Array = []
var manifest: Dictionary = {"version": 2, "tile_size": TILE, "pixel_scale": PIXEL, "map_size": [40, 28], "sources": [], "patterns": {}}

func _initialize() -> void:
	call_deferred("build")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func source_image(file: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/source/" + file + "_v2.png"))
	check(img != null and not img.is_empty(), "Missing source: " + file)
	img.convert(Image.FORMAT_RGBA8)
	return img

func cell_image(img: Image, columns: int, x: int, y: int, rows: int = 0) -> Image:
	if rows == 0:
		rows = columns
	var a := Vector2i(roundi(float(x * img.get_width()) / columns), roundi(float(y * img.get_height()) / rows))
	var b := Vector2i(roundi(float((x + 1) * img.get_width()) / columns), roundi(float((y + 1) * img.get_height()) / rows))
	return img.get_region(Rect2i(a, b - a))

func canvas(size: Vector2i) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	return img

func pixel_resize(img: Image, size: Vector2i) -> void:
	img.resize(size.x / PIXEL, size.y / PIXEL, Image.INTERPOLATE_NEAREST)
	img.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)

func visible_bounds(img: Image) -> Rect2i:
	# Ignore almost-transparent generation residue when measuring sprite padding.
	var lo := img.get_size()
	var hi := -Vector2i.ONE
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.5:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)

func fit_sprite(img: Image, size: Vector2i) -> Image:
	# Normalize all sprite sampling to the same logical pixel size.
	var cropped := img.get_region(visible_bounds(img))
	var logical := size / PIXEL
	var factor := minf(float(logical.x - 1) / cropped.get_width(), float(logical.y - 1) / cropped.get_height())
	cropped.resize(maxi(1, roundi(cropped.get_width() * factor)), maxi(1, roundi(cropped.get_height() * factor)), Image.INTERPOLATE_NEAREST)
	var result := canvas(logical)
	result.blit_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()), Vector2i((logical.x - cropped.get_width()) / 2, logical.y - cropped.get_height()))
	result.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	return result

func add_atlas(img: Image, name_: String, source_id: int) -> void:
	var path := OUT + name_ + ".png"
	check(img.save_png(path) == OK, "Could not save " + path)
	var texture := ImageTexture.create_from_image(img)
	texture.take_over_path(path)
	var source := TileSetAtlasSource.new()
	source.resource_name = name_.capitalize()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	source.use_texture_padding = true
	var count := 0
	for y in range(img.get_height() / TILE):
		for x in range(img.get_width() / TILE):
			if not img.get_region(Rect2i(x * TILE, y * TILE, TILE, TILE)).get_used_rect().has_area():
				continue
			source.create_tile(Vector2i(x, y))
			count += 1
	atlas_set.add_source(source, source_id)
	manifest.sources.append({"id": source_id, "name": name_, "png": "assets/tilesets/" + name_ + ".png", "size": [img.get_width(), img.get_height()], "tiles": count})

func add_pattern(name_: String, source_id: int, rect: Rect2i) -> void:
	var pattern := TileMapPattern.new()
	var source := atlas_set.get_source(source_id) as TileSetAtlasSource
	for y in range(rect.size.y):
		for x in range(rect.size.x):
			var at := rect.position + Vector2i(x, y)
			if source.has_tile(at):
				pattern.set_cell(Vector2i(x, y), source_id, at, 0)
	var index := atlas_set.add_pattern(pattern)
	catalog[name_] = {"source": source_id, "rect": rect, "pattern": index}
	manifest.patterns[name_] = {"pattern_index": index, "source_id": source_id, "atlas_rect_tiles": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}

func add_sprite(img: Image, source: Image, columns: int, cx: int, cy: int, rect: Rect2i) -> void:
	var sprite := fit_sprite(cell_image(source, columns, cx, cy), rect.size * TILE)
	img.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), rect.position * TILE)

func compile_atlases() -> void:
	# Nine-slice beds keep their crumbled perimeter when plots change size.
	var soil_source := source_image("soil")
	var soil := canvas(Vector2i(6 * TILE, 3 * TILE))
	for y in 3:
		for x in 6:
			var tile := cell_image(soil_source, 6, x, y, 3)
			pixel_resize(tile, Vector2i(TILE, TILE))
			soil.blit_rect(tile, Rect2i(0, 0, TILE, TILE), Vector2i(x, y) * TILE)
	var terrain_source := source_image("terrain")
	var terrain := canvas(Vector2i(128, 128))
	for y in 4:
		for x in 4:
			var tile := cell_image(terrain_source, 4, x, y)
			pixel_resize(tile, Vector2i(TILE, TILE))
			terrain.blit_rect(tile, Rect2i(0, 0, TILE, TILE), Vector2i(x, y) * TILE)
	# Keep the two legacy center patterns consistent with the new beds.
	terrain.blit_rect(soil, Rect2i(TILE, TILE, TILE, TILE), Vector2i(3, 1) * TILE)
	terrain.blit_rect(soil, Rect2i(4 * TILE, TILE, TILE, TILE), Vector2i(3, 2) * TILE)
	add_atlas(terrain, "terrain", 0)
	var terrain_names := ["grass_nw", "grass_n", "grass_ne", "dirt", "grass_w", "grass", "grass_e", "soil_dry", "grass_sw", "grass_s", "grass_se", "soil_wet", "grass_detail", "dirt_stones", "wood_deck", "paving"]
	for i in terrain_names.size():
		add_pattern(terrain_names[i], 0, Rect2i(i % 4, i / 4, 1, 1))

	var buildings := canvas(Vector2i(768, 224))
	var bs := source_image("buildings")
	var specs := [
		["farmhouse", 0, 0, Rect2i(0, 0, 8, 7)],
		["hanout", 1, 0, Rect2i(9, 0, 7, 7)],
		["well", 0, 1, Rect2i(17, 0, 3, 3)],
		["sluice_gate", 1, 1, Rect2i(21, 0, 2, 2)]]
	for s in specs:
		add_sprite(buildings, bs, 2, s[1], s[2], s[3])
	add_atlas(buildings, "buildings", 1)
	for s in specs:
		add_pattern(s[0], 1, s[3])

	var ps := source_image("props")
	var props := canvas(Vector2i(128, 128))
	for y in 4:
		for x in 4:
			var prop := cell_image(ps, 4, x, y)
			pixel_resize(prop, Vector2i(TILE, TILE))
			props.blit_rect(prop, Rect2i(0, 0, TILE, TILE), Vector2i(x, y) * TILE)
	add_atlas(props, "crops_and_props", 2)
	var names := ["mint_seedling", "mint_small", "mint_medium", "mint_mature", "tomato_seedling", "tomato_small", "tomato_green", "tomato_ripe", "terracotta_jar", "chest", "mint_basket", "tomato_crate", "fence_small", "fence_post", "bridge_small", "rocks"]
	for i in names.size():
		add_pattern(names[i], 2, Rect2i(i % 4, i / 4, 1, 1))

	var vs := source_image("vegetation")
	var vegetation := canvas(Vector2i(384, 192))
	specs = [
		["olive_tree", 0, 0, Rect2i(0, 0, 4, 6)],
		["fig_tree", 1, 0, Rect2i(5, 0, 4, 6)],
		["flowering_hedge", 0, 1, Rect2i(10, 0, 2, 1)],
		["wildflowers", 1, 1, Rect2i(10, 2, 1, 1)]]
	for s in specs:
		add_sprite(vegetation, vs, 2, s[1], s[2], s[3])
	add_atlas(vegetation, "vegetation", 3)
	for s in specs:
		add_pattern(s[0], 3, s[3])

	var ss := source_image("saqya")
	var channels := canvas(Vector2i(512, 128))
	var channel_specs := [
		["saqya_horizontal", 0, 0, 0], ["saqya_vertical", 1, 0, 0],
		["saqya_bend_nw", 0, 1, 0], ["saqya_bend_ne", 0, 1, 1],
		["saqya_bend_se", 0, 1, 2], ["saqya_bend_sw", 0, 1, 3],
		["saqya_t_south", 1, 1, 0], ["saqya_t_west", 1, 1, 1],
		["saqya_t_north", 1, 1, 2], ["saqya_t_east", 1, 1, 3]]
	for i in channel_specs.size():
		var s: Array = channel_specs[i]
		var tile := cell_image(ss, 2, s[1], s[2])
		pixel_resize(tile, Vector2i(64, 64))
		for turn_ in s[3]:
			tile.rotate_90(CLOCKWISE)
		channels.blit_rect(tile, Rect2i(0, 0, 64, 64), Vector2i(i % 8, i / 8) * 64)
	add_sprite(channels, ps, 4, 2, 3, Rect2i(4, 2, 1, 2))
	add_sprite(channels, ps, 4, 0, 3, Rect2i(6, 2, 2, 1))
	add_sprite(channels, ps, 4, 1, 3, Rect2i(9, 2, 1, 2))
	add_atlas(channels, "saqya", 4)
	for i in channel_specs.size():
		add_pattern(channel_specs[i][0], 4, Rect2i((i % 8) * 2, (i / 8) * 2, 2, 2))
	add_pattern("footbridge", 4, Rect2i(4, 2, 1, 2))
	add_pattern("fence_horizontal", 4, Rect2i(6, 2, 2, 1))
	add_pattern("fence_vertical", 4, Rect2i(9, 2, 1, 2))

	add_atlas(soil, "soil", 5)
	var edges := ["nw", "n", "ne", "w", "center", "e", "sw", "s", "se"]
	for moisture in 2:
		for i in edges.size():
			var name_ := "soil_dry_" if moisture == 0 else "soil_wet_"
			add_pattern(name_ + edges[i], 5, Rect2i(moisture * 3 + i % 3, i / 3, 1, 1))

func make_layer(name_: String) -> void:
	var layer := TileMapLayer.new()
	layer.name = name_
	layer.tile_set = atlas_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.collision_enabled = false
	layer.navigation_enabled = false
	map_root.add_child(layer)
	layer.owner = map_root
	layers[name_] = layer

func inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < MAP_SIZE.x and pos.y < MAP_SIZE.y

func stamp(layer: String, name_: String, x: int, y: int) -> void:
	if layer in ["Buildings", "Props", "Vegetation", "Saqya"]:
		placements.append({"layer": layer, "pattern": name_, "cell": [x, y]})
	var pattern := atlas_set.get_pattern(catalog[name_].pattern)
	for p in pattern.get_used_cells():
		var dest := p + Vector2i(x, y)
		if inside(dest):
			layers[layer].set_cell(dest, pattern.get_cell_source_id(p), pattern.get_cell_atlas_coords(p), 0)

func terrain_cell(x: int, y: int, name_: String, alternative: int = 0) -> void:
	layers.Ground.set_cell(Vector2i(x, y), 0, catalog[name_].rect.position, alternative)

func dirt_rect(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			dirt[Vector2i(x, y)] = true

func dirt_disk(center: Vector2, radius: Vector2) -> void:
	for y in range(floori(center.y - radius.y), ceili(center.y + radius.y) + 1):
		for x in range(floori(center.x - radius.x), ceili(center.x + radius.x) + 1):
			if ((Vector2(x, y) - center) / radius).length_squared() <= 1.0:
				dirt[Vector2i(x, y)] = true

func dirt_path(points: Array, radius: float) -> void:
	for i in range(points.size() - 1):
		var start := Vector2(points[i])
		var end := Vector2(points[i + 1])
		var steps := maxi(1, ceili(start.distance_to(end) * 3.0))
		for j in range(steps + 1):
			dirt_disk(start.lerp(end, float(j) / steps), Vector2(radius, radius))

func draw_ground() -> void:
	# Compact clearings connected by narrow, irregular footpaths.
	dirt_disk(Vector2(8, 9), Vector2(6.3, 5.0))
	dirt_disk(Vector2(26, 8), Vector2(6.2, 5.4))
	dirt_rect(Rect2i(24, 3, 6, 6))
	dirt_disk(Vector2(19, 11), Vector2(3.4, 2.7))
	dirt_path([Vector2(8, 11), Vector2(7, 14), Vector2(7, 18), Vector2(6, 24), Vector2(7, 28)], 1.4)
	dirt_path([Vector2(27, 9), Vector2(27, 12), Vector2(24, 15), Vector2(22, 18), Vector2(22, 28)], 1.35)
	dirt_path([Vector2(11, 11), Vector2(16, 12), Vector2(20, 11), Vector2(23, 10)], 1.15)
	dirt_disk(Vector2(6, 21), Vector2(5.5, 4.6))
	dirt_disk(Vector2(22, 23), Vector2(7.3, 3.8))
	dirt_disk(Vector2(34, 20), Vector2(3.6, 3.4))
	dirt_path([Vector2(29, 11), Vector2(33, 12), Vector2(35, 14), Vector2(34, 20)], 1.2)
	# Narrow grassy banks stay around the channels; paths only reach the bridges.
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var p := Vector2i(x, y)
			if dirt.has(p):
				terrain_cell(x, y, "dirt_stones" if (x * 17 + y * 13) % 101 == 0 else "dirt")
				continue
			var n := dirt.has(p + Vector2i.UP)
			var e := dirt.has(p + Vector2i.RIGHT)
			var s := dirt.has(p + Vector2i.DOWN)
			var w := dirt.has(p + Vector2i.LEFT)
			var tile := "grass"
			if n and w: tile = "grass_nw"
			elif n and e: tile = "grass_ne"
			elif s and w: tile = "grass_sw"
			elif s and e: tile = "grass_se"
			elif n: tile = "grass_n"
			elif s: tile = "grass_s"
			elif w: tile = "grass_w"
			elif e: tile = "grass_e"
			elif (x * 23 + y * 11) % 17 == 0: tile = "grass_detail"
			terrain_cell(x, y, tile)

func plot(rect: Rect2i, crop: String, stage: int) -> void:
	var stages := ["seedling", "small", "medium", "mature"] if crop == "mint" else ["seedling", "small", "green", "ripe"]
	var edges := ["nw", "n", "ne", "w", "center", "e", "sw", "s", "se"]
	var soil_prefix := "soil_dry_" if stage == 0 else "soil_wet_"
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var edge_x := 0 if x == rect.position.x else (2 if x == rect.end.x - 1 else 1)
			var edge_y := 0 if y == rect.position.y else (2 if y == rect.end.y - 1 else 1)
			stamp("Soil", soil_prefix + edges[edge_y * 3 + edge_x], x, y)
			stamp("Crops", crop + "_" + stages[stage], x, y)

func build_map() -> void:
	map_root = Node2D.new()
	map_root.name = "DouarFarm"
	map_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_root.set_meta("description", "A compact Moroccan farm around a bending saqya. Editable art layers only.")
	map_root.set_meta("map_size_tiles", MAP_SIZE)
	map_root.set_meta("tile_size_pixels", TILE)
	map_root.set_meta("art_version", 2)
	for name_ in ["Ground", "Courtyards", "Soil", "Saqya", "Crops", "Buildings", "Props", "Vegetation"]:
		make_layer(name_)
	draw_ground()

	# Local patios, not straight roads covering the whole farm.
	for y in range(9, 11):
		for x in range(5, 12):
			stamp("Courtyards", "paving", x, y)
	for y in range(8, 10):
		for x in range(25, 29):
			stamp("Courtyards", "paving", x, y)
	for x in range(31, 34):
		stamp("Courtyards", "paving", x, 11)
	stamp("Buildings", "hanout", 5, 3)
	stamp("Buildings", "farmhouse", 23, 2)
	stamp("Buildings", "well", 31, 9)

	# A single connected saqya bends around the central garden.
	for x in range(0, 12, 2):
		stamp("Saqya", "saqya_horizontal", x, 14)
	stamp("Saqya", "saqya_bend_sw", 12, 14)
	stamp("Saqya", "saqya_vertical", 12, 16)
	stamp("Saqya", "saqya_bend_ne", 12, 18)
	for x in range(14, 30, 2):
		stamp("Saqya", "saqya_horizontal", x, 18)
	stamp("Saqya", "saqya_bend_nw", 30, 18)
	stamp("Saqya", "saqya_vertical", 30, 16)
	stamp("Saqya", "saqya_bend_se", 30, 14)
	for x in range(32, 40, 2):
		stamp("Saqya", "saqya_horizontal", x, 14)
	stamp("Props", "footbridge", 7, 14)
	stamp("Props", "footbridge", 22, 18)
	stamp("Props", "footbridge", 35, 14)
	stamp("Props", "sluice_gate", 10, 13)

	plot(Rect2i(16, 9, 4, 2), "mint", 0)
	plot(Rect2i(17, 12, 3, 2), "mint", 2)
	plot(Rect2i(23, 11, 2, 2), "tomato", 1)
	plot(Rect2i(3, 19, 3, 4), "mint", 3)
	plot(Rect2i(8, 19, 3, 4), "mint", 2)
	plot(Rect2i(17, 21, 4, 4), "tomato", 3)
	plot(Rect2i(24, 21, 4, 4), "tomato", 2)
	plot(Rect2i(33, 18, 3, 4), "mint", 1)

	# Connected fences and groups of props help each place feel inhabited.
	for x in [2, 4, 8, 10]:
		stamp("Props", "fence_horizontal", x, 24)
	for y in [18, 20, 22]:
		stamp("Props", "fence_vertical", 1, y)
	for x in [16, 18, 24, 26]:
		stamp("Props", "fence_horizontal", x, 26)
	for y in [20, 22, 24]:
		stamp("Props", "fence_vertical", 29, y)
	for x in [32, 34]:
		stamp("Props", "fence_horizontal", x, 23)
	for p in [Vector2i(4, 9), Vector2i(12, 9), Vector2i(23, 8), Vector2i(30, 8), Vector2i(33, 11)]:
		stamp("Props", "terracotta_jar", p.x, p.y)
	for p in [Vector2i(11, 10), Vector2i(29, 9)]:
		stamp("Props", "chest", p.x, p.y)
	for p in [Vector2i(5, 10), Vector2i(8, 11), Vector2i(4, 23)]:
		stamp("Props", "mint_basket", p.x, p.y)
	for p in [Vector2i(6, 10), Vector2i(9, 11), Vector2i(25, 25)]:
		stamp("Props", "tomato_crate", p.x, p.y)
	for p in [Vector2i(3, 12), Vector2i(15, 15), Vector2i(28, 13), Vector2i(34, 25), Vector2i(21, 4), Vector2i(11, 26)]:
		stamp("Props", "rocks", p.x, p.y)
	# A few additional obstacles, outside the three bridge approaches.
	for p in [Vector2i(14, 11), Vector2i(28, 16), Vector2i(9, 17), Vector2i(31, 23)]:
		stamp("Props", "rocks", p.x, p.y)

	# Layered canopy clusters frame the clearings and continue beyond the view.
	var trees := [
		["olive_tree", -2, -2], ["fig_tree", 1, -3], ["olive_tree", 9, -4],
		["olive_tree", 13, -3], ["fig_tree", 18, -4], ["olive_tree", 21, -4],
		["olive_tree", 31, -2], ["fig_tree", 35, -3], ["olive_tree", 38, 0],
		["fig_tree", -3, 4], ["olive_tree", -2, 8],
		["fig_tree", 14, 2], ["olive_tree", 18, 1],
		["olive_tree", 35, 5], ["fig_tree", 37, 8],
		["fig_tree", -3, 19], ["olive_tree", -1, 23], ["fig_tree", 2, 25],
		["olive_tree", 10, 23], ["fig_tree", 13, 25],
		["olive_tree", 32, 23], ["fig_tree", 36, 22], ["olive_tree", 38, 18]]
	trees.sort_custom(func(a, b): return a[2] < b[2])
	for t in trees:
		stamp("Vegetation", t[0], t[1], t[2])
	for p in [Vector2i(3, 3), Vector2i(11, 2), Vector2i(21, 7), Vector2i(32, 6), Vector2i(2, 16), Vector2i(4, 16), Vector2i(8, 16), Vector2i(15, 16), Vector2i(17, 16), Vector2i(26, 16), Vector2i(28, 16), Vector2i(33, 16), Vector2i(36, 16), Vector2i(3, 25), Vector2i(8, 25), Vector2i(16, 26), Vector2i(26, 26)]:
		stamp("Vegetation", "flowering_hedge", p.x, p.y)
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var p := Vector2i(x, y)
			if not dirt.has(p) and (x * 41 + y * 23) % 23 == 0 and not layers.Saqya.get_used_cells().has(p):
				stamp("Vegetation", "wildflowers", x, y)
	for p in [Vector2i(4, 12), Vector2i(13, 11), Vector2i(21, 12), Vector2i(28, 10), Vector2i(16, 20), Vector2i(28, 24), Vector2i(32, 22)]:
		stamp("Vegetation", "wildflowers", p.x, p.y)

	var layer_export: Array = []
	for layer: TileMapLayer in layers.values():
		var cells: Array = []
		for pos in layer.get_used_cells():
			var sid := layer.get_cell_source_id(pos)
			var uv := layer.get_cell_atlas_coords(pos)
			check(atlas_set.get_source(sid).has_tile(uv), "Invalid tile reference")
			cells.append([pos.x, pos.y, sid, uv.x, uv.y, layer.get_cell_alternative_tile(pos)])
		layer_export.append({"name": str(layer.name), "cells": cells})
	manifest["layers"] = layer_export
	manifest["placements"] = placements
	var scene := PackedScene.new()
	check(scene.pack(map_root) == OK, "Map packing failed")
	check(ResourceSaver.save(scene, "res://maps/douar_farm.tscn") == OK, "Map save failed")

func build() -> void:
	# UI artwork shares the same nearest-neighbor, two-pixel sampling as the map.
	var icon_source := source_image("hud_icons")
	var icons := canvas(Vector2i(192, 96))
	for i in 8:
		var icon := fit_sprite(cell_image(icon_source, 4, i % 4, i / 4, 2), Vector2i(48, 48))
		icons.blit_rect(icon, Rect2i(0, 0, 48, 48), Vector2i(i % 4, i / 4) * 48)
	DirAccess.make_dir_recursive_absolute("res://assets/ui")
	check(icons.save_png("res://assets/ui/icons.png") == OK, "Could not save UI icons")
	atlas_set.tile_size = Vector2i(TILE, TILE)
	atlas_set.resource_name = "AtlasPixels Moroccan Farm v2"
	compile_atlases()
	check(ResourceSaver.save(atlas_set, OUT + "moroccan_farm.tres") == OK, "TileSet save failed")
	atlas_set.take_over_path(OUT + "moroccan_farm.tres")
	build_map()
	var file := FileAccess.open("res://maps/douar_farm.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	print("Compiled v2: %d atlas sources, %d patterns, %d static layers." % [atlas_set.get_source_count(), atlas_set.get_patterns_count(), layers.size()])
	map_root.free()
	quit()
