extends Node2D
@export var tilemap: TileMapLayer
@onready var route_tilemap: TileMapLayer = $Route/route
@onready var pont_tilemap : TileMapLayer = $Pont/pont
@onready var herbe_tilemap: TileMapLayer = $herbe
@onready var map_tilemap: TileMapLayer = $Map
@onready var ile2_tilemap: TileMapLayer = $ile2
@onready var ile3_tilemap: TileMapLayer = $ile3
@onready var ile4_tilemap: TileMapLayer = $ile4
@onready var ile5_tilemap: TileMapLayer = $ile5
@onready var menu = $CanvasLayer/Menu
@onready var stats = $CanvasLayer/Menu/HUD/Infos_Stats
@onready var goal_panel = $CanvasLayer/Menu/HUD/Goal
@onready var epilepsie_layer := $EpilepsieLayer
@onready var background := $EpilepsieLayer/Background
@onready var epi_bouton := $EpilepsieLayer/Button
@onready var label := $EpilepsieLayer/Label
@onready var audio := AudioStreamPlayer.new()

const TERRAIN_ID = 0
const FEU_CAMP_SCENE = preload("res://scenes/feu_camp.tscn")
const HUTTE_SCENE = preload("res://scenes/hutte.tscn")
const SAPIN_SCENE = preload("res://scenes/sapin.tscn")
const BAIES = preload("res://scenes/baies.tscn")
const COLLECT_BAIES = preload("res://scenes/collect_baies.tscn")
const SCIERIE_SCENE = preload("res://scenes/scierie.tscn")
const PUIT_SCENE = preload("res://scenes/puit.tscn")
const CARRIERE_SCENE = preload("res://scenes/carriere.tscn")
const PIERRE = preload("res://scenes/pierre.tscn")
const FERME = preload("res://scenes/ferme.tscn")
const BLE = preload("res://scenes/blé.tscn")
const ANIMAUX_BAT = preload("res://scenes/animaux_bat.tscn")
const FEU_CAMP_SOUND = preload("res://song/feu_camp.mp3")
const SCIERIE_SOUND = preload("res://song/scierie.mp3")

var island_tilemaps := []
var pnj_scene: PackedScene = preload("res://scenes/pnj.tscn")
var next_id := 1
var goal_accompli := 0
var last_cell: Vector2i = Vector2i()
var current_preview: Node2D = null
var current_scene: PackedScene = null
var selected_mode: String = ""
var pnj_counter := 1
var reproduction_timer := 0.0
var reproduction_interval := 130
var reassignment_timer := 0.0
var reassignment_interval := 30.0  
var death_queue := []
var astar_initialized := false
var dirty_cells := {}  
var astar_update_timer := 0.0
var astar_update_interval := 0.5  
var max_cells_per_update := 20  
var inventory := { "feu_camp": 1 }
var occupied_cells := {}
var objet_sizes = {
	"feu_camp": Vector2i(4, 4),
	"hutte": Vector2i(4, 4),
	"sapin": Vector2i(2, 2),
	"scierie": Vector2i(4, 4),
	"puit": Vector2i(4, 4),
	"baies": Vector2i(2, 2),
	"pierre": Vector2i(2, 2),
	"collect_baies": Vector2i(4, 4),
	"carriere": Vector2i(4, 4),
	"ferme": Vector2i(4,4),
	"blé": Vector2i(2,2),
	"animaux_bat":Vector2i(4,4)
}

var route_astar := AStarGrid2D.new()
var grid_size := Vector2i(128, 128)
var repeatable_modes = ["baies", "sapin", "blé", "pierre", "hutte"]
var is_holding_place := false
var hold_place_timer := 0.0
var hold_place_interval := 0.01   
var is_holding_pont := false
var pont_hold_timer := 0.0
var pont_hold_interval := 0.01

func _ready():
	background.modulate.a = 0.4
	epi_bouton.modulate.a = 0.4
	label.modulate.a = 0.4
	var fade_in = get_tree().create_tween()
	fade_in.tween_property(background, "modulate:a", 1.0, 1.5)
	fade_in.tween_property(epi_bouton, "modulate:a", 1.0, 1.5)
	fade_in.tween_property(label, "modulate:a", 1.0, 1.5)
	epi_bouton.pressed.connect(_on_epilepsie_continue_pressed)
	menu = get_node("/root/game/CanvasLayer/Menu")
	menu.connect("objet_selectionne", Callable(self, "_on_objet_selectionne"))
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	menu.update_inventory("feu_camp", inventory["feu_camp"])
	menu.set_locked_buttons(goal_accompli)
	island_tilemaps = [herbe_tilemap, ile2_tilemap, ile3_tilemap, ile4_tilemap, ile5_tilemap]
	spawn_pnjs(21)
	generate_sapins(120)
	detecter_types_eau()
	add_child(audio)
	initialize_astar()

func _cell_to_id(cell: Vector2i) -> int:
	return cell.x + cell.y * grid_size.x
	
func _get_route_cells() -> Array:
	var cells = []
	for cell in route_tilemap.get_used_cells():
		if route_tilemap.get_cell_source_id(cell) != -1:
			cells.append(cell)
	return cells

func initialize_astar():
	if astar_initialized:
		return
		
	route_astar.clear()
	var total_rect := herbe_tilemap.get_used_rect()
	for t in island_tilemaps:
		total_rect = total_rect.merge(t.get_used_rect())
	total_rect = total_rect.merge(map_tilemap.get_used_rect())

	route_astar.region = total_rect
	route_astar.cell_size = Vector2(1, 1)
	route_astar.update()
	
	for x in range(total_rect.size.x):
		for y in range(total_rect.size.y):
			var cell = Vector2i(total_rect.position.x + x, total_rect.position.y + y)
			dirty_cells[cell] = true
	astar_initialized = true

func update_astar_incremental():
	if dirty_cells.is_empty():
		return
		
	var cells_processed = 0
	var cells_to_remove = []
	
	for cell in dirty_cells.keys():
		if cells_processed >= max_cells_per_update:
			break
			
		_process_astar_cell(cell)
		cells_to_remove.append(cell)
		cells_processed += 1
	for cell in cells_to_remove:
		dirty_cells.erase(cell)

func mark_cell_dirty(cell: Vector2i):
	dirty_cells[cell] = true
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var neighbor = cell + Vector2i(dx, dy)
			if route_astar.region.has_point(neighbor):
				dirty_cells[neighbor] = true

func _process_astar_cell(cell: Vector2i):
	var herbe_source = herbe_tilemap.get_cell_source_id(cell)
	var map_source = map_tilemap.get_cell_source_id(cell)
	var pont_source = pont_tilemap.get_cell_source_id(cell)
	var route_source = route_tilemap.get_cell_source_id(cell)
	var is_water = false
	var has_bridge = pont_source != -1
	var is_route = route_source != -1
	var is_building = occupied_cells.has(cell)
	
	if map_source == 2: 
		is_water = true
	if herbe_source != -1:
		var atlas = herbe_tilemap.get_cell_atlas_coords(cell)
		if atlas == Vector2i(2, 0):
			is_water = true
	
	var has_valid_terrain = (herbe_source == 0) or is_route or has_bridge
	for island in island_tilemaps:
		if island.get_cell_source_id(cell) == 0:
			has_valid_terrain = true
			break
	
	var traversable = (not is_water or has_bridge) and not is_building and has_valid_terrain
	route_astar.set_point_solid(cell, not traversable)
	
func _process(delta):
	astar_update_timer += delta
	if astar_update_timer >= astar_update_interval:
		astar_update_timer = 0.0
		update_astar_incremental()
	reproduction_timer += delta
	if reproduction_timer >= reproduction_interval:
		reproduction_timer = 0.0
		verifier_reproduction()
	reassignment_timer += delta
	if reassignment_timer >= reassignment_interval:
		reassignment_timer = 0.0
		reassign_all_unemployed_pnjs()
	
	if current_preview and menu.is_locked(selected_mode):
		current_preview.queue_free()
		current_preview = null
		current_scene = null
		return
	
	if current_preview and selected_mode != "route":
		var size = objet_sizes.get(selected_mode, Vector2i(1, 1))
		var grid_pos = route_tilemap.local_to_map(get_global_mouse_position())
		grid_pos.x = int(grid_pos.x / size.x) * size.x
		grid_pos.y = int(grid_pos.y / size.y) * size.y
		var world_pos = route_tilemap.map_to_local(grid_pos)
	
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
	
	if is_holding_place:
		hold_place_timer += delta
		if hold_place_timer >= hold_place_interval:
			hold_place_timer = 0
			if selected_mode == "gomme":
				_erase_object_at_mouse()
			else:
				_place_object_at_mouse()
	
	if is_holding_pont:
		pont_hold_timer += delta
		if pont_hold_timer >= pont_hold_interval:
			pont_hold_timer = 0.0
			placer_pont()
	
	if Engine.get_process_frames() % 30 == 0:  
		update_ui_stats()

func _place_object_at_mouse():
	var pos = get_global_mouse_position()
	var size = objet_sizes.get(selected_mode, Vector2i(1,1))
	var base_cell = route_tilemap.local_to_map(pos)
	base_cell.x = int(base_cell.x / size.x) * size.x
	base_cell.y = int(base_cell.y / size.y) * size.y
	
	if not can_place_object(base_cell, size):
		return
	
	if goal_panel and goal_panel.has_method("valider_goal"):
		goal_panel.valider_goal(selected_mode)
	
	var inst = current_scene.instantiate()
	inst.name = "%s_%d" % [selected_mode, randi() % 100000]
	inst.global_position = route_tilemap.map_to_local(base_cell)
	inst.add_to_group("placeable")
	inst.add_to_group("batiment")
	
	if selected_mode == "carriere":
		inst.add_to_group("carriere")
	if selected_mode == "hutte":
		inst.add_to_group("housing")
	
	add_child(inst)
	get_node("CanvasLayer/TableauBord").update_dashboard(inst)
	
	if selected_mode == "hutte":
		assign_pnjs_to_hut(inst)
	
	match selected_mode:
		"feu_camp":
			audio.stream = FEU_CAMP_SOUND
			audio.play()
			inventory["feu_camp"] -= 1
			menu.update_inventory("feu_camp", inventory["feu_camp"])
			menu.set_bloque("feu_camp", true)
		"scierie":
			audio.stream = SCIERIE_SOUND
			audio.play()
		_:
			pass
	
	match selected_mode:
		"scierie":
			assign_pnjs_to_work(inst, "bucheron")
		"carriere":
			assign_pnjs_to_work(inst, "mineur")
		"ferme":
			assign_pnjs_to_work(inst, "fermier")
		"collect_baies":
			assign_pnjs_to_work(inst, "cueilleur")
		"hutte":
			assign_pnjs_to_hut(inst)
		"puit":
			assign_pnjs_to_work(inst, "pompier")
		_:
			pass
	
	for x in range(size.x):
		for y in range(size.y):
			var cell = base_cell + Vector2i(x, y)
			occupied_cells[cell] = true
			mark_cell_dirty(cell)
	
	if not (selected_mode in repeatable_modes):
		current_preview.queue_free()
		current_preview = null
		current_scene = null

func _unhandled_input(event):
	if event is InputEventMouseButton:
		var mouse_pos = get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			selected_mode = ""
			if current_preview:
				current_preview.queue_free()
				current_preview = null
				current_scene = null
			get_node("CanvasLayer/TableauBord").update_dashboard()
			return
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				for bat in get_tree().get_nodes_in_group("batiment"):
					if bat.has_node("ClickArea") and bat.get_node("ClickArea").global_position.distance_to(mouse_pos) < 32:
						get_node("CanvasLayer/TableauBord").update_dashboard(bat)
						return
				
				for pnj in get_tree().get_nodes_in_group("pnj"):
					if pnj.global_position.distance_to(mouse_pos) < 16:
						get_node("CanvasLayer/TableauBord").update_dashboard(pnj)
						return
				
				if selected_mode in repeatable_modes or selected_mode == "gomme":
					is_holding_place = true
					hold_place_timer = 0.0
					if selected_mode == "gomme":
						_erase_object_at_mouse()
					else:
						_place_object_at_mouse()
				elif selected_mode == "route":
					placer_route()
				elif selected_mode == "Pont":
					placer_pont()
				elif current_scene:
					_place_object_at_mouse()
			else:
				is_holding_place = false
				var clicked := false
				for bat in get_tree().get_nodes_in_group("batiment"):
					if bat.has_node("ClickArea") and bat.get_node("ClickArea").global_position.distance_to(mouse_pos) < 32:
						clicked = true
						break
				if not clicked:
					get_node("CanvasLayer/TableauBord").update_dashboard()
	
	elif event is InputEventKey:
		if event.keycode == KEY_R:
			if event.pressed and not event.echo and not menu.is_locked("sol_terre"):
				selected_mode = "route"
				placer_route()
		elif event.keycode == KEY_P:
			if event.pressed and not event.echo and not menu.is_locked("Pont"):
				is_holding_pont = true
				pont_hold_timer = 0.0
				placer_pont()
			elif not event.pressed:
				is_holding_pont = false

func _erase_object_at_mouse():
	var pos = get_global_mouse_position()
	for obj in get_tree().get_nodes_in_group("placeable"):
		if obj.is_in_group("pnj"):
			continue
		if obj.global_position.distance_to(pos) < 16:
			var base = route_tilemap.local_to_map(obj.global_position)
			var nom_base = obj.name.split("_")[0]
			var size = objet_sizes.get(nom_base, Vector2i(1,1))
			for x in range(size.x):
				for y in range(size.y):
					var c = base + Vector2i(x, y)
					occupied_cells.erase(c)
					mark_cell_dirty(c)
					route_tilemap.set_cells_terrain_connect([c], 0, -1, -1)
					
					var terrain_restored = false
					if herbe_tilemap.get_cell_source_id(c) != -1:
						herbe_tilemap.set_cells_terrain_connect([c], 0, TERRAIN_ID, 0)
						terrain_restored = true
					else:
						for island_tilemap in island_tilemaps:
							if island_tilemap.get_cell_source_id(c) != -1:
								island_tilemap.set_cells_terrain_connect([c], 0, TERRAIN_ID, 0)
								terrain_restored = true
								break
					if not terrain_restored:
						herbe_tilemap.set_cells_terrain_connect([c], 0, TERRAIN_ID, 0)
			
			if nom_base == "feu_camp":
				inventory["feu_camp"] += 1
				menu.update_inventory("feu_camp", inventory["feu_camp"])
				menu.set_bloque("feu_camp", false)
			
			obj.queue_free()
			break

func _on_objet_selectionne(nom: String):
	selected_mode = nom
	if current_preview:
		current_preview.queue_free()
		current_preview = null
		current_scene = null
	
	if nom == "gomme" or nom == "route":
		return
	
	match nom:
		"feu_camp":
			current_scene = FEU_CAMP_SCENE
		"hutte":
			current_scene = HUTTE_SCENE
		"sapin":
			current_scene = SAPIN_SCENE
		"baies":
			current_scene = BAIES
		"collect_baies":
			current_scene = COLLECT_BAIES
		"scierie":
			current_scene = SCIERIE_SCENE
		"puit":
			current_scene = PUIT_SCENE
		"carriere":
			current_scene = CARRIERE_SCENE
		"pierre":
			current_scene = PIERRE
		"ferme":
			current_scene = FERME
		"blé":
			current_scene = BLE
		"animaux_bat":
			current_scene = ANIMAUX_BAT
		_:
			return
	
	current_preview = current_scene.instantiate()
	current_preview.modulate = Color(1, 1, 1, 0.5)
	current_preview.z_index = 1
	current_preview.set_meta("is_preview", true)
	
	if current_preview.has_node("CollisionShape2D"):
		current_preview.get_node("CollisionShape2D").disabled = true
	if current_preview.has_node("ClickArea"):
		current_preview.get_node("ClickArea").set_deferred("monitoring", false)
	
	add_child(current_preview)
	var size = objet_sizes.get(nom, Vector2i(1,1))
	var grid_pos = route_tilemap.local_to_map(get_global_mouse_position())
	grid_pos.x = int(grid_pos.x / size.x) * size.x
	grid_pos.y = int(grid_pos.y / size.y) * size.y
	current_preview.global_position = route_tilemap.map_to_local(grid_pos)

func placer_pont():
	var c = pont_tilemap.local_to_map(get_global_mouse_position())
	if map_tilemap.get_cell_source_id(c) != 2:
		return
	if occupied_cells.has(c) or route_tilemap.get_cell_source_id(c) != -1:
		return
	
	var plus_proches = {
		"haut": map_tilemap.get_cell_source_id(c + Vector2i(0, -1)),
		"bas": map_tilemap.get_cell_source_id(c + Vector2i(0, 1)),
		"gauche": map_tilemap.get_cell_source_id(c + Vector2i(-1, 0)),
		"droite": map_tilemap.get_cell_source_id(c + Vector2i(1, 0))
	}
	
	var atlas_coords: Vector2i
	if plus_proches["gauche"] == 0 or plus_proches["droite"] == 0:
		atlas_coords = Vector2i(11, 31)
	elif plus_proches["haut"] == 0 or plus_proches["bas"] == 0:
		atlas_coords = Vector2i(12, 32)
	else:
		atlas_coords = Vector2i(11, 31)
	
	pont_tilemap.set_cell(c, 0, atlas_coords)
	pont_tilemap.z_index = 10
	mark_cell_dirty(c)

func placer_route():
	var c = route_tilemap.local_to_map(get_global_mouse_position())
	if herbe_tilemap.get_cell_source_id(c) == -1:
		return
	if occupied_cells.has(c) or route_tilemap.get_cell_source_id(c) != -1:
		return
	
	route_tilemap.set_cells_terrain_connect([c], 0, TERRAIN_ID, 0)
	mark_cell_dirty(c)
	
	if goal_panel and goal_panel.has_method("valider_goal"):
		goal_panel.valider_goal("check_routes")

func can_place_object(start_cell: Vector2i, size: Vector2i) -> bool:
	if menu == null:
		return false
	elif not menu.has_method("is_locked"):
		return false
	else:
		var verrou = menu.is_locked(selected_mode)
		if verrou:
			return false
	
	for x in range(size.x):
		for y in range(size.y):
			var cc = start_cell + Vector2i(x, y)
			if occupied_cells.has(cc) or route_tilemap.get_cell_source_id(cc) != -1:
				return false
			
			var valid_terrain = false
			if herbe_tilemap.get_cell_source_id(cc) == 0:
				valid_terrain = true
			
			for island_tilemap in island_tilemaps:
				if island_tilemap.get_cell_source_id(cc) == 0:
					valid_terrain = true
					break
			
			if not valid_terrain:
				return false
	
	return true

func update_ui_stats():
	var population = get_tree().get_nodes_in_group("pnj").size()
	var housing_total = get_tree().get_nodes_in_group("housing").size()
	var max_housing = 50
	var jobs_occupees = 0
	
	for p in get_tree().get_nodes_in_group("pnj"):
		if p.metier != "" and p.is_inside_tree():
			jobs_occupees += 1
	
	var progress := 0
	if goal_panel:
		var total = goal_panel.goals.size()
		var done = goal_panel.goal_accompli
		progress = int(float(done) / max(total, 1) * 100)
	
	stats.update_stats(
		population,
		Vector2i(housing_total, max_housing),
		jobs_occupees,
		progress
	)

var _pathfinding_cache := {}
var _cache_cleanup_timer := 0.0
var _cache_cleanup_interval := 10.0  

func get_cached_path(start: Vector2i, goal: Vector2i) -> Array:
	var cache_key = str(start) + "_" + str(goal)
	
	if _pathfinding_cache.has(cache_key):
		return _pathfinding_cache[cache_key]
	
	var path = route_astar.get_point_path(start, goal)
	_pathfinding_cache[cache_key] = path
	if _pathfinding_cache.size() > 100:
		var keys = _pathfinding_cache.keys()
		_pathfinding_cache.erase(keys[0])
	
	return path

func _clear_pathfinding_cache():
	_pathfinding_cache.clear()

func verifier_reproduction():
	var couples = []
	var _pnjs_libres = []
	for pnj in get_tree().get_nodes_in_group("pnj"):
		if pnj.has_house and pnj.age > 5.0:  
			var maison = pnj.maison
			var cohabitants = []
			for autre in get_tree().get_nodes_in_group("pnj"):
				if autre != pnj and autre.maison == maison:
					cohabitants.append(autre)
			
			if cohabitants.size() > 0:
				couples.append([pnj, cohabitants[0]])
	
	for couple in couples:
		if randf() < 0.32:  
			faire_bebe(couple[0].maison)
	
	reassign_all_unemployed_pnjs()

func faire_bebe(_unused):
	var bebe = pnj_scene.instantiate()
	bebe.name = "PNJ_%d" % next_id
	bebe.id = next_id
	next_id += 1
	bebe.add_to_group("pnj")
	bebe.add_to_group("placeable")
	add_child(bebe)
	
	var cible_hutte = _find_hutte_libre()
	if cible_hutte == null and bebe.maison:
		cible_hutte = bebe.maison
	
	if cible_hutte:
		var pos = cible_hutte.global_position
		bebe.global_position = pos + Vector2(randf_range(-10,10), randf_range(-10,10))
		bebe.has_house = true
		bebe.maison = cible_hutte
		if cible_hutte.has_method("add_habitant"):
			cible_hutte.call("add_habitant", bebe)
	else:
		bebe.global_position = Vector2.ZERO
	
	_register_pnj(bebe)
	_try_fill_all_jobs_for_metier("bucheron")
	_try_fill_all_jobs_for_metier("mineur")
	_try_fill_all_jobs_for_metier("fermier")
	_try_fill_all_jobs_for_metier("cueilleur")
	_try_fill_all_jobs_for_metier("pompier")

func _find_hutte_libre() -> Node2D:
	for hut in get_tree().get_nodes_in_group("housing"):
		if hut.habitants.size() < 2:
			return hut
	return null
	
func _register_pnj(pnj):
	pnj.died.connect(Callable(self, "_on_pnj_died"))
	
func spawn_pnjs(count: int):
	var tries := 0
	while count > 0 and tries < count * 10:
		tries += 1
		var cell = Vector2i(randi_range(0,20), randi_range(0,20))
		if herbe_tilemap.get_cell_source_id(cell) != 0:
			continue
		
		var pn = pnj_scene.instantiate()
		pn.name = "PNJ_%d" % next_id
		pn.id = next_id
		next_id += 1
		pn.global_position = herbe_tilemap.map_to_local(cell)
		pn.add_to_group("pnj")
		pn.add_to_group("placeable")
		add_child(pn)
		_register_pnj(pn)
		count -= 1
		
func _on_pnj_died(metier: String, batiment: Node, pnj: Node) -> void:
	if is_instance_valid(batiment):
		if batiment.has_method("remove_habitant"):
			batiment.remove_habitant(pnj)
		if batiment.has_method("remove_employe"):
			batiment.remove_employe(pnj)
	await get_tree().process_frame
	if metier != "" and is_instance_valid(batiment):
		assign_pnjs_to_work(batiment, metier)
		match metier:
			"bucheron":
				_try_fill_all_jobs_for_metier("bucheron")
			"mineur":
				_try_fill_all_jobs_for_metier("mineur")
			"fermier":
				_try_fill_all_jobs_for_metier("fermier")
			"cueilleur":
				_try_fill_all_jobs_for_metier("cueilleur")
			"pompier":
				_try_fill_all_jobs_for_metier("pompier")
	if pnj.has_house:
		assign_pnjs_to_hut()

func _try_fill_all_jobs_for_metier(metier: String) -> void:
	var group_name := ""
	match metier:
		"bucheron":  group_name = "scierie"
		"mineur":    group_name = "carriere"
		"fermier":   group_name = "ferme"
		"cueilleur": group_name = "collect_baies"
		"pompier":   group_name = "puit"
		_:
			return
	
	var buildings := []
	for building in get_tree().get_nodes_in_group("batiment"):
		if not is_instance_valid(building):
			continue
		if not building.has_method("add_employe"):
			continue
		if building.name.to_lower().begins_with(group_name.to_lower()):
			buildings.append(building)
	
	for building in buildings:
		var current_employees = building.employes.size() if "employes" in building else 0
		var max_employees = building.get("max_employes") if building.has_method("get") and "max_employes" in building else 2
		
		while current_employees < max_employees:
			var old_size = building.employes.size()
			assign_pnjs_to_work(building, metier)

			if building.employes.size() == old_size:
				break
			current_employees = building.employes.size()
			
func reassign_all_unemployed_pnjs():
	_try_fill_all_jobs_for_metier("bucheron")
	_try_fill_all_jobs_for_metier("mineur")
	_try_fill_all_jobs_for_metier("fermier")
	_try_fill_all_jobs_for_metier("cueilleur")
	_try_fill_all_jobs_for_metier("pompier")
	assign_pnjs_to_hut()
	
func generate_sapins(count: int = 50):
	var tries = 0
	var spawned = 0
	while spawned < count and tries < count * 20:
		tries += 1
		var selected_tilemap = island_tilemaps[randi() % island_tilemaps.size()]
		if not selected_tilemap.visible:
			continue
		
		var rect = selected_tilemap.get_used_rect()
		if rect.size == Vector2i(0, 0):
			continue
		
		var cell = Vector2i(
			randi_range(rect.position.x, rect.position.x + rect.size.x - 1),
			randi_range(rect.position.y, rect.position.y + rect.size.y - 1)
		)
		
		if selected_tilemap.get_cell_source_id(cell) == 0 and not occupied_cells.has(cell):
			var sp = SAPIN_SCENE.instantiate()
			sp.name = "sapin_" + str(randi() % 100000)
			sp.global_position = selected_tilemap.map_to_local(cell) + selected_tilemap.global_position
			sp.add_to_group("sapin")
			sp.add_to_group("placeable")
			add_child(sp)
			occupied_cells[cell] = true
			spawned += 1

func assign_pnjs_to_hut(new_hut: Node2D = null):
	var homeless_pnjs := []
	for pnj in get_tree().get_nodes_in_group("pnj"):
		if not pnj.has_house and pnj.is_inside_tree():
			homeless_pnjs.append(pnj)
	
	if homeless_pnjs.is_empty():
		return
	
	var available_huts := []
	for hut in get_tree().get_nodes_in_group("housing"):
		if not is_instance_valid(hut):
			continue
		var current_habitants = hut.habitants.size() if hut.has_method("get") and "habitants" in hut else 0
		var max_habitants = hut.get("max_habitants") if hut.has_method("get") and "max_habitants" in hut else 2
		
		if current_habitants < max_habitants:
			available_huts.append(hut)
	
	for hut in available_huts:
		var max_habitants = hut.get("max_habitants") if hut.has_method("get") and "max_habitants" in hut else 2
		while hut.habitants.size() < max_habitants and homeless_pnjs.size() > 0:
			var pnj = homeless_pnjs.pop_front()
			pnj.has_house = true
			pnj.maison = hut
			pnj.name = "PNJ_%d" % pnj_counter
			pnj_counter += 1
			
			if hut.has_method("add_habitant"):
				hut.add_habitant(pnj)
			
func reset_all_pnjs():
	for p in get_tree().get_nodes_in_group("pnj"):
		p.metier = ""
		p.mission = ""
		p.lieu_travail = null
		p.chemin.clear()
		p.following_route = false
		
func assign_pnjs_to_work(building: Node2D, metier: String) -> void:
	if not is_instance_valid(building):
		return
	
	var current_employees = building.employes.size() if building.has_method("get") and "employes" in building else 0
	var max_employees = building.get("max_employes") if building.has_method("get") and "max_employes" in building else 2
	var needed = max_employees - current_employees
	
	if needed <= 0:
		return
	
	var available_pnjs := []
	for pnj in get_tree().get_nodes_in_group("pnj"):
		if not is_instance_valid(pnj) or not pnj.is_inside_tree():
			continue
		if (pnj.lieu_travail == null or pnj.metier == "") and pnj.age > 3.0:
			available_pnjs.append(pnj)
	
	if available_pnjs.is_empty():
		return
	var assigned_count = 0
	for pnj in available_pnjs:
		if assigned_count >= needed:
			break
		pnj.metier = metier
		pnj.lieu_travail = building
		pnj.mission = "aller_travailler"
		pnj.name = "PNJ_%d" % pnj_counter
		pnj_counter += 1
		var route_cells = _get_route_cells()
		var raw_start = route_tilemap.local_to_map(pnj.global_position)
		var raw_goal = route_tilemap.local_to_map(building.global_position)
		var start_pos = raw_start if raw_start in route_cells else _find_nearest_walkable_cell(raw_start)
		var goal_pos = raw_goal if raw_goal in route_cells else _find_nearest_walkable_cell(raw_goal)
		var cell_path = get_cached_path(start_pos, goal_pos)
		pnj.chemin.clear()
		var half = route_astar.cell_size * 0.5
		for cell in cell_path:
			pnj.chemin.append(route_tilemap.map_to_local(cell) + half)
		pnj.chemin.append(building.global_position)
		pnj.current_step = 0
		pnj.following_route = true
		if pnj.has_method("update"):
			pnj.call_deferred("update")
		
		if building.has_method("add_employe") and not building.employes.has(pnj):
			building.add_employe(pnj)
		
		assigned_count += 1


func check_and_reassign_pnjs():
	var unemployed_pnjs = 0
	var available_jobs = 0
	
	for pnj in get_tree().get_nodes_in_group("pnj"):
		if pnj.lieu_travail == null and pnj.age > 3.0:
			unemployed_pnjs += 1
	
	for building in get_tree().get_nodes_in_group("batiment"):
		if building.has_method("add_employe"):
			var current = building.employes.size() if "employes" in building else 0
			var max_emp = building.get("max_employes") if building.has_method("get") and "max_employes" in building else 2
			available_jobs += max(0, max_emp - current)
	
	if unemployed_pnjs > 0 and available_jobs > 0:
		reassign_all_unemployed_pnjs()
		
func _find_nearest_walkable_cell(cell: Vector2i) -> Vector2i:
	var best = cell
	var best_dist = INF
	for dx in range(-5, 6):
		for dy in range(-5, 6):
			var c = cell + Vector2i(dx, dy)
			if route_astar.region.has_point(c) and not route_astar.is_point_solid(c):
				var d = c.distance_to(cell)
				if d < best_dist:
					best = c
					best_dist = d
	
	return best
	
func get_all_animaux_disponibles() -> Array:
	var all = []
	for bat in get_tree().get_nodes_in_group("batiment"):
		if bat.has_method("get_animaux_disponibles"):
			all += bat.get_animaux_disponibles()
	return all

func debloquer_objet(nom: String):
	var bouton = $ZoneInventaire/HBoxContainer.get_node_or_null(nom)
	if bouton and bouton.has_node("Croix"):
		bouton.get_node("Croix").visible = false

func print_total_carriere_stock() -> int:
	var total_pierre := 0
	for carre in get_tree().get_nodes_in_group("carriere"):
		if carre.has_method("get_stock"):
			total_pierre += carre.get_stock()
	return total_pierre
	
func print_total_baies_stock() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("baies"):
		if node.has_method("get_stock"):
			total += node.get_stock()
	return total

func print_total_ble_stock() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("ble"):
		if node.has_method("get_stock"):
			total += node.get_stock()
	return total

func print_total_wood_stock() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("scierie"):
		if node.has_method("get_stock"):
			total += node.get_stock()
	return total

func print_total_eau_stock() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("puit"):
		if node.has_method("get_stock"):
			total += node.get_stock()
	return total

func _on_epilepsie_continue_pressed():
	var fade_out = get_tree().create_tween()
	fade_out.tween_property(background, "modulate:a", 0.0, 1.5)
	fade_out.tween_callback(Callable($EpilepsieLayer, "hide"))
	
func detecter_types_eau():
	var eau_types = {}
	var used_rect = map_tilemap.get_used_rect()
	var start_x = used_rect.position.x
	var end_x = start_x + used_rect.size.x
	var start_y = used_rect.position.y
	var end_y = start_y + used_rect.size.y
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			var cell = Vector2i(x, y)
			var source = map_tilemap.get_cell_source_id(cell)
			var atlas = map_tilemap.get_cell_atlas_coords(cell)
			
			if source == 2:
				var key = str(atlas)
				if not eau_types.has(key):
					eau_types[key] = {
						"atlas": atlas,
						"count": 0,
						"example_pos": cell
					}
				eau_types[key]["count"] += 1
	
	for key in eau_types.keys():
		var _info = eau_types[key]	
	
	return eau_types

func sauvegarder_jeu():
	var save = FileAccess.open("user://sauvegarde.save", FileAccess.WRITE)
	var pnj_data = []
	
	for pnj in get_tree().get_nodes_in_group("pnj"):
		pnj_data.append({
			"position": pnj.global_position,
			"id": pnj.id,
			"metier": pnj.metier,
			"faim": pnj.faim,
			"soif": pnj.soif,
			"energie": pnj.energy
		})
	
	save.store_var(pnj_data)
	
	var objets_data = []
	for obj in get_tree().get_nodes_in_group("placeable"):
		objets_data.append({
			"type": obj.name,
			"position": obj.global_position
		})
	
	save.store_var(objets_data)
	save.close()
	
func charger_jeu():
	if not FileAccess.file_exists("user://sauvegarde.save"):
		return

	var file = FileAccess.open("user://sauvegarde.save", FileAccess.READ)

	# Supprimer anciens PNJ et objets
	for p in get_tree().get_nodes_in_group("pnj"):
		p.queue_free()
	for o in get_tree().get_nodes_in_group("placeable"):
		o.queue_free()

	# Recharger les PNJ
	var pnj_data = file.get_var()
	var scene_pnj = preload("res://scenes/pnj.tscn")
	for data in pnj_data:
		var p = scene_pnj.instantiate()
		p.global_position = data["position"]
		p.id = data["id"]
		p.metier = data["metier"]
		p.faim = data["faim"]
		p.soif = data["soif"]
		p.energy = data["energie"]
		p.name = "PNJ_" + str(p.id)
		p.add_to_group("pnj")
		p.add_to_group("placeable")
		add_child(p)

	# Recharger les objets
	var objets_data = file.get_var()
	for data in objets_data:
		var objet = data["type"]
		var pos = data["position"]
		var scene: PackedScene = null

		if objet.begins_with("sapin"):
			scene = SAPIN_SCENE
		elif objet.begins_with("feu_camp"):
			scene = FEU_CAMP_SCENE
		elif objet.begins_with("hutte"):
			scene = HUTTE_SCENE
		elif objet.begins_with("scierie"):
			scene = SCIERIE_SCENE
		elif objet.begins_with("carriere"):
			scene = CARRIERE_SCENE
		elif objet.begins_with("puit"):
			scene = PUIT_SCENE
		elif objet.begins_with("collect_baies"):
			scene = COLLECT_BAIES
		elif objet.begins_with("baies"):
			scene = BAIES
		elif objet.begins_with("pierre"):
			scene = PIERRE
		elif objet.begins_with("ferme"):
			scene = FERME
		elif objet.begins_with("blé"):
			scene = BLE
		elif objet.begins_with("animaux_bat"):
			scene = ANIMAUX_BAT

		if scene:
			var inst = scene.instantiate()
			inst.global_position = pos
			inst.add_to_group("placeable")

			if objet.begins_with("sapin") or objet.begins_with("baies") or objet.begins_with("pierre") or objet.begins_with("blé"):
				if objet.begins_with("sapin"):
					inst.add_to_group("sapin")
				var cell = herbe_tilemap.local_to_map(pos)
				occupied_cells[cell] = true
			else:
				inst.add_to_group("batiment")

			add_child(inst)

	_clear_pathfinding_cache()

	# Réassigner PNJ à leurs bâtiments
	for p in get_tree().get_nodes_in_group("pnj"):
		if p.metier == "":
			continue

		var cible = null
		for b in get_tree().get_nodes_in_group("batiment"):
			if b.has_method("add_employe") and not b.employes.has(p):
				cible = b
				break

		if cible:
			p.lieu_travail = cible
			p.mission = "aller_travailler"
			var start = route_tilemap.local_to_map(p.global_position)
			var goal = route_tilemap.local_to_map(cible.global_position)

			if route_tilemap.get_cell_source_id(start) == -1:
				start = _find_nearest_walkable_cell(start)
			if route_tilemap.get_cell_source_id(goal) == -1:
				goal = _find_nearest_walkable_cell(goal)

			var path = get_cached_path(start, goal)
			p.chemin.clear()
			var half = route_astar.cell_size * 0.5
			for cell in path:
				p.chemin.append(route_tilemap.map_to_local(cell) + half)
			p.chemin.append(cible.global_position)
			p.current_step = 0
			p.following_route = true
			cible.add_employe(p)

	file.close()
