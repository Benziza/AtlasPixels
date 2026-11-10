extends SceneTree
## Full-game north/south travel, map isolation, collision and save compatibility.
const Layout = preload("res://maps/world_layout.gd")
const FarmState = preload("res://maps/farm_state.gd")
const TEST_SAVE := "res://.godot/qa/civic-test-save.json"
var game: Node2D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func settle(ticks: int = 4) -> void:
	for _i in ticks:
		await physics_frame
		await process_frame

func make_game(persistence: bool = false) -> Node2D:
	var instance: Node2D = load("res://main.tscn").instantiate()
	instance.persistence_enabled = persistence
	instance.save_path = TEST_SAVE
	root.add_child(instance)
	return instance

func hits(point: Vector2) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = game.player.get_node("Feet").shape
	query.transform = Transform2D(0, point + Vector2(0, -8))
	query.collision_mask = 1
	query.exclude = [game.player.get_rid()]
	return game.get_world_2d().direct_space_state.intersect_shape(query)

func can_stand(point: Vector2) -> bool:
	return hits(point).is_empty()

func check_label(label: Label, expected: String) -> void:
	expect(label.text == expected, "Wrong civic sign text: " + label.text)
	expect(label.get_visible_line_count() == label.get_line_count(), "Clipped civic label: " + label.text)
	for line in label.text.split("\n"):
		var width := label.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		expect(width <= label.size.x, "Civic label exceeds its plaque: " + line)

func walk(action: String, ticks: int) -> void:
	Input.action_press(action)
	await settle(ticks)
	Input.action_release(action)
	await settle(8)

func run_tests() -> void:
	root.size = Vector2i(1280, 896)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	game = make_game()
	await settle()
	game.activate_area("douar", Layout.SQUARE_NORTH_RETURN)
	await settle()
	var snapshot: Dictionary = game.state.to_data().duplicate(true)
	var hud_rect: Rect2 = game.hud.clock_label.get_global_rect()
	check_label(game.square.get_node("DepthSort/ToCivic/Name"), "القيادة\nوالمستشفى")
	expect(game.square.get_node("DepthSort/ToCivic/CompassArrow").scale.y == 1, "North sign arrow is reversed")
	expect(game.context_hint() == tr("Walk north to the caidat and hospital."), "Northern exit has no route hint")
	game.open_pause()
	await walk("move_up", 60)
	expect(game.current_area == "douar" and not game.transitioning, "Pause did not block civic travel")
	game.close_menu()
	await walk("move_up", 72)
	expect(game.current_area == "civic" and not game.transitioning, "Walking north did not enter the separate map")
	expect(game.player.get_parent() == game.civic.get_node("DepthSort"), "Player is not depth-sorted in the civic map")
	expect(game.camera.zoom == Vector2(2, 2) and game.camera.limit_right == Layout.CIVIC_SIZE.x and game.camera.limit_bottom == Layout.CIVIC_SIZE.y, "Civic camera has wrong zoom or limits")
	expect(game.hud.clock_label.get_global_rect() == hud_rect, "Civic travel moved the HUD")
	expect(game.civic.visible and not game.square.visible and not game.cafe.visible and not game.get_node("Terrain").visible, "Travel left another area visible")
	expect(game.state.inventory == snapshot.inventory and game.state.coins == snapshot.coins and game.state.to_data().beds == snapshot.beds, "Travel lost inventory, money or crops")
	expect(game.civic.get_node("Ground").get_used_cells().size() == 32 * 24, "Civic terrain has holes")
	check_label(game.civic.get_node("DepthSort/Caidat/Name"), "القيادة")
	check_label(game.civic.get_node("DepthSort/Hospital/Name"), "المستشفى")
	check_label(game.civic.get_node("DepthSort/ToDouar/Name"), "ساحة الدوار")
	expect(game.civic.get_node("DepthSort/ToDouar/CompassArrow").scale.y == -1, "Southern return sign arrow is reversed")
	for point in [Layout.CIVIC_SPAWN, game.civic.CAIDAT_DOOR, game.civic.HOSPITAL_DOOR, Vector2(512, 720)]:
		expect(can_stand(point), "Civic entrance or exit blocked: " + str(point))
	for point in [Vector2(272, 280), Vector2(752, 280), Vector2(-8, 432), Vector2(1032, 432), Vector2(512, 0), Vector2(512, 784), Vector2(672, 696)]:
		expect(not can_stand(point), "Civic obstacle is missing: " + str(point))
	# Reach both front steps and the southern portal with player-sized physics queries.
	var targets := {Vector2i(17, 26): true, Vector2i(47, 26): true, Vector2i(32, 46): true}
	var start := Vector2i(Layout.CIVIC_SPAWN) / 16
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var index := 0
	while index < queue.size() and not targets.is_empty():
		var cell := queue[index]
		index += 1
		targets.erase(cell)
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + offset
			if next.x < 1 or next.y < 1 or next.x >= 64 or next.y >= 48 or seen.has(next):
				continue
			seen[next] = true
			if can_stand(Vector2(next * 16)):
				queue.append(next)
	expect(targets.is_empty(), "Civic buildings and return path are disconnected")
	for point in [Vector2(384, 194), Vector2(640, 496), Vector2(112, 416)]:
		var foreign := false
		for hit: Dictionary in hits(point):
			foreign = foreign or not game.civic.is_ancestor_of(hit.collider)
		expect(not foreign, "Hidden area still collides in civic map: " + str(point))
	game.player.position = game.square_markers.well
	expect(not game.near_marker("well"), "Hidden village well can be used in civic area")
	game.player.position = Layout.CAFE_DOOR
	expect(not game.near_marker("cafe"), "Hidden cafe entrance is active in civic area")
	for marker in ["caidat", "hospital"]:
		game.player.position = game.civic_markers[marker]
		await settle()
		game.interact()
		expect(not game.paused and not game.hud.toast_label.text.is_empty(), "Civic building interaction failed: " + marker)
	game.player.position = Vector2(512, 448)
	game.state.selected_tool = 0
	var seeds: int = game.state.inventory.mint_seed
	expect(not game.use_tool(Vector2i(16, 9)) and game.state.inventory.mint_seed == seeds, "Civic input changed hidden farm crops")
	game.persistence_enabled = true
	expect(game.save_progress(), "Could not save civic progress")
	var saved: Dictionary = game.state.to_data().duplicate(true)
	game.queue_free()
	await settle()
	game = make_game(true)
	await settle(8)
	expect(game.current_area == "civic" and game.player.position == Vector2(512, 448), "Reload lost civic map or position")
	expect(game.state.inventory == saved.inventory and game.state.coins == saved.coins and game.state.to_data().beds == saved.beds, "Reload lost farm progress")
	var validator := FarmState.new()
	validator.initialize(game.initial_beds)
	for version in [1, 2, 3]:
		var legacy: Dictionary = saved.duplicate(true)
		legacy.version = version
		legacy.area = "farm"
		legacy.player = [864, 352]
		if version == 1:
			legacy.erase("area")
		expect(validator.restore(legacy) and validator.inventory == game.state.inventory, "Legacy farm save lost progress: v%d" % version)
	for old_area in ["douar", "cafe"]:
		var legacy: Dictionary = saved.duplicate(true)
		legacy.version = 3
		legacy.area = old_area
		legacy.player = [320, 300]
		expect(validator.restore(legacy) and validator.area == old_area, "Version 3 area migration failed: " + old_area)
	var invalid: Dictionary = saved.duplicate(true)
	invalid.version = 3
	expect(not validator.restore(invalid), "Old save version accepted the new civic map")
	invalid.version = 4
	invalid.player = [1200, 448]
	expect(not validator.restore(invalid), "Civic save accepted douar-sized coordinates")
	game.player.position = Vector2(272, 280)
	game.save_progress()
	game.queue_free()
	await settle()
	game = make_game(true)
	await settle(8)
	expect(game.player.position == Layout.CIVIC_SPAWN, "Blocked civic save did not recover at the entrance")
	await walk("move_down", 72)
	expect(game.current_area == "douar" and not game.transitioning and game.player.position.distance_to(Layout.SQUARE_NORTH_RETURN) < 100, "Southern exit did not return to north douar")
	expect(game.camera.limit_right == Layout.SQUARE_SIZE.x and can_stand(game.player.position), "Return left wrong camera bounds or blocked spawn")
	await settle(90)
	expect(game.current_area == "douar" and not game.transitioning, "Return spawn immediately triggered another switch")
	game.player.position = Layout.SQUARE_NORTH_RETURN
	await walk("move_up", 72)
	expect(game.current_area == "civic", "Second trip north failed")
	var day: int = game.state.day
	game.state.minute = 1550
	game.state.tick_seconds = 6.99
	await settle(70)
	expect(game.current_area == "farm" and game.state.day == day + 1 and not game.transitioning, "02:00 in civic area did not return home once")
	game.activate_area("civic", Layout.CIVIC_SPAWN)
	game.menu_action("new_farm")
	expect(game.current_area == "farm" and game.state.day == 1, "New farm did not leave civic area")
	game.queue_free()
	await settle()
	print("Civic: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
