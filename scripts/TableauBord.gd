extends Control

@onready var batiment_panel := $Batiment
@onready var vbox := $Batiment/VBoxContainer

func _ready():
	await get_tree().process_frame
	batiment_panel.visible = false  # caché au démarrage
	update_dashboard()

func update_dashboard(batiment: Node = null):
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
