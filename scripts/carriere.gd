extends Node2D

var pierre_stock := 0
static var compteur := 1
var employes: Array = []

func add_employe(pnj: Node2D):
	employes.append(pnj)

func get_employes() -> Array:
	return employes

func _ready():
	if has_meta("is_preview") and get_meta("is_preview") == true:
		return  
	add_to_group("batiment")
	add_to_group("carriere")
	set_meta("nom_affichage", "Carriere : "+ str(compteur))
	compteur += 1
	_setup_click_area()

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

func _on_click(_vp, clic, _si):
	if clic is InputEventMouseButton and clic.pressed:
		get_node("/root/game/CanvasLayer/TableauBord").update_dashboard(self)

func get_nearby_rocks() -> Array:
	var rocks := []
	var radius := 2 * 64
	for rock in get_tree().get_nodes_in_group("rock"):
		if rock.visible and rock.global_position.distance_to(global_position) <= radius:
			rocks.append(rock)
	return rocks

func add_stone(amount: int):
	pierre_stock += amount
	var tb = get_node("/root/game/CanvasLayer/TableauBord")
	if tb.has_method("update_total_stock"):
		tb.update_total_stock()

func get_stock():
	return {"pierre": pierre_stock}
