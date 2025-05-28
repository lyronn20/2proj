extends CharacterBody2D
@export var recharge_hold_time := 15.0  
@onready var sprite: AnimatedSprite2D    = $AnimatedSprite2D
@onready var herbe_tilemap: TileMapLayer = get_node("/root/game/herbe")
@onready var route_tilemap: TileMapLayer = get_node("/root/game/Route/route")
@onready var game := get_node("/root/game")
@onready var astar: AStarGrid2D           = game.route_astar
@onready var energy_bar           = $Energybar/Fill
@onready var energy_bar_container = $Energybar
@onready var click_area           = $ClickArea

var id: int = 0
var show_energy := false
var has_house := false
var maison: Node2D       = null
var metier       := ""
var lieu_travail: Node2D = null
var mission      := ""
var mission_apres_recharge := ""
var energy := 100.0
var faim   := 100.0
var soif   := 100.0
var faim_tick := 0.0
var soif_tick := 0.0
var age := 0.0  
var esperance_vie := randf_range(15.0, 25.0)  	
var facteur_sante := 1.0  
var direction      := Vector2.ZERO
var speed          := 30.0
var wander_timer   := 0.0
var change_interval := 2.0
var chemin         = []   
var current_step   := 0
var following_route := false
var travail_rate      := 20.0      
var travail_threshold := 5.0
var recharge_rate := 20.0
var current_tree: Node2D = null
var cutting_timer := 0.0
var cutting_duration := 1  
var current_baie: Node2D = null
var current_rock: Node2D = null
var mining_timer := 0.0
var mining_duration := 1.0   
var eau_timer := 0.0
var temps_pompage := 1.5
var animal_retry_timer := 0.0
var lieu_boisson = null
signal died(metier: String, batiment: Node, pnj: Node)

func _ready():
	sprite.play("walk")
	pick_new_direction()
	energy_bar_container.visible = false
	click_area.connect("input_event", Callable(self, "_on_click"))
	collision_layer = 1
	collision_mask = 0
	match metier:
		"bucheron":
			mission = "aller_travailler"
			search_next_tree()
		"cueilleur":
			mission = "aller_travailler"
			search_next_baie()
		"mineur":
			mission = "aller_travailler"
			search_next_rock()
		"fermier":
			mission = "aller_travailler"
			search_next_ble()
		"pompier":
			if lieu_travail and lieu_travail.touche_eau:
				mission = "aller_bord_eau"
				go_to(lieu_travail.get_point_eau(), "aller_bord_eau")
		_:
			mission = ""



func _process(_delta):
	faim = clamp(faim, 0, 100)
	soif = clamp(soif, 0, 100)
	if faim < 20 and mission == "" and current_baie == null:
		if lieu_travail and "animaux" in lieu_travail and not lieu_travail.animaux.is_empty():
			var closest_animal = null
			var min_dist = INF
			for a in lieu_travail.animaux:
				if is_instance_valid(a):
					var dist = global_position.distance_to(a.global_position)
					if dist < min_dist:
						min_dist = dist
						closest_animal = a
			if closest_animal:
				current_baie = closest_animal
				go_to(closest_animal.global_position, "aller_manger_animal")
				lieu_travail.animaux.erase(closest_animal)
	var should_show = show_energy or mission in ["travailler", "cueillir", "mineur", "bucheron", "fermier"]
	energy_bar_container.visible = should_show
	if should_show:
		energy_bar_container.position = Vector2(0, -40)
		energy_bar.size.x = clamp(energy / 100.0 * 40.0, 0, 40)
		energy_bar.modulate = Color(1, 0, 0) if energy < 30 else Color(0, 1, 0)

func _on_click(_vp, event, _si):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tab = get_node("/root/game/CanvasLayer/TableauBord")
		if not tab:
			return
		if tab.pnj_panel.visible and tab.current_pnj == self:
			tab.pnj_panel.visible = false
			tab.current_pnj = null
		else:
			tab.update_pnj_panel(self)
			tab.current_pnj = self

func follow_path(_delta):
	if current_step >= chemin.size():
		following_route = false
		match mission:
			"aller_travailler":
				match metier:
					"cueilleur": mission = "cueillir"
					"bucheron": mission = "bucheron"
					"mineur": mission = "mineur"
					"fermier": mission = "recolter_ble"
					_: mission = "travailler"
			"aller_abattre": mission = "bucheron"
			"aller_cueillir": mission = "cueillir"
			"aller_mineur": mission = "mineur"
			"aller_recolter_ble": mission = "recolter_ble"
			"retour_maison": mission = "recharger"
			"aller_manger_animal": mission = "manger_animal"
			"aller_boire": mission = "boire"
			"retour_travail":
				match metier:
					"cueilleur": search_next_baie()
					"bucheron": search_next_tree()
					"mineur": search_next_rock()
					"fermier": search_next_ble()
			"aller_bord_eau": mission = "pomper"
			"retour_au_puit": mission = "deposer_eau"
		return
	var target_pos = chemin[current_step]
	var dist = global_position.distance_to(target_pos)
	if dist < 4:
		current_step += 1
		velocity = Vector2.ZERO
	else:
		var dir = (target_pos - global_position).normalized()
		velocity = dir * speed
		move_and_slide()
		
func do_work(_delta):
	match metier:
		"bucheron":
			search_next_tree()
		"cueilleur":
			search_next_baie()
		"mineur":
			search_next_rock()
		"fermier":
			search_next_ble()
		"pompier":
			if lieu_travail and lieu_travail.touche_eau:
				mission = "aller_bord_eau"
				go_to(lieu_travail.get_point_eau(), "aller_bord_eau")
		_:
			mission = ""

func do_recharge(delta):
	show_energy = true
	energy += delta * recharge_rate
	if energy >= 100:
		energy = 100
		show_energy = false
		await get_tree().create_timer(0.5).timeout
		if lieu_travail:
			mission = "retour_travail"
			go_to(lieu_travail.global_position, "retour_travail")


func prepare_return_path():
	if maison:
		var raw_start = route_tilemap.local_to_map(global_position)
		var raw_goal  = route_tilemap.local_to_map(maison.global_position)
		var start = game._find_nearest_walkable_cell(raw_start)
		var goal = game._find_nearest_walkable_cell(raw_goal)
		if not astar.region.has_point(start) or not astar.region.has_point(goal):
			following_route = false
			mission = ""
			return
		if astar.is_point_solid(start) or astar.is_point_solid(goal):
			following_route = false
			mission = ""
			return
		var path = astar.get_point_path(start, goal)
		chemin.clear()
		var half = astar.cell_size * 0.5
		for cell in path:
			chemin.append(route_tilemap.map_to_local(cell) + half)
		chemin.append(maison.global_position)
		current_step = 0
		following_route = true

func pick_new_direction():
	direction = Vector2(cos(randf() * TAU), sin(randf() * TAU)).normalized()
	
func move_randomly(delta):
	wander_timer += delta
	if wander_timer >= change_interval:
		wander_timer = 0
		pick_new_direction()
	var current_cell = route_tilemap.local_to_map(global_position)
	var is_on_route = route_tilemap.get_cell_source_id(current_cell) != -1
	var current_speed = speed * (2.0 if is_on_route else 1.0)
	var next_pos = global_position + direction * current_speed * delta
	var cell = herbe_tilemap.local_to_map(next_pos)
	if herbe_tilemap.get_cell_source_id(cell) == 0:
		global_position = next_pos
		sprite.flip_h = direction.x < 0
	else:
		pick_new_direction()
		
	
func do_chop_tree(delta):
	if energy <= travail_threshold:
		energy = 0
		mission = "retour_maison"
		prepare_return_path()
		return

	if current_tree and is_instance_valid(current_tree):
		var dist = global_position.distance_to(current_tree.global_position)
		if dist > 8:
			return
		velocity = Vector2.ZERO
		energy -= delta * travail_rate
		cutting_timer += delta
		if cutting_timer >= cutting_duration:
			var base_cell = herbe_tilemap.local_to_map(current_tree.global_position)
			var size = game.objet_sizes.get("sapin", Vector2i(1, 1))
			for x in range(size.x):
				for y in range(size.y):
					var cell = base_cell + Vector2i(x, y)
					game.occupied_cells.erase(cell) 
			current_tree.queue_free()
			if lieu_travail and lieu_travail.has_method("remove_tree_at"):
				lieu_travail.remove_tree_at(current_tree.global_position)
			cutting_timer = 0.0
			current_tree = null
			if lieu_travail and lieu_travail.has_method("add_wood"):
				lieu_travail.call("add_wood", 1)
			await get_tree().create_timer(0.5).timeout
			search_next_tree()
	else:
		current_tree = null
		search_next_tree()

func search_next_tree():
	if not lieu_travail or not lieu_travail.has_method("get_nearby_trees"):
		mission = "retour_maison"
		prepare_return_path()
		return
	var trees = lieu_travail.get_nearby_trees()
	if trees.size() == 0:
		mission = "retour_maison"
		prepare_return_path()
		return
	var closest: Node2D = trees[0]
	var dist = global_position.distance_to(closest.global_position)
	for t in trees:
		var d = global_position.distance_to(t.global_position)
		if d < dist:
			closest = t
			dist = d
	current_tree = closest
	go_to(current_tree.global_position, "aller_abattre")

func go_to(pos: Vector2, new_mission: String = ""):
	var raw_start = route_tilemap.local_to_map(global_position)
	var raw_goal  = route_tilemap.local_to_map(pos)
	var start = game._find_nearest_walkable_cell(raw_start)
	var goal  = game._find_nearest_walkable_cell(raw_goal)
	if not astar.region.has_point(start) or not astar.region.has_point(goal):
		following_route = false
		mission = ""
		return
	if astar.is_point_solid(start) or astar.is_point_solid(goal):
		following_route = false
		mission = ""
		return
	var path = astar.get_point_path(start, goal)
	chemin.clear()
	var half = astar.cell_size * 0.5
	if path.size() > 0:
		for cell in path:
			chemin.append(route_tilemap.map_to_local(cell) + half)
		chemin.append(pos)
		current_step = 0
		following_route = true
		if new_mission != "":
			mission = new_mission
	else:
		following_route = false
		mission = ""

func do_collect_baie(delta):
	if energy <= travail_threshold:
		energy = 0
		mission = "retour_maison"
		prepare_return_path()
		return
	if current_baie and is_instance_valid(current_baie):
		var dist = global_position.distance_to(current_baie.global_position)
		if dist > 8:
			return
		velocity = Vector2.ZERO
		energy -= delta * travail_rate
		cutting_timer += delta
		if cutting_timer >= cutting_duration:
			if lieu_travail and lieu_travail.has_method("respawn_baie"):
				lieu_travail.respawn_baie(current_baie.global_position)
			current_baie.queue_free()
			cutting_timer = 0.0
			if lieu_travail and lieu_travail.has_method("add_fruit"):
				lieu_travail.call("add_fruit", 1)
			await get_tree().create_timer(0.5).timeout
			search_next_baie()
	else:
		current_baie = null
		await get_tree().create_timer(0.5).timeout
		search_next_baie()

func _physics_process(delta):
	age += delta / 60.0
	calculer_facteur_sante()
	if age >= (esperance_vie * facteur_sante):
		mourir_naturellement()
		return
	if faim <= 0 and soif <= 0:
		mourir_de_privation()
		return
	faim_tick += delta
	soif_tick += delta
	if faim_tick >= randf_range(2.0, 5.0):
		faim = clamp(faim - 1, 0, 100)
		faim_tick = 0.0
	if soif_tick >= randf_range(1.5, 4.0):
		soif = clamp(soif - 1, 0, 100)
		soif_tick = 0.0
	if (faim <= 10 or soif <= 10) and mission not in ["aller_manger_animal", "manger_animal", "aller_boire", "boire"]:
		interrompre_pour_survie()
		return
	if following_route:
		follow_path(delta)
	elif faim < 20 and mission == "" and current_baie == null:
		animal_retry_timer += delta
		if animal_retry_timer >= 1.5:
			animal_retry_timer = 0.0
			search_nearest_animal()
	elif soif < 20 and mission == "" and current_baie == null:
		search_nearest_well()
	elif mission == "manger_animal":
		do_manger_animal(delta)
	elif mission == "boire":
		do_boire(delta)
	elif mission in ["travailler", "bucheron", "cueillir", "mineur", "recharger", "recolter_ble", "pomper", "deposer_eau"]:
		match mission:
			"travailler":     do_work(delta)
			"bucheron":       do_chop_tree(delta)
			"cueillir":       do_collect_baie(delta)
			"mineur":         do_mine(delta)
			"recharger":      do_recharge(delta)
			"recolter_ble":   do_collect_ble(delta)
			"pomper":         do_pomper(delta)
			"deposer_eau":    do_deposer_eau(delta)
	elif mission == "retour_travail":
		match metier:
			"cueilleur", "bucheron", "mineur", "fermier":
				go_to(lieu_travail.global_position, "aller_travailler")
			"pompier":
				if lieu_travail and lieu_travail.touche_eau:
					go_to(lieu_travail.get_point_eau(), "aller_bord_eau")
	elif mission == "":
		animal_retry_timer = 0.0
		match metier:
			"cueilleur": search_next_baie()
			"bucheron":  search_next_tree()
			"mineur":    search_next_rock()
			"fermier":   search_next_ble()
			"pompier":
				if lieu_travail and lieu_travail.touche_eau:
					mission = "aller_bord_eau"
					go_to(lieu_travail.get_point_eau(), "aller_bord_eau")
			_: move_randomly(delta)
	else:
		match metier:
			"bucheron":
				mission = "aller_travailler"
				search_next_tree()
			"cueilleur":
				mission = "aller_travailler"
				search_next_baie()
			"mineur":
				mission = "aller_travailler"
				search_next_rock()
			"fermier":
				mission = "aller_travailler"
				search_next_ble()
			"pompier":
				if lieu_travail and lieu_travail.touche_eau:
					mission = "aller_bord_eau"
					go_to(lieu_travail.get_point_eau(), "aller_bord_eau")
			_:
				move_randomly(delta)

func search_next_baie():
	if not lieu_travail or not lieu_travail.has_method("get_nearby_baies"):
		mission = ""
		return
	var toutes_les_baies = lieu_travail.get_nearby_baies()
	var baies = []
	for b in toutes_les_baies:
		if is_instance_valid(b) and b.visible:
			baies.append(b)
	if baies.size() == 0:
		current_baie = null
		await get_tree().create_timer(3.0).timeout
		search_next_baie()
		return
	var closest: Node2D = baies[0]
	var dist = global_position.distance_to(closest.global_position)
	for b in baies:
		var d = global_position.distance_to(b.global_position)
		if d < dist:
			closest = b
			dist = d
	current_baie = closest
	go_to(current_baie.global_position)
	mission = "aller_cueillir"
	
func search_next_rock():
	if not lieu_travail or not lieu_travail.has_method("get_nearby_rocks"):
		mission = "retour_maison"
		prepare_return_path()
		return
	var _all_rocks = get_tree().get_nodes_in_group("rock")
	var _radius := 10 * 64
	var rocks = lieu_travail.get_nearby_rocks()
	if rocks.is_empty():
		mission = "retour_maison"
		prepare_return_path()
		return
	var closest = rocks[0]
	var dist = global_position.distance_to(closest.global_position)
	for r in rocks:
		var d = global_position.distance_to(r.global_position)
		if d < dist:
			closest = r
			dist = d
	current_rock = closest	
	go_to(current_rock.global_position, "aller_mineur")

func do_mine(delta):
	if energy <= travail_threshold:
		energy = 0
		mission = "retour_maison"
		prepare_return_path()
		return
	if current_rock and is_instance_valid(current_rock):
		var dist = global_position.distance_to(current_rock.global_position)
		if dist > 8:
			return  
		velocity = Vector2.ZERO
		energy -= delta * travail_rate
		mining_timer += delta
		if mining_timer >= mining_duration:
			current_rock.respawn()
			mining_timer = 0.0
			if lieu_travail and lieu_travail.has_method("add_stone"):
				lieu_travail.call("add_stone", 1)
			await get_tree().create_timer(0.5).timeout
			search_next_rock()
	else:
		current_rock = null
		await get_tree().create_timer(0.5).timeout
		search_next_rock()

func search_next_ble():
	if not lieu_travail or not lieu_travail.has_method("get_nearby_ble"):
		mission = "retour_maison"
		prepare_return_path()
		return
	var tous_les_ble = lieu_travail.get_nearby_ble()
	var bles = []
	for b in tous_les_ble:
		if is_instance_valid(b) and b.visible:
			bles.append(b)
	if bles.is_empty():
		current_baie = null
		await get_tree().create_timer(3.0).timeout
		search_next_ble()
		return
	var closest: Node2D = bles[0]
	var dist = global_position.distance_to(closest.global_position)
	for b in bles:
		var d = global_position.distance_to(b.global_position)
		if d < dist:
			closest = b
			dist = d
	current_baie = closest
	go_to(current_baie.global_position)
	mission = "aller_recolter_ble"
	
func do_collect_ble(delta):
	if energy <= travail_threshold:
		energy = 0
		mission = "retour_maison"
		prepare_return_path()
		return
	if current_baie and is_instance_valid(current_baie):
		var dist = global_position.distance_to(current_baie.global_position)
		if dist > 8:
			return
		velocity = Vector2.ZERO
		energy -= delta * travail_rate
		cutting_timer += delta
		if cutting_timer >= cutting_duration:
			current_baie.respawn()
			cutting_timer = 0.0
			if lieu_travail and lieu_travail.has_method("add_wheat"):
				lieu_travail.call("add_wheat", 1)
			await get_tree().create_timer(0.5).timeout
			search_next_ble()
	else:
		current_baie = null
		await get_tree().create_timer(0.5).timeout
		search_next_ble()

func do_pomper(delta):
	if energy <= travail_threshold:
		energy = 0
		mission = "retour_maison"
		prepare_return_path()
		return
	velocity = Vector2.ZERO
	energy -= delta * travail_rate
	eau_timer += delta
	if eau_timer >= temps_pompage:
		eau_timer = 0.0
		if lieu_travail:
			mission = "retour_au_puit"
			go_to(lieu_travail.global_position, "retour_au_puit")
			
func do_deposer_eau(_delta):
	if global_position.distance_to(lieu_travail.global_position) > 8:
		return
	velocity = Vector2.ZERO
	if lieu_travail and lieu_travail.has_method("add_water"):
		lieu_travail.add_water(1)
		await get_tree().create_timer(0.5).timeout
		var next_pos = lieu_travail.get_point_eau()
		if next_pos == lieu_travail.global_position:
			mission = ""
			return
		go_to(next_pos, "aller_bord_eau")
		
func do_manger_animal(delta):
	if not is_instance_valid(current_baie):
		current_baie = null
		mission = ""
		return
	var dist = global_position.distance_to(current_baie.global_position)
	if dist > 8:
		return
	velocity = Vector2.ZERO
	cutting_timer += delta
	if cutting_timer >= cutting_duration:
		match current_baie.name.to_lower():
			"poule":  faim = clamp(faim + 100, 0, 100)
			"cochon": faim = clamp(faim + 100, 0, 100)
			"vache":  faim = clamp(faim + 100, 0, 100)
			_:        faim = clamp(faim + 50, 0, 100)
		current_baie.queue_free()
		for bat in get_tree().get_nodes_in_group("batiment"):
			if "animaux" in bat and current_baie in bat.animaux:
				bat.animaux.erase(current_baie)
				break
		current_baie = null
		cutting_timer = 0.0
		reprendre_mission_apres_survie()

func search_nearest_animal():
	var animaux = game.get_all_animaux_disponibles()
	if animaux.is_empty():
		return
	var closest_animal = null
	var min_dist = INF
	for a in animaux:
		if not is_instance_valid(a):
			continue
		var dist = global_position.distance_to(a.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_animal = a
	if closest_animal:
		current_baie = closest_animal
		go_to(closest_animal.global_position, "aller_manger_animal")
		
func search_nearest_well():
	var puits_dispo = []
	for bat in get_tree().get_nodes_in_group("batiment"):
		if bat.name.to_lower().begins_with("puit") and bat.has_method("boire") and bat.stock_eau > 0:
			puits_dispo.append(bat)
	if puits_dispo.is_empty():
		return
	var closest = null
	var min_dist = INF
	for puit in puits_dispo:
		var dist = global_position.distance_to(puit.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = puit
	if closest:
		lieu_boisson = closest
		go_to(closest.global_position, "aller_boire")

func do_boire(_delta):
	if not is_instance_valid(lieu_boisson) or global_position.distance_to(lieu_boisson.global_position) > 8:
		return
	velocity = Vector2.ZERO
	if lieu_boisson.boire():
		soif = 100
		reprendre_mission_apres_survie()
	else:
		mission = ""
	lieu_boisson = null
	
func calculer_facteur_sante():
	facteur_sante = 1.0
	if has_house:
		facteur_sante += 0.2
	if metier != "":
		facteur_sante += 0.1
	if faim > 70:
		facteur_sante += 0.15
	elif faim < 30:
		facteur_sante -= 0.1  
	if soif > 70:
		facteur_sante += 0.1
	elif soif < 30:
		facteur_sante -= 0.05
	if energy > 80:
		facteur_sante += 0.05
	facteur_sante = clamp(facteur_sante, 0.5, 2.0)

func mourir_naturellement():
	liberer_ressources()
	queue_free()

func mourir_de_privation():
	liberer_ressources()
	queue_free()

func liberer_ressources():
	if lieu_travail and lieu_travail.has_method("remove_employe"):
		lieu_travail.remove_employe(self)
	if maison and maison.has_method("remove_habitant"):
		maison.remove_habitant(self)
		

func interrompre_pour_survie():
	if mission != "":
		mission_apres_recharge = mission
	following_route = false
	chemin.clear()
	current_step = 0
	if soif <= 10:
		search_nearest_well()
	elif faim <= 10:
		search_nearest_animal()

func reprendre_mission_apres_survie():
	if mission_apres_recharge != "":
		mission = mission_apres_recharge
		mission_apres_recharge = ""
		match metier:
			"bucheron": search_next_tree()
			"cueilleur": search_next_baie()
			"mineur": search_next_rock()
			"fermier": search_next_ble()
			"pompier":
				if lieu_travail and lieu_travail.touche_eau:
					go_to(lieu_travail.get_point_eau(), "aller_bord_eau")
	else:
		mission = ""
		
func die():
	emit_signal("died", metier, lieu_travail, self)
	queue_free()
