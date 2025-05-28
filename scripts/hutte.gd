extends Node2D

var habitants: Array = []
var nom_affichage := "Hutte"
static var compteur := 1

func add_habitant(pnj):
	if not habitants.has(pnj):
		habitants.append(pnj)

func _ready():
	if has_meta("is_preview") and get_meta("is_preview") == true:
		return  # Ne pas exécuter le reste si c’est une preview
	add_to_group("batiment")
	set_meta("nom_affichage", "Hutte : "+ str(compteur))
	compteur += 1
	var area = Area2D.new()
	area.name = "ClickArea"	
	area.input_pickable = true
	add_child(area)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(64, 64)
	shape.shape = rect
	area.add_child(shape)

	area.connect("input_event", Callable(self, "_on_click"), CONNECT_ONE_SHOT)


func _on_click(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_node("/root/game/CanvasLayer/TableauBord").update_dashboard(self)
