# Marcador de Llaves - Automatización de Impresión

Este repositorio contiene los archivos para imprimir 5 marcadores de llaves de forma consecutiva en una Ender 3 V3 KE, con un sistema de expulsión automática.

## Contenido
- `Marcador de llaves 2.0_PLA_12m7s.gcode`: El archivo G-code original (1 unidad).
- `assemble_gcode_v3.ps1`: Script de PowerShell que genera el archivo 5x.
- `Marcador_de_llaves_5x_v3.gcode`: El archivo final listo para imprimir (5 unidades con expulsión).

## Funcionamiento
El script `v3` incluye:
1. Elevación del cabezal 5cm tras cada impresión.
2. Movimiento de la cama hacia adelante.
3. Descenso a 0.5cm.
4. Empuje de la pieza hacia el frente mediante el nozzle.
5. Optimización: Solo limpia el nozzle en la primera pieza.
