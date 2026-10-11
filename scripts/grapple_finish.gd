extends NoGrapple

var _player: CharacterBody3D
var _hook_controller: HookController


func _ready() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		push_error("GrappleFinish: Could not find the current scene.")
		return

	for candidate: Node in scene.find_children("*", "CharacterBody3D", true, false):
		var player := candidate as CharacterBody3D
		var controller := player.find_child("HookController", true, false) as HookController
		if controller != null:
			_player = player
			_hook_controller = controller
			return

	push_error("GrappleFinish: Could not find a player with a HookController.")


func _physics_process(_delta: float) -> void:
	if _player == null or _hook_controller == null:
		return

	if _hook_controller.course_finished or not _hook_controller.reached_halfway:
		return

	if not _player.is_on_floor():
		return

	for collision_index: int in range(_player.get_slide_collision_count()):
		var collision: KinematicCollision3D = _player.get_slide_collision(collision_index)
		if collision.get_collider() != self:
			continue

		if collision.get_normal().dot(_player.up_direction) > cos(_player.floor_max_angle):
			_hook_controller.complete_course()
			return
