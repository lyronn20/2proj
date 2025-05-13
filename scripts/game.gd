extends Node2D

@onready var grille_logique = $GrilleLogique
@onready var map = $Map
@onready var menu = $CanvasLayer/Menu
@onready var stats = $CanvasLayer/Menu/HUD/Infos_Stats

var last_cell = null

var current_preview: Sprite2D = null
var current_scene: PackedScene = null
var taille_objet := Vector2i(4, 4)

func _ready():
	map.set_process_unhandled_input(true)

	# Connexion depuis l'inventaire
	menu.get_node("HUD/ZoneInventaire").connect("objet_selectionne", Callable(self, "_on_objet_selectionne"))

func _process(_delta):
	var cell = grille_logique.local_to_map(get_global_mouse_position())

	if cell != last_cell:
		last_cell = cell
		menu.set_mouse_coords(cell)
		stats.update_stats(42, Vector2i(45, 50), Vector2i(38, 40), 22)

	# Mise à jour de la position de l’objet prévisualisé
	if current_preview:
		var cell_pos = grille_logique.local_to_map(get_global_mouse_position())
		cell_pos.x = int(cell_pos.x / 1) * 1
		cell_pos.y = int(cell_pos.y / 1) * 1
		current_preview.global_position = cell_pos * 32

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_preview and current_scene:
			var instance = current_scene.instantiate()
			instance.global_position = current_preview.global_position
			add_child(instance)

			current_preview.queue_free()
			current_preview = null
			current_scene = null

func _on_objet_selectionne(nom: String):
	if current_preview:
		current_preview.queue_free()

	var texture: Texture2D = null  # ✅ Défini avant le match

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
	
	current_preview.modulate.a = 0.5  # Transparent
	add_child(current_preview)
