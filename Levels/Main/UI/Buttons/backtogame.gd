extends Button

signal back_requested

func _on_pressed() -> void:
	back_requested.emit()
