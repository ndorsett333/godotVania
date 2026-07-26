extends KinematicBody2D

const Blaster := preload("res://scenes/projectiles/Blaster.tscn")

# Which way the weapon points. Drives both the pose and where shots go, so the
# two can never disagree.
enum Aim { FORWARD, DIAGONAL, UP }

export var speed := 130.0
export var gravity := 900.0
# Tuned so the soles clear the 31px-tall standing silhouette by ~3px at the
# apex. The closed form v^2 / (2 * gravity) overstates the rise by about 2px
# here, because physics integrates in 60Hz steps rather than continuously, so
# this is the value that measures right in-engine rather than on paper.
export var jump_velocity := 255.0
# Minimum seconds between shots, so mashing the key cannot outpace the weapon.
export var fire_cooldown := 0.25

onready var sprite := $Sprite
onready var anim := $AnimationPlayer

var velocity := Vector2.ZERO

var _fire_cooldown_left := 0.0


func _physics_process(delta: float) -> void:
	var direction := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	velocity.x = direction * speed
	velocity.y += gravity * delta

	# is_on_floor() reports the previous move_and_slide, which is what we want:
	# the jump is authorised by where the body finished last frame.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -jump_velocity

	velocity = move_and_slide(velocity, Vector2.UP)

	if direction != 0.0:
		# Mirror with scale rather than flip_h: the sprite carries a non-zero
		# offset to centre the art in its 32px cell, and flip_h would mirror
		# the art inside that cell while leaving the offset put, shifting the
		# character sideways on every turn. Scaling mirrors about the origin.
		sprite.scale.x = -1.0 if direction < 0.0 else 1.0

	var airborne := not is_on_floor()
	var aim := _current_aim(direction, airborne)

	_fire_cooldown_left = max(0.0, _fire_cooldown_left - delta)
	if Input.is_action_just_pressed("fire") and _fire_cooldown_left == 0.0:
		_fire(aim)
		_fire_cooldown_left = fire_cooldown

	# The walk and run sheets share a layout: three aim angles, four frames each
	# — forward (0-3), diagonal up (4-7), straight up (8-11). The jump sheet is
	# five aim angles of a single airborne pose, so it has its own grid width.
	# Every animation therefore keys its own texture, hframes and offset, since
	# the sheets differ in column count and in how they centre the body.
	if airborne:
		_play("jump")
	elif aim == Aim.DIAGONAL:
		_play("walk_aim_up")
	elif aim == Aim.UP:
		_play("aim_up")
	elif direction != 0.0:
		_play("walk")
	else:
		_play("idle")


func _current_aim(direction: float, airborne: bool) -> int:
	# Airborne always draws the jump sheet's forward-facing frame, so the shot
	# has to go forward too or the pose would lie about where you are aiming.
	if airborne or not Input.is_action_pressed("move_up"):
		return Aim.FORWARD
	return Aim.DIAGONAL if direction != 0.0 else Aim.UP


# Barrel tip for each pose, measured off the sprite sheets, in local pixels
# with the character facing right.
func _muzzle(aim: int) -> Vector2:
	match aim:
		Aim.UP:
			return Vector2(-1, -37)
		Aim.DIAGONAL:
			return Vector2(11, -30)
		_:
			return Vector2(14, -23)


func _aim_vector(aim: int) -> Vector2:
	match aim:
		Aim.UP:
			return Vector2(0, -1)
		Aim.DIAGONAL:
			return Vector2(1, -1).normalized()
		_:
			return Vector2(1, 0)


func _fire(aim: int) -> void:
	var facing := -1.0 if sprite.scale.x < 0.0 else 1.0

	var muzzle := _muzzle(aim)
	muzzle.x *= facing

	var dir := _aim_vector(aim)
	dir.x *= facing

	var bolt := Blaster.instance()
	# Parent to the level, not to the player, so shots keep their own course
	# instead of being dragged along by whatever the player does next.
	get_parent().add_child(bolt)
	bolt.launch(global_position + muzzle, dir)


func _play(name: String) -> void:
	if anim.current_animation != name:
		anim.play(name)
