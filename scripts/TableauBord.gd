extends Control

@onready var batiment_panel := $Batiment
@onready var vbox := $Batiment/VBoxContainer

@onready var pnj_panel := $PNJ
@onready var pnj_content := $PNJ/VBoxContainer
@onready var bar_faim := $PNJ/VBoxContainer/BarFaim
@onready var bar_soif := $PNJ/VBoxContainer/BarSoif
@onready var bar_energie := $PNJ/VBoxContainer/BarEnergie
@onready var stock_panel := $Total_stock/HBoxContainer

var current_pnj :Node= null



func _ready():
	await get_tree().process_frame
	batiment_panel.visible = false
	update_dashboard()
	await get_tree().create_timer(0.1).timeout
	update_total_stock()
	print("✅ total stock lancé")  # ← ce print DOIT apparaître


func update_dashboard(batiment: Node = null):
	pnj_panel.visible = false
	batiment_panel.visible = false
	for child in vbox.get_children():
		child.queue_free()

	if batiment:
		batiment_panel.visible = true

		# ➕ Utilise `nom_affichage` s'il existe, sinon fallback sur le name brut
		var nom := batiment.name
		if batiment.has_meta("nom_affichage"):
			nom = batiment.get_meta("nom_affichage")

		var label = Label.new()
		label.text = "🏠 " + nom
		label.add_theme_color_override("font_color", Color("#e9bc96"))
		vbox.add_child(label)

		if "habitants" in batiment:
			for p in batiment.habitants:
				var p_label = Label.new()
				p_label.text = "  → PNJ ID: " + str(p.id)
				p_label.add_theme_color_override("font_color", Color("#e9bc96"))
				vbox.add_child(p_label)
		elif "employes" in batiment:
			for p in batiment.employes:
				var p_label = Label.new()
				p_label.text = "  → PNJ ID: " + str(p.id)
				p_label.add_theme_color_override("font_color", Color("#e9bc96"))
				vbox.add_child(p_label)
		
		# Affiche le stock si disponible
		if batiment.has_method("get_stock"):
			var stock = batiment.get_stock()
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
	pnj_content.add_child(make_colored_bar(pnj.faim, Color(1, 0.2, 0.2)))  # rouge

	pnj_content.add_child(make_label("💧 Soif"))
	pnj_content.add_child(make_colored_bar(pnj.soif, Color(0.2, 0.6, 1)))   # bleu

	pnj_content.add_child(make_label("⚡ Énergie"))
	pnj_content.add_child(make_colored_bar(pnj.energy, Color(0.3, 1, 0.3))) # vert

	pnj_content.add_child(make_label("🧍 ID: " + str(pnj.id)))
	pnj_content.add_child(make_label("🏷️ Métier: " + str(pnj.metier)))



func make_colored_bar(value: float, color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.step = 1
	bar.value = value
	bar.custom_minimum_size = Vector2(0, 18)

	# Crée un style de fond sombre
	var background_style = StyleBoxFlat.new()
	background_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)  # fond presque noir avec transparence
	background_style.set_border_width_all(1)
	background_style.border_color = Color(0.3, 0.3, 0.3)

	# Crée un style de remplissage coloré
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(3)

	# Applique les styles
	bar.add_theme_stylebox_override("background", background_style)
	bar.add_theme_stylebox_override("fill", fill_style)

	# Ajoute un texte blanc lisible
	bar.add_theme_color_override("font_color", Color(1, 1, 1))
	bar.add_theme_color_override("font_outline_color", Color.BLACK)
	bar.add_theme_constant_override("outline_size", 1)


	return bar
	
	
	
func update_total_stock():
	var stock_total := {
		"blé": 0,
		"bois": 0,
		"pierre": 0,
		"baies": 0
	}

	for node in get_tree().get_nodes_in_group("batiment"):
		if node.has_method("get_stock"):
			var stock = node.get_stock()
			if typeof(stock) == TYPE_DICTIONARY:
				for key in stock:
					if stock_total.has(key):
						stock_total[key] += stock[key]

	for child in stock_panel.get_children():
		child.queue_free()

	var icons = {
		"blé": "🌾",
		"bois": "🪵",
		"pierre": "🪨",
		"baies": "🍓"
	}

	for res in ["blé", "bois", "pierre", "baies"]:
		var label = Label.new()
		label.text = icons[res] + " " + res + " : " + str(stock_total[res])
		label.add_theme_color_override("font_color", Color("#e9bc96"))
		stock_panel.add_child(label)
