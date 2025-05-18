extends Node2D

@export var manual_offset := Vector2(-8, -24)
@export var tilemap: TileMapLayer    # Glisse ton TileMapLayer ici dans l’inspecteur
@export var cell_size := 16          # Taille d’une case, en pixels
@export var preview_size := Vector2i(10, 10)  # Dimensions de la grille, en nombre de cases
@export var center_alpha := 0.6
@export var edge_alpha := 0.1


func _process(_delta):
	if tilemap == null:
		return

	var cell = tilemap.local_to_map(get_global_mouse_position())
	var local_pos = tilemap.map_to_local(cell)
	# on ajoute manual_offset ici
	position = tilemap.global_position + local_pos + manual_offset

	update_grid(Vector2.ZERO, preview_size)


func update_grid(center_pos: Vector2, size: Vector2i):
	# Supprime l’ancienne grille
	for child in get_children():
		child.queue_free()

	# Calcul du coin sup-gauche centré
	var half = size * cell_size * 0.5
	var start = center_pos - half

	var max_dx = size.x * 0.5
	var max_dy = size.y * 0.5

	# === verticales intérieures seulement (skip x=0 et x=size.x) ===
	for x in range(1, size.x):
		var norm = abs(x - max_dx) / max_dx
		var alpha = lerp(center_alpha, edge_alpha, norm)
		var line = Line2D.new()
		line.width = 1
		line.default_color = Color(0, 0, 0, alpha)
		line.add_point(start + Vector2(x * cell_size, 0))
		line.add_point(start + Vector2(x * cell_size, size.y * cell_size))
		add_child(line)

	# === horizontales intérieures seulement (skip y=0 et y=size.y) ===
	for y in range(1, size.y):
		var norm = abs(y - max_dy) / max_dy
		var alpha = lerp(center_alpha, edge_alpha, norm)
		var line = Line2D.new()
		line.width = 1
		line.default_color = Color(0, 0, 0, alpha)
		line.add_point(start + Vector2(0, y * cell_size))
		line.add_point(start + Vector2(size.x * cell_size, y * cell_size))
		add_child(line)
