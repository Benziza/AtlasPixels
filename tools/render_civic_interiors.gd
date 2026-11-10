extends "res://tools/render_cafe.gd"
## Capture the actual furnished rooms, with the normal HUD and player.

func render() -> void:
	root.size = Vector2i(1280, 896)
	var game: Node2D = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.state.minute = 600
	game.inactive = false
	game.toast_seconds = 0
	game.hud.toast_label.text = ""
	game.set_process(false)
	game.set_physics_process(false)
	game.player.controls_enabled = false
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	for area in ["caidat", "hospital"]:
		game.activate_area(area, Vector2(320, 344))
		game.refresh_all()
		game._process(0)
		await capture("res://.godot/qa/%s-interior-in-game.png" % area)
	game.queue_free()
	await process_frame
	quit()
