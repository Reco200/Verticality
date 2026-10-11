extends Node3D


const ROPE_SOURCE_OFFSET: float = 0.7

@onready var rope := $Rope
@onready var rope_mesh := $"Rope/Rope Mesh"
@onready var rope_visial_end := $"Hook End/Rope Visual Target"
@onready var hook_end := $"Hook End"


func extend_from_to(source_position: Vector3, target_position: Vector3, target_normal: Vector3) -> void:
	var rope_source_position := source_position
	var source_to_target := target_position - source_position
	if source_to_target.length_squared() > 0.0:
		rope_source_position += source_to_target.normalized() * minf(
			ROPE_SOURCE_OFFSET,
			source_to_target.length() * 0.5
		)
	
	global_position = rope_source_position
	hook_end.global_position = target_position
	_align_hook_end_with_surface(target_normal)
	
	var visual_target_position: Vector3 = _get_visual_target(target_position)
	var distance_to_target = global_position.distance_to(visual_target_position)
	
	rope_mesh.mesh.height = distance_to_target
	rope_mesh.position.z = -distance_to_target / 2
	
	rope.look_at(visual_target_position)


func _align_hook_end_with_surface(target_normal: Vector3) -> void:
	# This function compensates for the possible error of "look_at()" function
	# when model has to look strait up/down.
	
	if target_normal.dot(Vector3.UP) > 0.001 or target_normal.y < 0:
		if target_normal.y > 0:
			hook_end.rotation_degrees.x = -90
		
		elif target_normal.y < 0:
			hook_end.rotation_degrees.x = 90
	
	else:
		hook_end.look_at(hook_end.global_position - target_normal)


func _get_visual_target(default_value: Vector3) -> Vector3:
	# This function is here because it takes some time to load a hook end model, so
	# this functions uses the physical pull target while the visual marker is loading.
	
	if rope_visial_end:
		return rope_visial_end.global_position
	
	else:
		return default_value
