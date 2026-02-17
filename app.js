const fileInput = document.getElementById('fileInput');
const dropZone = document.getElementById('dropZone');
const processBtn = document.getElementById('processBtn');
const consoleEl = document.getElementById('console');
const fileStatus = document.getElementById('fileStatus');

let originalContent = "";
let originalName = "";

// --- UTILS ---
function log(msg, type = 'info') {
    const p = document.createElement('p');
    p.className = type;
    p.textContent = `> ${msg}`;
    consoleEl.appendChild(p);
    consoleEl.scrollTop = consoleEl.scrollHeight;
}

// --- FILE HANDLING ---
fileInput.addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (file) handleFile(file);
});

dropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropZone.classList.add('drag-over');
});

dropZone.addEventListener('dragleave', () => {
    dropZone.classList.remove('drag-over');
});

dropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('drag-over');
    const file = e.dataTransfer.files[0];
    if (file) handleFile(file);
});

function handleFile(file) {
    originalName = file.name;
    const reader = new FileReader();
    reader.onload = (e) => {
        originalContent = e.target.result;
        fileStatus.textContent = `Archivo cargado: ${file.name}`;
        processBtn.disabled = false;
        log(`Archivo cargado exitosamente (${(file.size / 1024).toFixed(1)} KB)`);
    };
    reader.readAsText(file);
}

// --- PROCESSING LOGIC ---
processBtn.addEventListener('click', () => {
    try {
        log("Iniciando procesamiento...", "info");
        const lines = originalContent.split(/\r?\n/);
        const copies = parseInt(document.getElementById('copies').value);
        const targetTemp = document.getElementById('temp').value;
        const centerX = document.getElementById('centerX').value;
        const depthY = document.getElementById('depthY').value;

        // Busqueda de marcadores (v5 logic)
        const findLineIdx = (pattern, start = 0) => {
            for (let i = start; i < lines.length; i++) {
                if (lines[i].includes(pattern)) return i;
            }
            return -1;
        };

        const idxStartExec = findLineIdx("EXECUTABLE_BLOCK_START");
        const idxM109 = findLineIdx("M109", idxStartExec);
        const idxFinPurga = findLineIdx("G1 X-1.7 Y20", idxM109);
        const idxStartObj = findLineIdx("EXCLUDE_OBJECT_START", idxFinPurga);
        const idxEndExec = findLineIdx("EXECUTABLE_BLOCK_END");

        // Encontrar ultimo EXCLUDE_OBJECT_END antes del fin
        let idxEndObj = -1;
        for (let i = idxEndExec; i > idxStartObj; i--) {
            if (lines[i].includes("EXCLUDE_OBJECT_END")) {
                idxEndObj = i;
                break;
            }
        }

        if (idxStartExec === -1 || idxM109 === -1 || idxEndObj === -1) {
            throw new Error("Marcadores no encontrados. Asegúrate de usar un G-code de Creality Print.");
        }

        log("Marcadores encontrados correctamente.");

        // Bloques
        const header = lines.slice(0, idxStartExec);
        const initCommon = lines.slice(idxStartExec, idxM109 + 1);
        const purga = lines.slice(idxM109 + 1, idxFinPurga + 1);
        const postPurga = lines.slice(idxFinPurga + 1, idxStartObj);
        const cuerpo = lines.slice(idxStartObj, idxEndObj + 1);
        const shutdown = lines.slice(idxEndObj + 1, idxEndExec);
        const configFinal = lines.slice(idxEndExec);

        const rutinaExpulsion = [
            `; --- INICIO RUTINA DE EXPULSIÓN ---`,
            `M117 Enfrentando cama a ${targetTemp}C...`,
            `M140 S0 ; Apagar cama`,
            `M104 S150 ; Nozzle en espera`,
            `G1 X${centerX} Y${depthY} F5000 ; Apartar cabezal`,
            `M190 R${targetTemp} ; Esperar enfriamiento`,
            `M117 Expulsando pieza...`,
            `G90`,
            `G1 Z50 F3000   ; Subir 5cm`,
            `G1 Y${depthY} F5000  ; Cama atrás`,
            `G1 X${centerX} F3000  ; Centrar X`,
            `G1 Z5 F3000    ; Bajar a 0.5cm`,
            `G1 Y0 F1500    ; Empujar pieza al frente`,
            `G1 Z50 F3000   ; Seguridad`,
            `; --- FIN RUTINA DE EXPULSIÓN ---`
        ];

        // Ensamblaje
        let finalGcode = [...header];

        for (let i = 1; i <= copies; i++) {
            log(`Procesando Pieza #${i}...`);
            finalGcode.push("");
            finalGcode.push("; #####################################");
            finalGcode.push(`; PIEZA NUMERO ${i}`);
            finalGcode.push("; #####################################");

            if (i > 1) finalGcode.push(...rutinaExpulsion);
            
            finalGcode.push(...initCommon);

            if (i === 1) {
                finalGcode.push(...purga);
            } else {
                finalGcode.push("; [Purga omitida en piezas posteriores]");
            }

            finalGcode.push(...postPurga);
            finalGcode.push(...cuerpo);
        }

        finalGcode.push(...shutdown);
        finalGcode.push(...configFinal);

        // Download
        const blob = new Blob([finalGcode.join('\n')], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `Multi_${copies}x_${originalName}`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        log("¡Éxito! El archivo se ha generado y descargado.", "info");

    } catch (err) {
        log(err.message, "error");
    }
});
