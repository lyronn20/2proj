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
var travail_threshold := 0.0
var recharge_rate := 20.0

func _ready():
	# lancement de la marche aléatoire
	sprite.play("walk")
	pick_new_direction()
	energy_bar_container.visible = false
	click_area.connect("input_event", Callable(self, "_on_click"))

func _process(delta):
	# 1) Statistiques
	faim -= delta * 0.3
	soif -= delta * 0.5
	faim = clamp(faim, 0, 100)
	soif = clamp(soif, 0, 100)

	# 2) Devrait-on afficher la barre ?
	#    - Si on a cliqué (show_energy)
	#    - OU si on est en train de TRAVAILLER
	var should_show = show_energy or mission == "travailler"
	energy_bar_container.visible = should_show
	if should_show:
		energy_bar_container.position = Vector2(0, -40)
		# 3) Mise à jour de la taille & couleur
		energy_bar.size.x = clamp(energy / 100.0 * 40.0, 0, 40)
		energy_bar.modulate = Color(1, 0, 0) if energy < 30 else Color(0, 1, 0)
		
func _physics_process(delta):
	if following_route:
		follow_path(delta)
	elif mission == "travailler":
		do_work(delta)
	elif mission == "recharger":
		do_recharge(delta)
	else:
		move_randomly(delta)


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
		if mission == "aller_travailler":
			mission = "travailler"
		elif mission == "retour_maison":
			# On est arrivé à la hutte : on passe à l'état recharge
			mission = "recharger"
		print("✅ PNJ", id, "arrivé en", mission)
		return
	var target_pos = chemin[current_step]
	print("→ PNJ", id, "étape", current_step, "vers", target_pos)
	var dir = (target_pos - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	if global_position.distance_to(target_pos) < 2:
		current_step += 1

func do_work(delta):
	show_energy = true
	energy -= delta * travail_rate
	if energy <= travail_threshold:
		energy = 0
		mission = "retour_maison"
		prepare_return_path()


func do_recharge(delta):
	# On affiche la barre tant qu'on recharge
	show_energy = true
	energy += delta * recharge_rate
	if energy >= 100:
		energy = 100
		# Recharge terminée : on repart en errance
		mission = ""
		show_energy = false

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
