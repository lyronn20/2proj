extends Node2D

var employes: Array = []
var nom_affichage := "Puit"
static var compteur := 1
var stock_eau := 0
var touche_eau := false
var last_water_point := Vector2.ZERO  # stocke le dernier point d'eau trouvé

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

func _process(_delta):
	if not touche_eau:
		detecte_eau()

func add_employe(pnj):
	if not employes.has(pnj):
		employes.append(pnj)

func add_water(amount: int):
	var game = get_node("/root/game")
	if game.get_tree().paused:
		return
	stock_eau += amount
	var tb = get_node("/root/game/CanvasLayer/TableauBord")
	if tb.has_method("update_total_stock"):
		tb.update_total_stock()
		
func get_stock():
	var stock = {"eau": stock_eau}
	return stock

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
				var pos = global_position + Vector2(dx * 16, dy * 16)
				var cell = tilemap.local_to_map(pos)
				var atlas = tilemap.get_cell_atlas_coords(cell)
				if atlas == Vector2i(2, 0):  # tuile d’eau
					var world_pos = tilemap.map_to_local(cell) + tilemap.global_position
					var goal_cell = game.route_tilemap.local_to_map(world_pos)
					if game.route_astar.region.has_point(goal_cell) and not game.route_astar.is_point_solid(goal_cell):
						touche_eau = true
						last_water_point = world_pos
						return

	touche_eau = false

func get_point_eau() -> Vector2:
	if not touche_eau:
		return global_position

	var game = get_node("/root/game")
	var cell = game.route_tilemap.local_to_map(last_water_point)

	# Trouver un point walkable le plus proche autour de l'eau
	var voisins = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var closest: Vector2i = Vector2i(-9999, -9999)
	var found := false
	for v in voisins:
		var voisin = cell + v
		if game.route_astar.region.has_point(voisin) and not game.route_astar.is_point_solid(voisin):
			closest = voisin
			found = true
			break


	if found:
		return game.route_tilemap.map_to_local(closest) + game.route_tilemap.global_position
	else:
		print("❌ Aucun accès walkable autour de l’eau")
		return global_position


func _on_click(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		get_node("/root/game/CanvasLayer/TableauBord").update_dashboard(self)
