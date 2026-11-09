extends SceneTree
## Walk across the old map edge, check the new perimeter, and reload both save layouts.
const FarmState = preload("res://maps/farm_state.gd")
const Layout = preload("res://maps/world_layout.gd")
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

func can_stand(point: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = game.player.get_node("Feet").shape
	query.transform = Transform2D(0, point + Vector2(0, -8))
	query.collision_mask = 1
	query.exclude = [game.player.get_rid()]
	return game.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func run_tests() -> void:
	root.size = Vector2i(1280, 896)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await settle()
	var ground: TileMapLayer = game.get_node("Terrain/Ground")
	expect(ground.get_used_cells().size() == 48 * 28, "Extended ground is incomplete")
	expect(game.state.beds.size() == 86, "Extension changed the existing farm beds")
	expect(game.camera.limit_right == Layout.FARM_SIZE.x, "Camera retained the old map boundary")
	var original: Node2D = load("res://maps/douar_farm_playable.tscn").instantiate()
	var original_ground: TileMapLayer = original.get_node("Terrain/Ground")
	var preserved := true
	for cell in original_ground.get_used_cells():
		preserved = preserved and ground.get_cell_atlas_coords(cell) == original_ground.get_cell_atlas_coords(cell)
	expect(preserved, "Original farm terrain was overwritten")
	original.free()
	game.player.position = Vector2(1240, 416)
	await settle()
	Input.action_press("move_right")
	await settle(95)
	Input.action_release("move_right")
	await settle()
	expect(game.player.position.x > 1440, "Old perimeter still blocks the eastern clearing")
	expect(can_stand(Vector2(1424, 720)), "New southern clearing is obstructed")
	expect(not can_stand(Vector2(1424, 480)), "New saqya water has no collision")
	game.player.position = Vector2(1512, 416)
	await settle()
	Input.action_press("move_right")
	await settle(30)
	Input.action_release("move_right")
	await settle()
	expect(game.player.position.x <= 1528.1, "Player escaped the new perimeter")
	game.state.player_position = Vector2(1460, 416)
	var data: Dictionary = game.state.to_data()
	var restored := FarmState.new()
	restored.initialize(game.initial_beds)
	expect(restored.restore(data) and restored.player_position == Vector2(1460, 416), "Save could not restore a position in the extension")
	data.player = [864, 352]
	expect(restored.restore(data), "Original farm save positions are no longer accepted")
	data.player = [1600, 416]
	expect(not restored.restore(data), "Save accepted a position outside the enlarged farm")
	game.queue_free()
	await settle()
	print("Farm extension: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
