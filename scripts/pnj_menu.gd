extends Control

@onready var panel        : Panel               = $Panel
@onready var label_id     : Label               = $Panel/VBoxContainer/Label_ID
@onready var bar_faim     : TextureProgressBar  = $Panel/VBoxContainer/Label_Faim
@onready var bar_soif     : TextureProgressBar  = $Panel/VBoxContainer/Label_Soif
@onready var label_metier : Label               = $Panel/VBoxContainer/Label_Metier

func _ready():
	visible = false
	set_process_unhandled_input(true)

func show_for(pnj):
	visible = true
	# Positionner le panel au-dessus du sprite
	var cam      : Camera2D = get_viewport().get_camera_2d()
	var screen_p = cam.unproject_position(pnj.global_position)
	var size     = panel.rect_size
	panel.rect_position = screen_p + Vector2(-size.x * 0.5,
											 -pnj.sprite.texture.get_size().y - size.y)

	# Mettre à jour l’ID
	label_id.text = "ID : %d" % pnj.id
	# Mettre à jour les barres de faim/soif
	bar_faim.value = pnj.faim
	bar_soif.value = pnj.soif
	# Mettre à jour le métier
	var met = pnj.metier if pnj.metier != "" else "Aucun"
	label_metier.text = "Métier : %s" % met

func _unhandled_input(event):
	if visible and event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		visible = false
