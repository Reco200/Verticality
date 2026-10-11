class_name HookController
extends Node
## Node that is responsible for managing the hook, and the hook interface.

@export_category("Hook Controller")
@export_group("Required Settings")

@onready var hook_raycast: RayCast3D = get_parent().find_child("RayCast3D", true, false) as RayCast3D
@onready var player_body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var player_camera: Camera3D = _find_player_camera()

@export var launch_action_name: String
@export var retract_action_name: String

@export_group("Optional Settings")
@export var pull_speed: float = 1.0

@export var hook_source: Node3D

@export_group("Advanced Settings")
@export_range(5.0, 1000.0, 0.5) var hook_range: float = 25.0
@export var hook_scene: PackedScene = preload("res://addons/grappling_hook_3d/src/hook.tscn")

@export var finish_shape: CollisionShape3D



var is_hook_launched: bool = false
var _hook_model: Node3D = null
var hook_target_normal: Vector3 = Vector3.ZERO
var hook_target_node: Marker3D = null

var reached_halfway: bool = false
var course_finished: bool = false

signal hook_launched()
signal hook_attached(body)
signal hook_detached()
signal course_time_recorded()

var timer_started: bool = false
var elapsed_time: float = 0.0

const COURSE_TIMES_PATH: String = "user://course_times.txt"

func _ready() -> void:
	if hook_raycast == null:
		push_error("HookController: Could not find a RayCast3D anywhere inside the Player.")

	if player_body == null:
		push_error("HookController: HookController must be a child of a CharacterBody3D.")

	if player_camera == null:
		push_error("HookController: Could not find a Camera3D anywhere inside the Player.")

	_align_raycast_to_camera()


func _find_player_camera() -> Camera3D:
	var cameras: Array[Node] = get_parent().find_children("*", "Camera3D", true, false)
	if cameras.is_empty():
		return null
	return cameras[0] as Camera3D


func _physics_process(delta: float) -> void:
	_align_raycast_to_camera()

	# Run the timer while the course is active.
	if timer_started and not course_finished:
		elapsed_time += delta

	if launch_action_name.is_empty():
		return

	# Only launch/retract when the grapple button is pressed.
	if Input.is_action_just_pressed(launch_action_name):
		hook_launched.emit()

		if is_hook_launched:
			_retract_hook()
		else:
			_launch_hook()

	# Keep grappling while the hook is attached.
	if is_hook_launched:
		_handle_hook(delta)

func complete_course() -> void:
	if course_finished or not timer_started or not reached_halfway:
		return

	course_finished = true
	print("Course completed")
	print("Time: %.2f seconds" % elapsed_time)
	if _log_course_time():
		course_time_recorded.emit()


func _log_course_time() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		push_error("HookController: Could not determine the current scene for the course time.")
		return false

	var mode: int = (
		FileAccess.READ_WRITE
		if FileAccess.file_exists(COURSE_TIMES_PATH)
		else FileAccess.WRITE
	)
	var file: FileAccess = FileAccess.open(COURSE_TIMES_PATH, mode)
	if file == null:
		push_error(
			"HookController: Could not open %s for writing (error %d)." %
			[COURSE_TIMES_PATH, FileAccess.get_open_error()]
		)
		return false

	file.seek_end()
	var date: Dictionary = Time.get_date_dict_from_system()
	file.store_line(
		"%s | %s | %.2f seconds" %
		[
			"%d/%d/%02d" % [date.month, date.day, date.year % 100],
			scene.scene_file_path,
			elapsed_time
		]
	)
	file.close()
	return true


func _align_raycast_to_camera() -> void:
	if hook_raycast == null or player_camera == null:
		return

	hook_raycast.global_transform = player_camera.global_transform
	hook_raycast.target_position = Vector3(0.0, 0.0, -hook_range)
	hook_raycast.enabled = true


func _launch_hook() -> void:
	if hook_raycast == null:
		return

	_align_raycast_to_camera()
	hook_raycast.force_raycast_update()

	if not hook_raycast.is_colliding():
		return

	var body: CollisionObject3D = hook_raycast.get_collider() as CollisionObject3D

	if body == null:
		return
		
	if body is NoGrapple:
		return	

	if course_finished:
		timer_started = false
		elapsed_time = 0.0
		reached_halfway = false
		course_finished = false

	# A body marked with GrappleHalfway is the course halfway target.
	if body is GrappleHalfway:
		reached_halfway = true
		print("halfway point reached")
	elif finish_shape != null:
		# Preserve support for scenes that configure a specific finish shape.
		var shape_index: int = hook_raycast.get_collider_shape()
		var owner_id: int = body.shape_find_owner(shape_index)

		if owner_id != -1:
			var hit_shape: CollisionShape3D = body.shape_owner_get_owner(owner_id) as CollisionShape3D

			if hit_shape == finish_shape:
				reached_halfway = true
				print("halfway point reached")

	is_hook_launched = true
	hook_attached.emit(body)

	if not timer_started:
		timer_started = true
		elapsed_time = 0.0
		print("timer started")

	hook_target_node = Marker3D.new()
	body.add_child(hook_target_node)

	hook_target_node.global_position = hook_raycast.get_collision_point()
	hook_target_normal = hook_raycast.get_collision_normal()

	if hook_scene:
		_hook_model = hook_scene.instantiate() as Node3D
		if _hook_model:
			add_child(_hook_model)

func _retract_hook() -> void:
	is_hook_launched = false

	if is_instance_valid(hook_target_node):
		hook_target_node.queue_free()

	hook_target_node = null

	if is_instance_valid(_hook_model):
		_hook_model.queue_free()

	_hook_model = null

	hook_detached.emit()


func _handle_hook(delta: float) -> void:
	if not is_instance_valid(hook_target_node) or not is_instance_valid(player_body):
		_retract_hook()
		return

	var pull_vector: Vector3 = (
		hook_target_node.global_position - player_body.global_position
	).normalized()

	var hook_force: Vector3 = pull_vector * pull_speed * delta * 60.0

	var max_upward_force: float = 3.0

	if hook_force.y > max_upward_force:
		hook_force.y = max_upward_force

	player_body.velocity += hook_force

	if not is_instance_valid(_hook_model):
		return

	var source_position: Vector3

	if hook_source:
		source_position = hook_source.global_position
	else:
		source_position = player_body.global_position

	_hook_model.extend_from_to(
		source_position,
		hook_target_node.global_position,
		hook_target_normal
	)
