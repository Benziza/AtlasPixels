extends Node2D
## A walkable mini-market laid out from the approved design.
const Layout = preload("res://maps/world_layout.gd")
const FIXTURES = preload("res://assets/interiors/hanout/fixtures.png")
const KEEPER = preload("res://assets/characters/shopkeeper.png")
const COUNTER = preload("res://assets/interiors/cafe/service-counter.tres")
const WINDOW = preload("res://assets/interiors/cafe/arched-window.tres")
const LANTERN = preload("res://assets/interiors/cafe/wall-lantern.tres")
const RUG = preload("res://assets/interiors/cafe/woven-rug.tres")
const MINT_POT = preload("res://assets/interiors/cafe/mint-pot.tres")
const PROPS = preload("res://assets/tilesets/crops_and_props.png")
const ICONS = preload("res://assets/ui/icons.png")
const FONT = preload("res://assets/ui/fonts/readex-pro.ttf")
const CHECKOUT_FRONT := Rect2(474, 373, 126, 44)
const WOOD := Color("934926")
const DARK := Color("582c20")
const ZELLIGE := Color("337b72")
var keeper_sprite: Sprite2D
var jacket_label: Label
@onready var depth: Node2D = $DepthSort

func _ready() -> void:
	set_meta("map_size_pixels", Layout.HANOUT_SIZE)
	$PlayerSpawn.position = Layout.HANOUT_SPAWN
	art(self, WINDOW, Vector2(105, 99), Vector2(62, 60))
	art(self, WINDOW, Vector2(522, 99), Vector2(62, 60))
	for x in [198, 440]:
		art(self, LANTERN, Vector2(x, 101), Vector2(18, 36))
	art(self, RUG, Vector2(320, 432), Vector2(122, 68))
	move_child(depth, get_child_count() - 1)

	var fridge := solid("DrinkCoolers", Vector2(320, 151), Rect2(-90, -28, 180, 28))
	art(fridge, region(FIXTURES, Rect2(0, 0, 184, 112)), Vector2.ZERO, Vector2(184, 112))
	var seeds := solid("SeedAisle", Vector2(327, 250), Rect2(-118, -42, 236, 42))
	art(seeds, region(FIXTURES, Rect2(192, 0, 240, 92)), Vector2.ZERO, Vector2(240, 78))
	for x in [-78, -39, 0, 39]:
		var icon_x := 0 if x in [-78, 0] else 48
		art(seeds, region(ICONS, Rect2(icon_x, 0, 48, 48)), Vector2(x, -63), Vector2(32, 32))
	art(seeds, region(PROPS, Rect2(0, 64, 32, 32)), Vector2(80, -62), Vector2(30, 30))
	var pantry := solid("PantryAisle", Vector2(314, 359), Rect2(-118, -45, 236, 45))
	art(pantry, region(FIXTURES, Rect2(192, 96, 240, 104)), Vector2.ZERO, Vector2(240, 84))
	var produce := solid("Produce", Vector2(99, 224), Rect2(-66, -48, 132, 48))
	art(produce, region(FIXTURES, Rect2(0, 120, 136, 94)), Vector2.ZERO, Vector2(136, 88))
	var mint := region(PROPS, Rect2(64, 64, 32, 32))
	for x in [-43, 0, 43]:
		art(produce, mint, Vector2(x, -70), Vector2(40, 40))
	var stock := solid("StockRack", Vector2(550, 225), Rect2(-56, -34, 112, 34))
	art(stock, region(FIXTURES, Rect2(0, 220, 116, 110)), Vector2.ZERO, Vector2(116, 110))
	var pot := solid("MintPot", Vector2(70, 402), Rect2(-13, -16, 26, 16))
	art(pot, MINT_POT, Vector2.ZERO, Vector2(37, 43))

	var keeper := solid("Shopkeeper", Vector2(516, 312), Rect2(-13, -16, 26, 16))
	keeper_sprite = art(keeper, KEEPER, Vector2.ZERO, Vector2(72, 64))
	keeper_sprite.hframes = 2
	keeper_sprite.position.x = -18
	keeper_sprite.name = "Artwork"
	jacket_label = Label.new()
	jacket_label.name = "JacketLettering"
	jacket_label.text = tr("The shopkeeper back print")
	jacket_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	jacket_label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	jacket_label.text_direction = Control.TEXT_DIRECTION_RTL
	jacket_label.language = "ar_MA"
	jacket_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jacket_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	jacket_label.add_theme_font_override("font", FONT)
	# Render the two lines large, then scale to the jacket's pixel footprint.
	jacket_label.add_theme_font_size_override("font_size", 22)
	jacket_label.add_theme_constant_override("line_spacing", -12)
	jacket_label.add_theme_color_override("font_color", Color("f7f3e7"))
	jacket_label.position = Vector2(-13, -35)
	jacket_label.size = Vector2(104, 58)
	jacket_label.scale = Vector2(0.25, 0.25)
	jacket_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	jacket_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keeper.add_child(jacket_label)
	var checkout := solid("Checkout", Vector2(536, 360), Rect2(-65, -38, 130, 38))
	for x in [-33, 33]:
		art(checkout, COUNTER, Vector2(x, 0), Vector2(68, 60))
	art(checkout, region(FIXTURES, Rect2(144, 220, 36, 38)), Vector2(33, -43), Vector2(36, 38))

	solid("NorthWall", Vector2.ZERO, Rect2(0, 0, 640, 112))
	solid("WestWall", Vector2.ZERO, Rect2(0, 0, 24, 448))
	solid("EastWall", Vector2.ZERO, Rect2(616, 0, 24, 448))
	solid("SouthWestWall", Vector2.ZERO, Rect2(24, 424, 264, 24))
	solid("SouthEastWall", Vector2.ZERO, Rect2(352, 424, 264, 24))
	solid("ThresholdBoundary", Vector2.ZERO, Rect2(288, 448, 64, 24))
	face_customer(false)

func can_talk(point: Vector2) -> bool:
	return CHECKOUT_FRONT.has_point(point)

func face_customer(customer_present: bool) -> void:
	var frame := 0 if customer_present else 1
	if keeper_sprite.frame != frame:
		keeper_sprite.frame = frame
		jacket_label.visible = not customer_present

func region(texture: Texture2D, rectangle: Rect2) -> AtlasTexture:
	var item := AtlasTexture.new()
	item.atlas = texture
	item.region = rectangle
	item.filter_clip = true
	return item

func art(parent: Node, texture: Texture2D, bottom: Vector2, size_: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = bottom - Vector2(size_.x / 2.0, size_.y)
	sprite.scale = size_ / texture.get_size()
	parent.add_child(sprite)
	return sprite

func solid(node_name: String, point: Vector2, footprint: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = point
	body.collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = footprint.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = footprint.get_center()
	body.add_child(collision)
	depth.add_child(body)
	return body

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(Layout.HANOUT_SIZE)), Color("352520"))
	for y in range(112, 448, 24):
		for x in range(24, 616, 24):
			var width := mini(24, 616 - x)
			var color := Color("dca46d") if (x / 24 + y / 24) % 4 == 0 else Color("e6b783")
			draw_rect(Rect2(x, y, width, 24), Color("c89163"))
			draw_rect(Rect2(x + 1, y + 1, width - 1, 23), color)
	draw_rect(Rect2(16, 16, 608, 96), Color("efbf82"))
	draw_rect(Rect2(16, 16, 608, 12), DARK)
	draw_rect(Rect2(20, 20, 600, 4), WOOD)
	draw_rect(Rect2(24, 96, 592, 16), Color("f5dfa9"))
	for x in range(28, 605, 16):
		draw_rect(Rect2(x + 4, 98, 4, 12), ZELLIGE)
		draw_rect(Rect2(x, 102, 12, 4), ZELLIGE)
	for x in [16, 616]:
		draw_rect(Rect2(x, 16, 8, 416), DARK)
		draw_rect(Rect2(x + 2, 24, 4, 400), WOOD)
	for wall in [Rect2(16, 424, 272, 24), Rect2(352, 424, 272, 24)]:
		draw_rect(wall, DARK)
		draw_rect(wall.grow(-3), WOOD)
		draw_rect(Rect2(wall.position + Vector2(3, 3), Vector2(wall.size.x - 6, 4)), Color("edb06c"))
