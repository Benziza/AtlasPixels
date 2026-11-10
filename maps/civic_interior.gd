extends Node2D
## Two furnished civic rooms with independent physics and readable interaction spots.
const Layout = preload("res://maps/world_layout.gd")
const CAFE_ASSETS := "res://assets/interiors/cafe/"
const ASSETS := "res://assets/interiors/civic/"
const FONT = preload("res://assets/ui/fonts/readex-pro.ttf")
const DARK := Color("65331f")
const RUST := Color("a84f2d")
const TEAL := Color("397e77")
@export_enum("caidat", "hospital") var building := "caidat"
@onready var depth: Node2D = $DepthSort
var interactions: Array[Dictionary] = []

func _ready() -> void:
	set_meta("map_size_pixels", Layout.CIVIC_INTERIOR_SIZE)
	$PlayerSpawn.position = Layout.CIVIC_INTERIOR_SPAWN
	for x in [144, 520]:
		art(self, "arched-window", Vector2(x, 104), Vector2(72, 74), true)
	for x in [228, 412]:
		art(self, "wall-lantern", Vector2(x, 92), Vector2(18, 38), true)
	plaque(self, tr("Caidat") if building == "caidat" else tr("Hospital"), Rect2(264, 54, 112, 30), 18)
	if building == "caidat":
		furnish_caidat()
	else:
		furnish_hospital()
	for spec: Array in [
		["NorthWall", Rect2(0, 0, 640, 112)], ["WestWall", Rect2(0, 0, 24, 448)],
		["EastWall", Rect2(616, 0, 24, 448)], ["SouthWestWall", Rect2(24, 424, 264, 24)],
		["SouthEastWall", Rect2(352, 424, 264, 24)], ["ThresholdBoundary", Rect2(288, 448, 64, 24)]
	]:
		solid(spec[0], Vector2.ZERO, spec[1])
	var front := Node2D.new()
	front.name = "FrontWall"
	front.z_index = 5
	front.draw.connect(func():
		for rect in [Rect2(16, 424, 272, 24), Rect2(352, 424, 272, 24)]:
			front.draw_rect(rect, DARK)
			front.draw_rect(rect.grow(-3), RUST)
			front.draw_rect(Rect2(rect.position + Vector2(3, 2), Vector2(rect.size.x - 6, 4)), Color("e9a05c"))
		# Open doors stay at the sides of the clear 64-pixel threshold.
		var door_color := Color("246742") if building == "caidat" else Color("227f9d")
		for x in [280, 352]:
			front.draw_rect(Rect2(x, 402, 8, 46), DARK)
			front.draw_rect(Rect2(x + 2, 404, 4, 42), door_color)
			front.draw_rect(Rect2(x + 3, 426, 2, 4), Color("e9b94f"))
	)
	add_child(front)
	move_child(depth, get_child_count() - 1)

func furnish_caidat() -> void:
	art(self, "woven-rug", Vector2(180, 392), Vector2(168, 70), true)
	for x in [80, 168]:
		prop("Archive%d" % x, "archive-cabinet", Vector2(x, 176), Vector2(68, 100), Rect2(-30, -38, 60, 38))
	chair("ReceptionChair", Vector2(168, 208))
	reception(Vector2(168, 268))
	prop("WaitingBench", "banquette", Vector2(90, 388), Vector2(92, 74), Rect2(-43, -28, 86, 28), true)
	for x in [184, 248]:
		chair("WaitingChair%d" % x, Vector2(x, 388))
	chair("CaidChair", Vector2(488, 160))
	prop("CaidDesk", "office-desk", Vector2(488, 236), Vector2(128, 88), Rect2(-60, -42, 120, 42))
	prop("MoroccanFlag", "moroccan-flag", Vector2(578, 184), Vector2(28, 84), Rect2(-10, -12, 20, 12))
	art(self, "notice-board", Vector2(586, 100), Vector2(44, 44))
	for x in [456, 528]:
		chair("VisitorChair%d" % x, Vector2(x, 292))
	for x in [368, 600]:
		var rail := solid("SideRail%d" % x, Vector2(x, 324), Rect2(-4, -140, 8, 140))
		rail.draw.connect(func():
			rail.draw_rect(Rect2(-4, -160, 8, 160), DARK)
			rail.draw_rect(Rect2(-2, -158, 4, 156), Color("c28343"))
			for y in [-160, -8]:
				rail.draw_rect(Rect2(-6, y, 12, 12), DARK)
				rail.draw_rect(Rect2(-4, y + 2, 8, 8), Color("e7a45d"))
		)
	prop("LeftRailing", "office-railing", Vector2(396, 332), Vector2(60, 40), Rect2(-28, -12, 56, 12))
	prop("RightRailing", "office-railing", Vector2(580, 332), Vector2(48, 40), Rect2(-22, -12, 44, 12))
	plant(Vector2(48, 248))
	plant(Vector2(584, 400))
	interactions = [
		spot(Vector2(168, 300), tr("E  /  Reception"), tr("The reception register and stamps are ready for the douar's paperwork.")),
		spot(Vector2(80, 204), tr("E  /  Archives"), tr("The douar's files are sorted in the archive cabinets.")),
		spot(Vector2(488, 316), tr("E  /  Caid's office"), tr("The caid's office: a ledger, folders and seats for visitors."))
	]

func furnish_hospital() -> void:
	chair("DoctorChair", Vector2(108, 136))
	prop("ConsultationDesk", "office-desk", Vector2(108, 200), Vector2(104, 72), Rect2(-48, -34, 96, 34))
	for x in [76, 140]:
		chair("VisitorChair%d" % x, Vector2(x, 244))
	prop("ExaminationCouch", "exam-couch", Vector2(236, 216), Vector2(44, 88), Rect2(-20, -66, 40, 66))
	prop("ConsultationCurtain", "privacy-curtain", Vector2(280, 220), Vector2(28, 100), Rect2(-5, -78, 10, 78))
	prop("MedicineCabinet", "medicine-cabinet", Vector2(408, 168), Vector2(64, 82), Rect2(-28, -24, 56, 24))
	prop("Sink", "wall-sink", Vector2(568, 154), Vector2(42, 50), Rect2(-18, -20, 36, 20))
	chair("ReceptionChair", Vector2(200, 252))
	reception(Vector2(168, 316))
	for x in [88, 148, 208]:
		chair("WaitingChair%d" % x, Vector2(x, 400))
	plant(Vector2(48, 400))
	for x in [440, 552]:
		prop("Bed%d" % x, "hospital-bed", Vector2(x, 316), Vector2(56, 108), Rect2(-25, -82, 50, 82))
	for x in [392, 600]:
		prop("Bedside%d" % x, "bedside-cabinet", Vector2(x, 260), Vector2(28, 42), Rect2(-12, -22, 24, 22))
	prop("WardCurtain", "privacy-curtain", Vector2(496, 316), Vector2(34, 120), Rect2(-5, -96, 10, 96))
	prop("MedicalTrolley", "medical-trolley", Vector2(536, 408), Vector2(76, 68), Rect2(-34, -28, 68, 28))
	interactions = [
		spot(Vector2(168, 344), tr("E  /  Reception"), tr("The hospital register is here. The waiting chairs are beside the entrance.")),
		spot(Vector2(236, 248), tr("E  /  Consultation"), tr("A consultation desk and examination couch, with a curtain for privacy.")),
		spot(Vector2(440, 344), tr("E  /  Care room"), tr("Clean beds and bedside cabinets are ready in the care room.")),
		spot(Vector2(552, 344), tr("E  /  Care room"), tr("Clean beds and bedside cabinets are ready in the care room.")),
		spot(Vector2(456, 400), tr("E  /  Medical supplies"), tr("Fresh towels and a closed medical kit are stored on the trolley."))
	]

func spot(point: Vector2, hint: String, message: String) -> Dictionary:
	return {"point": point, "hint": hint, "message": message}

func near_interaction(point: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var distance := 40.0
	for entry: Dictionary in interactions:
		var next_distance: float = point.distance_to(entry.point)
		if next_distance <= distance:
			nearest = entry
			distance = next_distance
	return nearest

func reception(point: Vector2) -> void:
	var counter := solid("Reception", point, Rect2(-104, -36, 208, 36))
	for x in [-72, 0, 72]:
		art(counter, "service-counter", Vector2(x, 0), Vector2(72, 60), true)
	art(counter, "paperwork", Vector2(0, -46), Vector2(132, 37))
	plaque(counter, tr("Reception"), Rect2(-38, -30, 76, 24), 12)

func chair(name_: String, point: Vector2) -> void:
	prop(name_, "chair-south", point, Vector2(28, 44), Rect2(-12, -18, 24, 18), true)

func plant(point: Vector2) -> void:
	prop("Plant%d" % int(point.x), "mint-pot", point, Vector2(32, 38), Rect2(-12, -16, 24, 16), true)

func plaque(parent: Node, text_: String, rect: Rect2, font_size: int) -> void:
	var panel := Panel.new()
	panel.name = "Plaque"
	panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f5cb8b")
	style.border_color = DARK
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var label := Label.new()
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text = text_
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.language = "ar_MA"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", DARK)
	label.size = rect.size
	panel.add_child(label)

func art(parent: Node, id: String, bottom: Vector2, size_: Vector2, reuse: bool = false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load((CAFE_ASSETS if reuse else ASSETS) + id + ".tres")
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

func prop(name_: String, id: String, point: Vector2, size_: Vector2, footprint: Rect2, reuse: bool = false) -> void:
	art(solid(name_, point, footprint), id, Vector2.ZERO, size_, reuse)

func _draw() -> void:
	var clinical := building == "hospital"
	var plaster := Color("ffe1b8") if clinical else Color("efbb73")
	draw_rect(Rect2(Vector2.ZERO, Vector2(Layout.CIVIC_INTERIOR_SIZE)), Color("302323"))
	for y in range(112, 448, 24):
		for x in range(24, 616, 24):
			var color := Color("f4d3a5") if clinical else Color("e5b27b")
			if (x / 24 + y / 24) % 3 == 0:
				color = color.darkened(0.035)
			draw_rect(Rect2(x, y, 24, 24), Color("c6956a"))
			draw_rect(Rect2(x + 1, y + 1, 22, 22), color)
			if (x / 24) % 7 == 2 and (y / 24) % 5 == 2:
				draw_rect(Rect2(x + 10, y + 6, 4, 12), TEAL)
				draw_rect(Rect2(x + 6, y + 10, 12, 4), TEAL)
	draw_rect(Rect2(16, 16, 608, 96), plaster)
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
	if clinical:
		draw_circle(Vector2(320, 40), 10, Color("ad2b1b"))
		draw_circle(Vector2(324, 37), 8, plaster)
