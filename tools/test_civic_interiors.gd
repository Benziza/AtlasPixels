extends SceneTree
## Exercise both interiors through the full game, including saved and hidden physics.
const Layout = preload("res://maps/world_layout.gd")
const FarmState = preload("res://maps/farm_state.gd")
const TEST_SAVE := "res://.godot/qa/civic-interiors-test-save.json"
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

func press_e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await settle(4)
	event.pressed = false
	Input.parse_input_event(event)
	await settle(30)

func walk(action: String, ticks: int) -> void:
	Input.action_press(action)
	await settle(ticks)
	Input.action_release(action)
	await settle(8)

func hits(point: Vector2) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = game.player.get_node("Feet").shape
	query.transform = Transform2D(0, point + Vector2(0, -8))
	query.collision_mask = 1
	query.exclude = [game.player.get_rid()]
	return game.get_world_2d().direct_space_state.intersect_shape(query)

func can_stand(point: Vector2) -> bool:
	return hits(point).is_empty()

func check_routes(room: Node2D) -> void:
	# Flood-fill with the real player's shape, not just the furniture rectangles.
	var start := Vector2i(Layout.CIVIC_INTERIOR_SPAWN) / 8
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var reachable := {start: true}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + offset
			if next.x < 1 or next.y < 1 or next.x >= 80 or next.y >= 56 or seen.has(next):
				continue
			seen[next] = true
			if can_stand(Vector2(next * 8)):
				queue.append(next)
				reachable[next] = true
	expect(reachable.has(Vector2i(40, 53)), "Door is disconnected: " + room.building)
	for entry: Dictionary in room.interactions:
		expect(can_stand(entry.point), "Interaction standing position is blocked: " + entry.hint)
		expect(reachable.has(Vector2i(entry.point).snapped(Vector2i(8, 8)) / 8), "Cannot reach: " + entry.hint)
		game.player.position = entry.point
		expect(game.context_hint() == entry.hint, "Wrong interaction hint")
		game.interact()
		expect(game.hud.toast_label.text == entry.message and not game.paused, "Interaction did not show its description")
	for label: Label in room.find_children("*", "Label", true, false):
		expect(label.get_parent().get_global_rect().encloses(label.get_global_rect()), "Plaque text escaped its panel: %s / %s / %s" % [label.text, label.get_parent().get_global_rect(), label.get_global_rect()])
		expect(label.get_visible_line_count() == label.get_line_count(), "Plaque text is clipped")

func check_room(area: String) -> void:
	game = make_game()
	await settle()
	var door: Vector2 = game.civic_markers[area]
	var outside: Vector2 = Layout.CAIDAT_RETURN if area == "caidat" else Layout.HOSPITAL_RETURN
	game.activate_area("civic", door)
	await settle()
	var original: Dictionary = game.state.to_data().duplicate(true)
	game.open_pause()
	await press_e()
	expect(game.current_area == "civic" and not game.transitioning, "Pause allowed entry: " + area)
	game.close_menu()
	await press_e()
	expect(game.current_area == area and not game.transitioning, "E did not enter: " + area)
	var room: Node2D = game.civic_interiors[area]
	expect(game.player.get_parent() == room.get_node("DepthSort"), "Player is outside interior depth sort")
	expect(game.camera.zoom == Vector2(2, 2) and game.camera.limit_right == 640 and game.camera.limit_bottom == 448, "Interior camera bounds changed")
	expect(room.visible and not game.civic.visible and not game.cafe.visible and not game.square.visible and not game.get_node("Terrain").visible, "Another map is visible inside")
	for name_: String in game.civic_interiors:
		expect(game.civic_interiors[name_].visible == (name_ == area), "Both interiors are visible")
	expect(game.player.position == Layout.CIVIC_INTERIOR_SPAWN and can_stand(game.player.position), "Interior arrival is blocked")
	await settle(60)
	expect(game.current_area == area and not game.transitioning, "Interior arrival bounced outside")
	game.state.minute = 1380
	game.update_daylight()
	expect(game.daylight.color == Color.WHITE, "Interior becomes dark at night")
	game.state.minute = 600
	for point in [Vector2(320, 384), Vector2(320, 304), Vector2(320, 424)]:
		expect(can_stand(point), "Central aisle is blocked")
	for point in [Vector2(8, 300), Vector2(632, 300), Vector2(320, 80), Vector2(200, 440)]:
		expect(not can_stand(point), "Room wall has no collision")
	var obstacle: Vector2 = Vector2(488, 224) if area == "caidat" else Vector2(440, 280)
	expect(not can_stand(obstacle), "Desk or bed has no collision")
	for point in [Vector2(384, 194), Vector2(112, 416), Vector2(272, 280), obstacle]:
		var foreign := false
		for hit: Dictionary in hits(point):
			foreign = foreign or not room.is_ancestor_of(hit.collider)
		expect(not foreign, "Hidden map still collides inside " + area)
	for marker in ["well", "cafe", "caidat", "hospital", "hanout"]:
		expect(not game.near_marker(marker), "Outdoor marker is active indoors")
	check_routes(room)
	game.player.position = Layout.CIVIC_INTERIOR_SPAWN
	await settle()
	game.state.selected_tool = 0
	expect(not game.use_tool(Vector2i(16, 9)), "Interior allowed farming")
	expect(game.state.inventory == original.inventory and game.state.coins == original.coins and game.state.to_data().beds == original.beds, "Interior altered farm progress")
	game.persistence_enabled = true
	expect(game.save_progress(), "Interior save failed")
	game.queue_free()
	await settle()
	game = make_game(true)
	await settle(8)
	expect(game.current_area == area and game.player.position == Layout.CIVIC_INTERIOR_SPAWN, "Save did not restore interior")
	expect(game.state.inventory == original.inventory and game.state.to_data().beds == original.beds, "Interior reload lost inventory or crops")
	# Corrupt-but-in-bounds furniture position is recovered without discarding progress.
	game.player.position = obstacle
	game.save_progress()
	game.queue_free()
	await settle()
	game = make_game(true)
	await settle(8)
	expect(game.current_area == area and game.player.position == Layout.CIVIC_INTERIOR_SPAWN, "Blocked interior save did not recover")
	game.open_pause()
	await walk("move_down", 40)
	expect(game.current_area == area, "Paused movement triggered exit")
	game.close_menu()
	await walk("move_down", 35)
	expect(game.current_area == "civic" and not game.transitioning, "Walking through door did not exit")
	expect(game.player.position.distance_to(outside) < 60 and can_stand(game.player.position), "Exit returned to wrong doorway")
	expect(game.daylight.color != Color.WHITE if game.state.minute >= 1260 else game.daylight.color == Color.WHITE, "Outdoor lighting was not restored")
	await settle(60)
	expect(game.current_area == "civic", "Exterior return bounced inside")
	game.player.position = door
	await press_e()
	expect(game.current_area == area, "Second entry failed")
	var day: int = game.state.day
	game.state.minute = 1550
	game.state.tick_seconds = 6.99
	await settle(70)
	expect(game.current_area == "farm" and game.state.day == day + 1 and not game.transitioning, "02:00 did not return home")
	game.activate_area(area, Layout.CIVIC_INTERIOR_SPAWN)
	game.menu_action("new_farm")
	expect(game.current_area == "farm" and game.state.day == 1, "New farm left player indoors")
	game.queue_free()
	await settle()

func check_versions() -> void:
	var state := FarmState.new()
	state.initialize({Vector2i(16, 9): FarmState.empty_bed()})
	var snapshot := state.to_data()
	var validator := FarmState.new()
	validator.initialize(state.beds)
	for version in [1, 2, 3, 4]:
		for area in ["farm", "douar", "cafe", "civic"]:
			if (version == 1 and area != "farm") or (version < 3 and area == "cafe") or (version < 4 and area == "civic"):
				continue
			var legacy: Dictionary = snapshot.duplicate(true)
			legacy.version = version
			legacy.area = area
			legacy.player = [320, 384]
			expect(validator.restore(legacy) and validator.area == area, "Old save rejected: %d / %s" % [version, area])
	for area in ["caidat", "hospital"]:
		var data: Dictionary = snapshot.duplicate(true)
		data.area = area
		data.player = [320, 384]
		expect(validator.restore(data) and validator.area == area, "Version 5 interior restore failed")
		var before := validator.to_data()
		data.version = 4
		expect(not validator.restore(data) and validator.to_data() == before, "Version 4 accepted new interior or mutated state")
		data.version = 5
		for point in [[800, 384], [320, 600], [-1, 384]]:
			data.player = point
			expect(not validator.restore(data), "Interior accepted exterior coordinates")

func run_tests() -> void:
	root.size = Vector2i(1280, 896)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	check_versions()
	for area in ["caidat", "hospital"]:
		await check_room(area)
	print("Civic interiors: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
