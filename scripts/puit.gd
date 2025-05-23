extends Node2D

var employes: Array = []
var nom_affichage := "Puit"
static var compteur := 1
var stock_eau := 0
var touche_eau := false
var last_water_point := Vector2.ZERO  # stocke le dernier point d'eau trouvé

func add_employe(pnj):
	if not employes.has(pnj):
		employes.append(pnj)

func add_water(amount: int):
	stock_eau += amount

func get_stock():
	return stock_eau

func boire() -> bool:
	if stock_eau > 0:
		stock_eau -= 1
		return true
	return false

func detecte_eau():
	var rayon := 3
	var game = get_node("/root/game")

	for tilemap in game.island_tilemaps:
		for dx in range(-rayon, rayon + 1):
			for dy in range(-rayon, rayon + 1):
				var cell = tilemap.local_to_map(global_position + Vector2(dx * 16, dy * 16))
				var atlas = tilemap.get_cell_atlas_coords(cell)
				if atlas == Vector2i(2, 0):  # eau
					touche_eau = true
					last_water_point = tilemap.map_to_local(cell) + tilemap.global_position
					return
	touche_eau = false

func get_point_eau() -> Vector2:
	return last_water_point if touche_eau else global_position

func _ready():
	if has_meta("is_preview") and get_meta("is_preview") == true:
		return
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
	detecte_eau()

func _on_click(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		get_node("/root/game/CanvasLayer/TableauBord").update_dashboard(self)
