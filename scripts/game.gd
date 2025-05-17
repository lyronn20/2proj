extends Node2D

@export var tilemap: TileMapLayer
@onready var route_tilemap: TileMapLayer = $Map/Route/route
@onready var herbe_tilemap: TileMapLayer = $herbe
@onready var menu                        = $CanvasLayer/Menu
@onready var stats                       = $CanvasLayer/Menu/HUD/Infos_Stats

const TERRAIN_ID        = 0
const SAPIN_SCENE       = preload("res://scenes/sapin.tscn")
const SCIERIE_SCENE     = preload("res://scenes/scierie.tscn")
const PUIT_SCENE        = preload("res://scenes/puit.tscn")
const CARRIERE_SCENE    = preload("res://scenes/carriere.tscn")
var pnj_scene: PackedScene = preload("res://scenes/pnj.tscn")
var grid_preview: Node2D


# Un seul feu de camp autorisé (le reste illimité)
var inventory := {
	"feu_camp": 1
}

var last_cell        = null
var current_preview  : Sprite2D    = null
var current_scene    : PackedScene = null
var selected_mode    := ""
var occupied_cells   := {}


# Tailles en cellules de chaque objet
var objet_sizes = {
	"feu_camp": Vector2i(4, 4),
	"hutte":    Vector2i(4, 4),
	"sapin":    Vector2i(4, 4),
	"scierie":  Vector2i(4, 4),
	"puit":     Vector2i(4, 4),
	"carriere": Vector2i(4, 4)
}

func _ready():
	menu.connect("objet_selectionne", Callable(self, "_on_objet_selectionne"))
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# initialise le bouton feu_camp
	menu.update_inventory("feu_camp", inventory["feu_camp"])
	spawn_pnjs(20)
	generate_sapins(100)
	grid_preview = preload("res://scenes/GridPreview.tscn").instantiate()
	add_child(grid_preview)
	grid_preview.z_index = 100


func _process(_delta):
	if current_preview and selected_mode != "route":
		var size = objet_sizes.get(selected_mode, Vector2i(1, 1))
		var grid_pos = route_tilemap.local_to_map(get_global_mouse_position())
		grid_pos.x = int(grid_pos.x / size.x) * size.x
		grid_pos.y = int(grid_pos.y / size.y) * size.y
		var world_pos = route_tilemap.map_to_local(grid_pos)
		grid_preview.visible = true
		grid_preview.update_grid(world_pos, size)
	var cell = route_tilemap.local_to_map(get_global_mouse_position())
	if cell != last_cell:
		last_cell = cell
		menu.set_mouse_coords(cell)

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
						# libère toutes les cellules qu'occupait l'objet
						var base = route_tilemap.local_to_map(obj.global_position)
						var size = objet_sizes[obj.name]
						for x in range(size.x):
							for y in range(size.y):
								occupied_cells.erase(base + Vector2i(x,y))
						# si c'était un feu de camp, remet en stock
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
				# empêche de poser un feu de camp si stock épuisé
				if selected_mode == "feu_camp" and inventory["feu_camp"] <= 0:
					print("🚫 Plus de feu de camp disponible.")
					return

				if current_scene:
					var size = objet_sizes[selected_mode]
					var base_cell = route_tilemap.local_to_map(pos)
					base_cell.x = int(base_cell.x / size.x) * size.x
					base_cell.y = int(base_cell.y / size.y) * size.y

					if can_place_object(base_cell, size):
						var inst = current_scene.instantiate()
						inst.name = selected_mode
						inst.global_position = route_tilemap.map_to_local(base_cell)
						inst.add_to_group("placeable")
						add_child(inst)

						for x in range(size.x):
							for y in range(size.y):
								occupied_cells[base_cell + Vector2i(x,y)] = true

						if selected_mode == "feu_camp":
							inventory["feu_camp"] -= 1
							menu.update_inventory("feu_camp", inventory["feu_camp"])
							print("✅ Feu de camp posé, stock restant :", inventory["feu_camp"])

						current_preview.queue_free()
						current_preview = null
						current_scene = null

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
	var scale := Vector2.ONE  # par défaut 1

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
			texture       = load("res://assets/batiments/carreire_pierre.png")  # corrigé ici
			scale         = Vector2(0.7, 0.7)
		_:
			return

	current_preview = Sprite2D.new()
	current_preview.texture = texture
	
	current_preview.modulate.a = 0.5
	current_preview.scale = scale
	add_child(current_preview)
	
	# 🟥 Afficher la grille ici
	
	var grid_pos = route_tilemap.local_to_map(get_global_mouse_position())
	var size = objet_sizes.get(nom, Vector2i(1, 1))
	grid_pos.x = int(grid_pos.x / size.x) * size.x
	grid_pos.y = int(grid_pos.y / size.y) * size.y	


func placer_route():
	var c = route_tilemap.local_to_map(get_global_mouse_position())
	if not occupied_cells.has(c):
		route_tilemap.set_cells_terrain_connect([c], 0, TERRAIN_ID, 0)

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
