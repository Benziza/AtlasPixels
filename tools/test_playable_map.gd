extends SceneTree
## Engine-level movement/collision regression checks. Run headlessly.
var farm: Node2D
var player: CharacterBody2D
var failures: Array[String] = []
var checks := 0
const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

func _initialize() -> void:
	call_deferred("run_tests")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func settle(count: int = 2) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func release_all() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func teleport(pos: Vector2) -> void:
	release_all()
	player.velocity = Vector2.ZERO
	player.global_position = pos
	await settle()

func walk(actions: Array, ticks: int) -> Vector2:
	for action: String in actions:
		Input.action_press(action)
	await settle(ticks)
	var result := player.global_position
	release_all()
	await settle()
	return result

func can_stand(pos: Vector2) -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = (player.get_node("Feet") as CollisionShape2D).shape
	params.transform = Transform2D(0.0, pos + Vector2(0, -8))
	params.collision_mask = 1
	params.exclude = [player.get_rid()]
	return player.get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()

func obstacle(pattern: String, cell: Vector2i) -> StaticBody2D:
	for body in get_nodes_in_group("obstacles"):
		if body.get_meta("pattern") == pattern and body.get_meta("cell") == cell:
			return body as StaticBody2D
	return null

func footprint(body: StaticBody2D) -> Rect2:
	var rect: Rect2 = body.get_meta("footprint_local")
	return Rect2(rect.position + body.global_position, rect.size)

func check_access() -> void:
	# Four-neighbor 8px search using the player's actual physics shape.
	var targets: Dictionary = {
		Vector2i(40, 44): "hanout approach",
		Vector2i(30, 68): "left fields via bridge",
		Vector2i(90, 84): "central fields via bridge",
		Vector2i(142, 68): "right fields via bridge"
	}
	var queue: Array[Vector2i] = [Vector2i(108, 44)]
	var seen: Dictionary = {Vector2i(108, 44): true}
	var index := 0
	while index < queue.size() and not targets.is_empty():
		var current := queue[index]
		index += 1
		targets.erase(current)
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + offset
			if next.x < 1 or next.x > 159 or next.y < 2 or next.y > 111 or seen.has(next):
				continue
			seen[next] = true
			if can_stand(Vector2(next * 8)):
				queue.append(next)
	expect(targets.is_empty(), "Unreachable destinations: " + str(targets.values()))
	print("Reachability: explored %d walkable samples." % queue.size())

func run_tests() -> void:
	farm = load("res://main.tscn").instantiate() as Node2D
	root.add_child(farm)
	player = farm.get_node("DepthSort/Player") as CharacterBody2D
	await settle(3)
	expect(player != null, "Player missing from default main scene")
	expect(farm.get_node("DepthSort").y_sort_enabled, "Depth sorting disabled")
	expect(can_stand(player.global_position), "Spawn overlaps an obstacle")
	expect(get_nodes_in_group("obstacles").size() >= 80, "Missing scene obstacles")
	var sprite := player.get_node("Visual/Sprite") as AnimatedSprite2D

	await teleport(Vector2(800, 400))
	var right_start := player.position
	Input.action_press("move_right")
	await settle(30)
	var cardinal_distance := player.position.distance_to(right_start)
	expect(sprite.animation == &"walk_right", "Right walk animation missing")
	release_all()
	await settle()
	expect(sprite.animation == &"idle_right", "Idle did not retain facing")
	expect(absf(cardinal_distance - 72.0) < 5.0, "Unexpected walking speed: " + str(cardinal_distance))
	await teleport(Vector2(800, 400))
	var diagonal := await walk(["move_right", "move_up"], 30)
	expect(absf(diagonal.distance_to(Vector2(800, 400)) - cardinal_distance) < 3.0, "Diagonal movement is faster")
	expect(sprite.animation == &"idle_up", "Diagonal facing did not settle")

	await teleport(Vector2(864, 336))
	var house_stop := await walk(["move_up"], 60)
	expect(house_stop.y >= 294 and house_stop.y < 310, "Walked through farmhouse or hit wrong footprint: " + str(house_stop))
	expect(sprite.animation == &"idle_up", "Blocked character keeps walking")
	await teleport(Vector2(328, 388))
	var shop_stop := await walk(["move_up"], 60)
	expect(shop_stop.y >= 326 and shop_stop.y < 346, "Hanout collision failed: " + str(shop_stop))

	await teleport(Vector2(176, 432))
	var water_stop := await walk(["move_down"], 60)
	expect(water_stop.y < 480 and water_stop.y >= 440, "Unbridged saqya is walkable: " + str(water_stop))
	for start in [Vector2(240, 424), Vector2(720, 552), Vector2(1136, 424)]:
		expect(can_stand(start), "Bridge approach is obstructed: " + str(start))
		await teleport(start)
		var end := await walk(["move_down"], 60)
		expect(end.y - start.y > 132, "Bridge blocks downward crossing: " + str(start) + " -> " + str(end))
		var back := await walk(["move_up"], 60)
		expect(absf(back.y - start.y) < 4, "Bridge blocks upward crossing: " + str(start))
	await teleport(Vector2(240, 480))
	var bridge_side := await walk(["move_right"], 30)
	expect(bridge_side.x < 254, "Walked sideways off bridge into water")

	var tree := obstacle("fig_tree", Vector2i(14, 2))
	var tree_rect := footprint(tree)
	expect(not can_stand(tree_rect.get_center() + Vector2(0, 8)), "Tree trunk is not solid")
	expect(can_stand(tree.position + Vector2(-40, -60)), "Tree canopy blocks walking")
	await teleport(Vector2(tree.position.x, tree_rect.end.y + 48))
	var tree_stop := await walk(["move_up"], 60)
	expect(tree_stop.y >= tree_rect.end.y + 15 and tree_stop.y <= tree_rect.end.y + 18, "Tree trunk collision failed: " + str(tree_stop))

	var rock_rect := footprint(obstacle("rocks", Vector2i(14, 11)))
	expect(not can_stand(rock_rect.get_center() + Vector2(0, 8)), "Rock is not solid")
	await teleport(Vector2(rock_rect.position.x - 40, rock_rect.get_center().y + 8))
	var rock_stop := await walk(["move_right"], 50)
	expect(rock_stop.x <= rock_rect.position.x - 7.5, "Walked through rock")

	var fence_rect := footprint(obstacle("fence_horizontal", Vector2i(2, 24)))
	await teleport(Vector2(fence_rect.get_center().x, fence_rect.end.y + 38))
	var fence_stop := await walk(["move_up"], 40)
	expect(fence_stop.y >= fence_rect.end.y + 15, "Walked through horizontal fence")
	var vertical_rect := footprint(obstacle("fence_vertical", Vector2i(1, 18)))
	await teleport(Vector2(20, vertical_rect.get_center().y + 8))
	var vertical_stop := await walk(["move_right"], 40)
	expect(vertical_stop.x <= vertical_rect.position.x - 7.5, "Walked through vertical fence")

	await teleport(Vector2(700, 868))
	expect((await walk(["move_down"], 60)).y <= 896.1, "Escaped bottom of map")
	await teleport(Vector2(24, 545))
	expect((await walk(["move_left"], 60)).x >= 7.9, "Escaped left of map")
	await teleport(Vector2(1250, 530))
	expect((await walk(["move_right"], 60)).x <= 1272.1, "Escaped right of map")
	await teleport(Vector2(800, 40))
	expect((await walk(["move_up"], 60)).y >= 15.9, "Escaped top of map")
	await teleport(Vector2(864, 352))
	check_access()
	release_all()
	print("Playable farm: %d checks, %d failures." % [checks, failures.size()])
	if failures.is_empty():
		print("PASS: movement, diagonal speed, facing, solid obstacles, all bridges both ways, bridge edges, map bounds and connected paths.")
	quit(0 if failures.is_empty() else 1)
