# Ficha de modelos

## Personaje – `models/hunk.glb`
| Dato | Valor |
|---|---|
| Título / autor | “Hunk” – Vasian-Digital3D |
| Fuente | https://sketchfab.com/3d-models/hunk-d891456f51a7431cafeac3137351cfc0 |
| Licencia | CC-BY-4.0 (requiere atribución) |
| Archivo | 42.8 MB, glTF 2.0 (export Sketchfab) |
| Triángulos | 119 601 (7 mallas: body 44 347, equipment 21 257, jacket 32 967, material 5 871, face 9 985, eyes 1 200, oa93 3 974) |
| Materiales / texturas | 7 materiales PBR, 15 imágenes PNG incrustadas (base color, normal, etc.) |
| Esqueleto | 1 skin, 189 articulaciones (brazos, piernas, columna, cuello, cabeza, dedos, músculos y twist) |
| Animaciones en el archivo | 1 (“Motion”, 21.9 s) – no se usa en esta entrega |
| Orientación original | “frente” hacia +Z (convención glTF); Godot usa −Z → se gira 180° en `HunkModel.tscn` |
| Escala original | el nodo raíz trae ×1.739; altura importada ≈ 3.28 m → se escala ×0.575 → **≈ 1.88 m** |
| Pose de reposo | T-pose (brazos horizontales) → el script los baja 68° |

## Escenario – `models/low_poly_street_gameready_6.glb`
| Dato | Valor |
|---|---|
| Título / autor | “low poly street gameready (6)” – dasy444 |
| Fuente | https://sketchfab.com/3d-models/low-poly-street-gameready-6-8070aa74a8724379aaf70008fa33bd6d |
| Licencia | Sketchfab Standard (revisar términos antes de redistribuir) |
| Triángulos | 2 107 (27 mallas) |
| Materiales / texturas | 3 materiales, 3 texturas PNG 1024² (cajas/rejas/barriles/concreto; fachadas; ladrillo) |
| Escala original | suelo 10.4 × 15.3 m, cajas de 0.35 m, barriles 0.47 m → demasiado pequeño para un personaje de 1.88 m |
| Corrección | instancia con escala **×2** (cajas 0.7 m, barriles ≈ 0.94 m, suelo 20.8 × 30.7 m) |
| Colisiones | no incluidas en el glb → `StaticBody3D` con cajas/cilindros calculados desde cada malla (×2) |

## Texturas derivadas (`textures/`)
`crate.png`, `concrete.png`, `barrel.png`: recortes del atlas del propio escenario, usados en las escaleras,
plataformas, pilares, cajas y barriles del parkour para mantener el mismo estilo.
