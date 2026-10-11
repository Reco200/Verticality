extends Control

signal back_requested

const COURSE_TIMES_PATH: String = "user://course_times.txt"
const DATA_FONT: FontFile = preload("res://fonts/IBM_Plex_Mono/IBMPlexMono-Light.ttf")
const DATA_COLOR: Color = Color("#00c0df")

@onready var rows: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/Rows
@onready var status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Status


func _ready() -> void:
	if is_visible_in_tree():
		_load_times()


func show_times() -> void:
	_load_times()
	show()


func _load_times() -> void:
	for child in rows.get_children():
		child.queue_free()

	if not FileAccess.file_exists(COURSE_TIMES_PATH):
		status_label.text = "No recorded course times yet."
		return

	var file := FileAccess.open(COURSE_TIMES_PATH, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error("Times: Could not open %s (error %d)." % [COURSE_TIMES_PATH, error])
		status_label.text = "Could not read recorded course times."
		return

	var lines := file.get_as_text().split("\n")
	file.close()

	var record_count := 0
	for index in range(lines.size() - 1, -1, -1):
		var line: String = lines[index].strip_edges()
		if line.is_empty():
			continue

		var fields := line.split(" | ", false, 2)
		if fields.size() != 3:
			push_warning("Times: Ignoring malformed record on line %d." % (index + 1))
			continue

		var duration_text: String = fields[2].trim_suffix(" seconds").strip_edges()
		if not duration_text.is_valid_float():
			push_warning("Times: Ignoring invalid time on line %d." % (index + 1))
			continue

		_add_record(
			_get_course_name(fields[1]),
			_get_recorded_date(fields[0]),
			float(duration_text)
		)
		record_count += 1

	status_label.text = (
		"No recorded course times yet."
		if record_count == 0
		else "%d recorded time(s)" % record_count
	)


func _add_record(course: String, recorded_at: String, seconds: float) -> void:
	_add_cell(course)
	_add_cell(recorded_at)
	_add_cell("%.2f seconds" % seconds)


func _add_cell(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.custom_minimum_size.x = 180
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.theme = theme
	label.add_theme_font_override("font", DATA_FONT)
	label.add_theme_color_override("font_color", DATA_COLOR)
	label.add_theme_font_size_override("font_size", 22)
	rows.add_child(label)


func _get_course_name(scene_path: String) -> String:
	var scene_name := scene_path.get_file().get_basename()
	match scene_name:
		"L_Main":
			return "Level 1"
		_:
			return scene_name.replace("_", " ")


func _get_recorded_date(recorded_at: String) -> String:
	var date_text: String = recorded_at.split("T", false, 1)[0]
	var date_parts: PackedStringArray = date_text.split("-", false, 2)
	if date_parts.size() != 3:
		return recorded_at

	for part in date_parts:
		if not part.is_valid_int():
			return recorded_at

	var year: int = int(date_parts[0])
	var month: int = int(date_parts[1])
	var day: int = int(date_parts[2])
	return "%d/%d/%02d" % [month, day, year % 100]


func _on_back_pressed() -> void:
	hide()
	back_requested.emit()
