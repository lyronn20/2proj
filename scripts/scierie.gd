extends Node2D

var employes: Array = []
var wood_stock := 0

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
		
func get_nearby_trees() -> Array:
	var radius := 10 * 64
	var trees := []
	for tree in get_tree().get_nodes_in_group("sapin"):
		var dist = tree.global_position.distance_to(global_position)
		if dist <= radius:
			trees.append(tree)
	return trees
	
func add_wood(amount: int):
	wood_stock += amount
	print("📦 Bois stocké :", wood_stock)

func get_stock() -> int:
	return wood_stock
