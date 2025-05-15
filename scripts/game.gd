extends Node2D

@onready var route_tilemap: TileMapLayer = $Map/Route/route
@onready var herbe_tilemap: TileMapLayer = $herbe
@onready var menu = $CanvasLayer/Menu
@onready var stats = $CanvasLayer/Menu/HUD/Infos_Stats

var last_cell = null
const TERRAIN_ID = 0
var current_preview: Sprite2D = null
var current_scene: PackedScene = null
var selected_mode: String = ""

var objet_sizes = {
	"feu_camp": Vector2i(4, 4),
	"hutte": Vector2i(4, 4),
	"sapin": Vector2i(1, 1)
}

var occupied_cells := {}
var pnj_scene: PackedScene = preload("res://scenes/pnj.tscn")
const SAPIN_SCENE = preload("res://scenes/Sapin.tscn")

func _ready():
	menu.connect("objet_selectionne", Callable(self, "_on_objet_selectionne"))
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	spawn_pnjs(20)
	generate_sapins(100)

func _process(_delta):
	var cell = route_tilemap.local_to_map(get_global_mouse_position())

	if cell != last_cell:
		last_cell = cell
		menu.set_mouse_coords(cell)

	if current_preview and selected_mode != "route":
		var size = objet_sizes.get(selected_mode, Vector2i(1, 1))
		var grid_pos = route_tilemap.local_to_map(get_global_mouse_position())
		grid_pos.x = int(grid_pos.x / size.x) * size.x
		grid_pos.y = int(grid_pos.y / size.y) * size.y
		current_preview.global_position = route_tilemap.map_to_local(grid_pos)

		# ✅ Vérifie la possibilité de placement pour colorer le sprite
		if can_place_object(grid_pos, size):
			current_preview.modulate = Color(1, 1, 1, 0.5)  # blanc transparent
		else:
			current_preview.modulate = Color(1, 0, 0, 0.5)  # rouge transparent

	elif current_preview:
		var grid_pos = route_tilemap.local_to_map(get_global_mouse_position())
		current_preview.global_position = route_tilemap.map_to_local(grid_pos)

	update_ui_stats()


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos = get_global_mouse_position()
		var cell = route_tilemap.local_to_map(pos)

		if selected_mode == "gomme":
			for obj in get_tree().get_nodes_in_group("placeable"):
				if obj is Node2D and obj.global_position.distance_to(pos) < 16:
					# Libère la cellule
					var obj_cell = route_tilemap.local_to_map(obj.global_position)
					occupied_cells.erase(obj_cell)
					obj.queue_free()
					break

			route_tilemap.set_cells_terrain_connect([cell], 0, -1, -1)
			herbe_tilemap.set_cells_terrain_connect([cell], 0, TERRAIN_ID, 0)

		elif selected_mode == "route":
			placer_route()

		elif current_scene:
			var size = objet_sizes.get(selected_mode, Vector2i(1, 1))
			var base_cell = route_tilemap.local_to_map(pos)
			base_cell.x = int(base_cell.x / size.x) * size.x
			base_cell.y = int(base_cell.y / size.y) * size.y

			if can_place_object(base_cell, size):
				var instance = current_scene.instantiate()
				instance.global_position = route_tilemap.map_to_local(base_cell)
				instance.add_to_group("placeable")

				if selected_mode == "sapin":
					instance.add_to_group("sapin")
				else:
					instance.add_to_group("housing")

				add_child(instance)

				for x in range(size.x):
					for y in range(size.y):
						var placed_cell = base_cell + Vector2i(x, y)
						occupied_cells[placed_cell] = true

				current_preview.queue_free()
				current_preview = null
				current_scene = null

	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		placer_route()

func placer_route():
	var cell = route_tilemap.local_to_map(get_global_mouse_position())
	if occupied_cells.has(cell):
		return
	route_tilemap.set_cells_terrain_connect([cell], 0, TERRAIN_ID, 0)

func _on_objet_selectionne(nom: String):
	selected_mode = nom

	if current_preview:
		current_preview.queue_free()
		current_preview = null
		current_scene = null

	if nom == "gomme" or nom == "route":
		return

	var texture: Texture2D = null

	match nom:
		"feu_camp":
			current_scene = preload("res://scenes/feu_camp.tscn")
			texture = load("res://assets/batiments/feu_camp.png")
		"hutte":
			current_scene = preload("res://scenes/hutte.tscn")
			texture = load("res://assets/batiments/hutte.png")
		"sapin":
			current_scene = SAPIN_SCENE
			texture = load("res://assets/environnement/sapin.png")  # adapte si besoin
		_:
			return

	current_preview = Sprite2D.new()
	current_preview.texture = texture
	current_preview.modulate.a = 0.5
	add_child(current_preview)

func can_place_object(start_cell: Vector2i, size: Vector2i) -> bool:
	for x in range(size.x):
		for y in range(size.y):
			var check_cell = start_cell + Vector2i(x, y)
			if occupied_cells.has(check_cell):
				return false
			if route_tilemap.get_cell_source_id(check_cell) != -1:
				return false
	return true

func update_ui_stats():
	var population = get_tree().get_nodes_in_group("pnj").size()
	var housing_count = get_tree().get_nodes_in_group("housing").size()
	var housing_total = housing_count

	var jobs_occupied = 0
	var jobs_total = 0
	var progress = 100

	stats.update_stats(population, Vector2i(housing_count, housing_total), Vector2i(jobs_occupied, jobs_total), progress)

func spawn_pnjs(count: int):
	var tries = 0
	var max_tries = count * 10

	while count > 0 and tries < max_tries:
		tries += 1
		var x = randi_range(0, 20)
		var y = randi_range(0, 20)
		var world_pos = Vector2(x, y)
		var cell = herbe_tilemap.local_to_map(world_pos)

		if herbe_tilemap.get_cell_source_id(cell) == 0:
			var pnj = pnj_scene.instantiate()
			pnj.global_position = herbe_tilemap.map_to_local(cell)
			pnj.add_to_group("pnj")
			add_child(pnj)
			count -= 1

func generate_sapins(count: int = 50):
	var map_size = Vector2i(herbe_tilemap.get_used_rect().size)
	var origin = herbe_tilemap.get_used_rect().position

	var spawned := 0
	var tries := 0

	while spawned < count and tries < count * 10:
		tries += 1
		var x = randi_range(origin.x, origin.x + map_size.x - 1)
		var y = randi_range(origin.y, origin.y + map_size.y - 1)
		var cell := Vector2i(x, y)

		# ✅ Vérifie que c’est de l’herbe et pas occupé
		if herbe_tilemap.get_cell_source_id(cell) == 0 and not occupied_cells.has(cell):
			var sapin = SAPIN_SCENE.instantiate()
			sapin.position = herbe_tilemap.map_to_local(cell)
			sapin.add_to_group("placeable")
			sapin.add_to_group("sapin")
			add_child(sapin)

			# ✅ Réserve la case dans occupied_cells
			occupied_cells[cell] = true
			spawned += 1
