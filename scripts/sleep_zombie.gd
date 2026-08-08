extends KinematicBody2D

export var speed := 45.0
export var gravity := 900.0
export var touch_damage := 10
export var touch_damage_interval := 0.5

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
# Placeholder: the sleep zombie has no art of its own yet, so every state sits
# on frame 72. Swap these for the real death frames once the sheet exists.
var _hit_frames := [72, 72, 72]
var _hit_frame_index := 0
var _hit_frame_timer := 0.0
var _hit_frame_durations := [0.12, 0.12, 0.18]


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_face(direction)
	_play("walk")


func _process(delta: float) -> void:
	if _is_dying:
		_update_hit_sequence(delta)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	_touch_damage_cooldown_left = max(0.0, _touch_damage_cooldown_left - delta)

	velocity.x = direction * speed
	velocity.y += gravity * delta
	velocity = move_and_slide(velocity, Vector2.UP)
	_update_contact_animation(_is_touching_damageable_body())
	_apply_touch_damage()

	if not is_on_floor():
		return

	# Turn on hitting a barrier, or when the ground runs out under the leading
	# foot. The ledge ray sits 8px ahead of centre, just outside the 12px-wide
	# body, so it loses the floor a moment before the body would walk off it.
	if is_on_wall() or not ledge_check.is_colliding():
		_face(-direction)


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
