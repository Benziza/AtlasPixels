extends "res://tools/preview_douar.gd"
## Start the full game inside the cafe, keeping the normal game save separate.

func _initialize() -> void:
	call_deferred("launch_cafe")

func launch_cafe() -> void:
	launch("res://.godot/qa/interactive-cafe-save.json")
	if not is_instance_valid(game):
		return
	game.activate_area("cafe", Layout.CAFE_SPAWN)
	game.show_toast(tr("Welcome to the cafe. Order at the counter, or relax by the tables."), 8)
	root.title = "AtlasPixels — Cafe local"
