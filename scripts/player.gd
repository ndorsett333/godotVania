extends KinematicBody2D

export var speed := 130.0
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

	# Both sheets share a layout: three aim angles, four frames each — forward
	# (0-3), diagonal up (4-7), straight up (8-11). Standing while holding up
	# aims straight up; moving while holding up aims along the diagonal.
	# Each animation keys its own texture and offset, since "walk" draws from
	# the run sheet and the rest from the walk sheet, and the two sheets centre
	# the body slightly differently.
	var aiming_up := Input.is_action_pressed("move_up")
	if aiming_up and direction != 0.0:
		_play("walk_aim_up")
	elif aiming_up:
		_play("aim_up")
	elif direction != 0.0:
		_play("walk")
	else:
		_play("idle")


func _play(name: String) -> void:
	if anim.current_animation != name:
		anim.play(name)
