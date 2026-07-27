extends Area2D

export var speed := 300.0
export var max_distance := 400.0

var direction := Vector2.RIGHT

var _travelled := 0.0


func _ready() -> void:
	connect("body_entered", self, "_on_body_entered")


# One hit is fatal; there is no health to subtract from yet.
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		body.queue_free()
		queue_free()


# Call after the bolt is in the tree, so global_position lands where intended.
func launch(from: Vector2, dir: Vector2) -> void:
	direction = dir.normalized()
	global_position = from
	# The taper is the bolt's tail, not its nose, so the art already points
	# along its own +X and the angle is used as-is. Each frame is symmetric
	# about its horizontal axis, so mirroring and rotating agree here.
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	global_position += step
	_travelled += step.length()
	if _travelled >= max_distance:
		queue_free()
