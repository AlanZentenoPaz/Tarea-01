extends CanvasLayer
## HUD: muestra el estado activo de la FSM, un registro legible de transiciones
## y el resultado de la prueba de desplazamiento (F5) con el limite de FPS (F6).

const MAX_LOG_LINES: int = 8
const FPS_CAPS: Array[int] = [30, 144]

@onready var state_label: Label = $StateLabel
@onready var log_label: Label = $LogLabel
@onready var help_label: Label = $HelpLabel
@onready var test_label: Label = $TestLabel

var _player: PlayerController = null
var _lines: Array[String] = []
var _fps_index: int = 1


func _ready() -> void:
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player != null:
		_player.state_changed.connect(_on_state_changed)
		_player.test_finished.connect(_on_test_finished)
	Engine.max_fps = FPS_CAPS[_fps_index]
	test_label.text = "F5: prueba 3 s (adelante) | F6: limite de FPS"
	help_label.text = "WASD mover | Shift correr | Espacio saltar | Mouse/flechas camara\nEsc mouse | F5 prueba | F6 limite FPS | R reaparecer | F1 ayuda"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_help"):
		help_label.visible = not help_label.visible
	elif event.is_action_pressed(&"cycle_fps"):
		_fps_index = (_fps_index + 1) % FPS_CAPS.size()
		Engine.max_fps = FPS_CAPS[_fps_index]
		_push_line("Limite de render: %d FPS" % Engine.max_fps)


func _process(_delta: float) -> void:
	if _player == null:
		return
	var h_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var test_text: String = "  [PRUEBA EN CURSO]" if _player.is_test_active() else ""
	state_label.text = "ESTADO: %s%s\nVel. horizontal: %.2f m/s | Vel. vertical: %.2f m/s\nEn suelo: %s\nFPS: %d (limite %d) | fisica: %d Hz" % [
		PlayerController.STATE_NAMES[_player.state],
		test_text,
		h_speed,
		_player.velocity.y,
		"si" if _player.is_on_floor() else "no",
		int(Engine.get_frames_per_second()),
		Engine.max_fps,
		Engine.physics_ticks_per_second,
	]


func _on_state_changed(old_state: String, new_state: String, reason: String) -> void:
	_push_line("%s -> %s  (%s)" % [old_state, new_state, reason])


func _on_test_finished(report: String) -> void:
	test_label.text = report
	_push_line("Prueba terminada: ver resultado abajo")


func _push_line(text: String) -> void:
	var stamp: String = "%6.2f s" % (Time.get_ticks_msec() / 1000.0)
	_lines.append("%s  %s" % [stamp, text])
	while _lines.size() > MAX_LOG_LINES:
		_lines.pop_front()
	log_label.text = "REGISTRO DE ESTADOS\n" + "\n".join(_lines)
