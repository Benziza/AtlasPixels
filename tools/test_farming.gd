extends SceneTree
## Farming rules, persistence and actual scene/input integration.
const FarmState = preload("res://maps/farm_state.gd")
const TEST_SAVE := "res://.godot/qa/farming-test-save.json"
var checks := 0
var failures: Array[String] = []
var game: Node2D

func _initialize() -> void:
	call_deferred("run_tests")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func fixture() -> RefCounted:
	var farm := FarmState.new()
	farm.initialize({Vector2i(0, 0): FarmState.empty_bed(), Vector2i(1, 0): FarmState.empty_bed(), Vector2i(2, 0): FarmState.empty_bed()})
	return farm

func test_rules() -> void:
	var farm := fixture()
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	expect(not farm.plant(Vector2i(99, 99), "mint").is_empty(), "Planting outside a bed was accepted")
	expect(farm.inventory.mint_seed == 20, "Invalid planting spent seeds")
	expect(farm.plant(a, "mint").is_empty(), "Mint planting failed")
	expect(farm.inventory.mint_seed == 19 and farm.stage(a) == 0, "Planting did not consume exactly one seed / start at stage zero")
	expect(not farm.plant(a, "tomato").is_empty() and farm.inventory.tomato_seed == 20, "Occupied bed replaced / spent a seed")
	farm.next_day()
	expect(farm.beds[a].growth == 0 and farm.beds[a].crop == "mint", "Dry crop grew or died")
	expect(not farm.harvest(a).is_empty() and farm.inventory.mint == 0, "Immature crop was harvested")
	for age in range(1, 5):
		var water_before: int = farm.water
		expect(farm.water_bed(a).is_empty(), "Daily watering failed")
		expect(not farm.water_bed(a).is_empty() and farm.water == water_before - 1, "Double watering used water / succeeded")
		farm.next_day()
		expect(farm.beds[a].growth == age and not farm.beds[a].watered, "Night growth / moisture reset failed")
		expect(farm.is_ready(a) == (age == 4), "Mint ripened on the wrong day")
	farm.next_day()
	expect(farm.is_ready(a), "Ripe crop disappeared without harvesting")
	expect(farm.harvest(a).is_empty() and farm.inventory.mint == 1 and farm.beds[a].crop == "", "Mint harvest did not empty the bed / enter inventory")
	expect(not farm.harvest(a).is_empty() and farm.inventory.mint == 1, "Repeated harvest duplicated produce")
	expect(farm.water_bed(a).is_empty() and farm.plant(a, "mint").is_empty() and farm.beds[a].watered, "Water-before-planting lost moisture")
	farm.next_day()
	expect(farm.beds[a].growth == 1, "Pre-watered seed did not grow overnight")
	farm.water = 0
	expect(not farm.water_bed(a).is_empty() and not farm.beds[a].watered, "Empty can still watered")
	farm.refill()
	expect(farm.water == 40, "Can did not refill to 40")
	farm.inventory.tomato_seed = 0
	expect(not farm.plant(b, "tomato").is_empty(), "Planted without a seed")
	farm.inventory.tomato_seed = 1
	farm.plant(b, "tomato")
	for age in range(1, 12):
		farm.water_bed(b)
		farm.next_day()
		expect(farm.is_ready(b) == (age == 11), "Tomato ripened on wrong night %d" % age)
	expect(farm.harvest(b).is_empty() and farm.inventory.tomato == 1 and farm.beds[b].regrow == 4, "Tomato did not retain its plant for regrowth")
	farm.next_day()
	expect(farm.beds[b].regrow == 4, "Dry tomato regrew")
	for remaining in [3, 2, 1, 0]:
		farm.water_bed(b)
		farm.next_day()
		expect(farm.beds[b].regrow == remaining, "Tomato regrowth skipped / repeated a day")
	expect(farm.is_ready(b) and farm.harvest(b).is_empty() and farm.inventory.tomato == 2, "Second tomato harvest failed")
	farm.coins = 24
	var stock: int = farm.inventory.mint_seed
	expect(not farm.buy_seeds("mint").is_empty() and farm.inventory.mint_seed == stock, "Shop allowed purchase without money")
	farm.coins = 100
	expect(farm.buy_seeds("mint").is_empty() and farm.coins == 75 and farm.inventory.mint_seed == stock + 5, "Seed purchase has wrong stock / price")
	expect(farm.sell_harvest() == 85 and farm.inventory.mint == 0 and farm.inventory.tomato == 0 and farm.coins == 160, "Selling did not clear basket / add correct coins")
	expect(farm.sell_harvest() == 0 and farm.coins == 160, "Repeated selling duplicated coins")

func test_clock_and_save() -> void:
	var farm := fixture()
	expect(farm.clock_text() == "06:00", "New day did not start at 06:00")
	farm.advance_time(6.5)
	expect(farm.minute == 360, "Clock ticked too early")
	farm.advance_time(0.5)
	expect(farm.minute == 370 and is_zero_approx(farm.tick_seconds), "10 minutes did not take 7 seconds")
	expect(farm.advance_time(7.0 * 119) and farm.minute == 1560, "Day did not end after 14 real minutes")
	var rollover := fixture()
	expect(rollover.restore(farm.to_data()), "Save made during the 02:00 fade could not be restored")
	expect(rollover.advance_time(0), "Restored 02:00 save did not request a morning transition")
	farm.next_day()
	expect(farm.day == 2 and farm.minute == 360, "Day rollover failed")
	farm.minute = 24 * 60
	expect(farm.clock_text() == "00:00", "Clock displayed midnight incorrectly")
	farm.minute = 360
	farm.plant(Vector2i.ZERO, "tomato")
	farm.water_bed(Vector2i.ZERO)
	farm.selected_tool = 2
	farm.player_position = Vector2(528, 344)
	farm.advance_time(2.5)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	expect(farm.save_file(TEST_SAVE) == OK, "Save file could not be written")
	var loaded := fixture()
	expect(loaded.load_file(TEST_SAVE), "Save could not be loaded")
	expect(loaded.to_data() == farm.to_data(), "Save round trip lost crop, moisture, inventory, position or clock state")
	farm.coins = 123
	expect(farm.save_file(TEST_SAVE) == OK and loaded.load_file(TEST_SAVE) and loaded.coins == 123, "Atomic save could not replace an existing file")
	var before: Dictionary = loaded.to_data()
	var invalid: Dictionary = farm.to_data()
	invalid.beds[0].crop = "unknown"
	expect(not loaded.restore(invalid) and loaded.to_data() == before, "Bad crop data partially overwrote live state")
	invalid = farm.to_data()
	invalid.inventory.mint_seed = -1
	expect(not loaded.restore(invalid), "Negative inventory was accepted")
	invalid = farm.to_data()
	invalid.beds[1] = invalid.beds[0]
	expect(not loaded.restore(invalid), "Duplicate bed coordinates were accepted")
	invalid = farm.to_data()
	invalid.player = [INF, 2]
	expect(not loaded.restore(invalid), "Invalid player position was accepted")
	expect(not loaded.restore(null), "Malformed JSON was accepted")

func settle(ticks: int = 3) -> void:
	for _i in ticks:
		await physics_frame
		await process_frame

func press(key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()

func click_at(point: Vector2) -> void:
	# parse_input_event receives window pixels, including the headless 64px stretch.
	point = root.get_final_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await settle()
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()

func test_scene() -> void:
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await settle()
	expect(game.state.beds.size() == 86 and game.crops.get_used_cells().size() == 78, "Initial farm is missing beds / empty nursery")
	game.player.position = Vector2(528, 344)
	game.player.facing = &"up"
	game.mouse_aim = false
	await settle()
	expect(game.aimed_cell() == Vector2i(16, 9), "Keyboard did not aim at the adjacent front tile")
	expect(game.can_reach(Vector2i(16, 9)) and not game.can_reach(Vector2i(17, 21)), "Tool reach permits remote farming / rejects nearby bed")
	await press(KEY_1)
	await press(KEY_SPACE)
	expect(game.state.beds[Vector2i(16, 9)].crop == "mint" and game.state.inventory.mint_seed == 19, "Actual planting input did not update inventory / crop")
	expect(game.crops.get_cell_atlas_coords(Vector2i(16, 9)) == Vector2i(0, 0), "Seed sprite did not appear")
	await settle(15)
	await press(KEY_3)
	await press(KEY_SPACE)
	expect(game.state.beds[Vector2i(16, 9)].watered and game.state.water == 39, "Actual watering input failed")
	expect(game.soil.get_cell_atlas_coords(Vector2i(16, 9)).x == 3, "Wet edge tile did not replace dry edge tile")
	await settle(15)
	await press(KEY_SPACE)
	expect(game.state.water == 39, "Repeated input spent water twice on one day")
	await click_at(game.hud.tools[1].get_global_rect().get_center())
	expect(game.state.selected_tool == 1, "Clicking toolbar did not select tomato seeds")
	await settle(15)
	await click_at(Vector2(560, 304))
	expect(game.state.beds[Vector2i(17, 9)].crop == "tomato" and game.state.inventory.tomato_seed == 19, "Mouse click did not plant the nearby targeted bed")
	await settle(15)
	await click_at(Vector2(624, 304))
	expect(game.state.beds[Vector2i(19, 9)].crop == "" and game.state.inventory.tomato_seed == 19, "Distant click spent seeds / planted remotely")
	await press(KEY_ESCAPE)
	expect(game.paused and not game.player.controls_enabled and is_instance_valid(game.hud.modal), "Escape did not pause clock / movement and open menu")
	var current_minute: int = game.state.minute
	var current_ticks: float = game.state.tick_seconds
	game._process(10)
	expect(game.state.minute == current_minute and is_equal_approx(game.state.tick_seconds, current_ticks), "Clock advanced in menu")
	await press(KEY_ESCAPE)
	expect(not game.paused and game.player.controls_enabled, "Escape did not resume")
	game.player.position = game.markers.well + Vector2(0, 24)
	game.state.water = 0
	await settle(15)
	await press(KEY_E)
	expect(game.state.water == 40, "E did not refill at the well")
	game.player.position = Vector2(176, 456)
	await settle(15)
	expect(game.water_nearby(), "Saqya was not recognized as a water source")
	game.state.water = 0
	await press(KEY_E)
	expect(game.state.water == 40, "E did not refill at the saqya")
	game.player.position = game.markers.hanout + Vector2(0, 20)
	await settle(15)
	await press(KEY_E)
	expect(game.paused and is_instance_valid(game.hud.modal), "E did not open hanout")
	var shop_buttons: Array[Node] = game.hud.modal.find_children("*", "Button", true, false)
	await click_at(shop_buttons[0].get_global_rect().get_center())
	expect(game.state.inventory.mint_seed == 24 and game.state.coins == 75, "Hanout purchase did not reach game state")
	game.close_menu()
	game.player.position = game.markers.farmhouse + Vector2(0, 24)
	await settle(15)
	await press(KEY_E)
	expect(game.paused and game.hud.modal_detail.text.contains("باقي خاصو الما"), "Door did not offer sleep / dry-crop warning")
	game.menu_action("sleep")
	await settle(65)
	expect(game.state.day == 2 and game.state.beds[Vector2i(16, 9)].growth == 1, "Sleep did not advance watered crop exactly once")
	expect(not game.state.beds[Vector2i(16, 9)].watered and game.soil.get_cell_atlas_coords(Vector2i(16, 9)).x == 0, "Morning did not dry the soil visually")
	expect(game.state.beds[Vector2i(17, 12)].growth == 2, "Dry existing mint grew overnight")
	expect(game.player.position == game.get_node("PlayerSpawn").position and not game.transitioning, "Sleep did not return player to home / unlock input")
	game.player.position = Vector2(112, 648)
	game.player.facing = &"up"
	game.mouse_aim = false
	await settle()
	await press(KEY_4)
	await press(KEY_SPACE)
	expect(game.state.inventory.mint == 1 and game.crops.get_cell_source_id(Vector2i(3, 19)) == -1, "Harvest input did not remove mature mint / add to basket")
	game.state.minute = 1550
	game.state.tick_seconds = 6.99
	await settle(65)
	expect(game.state.day == 3 and game.state.minute == 360 and not game.transitioning, "02:00 did not trigger exactly one new morning")
	expect(game.state.beds[Vector2i(16, 9)].growth == 1, "Automatic night grew a dry crop")
	game.state.minute = 450
	game.state.tick_seconds = 1.0
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	# Headless mode intentionally ignores desktop focus events; test the pause state directly.
	game.inactive = true
	game._process(30)
	expect(game.state.minute == 450 and game.state.tick_seconds == 1.0 and not game.player.controls_enabled, "Inactive window did not pause clock / controls")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game._process(0)
	expect(not game.inactive and game.player.controls_enabled, "Window focus did not resume controls")
	game.queue_free()
	await settle()

func run_tests() -> void:
	test_rules()
	test_clock_and_save()
	await test_scene()
	print("Farming: %d checks, %d failures." % [checks, failures.size()])
	if failures.is_empty():
		print("PASS: planting, daily watering, growth, regrowth, harvest, clock, menus, refill, shop, save validation and scene input.")
	quit(0 if failures.is_empty() else 1)
