extends CanvasLayer

const CourseTimeStore = preload("res://scripts/course_time_store.gd")

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
	var result: Dictionary = CourseTimeStore.read_text()
	if not result.ok:
		best_time_label.text = "BEST  unavailable"
		return

	if not result.exists:
		best_time_label.text = "BEST  --"
		return

	var best_time := INF
	for line in result.text.split("\n"):
		var fields := line.strip_edges().split(" | ", false, 2)
		if fields.size() != 3 or fields[1] != _course_scene_path:
			continue

		var duration_text: String = fields[2].trim_suffix(" seconds").strip_edges()
		if duration_text.is_valid_float():
			best_time = minf(best_time, float(duration_text))

	best_time_label.text = (
		"BEST  --"
		if is_inf(best_time)
		else "BEST  %.2f s" % best_time
	)
