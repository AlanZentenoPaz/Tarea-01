class_name CameraRig
extends Node3D
## Camara en tercera persona.
## Jerarquia: CameraRig (yaw) > Pitch (pitch) > SpringArm3D > Camera3D.
##
## - El rig es "top_level": no hereda la rotacion del jugador, por eso el giro
##   de camara es independiente del cuerpo. Su posicion sigue al jugador en
##   _process (actualizacion VISUAL), usando la posicion interpolada.
## - SpringArm3D lanza una forma (esfera) desde el pivote hacia atras; si hay
##   una pared en medio, acorta el brazo y la camara no la atraviesa.
## - Uso de delta: la rotacion por teclado y el suavizado de seguimiento
##   dependen del tiempo, por eso se multiplican por delta. El movimiento del
##   mouse (event.relative) ya es un desplazamiento, NO se multiplica por delta.

@export var follow_height: float = 1.55
@export var mouse_sensitivity: float = 0.0025
@export var key_turn_speed: float = 2.2
@export var follow_smoothing: float = 20.0
@export var min_pitch_degrees: float = -65.0
@export var max_pitch_degrees: float = 35.0
@export var initial_yaw_degrees: float = 180.0
@export var initial_pitch_degrees: float = -14.0

var yaw: float = 0.0
var pitch: float = 0.0

@onready var pitch_node: Node3D = $Pitch
@onready var spring_arm: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D

var _target: PlayerController = null


func _ready() -> void:
	top_level = true
	_target = get_parent() as PlayerController
	yaw = deg_to_rad(initial_yaw_degrees)
	pitch = deg_to_rad(initial_pitch_degrees)
	if _target != null:
		spring_arm.add_excluded_object(_target.get_rid())
		global_position = _target.get_visual_position() + Vector3(0.0, follow_height, 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * mouse_sensitivity
		pitch -= motion.relative.y * mouse_sensitivity
		pitch = clampf(pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	elif event.is_action_pressed(&"toggle_mouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	yaw += Input.get_axis(&"cam_right", &"cam_left") * key_turn_speed * delta
	pitch += Input.get_axis(&"cam_down", &"cam_up") * key_turn_speed * delta
	pitch = clampf(pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	_apply_rotation()
	if _target != null:
		var goal: Vector3 = _target.get_visual_position() + Vector3(0.0, follow_height, 0.0)
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_smoothing * delta))


## Coloca la camara de inmediato sobre el jugador (inicio y reaparicion).
func snap() -> void:
	if _target != null:
		global_position = _target.get_visual_position() + Vector3(0.0, follow_height, 0.0)


func _apply_rotation() -> void:
	rotation.y = yaw
	pitch_node.rotation.x = pitch
