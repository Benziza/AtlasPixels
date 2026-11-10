extends StaticBody2D
## A small world prop; mirror only the artwork, never the Arabic lettering.
@export var destination := "Douar square"
@export_enum("Left:-1", "Right:1", "Up:2", "Down:-2") var direction: int = 1

func _ready() -> void:
	$Artwork.flip_h = direction < 0
	$Name.text = tr(destination)
	$Name.position.x = -40 if direction > 0 else -32
	if absi(direction) == 2:
		# Vertical routes use a rectangular board and an independent compass arrow.
		$Artwork.texture = preload("res://assets/village/notice-sign.tres")
		$Artwork.flip_h = false
		$Artwork.position = Vector2(0, -48)
		$Artwork.scale = Vector2(128, 96) / $Artwork.texture.get_size()
		$Name.position = Vector2(-28, -84)
		$Name.size = Vector2(80, 32)
		var arrow := Polygon2D.new()
		arrow.name = "CompassArrow"
		arrow.polygon = PackedVector2Array([Vector2(-3, 10), Vector2(3, 10), Vector2(3, -2), Vector2(8, -2), Vector2(0, -11), Vector2(-8, -2), Vector2(-3, -2)])
		arrow.position = Vector2(-44, -68)
		arrow.scale.y = 1 if direction == 2 else -1
		arrow.color = Color("5b2b19")
		add_child(arrow)
