extends KinematicBody2D

export var speed := 90.0
export var gravity := 900.0

onready var sprite := $Sprite
onready var anim := $AnimationPlayer

var velocity := Vector2.ZERO


func _physics_process(delta: float) -> void:
	var direction := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	velocity.x = direction * speed
	velocity.y += gravity * delta
	velocity = move_and_slide(velocity, Vector2.UP)

	if direction != 0.0:
		# Mirror with scale rather than flip_h: the sprite carries a non-zero
		# offset to centre the art in its 32px cell, and flip_h would mirror
		# the art inside that cell while leaving the offset put, shifting the
		# character sideways on every turn. Scaling mirrors about the origin.
		sprite.scale.x = -1.0 if direction < 0.0 else 1.0

	if Input.is_action_pressed("move_up"):
		_play("aim_up")
	elif direction != 0.0:
		_play("walk")
	else:
		_play("idle")


func _play(name: String) -> void:
	if anim.current_animation != name:
		anim.play(name)
