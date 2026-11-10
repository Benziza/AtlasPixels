extends StaticBody2D
## A small world prop; mirror only the artwork, never the Arabic lettering.
@export var destination := "Douar square"
@export_enum("Left:-1", "Right:1") var direction: int = 1

func _ready() -> void:
	$Artwork.flip_h = direction < 0
	$Name.text = tr(destination)
	$Name.position.x = -40 if direction > 0 else -32
