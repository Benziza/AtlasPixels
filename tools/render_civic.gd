extends "res://tools/render_cafe.gd"
const Layout = preload("res://maps/world_layout.gd")
## Capture the actual separate map and its two route signs without touching saves.

func render() -> void:
	root.content_scale_size = Vector2i(1280, 960)
	root.size = Vector2i(1280, 960)
	var game: Node2D = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.activate_area("civic", Vector2(512, 432))
	game.state.minute = 600
	game.inactive = false
	game.toast_seconds = 0
	game.hud.toast_label.text = ""
	game.refresh_all()
	game.set_process(false)
	game.set_physics_process(false)
	game.player.controls_enabled = false
	game.hud.visible = false
	game.camera.zoom = Vector2(1.25, 1.25)
	game.camera.force_update_scroll()
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	await capture("res://.godot/qa/civic-quarter-in-game.png")
	root.content_scale_size = Vector2i(1280, 896)
	root.size = Vector2i(1280, 896)
	game.camera.zoom = Vector2(2, 2)
	game.activate_area("douar", Vector2(656, 144))
	game.camera.force_update_scroll()
	await capture("res://.godot/qa/douar-north-exit.png")
	game.activate_area("civic", Layout.CIVIC_SPAWN)
	game.camera.force_update_scroll()
	await capture("res://.godot/qa/civic-south-exit.png")
	game.queue_free()
	await process_frame
	quit()
