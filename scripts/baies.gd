# baie.gd
extends Node2D

@export var respawn_delay := 60.0  # secondes

func _ready():
	add_to_group("baies")

func respawn():
	# 1) On cache et désactive la baie
	visible = false
	set_process(false)

	if has_node("CollisionShape2D"):
		var shape = $CollisionShape2D
		if shape is CollisionShape2D:
			shape.disabled = true

	# 2) On attend le délai
	await get_tree().create_timer(respawn_delay).timeout

	# 3) On réaffiche et réactive la baie
	visible = true
	set_process(true)

	if has_node("CollisionShape2D"):
		var shape = $CollisionShape2D
		if shape is CollisionShape2D:
			shape.disabled = false
