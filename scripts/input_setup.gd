extends Node
## Autoload. Registra las acciones de entrada por codigo (teclas fisicas),
## asi el proyecto no depende de la serializacion de project.godot.
##
## Controles:
##   W A S D ........ mover (relativo a la camara)
##   Shift .......... correr
##   Espacio ........ saltar (solo en el suelo)
##   Mouse / flechas  girar camara
##   Esc ............ liberar / capturar el mouse
##   F5 ............. prueba de desplazamiento (3 s fisicos)
##   F6 ............. alternar limite de render (30 / 144 FPS)
##   R .............. reaparecer
##   F1 ............. mostrar / ocultar ayuda


func _init() -> void:
	_add_action(&"move_forward", [KEY_W])
	_add_action(&"move_back", [KEY_S])
	_add_action(&"move_left", [KEY_A])
	_add_action(&"move_right", [KEY_D])
	_add_action(&"jump", [KEY_SPACE])
	_add_action(&"run", [KEY_SHIFT])
	_add_action(&"cam_left", [KEY_LEFT])
	_add_action(&"cam_right", [KEY_RIGHT])
	_add_action(&"cam_up", [KEY_UP])
	_add_action(&"cam_down", [KEY_DOWN])
	_add_action(&"toggle_mouse", [KEY_ESCAPE])
	_add_action(&"test_move", [KEY_F5])
	_add_action(&"cycle_fps", [KEY_F6])
	_add_action(&"respawn", [KEY_R])
	_add_action(&"toggle_help", [KEY_F1])


func _add_action(action_name: StringName, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.5)
	for k in keys:
		var code: int = k
		var ev := InputEventKey.new()
		ev.physical_keycode = code as Key
		InputMap.action_add_event(action_name, ev)
