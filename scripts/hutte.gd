extends Node2D

var habitants: Array = []

func add_habitant(pnj):
	if not habitants.has(pnj):
		habitants.append(pnj)

func _ready():
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
		print("🏠 Hutte cliquée ! PNJ :", habitants.map(func(p): return p.name))
