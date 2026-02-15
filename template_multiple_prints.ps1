# ==============================================================================
# PLANTILLA PARA IMPRESIÓN CONTINUA CON EXPULSIÓN (Ender 3 V3 KE)
# ==============================================================================
# Instrucciones:
# 1. Abre tu archivo G-code original en un editor de texto (como Notepad++ o VS Code).
# 2. Identifica los números de línea para el Inicio, el Cuerpo y el Final.
# 3. Ajusta los índices en la sección "CONFIGURACIÓN DE LÍNEAS" abajo.
# 4. Ejecuta el script para generar el nuevo archivo.
# ==============================================================================

# --- CONFIGURACIÓN DE ARCHIVOS ---
$archivoOriginal = "Marcador de llaves 2.0_PLA_12m7s.gcode" # <--- CAMBIA EL NOMBRE AQUÍ
$archivoResultado = "Multi_Impresion_Personalizada.gcode"   # <--- NOMBRE DEL ARCHIVO FINAL
$cantidadDePiezas = 5                                      # <--- CUÁNTAS VECES IMPRIMIR

Write-Host "Leyendo archivo original..."
$lineas = Get-Content $archivoOriginal

# --- CONFIGURACIÓN DE LÍNEAS (Índices 0-based) ---
# Tip: En Notepad++, haz (Número de Línea - 1) para obtener el índice.

# 1. El Header: Incluye la miniatura, comentarios de configuración inicial.
$indiceFinHeader = 187 
$bloqueHeader = $lineas[0..$indiceFinHeader]

# 2. Inicio Común: Comandos hasta JUSTO ANTES de la línea de purga (G28, Temperaturas).
$indiceFinInitCommon = 199 
$bloqueInitCommon = $lineas[($indiceFinHeader + 1)..$indiceFinInitCommon]

# 3. Línea de Purga: La línea de limpieza que hace la maquina al lado izquierdo.
$indiceFinPurga = 202
$bloquePurga = $lineas[($indiceFinInitCommon + 1)..$indiceFinPurga]

# 4. Configuración Post-Purga: G92 E0 y preparativos antes de empezar la pieza.
$indiceFinPostPurga = 226
$bloquePostPurga = $lineas[($indiceFinPurga + 1)..$indiceFinPostPurga]

# 5. Cuerpo de la Pieza: Desde el primer comando de impresión hasta EXCLUDE_OBJECT_END.
$indiceFinCuerpo = 17872
$bloqueCuerpo = $lineas[($indiceFinPostPurga + 1)..$indiceFinCuerpo]

# 6. Shutdown Final: Retracción final, apagar motores, etc.
$indiceFinShutdown = 17892
$bloqueShutdown = $lineas[($indiceFinCuerpo + 1)..$indiceFinShutdown]

# 7. Metadata Extra: Bloque de configuración final (slicer settings).
$bloqueConfigFinal = $lineas[($indiceFinShutdown + 1)..($lineas.Count-1)]

# ==============================================================================
# RUTINA DE EXPULSIÓN (AJUSTA COORDENADAS SI TU PIEZA ES MÁS GRANDE)
# ==============================================================================
$rutinaExpulsion = @(
    "; --- INICIO RUTINA DE EXPULSIÓN ---",
    "M117 Enfrentando cama a 35C...",
    "M140 S0 ; Apagar cama",
    "M104 S150 ; Nozzle en espera (evita chorreo)",
    "G1 X110 Y200 F5000 ; Apartar cabezal mientras enfría",
    "M190 R35 ; Esperar a que despegue la pieza",
    "M117 Expulsando pieza...",
    "G90 ; Coordenadas absolutas",
    "G1 Z50 F3000   ; Levantar cabezal 5cm",
    "G1 Y200 F5000  ; Cama hacia atrás (la pieza queda detrás del nozzle)",
    "G1 X110 F5000  ; Centrar nozzle con la pieza",
    "G1 Z5 F3000    ; Bajar nozzle a 5mm de la cama",
    "G1 Y0 F1500    ; Cama hacia adelante (el nozzle empuja la pieza)",
    "G1 Z50 F3000   ; Levantar para seguridad",
    "; --- FIN RUTINA DE EXPULSIÓN ---"
)

# --- ENSAMBLAJE ---
Write-Host "Ensamblando G-code para $cantidadDePiezas piezas..."
$gcodeFinal = @()
$gcodeFinal += $bloqueHeader

for ($i = 1; $i -le $cantidadDePiezas; $i++) {
    Write-Host "Procesando pieza numero $i..."
    $gcodeFinal += ""
    $gcodeFinal += "; #####################################"
    $gcodeFinal += "; PIEZA NUMERO $i"
    $gcodeFinal += "; #####################################"
    
    if ($i -gt 1) {
        $gcodeFinal += $rutinaExpulsion
    }
    
    $gcodeFinal += $bloqueInitCommon
    
    if ($i -eq 1) { $gcodeFinal += $bloquePurga }
    else { $gcodeFinal += "; [Purga omitida en piezas posteriores]" }
    
    $gcodeFinal += $bloquePostPurga
    $gcodeFinal += $bloqueCuerpo
    $gcodeFinal += "; --- FIN PIEZA $i ---"
}

$gcodeFinal += $bloqueShutdown
$gcodeFinal += $bloqueConfigFinal

Write-Host "Guardando archivo..."
Set-Content $archivoResultado -Value $gcodeFinal -Encoding Utf8
Write-Host "¡Completado! El archivo '$archivoResultado' está listo."
