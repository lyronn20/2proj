extends Panel  

@export var pnj_id: String = ""
@export var faim: int = 100
@export var eau: int = 100
@export var metier: String = ""
signal pnj_selected(data)

func _ready():
	add_to_group("pnjs")

func _input_event(viewport, clic, shape_idx):
	if clic is InputEventMouseButton and clic.button_index == MOUSE_BUTTON_LEFT and clic.pressed:
		var data = {
			"id": pnj_id,
			"faim": faim,
			"eau": eau,
			"metier": metier
		}
		emit_signal("pnj_selected", data)
