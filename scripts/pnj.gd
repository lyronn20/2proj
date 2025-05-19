# pnj.gd
extends CharacterBody2D

# === Nodes & references ===
@onready var sprite: AnimatedSprite2D    = $AnimatedSprite2D
@onready var herbe_tilemap: TileMapLayer = get_node("/root/game/herbe")
@onready var route_tilemap: TileMapLayer = get_node("/root/game/Map/Route/route")
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
		search_next_baie()


func _process(delta):
	# 1) Statistiques
	faim -= delta * 0.3
	soif -= delta * 0.5
	faim = clamp(faim, 0, 100)
	soif = clamp(soif, 0, 100)

	# 2) Devrait-on afficher la barre ?
	#    - Si on a cliqué (show_energy)
	#    - OU si on est en train de TRAVAILLER
	var should_show = show_energy or mission in ["travailler", "cueillir", "bucheron"]
	energy_bar_container.visible = should_show
	if should_show:
		energy_bar_container.position = Vector2(0, -40)
		# 3) Mise à jour de la taille & couleur
		energy_bar.size.x = clamp(energy / 100.0 * 40.0, 0, 40)
		energy_bar.modulate = Color(1, 0, 0) if energy < 30 else Color(0, 1, 0)
		



func _on_click(_vp, event, _si):
	if event is InputEventMouseButton and event.pressed:
		show_energy = !show_energy
		print("🖱️ PNJ ID:", id)
		var tab = get_node_or_null("/root/game/CanvasLayer/TableauBord")
		if tab and tab.has_method("update_pnj_panel"):
			tab.update_pnj_panel(self)

# ————————————————————————————————————————————————————————————————
func follow_path(delta):
	if current_step >= chemin.size():
		following_route = false

		# 🔁 Gestion spéciale après recharge
		if mission == "retour_travail":
			if metier == "cueilleur":
				mission = "travailler"
				search_next_baie()
			elif metier == "bucheron":
				mission = "travailler"
				search_next_tree()
			elif metier == "mineur":
				mission = "travailler"
			return

		# 🎯 Gestion classique
		match mission:
			"aller_travailler":
				mission = "travailler"
			"aller_abattre":
				mission = "bucheron"
			"aller_cueillir":
				mission = "cueillir"
			"retour_maison":
				mission = "recharger"
		return

	var target_pos = chemin[current_step]
	var dir = (target_pos - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	if global_position.distance_to(target_pos) < 2:
		current_step += 1



func do_work(delta):
	if metier == "bucheron":
		search_next_tree()
	elif metier == "cueilleur":
		search_next_baie()
	elif metier == "mineur":
		# Simule le travail du mineur
		show_energy = true
		energy -= delta * travail_rate
		if energy <= travail_threshold:
			energy = 0
			mission = "retour_maison"
			prepare_return_path()
	else:
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
			return  # Trop loin, on attend de s’approcher

		velocity = Vector2.ZERO
		energy -= delta * travail_rate
		cutting_timer += delta

		if cutting_timer >= cutting_duration:
			current_tree.queue_free()
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
	var start = route_tilemap.local_to_map(global_position)
	var goal = route_tilemap.local_to_map(pos)

	var path = []
	if astar.region.has_point(start) and astar.region.has_point(goal):
		if not astar.is_point_solid(start) and not astar.is_point_solid(goal):
			path = astar.get_point_path(start, goal)

	chemin.clear()
	var half = astar.cell_size * 0.5
	if path.size() > 0:
		for cell in path:
			chemin.append(route_tilemap.map_to_local(cell) + half)
	else:
		chemin.append(pos)

	current_step = 0
	following_route = true

	# 👇 Corrigé : si une mission est donnée, on l'utilise
	if new_mission != "":
		mission = new_mission

	
func do_collect_baie(delta):
	if energy <= travail_threshold:
		energy = 0
		mission = "retour_maison"
		prepare_return_path()
		return

	if current_baie and is_instance_valid(current_baie):
		velocity = Vector2.ZERO
		energy -= delta * travail_rate
		if energy <= travail_threshold:
			energy = 0
			mission = "retour_maison"
			prepare_return_path()
			return

		cutting_timer += delta
		if cutting_timer >= cutting_duration:
			# 🌱 Lance le respawn
			if lieu_travail and lieu_travail.has_method("respawn_baie"):
				lieu_travail.respawn_baie(current_baie.global_position)

			current_baie.queue_free()
			cutting_timer = 0.0
			current_baie = null

			if lieu_travail.has_method("add_fruit"):
				lieu_travail.call("add_fruit", 1)

			await get_tree().create_timer(0.5).timeout
			search_next_baie()
	else:
		current_baie = null
		await get_tree().create_timer(0.5).timeout
		search_next_baie()


func _physics_process(delta):
	if following_route:
		follow_path(delta)
	elif mission in ["travailler", "bucheron", "cueillir", "recharger"]:
		match mission:
			"travailler": do_work(delta)
			"bucheron": do_chop_tree(delta)
			"cueillir": do_collect_baie(delta)
			"recharger": do_recharge(delta)
	elif mission == "retour_travail":
		if metier == "cueilleur":
			go_to(lieu_travail.global_position, "aller_travailler")
		elif metier == "bucheron":
			go_to(lieu_travail.global_position, "aller_travailler")
		elif metier == "mineur":
			mission = "travailler"
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
