extends TileMapLayer

@onready var cam = get_parent().get_node("Camera2D")
var min = 0.5
var max = 3.0
var zoom_speed = 0.1
var dragging := false

func _unhandled_input(clic):
	if clic is InputEventMouseButton:
		if clic.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom *= 1.0 - zoom_speed
			var limit1 = Vector2(min, min)
			var limit2 = Vector2(max, max)
			var z = cam.zoom
			cam.zoom = z.clamp(limit1, limit2)
		elif clic.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom *= 1.0 + zoom_speed
			var limit3 = Vector2(min, min)
			var limit4 = Vector2(max, max)
			var z = cam.zoom
			cam.zoom = z.clamp(limit3, limit4)
		elif clic.button_index == MOUSE_BUTTON_RIGHT:
			dragging = clic.pressed

	elif clic is InputEventMouseMotion and dragging:
		cam.global_position -= clic.relative * cam.zoom
