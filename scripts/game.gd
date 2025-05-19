## game.gd
extends Node2D

@export var tilemap: TileMapLayer
@onready var route_tilemap: TileMapLayer = $Map/Route/route
@onready var herbe_tilemap: TileMapLayer = $herbe
@onready var menu                        = $CanvasLayer/Menu
@onready var stats                       = $CanvasLayer/Menu/HUD/Infos_Stats

const TERRAIN_ID        = 0
const SAPIN_SCENE       = preload("res://scenes/sapin.tscn")
const BAIES       = preload("res://scenes/baies.tscn")
const COLLECT_BAIES       = preload("res://scenes/collect_baies.tscn")
const SCIERIE_SCENE     = preload("res://scenes/scierie.tscn")
const PUIT_SCENE        = preload("res://scenes/puit.tscn")
const CARRIERE_SCENE    = preload("res://scenes/carriere.tscn")
var pnj_scene: PackedScene = preload("res://scenes/pnj.tscn")
var next_id := 1

var last_cell: Vector2i = Vector2i()
var current_preview: Sprite2D  = null
var current_scene:   PackedScene = null
var selected_mode:   String      = ""
var grid_preview:    Node2D      = null
var pnj_counter := 1

var inventory := { "feu_camp": 1 }
var occupied_cells := {}
var objet_sizes = {
	"feu_camp": Vector2i(4, 4),
	"hutte":    Vector2i(4, 4),
	"sapin":    Vector2i(4, 4),
	"scierie":  Vector2i(4, 4),
	"puit":     Vector2i(4, 4),
	"baies":     Vector2i(2, 2),
	"collect_baies":     Vector2i(4, 4),
	"carriere": Vector2i(4, 4)
}

# A* grid
var route_astar := AStarGrid2D.new()
var grid_size := Vector2i(128, 128)

func _ready():
	# UI & spawn
	menu.connect("objet_selectionne", Callable(self, "_on_objet_selectionne"))
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	menu.update_inventory("feu_camp", inventory["feu_camp"])
	
	# crée les PNJ et les sapins
	spawn_pnjs(3)
	generate_sapins(100)

	# preview grid pour le placement
	grid_preview = preload("res://scenes/GridPreview.tscn").instantiate()
	add_child(grid_preview)
	grid_preview.z_index = 100

	# construit le graphe A* à partir du TileMap "route"
	build_route_astar()
	var cnt = _get_route_cells().size()


func _cell_to_id(cell: Vector2i) -> int:
	return cell.x + cell.y * grid_size.x

func _get_route_cells() -> Array:
	var cells = []
	for cell in route_tilemap.get_used_cells():
		if route_tilemap.get_cell_source_id(cell) != -1:
			cells.append(cell)
	return cells

func build_route_astar():
	# 1) Définition de la région à couvrir
	route_astar.region    = Rect2i(0, 0, grid_size.x, grid_size.y)
	route_astar.cell_size = Vector2(1, 1)
	# 2) Mise à jour automatique du graphe à partir des cellules « route »
	route_astar.update()
	# 3) Toutes les cellules non-route deviennent infranchissables
	var r = route_astar.region
	for x in range(r.position.x, r.position.x + r.size.x):
		for y in range(r.position.y, r.position.y + r.size.y):
			var cell = Vector2i(x, y)
			if route_tilemap.get_cell_source_id(cell) == -1:
				route_astar.set_point_solid(cell, true)

func _process(delta):
	if current_preview and selected_mode != "route":
		var size = objet_sizes.get(selected_mode, Vector2i(1, 1))
		var grid_pos = route_tilemap.local_to_map(get_global_mouse_position())
		grid_pos.x = int(grid_pos.x / size.x) * size.x
		grid_pos.y = int(grid_pos.y / size.y) * size.y
		var world_pos = route_tilemap.map_to_local(grid_pos)
		grid_preview.visible = false
		grid_preview.update_grid(world_pos, size)

	# coordonnées de la souris dans l'UI
	var cell = route_tilemap.local_to_map(get_global_mouse_position())
	if cell != last_cell:
		last_cell = cell
		menu.set_mouse_coords(cell)

	# position et couleur du sprite preview
	if current_preview:
		var size = objet_sizes[selected_mode]
		var gp = get_global_mouse_position()
		var grid_pos = route_tilemap.local_to_map(gp)
		grid_pos.x = int(grid_pos.x / size.x) * size.x
		grid_pos.y = int(grid_pos.y / size.y) * size.y
		current_preview.global_position = route_tilemap.map_to_local(grid_pos)
		if selected_mode != "route":
			current_preview.modulate = Color(1,1,1,0.5) if can_place_object(grid_pos, size) else Color(1,0,0,0.5)

	update_ui_stats()


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos  = get_global_mouse_position()
		var cell = route_tilemap.local_to_map(pos)

		match selected_mode:
			"gomme":
				for obj in get_tree().get_nodes_in_group("placeable"):
					if obj.global_position.distance_to(pos) < 16:
						var base = route_tilemap.local_to_map(obj.global_position)
						var size = objet_sizes[obj.name]
						for x in range(size.x):
							for y in range(size.y):
								occupied_cells.erase(base + Vector2i(x, y))
						if obj.name == "feu_camp":
							inventory["feu_camp"] += 1
							menu.update_inventory("feu_camp", inventory["feu_camp"])
						obj.queue_free()
						break
				route_tilemap.set_cells_terrain_connect([cell], 0, -1, -1)
				herbe_tilemap.set_cells_terrain_connect([cell], 0, TERRAIN_ID, 0)

			"route":
				placer_route()

			_:
				if selected_mode == "feu_camp" and inventory["feu_camp"] <= 0:
					return

				if current_scene:
					var size = objet_sizes[selected_mode]
					var base_cell = route_tilemap.local_to_map(pos)
					base_cell.x = int(base_cell.x / size.x) * size.x
					base_cell.y = int(base_cell.y / size.y) * size.y

					if can_place_object(base_cell, size):
						var inst = current_scene.instantiate()
						inst.name = selected_mode + "_" + str(randi() % 100000)
						inst.global_position = route_tilemap.map_to_local(base_cell)
						inst.add_to_group("placeable")
						inst.add_to_group("batiment")  # 🔥 ← ajoute cette ligne ici
						add_child(inst)
						get_node("CanvasLayer/TableauBord").update_dashboard(inst)


						if selected_mode == "scierie":
							assign_pnjs_to_work(inst, "bucheron")
						elif selected_mode == "carriere":
							assign_pnjs_to_work(inst, "mineur")
						elif selected_mode == "collect_baies":
							reset_all_pnjs()
							assign_pnjs_to_work(inst, "cueilleur")
						elif selected_mode == "hutte":
							assign_pnjs_to_hut(inst)

						for x in range(size.x):
							for y in range(size.y):
								occupied_cells[base_cell + Vector2i(x, y)] = true

						if selected_mode == "feu_camp":
							inventory["feu_camp"] -= 1
							menu.update_inventory("feu_camp", inventory["feu_camp"])

						current_preview.queue_free()
						current_preview = null
						current_scene = null

		# 🎯 Ajout : clic en dehors des bâtiments = on vide le tableau
		var clicked_batiment := false
		var mouse_pos = get_global_mouse_position()

		for bat in get_tree().get_nodes_in_group("batiment"):
			if bat.has_node("ClickArea"):
				var area = bat.get_node("ClickArea")
				if area is Area2D:
					if area.get_global_transform().origin.distance_to(mouse_pos) < 32:
						clicked_batiment = true
						break


		if not clicked_batiment:
			get_node("CanvasLayer/TableauBord").update_dashboard()

	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		placer_route()

func _on_objet_selectionne(nom: String):
	selected_mode = nom
	if current_preview:
		current_preview.queue_free()
		current_preview = null
		current_scene = null

	if nom == "gomme" or nom == "route":
		return

	var texture: Texture2D
	var scale := Vector2.ONE

	match nom:
		"feu_camp":
			current_scene = preload("res://scenes/feu_camp.tscn")
			texture       = load("res://assets/batiments/feu_camp.png")
		"hutte":
			current_scene = preload("res://scenes/hutte.tscn")
			texture       = load("res://assets/batiments/hutte.png")
		"sapin":
			current_scene = SAPIN_SCENE
			texture       = load("res://assets/batiments/sapin.png")
			scale         = Vector2(0.5, 0.5)
		"scierie":
			current_scene = SCIERIE_SCENE
			texture       = load("res://assets/batiments/scierie.png")
			scale         = Vector2(0.9, 0.9)
		"puit":
			current_scene = PUIT_SCENE
			texture       = load("res://assets/batiments/puit.png")
			scale         = Vector2(0.7, 0.7)
		"carriere":
			current_scene = CARRIERE_SCENE
			texture       = load("res://assets/batiments/carreire_pierre.png")
			scale         = Vector2(0.7, 0.7)
		"baies":
			current_scene = BAIES
			texture       = load("res://assets/batiments/baies2.png")
			scale         = Vector2(0.4, 0.4)
		"collect_baies":
			current_scene = COLLECT_BAIES
			texture       = load("res://assets/batiments/recolte_baies.png")
			scale         = Vector2(0.15, 0.15)
		_:
			return

	current_preview = Sprite2D.new()
	current_preview.texture = texture
	current_preview.modulate.a = 0.5
	current_preview.scale = scale
	add_child(current_preview)

	var grid_pos = route_tilemap.local_to_map(get_global_mouse_position())
	var size = objet_sizes.get(nom, Vector2i(1, 1))
	grid_pos.x = int(grid_pos.x / size.x) * size.x
	grid_pos.y = int(grid_pos.y / size.y) * size.y

func placer_route():
	var c = route_tilemap.local_to_map(get_global_mouse_position())
	if not occupied_cells.has(c):
		route_tilemap.set_cells_terrain_connect([c], 0, TERRAIN_ID, 0)
		# on met à jour l’ASTAR
		build_route_astar()

func can_place_object(start_cell: Vector2i, size: Vector2i) -> bool:
	for x in range(size.x):
		for y in range(size.y):
			var cc = start_cell + Vector2i(x,y)
			if occupied_cells.has(cc) or route_tilemap.get_cell_source_id(cc) != -1:
				return false
			if herbe_tilemap.get_cell_source_id(cc) == -1:
				return false
	return true

func update_ui_stats():
	stats.update_stats(
		get_tree().get_nodes_in_group("pnj").size(),
		Vector2i(get_tree().get_nodes_in_group("housing").size(), 50),
		Vector2i(0,0),
		100
	)

func spawn_pnjs(count: int):
	var tries = 0
	while count > 0 and tries < count*10:
		tries += 1
		var cell = Vector2i(randi_range(0,20), randi_range(0,20))
		if herbe_tilemap.get_cell_source_id(cell) == 0:
			var pn = pnj_scene.instantiate()
			pn.name = "pnj"
			pn.id = next_id
			next_id += 1
			pn.global_position = herbe_tilemap.map_to_local(cell)
			pn.add_to_group("pnj")
			pn.add_to_group("placeable")
			add_child(pn)
			count -= 1

func generate_sapins(count: int = 50):
	var rect = herbe_tilemap.get_used_rect()
	var tries = 0
	var spawned = 0
	while spawned < count and tries < count*10:
		tries += 1
		var cell = Vector2i(
			randi_range(rect.position.x, rect.position.x+rect.size.x-1),
			randi_range(rect.position.y, rect.position.y+rect.size.y-1)
		)
		if herbe_tilemap.get_cell_source_id(cell) == 0 and not occupied_cells.has(cell):
			var sp = SAPIN_SCENE.instantiate()
			sp.name = "sapin"
			sp.global_position = herbe_tilemap.map_to_local(cell)
			sp.add_to_group("sapin")
			sp.add_to_group("placeable")
			add_child(sp)
			occupied_cells[cell] = true
			spawned += 1

func assign_pnjs_to_hut(hut: Node2D):
	var free_pnjs := []
	for p in get_tree().get_nodes_in_group("pnj"):
		if not p.has_house:
			free_pnjs.append(p)
			if free_pnjs.size() >= 2:
				break

	for p in free_pnjs:
		p.name = "PNJ_" + str(pnj_counter)
		pnj_counter += 1
		p.has_house = true
		p.maison = hut
		hut.call("add_habitant", p)

func reset_all_pnjs():
	for p in get_tree().get_nodes_in_group("pnj"):
		p.metier = ""
		p.mission = ""
		p.lieu_travail = null
		p.chemin.clear()
		p.following_route = false
		
func assign_pnjs_to_work(building: Node2D, metier: String) -> void:
	var assigned := 0
	var route_cells := _get_route_cells()

	# 🧼 Libération des PNJ déjà assignés à ce métier
	for p in get_tree().get_nodes_in_group("pnj"):
		if p.metier == metier:
			p.metier = ""
			p.lieu_travail = null
			p.mission = ""
			p.chemin.clear()
			p.following_route = false

	for p in get_tree().get_nodes_in_group("pnj"):
		if p.metier != "":
			continue

		p.metier = metier
		p.lieu_travail = building
		p.mission = "aller_travailler"
		p.name = "PNJ_" + str(pnj_counter)
		pnj_counter += 1

		var raw_start = route_tilemap.local_to_map(p.global_position)
		var raw_goal = route_tilemap.local_to_map(building.global_position)

		var start = raw_start if raw_start in route_cells else _find_nearest_route_cell(raw_start)
		var goal  = raw_goal  if raw_goal  in route_cells else _find_nearest_route_cell(raw_goal)

		var cell_path = route_astar.get_point_path(start, goal)

		p.chemin.clear()
		var half = route_astar.cell_size * 0.5
		for cell in cell_path:
			p.chemin.append(route_tilemap.map_to_local(cell) + half)

		p.chemin.append(building.global_position)
		p.current_step = 0
		p.following_route = true
		p.call_deferred("update")



		if building.has_method("add_employe"):
			building.call("add_employe", p)

		assigned += 1
		if assigned >= 2:
			break

func _find_nearest_route_cell(cell: Vector2i) -> Vector2i:
	var best = cell
	var best_dist = INF
	for rc in _get_route_cells():
		var d = rc.distance_to(cell)
		if d < best_dist:
			best_dist = d
			best = rc
	return best
