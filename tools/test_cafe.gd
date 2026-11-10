extends SceneTree
## Full-game cafe travel, physics, menu, save migration and overnight return.
const Layout = preload("res://maps/world_layout.gd")
const FarmState = preload("res://maps/farm_state.gd")
const TEST_SAVE := "res://.godot/qa/cafe-test-save.json"
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
	event.keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle(30)

func can_stand(point: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = game.player.get_node("Feet").shape
	query.transform = Transform2D(0, point + Vector2(0, -8))
	query.collision_mask = 1
	query.exclude = [game.player.get_rid()]
	return game.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func run_tests() -> void:
	root.size = Vector2i(1280, 896)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	game = make_game()
	await settle()
	game.activate_area("douar", Layout.CAFE_DOOR)
	await settle()
	expect(can_stand(Layout.CAFE_DOOR) and can_stand(Layout.CAFE_RETURN), "Cafe entrance or return overlaps village obstacles")
	expect(game.context_hint() == tr("E  /  Enter the cafe"), "Door hint missing")
	game.open_pause()
	await press_e()
	expect(game.current_area == "douar", "Paused input entered cafe")
	game.close_menu()
	await press_e()
	expect(game.current_area == "cafe" and not game.transitioning, "E at door did not enter cafe")
	expect(game.player.get_parent() == game.cafe.get_node("DepthSort"), "Cafe player is not depth-sorted with furniture")
	expect(game.camera.zoom == Vector2(2, 2) and game.camera.limit_right == 640 and game.camera.limit_bottom == 448, "Cafe changed gameplay zoom or has incorrect camera bounds")
	expect(can_stand(Layout.CAFE_SPAWN), "Cafe spawn is blocked")
	for y in range(240, 417, 16):
		expect(can_stand(Vector2(320, y)), "Central cafe aisle blocked at y=%d" % y)
	for point in [Vector2(384, 194), Vector2(136, 340), Vector2(500, 340), Vector2(136, 196), Vector2(12, 300), Vector2(628, 300), Vector2(320, 100)]:
		expect(not can_stand(point), "Cafe obstacle is walkable at %s" % point)
	game.player.position = Vector2(384, 252)
	await settle()
	Input.action_press("move_up")
	await settle(40)
	Input.action_release("move_up")
	expect(game.player.position.y >= 223.5, "Walking passed through counter")
	await press_e()
	expect(game.paused and is_instance_valid(game.hud.modal), "E at counter did not open menu")
	var before: int = game.state.coins
	game.menu_action("cafe_tea")
	expect(game.state.coins == before - 5, "Tea has wrong price")
	game.menu_action("cafe_coffee")
	expect(game.state.coins == before - 13, "Coffee has wrong price")
	game.menu_action("cafe_msemen")
	expect(game.state.coins == before - 19, "Msemen has wrong price")
	game.state.coins = 4
	game.menu_action("cafe_tea")
	expect(game.state.coins == 4, "Cafe allowed purchase without funds")
	expect(not game.state.buy_refreshment("unknown").is_empty() and game.state.coins == 4, "Unknown cafe order charged coins")
	var minute: int = game.state.minute
	game._process(30)
	expect(game.state.minute == minute, "Clock advanced while cafe menu was open")
	game.close_menu()
	var seeds: int = game.state.inventory.mint_seed
	game.state.selected_tool = 0
	expect(not game.use_tool(Vector2i(16, 9)) and game.state.inventory.mint_seed == seeds, "Cafe input planted on hidden farm")
	game.state.minute = 1440
	game.update_daylight()
	expect(game.daylight.color == Color.WHITE, "Cafe lights went dark with outdoor night")
	game.state.minute = 360
	game.state.coins = 81
	game.player.position = Vector2(320, 300)
	game.persistence_enabled = true
	expect(game.save_progress(), "Cafe save failed")
	var saved: Dictionary = game.state.to_data().duplicate(true)
	game.queue_free()
	await settle()
	game = make_game(true)
	await settle(8)
	expect(game.current_area == "cafe" and game.player.position == Vector2(320, 300) and game.state.coins == 81, "Cafe reload lost area, position or coins")
	var validator := FarmState.new()
	validator.initialize(game.initial_beds)
	var invalid: Dictionary = saved.duplicate(true)
	invalid.player = [700, 300]
	expect(not validator.restore(invalid), "Cafe save accepted outdoor-sized coordinates")
	invalid = saved.duplicate(true)
	invalid.version = 2
	expect(not validator.restore(invalid), "Version 2 accepted an unknown cafe area")
	for version in [1, 2]:
		var legacy: Dictionary = saved.duplicate(true)
		legacy.version = version
		legacy.area = "farm"
		legacy.player = [864, 352]
		if version == 1:
			legacy.erase("area")
		expect(validator.restore(legacy) and validator.coins == 81 and validator.area == "farm", "Legacy v%d lost progress" % version)
	game.player.position = Vector2(384, 194)
	game.save_progress()
	game.queue_free()
	await settle()
	game = make_game(true)
	await settle(8)
	expect(game.player.position == Layout.CAFE_SPAWN, "Blocked cafe save did not recover at cafe spawn")
	Input.action_press("move_down")
	await settle(42)
	Input.action_release("move_down")
	await settle(10)
	expect(game.current_area == "douar" and not game.transitioning, "Walking through cafe door did not return to village")
	expect(game.player.position.distance_to(Layout.CAFE_RETURN) < 45 and can_stand(game.player.position), "Cafe exit returned to wrong or blocked village position")
	expect(game.camera.limit_right == Layout.SQUARE_SIZE.x, "Leaving cafe did not restore village camera")
	# The village greengrocer occupies this coordinate; only cafe bodies must disappear.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = game.player.get_node("Feet").shape
	query.transform = Transform2D(0, Vector2(384, 186))
	query.collision_mask = 1
	var hidden_cafe_collision := false
	for hit: Dictionary in game.get_world_2d().direct_space_state.intersect_shape(query):
		hidden_cafe_collision = hidden_cafe_collision or game.cafe.is_ancestor_of(hit.collider)
	expect(not hidden_cafe_collision, "Hidden cafe furniture still collides in village")
	game.activate_area("cafe", Layout.CAFE_SPAWN)
	await settle()
	var day: int = game.state.day
	game.state.minute = 1550
	game.state.tick_seconds = 6.99
	await settle(70)
	expect(game.current_area == "farm" and game.state.day == day + 1 and not game.transitioning, "02:00 in cafe did not return home exactly once")
	game.activate_area("cafe", Layout.CAFE_SPAWN)
	game.menu_action("new_farm")
	expect(game.current_area == "farm" and game.state.day == 1 and game.state.coins == 100, "New farm did not leave cafe cleanly")
	game.queue_free()
	await settle()
	print("Cafe: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
