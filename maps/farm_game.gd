extends Node2D
## Runtime farming layer. The authored map and its builders stay reusable.
const FarmState = preload("res://maps/farm_state.gd")
const FarmHUD = preload("res://maps/farm_hud.gd")
const TILE := 32
const REACH := 58.0
const SAVE_PATH := "user://farm-save.json"
@export var persistence_enabled := true
var state := FarmState.new()
var hud: CanvasLayer
var soil: TileMapLayer
var crops: TileMapLayer
var channels: TileMapLayer
var channel_image: Image
var feedback: Node2D
var player: CharacterBody2D
var camera: Camera2D
var bed_edges: Dictionary = {}
var initial_beds: Dictionary = {}
var paused := false
var inactive := false
var transitioning := false
var save_blocked := false
var mouse_aim := false
var cooldown := 0.0
var toast_seconds := 0.0
var autosave_seconds := 0.0
var target := Vector2i(-1, -1)
var daylight: CanvasModulate
var action_flash := 0.0
var flash_cell := Vector2i.ZERO
var flash_color := Color.WHITE
var markers: Dictionary = {}

func _ready() -> void:
	TranslationServer.set_locale("ar_MA")
	soil = $Terrain/Soil
	crops = $Terrain/Crops
	channels = $Terrain/Saqya
	channel_image = (channels.tile_set.get_source(4) as TileSetAtlasSource).texture.get_image()
	player = $DepthSort/Player
	camera = player.get_node("FollowCamera")
	var map_size: Vector2i = get_meta("map_size_pixels", Vector2i(1280, 896))
	camera.limit_right = map_size.x
	camera.limit_bottom = map_size.y
	for cell in soil.get_used_cells():
		var uv := soil.get_cell_atlas_coords(cell)
		bed_edges[cell] = Vector2i(uv.x % 3, uv.y)
		var bed := FarmState.empty_bed()
		if crops.get_cell_source_id(cell) == 2:
			var crop_uv := crops.get_cell_atlas_coords(cell)
			bed.crop = "mint" if crop_uv.y == 0 else "tomato"
			bed.growth = FarmState.CROPS[bed.crop].stages[crop_uv.x]
		# The eight nursery cells are ready to plant on a new farm.
		if Rect2i(16, 9, 4, 2).has_point(cell):
			bed = FarmState.empty_bed()
		initial_beds[cell] = bed
	state.initialize(initial_beds)
	var loaded := false
	if persistence_enabled and FileAccess.file_exists(SAVE_PATH):
		loaded = state.load_file(SAVE_PATH)
		save_blocked = not loaded
	if loaded:
		player.position = state.player_position
		call_deferred("validate_spawn")
	for body in $DepthSort.get_children():
		if body.has_meta("pattern") and body.get_meta("pattern") in ["farmhouse", "hanout", "well"]:
			var rect: Rect2 = body.get_meta("footprint_local")
			markers[body.get_meta("pattern")] = body.position + Vector2(rect.get_center().x, rect.end.y + 14)
	daylight = CanvasModulate.new()
	daylight.name = "Daylight"
	add_child(daylight)
	feedback = Node2D.new()
	feedback.name = "FarmFeedback"
	feedback.z_index = 5
	feedback.draw.connect(draw_feedback)
	add_child(feedback)
	hud = FarmHUD.new()
	hud.name = "FarmHUD"
	add_child(hud)
	hud.tool_selected.connect(select_tool)
	hud.action_requested.connect(menu_action)
	localize_shop_sign()
	refresh_all()
	if save_blocked:
		show_toast(tr("Save could not be loaded. It has been kept. Pause > New farm to start over."), 12)
	else:
		show_toast(tr("Welcome back!") if loaded else tr("Your seeds are ready. Plant in the empty nursery left of the house, then water it."), 9)
	if persistence_enabled:
		get_tree().auto_accept_quit = false

func localize_shop_sign() -> void:
	# Cover only the baked Latin lettering; keep the sign's frame and ornaments.
	for body in $DepthSort.get_children():
		if body.get_meta("pattern", "") != "hanout":
			continue
		var artwork: Sprite2D = body.get_node("Artwork")
		var texture: AtlasTexture = artwork.texture
		var plate := ColorRect.new()
		plate.layout_direction = Control.LAYOUT_DIRECTION_LTR
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.add_child(plate)
		plate.position = Vector2(76, 98)
		plate.size = Vector2(72, 14)
		plate.color = texture.atlas.get_image().get_pixelv(Vector2i(texture.region.position) + Vector2i(76, 110))
		var sign: Label = hud.label(tr("The hanout"), 14)
		sign.name = "HanoutSign"
		plate.add_child(sign)
		sign.position = Vector2(0, -3)
		sign.size = Vector2(72, 20)
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func validate_spawn() -> void:
	await get_tree().physics_frame
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $DepthSort/Player/Feet.shape
	query.transform = Transform2D(0, player.position + Vector2(0, -8))
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		player.position = $PlayerSpawn.position

func _notification(what: int) -> void:
	if not is_instance_valid(hud):
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_progress()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and DisplayServer.get_name() != "headless":
		inactive = true
		player.controls_enabled = false
		save_progress()
		refresh_hud()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		inactive = false
		refresh_hud()

func _exit_tree() -> void:
	if is_instance_valid(player):
		save_progress()

func _process(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	action_flash = maxf(0, action_flash - delta)
	toast_seconds = maxf(0, toast_seconds - delta)
	if toast_seconds == 0:
		hud.toast_label.text = ""
	player.controls_enabled = not (paused or inactive or transitioning)
	if player.controls_enabled:
		var old_minute: int = state.minute
		if state.advance_time(delta):
			end_day(true)
		elif old_minute != state.minute:
			update_daylight()
			refresh_hud()
			if state.minute == 24 * 60:
				show_toast(tr("It is midnight. Head home to sleep before 02:00."), 7)
		autosave_seconds += delta
		if autosave_seconds >= 30:
			save_progress()
			autosave_seconds = 0
		target = aimed_cell()
		hud.set_context(context_hint(), player.get_global_transform_with_canvas().origin)
	else:
		hud.set_context(tr("Paused") if inactive else "", player.get_global_transform_with_canvas().origin)
	feedback.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if transitioning or inactive:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_ESCAPE:
			if paused:
				close_menu()
			else:
				open_pause()
			get_viewport().set_input_as_handled()
			return
		if paused:
			return
		if key >= KEY_1 and key <= KEY_4:
			select_tool(key - KEY_1)
		elif key == KEY_SPACE:
			mouse_aim = false
			use_tool(aimed_cell())
		elif key == KEY_E:
			interact()
		elif key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			mouse_aim = false
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not paused:
		mouse_aim = true
	elif event is InputEventMouseButton and event.pressed and not paused:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_aim = true
			use_tool(aimed_cell())
			get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			select_tool(posmod(state.selected_tool + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 4))
			get_viewport().set_input_as_handled()

func aimed_cell() -> Vector2i:
	if mouse_aim:
		return soil.local_to_map(soil.to_local(get_global_mouse_position()))
	var facing := Vector2.DOWN
	match player.facing:
		&"up": facing = Vector2.UP
		&"left": facing = Vector2.LEFT
		&"right": facing = Vector2.RIGHT
	return soil.local_to_map(soil.to_local(player.global_position + Vector2(0, -8) + facing * 28))

func can_reach(cell: Vector2i) -> bool:
	var center := soil.to_global(soil.map_to_local(cell))
	var origin := player.global_position + Vector2(0, -8)
	if origin.distance_to(center) > REACH:
		return false
	var query := PhysicsRayQueryParameters2D.create(origin, center, 1, [player.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func select_tool(index: int) -> void:
	if paused or transitioning:
		return
	state.selected_tool = clampi(index, 0, 3)
	refresh_hud()

func use_tool(cell: Vector2i) -> bool:
	if paused or inactive or transitioning or cooldown > 0:
		return false
	cooldown = 0.18
	if state.selected_tool == 2 and water_nearby() and not state.beds.has(cell):
		refill_can()
		return true
	if not state.beds.has(cell):
		show_toast(tr("Use the prepared brown beds. The nursery has space for seeds."))
		return false
	if not can_reach(cell):
		show_toast(tr("Walk closer to that bed."))
		return false
	var error := ""
	var success := ""
	var color := Color("daca7b")
	match state.selected_tool:
		0, 1:
			var crop := "mint" if state.selected_tool == 0 else "tomato"
			error = state.plant(cell, crop)
			success = tr("%s planted. Water it today.") % tr(FarmState.CROPS[crop].name)
		2:
			error = state.water_bed(cell)
			success = tr("Watered. This crop will grow overnight.")
			color = Color("71d9e3")
		3:
			var crop: String = state.beds[cell].crop
			error = state.harvest(cell)
			if error.is_empty():
				success = tr("+1 %s in your basket") % tr(FarmState.CROPS[crop].name)
			color = Color("c9e882")
	if not error.is_empty():
		show_toast(error)
		return false
	flash_cell = cell
	flash_color = color
	action_flash = 0.45
	refresh_cell(cell)
	refresh_hud()
	show_toast(success, 2.2)
	save_progress()
	return true

func near_marker(name_: String, distance: float = 52.0) -> bool:
	return markers.has(name_) and player.global_position.distance_to(markers[name_]) <= distance

func water_nearby() -> bool:
	if near_marker("well", 58):
		return true
	# Use visible water pixels, not the empty portions of a channel's tile.
	var origin := player.global_position + Vector2(0, -8)
	for offset in [Vector2(0, -34), Vector2(0, 34), Vector2(-34, 0), Vector2(34, 0), Vector2.ZERO]:
		var point := channels.to_local(origin + offset)
		var cell := channels.local_to_map(point)
		var sid := channels.get_cell_source_id(cell)
		if sid < 0:
			continue
		var uv := channels.get_cell_atlas_coords(cell) * TILE + Vector2i(posmod(int(point.x), TILE), posmod(int(point.y), TILE))
		var pixel := channel_image.get_pixelv(uv)
		if pixel.a > 0.5 and pixel.g > pixel.r * 1.3 and pixel.b > pixel.r * 1.3:
			return true
	return false

func interact() -> void:
	if paused or transitioning or cooldown > 0:
		return
	if near_marker("farmhouse", 64):
		open_sleep()
	elif near_marker("hanout", 58):
		open_shop()
	elif water_nearby():
		refill_can()
	else:
		var cell := aimed_cell()
		if state.is_ready(cell) and can_reach(cell):
			var previous: int = state.selected_tool
			state.selected_tool = 3
			use_tool(cell)
			state.selected_tool = previous
			refresh_hud()
		else:
			show_toast(tr("E: harvest a ripe crop, refill by water, visit the hanout, or sleep at your door."), 4)

func refill_can() -> void:
	state.refill()
	cooldown = 0.2
	refresh_hud()
	show_toast(tr("Watering can refilled: 40 / 40"))
	save_progress()

func context_hint() -> String:
	if near_marker("farmhouse", 64):
		return tr("E  /  Sleep until tomorrow")
	if near_marker("hanout", 58):
		return tr("E  /  Hanout: seeds and harvest")
	if state.beds.has(target):
		return state.describe(target) if can_reach(target) else tr("Walk closer to this bed")
	if water_nearby():
		return tr("E  /  Refill your watering can")
	return ""

func refresh_cell(cell: Vector2i) -> void:
	var uv: Vector2i = bed_edges[cell]
	if state.beds[cell].watered:
		uv.x += 3
	soil.set_cell(cell, 5, uv)
	var stage: int = state.stage(cell)
	if stage < 0:
		crops.erase_cell(cell)
	else:
		crops.set_cell(cell, 2, Vector2i(stage, 0 if state.beds[cell].crop == "mint" else 1))

func refresh_all() -> void:
	for cell: Vector2i in state.beds:
		refresh_cell(cell)
	refresh_hud()
	update_daylight()

func refresh_hud() -> void:
	if is_instance_valid(hud):
		hud.refresh(state, paused or inactive or transitioning)

func update_daylight() -> void:
	var dusk := clampf(float(state.minute - 17 * 60) / (4 * 60), 0, 1)
	daylight.color = Color.WHITE.lerp(Color("7e88b0"), dusk)

func show_toast(message: String, duration: float = 3.0) -> void:
	hud.toast_label.text = message
	toast_seconds = duration

func save_progress() -> bool:
	if not persistence_enabled or save_blocked:
		return false
	state.player_position = player.position
	var error := state.save_file(SAVE_PATH)
	if error != OK:
		push_warning("Farm save failed: " + error_string(error))
		if is_instance_valid(hud):
			show_toast(tr("Could not save. Your farm is still open; try saving again from Pause."), 8)
	return error == OK

func set_paused(value: bool) -> void:
	paused = value
	player.controls_enabled = not (paused or inactive or transitioning)
	player.velocity = Vector2.ZERO
	refresh_hud()

func close_menu() -> void:
	hud.close_modal()
	set_paused(false)

func open_pause() -> void:
	set_paused(true)
	hud.show_modal(tr("A moment in the douar"), tr("WASD / arrows: move.  1-4: select a tool.\nClick / Space: use.  E: interact.\nMint: 4 watered nights, one harvest.\nTomato: 11 nights, then 4 to regrow.\nYour farm saves automatically."), [[tr("Continue"), "close"], [tr("Save farm"), "save"], [tr("New farm..."), "new_confirm"]])

func open_sleep() -> void:
	set_paused(true)
	var dry := 0
	for cell: Vector2i in state.beds:
		if state.beds[cell].crop != "" and not state.is_ready(cell) and not state.beds[cell].watered:
			dry += 1
	hud.show_modal(tr("Sleep until tomorrow?"), tr("%d growing crops still need water.\nOnly watered crops will grow tonight.\nYou will wake up at 06:00.") % dry, [[tr("Sleep and save"), "sleep"], [tr("Keep working"), "close"]])

func open_shop() -> void:
	set_paused(true)
	hud.show_modal(tr("The hanout"), shop_text(), [[tr("5 mint seeds  /  25 coins"), "buy_mint"], [tr("5 tomato seeds  /  50 coins"), "buy_tomato"], [tr("Sell harvest  /  Mint 15, Tomato 35"), "sell"], [tr("Back to the farm"), "close"]])

func shop_text() -> String:
	return tr("Coins: %d\nBasket: %d mint / %d tomatoes\nSeeds: %d mint / %d tomato") % [state.coins, state.inventory.mint, state.inventory.tomato, state.inventory.mint_seed, state.inventory.tomato_seed]

func menu_action(action: String) -> void:
	match action:
		"pause":
			if not transitioning:
				open_pause()
		"close": close_menu()
		"sleep":
			close_menu()
			end_day(false)
		"save":
			var saved := save_progress()
			hud.modal_detail.text = tr("Farm saved.") if saved else tr("Could not save. If the old save is unreadable, start a new farm to replace it.")
		"new_confirm":
			hud.show_modal(tr("Start a new farm?"), tr("This replaces your saved farm, crops and inventory."), [[tr("Keep my farm"), "close"], [tr("Start fresh"), "new_farm"]])
		"new_farm":
			state = FarmState.new()
			state.initialize(initial_beds)
			save_blocked = false
			player.position = $PlayerSpawn.position
			close_menu()
			refresh_all()
			save_progress()
			show_toast(tr("A fresh start! Plant your first seeds in the empty nursery."), 6)
		"buy_mint", "buy_tomato":
			var error: String = state.buy_seeds(action.trim_prefix("buy_"))
			hud.modal_detail.text = shop_text() + "\n" + (tr("Seeds added to your bag.") if error.is_empty() else error)
			refresh_hud()
			save_progress()
		"sell":
			var earned: int = state.sell_harvest()
			hud.modal_detail.text = shop_text() + "\n" + (tr("Sold for %d coins.") % earned if earned > 0 else tr("Your basket is empty."))
			refresh_hud()
			save_progress()

func end_day(forced: bool) -> void:
	if transitioning:
		return
	transitioning = true
	player.controls_enabled = false
	player.velocity = Vector2.ZERO
	hud.close_modal()
	paused = false
	refresh_hud()
	var fade := create_tween()
	fade.tween_property(hud.day_fade, "color:a", 1.0, 0.35)
	await fade.finished
	var summary: Dictionary = state.next_day()
	player.position = $PlayerSpawn.position
	refresh_all()
	save_progress()
	var dawn := create_tween()
	dawn.tween_property(hud.day_fade, "color:a", 0.0, 0.45)
	await dawn.finished
	transitioning = false
	player.controls_enabled = not inactive
	refresh_hud()
	show_toast((tr("02:00 - time to rest. ") if forced else "") + tr("Day %d: %d crops grew; %d waited for water.") % [state.day, summary.grown, summary.missed], 7)

func draw_feedback() -> void:
	if not is_instance_valid(player) or paused or inactive or transitioning:
		return
	if state.beds.has(target):
		var color := Color("f6e2a0") if can_reach(target) else Color("dc8168")
		feedback.draw_rect(Rect2(Vector2(target * TILE) + Vector2(1, 1), Vector2(30, 30)), Color(color, 0.12), true)
		feedback.draw_rect(Rect2(Vector2(target * TILE) + Vector2(1, 1), Vector2(30, 30)), color, false, 2)
	if action_flash > 0:
		var center := Vector2(flash_cell * TILE) + Vector2(16, 16)
		for i in 4:
			var offset := Vector2(-9 + i * 6, -12 - (0.45 - action_flash) * 36)
			feedback.draw_rect(Rect2(center + offset, Vector2(3, 5)), Color(flash_color, action_flash / 0.45))
