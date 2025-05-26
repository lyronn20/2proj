extends Control

@onready var batiment_panel := $Batiment
@onready var vbox := $Batiment/VBoxContainer

@onready var pnj_panel := $PNJ
@onready var pnj_content := $PNJ/VBoxContainer
@onready var bar_faim := $PNJ/VBoxContainer/BarFaim
@onready var bar_soif := $PNJ/VBoxContainer/BarSoif
@onready var bar_energie := $PNJ/VBoxContainer/BarEnergie
@onready var stock_panel := $Total_stock/HBoxContainer

var current_pnj: Node = null

func _ready():
	await get_tree().process_frame
	batiment_panel.visible = false
	update_dashboard()
	await get_tree().create_timer(0.1).timeout
	update_total_stock()

	# 🕒 Rafraîchir le stock régulièrement
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.timeout.connect(update_total_stock)
	add_child(timer)
	timer.start()

func update_dashboard(batiment: Node = null):
	pnj_panel.visible = false
	batiment_panel.visible = false

	# Vide l'ancien contenu
	for child in vbox.get_children():
		child.queue_free()

	# Si rien n'est sélectionné, on sort
	if batiment == null:
		return

	batiment_panel.visible = true

	# Titre du bâtiment
	var nom := batiment.name
	if batiment.has_meta("nom_affichage"):
		nom = batiment.get_meta("nom_affichage")
	vbox.add_child(make_label("🏠 " + nom))

	# Liste des PNJ
	if "habitants" in batiment:
		# On purge d'abord les références mortes
		batiment.habitants = batiment.habitants.filter(is_instance_valid)
		for p in batiment.habitants:
			# Garde seulement les PNJ encore valides
			if is_instance_valid(p):
				vbox.add_child(make_label("→ PNJ ID: " + str(p.id)))
	elif "employes" in batiment:
		batiment.employes = batiment.employes.filter(is_instance_valid)
		for p in batiment.employes:
			if is_instance_valid(p):
				vbox.add_child(make_label("→ PNJ ID: " + str(p.id)))


		# Affiche le stock si disponible
		if batiment.has_method("get_stock"):
			var stock = batiment.get_stock()
			if typeof(stock) == TYPE_DICTIONARY:
				vbox.add_child(make_label("📦 Stock :"))
				for res in stock.keys():
					vbox.add_child(make_label("  → " + res.capitalize() + " : " + str(stock[res])))
			else:
				vbox.add_child(make_label("📦 Stock : " + str(stock)))

func make_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color("#e9bc96"))
	return lbl

func make_bar(value: float) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.step = 1
	bar.value = value
	bar.custom_minimum_size = Vector2(0, 16)
	return bar

func update_pnj_panel(pnj: Node):
	pnj_panel.visible = true
	batiment_panel.visible = false

	for child in pnj_content.get_children():
		child.queue_free()

	pnj_content.add_child(make_label("🍗 Faim"))
	pnj_content.add_child(make_colored_bar(pnj.faim, Color(1, 0.2, 0.2)))

	pnj_content.add_child(make_label("💧 Soif"))
	pnj_content.add_child(make_colored_bar(pnj.soif, Color(0.2, 0.6, 1)))

	pnj_content.add_child(make_label("⚡ Énergie"))
	pnj_content.add_child(make_colored_bar(pnj.energy, Color(0.3, 1, 0.3)))

	pnj_content.add_child(make_label("🧍 ID: " + str(pnj.id)))
	pnj_content.add_child(make_label("🏷️ Métier: " + str(pnj.metier)))

func make_colored_bar(value: float, color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.step = 1
	bar.value = value
	bar.custom_minimum_size = Vector2(0, 18)

	var background_style = StyleBoxFlat.new()
	background_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	background_style.set_border_width_all(1)
	background_style.border_color = Color(0.3, 0.3, 0.3)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(3)

	bar.add_theme_stylebox_override("background", background_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.add_theme_color_override("font_color", Color(1, 1, 1))
	bar.add_theme_color_override("font_outline_color", Color.BLACK)
	bar.add_theme_constant_override("outline_size", 1)

	return bar

func update_total_stock():
	var stock_total := {
		"blé": 0,
		"bois": 0,
		"pierre": 0,
		"baies": 0,
		"eau": 0
	}

	for node in get_tree().get_nodes_in_group("batiment"):
		if node.has_method("get_stock"):
			var stock = node.get_stock()
			if typeof(stock) == TYPE_DICTIONARY:
				for key in stock:
					if stock_total.has(key):
						stock_total[key] += stock[key]
			elif typeof(stock) == TYPE_INT:
				# Si le bâtiment retourne un entier → on suppose que c'est de l'eau (cas du puit)
				stock_total["eau"] += stock

	for child in stock_panel.get_children():
		child.queue_free()

	var icons = {
		"blé": "🌾 ",
		"bois": "🪵 ",
		"pierre": "🪨 ",
		"baies": "🍓 ",
		"eau": "💧 "
	}

	for res in ["blé", "bois", "pierre", "baies", "eau"]:
		var label = Label.new()
		label.text = icons[res] + " " + res + " : " + str(stock_total[res])
		label.add_theme_color_override("font_color", Color("#e9bc96"))
		stock_panel.add_child(label)
