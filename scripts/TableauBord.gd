extends Control

@onready var batiment_panel := $Batiment
@onready var vbox := $Batiment/VBoxContainer
@onready var pnj_panel := $PNJ
@onready var pnj_content := $PNJ/VBoxContainer




func _ready():
	await get_tree().process_frame
	batiment_panel.visible = false  # caché au démarrage
	update_dashboard()

func update_dashboard(batiment: Node = null):
	pnj_panel.visible = false  # cache le panneau PNJ quand on montre un bâtiment
	batiment_panel.visible = false
	for child in vbox.get_children():
		child.queue_free()

	if batiment:
		batiment_panel.visible = true

		var label = Label.new()
		label.text = "🏠 " + batiment.name
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


func update_pnj_panel(pnj: Node):
	pnj_panel.visible = true
	batiment_panel.visible = false
	for child in pnj_content.get_children():
		child.queue_free()

	var label_id = Label.new()
	label_id.text = "🧍 ID: " + str(pnj.id)
	label_id.add_theme_color_override("font_color", Color("#e9bc96"))
	pnj_content.add_child(label_id)

	var label_metier = Label.new()
	label_metier.text = "🏷️ Métier: " + str(pnj.metier)
	label_metier.add_theme_color_override("font_color", Color("#e9bc96"))
	pnj_content.add_child(label_metier)

	var label_faim = Label.new()
	label_faim.text = "🍗 Faim: " + str(round(pnj.faim)) + "%"
	label_faim.add_theme_color_override("font_color", Color("#e9bc96"))
	pnj_content.add_child(label_faim)

	var label_soif = Label.new()
	label_soif.text = "💧 Soif: " + str(round(pnj.soif)) + "%"
	label_soif.add_theme_color_override("font_color", Color("#e9bc96"))
	pnj_content.add_child(label_soif)
