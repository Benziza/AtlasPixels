extends SceneTree
## Run with: godot --headless --path . --script res://tools/test_darija.gd
const FarmState = preload("res://maps/farm_state.gd")
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

func settle() -> void:
	for _i in 4:
		await process_frame

func test_catalog() -> void:
	var catalog := load("res://translations/ar_MA.po") as Translation
	expect(catalog != null and catalog.get_locale() == "ar_MA", "Darija catalog did not load")
	if catalog == null:
		return
	var font := load("res://assets/ui/fonts/readex-pro.ttf") as FontFile
	font.allow_system_fallback = false
	var placeholders := RegEx.new()
	placeholders.compile("%[-+0 #]*[0-9]*(?:\\.[0-9]+)?[sdif]")
	var characters: Dictionary = {}
	for message: String in catalog.get_message_list():
		var translated := String(catalog.get_message(message))
		expect(not translated.is_empty() and translated != message, "Missing Darija translation: " + message)
		var expected_formats: Array[String] = []
		var actual_formats: Array[String] = []
		for match_ in placeholders.search_all(message):
			expected_formats.append(match_.get_string())
		for match_ in placeholders.search_all(translated):
			actual_formats.append(match_.get_string())
		expect(expected_formats == actual_formats, "Changed formatting placeholders: " + message)
		for character in translated:
			var code := character.unicode_at(0)
			if code >= 32 and not (code >= 0x2066 and code <= 0x2069):
				characters[code] = true
	for code: int in characters:
		expect(font.has_char(code), "Bundled font lacks character U+%04X" % code)
	# Cover literal tr() calls as well as the dynamically translated crop names.
	var calls := RegEx.new()
	calls.compile('tr\\("((?:[^"\\\\]|\\\\.)*)"\\)')
	for path in ["res://maps/farm_state.gd", "res://maps/farm_game.gd", "res://maps/farm_hud.gd", "res://maps/douar_square.gd", "res://maps/cafe_interior.gd"]:
		for call in calls.search_all(FileAccess.get_file_as_string(path)):
			var message: String = JSON.parse_string('"' + call.get_string(1) + '"')
			expect(not catalog.get_message(message).is_empty(), "Untranslated runtime message: " + message)
	for crop: String in FarmState.CROPS:
		expect(not catalog.get_message(FarmState.CROPS[crop].name).is_empty(), "Untranslated crop: " + crop)

func check_controls(parent: Node) -> void:
	for node in parent.get_children():
		if node is Control and parent is Control and node.is_visible_in_tree():
			expect(parent.get_global_rect().grow(4).encloses(node.get_global_rect()), "Control outside its parent: " + str(node.get_path()))
		if node is Label and not node.text.is_empty() and node.is_visible_in_tree():
			var lines: int = node.get_line_count()
			expect(node.get_visible_line_count() >= lines, "Clipped label: " + node.text)
			if node.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var font: Font = node.get_theme_font("font")
				var width := font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, node.get_theme_font_size("font_size")).x
				expect(width <= node.size.x + 1, "Label wider than its area: " + node.text)
		if node is Button and not node.text.is_empty() and node.is_visible_in_tree():
			var font: Font = node.get_theme_font("font")
			var width := font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, node.get_theme_font_size("font_size")).x
			var padding: float = node.get_theme_stylebox("normal").get_minimum_size().x
			expect(width <= node.size.x - padding, "Button text overflow: " + node.text)
		check_controls(node)

func test_scene() -> void:
	root.size = Vector2i(1280, 896)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await settle()
	expect(TranslationServer.get_locale() == "ar_MA", "Game did not start in Moroccan Darija")
	expect(game.hud.toast_label.text.contains("الزريعة"), "Welcome message is not in Darija")
	expect(game.hud.tools[0].tooltip_text.contains("النعناع"), "Tool tooltip is not in Darija")
	var signs := game.find_children("HanoutSign", "Label", true, false)
	expect(signs.size() == 1 and signs[0].text == "الحانوت", "Shop artwork still has an untranslated sign")
	expect(game.state.describe(Vector2i(3, 19)).contains("النعناع"), "Crop description leaked its internal English name")
	expect(game.state.describe(Vector2i(17, 21)).contains("مطيشة"), "Tomato description is not localized")
	check_controls(game.hud.screen)
	# Exercise all weekdays and both clock periods in the fixed-size HUD.
	game.set_paused(true)
	var times := [[360, "ص"], [720, "م"], [780, "م"], [1140, "م"], [1430, "م"], [1440, "ص"], [1560, "ص"]]
	for day in range(1, 8):
		game.state.day = day
		game.state.minute = times[day - 1][0]
		game.refresh_hud()
		await settle()
		expect(game.hud.clock_label.text.ends_with(times[day - 1][1]), "Wrong Arabic clock period")
		check_controls(game.hud.screen)
	game.open_pause()
	await settle()
	expect(game.hud.modal_detail.text.contains("كتتسجل بوحدها"), "Pause help is not in Darija")
	check_controls(game.hud.screen)
	game.close_menu()
	game.open_shop()
	game.menu_action("buy_mint")
	await settle()
	expect(game.state.coins == 75 and game.hud.modal_detail.text.contains("تزادت الزريعة"), "Localized shop purchase failed")
	check_controls(game.hud.screen)
	game.close_menu()
	game.open_sleep()
	await settle()
	expect(game.hud.modal_detail.text.contains("باقي خاصو الما"), "Sleep warning is not in Darija")
	check_controls(game.hud.screen)
	game.close_menu()
	game.open_pause()
	game.menu_action("save")  # Persistence is disabled: exercise the failure message safely.
	await settle()
	check_controls(game.hud.screen)
	game.menu_action("new_confirm")
	await settle()
	check_controls(game.hud.screen)
	game.close_menu()
	game.activate_area("cafe", Vector2(384, 236))
	game.open_cafe_menu()
	await settle()
	check_controls(game.hud.screen)
	game.menu_action("cafe_tea")
	await settle()
	check_controls(game.hud.screen)
	game.queue_free()
	await settle()

func run_tests() -> void:
	test_catalog()
	await test_scene()
	print("Darija: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
