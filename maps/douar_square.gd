extends Node2D
## Standalone square art; the travel controller can mount it as another area.
func _ready() -> void:
	TranslationServer.set_locale("ar_MA")
	$AreaSign/Name.text = tr("Douar square")
	$DepthSort/Hanout/Artwork/SignPlate/Name.text = tr("The hanout")
	$DepthSort/Cafe/Artwork/Name.text = tr("Village cafe")
	$DepthSort/Greengrocer/Artwork/Name.text = tr("Greengrocer")
