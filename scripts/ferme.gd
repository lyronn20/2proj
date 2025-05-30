extends Node2D

var ble_stock := 0
static var compteur := 1
@onready var ble_scene: PackedScene = preload("res://scenes/blé.tscn")

var employes: Array = []

func add_employe(pnj: Node2D):
	employes.append(pnj)

func _ready():
	if has_meta("is_preview") and get_meta("is_preview") == true:
		return  
	add_to_group("ferme")
	add_to_group("ble")   
	set_meta("nom_affichage", "Ferme : "+ str(compteur))
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

func _on_click(_viewport, clic, _shape_idx):
	if clic is InputEventMouseButton and clic.pressed:
		get_node("/root/game/CanvasLayer/TableauBord").update_dashboard(self)

func get_nearby_ble() -> Array:
	var all_ble = get_tree().get_nodes_in_group("blé")
	var radius := 2 * 64
	var ble := []
	for b in all_ble:
		if b.visible and b.global_position.distance_to(global_position) <= radius:
			ble.append(b)
	return ble


func add_wheat(amount: int):
	ble_stock += amount
	var tb = get_node("/root/game/CanvasLayer/TableauBord")
	if tb and tb.has_method("update_total_stock"):
		tb.update_total_stock()



func get_stock():
	return {"blé": ble_stock}


func respawn_ble(pos: Vector2):
	await get_tree().create_timer(60).timeout
	var new_ble = ble_scene.instantiate()
	new_ble.global_position = pos
	get_node("/root/game").add_child(new_ble)
	new_ble.add_to_group("blé")



func get_employes():
	return employes
	
