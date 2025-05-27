## game.gd
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
@onready var bouton := $EpilepsieLayer/Button
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
var goal_accompli : = 0
var last_cell: Vector2i = Vector2i()
var current_preview: Node2D = null
var current_scene:   PackedScene = null
var selected_mode:   String      = ""
var grid_preview:    Node2D      = null
var pnj_counter := 1
var reproduction_timer := 0.0
var reproduction_interval := 130
var death_queue := []

var inventory := { "feu_camp": 1 }
var occupied_cells := {}
var objet_sizes = {
	"feu_camp": Vector2i(4, 4),
	"hutte":    Vector2i(4, 4),
	"sapin":    Vector2i(2, 2),
	"scierie":  Vector2i(4, 4),
	"puit":     Vector2i(4, 4),
	"baies":     Vector2i(2, 2),
	"pierre":     Vector2i(2, 2),
	"collect_baies":     Vector2i(4, 4),
	"carriere": Vector2i(4, 4),
	"ferme": Vector2i(4,4),
	"blé": Vector2i(2,2),
	"animaux_bat":Vector2i(4,4)
}

# A* grid
var route_astar := AStarGrid2D.new()
var grid_size := Vector2i(128, 128)

var repeatable_modes = ["baies", "sapin", "blé", "pierre", "hutte"]

# flag & timer pour le click-and-hold
var is_holding_place := false
var hold_place_timer := 0.0
var hold_place_interval := 0.01   
var is_holding_pont := false
var pont_hold_timer := 0.0
var pont_hold_interval := 0.01

func _ready():
	# départ tout invisible
	background.modulate.a = 0.4
	bouton.modulate.a = 0.4
	label.modulate.a = 0.4
	# fondu d’entrée
	var fade_in = get_tree().create_tween()
	fade_in.tween_property(background, "modulate:a", 1.0, 1.5)
	fade_in.tween_property(bouton, "modulate:a", 1.0, 1.5)
	fade_in.tween_property(label, "modulate:a", 1.0, 1.5)
	bouton.pressed.connect(_on_epilepsie_continue_pressed)
	menu = get_node("/root/game/CanvasLayer/Menu")
	menu.connect("objet_selectionne", Callable(self, "_on_objet_selectionne"))
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	menu.update_inventory("feu_camp", inventory["feu_camp"])
	menu.set_locked_buttons(goal_accompli)
	island_tilemaps = [herbe_tilemap, ile2_tilemap, ile3_tilemap, ile4_tilemap, ile5_tilemap]
	spawn_pnjs(21)
	generate_sapins(120)
	detecter_types_eau()

	grid_preview = preload("res://scenes/GridPreview.tscn").instantiate()
	add_child(grid_preview)
	grid_preview.z_index = 100
	add_child(audio)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("music"), -20)
	build_route_astar()


func _cell_to_id(cell: Vector2i) -> int:
	return cell.x + cell.y * grid_size.x

func _get_route_cells() -> Array:
	var cells = []
	for cell in route_tilemap.get_used_cells():
		if route_tilemap.get_cell_source_id(cell) != -1:
			cells.append(cell)
	return cells

func build_route_astar():
	route_astar.clear()

	# Calculer dynamiquement la zone utilisée par toutes les tilemaps
	var total_rect := herbe_tilemap.get_used_rect()
	for t in island_tilemaps:
		total_rect = total_rect.merge(t.get_used_rect())
	
	# 🔍 AJOUTER AUSSI map_tilemap dans le calcul
	total_rect = total_rect.merge(map_tilemap.get_used_rect())

	route_astar.region = total_rect
	route_astar.cell_size = Vector2(1, 1)
	route_astar.update()
	for x in range(total_rect.position.x, total_rect.position.x + total_rect.size.x):
		for y in range(total_rect.position.y, total_rect.position.y + total_rect.size.y):
			var cell = Vector2i(x, y)
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
				if atlas == Vector2i(2, 0):  # Ton WATER_ATLAS
					is_water = true
			var has_valid_terrain = (herbe_source == 0) or is_route or has_bridge
			for island in island_tilemaps:
				if island.get_cell_source_id(cell) == 0:
					has_valid_terrain = true
					break
			var traversable = (not is_water or has_bridge) and not is_building and has_valid_terrain
			route_astar.set_point_solid(cell, not traversable)

func _process(delta):
	reproduction_timer += delta
	if reproduction_timer >= reproduction_interval:
		reproduction_timer = 0.0
		verifier_reproduction()

	# Et tout ce qui est preview, UI, stats...

	
	# Système de reproduction
	reproduction_timer += delta
	if reproduction_timer >= reproduction_interval:
		reproduction_timer = 0.0
		verifier_reproduction()
	# 1) Si preview verrouillée → on la supprime et on sort
	if current_preview and menu.is_locked(selected_mode):
		current_preview.queue_free()
		current_preview = null
		current_scene = null
		return

	# 2) Mise à jour du grid_preview (si vous en avez un)
	if current_preview and selected_mode != "route":
		var size = objet_sizes.get(selected_mode, Vector2i(1, 1))
		var grid_pos = route_tilemap.local_to_map(get_global_mouse_position())
		grid_pos.x = int(grid_pos.x / size.x) * size.x
		grid_pos.y = int(grid_pos.y / size.y) * size.y
		var world_pos = route_tilemap.map_to_local(grid_pos)
		grid_preview.visible = false
		grid_preview.update_grid(world_pos, size)

	# 3) Coordonnées de la souris dans l’UI
	var cell = route_tilemap.local_to_map(get_global_mouse_position())
	if cell != last_cell:
		last_cell = cell
		menu.set_mouse_coords(cell)

	# 4) Mise à jour de la preview (position + couleur)
	if current_preview:
		var size = objet_sizes[selected_mode]
		var gp = get_global_mouse_position()
		var grid_pos = route_tilemap.local_to_map(gp)
		grid_pos.x = int(grid_pos.x / size.x) * size.x
		grid_pos.y = int(grid_pos.y / size.y) * size.y
		current_preview.global_position = route_tilemap.map_to_local(grid_pos)
		if selected_mode != "route":
			current_preview.modulate = Color(1,1,1,0.5) if can_place_object(grid_pos, size) else Color(1,0,0,0.5)

	# 5) Si on est en “hold” et que c’est un mode répétable (ou la gomme), on agit
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
	# 6) Mise à jour du HUD stat
	update_ui_stats()

func _place_object_at_mouse():
	# 1) Calcul de la cellule alignée
	var pos       = get_global_mouse_position()
	var size      = objet_sizes.get(selected_mode, Vector2i(1,1))
	var base_cell = route_tilemap.local_to_map(pos)
	base_cell.x = int(base_cell.x / size.x) * size.x
	base_cell.y = int(base_cell.y / size.y) * size.y

	# 2) Vérif placement
	if not can_place_object(base_cell, size):
		return

	# 3) Validation de la mission
	if goal_panel and goal_panel.has_method("valider_goal"):
		goal_panel.valider_goal(selected_mode)

	# 4) Instanciation
	var inst = current_scene.instantiate()
	inst.name            = "%s_%d" % [selected_mode, randi() % 100000]
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

	
		# 🔊 Bruitages
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


	# 5) Gestion spéciale feu de camp
	if selected_mode == "feu_camp":
		inventory["feu_camp"] -= 1
		menu.update_inventory("feu_camp", inventory["feu_camp"])
		menu.set_bloque("feu_camp", true)

	# 6) Affectation PNJ
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

	
	# 7) Marquage des cellules
	for x in range(size.x):
		for y in range(size.y):
			occupied_cells[base_cell + Vector2i(x, y)] = true

	# 8) Si ce n’est pas un mode répétable, on détruit la preview
	if not (selected_mode in repeatable_modes):
		current_preview.queue_free()
		current_preview = null
		current_scene = null


func _unhandled_input(event):
	if event is InputEventMouseButton:
		var mouse_pos = get_global_mouse_position()

		# ► Clic droit : désélection
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			selected_mode = ""
			if current_preview:
				current_preview.queue_free()
				current_preview = null
				current_scene = null
			get_node("CanvasLayer/TableauBord").update_dashboard()
			return

		# ► Clic gauche : interactions
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

				# Répétables ou gomme
				if selected_mode in repeatable_modes or selected_mode == "gomme":
					is_holding_place = true
					hold_place_timer = 0.0
					if selected_mode == "gomme":
						_erase_object_at_mouse()
					else:
						_place_object_at_mouse()

				# Mode route
				elif selected_mode == "route":
					placer_route()

				# Mode pont
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
		# ← on ne touche pas aux PNJ
		if obj.is_in_group("pnj"):
			continue

		if obj.global_position.distance_to(pos) < 16:
			var base     = route_tilemap.local_to_map(obj.global_position)
			var nom_base = obj.name.split("_")[0]
			var size     = objet_sizes.get(nom_base, Vector2i(1,1))

			# nettoyage de chaque tuile et restauration du terrain
			for x in range(size.x):
				for y in range(size.y):
					var c = base + Vector2i(x, y)
					occupied_cells.erase(c)
					route_tilemap.set_cells_terrain_connect([c], 0, -1, -1)
					
					# 🔥 RESTAURER LE BON TERRAIN selon l'île
					var terrain_restored = false
					
					# Essayer herbe_tilemap d'abord
					if herbe_tilemap.get_cell_source_id(c) != -1:
						herbe_tilemap.set_cells_terrain_connect([c], 0, TERRAIN_ID, 0)
						terrain_restored = true
					else:
						# Essayer les autres îles
						for island_tilemap in island_tilemaps:
							if island_tilemap.get_cell_source_id(c) != -1:
								island_tilemap.set_cells_terrain_connect([c], 0, TERRAIN_ID, 0)
								terrain_restored = true
								break
					
					# Si aucun terrain trouvé, restaurer sur herbe_tilemap par défaut
					if not terrain_restored:
						herbe_tilemap.set_cells_terrain_connect([c], 0, TERRAIN_ID, 0)

			# si c'est un feu de camp, on le re-débloque
			if nom_base == "feu_camp":
				inventory["feu_camp"] += 1
				menu.update_inventory("feu_camp", inventory["feu_camp"])
				menu.set_bloque("feu_camp", false)

			obj.queue_free()
			break

func _on_objet_selectionne(nom: String):
	selected_mode = nom

	# Supprime l’ancienne preview si elle existe
	if current_preview:
		current_preview.queue_free()
		current_preview = null
		current_scene = null

	# Pas de preview pour la gomme ni la route
	if nom == "gomme" or nom == "route":
		return

	# Sélectionne la scène à instancier
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

	# Instancie la vraie scène en mode preview
	current_preview = current_scene.instantiate()
	current_preview.modulate = Color(1, 1, 1, 0.5)
	current_preview.z_index = 1
	current_preview.set_meta("is_preview", true)

	# (Optionnel) désactive collisions et zones de clic de la preview
	if current_preview.has_node("CollisionShape2D"):
		current_preview.get_node("CollisionShape2D").disabled = true
	if current_preview.has_node("ClickArea"):
		current_preview.get_node("ClickArea").set_deferred("monitoring", false)

	add_child(current_preview)
	# Positionne immédiatement la preview sur la grille
	var size     = objet_sizes.get(nom, Vector2i(1,1))
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

	var voisins = {
		"haut": map_tilemap.get_cell_source_id(c + Vector2i(0, -1)),
		"bas": map_tilemap.get_cell_source_id(c + Vector2i(0, 1)),
		"gauche": map_tilemap.get_cell_source_id(c + Vector2i(-1, 0)),
		"droite": map_tilemap.get_cell_source_id(c + Vector2i(1, 0))
	}

	var atlas_coords: Vector2i

	if voisins["gauche"] == 0 or voisins["droite"] == 0:
		atlas_coords = Vector2i(11, 31)
	elif voisins["haut"] == 0 or voisins["bas"] == 0:
		atlas_coords = Vector2i(12, 32)
	else:
		atlas_coords = Vector2i(11, 31)

	pont_tilemap.set_cell(c, 0, atlas_coords)
	pont_tilemap.z_index = 10
	build_route_astar()


func placer_route():
	var c = route_tilemap.local_to_map(get_global_mouse_position())

	if herbe_tilemap.get_cell_source_id(c) == -1:
		return

	if occupied_cells.has(c) or route_tilemap.get_cell_source_id(c) != -1:
		return

	route_tilemap.set_cells_terrain_connect([c], 0, TERRAIN_ID, 0)
	build_route_astar()

	if goal_panel and goal_panel.has_method("valider_goal"):
		goal_panel.valider_goal("check_routes")


func can_place_object(start_cell: Vector2i, size: Vector2i) -> bool:
	if menu == null:
		print("❌ menu est null !")
		return false
	elif not menu.has_method("is_locked"):
		print("❌ menu n'a pas is_locked")
		return false
	else:
		var verrou = menu.is_locked(selected_mode)
		if verrou:
			return false

	for x in range(size.x):
		for y in range(size.y):
			var cc = start_cell + Vector2i(x, y)
			
			# Vérifier si la cellule est déjà occupée ou s'il y a une route
			if occupied_cells.has(cc) or route_tilemap.get_cell_source_id(cc) != -1:
				return false
			
			# 🔥 NOUVELLE LOGIQUE : Vérifier sur TOUTES les îles
			var valid_terrain = false
			
			# Vérifier herbe_tilemap (île principale)
			if herbe_tilemap.get_cell_source_id(cc) == 0:
				valid_terrain = true
			
			# Vérifier toutes les autres îles
			for island_tilemap in island_tilemaps:
				if island_tilemap.get_cell_source_id(cc) == 0:
					valid_terrain = true
					break
			
			# Si aucun terrain valide trouvé, on ne peut pas placer
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

	# 📊 Calcul progression par objectifs accomplis
	var progress := 0
	var goal_panel = get_node_or_null("CanvasLayer/Menu/HUD/Goal")
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


	
func verifier_reproduction():
	var couples = []
	var pnjs_libres = []
	
	# Trouve les couples (PNJ dans la même maison)
	for pnj in get_tree().get_nodes_in_group("pnj"):
		if pnj.has_house and pnj.age > 5.0:  
			var maison = pnj.maison
			var cohabitants = []
			for autre in get_tree().get_nodes_in_group("pnj"):
				if autre != pnj and autre.maison == maison:
					cohabitants.append(autre)
			
			if cohabitants.size() > 0:
				couples.append([pnj, cohabitants[0]])
	
	# Chance de reproduction pour chaque couple
	for couple in couples:
		if randf() < 0.22:  
			faire_bebe(couple[0].maison)

func faire_bebe(_unused):
	# 1) instanciation du bébé
	var bebe = pnj_scene.instantiate()
	bebe.name = "PNJ_%d" % next_id
	bebe.id = next_id
	next_id += 1
	bebe.add_to_group("pnj")
	bebe.add_to_group("placeable")
	add_child(bebe)

	# 2) on cherche une hutte libre (jamais celle des parents)
	var cible_hutte = _find_hutte_libre()
	# si aucune n'est libre, on retombe sur la hutte des parents
	if cible_hutte == null and bebe.maison:
		cible_hutte = bebe.maison
	# si toujours null, on fait sans maison
	if cible_hutte:
		# 3) positionnement autour de la hutte choisie
		var pos = cible_hutte.global_position
		bebe.global_position = pos + Vector2(randf_range(-10,10), randf_range(-10,10))
		# 4) inscription comme habitant
		bebe.has_house = true
		bebe.maison = cible_hutte
		if cible_hutte.has_method("add_habitant"):
			cible_hutte.call("add_habitant", bebe)
	else:
		# fallback : pile au centre de la carte
		bebe.global_position = Vector2.ZERO

	# 5) connexion du signal de mort
	_register_pnj(bebe)
	
	# 6) on tente immédiatement de remplir tous les postes vacants
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

	# 2) Fonction “spawn” : instancie, ajoute au tree, puis enregistre
func spawn_pnjs(count: int):
	var tries := 0
	while count > 0 and tries < count * 10:
		tries += 1
		# → Ta logique pour trouver `cell` valide (ex. random sur herbe_tilemap) :
		var cell = Vector2i(randi_range(0,20), randi_range(0,20))
		if herbe_tilemap.get_cell_source_id(cell) != 0:
			continue

		# Instanciation
		var pn = pnj_scene.instantiate()
		pn.name = "PNJ_%d" % next_id
		pn.id = next_id
		next_id += 1
		pn.global_position = herbe_tilemap.map_to_local(cell)
		pn.add_to_group("pnj")
		pn.add_to_group("placeable")
		add_child(pn)

		# Connexion du signal de mort
		_register_pnj(pn)

		count -= 1
	

func _on_pnj_died(metier: String, batiment: Node, pnj: Node) -> void:
	if not is_instance_valid(batiment):
		return

	# ➤ Retirer le PNJ de son boulot ou de sa hutte
	if batiment.has_method("remove_habitant"):
		batiment.remove_habitant(pnj)
	if batiment.has_method("remove_employe"):
		batiment.remove_employe(pnj)

	# ➤ Réassigner immédiatement un remplaçant pour CE bâtiment
	assign_pnjs_to_work(batiment, metier)

	# On peut stocker dans death_queue si besoin, mais l’important est la ré-affectation.
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
		_:
			pass


# 2) Pour chaque bâtiment du métier donné, on complète jusqu’à 2 employés.
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

	for building in get_tree().get_nodes_in_group("batiment"):
		if not building.has_method("add_employe"):
			continue
		if not building.name.begins_with(group_name):
			continue

		# tant qu’il reste de la place, on tente d’y envoyer un PNJ libre
		while building.employes.size() < 2:
			assign_pnjs_to_work(building, metier)

func generate_sapins(count: int = 50):
	var tries = 0
	var spawned = 0
	while spawned < count and tries < count * 20:
		tries += 1
		var tilemap = island_tilemaps[randi() % island_tilemaps.size()]
		if not tilemap.visible:
			continue
		var rect = tilemap.get_used_rect()
		if rect.size == Vector2i(0, 0):
			continue
		var cell = Vector2i(
			randi_range(rect.position.x, rect.position.x + rect.size.x - 1),
			randi_range(rect.position.y, rect.position.y + rect.size.y - 1)
		)
		if tilemap.get_cell_source_id(cell) == 0 and not occupied_cells.has(cell):
			var sp = SAPIN_SCENE.instantiate()
			sp.name = "sapin_" + str(randi() % 100000)
			sp.global_position = tilemap.map_to_local(cell) + tilemap.global_position
			sp.add_to_group("sapin")
			sp.add_to_group("placeable")
			add_child(sp)
			occupied_cells[cell] = true
			spawned += 1


func assign_pnjs_to_hut(_ignore: Variant = null):
	var free_pnjs := []
	for p in get_tree().get_nodes_in_group("pnj"):
		if not p.has_house:
			free_pnjs.append(p)

	for hut in get_tree().get_nodes_in_group("housing"):
		while hut.habitants.size() < 2 and free_pnjs.size() > 0:
			var pnj = free_pnjs.pop_front()
			pnj.name = "PNJ_" + str(pnj_counter)
			pnj_counter += 1
			pnj.has_house = true
			pnj.maison = hut
			hut.call("add_habitant", pnj)



func reset_all_pnjs():
	for p in get_tree().get_nodes_in_group("pnj"):
		p.metier = ""
		p.mission = ""
		p.lieu_travail = null
		p.chemin.clear()
		p.following_route = false
		
func assign_pnjs_to_work(building: Node2D, metier: String) -> void:
	# Combien de postes il reste à pourvoir (max 2)
	var needed: int = 2 - building.employes.size()
	if needed <= 0:
		return

	var route_cells = _get_route_cells()

	# On parcourt les PNJ libres (sans lieu_travail)
	for p in get_tree().get_nodes_in_group("pnj"):
		if p.lieu_travail != null:
			continue

		# 1) On assigne le PNJ
		p.metier       = metier
		p.lieu_travail = building
		p.mission      = "aller_travailler"
		p.name         = "PNJ_%d" % pnj_counter
		pnj_counter   += 1

		# 2) Calcul du chemin A*
		var raw_start = route_tilemap.local_to_map(p.global_position)
		var raw_goal  = route_tilemap.local_to_map(building.global_position)
		var start_pos = raw_start if raw_start in route_cells else _find_nearest_walkable_cell(raw_start)
		var goal_pos  = raw_goal  if raw_goal  in route_cells else _find_nearest_walkable_cell(raw_goal)
		var cell_path = route_astar.get_point_path(start_pos, goal_pos)

		p.chemin.clear()
		var half = route_astar.cell_size * 0.5
		for cell in cell_path:
			p.chemin.append(route_tilemap.map_to_local(cell) + half)
		p.chemin.append(building.global_position)

		p.current_step    = 0
		p.following_route = true
		if p.has_method("update"):
			p.call_deferred("update")

		# 3) On notifie le bâtiment
		if building.has_method("add_employe") and not building.employes.has(p):
			building.call("add_employe", p)

		# 4) Décrément et sortie dès que complet
		needed -= 1
		if needed <= 0:
			break



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
		# On utilise la méthode get_stock() plutôt que carre.has()
		if carre.has_method("get_stock"):
			total_pierre += carre.get_stock()
	return total_pierre
# Total des baies de tous les collecteurs de baies
func print_total_baies_stock() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("baies"):
		if node.has_method("get_stock"):
			total += node.get_stock()
	return total

# Total du blé de toutes les fermes
func print_total_ble_stock() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("ble"):
		if node.has_method("get_stock"):
			total += node.get_stock()
	return total

# Total du bois de toutes les scieries
func print_total_wood_stock() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("scierie"):
		if node.has_method("get_stock"):
			total += node.get_stock()
	return total

# Total du bois de toutes les scieries
func print_total_eau_stock() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("puit"):
		if node.has_method("get_stock"):
			total += node.get_stock()
	return total

func sauvegarder_jeu():
	var save = FileAccess.open("user://sauvegarde.save", FileAccess.WRITE)
	# 🔹 Sauver les PNJ
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

	# 🔹 Sauver tous les objets placeables (y compris sapins)
	var objets_data = []
	for obj in get_tree().get_nodes_in_group("placeable"):
		objets_data.append({
			"type": obj.name,
			"position": obj.global_position
		})
	save.store_var(objets_data)

	save.close()
	print("✅ Sauvegarde effectuée")

func charger_jeu():
	if not FileAccess.file_exists("user://sauvegarde.save"):
		print("⚠️ Aucun fichier de sauvegarde trouvé")
		return

	var file = FileAccess.open("user://sauvegarde.save", FileAccess.READ)

	# Supprimer anciens PNJ et objets
	for p in get_tree().get_nodes_in_group("pnj"):
		p.queue_free()
	for o in get_tree().get_nodes_in_group("placeable"):
		o.queue_free()

	# Charger PNJ
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

	# Charger bâtiments et sapins
	var objets_data = file.get_var()
	for data in objets_data:
		var name = data["type"]
		var pos = data["position"]
		var scene: PackedScene = null

		if name.begins_with("sapin"):
			scene = preload("res://scenes/sapin.tscn")
		elif name.begins_with("feu_camp"):
			scene = preload("res://scenes/feu_camp.tscn")
		elif name.begins_with("hutte"):
			scene = preload("res://scenes/hutte.tscn")
		elif name.begins_with("scierie"):
			scene = preload("res://scenes/scierie.tscn")
		elif name.begins_with("carriere"):
			scene = preload("res://scenes/carriere.tscn")
		elif name.begins_with("puit"):
			scene = preload("res://scenes/puit.tscn")
		elif name.begins_with("collect_baies"):
			scene = preload("res://scenes/collect_baies.tscn")
		elif name.begins_with("baies"):
			scene = preload("res://scenes/baies.tscn")
		elif name.begins_with("pierre"):
			scene = preload("res://scenes/pierre.tscn")
		elif name.begins_with("ferme"):
			scene = preload("res://scenes/ferme.tscn")
		elif name.begins_with("blé"):
			scene = preload("res://scenes/blé.tscn")
		elif name.begins_with("animaux_bat"):
			scene = preload("res://scenes/animaux_bat.tscn")



		if scene:
			var inst = scene.instantiate()
			inst.name = name
			inst.global_position = pos
			inst.add_to_group("placeable")

			if name.begins_with("sapin") or name.begins_with("baies") or name.begins_with("pierre") or name.begins_with("blé"):
				if name.begins_with("sapin"):
					inst.add_to_group("sapin")
				var cell = herbe_tilemap.local_to_map(pos)
				occupied_cells[cell] = true
			else:
				inst.add_to_group("batiment")

			add_child(inst)

	# Réattribuer les PNJ à leur lieu de travail
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

			var path = route_astar.get_point_path(start, goal)
			p.chemin.clear()
			var half = route_astar.cell_size * 0.5
			for cell in path:
				p.chemin.append(route_tilemap.map_to_local(cell) + half)
			p.chemin.append(cible.global_position)

			p.current_step = 0
			p.following_route = true
			cible.add_employe(p)

	file.close()
	print("✅ Partie chargée manuellement")

func _on_epilepsie_continue_pressed():
	var fade_out = get_tree().create_tween()
	fade_out.tween_property(background, "modulate:a", 0.0, 1.5)
	fade_out.tween_callback(Callable($EpilepsieLayer, "hide"))
	

func detecter_types_eau():
	var eau_types = {}
	var used_rect = map_tilemap.get_used_rect()
	
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var cell = Vector2i(x, y)
			var source = map_tilemap.get_cell_source_id(cell)
			var atlas = map_tilemap.get_cell_atlas_coords(cell)
			
			# Si c'est une tuile avec source_id = 2 (vos tuiles d'eau)
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
		var info = eau_types[key]	
	return eau_types
