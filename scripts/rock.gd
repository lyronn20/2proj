extends Node2D

@export var respawn_delay := 30.0
var is_active := true

func _ready():
	add_to_group("rock")

func respawn():
	is_active = false
	visible = false
	set_process(false)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	await get_tree().create_timer(respawn_delay).timeout
	visible = true
	set_process(true)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = false
	is_active = true
