extends Control

func _ready() -> void:
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"escape") and not event.is_echo():
		if get_tree().paused:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()

func resume():
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hide()

func pause(): 
	show()
	$PanelContainer.show()
	$Times.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

func _on_button_pressed() -> void:
	resume()


func _on_button_2_pressed() -> void:
	$PanelContainer.hide()
	$Times.show_times()

func _on_times_back_requested() -> void:
	$Times.hide()
	$PanelContainer.show()


func _on_button_3_pressed() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Levels/Main/UI/control.tscn")
