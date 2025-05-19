extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var herbe_tilemap: TileMapLayer = get_node("/root/game/herbe")
@onready var route_tilemap: TileMapLayer = get_node("/root/game/Map/Route/route")
@onready var game := get_node("/root/game")

@onready var energy_bar := $Energybar/Fill
@onready var energy_bar_container := $Energybar
@onready var click_area := $ClickArea
var show_energy := false

var direction := Vector2.ZERO
var speed := 30.0
var wander_timer := 0.0
var change_interval := 2.0
var target_route_pos := Vector2.ZERO
var following_route := false

var maison: Node2D = null
var has_house := false
var is_returning_home := false
var is_going_to_work := false

var metier := ""
var lieu_travail: Node2D = null
var energy := 100

var chemin: Array[Vector2i] = []
var current_step := 0
var id: int = 0
var faim := 100.0
var soif := 100.0
var mission := ""


func _ready():
	sprite.play("walk")
	pick_new_direction()
	energy_bar_container.visible = false
	click_area.connect("input_event", Callable(self, "_on_click"))

func _process(delta):
	faim -= delta * 0.3
	soif -= delta * 0.5
	faim = clamp(faim, 0, 100)
	soif = clamp(soif, 0, 100)
	# Travailler tant qu'il a de l'énergie
	if is_going_to_work and lieu_travail:
		if energy <= 20:
			is_going_to_work = false
			is_returning_home = true
		else:
			if chemin.is_empty():
				aller_vers(lieu_travail.global_position)
			suivre_chemin(delta)
			energy -= 5 * delta
			return

	# Rentrer se reposer à la maison
	if has_house and is_returning_home:
		if chemin.is_empty():
			aller_vers(maison.global_position)
		suivre_chemin(delta)
		if position.distance_to(maison.global_position) < 5:
			energy += 10 * delta
			if energy >= 100:
				energy = 100
				is_returning_home = false
				is_going_to_work = true
		return

	# Comportement errant
	wander_timer += delta
	if not following_route:
		find_nearby_route()
	if following_route:
		move_towards_route(delta)
	else:
		if wander_timer >= change_interval:
			pick_new_direction()
			wander_timer = 0.0
		move_randomly(delta)

	# Barre d'énergie
	if energy_bar_container and energy_bar:
		if show_energy:
			energy_bar_container.visible = true
			energy_bar_container.position = Vector2(0, -40)
			energy_bar.size.x = clamp(energy / 100.0 * 40.0, 0, 40)
			energy_bar.modulate = Color(1, 0, 0) if energy < 30 else Color(0, 1, 0)
		else:
			energy_bar_container.visible = false

func _on_click(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		show_energy = !show_energy
		print("🖱️ PNJ ID:", id)

		var tableau := get_node_or_null("/root/game/CanvasLayer/TableauBord")
		if tableau and tableau.has_method("update_pnj_panel"):
			tableau.update_pnj_panel(self)


func move_randomly(delta):
	var next_pos = position + direction * speed * delta
	var cell = herbe_tilemap.local_to_map(next_pos)
	if herbe_tilemap.get_cell_source_id(cell) == 0:
		position = next_pos
		sprite.flip_h = direction.x < 0
	else:
		pick_new_direction()

func pick_new_direction():
	direction = Vector2(cos(randf() * TAU), sin(randf() * TAU)).normalized()

func find_nearby_route():
	var current_cell = route_tilemap.local_to_map(position)
	for x in range(-10, 11):
		for y in range(-10, 11):
			var check_cell = current_cell + Vector2i(x, y)
			if route_tilemap.get_cell_source_id(check_cell) != -1:
				target_route_pos = route_tilemap.map_to_local(check_cell)
				following_route = true
				return

func move_towards_route(delta):
	var to_route = (target_route_pos - position).normalized()
	var next_pos = position + to_route * speed * delta
	var cell = herbe_tilemap.local_to_map(next_pos)
	if herbe_tilemap.get_cell_source_id(cell) == 0 or route_tilemap.get_cell_source_id(route_tilemap.local_to_map(next_pos)) != -1:
		position = next_pos
		sprite.flip_h = to_route.x < 0
		if position.distance_to(target_route_pos) < 5:
			following_route = false
	else:
		following_route = false
		pick_new_direction()

func aller_vers(destination: Vector2):
	var start = route_tilemap.local_to_map(position)
	var end = route_tilemap.local_to_map(destination)
	if not game.route_astar.is_in_boundsv(start) or not game.route_astar.is_in_boundsv(end):
		return
	chemin = game.route_astar.get_point_path(start, end)
	current_step = 0

func suivre_chemin(delta):
	if chemin.size() == 0 or current_step >= chemin.size():
		return
	var target = route_tilemap.map_to_local(chemin[current_step])
	var dir = (target - position).normalized()
	position += dir * speed * delta
	sprite.flip_h = dir.x < 0
	if position.distance_to(target) < 5:
		current_step += 1


func assigner_mission(m: String):
	mission = m
	print("📝 PNJ ", id, " a reçu la mission :", m)
