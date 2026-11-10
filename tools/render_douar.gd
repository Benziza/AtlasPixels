extends "res://tools/render_cafe.gd"
## Real-engine overview and gameplay detail captures; no player save is touched.

func render() -> void:
	root.size = Vector2i(1280, 896)
	var game: Node2D = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.activate_area("douar", Vector2(696, 550))
	game.state.minute = 600
	game.inactive = false
	game.toast_seconds = 0
	game.hud.toast_label.text = ""
	game.refresh_all()
	game.set_process(false)
	game.set_physics_process(false)
	game.player.controls_enabled = false
	game.hud.visible = false
	game.camera.zoom = Vector2.ONE
	game.camera.force_update_scroll()
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	await capture("res://.godot/qa/douar-bakery-overview.png")
	game.camera.zoom = Vector2(2, 2)
	game.player.position = Vector2(200, 336)
	game.camera.force_update_scroll()
	await capture("res://.godot/qa/bakery-in-game.png")
	game.activate_area("farm", Vector2(1392, 404))
	game.camera.force_update_scroll()
	await capture("res://.godot/qa/douar-direction-in-game.png")
	game.queue_free()
	await process_frame
	quit()
