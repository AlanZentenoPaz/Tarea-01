class_name PlayerController
extends CharacterBody3D
## Controlador del personaje.
##
## SEPARACION DE RESPONSABILIDADES
##  - _physics_process(delta): movimiento, gravedad, salto, colisiones y FSM.
##    Corre a tasa fija (60 Hz, project.godot), independiente de los FPS.
##  - _process(delta): solo apariencia (giro del modelo, pose de brazos/piernas,
##    cabeza). Nunca modifica velocity ni position fisica.
##  - La camara (camera_rig.gd) es otro nodo con su propio _process.
##
## USO DE delta (cada magnitud recibe el tiempo UNA sola vez)
##  - velocity.y -= gravity * delta ........ aceleracion (m/s^2) -> velocidad.
##  - move_toward(..., accel * delta) ...... aceleracion horizontal.
##  - move_and_slide() ..................... integra velocity * delta
##    internamente. Por eso velocity NUNCA se multiplica por delta antes.
##  - El impulso de salto (velocity.y = jump_velocity) es una velocidad
##    instantanea: no lleva delta.

signal state_changed(old_state: String, new_state: String, reason: String)
signal test_finished(report: String)

enum State { IDLE, WALK, JUMP }
const STATE_NAMES: Array[String] = ["IDLE", "WALK", "JUMP"]

@export_group("Movimiento")
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var acceleration: float = 45.0
@export var deceleration: float = 55.0
@export var air_acceleration: float = 18.0
@export_group("Salto y gravedad")
@export var jump_velocity: float = 7.5
@export var gravity: float = 22.0
@export var max_fall_speed: float = 40.0
@export_group("Visual y pruebas")
@export var turn_speed: float = 14.0
@export var fall_limit_y: float = -20.0
@export var test_duration_ticks: int = 180

var state: State = State.IDLE
var move_input: Vector2 = Vector2.ZERO
var wish_direction: Vector3 = Vector3.ZERO

@onready var model_pivot: Node3D = $ModelPivot
@onready var visual: HunkVisual = $ModelPivot/HunkModel
@onready var camera_rig: CameraRig = $CameraRig

var _prev_position: Vector3 = Vector3.ZERO
var _curr_position: Vector3 = Vector3.ZERO
var _state_time: float = 0.0
var _test_active: bool = false
var _test_ticks: int = 0
var _test_start_pos: Vector3 = Vector3.ZERO
var _test_start_frames: int = 0
var _test_start_msec: int = 0


func _ready() -> void:
	add_to_group("player")
	model_pivot.top_level = true
	model_pivot.rotation.y = PI  # empieza mirando hacia +Z (hacia el parkour)
	var spawn: Node3D = get_tree().get_first_node_in_group("spawn") as Node3D
	if spawn != null:
		global_position = spawn.global_position
	_snap_visual()
	camera_rig.snap()


# --------------------------------------------------------------------------
# FISICA (tasa fija)
# --------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(&"respawn") or global_position.y < fall_limit_y:
		respawn()
		return

	_read_input()

	var was_on_floor: bool = is_on_floor()

	# 1) Gravedad: aceleracion * delta (una vez) y solo en el aire.
	if not was_on_floor:
		velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)

	# 2) Salto: solo si el cuerpo esta en el suelo. Es un impulso (sin delta).
	var jumped: bool = false
	if Input.is_action_just_pressed(&"jump") and was_on_floor and not _test_active:
		velocity.y = jump_velocity
		jumped = true

	# 3) Movimiento horizontal relativo a la camara (yaw de la camara).
	var target_speed: float = walk_speed
	if Input.is_action_pressed(&"run") and not _test_active:
		target_speed = run_speed
	var cam_basis := Basis(Vector3.UP, camera_rig.yaw)
	wish_direction = cam_basis * Vector3(move_input.x, 0.0, move_input.y)
	if wish_direction.length() > 1.0:
		wish_direction = wish_direction.normalized()
	var target_velocity: Vector3 = wish_direction * target_speed

	var accel: float = air_acceleration
	if was_on_floor:
		accel = acceleration if wish_direction.length() > 0.01 else deceleration
	var horizontal := Vector2(velocity.x, velocity.z)
	horizontal = horizontal.move_toward(Vector2(target_velocity.x, target_velocity.z), accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	# 4) move_and_slide() ya multiplica velocity por delta internamente.
	move_and_slide()

	# 5) Maquina de estados (despues de mover, is_on_floor() ya esta actualizado).
	_update_state(jumped)

	# 6) Guardar posiciones fisicas para interpolar la parte visual.
	_prev_position = _curr_position
	_curr_position = global_position

	# 7) Prueba de desplazamiento (F5).
	_update_test()


func _read_input() -> void:
	if _test_active:
		move_input = Vector2(0.0, -1.0)  # fuerza "adelante" (relativo a la camara)
	else:
		move_input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		if Input.is_action_just_pressed(&"test_move"):
			_start_test()


# --------------------------------------------------------------------------
# FSM: Idle / Walk / Jump con transiciones explicitas
# --------------------------------------------------------------------------
func _update_state(jumped: bool) -> void:
	var on_floor: bool = is_on_floor()
	var has_input: bool = wish_direction.length() > 0.1
	var h_speed: float = Vector2(velocity.x, velocity.z).length()
	var next: State = state
	var reason: String = ""

	match state:
		State.IDLE:
			if jumped:
				next = State.JUMP
				reason = "Espacio en el suelo"
			elif not on_floor:
				next = State.JUMP
				reason = "sin suelo (caida)"
			elif has_input:
				next = State.WALK
				reason = "hay entrada de movimiento"
		State.WALK:
			if jumped:
				next = State.JUMP
				reason = "Espacio en el suelo"
			elif not on_floor:
				next = State.JUMP
				reason = "sin suelo (borde)"
			elif not has_input and h_speed < 0.3:
				next = State.IDLE
				reason = "sin entrada y velocidad ~0"
		State.JUMP:
			if on_floor and not jumped and velocity.y <= 0.1:
				if has_input:
					next = State.WALK
					reason = "aterrizaje con entrada"
				else:
					next = State.IDLE
					reason = "aterrizaje sin entrada"

	if next != state:
		var old_name: String = STATE_NAMES[state]
		state = next
		_state_time = 0.0
		var line: String = "[%.2fs] %s -> %s (%s)" % [Time.get_ticks_msec() / 1000.0, old_name, STATE_NAMES[state], reason]
		print(line)
		state_changed.emit(old_name, STATE_NAMES[state], reason)


# --------------------------------------------------------------------------
# PRUEBA DE DESPLAZAMIENTO CON DOS LIMITES DE RENDER (F5 + F6)
# Duracion medida en ticks de fisica (180 ticks = 3 s a 60 Hz). La distancia
# debe ser casi igual con max_fps = 30 y 144 porque la fisica no depende de
# los cuadros dibujados.
# --------------------------------------------------------------------------
func _start_test() -> void:
	if _test_active:
		return
	_test_active = true
	_test_ticks = 0
	_test_start_pos = global_position
	_test_start_frames = Engine.get_process_frames()
	_test_start_msec = Time.get_ticks_msec()
	print("Prueba iniciada (max_fps=%d)" % Engine.max_fps)


func _update_test() -> void:
	if not _test_active:
		return
	_test_ticks += 1
	if _test_ticks < test_duration_ticks:
		return
	_test_active = false
	var d: Vector3 = global_position - _test_start_pos
	var dist: float = Vector2(d.x, d.z).length()
	var fps_cap: String = "sin limite" if Engine.max_fps == 0 else str(Engine.max_fps)
	var report: String = "PRUEBA %d ticks (%.2f s fisicos) | max_fps=%s | distancia=%.3f m | frames de render=%d | tiempo real=%d ms" % [
		test_duration_ticks,
		float(test_duration_ticks) / float(Engine.physics_ticks_per_second),
		fps_cap,
		dist,
		Engine.get_process_frames() - _test_start_frames,
		Time.get_ticks_msec() - _test_start_msec,
	]
	print(report)
	test_finished.emit(report)


func is_test_active() -> bool:
	return _test_active


# --------------------------------------------------------------------------
# VISUAL (por cuadro de render). No toca la fisica.
# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	_state_time += delta
	model_pivot.global_position = get_visual_position()

	# El modelo gira hacia donde se mueve (suavizado dependiente de delta).
	if wish_direction.length() > 0.1:
		var target_yaw: float = atan2(-wish_direction.x, -wish_direction.z)
		var current_yaw: float = model_pivot.rotation.y
		model_pivot.rotation.y = lerp_angle(current_yaw, target_yaw, 1.0 - exp(-turn_speed * delta))

	# La cabeza mira hacia donde mira la camara (relativo al cuerpo).
	var look_yaw: float = wrapf(camera_rig.yaw - model_pivot.rotation.y, -PI, PI)
	var h_speed: float = Vector2(velocity.x, velocity.z).length()
	visual.update_pose(delta, int(state), h_speed, look_yaw, camera_rig.pitch)


## Posicion para dibujar: interpolacion entre los dos ultimos ticks de fisica.
func get_visual_position() -> Vector3:
	return _prev_position.lerp(_curr_position, Engine.get_physics_interpolation_fraction())


func respawn() -> void:
	var spawn: Node3D = get_tree().get_first_node_in_group("spawn") as Node3D
	if spawn != null:
		global_position = spawn.global_position
	velocity = Vector3.ZERO
	_test_active = false
	_snap_visual()
	camera_rig.snap()
	if state != State.IDLE:
		_change_to_idle()


func _change_to_idle() -> void:
	var old_name: String = STATE_NAMES[state]
	state = State.IDLE
	state_changed.emit(old_name, STATE_NAMES[state], "reaparicion")


func _snap_visual() -> void:
	_prev_position = global_position
	_curr_position = global_position
	model_pivot.global_position = global_position
