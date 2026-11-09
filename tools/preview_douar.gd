extends SceneTree
## Interactive village preview using the gameplay camera and a separate save.
const Layout = preload("res://maps/world_layout.gd")
const PREVIEW_SAVE := "res://.godot/qa/interactive-village-save.json"
var game: Node2D

func _initialize() -> void:
	call_deferred("launch")

func launch(preview_path: String = PREVIEW_SAVE, source_path: String = "user://farm-save.json") -> void:
	var has_preview := FileAccess.file_exists(preview_path)
	var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(preview_path.get_base_dir()))
	if result == OK and not has_preview and FileAccess.file_exists(source_path):
		result = DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(preview_path))
	if result != OK:
		push_error("Could not prepare the preview save: " + error_string(result))
		quit(1)
		return
	game = load("res://main.tscn").instantiate()
	game.save_path = preview_path
	root.add_child(game)
	if not has_preview:
		game.activate_area("douar", Layout.SQUARE_SPAWN)
	# Inherit FollowCamera's zoom; a playable preview must not force map-overview zoom.
	game.camera.force_update_scroll()
	game.show_toast(tr("Welcome to the douar square.") if game.current_area == "douar" else tr("Welcome back!"), 8)
	root.title = "AtlasPixels — Douar local preview"
	if DisplayServer.get_name() != "headless":
		var usable := DisplayServer.screen_get_usable_rect()
		var fit := minf(1.0, minf((usable.size.x - 64.0) / 1280.0, (usable.size.y - 80.0) / 896.0))
		root.size = Vector2i(Vector2(1280, 896) * fit)
		DisplayServer.window_set_position(usable.position + (usable.size - root.size) / 2)
	print("Local douar preview ready. Camera zoom: ", game.camera.zoom)
