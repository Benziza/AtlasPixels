extends SceneTree
const Layout = preload("res://maps/world_layout.gd")
var checks := 0
var failures: Array[String] = []
var square: Node2D
var player: CharacterBody2D

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
	query.shape = player.get_node("Feet").shape
	query.transform = Transform2D(0, point + Vector2(0, -8))
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	return square.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func run_tests() -> void:
	root.size = Vector2i(1280, 896)
	square = load("res://maps/douar_square.tscn").instantiate()
	root.add_child(square)
	player = load("res://characters/player.tscn").instantiate()
	player.position = square.get_node("PlayerSpawn").position
	square.get_node("DepthSort").add_child(player)
	var camera: Camera2D = player.get_node("FollowCamera")
	camera.limit_right = Layout.SQUARE_SIZE.x
	camera.limit_bottom = Layout.SQUARE_SIZE.y
	await settle()
	expect(square.get_node("Ground").get_used_cells().size() == 32 * 24, "Square ground is incomplete")
	expect(square.get_node("AreaSign/Name").text == "ساحة الدوار", "Square name is not localized")
	expect(square.get_node("DepthSort/Hanout/Artwork/SignPlate/Name").text == "الحانوت", "Square shop sign is not localized")
	expect(can_stand(player.position), "Square spawn overlaps an obstacle")
	expect(not can_stand(Vector2(-8, 416)), "Square has no western boundary")
	var house: StaticBody2D = square.get_node("DepthSort/House")
	var footprint: Rect2 = house.get_meta("footprint_local")
	expect(not can_stand(house.position + footprint.get_center() + Vector2(0, 8)), "House has no solid footprint")
	var targets := {Vector2i(32, 26): true, Vector2i(47, 30): true, Vector2i(36, 18): true, Vector2i(13, 19): true, Vector2i(2, 26): true}
	var queue: Array[Vector2i] = [Vector2i(7, 26)]
	var seen := {Vector2i(7, 26): true}
	var index := 0
	while index < queue.size() and not targets.is_empty():
		var cell := queue[index]
		index += 1
		targets.erase(cell)
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + offset
			if next.x < 1 or next.y < 1 or next.x >= 64 or next.y >= 48 or seen.has(next):
				continue
			seen[next] = true
			if can_stand(Vector2(next * 16)):
				queue.append(next)
	expect(targets.is_empty(), "Square landmarks are not connected: " + str(targets.keys()))
	Input.action_press("move_right")
	await settle(90)
	Input.action_release("move_right")
	await settle()
	expect(player.position.x > 300, "Western approach blocks walking into the square")
	square.queue_free()
	await settle()
	print("Douar square: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
