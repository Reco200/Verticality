extends RefCounted

const COURSE_TIMES_PATH: String = "user://course_times.txt"
const WEB_STORAGE_KEY: String = "verticality.course_times.v1"


static func read_text() -> Dictionary:
	if OS.has_feature("web"):
		var result: Variant = JavaScriptBridge.eval(
			"(function(){try{return JSON.stringify({ok:true,value:localStorage.getItem(%s)});}catch(e){return JSON.stringify({ok:false,error:String(e)});}})()" %
			JSON.stringify(WEB_STORAGE_KEY)
		)
		if typeof(result) != TYPE_STRING:
			push_error("CourseTimeStore: Could not read course times from browser storage.")
			return {"ok": false, "exists": false, "text": ""}

		var parsed: Variant = JSON.parse_string(result)
		if not parsed is Dictionary or not parsed.get("ok", false):
			push_error(
				"CourseTimeStore: Could not read course times from browser storage: %s" %
				(parsed.get("error", "unknown error") if parsed is Dictionary else "invalid response")
			)
			return {"ok": false, "exists": false, "text": ""}

		var value: Variant = parsed.get("value")
		if value == null and FileAccess.file_exists(COURSE_TIMES_PATH):
			var legacy_file := FileAccess.open(COURSE_TIMES_PATH, FileAccess.READ)
			if legacy_file == null:
				push_error(
					"CourseTimeStore: Could not open legacy %s (error %d)." %
					[COURSE_TIMES_PATH, FileAccess.get_open_error()]
				)
				return {"ok": false, "exists": false, "text": ""}

			var legacy_text := legacy_file.get_as_text()
			legacy_file.close()
			if not _write_web_text(legacy_text):
				return {"ok": false, "exists": false, "text": ""}
			return {"ok": true, "exists": true, "text": legacy_text}

		return {
			"ok": true,
			"exists": value != null,
			"text": value if value is String else ""
		}

	if not FileAccess.file_exists(COURSE_TIMES_PATH):
		return {"ok": true, "exists": false, "text": ""}

	var file := FileAccess.open(COURSE_TIMES_PATH, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error(
			"CourseTimeStore: Could not open %s (error %d)." %
			[COURSE_TIMES_PATH, error]
		)
		return {"ok": false, "exists": false, "text": ""}

	var text := file.get_as_text()
	file.close()
	return {"ok": true, "exists": true, "text": text}


static func append_record(record: String) -> bool:
	if OS.has_feature("web"):
		var stored: Dictionary = read_text()
		if not stored.ok:
			return false

		return _write_web_text(stored.text + record + "\n")

	var mode := (
		FileAccess.READ_WRITE
		if FileAccess.file_exists(COURSE_TIMES_PATH)
		else FileAccess.WRITE
	)
	var file := FileAccess.open(COURSE_TIMES_PATH, mode)
	if file == null:
		push_error(
			"CourseTimeStore: Could not open %s for writing (error %d)." %
			[COURSE_TIMES_PATH, FileAccess.get_open_error()]
		)
		return false

	file.seek_end()
	file.store_line(record)
	file.close()
	return true


static func _write_web_text(text: String) -> bool:
	var result: Variant = JavaScriptBridge.eval(
		"(function(){try{localStorage.setItem(%s,%s);return true;}catch(e){console.error('Could not save course times:',e);return false;}})()" %
		[JSON.stringify(WEB_STORAGE_KEY), JSON.stringify(text)]
	)
	if result != true:
		push_error("CourseTimeStore: Could not save course times to browser storage.")
		return false
	return true
