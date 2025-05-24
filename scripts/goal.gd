extends Node

@onready var lbl_title = $Label
@onready var lbl_description = $RichTextLabel
@onready var tilemap_nuages: TileMapLayer = get_node("/root/game/tilemap_nuages")

var route_tilemap: TileMapLayer 
var current_goal_index := 0
var goal_accompli = 7
var menu 
var goals = [
	{
		"title": "Poser un feu de camp",
		"description": "Place ton premier feu de camp pour établir ton campement.",
		"id": "feu_camp",
		"zone_rect": {
			"coin_haut_gauche": Vector2i(-122,-4),
			"coin_bas_droit": Vector2i(-23, 112)
		}
	},
	{
		"title": "Construire une hutte",
		"description": "Construis une hutte pour héberger tes citoyens.",
		"id": "hutte",
		"zone": Vector2i(55, 30)
	},
	{
		"title": "Poser des routes en terre",
		"description": "Place 5 routes en terre pour faciliter les déplacements.",
		"id": "route_terre"
	},
	{
		"title": "Construire un puits",
		"description": "Place un puits pour que les citoyens puissent boire.",
		"id": "puit"
	},
	{
		"title": "Construire une ferme",
		"description": "Plante et récolte du blé pour nourrir la population.",
		"id": "ferme"
	},
	{
		"title": "Construire une scierie",
		"description": "Transforme le bois brut en planches.",
		"id": "scierie"
	},
	{
		"title": "Construire un pont",
		"description": "Relie ton île principale à une autre en posant un pont.",
		"id": "pont"
	},
	{
		"title": "Entrer dans l’âge de pierre",
		"description": "Atteins l'île secondaire et pose un feu de camp.",
		"id": "ile2"
	}
]

func _ready():
	update_goal_display()

	if get_tree().get_root().has_node("game/Route/route"):
		route_tilemap = get_tree().get_root().get_node("game/Route/route")
	else:
		push_warning("❌ TileMap de route introuvable. Vérifie le chemin dans goal.gd")

	# 🔗 Lier le menu
	if get_tree().get_root().has_node("game/CanvasLayer/Menu"):
		menu = get_tree().get_root().get_node("game/CanvasLayer/Menu")
	else:
		push_warning("❌ Menu introuvable dans goal.gd")


func update_goal_display():
	if current_goal_index < goals.size():
		var goal = goals[current_goal_index]
		lbl_title.text = "🎯 " + goal.title
		lbl_description.text = goal.description
	else:
		lbl_title.text = "✅ Objectifs terminés"
		lbl_description.text = "Félicitations !"

		if get_parent().has_method("debloquer_objet"):
			get_parent().debloquer_objet()

func valider_goal(goal_id: String):
	if current_goal_index < goals.size() and goals[current_goal_index].id == goal_id:
		print("🎯 Goal validé :", goal_id)
		current_goal_index += 1
		goal_accompli += 1  # ✅ on incrémente ici
		var goal = goals[current_goal_index - 1]
		if "zone_rect" in goal:
			var rect = goal["zone_rect"]
			debloquer_zone_nuage_rect(rect["coin_haut_gauche"], rect["coin_bas_droit"])
		elif "zone" in goal:
			debloquer_zone_nuage(goal["zone"], 20)
		
		update_goal_display()

		# 🔓 débloquer les objets dans le menu en fonction du progrès
		if menu:
			menu.set_locked_buttons(goal_accompli)



func _process(_delta):
	if current_goal_index >= goals.size():
		return

	if goals[current_goal_index].id == "route_terre" and route_tilemap:
		var count = 0
		for cell in route_tilemap.get_used_cells():
			if route_tilemap.get_cell_source_id(cell) != -1:
				count += 1

		if count >= 5:
			valider_goal("route_terre")
			
			
func debloquer_zone_nuage(position: Vector2i, rayon: int = 5):

	if not tilemap_nuages:

		push_error("❌ tilemap_nuages est nul.")

		return



	for x in range(-rayon, rayon + 1):

		for y in range(-rayon, rayon + 1):

			var cell: Vector2i = position + Vector2i(x, y)

			tilemap_nuages.set_cell( cell, -1)



func debloquer_zone_nuage_rect(coin_haut_gauche: Vector2i, coin_bas_droit: Vector2i):

	if not tilemap_nuages:

		push_error("❌ tilemap_nuages est nul.")

		return



	for x in range(coin_haut_gauche.x, coin_bas_droit.x + 1):

		for y in range(coin_haut_gauche.y, coin_bas_droit.y + 1):

			var cell = Vector2i(x, y)

			tilemap_nuages.set_cell( cell, -1)
