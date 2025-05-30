extends AnimatedSprite2D

@onready var herbe_tilemap: TileMapLayer = get_node("/root/game/herbe")

var direction := Vector2.ZERO
var speed := 15.0
var wander_timer := 0.0
var interval := 2.0

func _ready():
	pick_new_direction()
	if sprite_frames and sprite_frames.has_animation("walk"):
		play("walk")

func _process(delta):
	wander_timer += delta
	if wander_timer >= interval:
		wander_timer = 0
		pick_new_direction()
	var next_pos = global_position + direction * speed * delta
	var cell = herbe_tilemap.local_to_map(next_pos)
	if herbe_tilemap.get_cell_source_id(cell) == 0:
		global_position = next_pos
		self.flip_h = direction.x < 0
	else:
		pick_new_direction()

func pick_new_direction():
	var dx = randf_range(-1.0, 1.0)
	var dy = randf_range(-1.0, 1.0)
	direction = Vector2(dx, dy).normalized()
