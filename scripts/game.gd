extends Node2D

@onready var route_tilemap: TileMapLayer = $Map/Route/route
@onready var menu = $CanvasLayer/Menu
@onready var stats = $CanvasLayer/Menu/HUD/Infos_Stats

var last_cell = null
const TERRAIN_ID = 0  # ID du terrain dans le TerrainSet (ici "route")

func _ready():
	menu.connect("objet_selectionne", Callable(self, "_on_objet_selectionne"))
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(_delta):
	var cell = route_tilemap.local_to_map(get_global_mouse_position())

	if cell != last_cell:
		last_cell = cell
		menu.set_mouse_coords(cell)
		stats.update_stats(0, Vector2i(45, 50), Vector2i(38, 40), 22)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		placer_route()

func placer_route():
	var mouse_pos = get_global_mouse_position()
	var cell = route_tilemap.local_to_map(mouse_pos)
	route_tilemap.set_cells_terrain_connect([cell], 0, TERRAIN_ID, 0)

func _on_objet_selectionne(nom: String):
	# Tu peux laisser vide ou gérer autre chose ici plus tard
	pass
