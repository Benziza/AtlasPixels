extends SceneTree
## Render the actual game and its cafe menu for visual QA (requires a display).

func _initialize() -> void:
	call_deferred("render")

func capture(path: String) -> void:
	for _i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(path)
	assert(result == OK, "Could not save cafe render")
	print("Rendered: ", ProjectSettings.globalize_path(path))

func render() -> void:
	root.size = Vector2i(1280, 896)
	var game: Node2D = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.activate_area("cafe", Vector2(320, 304))
	game.state.minute = 600
	game.inactive = false
	game.toast_seconds = 0
	game.hud.toast_label.text = ""
	game.refresh_all()
	game._process(0)
	game.set_process(false)
	game.set_physics_process(false)
	game.player.controls_enabled = false
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	await capture("res://.godot/qa/cafe-in-game.png")
	game.open_cafe_menu()
	await capture("res://.godot/qa/cafe-menu.png")
	game.queue_free()
	await process_frame
	quit()
