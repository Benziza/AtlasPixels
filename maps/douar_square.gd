extends Node2D
## Standalone square art; the travel controller can mount it as another area.
func _ready() -> void:
	TranslationServer.set_locale("ar_MA")
	$DepthSort/Bakery/Name.text = tr("Bakery")
	$DepthSort/Cafe/Artwork/Name.text = tr("Village cafe")
	$DepthSort/Greengrocer/Artwork/Name.text = tr("Greengrocer")
