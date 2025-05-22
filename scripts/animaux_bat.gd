extends Node2D

@export var poule_scene: PackedScene = preload("res://scenes/poule.tscn")
@export var cochon_scene: PackedScene = preload("res://scenes/cochon.tscn")
@export var vache_scene: PackedScene = preload("res://scenes/vache.tscn")

var animaux := []
const MAX_ANIMAUX = 15

func _ready():
	spawn_animaux()
	# Redémarre le spawn toutes les 60 sec
	$Timer.wait_time = 60
	$Timer.start()
	$Timer.timeout.connect(spawn_animaux)

func spawn_animaux():
	if animaux.size() >= MAX_ANIMAUX:
		return

	var to_spawn := [
		{ "scene": poule_scene, "max": 5 },
		{ "scene": cochon_scene, "max": 5 },
		{ "scene": vache_scene, "max": 5 },
	]

	for group in to_spawn:
		var count = animaux.filter(func(a): return a.type == group.scene.resource_path).size()
		while count < group.max and animaux.size() < MAX_ANIMAUX:
			var instance = group.scene.instantiate()
			instance.global_position = global_position + Vector2(randf_range(-48, 48), randf_range(-48, 48))
			get_tree().get_root().get_node("game").add_child(instance)
			instance.type = group.scene.resource_path  # pour filtrer ensuite
			animaux.append(instance)
			count += 1

# Pour qu’un PNJ appelle ça :
func consommer_animal(pnj):
	var type_priorite = [
		{ "gain": 60, "name": "vache" },
		{ "gain": 35, "name": "cochon" },
		{ "gain": 15, "name": "poule" },
	]

	for t in type_priorite:
		for a in animaux:
			if a.name.to_lower().findn(t.name) != -1:
				a.queue_free()
				animaux.erase(a)
				pnj.faim = clamp(pnj.faim + t.gain, 0, 100)
				return true
	return false

func get_animaux_disponibles():
	return animaux.filter(func(a): return is_instance_valid(a) and a.visible)

func get_animal_disponible():
	var dispos = get_animaux_disponibles()
	if dispos.size() == 0:
		return null
	return dispos[randi() % dispos.size()]
