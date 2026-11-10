extends Node2D
## Standalone square art; the travel controller can mount it as another area.
func _ready() -> void:
	TranslationServer.set_locale("ar_MA")
	$DepthSort/Bakery/Name.text = tr("Bakery")
	$DepthSort/Cafe/Artwork/Name.text = tr("Village cafe")
	$DepthSort/Greengrocer/Artwork/Name.text = tr("Greengrocer")
	var north_sign: StaticBody2D = preload("res://maps/route_sign.tscn").instantiate()
	north_sign.name = "ToCivic"
	north_sign.position = Vector2(784, 160)
	north_sign.destination = "Caidat and hospital"
	north_sign.direction = 2
	$DepthSort.add_child(north_sign)
