extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var herbe_tilemap: TileMapLayer = get_node("/root/game/herbe")
@onready var route_tilemap: TileMapLayer = get_node("/root/game/Map/Route/route")
@onready var game := get_node("/root/game")  # Pour accéder à AStar

@onready var energy_bar_container := $EnergyBarContainer
@onready var energy_bar := $EnergyBarContainer/Fill
var show_energy := false

var direction := Vector2.ZERO
var speed := 30.0
var wander_timer := 0.0
var change_interval := 2.0
var target_route_pos: Vector2 = Vector2.ZERO
var following_route := false

var maison: Node2D = null
var has_house := false
var is_returning_home := false
var is_going_to_work := false

var metier: String = ""  # "bucheron", "mineur", etc.
var lieu_travail: Node2D = null
var energy := 100

var chemin: Array[Vector2i] = []
var current_step := 0

func _ready():
	sprite.play("walk")
	pick_new_direction()
	call_deferred("_connect_click_area")

func _connect_click_area():
	if has_node("ClickArea"):
		$ClickArea.connect("input_event", Callable(self, "_input_event"))

func _process(delta):
	# Aller travailler le jour si métier et énergie
	if is_going_to_work and lieu_travail and energy > 0:
		if chemin.size() == 0:
			aller_vers(lieu_travail.global_position)
		suivre_chemin(delta)
		energy -= 5 * delta
		return

	# Retour à la maison la nuit
	if has_house and is_returning_home:
		if chemin.size() == 0:
			aller_vers(maison.global_position)
		suivre_chemin(delta)
		return

	# Recharge énergie si la nuit
	if not is_going_to_work and energy < 100:
		energy += 5 * delta

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

	# Mise à jour de la barre d'énergie
	if energy_bar_container and energy_bar:
		if show_energy:
			print("🔋 Affichage actif pour : ", name)
			energy_bar_container.visible = true
			energy_bar_container.position = Vector2(0, -40)
			energy_bar.size.x = clamp(energy / 100.0 * 40.0, 0, 40)
			energy_bar.modulate = Color(1, 0, 0) if energy < 30 else Color(0, 1, 0)
		else:
			energy_bar_container.visible = false

func move_randomly(delta):
	var next_pos = position + direction * speed * delta
	var cell = herbe_tilemap.local_to_map(next_pos)
	if herbe_tilemap.get_cell_source_id(cell) == 0:
		position = next_pos
		sprite.flip_h = direction.x < 0
	else:
		pick_new_direction()

func pick_new_direction():
	var angle = randf_range(0, TAU)
	direction = Vector2(cos(angle), sin(angle)).normalized()

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
		if position.distance_to(target_route_pos) < 5.0:
			following_route = false
	else:
		following_route = false
		pick_new_direction()

func aller_vers(destination: Vector2):
	var start = route_tilemap.local_to_map(position)
	var end = route_tilemap.local_to_map(destination)
	var astar = game.route_astar
	if not astar.is_in_boundsv(start) or not astar.is_in_boundsv(end):
		return
	chemin = astar.get_point_path(start, end)
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

func set_time_of_day(time: String):
	if time == "night":
		is_returning_home = true
		is_going_to_work = false
	elif time == "day":
		is_returning_home = false
		if metier != "":
			is_going_to_work = true

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		show_energy = not show_energy
		print("✅ Clic détecté sur ", name)
