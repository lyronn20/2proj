extends Node2D

var employes: Array = []
var nom_affichage := "Puit"
static var compteur := 1

func add_employe(pnj):
	if not employes.has(pnj):
		employes.append(pnj)

func _ready():
	if has_meta("is_preview") and get_meta("is_preview") == true:
		return  # Ne pas exécuter le reste si c’est une preview
	add_to_group("batiment")
	set_meta("nom_affichage", "Puit : " + str(compteur))
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

	area.connect("input_event", Callable(self, "_on_click"))

func _on_click(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		get_node("/root/game/CanvasLayer/TableauBord").update_dashboard(self)
