# Bitácora de procedencia

## Origen del personaje
No se generó un modelo con Tripo/Meshy en esta entrega: se usó un **recurso de práctica** (Sketchfab, CC-BY-4.0),
`hunk.glb`, entregado por el estudiante, con el escenario `low_poly_street_gameready_6.glb`.
Origen y licencias: ver `docs/FICHA_MODELOS.md`.

- Herramienta de generación IA: no aplica. Prompt exacto: no aplica.
- Fecha de integración: 2026-10-06.

## Verificaciones (sin inventar defectos) y correcciones medidas
| # | Verificación | Resultado | Acción |
|---|---|---|---|
| 1 | Escala del personaje | altura importada ≈ 3.28 m (raíz ×1.739) | escala ×0.575 → ≈ 1.88 m |
| 2 | Orientación | frente en +Z (ojos con z mayor que la cabeza) | giro de 180° en el envoltorio |
| 3 | Articulaciones / pose | esqueleto completo (189 huesos); brazos en T-pose, piernas verticales | brazos bajados 68° por código |
| 4 | Escala del escenario | cajas de 0.35 m frente a un personaje de 1.88 m | escenario ×2 |
| 5 | Colisiones del escenario | el glb no trae colisiones | cajas/cilindros simples en `StaticBody3D` |
| 6 | Archivos / materiales | 7 + 3 materiales, texturas incrustadas, sin referencias externas | nada que corregir |

## Comparación antes / después
- Personaje: 3.28 m → 1.88 m; orientación +Z → −Z (adelante de Godot).
- Escenario: suelo 10.4 × 15.3 m → 20.8 × 30.7 m; caja 0.35 m → 0.7 m.
