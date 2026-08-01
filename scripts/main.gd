extends Node2D

onready var player := $Player
onready var health_label := $HUD/HealthLabel
onready var health_bar := $HUD/HealthBar


func _ready() -> void:
	if player.has_signal("health_changed"):
		player.connect("health_changed", self, "_on_player_health_changed")

	_on_player_health_changed(player.health, player.max_health)


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = "Health %d" % current_health
