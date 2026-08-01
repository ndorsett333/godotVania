extends Area2D

export var speed := 300.0
export var max_distance := 400.0

var direction := Vector2.RIGHT
var _shooter: Node = null

var _travelled := 0.0


func _ready() -> void:
	connect("body_entered", self, "_on_body_entered")


func _handle_hit(collider: Object) -> void:
	var node := collider as Node
	if node and node == _shooter:
		return

	if node and node.is_in_group("enemies"):
		if node.has_method("on_blaster_hit"):
			node.on_blaster_hit()
		else:
			node.queue_free()

	queue_free()


# One hit is fatal; there is no health to subtract from yet.
func _on_body_entered(body: Node) -> void:
	_handle_hit(body)


# Call after the bolt is in the tree, so global_position lands where intended.
func launch(from: Vector2, dir: Vector2, shooter: Node = null) -> void:
	direction = dir.normalized()
	_shooter = shooter
	global_position = from
	# The taper is the bolt's tail, not its nose, so the art already points
	# along its own +X and the angle is used as-is. Each frame is symmetric
	# about its horizontal axis, so mirroring and rotating agree here.
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	var from := global_position
	var to := from + step
	var hit := get_world_2d().direct_space_state.intersect_ray(
		from,
		to,
		[self, _shooter],
		collision_mask,
		true,
		false
	)

	if hit:
		global_position = hit.position
		_handle_hit(hit.collider)
		return

	global_position = to
	_travelled += step.length()
	if _travelled >= max_distance:
		queue_free()
