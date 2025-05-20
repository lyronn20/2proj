extends Node2D

@export var respawn_delay := 60.0  # secondes

func _ready():
	add_to_group("blé")

func respawn():
	# 1) on cache et désactive la baie
	visible = false
	set_process(false)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true

	# 2) on attend le délai
	await get_tree().create_timer(respawn_delay).timeout

	# 3) on réaffiche et réactive la baie
	visible = true
	set_process(true)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = false
