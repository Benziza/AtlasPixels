extends CharacterBody2D
## Top-down movement. The farming controller can lock input for menus and sleep.
@export_range(32.0, 320.0, 1.0) var walk_speed: float = 144.0
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
var facing: StringName = &"down"
var controls_enabled := true

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down") if controls_enabled else Vector2.ZERO
	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			facing = &"right" if direction.x > 0.0 else &"left"
		else:
			facing = &"down" if direction.y > 0.0 else &"up"
	velocity = direction * walk_speed
	move_and_slide()
	var moving := get_position_delta().length_squared() > 0.001
	var animation := StringName(("walk_" if moving else "idle_") + str(facing))
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)
