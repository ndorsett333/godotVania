extends KinematicBody2D

export var speed := 70.0
export var gravity := 900.0
export var touch_damage := 10
export var touch_damage_interval := 0.5

onready var sprite := $Sprite
onready var anim := $AnimationPlayer
onready var ledge_check := $LedgeCheck

# -1 walks left. Placed at the right end of the floor, so it sets off inward.
var direction := -1.0

var velocity := Vector2.ZERO
var _touch_damage_cooldown_left := 0.0


func _ready() -> void:
	_face(direction)
	anim.play("walk")


func _physics_process(delta: float) -> void:
	_touch_damage_cooldown_left = max(0.0, _touch_damage_cooldown_left - delta)

	velocity.x = direction * speed
	velocity.y += gravity * delta
	velocity = move_and_slide(velocity, Vector2.UP)
	_apply_touch_damage()

	if not is_on_floor():
		return

	# Turn on hitting a barrier, or when the ground runs out under the leading
	# foot. The ledge ray sits 8px ahead of centre, just outside the 12px-wide
	# body, so it loses the floor a moment before the body would walk off it.
	if is_on_wall() or not ledge_check.is_colliding():
		_face(-direction)


func _apply_touch_damage() -> void:
	if _touch_damage_cooldown_left > 0.0:
		return

	for i in range(get_slide_count()):
		var collision := get_slide_collision(i)
		if collision == null:
			continue

		var body := collision.collider
		if body and body.has_method("take_damage"):
			body.take_damage(touch_damage)
			_touch_damage_cooldown_left = touch_damage_interval
			return


func _face(dir: float) -> void:
	direction = dir
	# The art is drawn facing right; mirroring by scale keeps the body centred
	# on the origin despite the sprite's non-zero offset.
	sprite.scale.x = dir
	ledge_check.position.x = 8.0 * dir
