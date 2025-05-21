extends Node2D

var employes: Array = []
var wood_stock := 0
static var compteur := 1

func _ready():
	add_to_group("batiment")
	add_to_group("scierie") 
	set_meta("nom_affichage", "Scierie : "+ str(compteur))
	compteur += 1
	_setup_click_area()

func add_employe(pnj):
	if not employes.has(pnj):
		employes.append(pnj)
		pnj.metier = "bucheron"
		pnj.lieu_travail = self

func _setup_click_area():
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

func _on_click(_vp, event, _si):
	if event is InputEventMouseButton and event.pressed:
		get_node("/root/game/CanvasLayer/TableauBord").update_dashboard(self)

func get_nearby_trees() -> Array:
	var all_trees = get_tree().get_nodes_in_group("sapin")
	var radius := 3 * 64
	var trees := []
	for tree in all_trees:
		if tree.global_position.distance_to(global_position) <= radius:
			trees.append(tree)
	return trees

func add_wood(amount: int):
	wood_stock += amount
	get_tree().current_scene.print_total_wood_stock()

func get_stock() -> int:
	return wood_stock
