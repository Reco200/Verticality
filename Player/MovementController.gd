extends CharacterBody3D
class_name MovementController

@export var gravity_multiplier := 5
@export var speed := 30.0
@export var acceleration := 10.0
@export var deceleration := 12.0
@export_range(0.0, 1.0, 0.05) var air_control := 0.5
@export var max_air_speed := 6.0
@export var jump_height := 20

var direction := Vector3.ZERO
var input_axis := Vector2.ZERO

@onready var gravity: float = (
	ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_multiplier
)


func _physics_process(delta: float) -> void:
	input_axis = Input.get_vector(
		&"move_back",
		&"move_forward",
		&"move_left",
		&"move_right"
	)

	direction_input()

	if is_on_floor():
		if Input.is_action_just_pressed(&"jump"):
			velocity.y = jump_height
	else:
		velocity.y -= gravity * delta

	accelerate(delta)
	move_and_slide()


func direction_input() -> void:
	direction = Vector3.ZERO
	var aim: Basis = global_transform.basis
	direction = aim.z * -input_axis.x + aim.x * input_axis.y

	if direction.length_squared() > 1.0:
		direction = direction.normalized()


func accelerate(delta: float) -> void:
	var temp_vel: Vector3 = velocity
	temp_vel.y = 0.0

	var temp_accel: float
	var target: Vector3 = direction * speed

	if direction.dot(temp_vel) > 0.0:
		temp_accel = acceleration
	else:
		temp_accel = deceleration

	# Less movement control while airborne.
	if not is_on_floor():
		temp_accel *= air_control

	var accel_weight: float = clampf(temp_accel * delta, 0.0, 1.0)

	temp_vel = temp_vel.lerp(target, accel_weight)

	# Gradually slow down when exceeding the air-speed cap.
	if not is_on_floor():
		var air_speed_cap: float = self.max_air_speed
		var air_slowdown: float = 1.0

		var horizontal_velocity: Vector3 = Vector3(
			temp_vel.x,
			0.0,
			temp_vel.z
		)

		var horizontal_speed: float = horizontal_velocity.length()

		if horizontal_speed > air_speed_cap:
			var new_speed: float = move_toward(
				horizontal_speed,
				air_speed_cap,
				air_slowdown * delta
			)

			horizontal_velocity = horizontal_velocity.normalized() * new_speed

			temp_vel.x = horizontal_velocity.x
			temp_vel.z = horizontal_velocity.z

	velocity.x = temp_vel.x
	velocity.z = temp_vel.z
