extends "res://tools/preview_douar.gd"
## Full gameplay with a dedicated preview save, starting between the two buildings.

func _initialize() -> void:
	call_deferred("launch_civic")

func launch_civic() -> void:
	launch("res://.godot/qa/interactive-civic-save.json")
	if not is_instance_valid(game):
		return
	game.activate_area("civic", Vector2(512, 320))
	game.show_toast(tr("Welcome! The caidat is on the left and the hospital on the right."), 8)
	root.title = "AtlasPixels — Caidat et hopital local"
