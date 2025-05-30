extends Panel
signal objet_selectionne(nom: String)

@onready var label_coord = $HUD/GestionJeu/coordonées/mouse_coordonnées
@onready var btn_pause   = $HUD/GestionJeu/button/btn_pause
@onready var btn_play    = $HUD/GestionJeu/button/btn_play
@onready var btn_fast    = $HUD/GestionJeu/button/btn_fast
@onready var inventaire  = $HUD/ZoneInventaire
@onready var feu_camp = $HUD/ZoneInventaire/HBoxContainer/feu_camp
@onready var hutte = $HUD/ZoneInventaire/HBoxContainer/hutte
@onready var sapin = $HUD/ZoneInventaire/route/sapin
@onready var scierie = $HUD/ZoneInventaire/HBoxContainer/scierie
@onready var puit = $HUD/ZoneInventaire/HBoxContainer/puit
@onready var carriere = $HUD/ZoneInventaire/HBoxContainer/carriere
@onready var sol_terre = $HUD/ZoneInventaire/route/sol_terre
@onready var collect_baies = $HUD/ZoneInventaire/HBoxContainer/collect_baies
@onready var baies = $HUD/ZoneInventaire/route/baies
@onready var pierre = $HUD/ZoneInventaire/route/pierre
@onready var gomme = $HUD/ZoneInventaire/route/Gomme
@onready var animaux_bat = $HUD/ZoneInventaire/HBoxContainer/animaux_bat
var menu
var time_scales = [2.0, 4.0, 8.0]

func _ready():
	btn_pause.pressed.connect(_on_pause)
	btn_play.pressed.connect(_on_play)
	btn_fast.pressed.connect(_on_fast)
	inventaire.connect("objet_selectionne", Callable(self, "_on_objet_selectionne_recu"))
	_update_fast_button()
	menu = get_node("/root/game/CanvasLayer/Menu")

func _on_pause():
	Engine.time_scale = 0.0
	_update_fast_button()

func _on_play():
	Engine.time_scale = 1.0
	_update_fast_button()

func _on_fast():
	if Engine.time_scale == 0.0:
		Engine.time_scale = 1.0
	else:
		var idx = time_scales.find(Engine.time_scale)
		if idx < 0:
			idx = 0
		idx = (idx + 1) % time_scales.size()
		Engine.time_scale = time_scales[idx]
	_update_fast_button()

func _update_fast_button():
	var _ts = Engine.time_scale
	var display = ""
	if btn_fast is Button:
		btn_fast.text = display
	else:
		var lbl = btn_fast.get_node_or_null("Label")
		if lbl:
			lbl.text = display
		else:
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
	var objets_associes = {
	"scierie": ["sapin"],
	"ferme": ["blé"],
	"collect_baies": ["baies"],
	"carriere": ["pierre", "roches"],
	"Pont": ["Pont"],              
	"route": ["sol_terre"]       
	}


	var all_buttons = {
		"feu_camp": 0,
		"hutte": 1,
		"puit": 2,
		"animaux_bat": 3,
		"scierie": 5,
		"sapin": 6,
		"ferme": 11,
		"blé": 11,
		"collect_baies": 10,
		"baies": 10,
		"carriere": 8,
		"pierre": 9,
		"Pont": 12,           
		"sol_terre": 4  
	}

	for btn_name in all_buttons.keys():
		var required_goal = all_buttons[btn_name]
		if inventaire:
			var btn = _get_bouton_par_nom(btn_name)
			if btn:
				var croix = btn.get_node_or_null("verrou")
				var est_verrouille = goal_accompli < required_goal

				if croix:
					croix.visible = est_verrouille
				if btn is BaseButton:
					btn.disabled = est_verrouille

				if not est_verrouille and objets_associes.has(btn_name):
					for alias in objets_associes[btn_name]:
						var btn_lie = inventaire.get_node_or_null("HBoxContainer/" + alias)
						if btn_lie:
							var verrou_lie = btn_lie.get_node_or_null("verrou")
							if verrou_lie:
								verrou_lie.visible = false
							if btn_lie is BaseButton:
								btn_lie.disabled = false

			
func set_bloque(nom: String, bloque: bool):
	var noeud = _get_bouton_par_nom(nom)
	if noeud:
		var verrou = noeud.get_node_or_null("verrou")
		if verrou and verrou is TextureRect:
			verrou.visible = bloque


func is_locked(nom: String) -> bool:
	var noeud = _get_bouton_par_nom(nom)
	if noeud:
		var verrou = noeud.get_node_or_null("verrou")
		if verrou and verrou is TextureRect:
			return verrou.visible
	return false


func _get_bouton_par_nom(nom: String) -> Node:
	if inventaire.has_node("HBoxContainer/" + nom):
		return inventaire.get_node("HBoxContainer/" + nom)
	elif inventaire.has_node("route/" + nom):
		return inventaire.get_node("route/" + nom)
	return null
