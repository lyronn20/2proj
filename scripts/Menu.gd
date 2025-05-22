extends Panel
signal objet_selectionne(nom: String)

@onready var label_coord = $HUD/GestionJeu/coordonées/mouse_coordonnées
@onready var btn_pause   = $HUD/GestionJeu/button/btn_pause
@onready var btn_play    = $HUD/GestionJeu/button/btn_play
@onready var btn_fast    = $HUD/GestionJeu/button/btn_fast
@onready var inventaire  = $HUD/ZoneInventaire
@onready var feu_camp    = $HBoxContainer/feu_camp
@onready var hutte       = $HBoxContainer/hutte
@onready var sapin       = $route/sapin
@onready var scierie     = $HBoxContainer/scierie
@onready var puit        = $HBoxContainer/puit
@onready var carriere    = $HBoxContainer/carriere
@onready var route_terre = $route/sol_terre
@onready var collect_baies   = $HBoxContainer/collect_baies
@onready var baies    = $route/baies
@onready var pierre   = $route/pierre
@onready var gomme       = $route/Gomme
@onready var animaux_bat = $HUD/ZoneInventaire/HBoxContainer/animaux_bat
var menu
var time_scales = [2.0, 4.0, 8.0]

func _ready():
	btn_pause.pressed.connect(_on_pause)
	btn_play.pressed.connect(_on_play)
	btn_fast.pressed.connect(_on_fast)
	inventaire.connect("objet_selectionne", Callable(self, "_on_objet_selectionne_recu"))

	# 2) Initialiser l’affichage du bouton rapide
	_update_fast_button()
	menu = get_node("/root/game/CanvasLayer/Menu")


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
		
func set_locked_buttons(goal_accompli: int):
	var all_buttons = {
		"feu_camp": 0,
		"hutte": 1,
		"animaux_bat": 2,
		"puit": 3,
		"ferme": 4,
		"collect_baies": 5,
		"scierie": 6,
		"carriere": 7
	}

	for btn_name in all_buttons.keys():
		var required_goal = all_buttons[btn_name]
		if inventaire:
			var btn = inventaire.get_node_or_null("HBoxContainer/" + btn_name)
			if btn:
				var croix = btn.get_node_or_null("verrou")
				
				if croix:
					croix.visible = goal_accompli < required_goal
				# Et tu peux désactiver les boutons aussi si tu veux :
				if btn is BaseButton:
					btn.disabled = goal_accompli < required_goal
			
func set_bloque(nom: String, bloque: bool):
	var noeud = get_node_or_null("HBoxContainer/" + nom)
	if noeud:
		var verrou = noeud.get_node_or_null("Verrou")
		if verrou and verrou is TextureRect:
			verrou.visible = bloque
			
func is_locked(nom: String) -> bool:
	if not inventaire:
		return false
	var noeud = inventaire.get_node_or_null("HBoxContainer/" + nom)
	if noeud:
		var verrou = noeud.get_node_or_null("verrou")
		if verrou and verrou is TextureRect:
			return verrou.visible
	return false
