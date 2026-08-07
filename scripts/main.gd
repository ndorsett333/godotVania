extends Node2D

onready var player := $Player
onready var health_label := $HUD/HealthLabel


func _ready() -> void:
	if player.has_signal("health_changed"):
		var err := player.connect("health_changed", self, "_on_player_health_changed")
		if err != OK:
			push_error("Failed to connect player health signal: %s" % err)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is PhysicsBody2D:
			player.add_collision_exception_with(enemy)
			enemy.add_collision_exception_with(player)

	_on_player_health_changed(player.health, player.max_health)


func _on_player_health_changed(current_health: int, _max_health: int) -> void:
	health_label.text = "+%d" % current_health
