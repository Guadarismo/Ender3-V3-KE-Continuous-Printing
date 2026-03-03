# ==============================================================================
# PLANTILLA PARA IMPRESIÓN CONTINUA CON EXPULSIÓN (Ender 3 V3 KE) - v5 (FINAL)
# ==============================================================================

# --- CONFIGURACIÓN DE ARCHIVOS ---
$archivoOriginal = "GCodeLaminador.gcode" 
$archivoResultado = "Multi_Impresion_Personalizada.gcode" # Volvemos al nombre deseado
$cantidadDePiezas = 5

Write-Host "Leyendo archivo original: $archivoOriginal..."
$lineas = Get-Content $archivoOriginal

# --- BUSCADOR AUTOMÁTICO DE PUNTOS DE CORTE ---
function Buscar-Linea($patron, $desde = 0) {
    for ($i = $desde; $i -lt $lineas.Count; $i++) {
        if ($lineas[$i] -match $patron) { return $i }
    }
    return -1
}

# 1. El fin del preámbulo (metadata y fotos)
$idxStartExec = Buscar-Linea "EXECUTABLE_BLOCK_START"
$idxFinHeader = $idxStartExec - 1

# 2. El fin de la inicialización común (hasta M109 o purga)
$idxM109 = Buscar-Linea "M109" $idxStartExec
$idxFinPurga = Buscar-Linea "G1 X-1.7 Y20" $idxM109 # Fin de la linea de purga

# 3. El inicio real de la pieza
$idxStartObjeto = Buscar-Linea "EXCLUDE_OBJECT_START" $idxFinPurga

# 4. El fin del ejecutable (donde terminan los comandos de movimiento)
$idxEndExecutable = Buscar-Linea "EXECUTABLE_BLOCK_END"

# 5. Encontrar el fin de la impresión (último exclude end antes del fin)
$idxEndObjeto = -1
for ($i = $idxEndExecutable; $i -gt $idxStartObjeto; $i--) {
    if ($lineas[$i] -match "EXCLUDE_OBJECT_END") {
        $idxEndObjeto = $i
        break
    }
}

if ($idxStartExec -eq -1 -or $idxM109 -eq -1 -or $idxEndObjeto -eq -1) {
    Write-Error "No se pudieron encontrar los marcadores. Asegúrate que sea un archivo de Creality Print original."
    exit
}

# --- ENSAMBLAJE DE BLOQUES ---
$bloqueHeader = $lineas[0..$idxFinHeader]
$bloqueInitCommon = $lineas[$idxStartExec..$idxM109]
$bloquePurga = $lineas[($idxM109 + 1)..$idxFinPurga]
$bloquePostPurga = $lineas[($idxFinPurga + 1)..($idxStartObjeto - 1)]
$bloqueCuerpo = $lineas[$idxStartObjeto..$idxEndObjeto]
$bloqueShutdown = $lineas[($idxEndObjeto + 1)..($idxEndExecutable - 1)]
$bloqueConfigFinal = $lineas[$idxEndExecutable..($lineas.Count - 1)]

# ==============================================================================
# RUTINA DE EXPULSIÓN
# ==============================================================================
$rutinaExpulsion = @(
    "; --- INICIO RUTINA DE EXPULSIÓN ---",
    "M117 Enfrentando cama a 35C...",
    "M140 S0 ; Apagar cama",
    "M104 S150 ; Nozzle en espera",
    "G1 X110 Y200 F5000 ; Apartar cabezal",
    "M190 R35 ; Esperar enfriamiento",
    "M117 Expulsando pieza...",
    "G90",
    "G1 Z50 F3000   ; Subir 5cm",
    "G1 Y200 F5000  ; Cama atrás",
    "G1 X110 F5000  ; Centrar X",
    "G1 Z5 F3000    ; Bajar a 0.5cm",
    "G1 Y0 F1500    ; Empujar pieza al frente",
    "G1 Z50 F3000   ; Seguridad",
    "; --- FIN RUTINA DE EXPULSIÓN ---"
)

# --- PROCESO DE ENSAMBLAJE ---
Write-Host "Ensamblando G-code para $cantidadDePiezas piezas..."
$gcodeFinal = @()
$gcodeFinal += $bloqueHeader

for ($i = 1; $i -le $cantidadDePiezas; $i++) {
    Write-Host "Procesando Pieza #$i..."
    $gcodeFinal += ""
    $gcodeFinal += "; #####################################"
    $gcodeFinal += "; PIEZA NUMERO $i"
    $gcodeFinal += "; #####################################"
    
    if ($i -gt 1) { $gcodeFinal += $rutinaExpulsion }
    
    $gcodeFinal += $bloqueInitCommon
    
    if ($i -eq 1) { $gcodeFinal += $bloquePurga }
    else { $gcodeFinal += "; [Purga omitida en piezas posteriores]" }
    
    $gcodeFinal += $bloquePostPurga
    $gcodeFinal += $bloqueCuerpo
}

$gcodeFinal += $bloqueShutdown
$gcodeFinal += $bloqueConfigFinal

Write-Host "Guardando archivo..."
Set-Content $archivoResultado -Value $gcodeFinal -Encoding Utf8
Write-Host "¡Completado! El archivo '$archivoResultado' está listo."
