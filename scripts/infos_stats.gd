extends Panel

@onready var lbl_population = $VBoxContainer/Population
@onready var lbl_housing = $VBoxContainer/Housing
@onready var lbl_jobs = $VBoxContainer/Jobs
@onready var lbl_progress = $VBoxContainer/HBoxContainer/Progress
@onready var bar_progress = $VBoxContainer/HBoxContainer/ProgressBar
@onready var lbl_timer = $VBoxContainer/Timer

var time_elapsed := 0.0

func _ready():
	var color = Color.html("#e9bc96")
	lbl_population.add_theme_color_override("font_color", color)
	lbl_housing.add_theme_color_override("font_color", color)
	lbl_jobs.add_theme_color_override("font_color", color)
	lbl_progress.add_theme_color_override("font_color", color)
	lbl_timer.add_theme_color_override("font_color", color)

func _process(delta):
	time_elapsed += delta
	var mins = int(time_elapsed / 60)
	var secs = int(time_elapsed) % 60
	lbl_timer.text = "⏱ %02d:%02d" % [mins, secs]

func update_stats(pop: int, housing: Vector2i, jobs: int, progress: int):
	lbl_population.text = "👥 Population : %d" % pop
	lbl_housing.text = "🏠 Habitations : %d / %d" % [housing.x, housing.y]
	lbl_jobs.text = "🛠 Métiers : %d" % jobs
	lbl_progress.text = "Progress : %d%%" % progress
	bar_progress.value = progress
