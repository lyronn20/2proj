extends Panel

@onready var label_coord = $HUD/GestionJeu/coordonées/mouse_coordonnées
@onready var btn_pause = $HUD/GestionJeu/button/btn_pause
@onready var btn_play = $HUD/GestionJeu/button/btn_play
@onready var btn_fast = $HUD/GestionJeu/button/btn_fast

func _ready():
	# Connexion des boutons
	btn_pause.pressed.connect(_on_pause)
	btn_play.pressed.connect(_on_play)
	btn_fast.pressed.connect(_on_fast)
	


func _on_pause():
	Engine.time_scale = 0

func _on_play():
	Engine.time_scale = 1

func _on_fast():
	Engine.time_scale = 2

func set_mouse_coords(cell: Vector2i):
	label_coord.text = "Mouse: %s" % str(cell)
