extends Node
@onready var lbl_title = $Label
@onready var lbl_description = $RichTextLabel

var current_goal_index := 0

var goals = [
	{
		"title": "Poser un feu de camp",
		"description": "Place ton premier feu de camp pour établir ton campement.",
		"id": "feu_camp"
	},
	{
		"title": "Construire une hutte",
		"description": "Construis une hutte pour héberger tes citoyens.",
		"id": "hutte"
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

func update_goal_display():
	if current_goal_index < goals.size():
		var goal = goals[current_goal_index]
		lbl_title.text = "🎯 " + goal.title
		lbl_description.text = goal.description
	else:
		lbl_title.text = "✅ Objectifs terminés"
		lbl_description.text = "Félicitations !"

func valider_goal(goal_id: String):
	print("✅ Tentative de validation de goal:", goal_id)

	if current_goal_index < goals.size() and goals[current_goal_index].id == goal_id:
		print("🎯 Goal validé :", goal_id)
		current_goal_index += 1
		update_goal_display()

	if current_goal_index < goals.size() and goals[current_goal_index].id == goal_id:
		current_goal_index += 1
		update_goal_display()
