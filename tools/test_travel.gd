extends SceneTree
## Real walking, isolated on-disk saves, legacy migration and overnight return.
const FarmState = preload("res://maps/farm_state.gd")
const Layout = preload("res://maps/world_layout.gd")
const Game = preload("res://main.tscn")
const TEST_SAVE := "res://.godot/qa/travel-test-save.json"
var game: Node2D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func settle(ticks: int = 3) -> void:
	for _i in ticks:
		await physics_frame
		await process_frame

func make_game(persistence: bool = true) -> Node2D:
	var instance: Node2D = Game.instantiate()
	instance.persistence_enabled = persistence
	instance.save_path = TEST_SAVE
	root.add_child(instance)
	return instance

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
	# Start with the pre-travel save format and exercise the actual startup loader.
	game = make_game(false)
	await settle()
	var legacy: Dictionary = game.state.to_data()
	legacy.version = 1
	legacy.erase("area")
	legacy.day = 3
	legacy.inventory.mint_seed = 14
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	game.queue_free()
	await settle()
	game = make_game()
	await settle()
	expect(not game.save_blocked and game.current_area == "farm" and game.state.day == 3, "Legacy farm save did not load")
	expect(game.state.inventory.mint_seed == 14 and game.state.to_data().version == FarmState.SAVE_VERSION, "Legacy inventory was lost during migration")
	game.player.position = Vector2(528, 344)
	game.player.facing = &"up"
	await settle()
	expect(game.use_tool(Vector2i(16, 9)), "Could not plant before travel")
	await settle(15)
	game.state.selected_tool = 2
	expect(game.use_tool(Vector2i(16, 9)), "Could not water before travel")
	game.player.position = Layout.FARM_RETURN
	await settle()
	var clock_rect: Rect2 = game.hud.clock_label.get_global_rect()
	Input.action_press("move_right")
	await settle(70)
	Input.action_release("move_right")
	await settle()
	expect(game.current_area == "douar" and not game.transitioning, "Walking east did not enter the square")
	expect(game.player.get_parent() == game.square.get_node("DepthSort"), "Player was not moved into square depth sorting")
	expect(game.camera.limit_right == Layout.SQUARE_SIZE.x, "Square retained the farm's camera boundary")
	expect(game.camera.limit_bottom == Layout.SQUARE_SIZE.y, "Square retained its old vertical camera boundary")
	expect(game.hud.clock_label.get_global_rect() == clock_rect, "Travel moved the HUD")
	expect(can_stand(Vector2(800, 240)), "Hidden farm collisions still block the square")
	expect(can_stand(Layout.SQUARE_SPAWN), "Hidden farm saqya still blocks the renovated square entrance")
	game.player.position = Layout.SQUARE_SPAWN
	expect(game.context_hint() == tr("Walk west to return to the farm."), "Return hint missed the renovated entrance")
	var seed_count: int = game.state.inventory.mint_seed
	game.state.selected_tool = 0
	await settle(15)
	expect(not game.use_tool(Vector2i(16, 9)) and game.state.inventory.mint_seed == seed_count, "Square tools mutated the hidden farm")
	game.player.position = game.square_markers.well + Vector2(0, 24)
	game.state.water = 0
	await settle(15)
	game.interact()
	expect(game.state.water == 40, "Square well did not refill the can")
	game.player.position = game.square_markers.hanout + Vector2(0, 20)
	await settle(15)
	game.interact()
	expect(game.paused and is_instance_valid(game.hud.modal), "Square hanout did not open")
	game.menu_action("buy_mint")
	expect(game.state.coins == 75 and game.state.inventory.mint_seed == seed_count + 5, "Square shop did not use the shared inventory")
	game.close_menu()
	# Save beyond the old 1024px square boundary, then reload the actual file.
	game.player.position = Vector2(1200, 512)
	expect(game.save_progress(), "Square progress could not be saved")
	var saved: Dictionary = game.state.to_data().duplicate(true)
	game.queue_free()
	await settle()
	game = make_game()
	await settle()
	expect(game.current_area == "douar" and game.player.position == Vector2(1200, 512), "Saved position in the expanded square did not load at startup")
	expect(game.state.inventory == saved.inventory and game.state.coins == saved.coins, "Reload lost the shared inventory or money")
	expect(game.state.to_data().beds == saved.beds, "Reload lost crops or moisture")
	game.player.position = Vector2(80, Layout.SQUARE_SPAWN.y)
	await settle()
	Input.action_press("move_left")
	await settle(70)
	Input.action_release("move_left")
	await settle()
	expect(game.current_area == "farm" and not game.transitioning and game.player.position.x > 1280, "Walking west did not return to the farm approach")
	expect(game.camera.limit_right == Layout.FARM_SIZE.x, "Return did not restore farm camera limits")
	expect(can_stand(Vector2(640, 500)), "Hidden square collisions still block the farm")
	expect(not can_stand(Vector2(112, 496)), "Returning to the farm did not restore its saqya collisions")
	game.player.position = Layout.FARM_EXIT.get_center()
	game.open_pause()
	await settle(30)
	expect(game.current_area == "farm" and not game.transitioning, "Pause did not block travel")
	game.player.position = Layout.FARM_RETURN
	game.close_menu()
	game.activate_area("douar", game.square.get_node("PlayerSpawn").position)
	var day: int = game.state.day
	game.state.minute = 1550
	game.state.tick_seconds = 6.99
	await settle(70)
	expect(game.current_area == "farm" and game.state.day == day + 1 and not game.transitioning, "02:00 in the square did not return home exactly once")
	expect(game.player.position == game.get_node("PlayerSpawn").position, "Overnight return missed the home spawn")
	expect(game.state.beds[Vector2i(16, 9)].growth == 1 and not game.state.beds[Vector2i(16, 9)].watered, "Travel disrupted daily crop growth")
	# The former entrance is now inside the oven; old saves must recover safely.
	game.activate_area("douar", Vector2(112, 416))
	game.save_progress()
	game.queue_free()
	await settle()
	game = make_game()
	await settle(6)
	expect(game.current_area == "douar" and game.player.position == game.square.get_node("PlayerSpawn").position, "Blocked square spawn did not recover at the square entrance")
	expect(game.state.inventory == saved.inventory and game.state.coins == saved.coins, "Renovating the village lost saved inventory or money")
	var invalid: Dictionary = game.state.to_data().duplicate(true)
	var validator := FarmState.new()
	validator.initialize(game.initial_beds)
	invalid.area = "unknown"
	expect(not validator.restore(invalid), "Unknown area was accepted")
	invalid.area = "douar"
	invalid.player = [1400, 416]
	expect(not validator.restore(invalid), "Square save accepted farm-sized coordinates")
	invalid.player = [112, 416]
	invalid.erase("area")
	expect(not validator.restore(invalid), "Version-2 save without an area was accepted")
	game.menu_action("new_farm")
	expect(game.current_area == "farm" and game.state.day == 1 and game.state.coins == 100, "New farm did not leave the square cleanly")
	game.queue_free()
	await settle()
	print("Travel: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
