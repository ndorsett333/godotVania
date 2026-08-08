extends KinematicBody2D

export var speed := 45.0
export var gravity := 900.0
export var touch_damage := 10
export var touch_damage_interval := 0.5
# Measured origin to origin, so effectively floor-level distance between the two.
export var wake_radius := 48.0

var health := 20

onready var sprite := $Sprite
onready var anim := $AnimationPlayer
onready var ledge_check := $LedgeCheck
onready var body_collision := $CollisionShape2D
onready var touch_area := $TouchArea

# -1 walks left. Placed at the right end of the floor, so it sets off inward.
var direction := -1.0

var velocity := Vector2.ZERO
var _touch_damage_cooldown_left := 0.0
var _is_dying := false
# Sleeps until the player comes inside wake_radius, then hunts them for good.
var _is_awake := false
var _target: Node2D = null
var _hit_frames := [41, 42, 43]
var _hit_frame_index := 0
var _hit_frame_timer := 0.0
var _hit_frame_durations := [0.12, 0.12, 0.18]


func _ready() -> void:
	_face(direction)
	_play("sleep")


func _process(delta: float) -> void:
	if _is_dying:
		_update_hit_sequence(delta)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	velocity.y += gravity * delta

	if not _is_awake:
		# Dormant: gravity still settles it onto the floor, but it neither walks
		# nor bites until the player strays close enough to wake it.
		velocity.x = 0.0
		velocity = move_and_slide(velocity, Vector2.UP)
		_check_for_wake()
		return

	_touch_damage_cooldown_left = max(0.0, _touch_damage_cooldown_left - delta)

	# Awake it hunts rather than patrols, so it re-aims at the player every frame
	# instead of turning around at obstacles.
	_face_target()
	velocity.x = 0.0 if _is_ledge_ahead() else direction * speed
	velocity = move_and_slide(velocity, Vector2.UP)
	_update_contact_animation(_is_touching_damageable_body())
	_apply_touch_damage()


func _check_for_wake() -> void:
	if not _resolve_target():
		return

	if global_position.distance_to(_target.global_position) > wake_radius:
		return

	_is_awake = true
	_face_target()
	_play("walk")


func _resolve_target() -> bool:
	if _target and is_instance_valid(_target):
		return true

	_target = null
	var players := get_tree().get_nodes_in_group("player")
	if players.empty():
		return false

	_target = players[0]
	return true


func _face_target() -> void:
	if not _resolve_target():
		return

	var dx := _target.global_position.x - global_position.x
	# Deadband: without it the sprite flips every frame while the player stands
	# directly on top of it.
	if abs(dx) < 2.0:
		return

	_face(-1.0 if dx < 0.0 else 1.0)


# Walls stop it on their own via move_and_slide, but a ledge would let it walk
# straight off the platform chasing the player, so hold position at the edge.
# The ray sits 8px ahead of centre, just outside the 12px-wide body, so it loses
# the floor a moment before the body would.
func _is_ledge_ahead() -> bool:
	if not is_on_floor():
		return false

	# _face just moved the ray; without this it would answer for the old side.
	ledge_check.force_raycast_update()
	return not ledge_check.is_colliding()


func take_damage(amount: int) -> void:
	if _is_dying:
		return

	var damage := int(max(amount, 0))
	if damage == 0:
		return

	health -= damage
	if health > 0:
		return

	on_blaster_hit()


func on_blaster_hit() -> void:
	if _is_dying:
		return

	_is_dying = true
	velocity = Vector2.ZERO
	body_collision.disabled = true
	ledge_check.enabled = false
	anim.stop(true)
	_hit_frame_index = 0
	_hit_frame_timer = 0.0
	_show_hit_frame(0)


func _update_hit_sequence(delta: float) -> void:
	_hit_frame_timer += delta
	var duration = _hit_frame_durations[_hit_frame_index]
	if _hit_frame_timer < duration:
		return

	_hit_frame_index += 1
	if _hit_frame_index >= _hit_frames.size():
		queue_free()
		return

	_hit_frame_timer = 0.0
	_show_hit_frame(_hit_frame_index)


func _show_hit_frame(index: int) -> void:
	sprite.visible = true
	sprite.hframes = 13
	sprite.vframes = 6
	sprite.frame = _hit_frames[index]


func _apply_touch_damage() -> void:
	if _touch_damage_cooldown_left > 0.0:
		return

	for body in touch_area.get_overlapping_bodies():
		if body and body != self and body.has_method("take_damage"):
			body.take_damage(touch_damage)
			_touch_damage_cooldown_left = touch_damage_interval
			return


func _is_touching_damageable_body() -> bool:
	for body in touch_area.get_overlapping_bodies():
		if body and body != self and body.has_method("take_damage"):
			return true
	return false


func _update_contact_animation(touching_damageable: bool) -> void:
	_play("contact" if touching_damageable else "walk")


func _play(name: String) -> void:
	if anim.current_animation != name:
		anim.play(name)


func _face(dir: float) -> void:
	direction = dir
	# The art is drawn facing right; mirroring by scale keeps the body centred
	# on the origin despite the sprite's non-zero offset.
	sprite.scale.x = dir
	ledge_check.position.x = 8.0 * dir
