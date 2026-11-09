extends SceneTree
## Follow-camera limits, screen-space HUD, and input while the world scrolls.
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

func settle(ticks: int = 3) -> void:
	for _i in ticks:
		await physics_frame
		await process_frame

func visible_world() -> Rect2:
	var inverse := root.get_canvas_transform().affine_inverse()
	return Rect2(inverse * Vector2.ZERO, root.get_visible_rect().size / game.camera.zoom)

func run_tests() -> void:
	root.size = Vector2i(1280, 896)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await settle()
	expect(root.get_camera_2d() == game.camera, "Player camera is not active")
	var clock_rect: Rect2 = game.hud.clock_label.get_global_rect()
	var toolbar_rect: Rect2 = game.hud.toolbar.get_global_rect()
	game.player.position = Vector2(800, 400)
	await settle()
	var before: Vector2 = game.camera.get_screen_center_position()
	Input.action_press("move_right")
	await settle(30)
	Input.action_release("move_right")
	await settle()
	expect(game.camera.get_screen_center_position().x > before.x + 60, "Camera did not follow walking")
	expect(game.hud.clock_label.get_global_rect() == clock_rect, "Clock moved with the world")
	expect(game.hud.toolbar.get_global_rect() == toolbar_rect, "Toolbar moved with the world")
	var map_size: Vector2i = game.get_meta("map_size_pixels")
	for point in [Vector2(8, 16), Vector2(map_size) - Vector2(8, 0), Vector2(map_size.x - 8, 16), Vector2(8, map_size.y)]:
		game.player.position = point
		await settle()
		var view := visible_world()
		expect(view.position.x >= -0.1 and view.position.y >= -0.1, "Camera showed outside the top/left boundary")
		expect(view.end.x <= map_size.x + 0.1 and view.end.y <= map_size.y + 0.1, "Camera showed outside the bottom/right boundary")
	game.player.position = Vector2(528, 344)
	game.player.facing = &"up"
	game.mouse_aim = false
	await settle()
	expect(game.aimed_cell() == Vector2i(16, 9), "Scrolling changed keyboard targeting")
	var screen_point: Vector2 = game.player.get_global_transform_with_canvas().origin
	expect(game.hud.hint_panel.visible, "Nearby crop hint disappeared")
	expect(absf(game.hud.hint_panel.get_global_rect().get_center().x - screen_point.x) <= 2, "Hint did not follow the player in screen space")
	game.player.position = Vector2(700, 868)
	await settle()
	expect(game.hud.toolbar_at_top, "Toolbar did not avoid the player at the bottom edge")
	game.player.position = Vector2(800, 400)
	await settle()
	expect(not game.hud.toolbar_at_top, "Toolbar did not return after leaving the bottom edge")
	game.queue_free()
	await settle()
	print("Camera: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
