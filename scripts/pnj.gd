extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var herbe_tilemap: TileMapLayer = get_node("/root/game/herbe")  # Chemin vers la tilemap herbe

var direction := Vector2.ZERO
var speed := 30.0
var wander_timer := 0.0
var change_interval := 2.0

func _ready():
	sprite.play("walk")
	pick_new_direction()

func _process(delta):
	wander_timer += delta
	if wander_timer >= change_interval:
		pick_new_direction()
		wander_timer = 0.0

	var next_pos = position + direction * speed * delta
	var cell = herbe_tilemap.local_to_map(next_pos)

	if herbe_tilemap.get_cell_source_id(cell) == 0:
		# ✅ Si la prochaine case est de l’herbe, on avance
		position = next_pos
		sprite.flip_h = direction.x < 0
	else:
		# ❌ Sinon, changer de direction
		pick_new_direction()

func pick_new_direction():
	var angle = randf_range(0, TAU)
	direction = Vector2(cos(angle), sin(angle)).normalized()
