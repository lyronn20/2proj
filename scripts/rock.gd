extends Node2D

@export var respawn_delay := 60.0  # secondes
var is_active := true

func _ready():
	add_to_group("rock")

func respawn():
	# 1) Désactive et cache la pierre
	is_active = false
	visible = false
	set_process(false)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true

	# 2) Attends le délai
	await get_tree().create_timer(respawn_delay).timeout

	# 3) Réactive et réaffiche la même instance
	visible = true
	set_process(true)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = false
	is_active = true
