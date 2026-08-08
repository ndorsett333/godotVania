extends Node2D

onready var player := $Player
onready var health_label := $HUD/HealthLabel
onready var pause_overlay := $HUD/PauseOverlay

var _is_paused := false


func _ready() -> void:
	# Main has to keep running while the tree is paused, or nothing would be left
	# listening for the button that lifts the pause.
	pause_mode = Node.PAUSE_MODE_PROCESS
	pause_overlay.visible = false

	if player.has_signal("health_changed"):
		var err := player.connect("health_changed", self, "_on_player_health_changed")
		if err != OK:
			push_error("Failed to connect player health signal: %s" % err)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is PhysicsBody2D:
			player.add_collision_exception_with(enemy)
			enemy.add_collision_exception_with(player)

	_on_player_health_changed(player.health, player.max_health)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return

	# Dying freezes the tree by the same switch. Only whoever froze it may thaw
	# it, so the pause button is inert on the death screen.
	if get_tree().paused and not _is_paused:
		return

	_set_paused(not _is_paused)
	get_tree().set_input_as_handled()


func _set_paused(value: bool) -> void:
	_is_paused = value
	get_tree().paused = value
	pause_overlay.visible = value


func _on_player_health_changed(current_health: int, _max_health: int) -> void:
	health_label.text = "+%d" % current_health
