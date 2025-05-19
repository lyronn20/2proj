extends Node2D

@onready var sprite = $Sprite2D
@export var respawn_delay := 10.0

var is_active := true

func _ready():
	add_to_group("baies")
	visible = true
	is_active = true

func respawn():
	is_active = false
	visible = false
	set_process(false)

	await get_tree().create_timer(respawn_delay).timeout

	visible = true
	set_process(true)
	is_active = true
