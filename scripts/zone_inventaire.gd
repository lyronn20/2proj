extends Panel
signal objet_selectionne(nom: String)

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
@onready var ferme   = $HBoxContainer/ferme
@onready var blé 	 = $route/blé

func _ready():
	feu_camp.connect("gui_input", Callable(self, "_on_feu_camp_input"))
	hutte.connect("gui_input", Callable(self, "_on_hutte_input"))
	gomme.connect("gui_input", Callable(self, "_on_gomme_input"))
	sapin.connect("gui_input", Callable(self, "_on_sapin_input"))
	scierie.connect("gui_input", Callable(self, "_on_scierie_input"))
	puit.connect("gui_input", Callable(self, "_on_puit_input"))
	carriere.connect("gui_input", Callable(self, "_on_carriere_input"))
	collect_baies.connect("gui_input", Callable(self, "_on_collect_baies_input"))
	baies.connect("gui_input", Callable(self, "_on_baies_input"))
	pierre.connect("gui_input", Callable(self, "_on_pierre_input"))
	ferme.connect("gui_input", Callable(self, "_on_ferme_input"))
	blé.connect("gui_input", Callable(self, "_on_ble_input"))

func _on_feu_camp_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "feu_camp")

func _on_hutte_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "hutte")

func _on_gomme_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "gomme")

func _on_sapin_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "sapin")

func _on_scierie_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "scierie")

func _on_puit_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "puit")

func _on_carriere_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "carriere")
		
func _on_collect_baies_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "collect_baies")

func _on_baies_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "baies")
		
func _on_pierre_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "pierre")

func _on_ferme_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne","ferme")


func _on_ble_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne","blé")
