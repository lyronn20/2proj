extends Node2D

var baies_stock := 0
static var compteur := 1
@onready var baie_scene: PackedScene = preload("res://scenes/baies.tscn")

var employes: Array = []

func add_employe(pnj: Node2D):
	employes.append(pnj)

func _ready():
	add_to_group("batiment")
	add_to_group("baies")  
	set_meta("nom_affichage", "Collecteur : "+ str(compteur))
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

func get_nearby_baies() -> Array:
	# 1) Récupère toutes les baies du groupe
	var all_baies = get_tree().get_nodes_in_group("baies")
	var radius := 2 * 64
	var baies := []
	for b in all_baies:
		if b.visible and b.global_position.distance_to(global_position) <= radius:
			baies.append(b)
	return baies


func add_fruit(amount: int):
	baies_stock += amount
	var tb = get_node("/root/game/CanvasLayer/TableauBord")
	if tb and tb.has_method("update_total_stock"):
		tb.update_total_stock()


func get_stock():
	return {"baies": baies_stock}


func respawn_baie(pos: Vector2):
	await get_tree().create_timer(60).timeout
	var new_baie = baie_scene.instantiate()
	new_baie.global_position = pos
	get_node("/root/game").add_child(new_baie)
	new_baie.add_to_group("baies")
