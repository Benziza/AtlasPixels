extends Node2D
## A separate outdoor area reached from the north path of the douar.
const CAIDAT_DOOR := Vector2(272, 408)
const HOSPITAL_DOOR := Vector2(752, 408)

func _ready() -> void:
	TranslationServer.set_locale("ar_MA")
	$DepthSort/Caidat/Name.text = tr("Caidat")
	$DepthSort/Hospital/Name.text = tr("Hospital")
