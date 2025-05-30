extends Control
func _ready():
	$btnJouer.pressed.connect(_on_jouer_pressed)
	$btnCharger.pressed.connect(_on_charger_pressed)
	$btnQuitter.pressed.connect(_on_quitter_pressed)

func _on_jouer_pressed():
	get_tree().change_scene_to_file("res://scenes/game.tscn")  

func _on_charger_pressed():
	return

func _on_quitter_pressed():
	get_tree().quit()
