extends Panel
signal objet_selectionne(nom: String)

@onready var feu_camp = $HBoxContainer/feu_camp
@onready var hutte = $HBoxContainer/hutte
@onready var route_terre = $route/sol_terre
@onready var gomme = $route/Gomme

func _ready():
	feu_camp.connect("gui_input", Callable(self, "_on_feu_camp_input"))
	hutte.connect("gui_input", Callable(self, "_on_hutte_input"))
	gomme.connect("gui_input", Callable(self, "_on_gomme_input"))

func _on_feu_camp_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "feu_camp")

func _on_hutte_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "hutte")


func _on_gomme_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("objet_selectionne", "gomme")
