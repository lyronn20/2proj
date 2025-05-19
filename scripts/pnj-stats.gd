# pnj_stats.gd
extends Panel    # ou Node2D, ou CollisionObject2D selon ta scène

# On déclare les variables exportées pour pouvoir les régler dans l’inspecteur
@export var pnj_id: String = ""
@export var faim: int = 100
@export var eau: int = 100
@export var metier: String = ""

signal pnj_selected(data)

func _ready():
	# Optionnel : ajouter ce PNJ à un groupe pour faciliter la connexion dans game.gd
	add_to_group("pnjs")

# Fonction appelée quand on clique sur le collision shape du PNJ
func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var data = {
			"id": pnj_id,
			"faim": faim,
			"eau": eau,
			"metier": metier
		}
		emit_signal("pnj_selected", data)
