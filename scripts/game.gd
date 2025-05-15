extends Node2D

@onready var route_tilemap: TileMapLayer = $Map/Route/route
@onready var menu = $CanvasLayer/Menu
@onready var stats = $CanvasLayer/Menu/HUD/Infos_Stats

var last_cell = null
const TERRAIN_ID = 0

var current_preview: Sprite2D = null
var current_scene: PackedScene = null
var selected_mode: String = ""

func _ready():
	menu.connect("objet_selectionne", Callable(self, "_on_objet_selectionne"))
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(_delta):
	var cell = route_tilemap.local_to_map(get_global_mouse_position())

	if cell != last_cell:
		last_cell = cell
		menu.set_mouse_coords(cell)
		stats.update_stats(0, Vector2i(45, 50), Vector2i(38, 40), 22)

	if current_preview:
		var grid_pos = route_tilemap.local_to_map(get_global_mouse_position())
		current_preview.global_position = route_tilemap.map_to_local(grid_pos)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos = get_global_mouse_position()
		var cell = route_tilemap.local_to_map(pos)

		if selected_mode == "gomme":
			for obj in get_tree().get_nodes_in_group("placeable"):
				if obj is Node2D and obj.global_position.distance_to(pos) < 16:
					obj.queue_free()
					break

		elif current_scene:
			var instance = current_scene.instantiate()
			instance.global_position = current_preview.global_position  # ✅ synchronisé
			instance.add_to_group("placeable")
			add_child(instance)


			current_preview.queue_free()
			current_preview = null
			current_scene = null

	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		placer_route()

func placer_route():
	var cell = route_tilemap.local_to_map(get_global_mouse_position())
	route_tilemap.set_cells_terrain_connect([cell], 0, TERRAIN_ID, 0)

func _on_objet_selectionne(nom: String):
	selected_mode = nom

	if current_preview:
		current_preview.queue_free()
		current_preview = null
		current_scene = null

	if nom == "gomme":
		return

	var texture: Texture2D = null

	match nom:
		"feu_camp":
			current_scene = preload("res://scenes/feu_camp.tscn")
			texture = load("res://assets/batiments/feu_camp.png")
		"hutte":
			current_scene = preload("res://scenes/hutte.tscn")
			texture = load("res://assets/batiments/hutte.png")
		_:
			return

	current_preview = Sprite2D.new()
	current_preview.texture = texture
	current_preview.modulate.a = 0.5
	add_child(current_preview)
