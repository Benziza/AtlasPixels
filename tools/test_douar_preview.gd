extends "res://tools/preview_douar.gd"
## Exercise the real preview launcher with isolated save fixtures.
const TEST_SAVE := "res://.godot/qa/preview-zoom-test-save.json"
const TEST_SOURCE := "res://.godot/qa/preview-zoom-test-source.json"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for _i in range(4):
		await physics_frame
		await process_frame

func run_tests() -> void:
	root.size = Vector2i(1280, 896)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVE.get_base_dir()))
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var source_game: Node2D = load("res://main.tscn").instantiate()
	source_game.persistence_enabled = false
	root.add_child(source_game)
	source_game.state.day = 4
	source_game.state.inventory.mint = 5
	var original := JSON.stringify(source_game.state.to_data())
	var file := FileAccess.open(TEST_SOURCE, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	source_game.queue_free()
	await settle()
	launch(TEST_SAVE, TEST_SOURCE)
	await settle()
	expect(game.current_area == "douar", "First preview launch did not open the douar")
	expect(game.camera.zoom == Vector2(2, 2), "Preview changed gameplay zoom to a map overview")
	expect(root.get_camera_2d() == game.camera, "Preview is not using the player's follow camera")
	expect(game.state.day == 4 and game.state.inventory.mint == 5, "Preview did not copy existing progress")
	expect(game.save_path == TEST_SAVE, "Preview is not using a separate save")
	game.state.coins = 75
	game.activate_area("farm", Layout.FARM_RETURN)
	await settle()
	expect(game.camera.zoom == Vector2(2, 2), "Returning to the farm changed preview zoom")
	expect(game.save_progress(), "Preview progress could not be saved")
	game.queue_free()
	await settle()
	launch(TEST_SAVE, TEST_SOURCE)
	await settle()
	expect(game.current_area == "farm" and game.player.position == Layout.FARM_RETURN, "Relaunch lost the preview's current area or position")
	expect(game.state.coins == 75 and game.state.inventory.mint == 5, "Relaunch overwrote preview progress with the source save")
	expect(game.camera.zoom == Vector2(2, 2), "Relaunch changed the original camera zoom")
	game.activate_area("douar", Layout.SQUARE_SPAWN)
	await settle()
	expect(game.camera.zoom == Vector2(2, 2), "Entering the douar changed preview zoom")
	game.queue_free()
	await settle()
	expect(FileAccess.get_file_as_string(TEST_SOURCE) == original, "Preview modified the original save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SOURCE))
	print("Douar preview: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
