class_name HunkVisual
extends Node3D
## Apariencia del personaje (escena envolvente de hunk.glb).
##
## El controlador (player.gd) NO depende de este script: solo le pasa el estado
## y la velocidad una vez por cuadro. Aqui se mueven los huesos del esqueleto
## de forma procedural (brazos, piernas, torso y cabeza). Los clips definitivos
## se hacen en la Tarea 2.
##
## Como funciona (independiente de los ejes del archivo):
##  1. Se calculan los ejes del personaje en el espacio del esqueleto a partir
##     de la pose de reposo: izquierda = clavicula_izq - clavicula_der,
##     arriba = cabeza - cadera, adelante = izquierda x arriba.
##  2. Para cada hueso se define una rotacion "delta" en ese espacio y se
##     convierte a la pose local:  local = inverso(global_padre) * delta * reposo.
##  3. Los huesos se procesan de padre a hijo.
## El modelo viene en T-pose: los brazos se bajan a una pose en A.

@export var arm_down_degrees: float = 68.0
@export var leg_swing_degrees: float = 32.0
@export var knee_bend_degrees: float = 55.0
@export var arm_swing_degrees: float = 30.0
@export var step_rate: float = 2.0
@export var pose_blend_speed: float = 9.0
@export var head_follow_speed: float = 12.0
@export var max_head_yaw_degrees: float = 80.0
@export var max_head_pitch_degrees: float = 35.0

const BONE_PREFIXES: Dictionary = {
	"hips": "hips_0",
	"spine1": "spine_1_0",
	"spine2": "spine_2_0",
	"neck0": "neck_0_0",
	"neck1": "neck_1_0",
	"head": "head_0",
	"l_clav": "l_arm_clavicle_0",
	"r_clav": "r_arm_clavicle_0",
	"l_hum": "l_arm_humerus_0",
	"r_hum": "r_arm_humerus_0",
	"l_rad": "l_arm_radius_0",
	"r_rad": "r_arm_radius_0",
	"l_fem": "l_leg_femur_0",
	"r_fem": "r_leg_femur_0",
	"l_tib": "l_leg_tibia_0",
	"r_tib": "r_leg_tibia_0",
	"l_ank": "l_leg_ankle_0",
	"r_ank": "r_leg_ankle_0",
}

var skeleton: Skeleton3D = null
var bone_ids: Dictionary = {}

var _lateral: Vector3 = Vector3.RIGHT   # hacia la izquierda del personaje
var _up: Vector3 = Vector3.UP
var _forward: Vector3 = Vector3.BACK
var _right: Vector3 = Vector3.LEFT
var _leg_length: float = 1.0
var _ok: bool = false

var _time: float = 0.0
var _phase: float = 0.0
var _walk_blend: float = 0.0
var _air_blend: float = 0.0
var _head_yaw: float = 0.0
var _head_pitch: float = 0.0


func _ready() -> void:
	var found: Array[Node] = find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_warning("HunkVisual: no se encontro Skeleton3D dentro de hunk.glb")
		return
	skeleton = found[0] as Skeleton3D
	for key in BONE_PREFIXES.keys():
		var idx: int = _find_bone(String(BONE_PREFIXES[key]))
		if idx < 0:
			push_warning("HunkVisual: hueso no encontrado para '%s'" % String(key))
		bone_ids[key] = idx
	for required in ["hips", "head", "l_clav", "r_clav", "l_fem", "l_ank"]:
		if int(bone_ids[required]) < 0:
			push_warning("HunkVisual: falta un hueso esencial, se desactiva la pose procedural")
			return
	_compute_axes()
	_ok = true


func _find_bone(prefix: String) -> int:
	for i in range(skeleton.get_bone_count()):
		var bone_name: String = skeleton.get_bone_name(i)
		if bone_name.begins_with(prefix) and not bone_name.contains("scaleCompensation"):
			return i
	return -1


func _rest_origin(key: String) -> Vector3:
	return skeleton.get_bone_global_rest(int(bone_ids[key])).origin


func _compute_axes() -> void:
	_lateral = (_rest_origin("l_clav") - _rest_origin("r_clav")).normalized()
	var up_raw: Vector3 = (_rest_origin("head") - _rest_origin("hips")).normalized()
	_up = (up_raw - _lateral * up_raw.dot(_lateral)).normalized()
	_forward = _lateral.cross(_up).normalized()
	_right = -_lateral
	_leg_length = (_rest_origin("l_fem") - _rest_origin("l_ank")).length()


# Rotaciones en el espacio del esqueleto -----------------------------------
## Angulo positivo: una extremidad que cuelga se balancea hacia ADELANTE
## (y la cabeza mira hacia ARRIBA).
func _swing(angle: float) -> Basis:
	return Basis(Quaternion(_right, angle))


## Angulo positivo: gira hacia la IZQUIERDA del personaje.
func _yaw(angle: float) -> Basis:
	return Basis(Quaternion(_up, angle))


## Baja el brazo desde la T-pose (el brazo izquierdo apunta a +lateral).
func _arm_down(is_left: bool) -> Basis:
	var a: float = deg_to_rad(arm_down_degrees)
	if is_left:
		return Basis(Quaternion(-_forward, a))
	return Basis(Quaternion(_forward, a))


## Fija la orientacion global de un hueso como (delta * orientacion de reposo).
func _pose_bone(key: String, delta_basis: Basis) -> void:
	var idx: int = int(bone_ids.get(key, -1))
	if idx < 0:
		return
	var rest_global: Transform3D = skeleton.get_bone_global_rest(idx)
	var parent_basis: Basis = Basis.IDENTITY
	var parent: int = skeleton.get_bone_parent(idx)
	if parent >= 0:
		parent_basis = skeleton.get_bone_global_pose(parent).basis
	var desired: Basis = (delta_basis * rest_global.basis).orthonormalized()
	var local_basis: Basis = parent_basis.orthonormalized().inverse() * desired
	skeleton.set_bone_pose_rotation(idx, local_basis.get_rotation_quaternion())


## Baja la cadera para que los pies sigan tocando el suelo al abrir las piernas.
func _set_hips_drop(drop: float) -> void:
	var idx: int = int(bone_ids["hips"])
	var rest_local: Transform3D = skeleton.get_bone_rest(idx)
	var parent_basis: Basis = Basis.IDENTITY
	var parent: int = skeleton.get_bone_parent(idx)
	if parent >= 0:
		parent_basis = skeleton.get_bone_global_pose(parent).basis
	var offset: Vector3 = parent_basis.inverse() * (-_up * drop)
	skeleton.set_bone_pose_position(idx, rest_local.origin + offset)


## Llamado por el jugador una vez por cuadro de render.
## state: 0 = Idle, 1 = Walk, 2 = Jump.
## look_yaw / look_pitch: hacia donde mira la camara respecto al cuerpo (rad).
func update_pose(delta: float, state: int, ground_speed: float, look_yaw: float, look_pitch: float) -> void:
	if not _ok:
		return
	_time += delta
	var walking: bool = state == 1
	var airborne: bool = state == 2
	_walk_blend = move_toward(_walk_blend, 1.0 if walking else 0.0, pose_blend_speed * delta)
	_air_blend = move_toward(_air_blend, 1.0 if airborne else 0.0, pose_blend_speed * delta)
	if walking:
		_phase = fmod(_phase + delta * ground_speed * step_rate, TAU)

	var s: float = sin(_phase)
	var c: float = cos(_phase)
	var speed_scale: float = clampf(ground_speed / 5.0, 0.6, 1.4)
	var air_w: float = _air_blend

	# Piernas -------------------------------------------------------------
	var leg_amp: float = deg_to_rad(leg_swing_degrees) * speed_scale * _walk_blend
	var knee_max: float = deg_to_rad(knee_bend_degrees) * _walk_blend
	var thigh_l: float = lerpf(leg_amp * s, deg_to_rad(38.0), air_w)
	var thigh_r: float = lerpf(-leg_amp * s, deg_to_rad(-18.0), air_w)
	var knee_l: float = lerpf(knee_max * maxf(0.0, c), deg_to_rad(60.0), air_w)
	var knee_r: float = lerpf(knee_max * maxf(0.0, -c), deg_to_rad(30.0), air_w)

	# Brazos (opuestos a las piernas) ---------------------------------------
	var arm_amp: float = deg_to_rad(arm_swing_degrees) * speed_scale * _walk_blend
	var arm_l: float = lerpf(-arm_amp * s, deg_to_rad(40.0), air_w)
	var arm_r: float = lerpf(arm_amp * s, deg_to_rad(40.0), air_w)
	var elbow_base: float = deg_to_rad(12.0)
	var elbow_walk: float = deg_to_rad(32.0) * _walk_blend
	var elbow_l: float = lerpf(elbow_base + elbow_walk * maxf(0.0, -s), deg_to_rad(55.0), air_w)
	var elbow_r: float = lerpf(elbow_base + elbow_walk * maxf(0.0, s), deg_to_rad(55.0), air_w)

	# Torso -----------------------------------------------------------------
	var lean: float = deg_to_rad(5.0) * speed_scale * _walk_blend + deg_to_rad(4.0) * air_w
	var breath: float = sin(_time * 1.8) * deg_to_rad(0.7) * (1.0 - _walk_blend)
	var twist: float = deg_to_rad(7.0) * _walk_blend * s

	# Cabeza (sigue a la camara, suavizada con delta) ------------------------
	var yaw_limit: float = deg_to_rad(max_head_yaw_degrees)
	var pitch_limit: float = deg_to_rad(max_head_pitch_degrees)
	var k: float = 1.0 - exp(-head_follow_speed * delta)
	_head_yaw = lerpf(_head_yaw, clampf(look_yaw, -yaw_limit, yaw_limit), k)
	_head_pitch = lerpf(_head_pitch, clampf(look_pitch * 0.6, -pitch_limit, pitch_limit), k)

	# Aplicar de padre a hijo ------------------------------------------------
	var drop: float = _leg_length * (1.0 - cos(leg_amp * absf(s))) * 0.9
	_set_hips_drop(drop)
	_pose_bone("spine1", _swing(-(lean * 0.5 + breath)) * _yaw(twist * 0.4))
	_pose_bone("spine2", _swing(-(lean * 0.8 + breath)) * _yaw(twist * 0.8))
	_pose_bone("neck0", _yaw(_head_yaw * 0.25) * _swing(_head_pitch * 0.2))
	_pose_bone("neck1", _yaw(_head_yaw * 0.5) * _swing(_head_pitch * 0.5))
	_pose_bone("head", _yaw(_head_yaw) * _swing(_head_pitch))

	_pose_bone("l_fem", _swing(thigh_l))
	_pose_bone("l_tib", _swing(thigh_l - knee_l))
	_pose_bone("l_ank", _swing(-0.3 * air_w))
	_pose_bone("r_fem", _swing(thigh_r))
	_pose_bone("r_tib", _swing(thigh_r - knee_r))
	_pose_bone("r_ank", _swing(-0.3 * air_w))

	_pose_bone("l_hum", _swing(arm_l) * _arm_down(true))
	_pose_bone("l_rad", _swing(arm_l + elbow_l) * _arm_down(true))
	_pose_bone("r_hum", _swing(arm_r) * _arm_down(false))
	_pose_bone("r_rad", _swing(arm_r + elbow_r) * _arm_down(false))
