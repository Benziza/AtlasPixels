extends SceneTree
## Redraws, obstacle changes, text layout and feedback visibility in the live scene.
var game: Node2D
var checks := 0
var failures: Array[String] = []
var feedback_draws := 0
var dial_draws := 0
var water_draws := 0

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

func run_tests() -> void:
	root.size = Vector2i(1280, 896)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.player.position = Vector2(528, 344)
	game.player.facing = &"up"
	game.mouse_aim = false
	await settle()
	game.feedback.draw.connect(func(): feedback_draws += 1)
	game.hud.dial.draw.connect(func(): dial_draws += 1)
	game.hud.water_meter.draw.connect(func(): water_draws += 1)
	await settle(10)
	expect(feedback_draws == 0, "Stationary targeting keeps redrawing")
	game.player.facing = &"down"
	await settle()
	expect(game.feedback_target == Vector2i(-1, -1) and feedback_draws > 0, "Leaving a bed did not clear the outline")
	game.player.facing = &"up"
	await settle()
	expect(game.feedback_target == Vector2i(16, 9), "Turning back did not restore the target")
	for i in 4:
		game.select_tool(i)
		await settle()
	expect(dial_draws == 0 and water_draws == 0, "Tool selection redraws unchanged meters")
	game.state.water -= 1
	game.refresh_hud()
	await settle()
	expect(water_draws == 1 and dial_draws == 0, "Water changes did not update only the gauge")
	game.state.minute += 10
	game.refresh_hud()
	await settle()
	expect(dial_draws == 1, "Time changes did not update the dial")
	game.open_pause()
	await settle()
	expect(not game.feedback.visible and not game.hud.hint_panel.visible, "Pause left farm feedback visible")
	expect(dial_draws == 2, "Pause indicator did not update")
	game.close_menu()
	await settle()
	expect(game.feedback.visible and game.hud.hint_panel.visible, "Resume lost farm feedback")
	game.inactive = true
	await settle()
	expect(not game.feedback.visible, "Inactive window left farm feedback visible")
	game.inactive = false
	await settle()
	expect(game.feedback.visible, "Restoring focus lost farm feedback")
	# A new obstacle must invalidate reach even while the player and target stay still.
	var obstacle := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 6)
	collision.shape = shape
	obstacle.add_child(collision)
	obstacle.position = Vector2(528, 320)
	game.add_child(obstacle)
	await settle()
	expect(game.hud.hint_label.text == tr("Walk closer to this bed"), "New obstacle left the reach hint stale")
	expect(feedback_draws > 0, "New obstacle did not update the outline")
	game.select_tool(0)
	expect(not game.use_tool(Vector2i(16, 9)), "Tool reached through a new obstacle")
	obstacle.queue_free()
	await settle(15)
	expect(game.use_tool(Vector2i(16, 9)), "Removing the obstacle did not restore planting")
	await settle(4)
	var animated_draws := feedback_draws
	await settle(4)
	expect(feedback_draws > animated_draws, "Planting flash stopped animating")
	await settle(30)
	expect(game.action_flash == 0 and game.feedback_flash == 0, "Finished flash was not cleared")
	var settled_draws := feedback_draws
	await settle(5)
	expect(feedback_draws == settled_draws, "Finished flash keeps redrawing")
	game.activate_area("douar", Vector2(192, 400))
	await settle()
	expect(not game.feedback.visible, "Farm outline leaked into the village")
	game.activate_area("farm", Vector2(528, 344))
	await settle()
	expect(game.feedback.visible, "Farm feedback did not return after travel")
	# Isolate HUD layout while keeping its normal process and layout notifications.
	game.set_process(false)
	var hud: CanvasLayer = game.hud
	hud.set_context("E", Vector2(500, 400))
	var short_width: float = hud.hint_panel.size.x
	hud.set_context(tr("E  /  Hanout: seeds and harvest"), Vector2(500, 400))
	expect(hud.hint_panel.size.x > short_width, "Changed hint text kept its old width")
	hud.set_context("E", Vector2(500, 400))
	hud.hint_label.add_theme_font_size_override("font_size", 30)
	await settle()
	hud.set_context("E", Vector2(500, 400))
	expect(hud.hint_panel.size.x > short_width, "Font change did not invalidate hint width")
	hud.hint_label.add_theme_font_size_override("font_size", 20)
	hud.set_context("E", Vector2(500, 400))
	var position_before: Vector2 = hud.hint_panel.position
	hud.set_context("E", Vector2(600, 400))
	expect(hud.hint_panel.position.x == position_before.x + 100, "Cached hint stopped following the player")
	root.size = Vector2i(960, 720)
	await settle()
	hud.set_context("E", Vector2(950, 600))
	expect(hud.hint_panel.get_rect().end.x <= hud.screen.size.x - 11, "Hint did not clamp after resizing")
	game.show_toast("One\nTwo\nThree\nFour")
	await settle()
	var tall_height: float = hud.toast_panel.size.y
	game.show_toast("One")
	await settle()
	expect(hud.toast_panel.size.y < tall_height, "Shorter toast kept the previous height")
	game.open_pause()
	game.show_toast("One\nTwo\nThree\nFour\nFive")
	await settle()
	expect(not hud.toast_panel.visible, "Modal did not hide the toast")
	game.close_menu()
	await settle()
	expect(hud.toast_panel.visible and hud.toast_panel.size.y > tall_height, "Hidden toast did not resize when shown again")
	game.show_toast("")
	await settle()
	expect(not hud.toast_panel.visible, "Empty toast stayed visible")
	game.queue_free()
	await settle()
	print("Interface: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
