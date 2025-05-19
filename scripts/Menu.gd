extends Panel
signal objet_selectionne(nom: String)

@onready var label_coord = $HUD/GestionJeu/coordonées/mouse_coordonnées
@onready var btn_pause   = $HUD/GestionJeu/button/btn_pause
@onready var btn_play    = $HUD/GestionJeu/button/btn_play
@onready var btn_fast    = $HUD/GestionJeu/button/btn_fast
@onready var inventaire  = $HUD/ZoneInventaire

var time_scales = [2.0, 4.0, 8.0]

func _ready():
	btn_pause.pressed.connect(_on_pause)
	btn_play.pressed.connect(_on_play)
	btn_fast.pressed.connect(_on_fast)
	inventaire.connect("objet_selectionne", Callable(self, "_on_objet_selectionne_recu"))

	# 2) Initialiser l’affichage du bouton rapide
	_update_fast_button()

func _on_pause():
	Engine.time_scale = 0.0
	_update_fast_button()

func _on_play():
	Engine.time_scale = 1.0
	_update_fast_button()

func _on_fast():
	# Si on est en pause, repasse en x1
	if Engine.time_scale == 0.0:
		Engine.time_scale = 1.0
	else:
		# Trouver l'index actuel (ou 0 si pas trouvé)
		var idx = time_scales.find(Engine.time_scale)
		if idx < 0:
			idx = 0
		# Passer au palier suivant, en boucle
		idx = (idx + 1) % time_scales.size()
		Engine.time_scale = time_scales[idx]
	_update_fast_button()

func _update_fast_button():
	var ts = Engine.time_scale
	var display = ""
	if btn_fast is Button:
		btn_fast.text = display
	else:
		# sinon, on cherche un Label enfant
		var lbl = btn_fast.get_node_or_null("Label")
		if lbl:
			lbl.text = display
		else:
			# fallback
			btn_fast.text = display

func set_mouse_coords(cell: Vector2i):
	label_coord.text = "Mouse: %s" % cell

func _on_objet_selectionne_recu(nom: String):
	emit_signal("objet_selectionne", nom)

func update_inventory(item_name: String, count: int) -> void:
	if item_name != "feu_camp":
		return
	var btn = inventaire.get_node("HBoxContainer/feu_camp")
	btn.visible = (count > 0)
	if btn is BaseButton:
		btn.disabled = (count <= 0)
