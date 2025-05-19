extends Control

@onready var vbox := $VBoxContainer

func _ready():
	await get_tree().process_frame
	update_dashboard()


func update_dashboard(batiment: Node = null):
	for child in vbox.get_children():
		child.queue_free()

	if batiment:
		var label = Label.new()
		label.text = "🏠 " + batiment.name
		vbox.add_child(label)

		if "habitants" in batiment:
			for p in batiment.habitants:
				var p_label = Label.new()
				p_label.text = "  → PNJ ID: " + str(p.id)
				vbox.add_child(p_label)
		elif "employes" in batiment:
			for p in batiment.employes:
				var p_label = Label.new()
				p_label.text = "  → PNJ ID: " + str(p.id)
				vbox.add_child(p_label)
