extends Node2D

@export var poule_scene: PackedScene = preload("res://scenes/poule.tscn")
@export var cochon_scene: PackedScene = preload("res://scenes/cochon.tscn")
@export var vache_scene: PackedScene = preload("res://scenes/vache.tscn")

var animaux := []
const MAX_ANIMAUX = 15

func _ready():
	add_to_group("batiment")
	add_to_group("animaux_bat")
	$Timer.wait_time = 25
	$Timer.start()
	$Timer.timeout.connect(spawn_animaux)

func spawn_animaux():
	if animaux.size() >= MAX_ANIMAUX:
		return
	var scenes = [poule_scene, cochon_scene, vache_scene]
	var scene = scenes[randi() % scenes.size()]
	var instance = scene.instantiate()
	var x_offset = randf_range(-48, 48)
	var y_offset = randf_range(-48, 48)
	instance.global_position = global_position + Vector2(x_offset, y_offset)
	get_tree().get_root().get_node("game").add_child(instance)
	animaux.append(instance)

func consommer_animal(pnj):
	var priorites = [
		{ "gain": 100, "name": "vache", "scene": vache_scene },
		{ "gain": 100, "name": "cochon", "scene": cochon_scene },
		{ "gain": 100, "name": "poule", "scene": poule_scene }
	]

	for t in priorites:
		for a in animaux:
			if a.name.to_lower().findn(t.name) != -1:
				animaux.erase(a)
				a.queue_free()
				pnj.faim = clamp(pnj.faim + t.gain, 0, 100)
				await get_tree().create_timer(60).timeout
				spawn_specific(t.scene)
				return true
	return false

func spawn_specific(scene: PackedScene):
	if animaux.size() >= MAX_ANIMAUX:
		return
	var instance = scene.instantiate()
	instance.global_position = global_position + Vector2(randf_range(-48, 48), randf_range(-48, 48))
	get_tree().get_root().get_node("game").add_child(instance)
	animaux.append(instance)

func get_animaux_disponibles():
	return animaux.filter(func(a): return is_instance_valid(a) and a.visible)

func get_animal_disponible():
	var dispos = get_animaux_disponibles()
	if dispos.size() == 0:
		return null
	return dispos[randi() % dispos.size()]
