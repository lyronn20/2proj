extends Node2D

@export var tilemap: TileMapLayer    # Glisse ton TileMapLayer ici dans l’inspecteur
@export var cell_size := 16          # Taille d’une case, en pixels
@export var preview_size := Vector2i(4, 4)  # Dimensions de la grille, en nombre de cases

func _process(_delta):
	if tilemap == null:
		return

	# 1) Récupère la cellule sous la souris (coordonnées en tuiles)
	var cell = tilemap.local_to_map(get_global_mouse_position())
	# 2) Transforme en position locale (pixels) à l’intérieur du TileMap
	var local_pos = tilemap.map_to_local(cell)
	# 3) Convertis en position monde, en tenant compte de la position du TileMapLayer dans la scène
	position = tilemap.global_position + local_pos

	# 4) Redessine la grille, centrée sur (0,0) local de ce Node2D
	update_grid(Vector2.ZERO, preview_size)


func update_grid(center_pos: Vector2, size: Vector2i):
	# Supprime l’ancienne grille
	for child in get_children():
		child.queue_free()

	# Calcule le coin supérieur-gauche de la grille, centré
	var offset = Vector2(size.x, size.y) * cell_size * 0.5
	var start = center_pos - offset

	# Trace les lignes verticales
	for x in range(size.x + 1):
		var line = Line2D.new()
		line.width = 1
		line.default_color = Color(1, 1, 1, 0.5)
		line.add_point(start + Vector2(x * cell_size, 0))
		line.add_point(start + Vector2(x * cell_size, size.y * cell_size))
		add_child(line)

	# Trace les lignes horizontales
	for y in range(size.y + 1):
		var line = Line2D.new()
		line.width = 1
		line.default_color = Color(1, 1, 1, 0.5)
		line.add_point(start + Vector2(0, y * cell_size))
		line.add_point(start + Vector2(size.x * cell_size, y * cell_size))
		add_child(line)
