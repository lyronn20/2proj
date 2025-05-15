@tool
extends GridContainer

@export var width := 10:
	set(value):
		width = value
		_refresh_grid()
@export var height := 10:
	set(value):
		height = value
		_refresh_grid()
@export var cell_width := 32:
	set(value):
		cell_width = value
		_refresh_grid()
@export var cell_height := 32:
	set(value):
		cell_height = value
		_refresh_grid()
@export var border_size := 0:
	set(value):
		border_size = value
		_refresh_grid()

func _ready():
	if Engine.is_editor_hint(): return
	_refresh_grid()

func _refresh_grid():
	columns = width
	add_theme_constant_override("h_separation", border_size)
	add_theme_constant_override("v_separation", border_size)

	for child in get_children():
		child.queue_free()

	for y in height:
		for x in width:
			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(cell_width, cell_height)
			_set_cell_style(cell, Color(1,1,1,0))  # Transparent

			cell.mouse_entered.connect(func():
				_set_cell_style(cell, Color(1, 0, 0, 0.2))  # Rouge au survol
			)
			cell.mouse_exited.connect(func():
				_set_cell_style(cell, Color(1,1,1,0))  # Re-transparent
			)
			cell.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed:
					_set_cell_style(cell, Color(0, 1, 0, 0.4))  # Vert au clic
					print("Cell clicked at (", x, ",", y, ")")
			)

			add_child(cell)

func _set_cell_style(cell: PanelContainer, color: Color):
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = color
	cell.add_theme_stylebox_override("panel", stylebox)
