extends Node2D

var employes: Array = []

func add_employe(pnj):
	if not employes.has(pnj):
		employes.append(pnj)
		pnj.metier = "bucheron"
		pnj.lieu_travail = self

func _ready():
	add_to_group("batiment")
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
