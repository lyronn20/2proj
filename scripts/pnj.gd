# pnj.gd
extends CharacterBody2D
@export var recharge_hold_time := 15.0  # en secondes
# === Nodes & references ===
@onready var sprite: AnimatedSprite2D    = $AnimatedSprite2D
@onready var herbe_tilemap: TileMapLayer = get_node("/root/game/herbe")
@onready var route_tilemap: TileMapLayer = get_node("/root/game/Route/route")
@onready var game := get_node("/root/game")
@onready var astar: AStarGrid2D           = game.route_astar

@onready var energy_bar           = $Energybar/Fill
@onready var energy_bar_container = $Energybar
@onready var click_area           = $ClickArea

# === Identification & state ===
var id: int = 0
var show_energy := false

# === Housing ===
var has_house := false
var maison: Node2D       = null

# === Job & mission ===
var metier       := ""
var lieu_travail: Node2D = null
var mission      := ""
var mission_apres_recharge := ""

# === Stats ===
var energy := 100.0
var faim   := 100.0
var soif   := 100.0

# === Random movement ===
var direction      := Vector2.ZERO
var speed          := 30.0
var wander_timer   := 0.0
var change_interval := 2.0

# === Pathfinding ===
var chemin         = []             # PackedVector2Array fonctionne aussi
var current_step   := 0
var following_route := false

# === Work parameters ===
var travail_rate      := 20.0       # énergie perdue par seconde en travaillant
var travail_threshold := 5.0
var recharge_rate := 20.0

var current_tree: Node2D = null
var cutting_timer := 0.0
var cutting_duration := 1  # secondes

var current_baie: Node2D = null

var current_rock: Node2D = null
var mining_timer := 0.0
var mining_duration := 1.0   # en secondes


func _ready():
	# lancement de la marche aléatoire
	sprite.play("walk")
	pick_new_direction()
	energy_bar_container.visible = false
	click_area.connect("input_event", Callable(self, "_on_click"))

	# ───────────────────────────────
	#  DÉSACTIVATION DES COLLISIONS ENTRE PNJ
	# ───────────────────────────────
	# On garde le PNJ sur la couche 1,
	# mais on enlève toutes les couches dans son mask :
	# il ne détectera donc plus aucun autre corps (ni PNJ, ni décor, ni bâtiment).
	collision_layer = 1
	collision_mask  = 0


	if metier == "bucheron":
		mission = "aller_travailler"
		search_next_tree()
	elif metier == "cueilleur":
		mission = "aller_travailler"
		search_next_baie()       # ← on lance bien la recherche
	elif metier == "mineur":
		mission = "aller_travailler"
		search_next_rock()	
	elif metier == "fermier":
		mission = "aller_travailler"
		search_next_ble()



func _process(delta):
	# 1) Statistiques
	faim -= delta * 0.3
	soif -= delta * 0.5
	faim = clamp(faim, 0, 100)
	soif = clamp(soif, 0, 100)

	# 1.5) Aller manger si faim trop basse
	if faim < 20 and mission == "" and lieu_travail and lieu_travail.has_method("get_animaux_disponibles"):
		var cible = lieu_travail.get_animal_disponible()
		if cible:
			current_baie = cible
			go_to(cible.global_position, "aller_manger_animal")

	# 2) Devrait-on afficher la barre ?
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

		print("🖱️ PNJ ID:", id)

		
	# ————————————————————————————————————————————————————————————————
func follow_path(delta):
	if current_step >= chemin.size():
		following_route = false

		if mission == "retour_travail":
			if metier == "cueilleur": search_next_baie()
			elif metier == "bucheron": search_next_tree()
			elif metier == "mineur": search_next_rock()
			elif metier == "fermier": search_next_ble()
			return

		match mission:
			"aller_travailler":
				match metier:
					"cueilleur":
						mission = "cueillir"
					"bucheron":
						mission = "bucheron"
					"mineur":
						mission = "mineur"
					"fermier":
						mission = "recolter_ble"
					_:
						mission = "travailler"
			"aller_abattre":
				mission = "bucheron"
			"aller_cueillir":
				mission = "cueillir"
			"aller_mineur":
				mission = "mineur"
			"aller_recolter_ble":
				mission = "recolter_ble"
			"retour_maison":
				mission = "recharger"
			"aller_manger_animal":
				mission = "manger_animal"

		return

	var target_pos = chemin[current_step]
	var dir = (target_pos - global_position).normalized()
	velocity = dir * speed
	move_and_slide()

	if global_position.distance_to(target_pos) < 2:
		current_step += 1


func do_work(delta):
	match metier:
		"bucheron":
			search_next_tree()
		"cueilleur":
			search_next_baie()
		"mineur":
			search_next_rock()
		"fermier":
			search_next_ble()
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
		# a) Chemin A* vers la route la plus proche de la maison
		var start = route_tilemap.local_to_map(global_position)
		var goal  = route_tilemap.local_to_map(maison.global_position)
		var cell_path = astar.get_point_path(start, goal)

		# b) Conversion en positions monde
		chemin.clear()
		var half = astar.cell_size * 0.5
		for cell in cell_path:
			chemin.append(route_tilemap.map_to_local(cell) + half)

		# c) On ajoute en fin la position exacte de la maison
		chemin.append(maison.global_position)

		# d) Lancement du suivi
		current_step    = 0
		following_route = true
		request_redraw()
# 4) Errance aléatoire quand pas de mission
func move_randomly(delta):
	wander_timer += delta
	if wander_timer >= change_interval:
		wander_timer = 0
		pick_new_direction()
	var next_pos = global_position + direction * speed * delta
	var cell     = herbe_tilemap.local_to_map(next_pos)
	if herbe_tilemap.get_cell_source_id(cell) == 0:
		global_position = next_pos
		sprite.flip_h   = direction.x < 0
	else:
		pick_new_direction()

func pick_new_direction():
	direction = Vector2(cos(randf() * TAU), sin(randf() * TAU)).normalized()

# ————————————————————————————————————————————————————————————————
# Dessiner la trajectoire A* en mode debug
func _draw():
	for i in range(chemin.size() - 1):
		draw_line(chemin[i], chemin[i + 1], Color(1, 0, 0), 2)

# Méthode publique pour redessiner en one-shot sans erreur de compilation
func request_redraw():
	call_deferred("update")
	

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
			# 🪓 Supprimer l'arbre
			var base_cell = herbe_tilemap.local_to_map(current_tree.global_position)

			# Taille correcte de l'arbre (tu peux l'adapter ici si besoin)
			var size = game.objet_sizes.get("sapin", Vector2i(1, 1))

			for x in range(size.x):
				for y in range(size.y):
					var cell = base_cell + Vector2i(x, y)
					game.occupied_cells.erase(cell)  # ✅ On libère TOUTES les cases

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
	# a) start/goal en coordonnées de tile
	var raw_start = route_tilemap.local_to_map(global_position)
	var raw_goal  = route_tilemap.local_to_map(pos)

	# b) on projette le goal sur le réseau A*
	var goal = raw_goal
	if not astar.region.has_point(raw_goal) or astar.is_point_solid(raw_goal):
		goal = game._find_nearest_route_cell(raw_goal)

	# c) calcul du chemin A*
	var path = []
	if astar.region.has_point(raw_start) and astar.region.has_point(goal):
		if not astar.is_point_solid(raw_start) and not astar.is_point_solid(goal):
			path = astar.get_point_path(raw_start, goal)

	# d) reconstruction world‐space
	chemin.clear()
	var half = astar.cell_size * 0.5
	if path.size() > 0:
		for cell in path:
			chemin.append(route_tilemap.map_to_local(cell) + half)
		# dernière étape : centre du pos, pour entrer dans le bâtiment
		chemin.append(pos)
	else:
		# si A* n'a rien trouvé (cas vraiment rare), on finit quand même
		chemin.append(pos)
	current_step    = 0
	following_route = true

	# e) applique la mission si fournie
	if new_mission != "":
		mission = new_mission

	
func do_collect_baie(delta):
	# 1) Si l'énergie est trop faible, on rentre se ressourcer
	if energy <= travail_threshold:
		energy = 0
		mission = "retour_maison"
		prepare_return_path()
		return

	# 2) Si on a une baie valide
	if current_baie and is_instance_valid(current_baie):
		var dist = global_position.distance_to(current_baie.global_position)
		if dist > 8:
			return  # Trop loin, on attend d’être proche

		# On s’arrête pour cueillir
		velocity = Vector2.ZERO
		energy -= delta * travail_rate
		cutting_timer += delta

		if cutting_timer >= cutting_duration:
	# On supprime la baie et on demande au bâtiment de la respawn
			if lieu_travail and lieu_travail.has_method("respawn_baie"):
				lieu_travail.respawn_baie(current_baie.global_position)
			current_baie.queue_free()
			cutting_timer = 0.0

			# On stocke les fruits dans la scierie (ou ferme)
			if lieu_travail and lieu_travail.has_method("add_fruit"):
				lieu_travail.call("add_fruit", 1)

			# Petite pause avant de chercher la suivante
			await get_tree().create_timer(0.5).timeout
			search_next_baie()

	else:
		# Pas de cible ou baie détruite : on réessaie après un court délai
		current_baie = null
		await get_tree().create_timer(0.5).timeout
		search_next_baie()


func _physics_process(delta):
	if following_route:
		follow_path(delta)

	elif mission in ["travailler", "bucheron", "cueillir", "mineur", "recharger", "recolter_ble"]:
		match mission:
			"travailler": do_work(delta)
			"bucheron": do_chop_tree(delta)
			"cueillir": do_collect_baie(delta)
			"mineur": do_mine(delta)
			"recharger": do_recharge(delta)
			"recolter_ble": do_collect_ble(delta)

	elif mission == "retour_travail":
		if metier in ["cueilleur", "bucheron", "mineur"]:
			go_to(lieu_travail.global_position, "aller_travailler")

	elif mission == "manger_animal":
		do_manger_animal(delta)

	else:
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

	# Affiche tous les noeuds groupés "rock"
	var all_rocks = get_tree().get_nodes_in_group("rock")

	# Affiche la position de la carrière et le rayon
	var radius := 10 * 64

	# Récupère la liste filtrée
	var rocks = lieu_travail.get_nearby_rocks()

	if rocks.is_empty():
		mission = "retour_maison"
		prepare_return_path()
		return

	# Choix de la plus proche
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
	# Si l'énergie est trop faible, on rentre
	if energy <= travail_threshold:
		energy = 0
		mission = "retour_maison"
		prepare_return_path()
		return

	if current_rock and is_instance_valid(current_rock):
		var dist = global_position.distance_to(current_rock.global_position)
		if dist > 8:
			return  # Trop loin, on attend de s’approcher

		# On s’arrête pour miner
		velocity = Vector2.ZERO
		energy -= delta * travail_rate
		mining_timer += delta

		if mining_timer >= mining_duration:
			# On « mine » la pierre : on la cache et lance son respawn interne
			current_rock.respawn()
			mining_timer = 0.0
			# Stockage dans la carrière
			if lieu_travail and lieu_travail.has_method("add_stone"):
				lieu_travail.call("add_stone", 1)
			# Petite pause avant de chercher la suivante
			await get_tree().create_timer(0.5).timeout
			search_next_rock()
	else:
		# Si plus de roche ciblée ou détruite, on réessaie après un court délai
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

func do_manger_animal(delta):
	if not current_baie or not is_instance_valid(current_baie):
		current_baie = null
		mission = ""
		return

	var dist = global_position.distance_to(current_baie.global_position)
	if dist > 8:
		return

	velocity = Vector2.ZERO
	energy -= delta * travail_rate
	cutting_timer += delta

	if cutting_timer >= cutting_duration:
		match current_baie.name.to_lower():
			"poule": faim = clamp(faim + 15, 0, 100)
			"cochon": faim = clamp(faim + 35, 0, 100)
			"vache": faim = clamp(faim + 60, 0, 100)

		current_baie.queue_free()
		if lieu_travail.animaux.has(current_baie):
			lieu_travail.animaux.erase(current_baie)
		current_baie = null
		cutting_timer = 0.0
		mission = ""
		print("🍗 PNJ", id, " a mangé un animal.")
