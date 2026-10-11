extends CanvasLayer

const COURSE_TIMES_PATH: String = "user://course_times.txt"

@onready var best_time_label: Label = $BestTime

var _course_scene_path: String


func _ready() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		push_error("HighScore: Could not determine the current course scene.")
		return

	_course_scene_path = current_scene.scene_file_path
	_update_best_time()

	var hook_controller := current_scene.find_child("HookController", true, false) as HookController
	if hook_controller == null:
		push_error("HighScore: Could not find the course HookController.")
		return

	hook_controller.course_time_recorded.connect(_update_best_time)


func _update_best_time() -> void:
	if not FileAccess.file_exists(COURSE_TIMES_PATH):
		best_time_label.text = "BEST  --"
		return

	var file := FileAccess.open(COURSE_TIMES_PATH, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error(
			"HighScore: Could not open %s (error %d)." %
			[COURSE_TIMES_PATH, error]
		)
		best_time_label.text = "BEST  unavailable"
		return

	var best_time := INF
	for line in file.get_as_text().split("\n"):
		var fields := line.strip_edges().split(" | ", false, 2)
		if fields.size() != 3 or fields[1] != _course_scene_path:
			continue

		var duration_text: String = fields[2].trim_suffix(" seconds").strip_edges()
		if duration_text.is_valid_float():
			best_time = minf(best_time, float(duration_text))

	file.close()

	best_time_label.text = (
		"BEST  --"
		if is_inf(best_time)
		else "BEST  %.2f s" % best_time
	)
