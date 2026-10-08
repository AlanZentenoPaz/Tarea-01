# Parkour con Hunk · Escena base y modelo en Godot 4.x

> **Tarea 1** · Trabajo individual · Godot 4.x · 100 puntos

Una escena 3D controlable en tercera persona: un personaje con esqueleto (*Hunk*) recorre una calle industrial de estilo
low poly ampliada con un circuito de parkour (escaleras, plataformas, pilares, cajas, muros bajos y barriles). El proyecto
está pensado para entender, y poder explicar, **cómo se separan el movimiento, la física, la cámara y la apariencia**.

| | |
|---|---|
| **Motor** | Godot 4.2 o superior (diseñado con *Forward+*; compatible con 4.3 y 4.4) |
| **Lenguaje** | GDScript |
| **Escena principal** | `scenes/Main.tscn` |
| **Complementos de terceros** | Ninguno |
| **Reporte (PDF)** | `docs/Tarea1_Reporte.pdf` |
| **Video de demostración** | (https://drive.google.com/file/d/1NU_o8MFLmxKDkOe4eb_czuQ9ZIR6If34/view?usp=sharing ) |

---

## Contenido

1. [Inicio rápido](#1-inicio-rápido)
2. [Controles](#2-controles)
3. [Estructura del proyecto](#3-estructura-del-proyecto)
4. [Cómo funciona](#4-cómo-funciona)
5. [Pruebas de aceptación](#5-pruebas-de-aceptación)
6. [Parámetros ajustables](#6-parámetros-ajustables)
7. [Limitaciones conocidas](#7-limitaciones-conocidas)
8. [Procedencia, licencias y créditos](#8-procedencia-licencias-y-créditos)

---

## 1. Inicio rápido

1. Abre Godot, pulsa **Importar** y selecciona el archivo `project.godot`.
2. **Espera a que termine la primera importación.** Godot procesa `hunk.glb` (≈ 43 MB, unos 120 000 triángulos y 15 texturas)
   y puede tardar un par de minutos la primera vez.
3. Pulsa **F5** (o el botón ▶) para ejecutar la escena principal.
4. El mouse queda capturado para controlar la cámara; **Esc** lo libera.

> Si abres una copia del proyecto en otra carpeta, no hace falta copiar la carpeta oculta `.godot/`: Godot la regenera sola.

## 2. Controles

| Acción | Tecla | Detalle |
|---|---|---|
| Mover | `W` `A` `S` `D` | Relativo al giro actual de la cámara |
| Correr | `Shift` (mantener) | 8 m/s en lugar de 5 m/s |
| Saltar | `Espacio` | Solo si el personaje está en el suelo |
| Girar la cámara | Mouse o flechas | Cabeceo limitado entre −65° y +35° |
| Liberar / capturar el mouse | `Esc` | |
| Prueba de desplazamiento | `F5` | Camina 180 ticks de física (3 s) y reporta la distancia |
| Límite de render | `F6` | Alterna entre 30 y 144 FPS (inicia en 144) |
| Reaparecer | `R` | También ocurre al caer por debajo de y = −20 |
| Mostrar / ocultar ayuda | `F1` | |

> Dentro del juego, `F5` es la prueba de desplazamiento; para ejecutar el proyecto desde el editor usa el botón ▶.

Las acciones se registran por código en el autoload `scripts/input_setup.gd`, por lo que no dependen del *Input Map* del editor.

El **HUD** muestra el estado activo de la máquina de estados, las velocidades horizontal y vertical, si el personaje está
en el suelo, los FPS, el límite de render, la frecuencia de física y un registro con las últimas transiciones
(también impreso en la consola).

---

## 3. Estructura del proyecto

```text
project.godot
scenes/
├─ Main.tscn         Nivel + jugador + HUD
├─ Level.tscn        Entorno, luz, escenario, colisiones y parkour
├─ Player.tscn       CharacterBody3D, cámara y envoltorio del modelo
├─ HunkModel.tscn    Escena envolvente de hunk.glb (apariencia)
└─ HUD.tscn          Interfaz de depuración
scripts/
├─ player.gd         Entrada, física, FSM, prueba de desplazamiento
├─ camera_rig.gd     Cámara en tercera persona con SpringArm3D
├─ hunk_visual.gd    Pose procedural del esqueleto
├─ hud.gd            Estado, registro y resultados
└─ input_setup.gd    Autoload con las acciones de teclado
models/              hunk.glb · low_poly_street_gameready_6.glb
textures/            crate.png · concrete.png · barrel.png
docs/                FICHA_MODELOS.md · Tarea1_Reporte.pdf · reporte/ (script del PDF)
Prompts/             BITACORA.md
```

**Árbol de nodos principal**

```text
Main (Node3D)
├─ Level   (Level.tscn)
│   ├─ WorldEnvironment        cielo procedural
│   ├─ Sun                     DirectionalLight3D con sombras
│   ├─ Street                  instancia del .glb (escala ×2)
│   ├─ SpawnPoint              Marker3D, grupo "spawn"
│   ├─ Colliders               StaticBody3D + CollisionShape3D (suelo, límites, obstáculos)
│   └─ Parkour                 escaleras, plataformas, pilares, cajas, muros, barriles
├─ Player  (Player.tscn)
│   ├─ CollisionShape3D        cápsula r = 0.35 m, h = 1.8 m
│   ├─ ModelPivot              top_level, solo visual
│   │   └─ HunkModel           hunk_visual.gd
│   │       └─ Model           instancia de hunk.glb
│   └─ CameraRig               camera_rig.gd, top_level
│       └─ Pitch ─ SpringArm3D ─ Camera3D
└─ HUD     (HUD.tscn)
```

El controlador (`player.gd`) **no conoce el modelo**: solo le entrega el estado y la velocidad a `HunkModel` una vez por cuadro.
Se puede sustituir `hunk.glb` por otro personaje sin tocar la lógica de movimiento.

---

## 4. Cómo funciona

### 4.1 Movimiento, física y tiempo (`delta`)

El código separa dos mundos que corren a ritmos distintos:

| Función | Ritmo | Qué hace |
|---|---|---|
| `_physics_process(delta)` | Paso fijo, 60 Hz | Lee la entrada, aplica gravedad y salto, mueve el cuerpo, resuelve colisiones y actualiza la FSM |
| `_process(delta)` | Un cuadro de render | Gira el modelo, calcula la pose, mueve la cabeza y sigue con la cámara. **Nunca** toca `velocity` ni la posición física |

**Dónde se usa `delta` y dónde no.** Cada magnitud recibe el tiempo una sola vez:

```gdscript
# Gravedad: aceleración (m/s²) × delta = cambio de velocidad. Solo en el aire.
velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)

# Salto: es una velocidad instantánea, no una tasa. Sin delta. Solo en el suelo.
if Input.is_action_just_pressed(&"jump") and was_on_floor:
    velocity.y = jump_velocity

# Aceleración horizontal: aceleración × delta.
horizontal = horizontal.move_toward(objetivo, accel * delta)

# move_and_slide() ya integra velocity × delta internamente:
# la velocidad NO se vuelve a multiplicar por delta.
move_and_slide()
```

El movimiento del mouse (`event.relative`) tampoco se multiplica por `delta`, porque ya es un desplazamiento y no una velocidad;
en cambio, el giro con flechas y los suavizados exponenciales (`1 − exp(−k·delta)`) sí dependen del tiempo.

**Movimiento relativo a la cámara.** La entrada 2D se convierte en una dirección 3D girada por el *yaw* de la cámara:

```gdscript
var cam_basis := Basis(Vector3.UP, camera_rig.yaw)
wish_direction = cam_basis * Vector3(move_input.x, 0.0, move_input.y)
```

**Interpolación visual.** Con física a 60 Hz y render a 144 FPS, dibujar directamente la posición del cuerpo produciría tirones.
Al final de cada tick se guardan la posición previa y la actual, y `_process` dibuja en
`prev.lerp(curr, Engine.get_physics_interpolation_fraction())`. La cámara usa esa misma posición.

### 4.2 Cámara y paredes

La jerarquía es `CameraRig → Pitch → SpringArm3D → Camera3D`.

- El rig es **`top_level`**: no hereda la rotación del cuerpo, así que girar la cámara no gira al personaje.
- El **`SpringArm3D`** mide 4.6 m y lanza una esfera de 0.3 m de radio hacia atrás contra la capa 1 (“mundo”).
  Si hay una pared en medio, el brazo se acorta y la cámara se queda delante de ella.
- El cuerpo del jugador se excluye del brazo (`add_excluded_object`) para que no choque consigo mismo.
- No se utiliza ningún complemento de cámara.

### 4.3 Máquina de estados (Idle · Walk · Jump)

```text
                 hay entrada
        ┌────────────────────────────►┐
      IDLE                          WALK
        └◄────────────────────────────┘
        sin entrada y velocidad < 0.3 m/s

   IDLE / WALK ──(Espacio en suelo, o se pierde el suelo)──► JUMP
   JUMP ──(aterriza con entrada)──► WALK
   JUMP ──(aterriza sin entrada)──► IDLE
```

| Desde | Hacia | Condición |
|---|---|---|
| IDLE | WALK | En suelo y hay entrada de movimiento |
| IDLE | JUMP | Espacio en el suelo, o deja de haber suelo |
| WALK | IDLE | Sin entrada y velocidad horizontal < 0.3 m/s |
| WALK | JUMP | Espacio en el suelo, o el personaje cae por un borde |
| JUMP | WALK | Toca el suelo con velocidad vertical ≤ 0.1 y hay entrada |
| JUMP | IDLE | Toca el suelo con velocidad vertical ≤ 0.1 y no hay entrada |

Decisiones de diseño:

- **No existe el salto en el aire**: el impulso solo se aplica si el cuerpo estaba en el suelo al comenzar el tick, y ninguna
  transición desde JUMP lo vuelve a aplicar.
- **Caer cuenta como JUMP**: la guía pide tres estados, así que caminar fuera de un borde usa la misma pose aérea.
- **La FSM se evalúa después de `move_and_slide()`**, cuando `is_on_floor()` ya refleja la colisión de ese tick.
- Cada transición se registra con su instante y su motivo, por ejemplo `IDLE -> WALK (hay entrada de movimiento)`.

### 4.4 El personaje (`hunk.glb`)

| | |
|---|---|
| Escala | La raíz del archivo trae un factor de 1.739 que dejaba al personaje en ≈ 3.3 m. La envoltura aplica **×0.575** → ≈ **1.88 m** |
| Orientación | glTF mira hacia +Z; Godot usa −Z como “adelante”. La envoltura lo gira 180° |
| Pose de reposo | T-pose. El script baja los brazos 68° (`arm_down_degrees`) para obtener una pose en A |

`hunk_visual.gd` anima el esqueleto de forma procedural. En lugar de depender de los ejes de cada hueso, calcula los ejes del
personaje (izquierda, arriba, adelante) a partir de la pose de reposo y expresa todas las rotaciones en ese espacio:

- **Piernas**: balanceo ±32° con flexión de rodilla durante la fase de avance; la cadera baja para que los pies sigan tocando el suelo.
- **Brazos**: balanceo opuesto a las piernas (±30°) con flexión de codo.
- **Torso**: inclinación hacia adelante y ligero giro con cada paso; respiración leve en reposo.
- **Salto**: pose aérea con una pierna adelante flexionada, brazos arriba y mezcla suave de entrada y salida.
- **Cabeza**: gira hacia donde mira la cámara respecto al cuerpo (límite ±80° horizontal y ±35° vertical), repartido entre dos huesos
  del cuello y la cabeza, con suavizado dependiente de `delta`.

Los clips definitivos y el ajuste fino de la deformación quedan para la Tarea 2.

### 4.5 El escenario y el circuito de parkour

El escenario `low_poly_street_gameready_6.glb` se instancia con **escala ×2** (sus cajas medían 0.35 m frente a un personaje de 1.88 m).
Como el archivo no trae colisiones, cada elemento se cubre con formas simples (`BoxShape3D`, `CylinderShape3D`) dentro de
`StaticBody3D`; el suelo y cuatro límites invisibles impiden salir del mapa. Los props nuevos reutilizan las texturas del propio escenario
(cajas metálicas, concreto agrietado, barril oxidado) para conservar el estilo.

El **cielo** es procedural (`ProceduralSkyMaterial`) y la luz es una **`DirectionalLight3D` con sombras** (distancia máxima de 70 m).

| Elemento | Medidas | Colisión |
|---|---|---|
| Escaleras **S1** (10 peldaños) | contrahuella 0.20 m, altura 2.0 m | rampa de 24° bajo los peldaños |
| Plataformas **P1** y **P2** | altura 2.0 m, hueco de 1.6 m entre ellas | `BoxShape3D` |
| Pilares (3) | 1.6 / 1.2 / 0.8 m, separación 0.6 m | `BoxShape3D` |
| Torre de cajas (3) | 0.8 / 1.6 / 2.4 m | `BoxShape3D` |
| Escaleras **S2** (12 peldaños) | bajada desde la caja de 2.4 m | rampa de 30° |
| Muros bajos (2) | altura 1.0 m | `BoxShape3D` |
| Barriles (6) | 0.95 m | `CylinderShape3D` |

El salto máximo es `v² / (2g) = 7.5² / (2·22) ≈ 1.28 m`, de modo que ningún escalón del circuito supera 0.8 m entre apoyos.

**Recorrido sugerido:** pilares ascendentes → plataforma P2 → salto sobre el hueco → plataforma P1 → escaleras S1 hacia el suelo;
y, aparte, torre de cajas → caja de 2.4 m → escaleras S2.

Las escaleras tienen peldaños visibles pero una **única rampa de colisión** debajo (menor que `floor_max_angle` = 45°),
lo que evita que el personaje se atasque en cada escalón sin necesidad de lógica de subida de peldaños.

---

## 5. Pruebas de aceptación

| # | Prueba | Cómo hacerla | Resultado esperado |
|---|---|---|---|
| 1 | Colisiones | Caminar y saltar junto al suelo, esquinas, cajas y muros; mantener `Espacio` en el aire | No atraviesa nada y no hay salto en el aire |
| 2 | Cámara | Girar la cámara pegada a las fachadas y al bloque grande del oeste | El movimiento mantiene la referencia de cámara y la cámara no atraviesa paredes |
| 3 | FSM | Observar el HUD al caminar, saltar, aterrizar y soltar las teclas | IDLE ↔ WALK ↔ JUMP según la tabla; vuelve a IDLE al detenerse |
| 4 | Dos límites de render | Parado en zona libre: `F6` (144 FPS) → `F5`; después `F6` (30 FPS) → `F5` | Misma distancia en ambos casos; cambian los cuadros de render |
| 5 | Copia limpia | Copiar la carpeta, abrirla en Godot y revisar la consola | Sin archivos faltantes; modelo, materiales y escala correctos |

**Valor teórico de la prueba 4.** el personaje camina 420 ticks (7 s físicos) y el HUD reporta distancia, ticks, cuadros y tiempo real. La distancia debe ser casi idéntica con 30 y 144 FPS (teórico: 5 m/s × 3 s menos ≈ 0.28 m de aceleración, ≈ 14.7 m en terreno libre); cambian los cuadros dibujados (≈ 210 contra ≈ 1008), no el desplazamiento.

---

## 6. Parámetros ajustables

Todos son variables `@export`, editables en el Inspector sin tocar el código.

**`player.gd`**

| Parámetro | Valor | Efecto |
|---|---|---|
| `walk_speed` / `run_speed` | 5 / 8 m/s | Velocidad máxima |
| `acceleration` / `deceleration` / `air_acceleration` | 45 / 55 / 18 m/s² | Respuesta al iniciar, detenerse y en el aire |
| `jump_velocity` | 7.5 m/s | Altura de salto ≈ 1.28 m |
| `gravity` / `max_fall_speed` | 22 m/s² / 40 m/s | Caída |
| `turn_speed` | 14 1/s | Rapidez con la que el modelo gira hacia su rumbo |
| `test_duration_ticks` | 180 | Duración de la prueba F5 |

**`camera_rig.gd`**

| Parámetro | Valor |
|---|---|
| `follow_height` | 1.55 m |
| `mouse_sensitivity` | 0.0025 rad/px |
| `key_turn_speed` | 2.2 rad/s |
| `follow_smoothing` | 20 1/s |
| `min_pitch_degrees` / `max_pitch_degrees` | −65° / 35° |

**`hunk_visual.gd`**

| Parámetro | Valor |
|---|---|
| `arm_down_degrees` | 68° |
| `leg_swing_degrees` / `knee_bend_degrees` | 32° / 55° |
| `arm_swing_degrees` | 30° |
| `max_head_yaw_degrees` / `max_head_pitch_degrees` | 80° / 35° |

---

## 7. Limitaciones conocidas

- La pose procedural es una aproximación: en los hombros (T-pose bajada 68°) puede haber cierta deformación de la chaqueta.
  Ajustar `arm_down_degrees` suele bastar; la solución completa son clips de animación (Tarea 2).
- Las escaleras usan una rampa de colisión simple: el pie puede quedar ligeramente por encima o por debajo (≈ 0.1 m) de la huella visual.
- Las animaciones incluidas en `hunk.glb` (“Motion”) no se usan en esta entrega.
- El límite de render alterna entre 30 y 144 FPS; con VSync activado en el sistema, el tope real puede ser menor.

## 8. Procedencia, licencias y créditos

| Recurso | Autor | Licencia | Fuente |
|---|---|---|---|
| `hunk.glb` | Vasian-Digital3D | CC-BY-4.0 (requiere atribución) | [Sketchfab](https://sketchfab.com/3d-models/hunk-d891456f51a7431cafeac3137351cfc0) |
| `low_poly_street_gameready_6.glb` | dasy444 | Sketchfab Standard | [Sketchfab](https://sketchfab.com/3d-models/low-poly-street-gameready-6-8070aa74a8724379aaf70008fa33bd6d) |
| `textures/*.png` | Recortes del atlas del escenario | La del escenario | — |

No se generó un personaje con Tripo o Meshy: se usó un recurso de práctica externo, declarado en `Prompts/BITACORA.md`.
La revisión de escala, orientación, esqueleto y materiales está en `docs/FICHA_MODELOS.md`.
