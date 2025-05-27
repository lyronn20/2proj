extends Node

@onready var lbl_title = $Label
@onready var lbl_description = $RichTextLabel
@onready var tilemap_nuages: TileMapLayer = get_node("/root/game/tilemap_nuages")

var route_tilemap: TileMapLayer 
var current_goal_index := 0
var goal_accompli = 0
var menu 
var goals = [
	{ "title": "Construire un feu de camp", "description": "Place ton premier feu de camp pour établir ton campement.", "check": "check_feu_camp" },
	{ "title": "Construire 8 huttes", "description": "Construis 8 huttes pour loger tes habitants.", "check": "check_feu_camp" },
	{ "title": "Construire un puit", "description": "Installe un puit pour que les PNJ puissent boire.", "check": "check_feu_camp" },
	{ "title": "Construire un enclos à animaux", "description": "Place un bâtiment à animaux pour les élever.", "check": "check_feu_camp" },
	{ "title": "Construire 10 routes", "description": "Place 10 routes pour connecter tes bâtiments.", "check": "check_feu_camp" },
	{ "title": "Construire une scierie", "description": "Transforme le bois en planches.", "check": "check_feu_camp" },
	{ "title": "Avoir 150 bois", "description": "Stocke au moins 150 bois.", "check": "check_feu_camp" },
	{ "title": "Construire 3 bâtiments à animaux", "description": "Pose au moins 3 bâtiments à animaux pour accueillir du bétail.", "check": "check_feu_camp" },
	{ "title": "Construire une carrière", "description": "Place une carrière pour extraire de la pierre.", "check": "check_feu_camp" },
	{"title": "Avoir 100 pierres ", "description": "Stocker au moins 100 pierres", "check": "check_feu_camp" },
	{ "title": "Collecteur de baies + 75 baies", "description": "Place un collecteur de baies et récolte 75 baies.", "check": "check_feu_camp" },
	{ "title": "Construire une ferme", "description": "Commence l'agriculture.", "check": "check_feu_camp" },
	#{ "title": "Sélection multiple + déplacement", "description": "Sélectionne et déplace plusieurs objets.", "check": "check_multi_select" },
	{ "title": "2 puits + 2 enclos à animaux", "description": "Aie 2 puits et 2 bâtiments à animaux.", "check": "check_feu_camp" },
	{ "title": "100 citoyens", "description": "Atteins 50 PNJ sur l’île principale.", "check": "check_feu_camp" },
	{ "title": "250 blés stockés", "description": "Stocke au moins 250 blés.", "check": "check_feu_camp" },
	{ "title": "30 métiers assignés", "description": "Affecte 30 PNJ à un métier.", "check": "check_feu_camp" },
	{ "title": "150 citoyens + débloquer pont", "description": "Atteins 100 citoyens pour débloquer le pont.", "check": "check_feu_camp" },
	{ "title": "Construire un pont vers l'île 2", "description": "Permet d'étendre ton territoire vers l'île 2.", "check": "check_pont_ile2", "zone_rect": { "coin_haut_gauche": Vector2i(-110, -5), "coin_bas_droit": Vector2i(8, 112) } },
	{ "title": "Construire un pont vers l'île 3", "description": "Étends ton territoire vers l'île 3.", "check": "check_pont_ile3", "zone_rect": { "coin_haut_gauche": Vector2i(-110, -94), "coin_bas_droit": Vector2i(8, -2) } },  # ← HAUT GAUCHE
	{ "title": "Construire un pont vers l'île 4", "description": "Étends ton territoire vers l'île 4.", "check": "check_pont_ile4", "zone_rect": { "coin_haut_gauche": Vector2i(6, 28), "coin_bas_droit": Vector2i(118, 112) } },  # ← BAS DROITE
	{ "title": "Construire un pont vers l'île 5", "description": "Étends ton territoire vers l'île 5.", "check": "check_pont_ile5", "zone_rect": { "coin_haut_gauche": Vector2i(8, -94), "coin_bas_droit": Vector2i(130, 31) } }  # ← HAUT DROITE
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
		lbl_title.text = "🎯 " + goal["title"]
		lbl_description.text = goal["description"]
	else:
		lbl_title.text = "✅ Objectifs terminés"
		lbl_description.text = "Félicitations !"

		if get_parent().has_method("debloquer_objet"):
			get_parent().debloquer_objet()

func valider_goal(goal_id: String):
	if current_goal_index >= goals.size():
		return

	var goal = goals[current_goal_index]

	# Vérifie que le goal actuel correspond à celui à valider
	if "check" in goal and goal["check"] == goal_id:
		print("🎯 Objectif validé :", goal["title"])
		current_goal_index += 1
		goal_accompli += 1

		if "zone_rect" in goal:
			var rect = goal["zone_rect"]
			debloquer_zone_nuage_rect(rect["coin_haut_gauche"], rect["coin_bas_droit"])
			match goal_id:
				"check_pont_ile2":
					var ile2_label = get_node_or_null("/root/game/ile 2")
					if ile2_label:
						ile2_label.visible = false
				"check_pont_ile3":
					var ile3_label = get_node_or_null("/root/game/ile 3")
					if ile3_label:
						ile3_label.visible = false
				"check_pont_ile4":
					var ile4_label = get_node_or_null("/root/game/ile 4")
					if ile4_label:
						ile4_label.visible = false
				"check_pont_ile5":
					var ile5_label = get_node_or_null("/root/game/ile 5")
					if ile5_label:
						ile5_label.visible = false


		elif "zone" in goal:
			debloquer_zone_nuage(goal["zone"], 20)

		update_goal_display()

		if menu:
			menu.set_locked_buttons(goal_accompli)
			
		if goal_id == "check_scierie":
			debloquer_liens_objets("scierie")
		elif goal_id == "check_ferme":
			debloquer_liens_objets("ferme")
		elif goal_id == "check_berry":
			debloquer_liens_objets("collect_baies")
		elif goal_id == "check_carriere":
			debloquer_liens_objets("carriere")
		if goal_id == "check_pont":
			menu.set_bloque("Pont", false)
		elif goal_id == "check_scierie":
			menu.set_bloque("sapin", false)
			menu.set_bloque("sol_terre", false)





func _process(_delta):
	if current_goal_index >= goals.size():
		return

	check_current_goal()
			
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

func check_current_goal():
	if current_goal_index >= goals.size():
		return

	var goal = goals[current_goal_index]
	var check_method = goal.get("check", "")

	if has_method(check_method):
		var result = call(check_method)
		if result == true:
			valider_goal(goal["check"])


func check_feu_camp() -> bool:
	# Vérifie si un bâtiment commençant par "feu_camp" existe
	for node in get_tree().get_nodes_in_group("batiment"):
		if node.name.begins_with("feu_camp"):
			return true
	return false


func check_huttes() -> bool:
	var total = 0
	for obj in get_tree().get_nodes_in_group("placeable"):
		if obj.name.begins_with("hutte"):
			total += 1
	return total >= 8


func check_puit() -> bool:
	for obj in get_tree().get_nodes_in_group("placeable"):
		if obj.name.begins_with("puit"):
			return true
	return false
	
func check_animaux() -> bool:
	for node in get_tree().get_nodes_in_group("batiment"):
		if node.name.begins_with("animaux_bat"):
			return true
	return false

func check_routes() -> bool:
	if not route_tilemap:
		return false
	var count := 0
	for cell in route_tilemap.get_used_cells():
		if route_tilemap.get_cell_source_id(cell) != -1:
			count += 1
	return count >= 10

func check_scierie() -> bool:
	for node in get_tree().get_nodes_in_group("batiment"):
		if node.name.begins_with("scierie") and not node.has_meta("is_preview"):
			return true
	return false


func check_150_bois() -> bool:
	var total := 0
	for node in get_tree().get_nodes_in_group("scierie"):
		if node.has_method("get_stock"):
			total += node.get_stock()["bois"]
	return total >= 150
	
func check_3_animaux() -> bool:
	var total := 0
	for node in get_tree().get_nodes_in_group("animaux_bat"):
		if node.name.begins_with("animaux_bat"):
			total += 1
	return total >= 3


func check_carriere() -> bool:
	for node in get_tree().get_nodes_in_group("batiment"):
		if node.name.begins_with("carriere"):
			return true
	return false
	
func check_pierres() ->bool:
	var total := 0
	for node in get_tree().get_nodes_in_group("carriere"):
		if node.has_method("get_stock"):
			total += node.get_stock()["pierre"]
	return total >= 100

func check_berry() -> bool:
	var total := 0
	for node in get_tree().get_nodes_in_group("collect_baies"):
		if node.has_method("get_stock"):
			var stock = node.get_stock()
			if typeof(stock) == TYPE_DICTIONARY and stock.has("baies"):
				total += int(stock["baies"])
	return total >= 75

func check_ferme() -> bool:
	for node in get_tree().get_nodes_in_group("batiment"):
		if node.name.begins_with("ferme") and not node.has_meta("is_preview"):
			return true
	return false

func check_multi_select() -> bool:
	# À adapter à ton système de sélection/déplacement
	# Ici on vérifie s'il y a un groupe d'objets sélectionnés en cours
	if get_parent().has_method("has_moved_multiple"):
		return get_parent().has_moved_multiple()
	return false

func check_double_eau_animaux() -> bool:
	var nb_puits := 0
	var nb_animaux := 0
	for node in get_tree().get_nodes_in_group("batiment"):
		if node.name.begins_with("puit") and not node.has_meta("is_preview"):
			nb_puits += 1
		elif node.name.begins_with("animaux_bat") and not node.has_meta("is_preview"):
			nb_animaux += 1
	return nb_puits >= 2 and nb_animaux >= 2

func check_50_citoyens() -> bool:
	var total := get_tree().get_nodes_in_group("pnj").size()
	return total >= 50

func check_250_ble() -> bool:
	var total := 0
	for node in get_tree().get_nodes_in_group("ferme"):
		if node.has_method("get_stock"):
			var stock = node.get_stock()
			if typeof(stock) == TYPE_DICTIONARY and stock.has("blé"):
				total += int(stock["blé"])
	return total >= 250

func check_30_metiers() -> bool:
	var count := 0
	for pnj in get_tree().get_nodes_in_group("pnj"):
		if pnj.metier != "":
			count += 1
	return count >= 30
	
func check_100_citoyens() -> bool:
	var total := get_tree().get_nodes_in_group("pnj").size()
	return total >= 100

func check_pont() -> bool:
	if not get_tree().get_root().has_node("game/Pont/pont"):
		return false

	var pont_tilemap = get_tree().get_root().get_node("game/Pont/pont")
	for cell in pont_tilemap.get_used_cells():
		if pont_tilemap.get_cell_source_id(cell) != -1:
			return true
	return false
	
func check_pont_ile2() -> bool:
	if not get_tree().get_root().has_node("game/Pont/pont"):
		return false

	var pont_tilemap = get_tree().get_root().get_node("game/Pont/pont")

	for cell in pont_tilemap.get_used_cells():
		if pont_tilemap.get_cell_source_id(cell) != -1:
			if cell.x >= -122 and cell.x <= -23 and cell.y >= -4 and cell.y <= 112:
				return true
	return false
	
func check_pont_ile3() -> bool:
	return _pont_dans_zone(Vector2i(-122, -102), Vector2i(-38, -11))  # haut gauche

func check_pont_ile4() -> bool:
	return _pont_dans_zone(Vector2i(6, 28), Vector2i(118, 112))  # bas droite

func check_pont_ile5() -> bool:
	return _pont_dans_zone(Vector2i(8, -94), Vector2i(130, 31))  # haut droite


func _pont_dans_zone(chg: Vector2i, cbd: Vector2i) -> bool:
	var pont_tilemap = get_node_or_null("/root/game/Pont/pont")
	if not pont_tilemap:
		return false
	for cell in pont_tilemap.get_used_cells():
		if cell.x >= chg.x and cell.x <= cbd.x and cell.y >= chg.y and cell.y <= cbd.y:
			if pont_tilemap.get_cell_source_id(cell) != -1:
				return true
	return false



func debloquer_liens_objets(nom: String):
	if menu == null:
		return

	match nom:
		"scierie":
			menu.set_bloque("sapin", false)
		"ferme":
			menu.set_bloque("blé", false)
		"collect_baies":
			menu.set_bloque("baies", false)
		"carriere":
			menu.set_bloque("pierre", false)
		_:
			pass
