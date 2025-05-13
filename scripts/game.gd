extends Node2D

@onready var grille_logique = $GrilleLogique
@onready var map = $Map
@onready var menu = $CanvasLayer/Menu
@onready var stats = $CanvasLayer/Menu/HUD/Infos_Stats

var last_cell = null

func _ready():
	map.set_process_unhandled_input(true)

func _process(_delta):
	var cell = grille_logique.local_to_map(get_global_mouse_position())
	if cell != last_cell:
		last_cell = cell
		menu.set_mouse_coords(cell)

		# ⬇️ Simulation de mise à jour des stats
		stats.update_stats(42, Vector2i(45, 50), Vector2i(38, 40), 22)
