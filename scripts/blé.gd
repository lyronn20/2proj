extends Node2D
@export var respawn_delay := 60.0  
func _ready():
	add_to_group("blé")

func respawn():
	visible = false
	set_process(false)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	await get_tree().create_timer(respawn_delay).timeout
	visible = true
	set_process(true)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = false
