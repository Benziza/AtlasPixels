extends Node2D
## A single-screen cafe assembled from separate furniture, with solid footprints.
const Layout = preload("res://maps/world_layout.gd")
const ASSETS := "res://assets/interiors/cafe/"
const COUNTER_SPOT := Vector2(384, 236)
const CHECKERS_SPOT := Vector2(500, 378)
const RUST := Color("a84f2d")
const DARK := Color("65331f")
const TEAL := Color("397e77")
@onready var depth: Node2D = $DepthSort

func _ready() -> void:
	set_meta("map_size_pixels", Layout.CAFE_SIZE)
	$PlayerSpawn.position = Layout.CAFE_SPAWN
	# Wall decorations sit behind all moving characters.
	art(self, "arched-window", Vector2(136, 102), Vector2(76, 74))
	art(self, "arched-window", Vector2(522, 102), Vector2(72, 70))
	art(self, "wall-lantern", Vector2(232, 98), Vector2(20, 42))
	art(self, "wall-lantern", Vector2(464, 98), Vector2(20, 42))
	art(self, "wall-radio", Vector2(590, 92), Vector2(42, 34))
	art(self, "woven-rug", Vector2(136, 280), Vector2(176, 132))
	prop("TeaCabinet", "tea-cabinet", Vector2(320, 142), Vector2(72, 82), Rect2(-32, -20, 64, 20))
	prop("EspressoMachine", "espresso-machine", Vector2(412, 142), Vector2(60, 72), Rect2(-26, -20, 52, 20))
	prop("Banquette", "banquette", Vector2(136, 208), Vector2(120, 96), Rect2(-56, -34, 112, 34))
	prop("SalonTable", "tea-table", Vector2(136, 260), Vector2(46, 48), Rect2(-21, -26, 42, 26))
	prop("PoufLeft", "leather-pouf", Vector2(84, 262), Vector2(30, 32), Rect2(-14, -20, 28, 20))
	prop("PoufRight", "leather-pouf", Vector2(188, 262), Vector2(30, 32), Rect2(-14, -20, 28, 20))
	var counter := solid("Counter", Vector2(384, 208), Rect2(-120, -42, 240, 42))
	for x in [-80, 0, 80]:
		art(counter, "service-counter", Vector2(x, 0), Vector2(80, 64))
	art(counter, "tea-tray", Vector2(-56, -48), Vector2(40, 36))
	art(counter, "bread-basket", Vector2(64, -48), Vector2(36, 30))
	prop("TeaTable", "tea-table", Vector2(136, 352), Vector2(50, 54), Rect2(-23, -32, 46, 32))
	prop("CheckersTable", "checkers-table", Vector2(500, 352), Vector2(50, 56), Rect2(-23, -32, 46, 32))
	for x in [92, 180, 456, 544]:
		prop("Chair%d" % x, "chair-south", Vector2(x, 354), Vector2(28, 44), Rect2(-12, -22, 24, 22))
	for point in [Vector2(54, 150), Vector2(584, 210), Vector2(244, 412), Vector2(396, 412)]:
		prop("MintPot%d" % int(point.x), "mint-pot", point, Vector2(34, 40), Rect2(-13, -16, 26, 16))
	solid("NorthWall", Vector2.ZERO, Rect2(0, 0, 640, 112))
	solid("WestWall", Vector2.ZERO, Rect2(0, 0, 24, 448))
	solid("EastWall", Vector2.ZERO, Rect2(616, 0, 24, 448))
	solid("SouthWestWall", Vector2.ZERO, Rect2(24, 424, 264, 24))
	solid("SouthEastWall", Vector2.ZERO, Rect2(352, 424, 264, 24))
	solid("ThresholdBoundary", Vector2.ZERO, Rect2(288, 448, 64, 24))
	var front := Node2D.new()
	front.name = "FrontWall"
	front.z_index = 5
	front.draw.connect(func():
		for rect in [Rect2(16, 424, 272, 24), Rect2(352, 424, 272, 24)]:
			front.draw_rect(rect, DARK)
			front.draw_rect(rect.grow(-3), RUST)
			front.draw_rect(Rect2(rect.position + Vector2(3, 2), Vector2(rect.size.x - 6, 4)), Color("e9a05c"))
	)
	add_child(front)
	# Static wall art and the rug must render behind depth-sorted furniture/player.
	move_child(depth, get_child_count() - 1)

func art(parent: Node, id: String, bottom: Vector2, size_: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(ASSETS + id + ".tres")
	sprite.centered = false
	sprite.position = bottom - Vector2(size_.x / 2, size_.y)
	sprite.scale = size_ / sprite.texture.get_size()
	parent.add_child(sprite)
	return sprite

func solid(name_: String, point: Vector2, footprint: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = name_
	body.position = point
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("footprint_local", footprint)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = footprint.size
	collision.shape = shape
	collision.position = footprint.get_center()
	body.add_child(collision)
	depth.add_child(body)
	return body

func prop(name_: String, id: String, point: Vector2, size_: Vector2, footprint: Rect2) -> void:
	art(solid(name_, point, footprint), id, Vector2.ZERO, size_)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(Layout.CAFE_SIZE)), Color("302323"))
	# Quiet tiled floor, with small teal accents and a contrasting entrance.
	for y in range(112, 448, 24):
		for x in range(24, 616, 24):
			var color := Color("dca36b") if (x / 24 + y / 24) % 3 == 0 else Color("e5b27b")
			draw_rect(Rect2(x, y, 24, 24), Color("ba8156"))
			draw_rect(Rect2(x + 1, y + 1, 22, 22), color)
			if (x / 24) % 7 == 2 and (y / 24) % 5 == 2:
				draw_rect(Rect2(x + 10, y + 6, 4, 12), TEAL)
				draw_rect(Rect2(x + 6, y + 10, 12, 4), TEAL)
	for y in range(424, 448, 8):
		for x in range(288, 352, 8):
			draw_rect(Rect2(x, y, 8, 8), Color("f3ddb2") if (x / 8 + y / 8) % 2 == 0 else TEAL)
	draw_rect(Rect2(16, 16, 608, 96), Color("efbb73"))
	draw_rect(Rect2(16, 16, 608, 12), DARK)
	draw_rect(Rect2(20, 18, 600, 7), RUST)
	for x in range(24, 616, 24):
		draw_rect(Rect2(x, 100, 24, 12), Color("f4dda5"))
		draw_rect(Rect2(x + 8, 100, 8, 12), TEAL)
		draw_rect(Rect2(x + 4, 104, 16, 4), TEAL)
	for x in [16, 616]:
		draw_rect(Rect2(x, 16, 8, 408), DARK)
		draw_rect(Rect2(x + 2, 20, 4, 404), RUST)
		for y in range(24, 420, 24):
			draw_rect(Rect2(x + 2, y, 4, 2), Color("eda35c"))
