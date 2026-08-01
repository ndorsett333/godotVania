extends KinematicBody2D

const Blaster := preload("res://scenes/projectiles/Blaster.tscn")
const CrouchTexture := preload("res://assets/sprites/player/Voidster_Crouch_R.png")
const DamageTexture := preload("res://assets/sprites/player/Voidster_Damage_R.png")

# Which way the weapon points. Drives both the pose and where shots go, so the
# two can never disagree.
enum Aim { FORWARD, DIAGONAL, UP }

signal health_changed(current_health, max_health)

export var speed := 130.0
export var gravity := 900.0
# Tuned so the soles clear the 31px-tall standing silhouette by ~3px at the
# apex. The closed form v^2 / (2 * gravity) overstates the rise by about 2px
# here, because physics integrates in 60Hz steps rather than continuously, so
# this is the value that measures right in-engine rather than on paper.
export var jump_velocity := 255.0
# Minimum seconds between shots, so mashing the key cannot outpace the weapon.
export var fire_cooldown := 0.25
export var max_health := 100
export var damage_flash_duration := 0.18
export var death_hold_duration := 1.0
export var death_flash_duration := 1.0
export var death_flash_interval := 0.1

onready var sprite := $Sprite
onready var anim := $AnimationPlayer
onready var body_collision := $CollisionShape2D

var velocity := Vector2.ZERO
var health := 100

var _fire_cooldown_left := 0.0
var _damage_flash_left := 0.0
var _is_dead := false
var _death_phase := 0
var _death_timer := 0.0
var _death_flash_timer := 0.0
var _death_show_second_sprite := true


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	health = max_health
	emit_signal("health_changed", health, max_health)


func _process(delta: float) -> void:
	if _is_dead:
		_update_death_sequence(delta)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_damage_flash_left = max(0.0, _damage_flash_left - delta)

	var direction := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var wants_crouch := Input.is_action_pressed("move_down")
	var crouching := wants_crouch and is_on_floor()

	velocity.x = 0.0 if crouching else direction * speed
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
	crouching = not airborne and wants_crouch

	_fire_cooldown_left = max(0.0, _fire_cooldown_left - delta)
	if Input.is_action_just_pressed("fire") and _fire_cooldown_left == 0.0:
		_fire(aim, crouching)
		_fire_cooldown_left = fire_cooldown

	# The walk and run sheets share a layout: three aim angles, four frames each
	# — forward (0-3), diagonal up (4-7), straight up (8-11). The jump sheet is
	# five aim angles of a single airborne pose, so it has its own grid width.
	# Every animation therefore keys its own texture, hframes and offset, since
	# the sheets differ in column count and in how they centre the body.
	if _damage_flash_left > 0.0:
		_apply_damage_pose()
	elif crouching:
		_apply_crouch_pose()
	elif airborne:
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
func _muzzle(aim: int, crouching: bool) -> Vector2:
	if crouching:
		# Tuned so the bolt starts from the crouched hand instead of chest height.
		return Vector2(10, -16)

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


func _fire(aim: int, crouching: bool) -> void:
	var facing := -1.0 if sprite.scale.x < 0.0 else 1.0

	var muzzle := _muzzle(aim, crouching)
	muzzle.x *= facing

	var dir := _aim_vector(aim)
	dir.x *= facing

	var bolt := Blaster.instance()
	# Parent to the level, not to the player, so shots keep their own course
	# instead of being dragged along by whatever the player does next.
	get_parent().add_child(bolt)
	bolt.launch(global_position + muzzle, dir, self)


func _play(name: String) -> void:
	if anim.current_animation != name:
		anim.play(name)


func _apply_crouch_pose() -> void:
	# Sprite #3 is frame index 2 (Godot frames are zero-based).
	anim.stop()
	sprite.texture = CrouchTexture
	sprite.hframes = 5
	sprite.frame = 2
	sprite.offset = Vector2(-1.75, -16)


func _apply_damage_pose() -> void:
	anim.stop()
	sprite.texture = DamageTexture
	sprite.hframes = 2
	sprite.offset = Vector2(-1.75, -16)
	var halfway := damage_flash_duration * 0.5
	# Show sprite #2 first, then sprite #1.
	sprite.frame = 1 if _damage_flash_left > halfway else 0


func _apply_death_pose() -> void:
	anim.stop()
	sprite.texture = DamageTexture
	sprite.hframes = 2
	sprite.offset = Vector2(-1.75, -16)
	# Sprite #1 on the damage sheet is frame index 0.
	sprite.frame = 0


func _apply_death_flash_pose() -> void:
	anim.stop()
	sprite.texture = DamageTexture
	sprite.hframes = 2
	sprite.offset = Vector2(-1.75, -16)
	# Flash sprite #2 over sprite #1.
	sprite.frame = 1 if _death_show_second_sprite else 0


func _update_death_sequence(delta: float) -> void:
	if _death_phase == 1:
		sprite.visible = true
		_apply_death_pose()
		_death_timer = max(0.0, _death_timer - delta)
		if _death_timer == 0.0:
			_death_phase = 2
			_death_timer = death_flash_duration
			_death_flash_timer = 0.0
			_death_show_second_sprite = true
		return

	if _death_phase == 2:
		sprite.visible = true
		_death_timer = max(0.0, _death_timer - delta)
		_death_flash_timer -= delta
		if _death_flash_timer <= 0.0:
			_death_show_second_sprite = not _death_show_second_sprite
			_death_flash_timer = death_flash_interval
		_apply_death_flash_pose()
		if _death_timer == 0.0:
			_death_phase = 3
			sprite.visible = false
			body_collision.disabled = true


func set_health(value: int) -> void:
	health = int(clamp(value, 0, max_health))
	emit_signal("health_changed", health, max_health)


func take_damage(amount: int) -> void:
	if _is_dead:
		return

	var damage := max(amount, 0)
	if damage == 0:
		return

	var previous_health := health
	set_health(health - damage)
	if health < previous_health:
		_damage_flash_left = damage_flash_duration

	if health == 0:
		_die()


func heal(amount: int) -> void:
	if _is_dead:
		return

	set_health(health + max(amount, 0))


func _die() -> void:
	if _is_dead:
		return

	_is_dead = true
	_damage_flash_left = 0.0
	_death_phase = 1
	_death_timer = death_hold_duration
	_death_flash_timer = 0.0
	_death_show_second_sprite = true
	_apply_death_pose()

	# Pause one frame later so the death pose is rendered first.
	call_deferred("_freeze_world")


func _freeze_world() -> void:
	# The death pose stays visible while gameplay is paused.
	get_tree().paused = true
