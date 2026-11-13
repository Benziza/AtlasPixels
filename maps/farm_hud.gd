extends CanvasLayer
## Pixel HUD: live day dial, money, water and a twelve-slot inventory bar.
signal tool_selected(index: int)
signal action_requested(action: String)
const INK := Color("5b2b19")
const PAPER := Color("ffda91")
const WOOD := Color("a64d26")
const SLOT := 56
const BAR_WIDTH := SLOT * 12 + 24
var screen: Control
var clock_label: Label
var date_label: Label
var money_label: Label
var water_label: Label
var hint_label: Label
var toast_label: Label
var hint_panel: Control
var toast_panel: Control
var toolbar: Control
var water_meter: Control
var dial: Control
var period_icon: TextureRect
var tools: Array[Button] = []
var counts: Array[Label] = []
var produce_icons: Array[TextureRect] = []
var modal: Control
var modal_detail: Label
var day_fade: ColorRect
var font: FontFile
var atlas: Texture2D
var cached_selection := -1
var toolbar_at_top := false
var hint_width := -1.0
var toast_layout_dirty := true

class DarijaTooltip extends Label:
	func _init(message: String) -> void:
		text = message
		language = "ar_MA"
		text_direction = Control.TEXT_DIRECTION_RTL
		horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		theme_type_variation = "TooltipLabel"

class ToolButton extends Button:
	func _make_custom_tooltip(for_text: String) -> Object:
		return DarijaTooltip.new(for_text)

class WaterGauge extends Control:
	var value := 40.0:
		set(next):
			if value != next:
				value = next
				queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("78432a"))
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("a77649"))
		var width := floorf((size.x - 4) * clampf(value / 40, 0, 1))
		draw_rect(Rect2(2, 2, width, size.y - 4), Color("58b9c9"))
		draw_rect(Rect2(2, 2, width, 2), Color("a0e1df"))

class PixelFrame extends Control:
	var inset := false
	func _make_custom_tooltip(for_text: String) -> Object:
		return DarijaTooltip.new(for_text)
	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		# Every edge is aligned to the same two-pixel grid as the game art.
		draw_rect(Rect2(2, 4, size.x, size.y), Color(0.16, 0.07, 0.03, 0.35))
		var colors := [Color("592414"), Color("b45b28"), Color("efaa52"), Color("ffdf96"), Color("a9582e"), Color("f5c67e")]
		if inset:
			colors = [Color("78351d"), Color("ffd990"), Color("c88b51"), Color("f5c67e")]
		for i in colors.size():
			draw_rect(rect.grow(-i * 2), colors[i])
		if not inset:
			for p in [Vector2(4, 4), Vector2(size.x - 8, 4), Vector2(4, size.y - 8), size - Vector2(8, 8)]:
				draw_rect(Rect2(p, Vector2(4, 4)), Color("ffe9aa"))

class DayDial extends Control:
	var minute := 360:
		set(next):
			if minute != next:
				minute = next
				queue_redraw()
	var paused := false:
		set(next):
			if paused != next:
				paused = next
				queue_redraw()
	func _draw() -> void:
		var night := minute >= 19 * 60
		var center := Vector2(44, 44)
		for row in range(-21, 22):
			var half := floorf(sqrt(maxf(0, 21 * 21 - row * row)))
			draw_rect(Rect2(center + Vector2(-half * 2, row * 2), Vector2(half * 4 + 2, 2)), Color("65321f"))
		for row in range(-18, 19):
			var half := floorf(sqrt(maxf(0, 18 * 18 - row * row)))
			var sky := Color("566789") if night else Color("91c9d0")
			if row > 8:
				sky = Color("51624b") if night else Color("e4b66c")
			draw_rect(Rect2(center + Vector2(-half * 2, row * 2), Vector2(half * 4 + 2, 2)), sky)
		draw_rect(Rect2(26, 20, 12, 12), Color("fff1ba"))
		if night:
			draw_rect(Rect2(32, 18, 8, 10), Color("566789"))
			draw_rect(Rect2(56, 26, 2, 2), Color("fff1ba"))
			draw_rect(Rect2(20, 44, 2, 2), Color("fff1ba"))
		else:
			draw_rect(Rect2(42, 36, 18, 4), Color("e4f0dc"))
			draw_rect(Rect2(48, 32, 8, 4), Color("e4f0dc"))
		for i in 7:
			var angle := PI + i * PI / 6.0
			var p := Vector2(44, 62) + Vector2(cos(angle), sin(angle)) * 32
			draw_rect(Rect2((p / 2).round() * 2, Vector2(2, 4)), Color("775132"))
		var progress := clampf(float(minute - 360) / 1200.0, 0, 1)
		var angle := PI + progress * PI
		var tip := Vector2(44, 62) + Vector2(cos(angle), sin(angle)) * 30
		for i in 17:
			var p := (Vector2(44, 62).lerp(tip, i / 16.0) / 2).round() * 2
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(6, 6)), Color("804023"))
			draw_rect(Rect2(p, Vector2(2, 2)), Color("ffce61"))
		draw_rect(Rect2(40, 58, 8, 8), Color("fff0b1"))
		if paused:
			draw_rect(Rect2(36, 76, 4, 8), Color("fff0b1"))
			draw_rect(Rect2(46, 76, 4, 8), Color("fff0b1"))

func flat(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.anti_aliasing = false
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func label(text: String, font_size: int = 24, light: bool = false) -> Label:
	var item := Label.new()
	item.layout_direction = Control.LAYOUT_DIRECTION_LTR
	item.text = text
	item.language = "ar_MA"
	item.text_direction = Control.TEXT_DIRECTION_RTL
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item.add_theme_font_override("font", font)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", Color("fff1c4") if light else INK)
	if light:
		item.add_theme_color_override("font_outline_color", Color("57321e"))
		item.add_theme_constant_override("outline_size", 4)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

func anchor_rect(item: Control, preset: Control.LayoutPreset, rect: Rect2) -> void:
	item.set_anchors_preset(preset)
	item.offset_left = rect.position.x
	item.offset_top = rect.position.y
	item.offset_right = rect.end.x
	item.offset_bottom = rect.end.y

func frame(parent: Node, rect: Rect2, inset: bool = false) -> Control:
	var item := PixelFrame.new()
	item.layout_direction = Control.LAYOUT_DIRECTION_LTR
	item.position = rect.position
	item.size = rect.size
	item.inset = inset
	parent.add_child(item)
	item.resized.connect(item.queue_redraw)
	return item

func icon(index: int, parent: Node, rect: Rect2) -> TextureRect:
	var image := AtlasTexture.new()
	image.atlas = atlas
	image.region = Rect2((index % 4) * 48, (index / 4) * 48, 48, 48)
	var item := TextureRect.new()
	item.layout_direction = Control.LAYOUT_DIRECTION_LTR
	item.texture = image
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.position = rect.position
	item.size = rect.size
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func place_label(parent: Node, text: String, rect: Rect2, font_size: int = 24, light: bool = false) -> Label:
	var item := label(text, font_size, light)
	item.position = rect.position
	item.size = rect.size
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(item)
	return item

func button(text: String, action: String = "") -> Button:
	var item := ToolButton.new()
	item.layout_direction = Control.LAYOUT_DIRECTION_LTR
	item.text = text
	item.language = "ar_MA"
	item.text_direction = Control.TEXT_DIRECTION_RTL
	item.custom_minimum_size.y = 46
	item.add_theme_font_size_override("font_size", 24)
	item.add_theme_color_override("font_color", INK)
	item.add_theme_color_override("font_hover_color", INK)
	item.add_theme_color_override("font_pressed_color", INK)
	item.add_theme_color_override("font_focus_color", INK)
	item.add_theme_stylebox_override("normal", flat(Color("f1be78"), Color("a95c31")))
	item.add_theme_stylebox_override("hover", flat(Color("ffe2a0"), Color("c8793a")))
	item.add_theme_stylebox_override("pressed", flat(Color("eaa866"), Color("9d4326"), 4))
	item.add_theme_stylebox_override("focus", flat(Color(0, 0, 0, 0), Color("b64c29"), 2))
	if not action.is_empty():
		item.pressed.connect(func(): action_requested.emit(action))
	return item

func _ready() -> void:
	layer = 20
	atlas = load("res://assets/ui/icons.png")
	font = load("res://assets/ui/fonts/readex-pro.ttf").duplicate()
	font.allow_system_fallback = false
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	screen = Control.new()
	# Keep the map-aligned HUD and hotkey slots in place; text itself reads RTL.
	screen.layout_direction = Control.LAYOUT_DIRECTION_LTR
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(screen)
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 24
	theme.set_stylebox("panel", "TooltipPanel", flat(PAPER, WOOD, 3))
	theme.set_color("font_color", "TooltipLabel", INK)
	theme.set_font_size("font_size", "TooltipLabel", 24)
	screen.theme = theme
	build_clock()
	build_toolbar()
	hint_panel = frame(screen, Rect2(0, 0, 300, 42))
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.visible = false
	hint_label = place_label(hint_panel, "", Rect2(14, 6, 272, 30), 20)
	hint_label.theme_changed.connect(invalidate_hint_width)
	font.changed.connect(invalidate_hint_width)
	toast_panel = frame(screen, Rect2(0, 0, 660, 54))
	anchor_rect(toast_panel, Control.PRESET_CENTER_TOP, Rect2(-330, 18, 660, 54))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false
	toast_label = place_label(toast_panel, "", Rect2(14, 10, 632, 34), 22)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.minimum_size_changed.connect(func(): toast_layout_dirty = true)
	day_fade = ColorRect.new()
	day_fade.layout_direction = Control.LAYOUT_DIRECTION_LTR
	day_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	day_fade.color = Color(0.09, 0.08, 0.13, 0)
	day_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(day_fade)

func build_clock() -> void:
	var clock := frame(screen, Rect2(0, 0, 240, 120))
	anchor_rect(clock, Control.PRESET_TOP_RIGHT, Rect2(-258, 18, 240, 120))
	clock.tooltip_text = tr("The day runs from 6:00 am to 2:00 am.\nSleep at your front door to start tomorrow.")
	dial = DayDial.new()
	dial.layout_direction = Control.LAYOUT_DIRECTION_LTR
	dial.position = Vector2(12, 16)
	dial.size = Vector2(88, 88)
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.add_child(dial)
	frame(clock, Rect2(104, 10, 124, 34), true)
	date_label = place_label(clock, tr("Mon. 1"), Rect2(114, 12, 108, 30), 22)
	frame(clock, Rect2(104, 46, 44, 26), true)
	period_icon = icon(7, clock, Rect2(114, 46, 24, 24))
	var day_badge := frame(clock, Rect2(152, 46, 76, 26), true)
	place_label(day_badge, tr("Douar"), Rect2(8, 0, 62, 26), 20)
	frame(clock, Rect2(104, 76, 124, 32), true)
	clock_label = place_label(clock, tr("6:00 am"), Rect2(114, 76, 108, 32), 24)
	clock_label.text_direction = Control.TEXT_DIRECTION_LTR
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var money := frame(screen, Rect2(0, 0, 216, 38))
	anchor_rect(money, Control.PRESET_TOP_RIGHT, Rect2(-234, 142, 216, 38))
	money.tooltip_text = tr("Coins\nSell your harvest at the hanout.")
	icon(6, money, Rect2(10, 6, 24, 24))
	money_label = place_label(money, "100", Rect2(42, 4, 160, 30), 24)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.add_theme_color_override("font_color", Color("a53423"))
	var water := frame(screen, Rect2(0, 0, 178, 32))
	anchor_rect(water, Control.PRESET_TOP_RIGHT, Rect2(-234, 184, 178, 32))
	water.tooltip_text = tr("Watering can\nPress E at the well or saqya to refill.")
	icon(2, water, Rect2(6, 4, 24, 24))
	water_meter = WaterGauge.new()
	water_meter.layout_direction = Control.LAYOUT_DIRECTION_LTR
	water_meter.position = Vector2(36, 10)
	water_meter.size = Vector2(126, 12)
	water_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.add_child(water_meter)
	water_label = place_label(water, "40/40", Rect2(42, 0, 112, 32), 18, true)
	water_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pause_button := button("II", "pause")
	pause_button.custom_minimum_size = Vector2.ZERO
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.tooltip_text = tr("Pause / help (Esc)")
	for style_name in ["normal", "hover", "pressed", "focus"]:
		var style := pause_button.get_theme_stylebox(style_name).duplicate() as StyleBoxFlat
		style.content_margin_left = 2
		style.content_margin_right = 2
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		pause_button.add_theme_stylebox_override(style_name, style)
	screen.add_child(pause_button)
	anchor_rect(pause_button, Control.PRESET_TOP_RIGHT, Rect2(-50, 184, 32, 32))

func build_toolbar() -> void:
	toolbar = frame(screen, Rect2(0, 0, BAR_WIDTH, 80))
	anchor_rect(toolbar, Control.PRESET_CENTER_BOTTOM, Rect2(-BAR_WIDTH / 2, -96, BAR_WIDTH, 80))
	var tips := [tr("Mint seeds\n4 watered nights to grow.\nClick a bed or press Space to plant."), tr("Tomato seeds\n11 watered nights; regrows every 4.\nClick a bed or press Space to plant."), tr("Watering can\nWater a nearby bed once each day.\nE at the well / saqya refills the can."), tr("Harvest\nPick a ripe crop with Click, Space or E.")]
	for i in 12:
		var slot := button("")
		# Resolve inherited layout before setting fixed coordinates.
		toolbar.add_child(slot)
		slot.custom_minimum_size = Vector2.ZERO
		slot.position = Vector2(12 + i * SLOT, 12)
		slot.size = Vector2(SLOT, SLOT)
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if i < 4 else Control.CURSOR_ARROW
		if i < 4:
			slot.tooltip_text = tips[i]
			slot.pressed.connect(func(): tool_selected.emit(i))
			tools.append(slot)
			icon(i, slot, Rect2(4, 4, 48, 48))
			place_label(slot, str(i + 1), Rect2(4, -2, 16, 20), 16, true)
		elif i < 6:
			slot.tooltip_text = tr("Harvested mint - sell at the hanout") if i == 4 else tr("Harvested tomatoes - sell at the hanout")
			produce_icons.append(icon(i, slot, Rect2(4, 4, 48, 48)))
		else:
			slot.tooltip_text = tr("Empty inventory slot")
		if i < 6:
			var count := place_label(slot, "", Rect2(2, 30, 48, 24), 18, true)
			count.text_direction = Control.TEXT_DIRECTION_LTR
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			counts.append(count)

func _process(_delta: float) -> void:
	toast_panel.visible = not toast_label.text.is_empty() and not is_instance_valid(modal)
	if toast_panel.visible and toast_layout_dirty:
		toast_layout_dirty = false
		var height := maxf(54, toast_label.get_minimum_size().y + 24)
		toast_panel.size.y = height
		toast_label.size.y = height - 20
	if is_instance_valid(modal):
		hint_panel.visible = false

func invalidate_hint_width() -> void:
	hint_width = -1.0

func set_context(text: String, screen_point: Vector2) -> void:
	var should_move := screen_point.y > screen.size.y - 140 and absf(screen_point.x - screen.size.x / 2) < BAR_WIDTH / 2 + 40
	if should_move != toolbar_at_top:
		toolbar_at_top = should_move
		anchor_rect(toolbar, Control.PRESET_CENTER_TOP if toolbar_at_top else Control.PRESET_CENTER_BOTTOM, Rect2(-BAR_WIDTH / 2, 18 if toolbar_at_top else -96, BAR_WIDTH, 80))
		anchor_rect(toast_panel, Control.PRESET_CENTER_TOP, Rect2(-330, 110 if toolbar_at_top else 18, 660, toast_panel.size.y))
	if hint_label.text != text:
		hint_label.text = text
		invalidate_hint_width()
	hint_panel.visible = not text.is_empty() and not is_instance_valid(modal)
	if not hint_panel.visible:
		return
	if hint_width < 0:
		var hint_font := hint_label.get_theme_font("font")
		hint_width = minf(620, hint_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_label.get_theme_font_size("font_size")).x + 30)
		hint_panel.size = Vector2(hint_width, 42)
		hint_label.size = Vector2(hint_width - 28, 30)
	var viewport_size := screen.size
	hint_panel.position = Vector2(clampf(screen_point.x - hint_width / 2, 12, viewport_size.x - hint_width - 12), clampf(screen_point.y + 38, 12, viewport_size.y - 148)).round()

func refresh(state: RefCounted, paused: bool) -> void:
	var hour: int = (state.minute / 60) % 24
	var hour12 := hour % 12
	if hour12 == 0:
		hour12 = 12
	clock_label.text = "%d:%02d %s" % [hour12, state.minute % 60, tr("am") if hour < 12 else tr("pm")]
	clock_label.add_theme_color_override("font_color", Color("a22e22") if state.minute >= 24 * 60 else INK)
	var weekdays := [tr("Mon"), tr("Tue"), tr("Wed"), tr("Thu"), tr("Fri"), tr("Sat"), tr("Sun")]
	date_label.text = tr("%s. %d") % [weekdays[(state.day - 1) % 7], state.day]
	money_label.text = str(state.coins)
	water_meter.value = state.water
	water_label.text = "%d/40" % state.water
	dial.minute = state.minute
	dial.paused = paused
	period_icon.modulate = Color("949ebd") if state.minute >= 19 * 60 else Color.WHITE
	counts[0].text = str(state.inventory.mint_seed)
	counts[1].text = str(state.inventory.tomato_seed)
	counts[2].text = ""
	counts[3].text = ""
	counts[4].text = str(state.inventory.mint) if state.inventory.mint > 0 else ""
	counts[5].text = str(state.inventory.tomato) if state.inventory.tomato > 0 else ""
	produce_icons[0].visible = state.inventory.mint > 0
	produce_icons[1].visible = state.inventory.tomato > 0
	if cached_selection != state.selected_tool:
		cached_selection = state.selected_tool
		for i in 4:
			var selected: bool = i == state.selected_tool
			tools[i].add_theme_stylebox_override("normal", flat(Color("ffdb96") if selected else Color("f1be78"), Color("af3523") if selected else Color("c88b51"), 4 if selected else 2))
			tools[i].add_theme_stylebox_override("hover", flat(Color("ffe4ac"), Color("af3523") if selected else Color("c8793a"), 4 if selected else 2))

func close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null
	modal_detail = null

func show_modal(title: String, detail: String, actions: Array) -> void:
	close_modal()
	modal = Control.new()
	modal.layout_direction = Control.LAYOUT_DIRECTION_LTR
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(modal)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.08, 0.07, 0.04, 0.62)
	modal.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 520
	card.add_theme_stylebox_override("panel", flat(PAPER, WOOD, 6))
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	card.add_child(content)
	content.add_child(label(title, 32))
	modal_detail = label(detail, 24)
	modal_detail.custom_minimum_size.x = 490
	modal_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(modal_detail)
	for spec: Array in actions:
		var item := button(spec[0], spec[1])
		content.add_child(item)
		if content.get_child_count() == 3:
			item.grab_focus()
