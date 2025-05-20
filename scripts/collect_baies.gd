extends Node2D

var baies_stock := 0
@onready var baie_scene: PackedScene = preload("res://scenes/baies.tscn")

var employes: Array = []

func add_employe(pnj: Node2D):
	employes.append(pnj)

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

func get_nearby_baies() -> Array:
	# 1) Récupère toutes les baies du groupe
	var all_baies = get_tree().get_nodes_in_group("baies")
	var radius := 15 * 64
	var baies := []
	for b in all_baies:
		if b.visible and b.global_position.distance_to(global_position) <= radius:
			baies.append(b)
	return baies


func add_fruit(amount: int):
	baies_stock += amount
	print("📦 Baies stocke :", baies_stock)

func get_stock() -> int:
	return baies_stock

func respawn_baie(pos: Vector2):
	await get_tree().create_timer(60).timeout
	var new_baie = baie_scene.instantiate()
	new_baie.global_position = pos
	get_node("/root/game").add_child(new_baie)
	new_baie.add_to_group("baies")
