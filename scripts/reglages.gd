extends Panel

@onready var bouton = $HBoxContainer/TextureRect
@onready var menu = $menu_reglages
@onready var panneau_popup = $menu_reglages/panneau_popup
@onready var label_popup = $menu_reglages/panneau_popup/VBoxContainer/Label
@onready var panneau_confirmation = $menu_reglages/popup_quit
@onready var btn_confirm_quit = $menu_reglages/popup_quit/VBoxContainer/BtnConfirmerQuitter
@onready var btn_cancel_quit = $menu_reglages/popup_quit/VBoxContainer/BtnAnnulerQuitter

@onready var btn_regles = $menu_reglages/BtnRegles
@onready var btn_touches = $menu_reglages/BtnTouches
@onready var btn_reset = $menu_reglages/BtnRecommencer
@onready var btn_quit = $menu_reglages/BtnQuitter

func _ready():
	menu.visible = false
	panneau_popup.visible = false
	panneau_confirmation.visible = false
	panneau_confirmation.hide() # 🛠️ assure que le popup ne clignote pas au lancement

	bouton.mouse_filter = Control.MOUSE_FILTER_PASS
	bouton.connect("gui_input", _on_bouton_clicked)

	btn_regles.pressed.connect(_on_regles_pressed)
	btn_touches.pressed.connect(_on_touches_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

	btn_confirm_quit.pressed.connect(_on_confirm_quit)
	btn_cancel_quit.pressed.connect(_on_cancel_quit)

	set_process_unhandled_input(true)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if panneau_popup.visible:
				panneau_popup.visible = false
			elif panneau_confirmation.visible:
				panneau_confirmation.visible = false
			elif menu.visible:
				menu.visible = false
		elif event.keycode == KEY_M:
			menu.visible = !menu.visible

func _on_bouton_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		menu.visible = !menu.visible


func _on_reset_pressed():
	get_tree().reload_current_scene()

func _on_regles_pressed():
	_fermer_tous_les_popups()
	_affiche_popup("Règles du jeu,\nDéveloppe ta ville,\nplace des bâtiments,\noptimise tes ressources.")

func _on_touches_pressed():
	_fermer_tous_les_popups()
	_affiche_popup("Contrôles :\n- Clic gauche = placer objet\n- R = route\n- Gomme = supprimer\n- Échap = fermer\n- M = menu")

func _on_quit_pressed():
	_fermer_tous_les_popups()
	panneau_confirmation.visible = true


func _on_confirm_quit():
	get_tree().quit()

func _on_cancel_quit():
	panneau_confirmation.visible = false

func _affiche_popup(texte: String):
	var style = label_popup.get_theme_stylebox("normal").duplicate()
	label_popup.add_theme_stylebox_override("normal", style)
	label_popup.add_theme_color_override("font_color", Color("#e9bc96"))
	label_popup.text = texte
	panneau_popup.visible = true
	
	
func _fermer_tous_les_popups():
	panneau_popup.visible = false
	panneau_confirmation.visible = false
