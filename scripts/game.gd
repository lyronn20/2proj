extends Node2D

@onready var grille_logique = $GrilleLogique
@onready var map = $Map
@onready var menu = $CanvasLayer/Menu  # On accède au Menu, qui s'occupe du label

var last_cell = null

func _ready():
	map.set_process_unhandled_input(true)
	

func _process(_delta):
	var cell = grille_logique.local_to_map(get_global_mouse_position())
	if cell != last_cell:
		last_cell = cell
		menu.set_mouse_coords(cell)
