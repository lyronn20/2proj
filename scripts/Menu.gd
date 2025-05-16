# Menu.gd
extends Panel
signal objet_selectionne(nom: String)

@onready var label_coord = $HUD/GestionJeu/coordonées/mouse_coordonnées
@onready var btn_pause   = $HUD/GestionJeu/button/btn_pause
@onready var btn_play    = $HUD/GestionJeu/button/btn_play
@onready var btn_fast    = $HUD/GestionJeu/button/btn_fast
@onready var inventaire  = $HUD/ZoneInventaire

func _ready():
	btn_pause.pressed.connect(_on_pause)
	btn_play.pressed.connect(_on_play)
	btn_fast.pressed.connect(_on_fast)
	inventaire.connect("objet_selectionne", Callable(self, "_on_objet_selectionne_recu"))

func _on_pause():
	Engine.time_scale = 0
func _on_play():
	Engine.time_scale = 1
func _on_fast():
	Engine.time_scale = 2

func set_mouse_coords(cell: Vector2i):
	label_coord.text = "Mouse: %s" % cell

func _on_objet_selectionne_recu(nom: String):
	emit_signal("objet_selectionne", nom)

# Gestion du bouton feu_camp uniquement
func update_inventory(item_name: String, count: int) -> void:
	if item_name != "feu_camp":
		return
	var btn = inventaire.get_node("HBoxContainer/feu_camp")
	btn.visible  = (count > 0)
	if btn is BaseButton:
		btn.disabled = (count <= 0)
