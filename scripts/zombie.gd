extends KinematicBody2D

export var speed := 70.0
export var gravity := 900.0

onready var sprite := $Sprite
onready var anim := $AnimationPlayer
onready var ledge_check := $LedgeCheck

# -1 walks left. Placed at the right end of the floor, so it sets off inward.
var direction := -1.0

var velocity := Vector2.ZERO


func _ready() -> void:
	_face(direction)
	anim.play("walk")


func _physics_process(delta: float) -> void:
	velocity.x = direction * speed
	velocity.y += gravity * delta
	velocity = move_and_slide(velocity, Vector2.UP)

	if not is_on_floor():
		return

	# Turn on hitting a barrier, or when the ground runs out under the leading
	# foot. The ledge ray sits 8px ahead of centre, just outside the 12px-wide
	# body, so it loses the floor a moment before the body would walk off it.
	if is_on_wall() or not ledge_check.is_colliding():
		_face(-direction)


func _face(dir: float) -> void:
	direction = dir
	# The art is drawn facing right; mirroring by scale keeps the body centred
	# on the origin despite the sprite's non-zero offset.
	sprite.scale.x = dir
	ledge_check.position.x = 8.0 * dir
