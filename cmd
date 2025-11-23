<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Diagnóstico de Red Virtual</title>
<style>
    body {
        font-family: 'Courier New', monospace;
        background: #000;
        color: #0f0;
        margin: 0;
        padding: 20px;
        height: 100vh;
        overflow: hidden;
    }
    #game {
        max-width: 1000px;
        margin: 0 auto;
        border: 2px solid #0f0;
        padding: 20px;
        border-radius: 10px;
        background: #001100;
        box-shadow: 0 0 20px #0f0;
    }
    h1 { text-align: center; text-shadow: 0 0 10px #0f0; }
    #scenario {
        background: #000;
        padding: 15px;
        border: 1px solid #0f0;
        height: 120px;
        overflow-y: auto;
        margin: 20px 0;
    }
    #editor {
        width: 100%;
        height: 200px;
        background: #000;
        color: #0f0;
        border: 1px solid #0f0;
        padding: 10px;
        font-family: 'Courier New', monospace;
        font-size: 14px;
    }
    button {
        background: #000;
        color: #0f0;
        border: 1px solid #0f0;
        padding: 10px 20px;
        margin: 10px 5px;
        cursor: pointer;
        font-weight: bold;
    }
    button:hover { background: #003300; }
    #feedback {
        margin: 20px 0;
        padding: 15px;
        border: 1px dashed #0f0;
        min-height: 80px;
    }
    #stats {
        position: absolute;
        top: 20px;
        right: 20px;
        background: rgba(0,0,0,0.8);
        padding: 10px;
        border: 1px solid #0f0;
    }
    .success { color: #00ff00; }
    .error { color: #ff0000; }
    .blink {
        animation: blink 1s infinite;
    }
    @keyframes blink {
        50% { opacity: 0; }
    }
</style>
</head>
<body>

<div id="game">
    <h1>DIAGNÓSTICO DE RED VIRTUAL</h1>
    <div id="stats">
        Nivel: <span id="level">1</span>/8<br>
        Puntos: <span id="score">0</span><br>
        Vidas: <span id="lives">❤️❤️❤️</span>
    </div>

    <div id="scenario"></div>

    <p><strong>Instrucciones:</strong> Edita el archivo de configuración o escribe el comando correcto para solucionar el problema.</p>
    
    <textarea id="editor" placeholder="Escribe aquí tu solución..."></textarea>

    <div style="text-align:center;">
        <button onclick="checkAnswer()">▶ ENVIAR SOLUCIÓN</button>
        <button onclick="nextScenario()">SIGUIENTE ESCENARIO →</button>
    </div>

    <div id="feedback">Bienvenido, técnico. Lee el escenario y arregla el problema.</div>
</div>

<script>
// === BASE DE DATOS DE ESCENARIOS ===
const scenarios = [
    {
        id: 1,
        title: "Escenario 1 - No hay conexión a Internet",
        description: `El cliente reporta que no tiene Internet en su PC.
Al revisar el cable de red, todo está conectado.
Comando ipconfig muestra:
    Dirección IPv4 . . . . . . . . . : 169.254.10.45
    Máscara de subred  . . . . . . . : 255.255.0.0
    Puerta de enlace predeterminada : (vacío)

El router está funcionando y otros dispositivos sí tienen Internet.`,
        hint: "El equipo tiene una IP APIPA (169.254.x.x)",
        file: `interfaz Ethernet:
    dhcp: false
    ip: 169.254.10.45
    mascara: 255.255.255.0
    gateway: `,
        solutions: [/dhcp:\s*true/i, /ip:\s*dhcp/i, /obtener.*autom/i],
        correctFeedback: "¡Correcto! Activaste DHCP y el equipo obtuvo IP válida del router.",
        wrongFeedback: "No se activó DHCP. La IP 169.254.x.x indica que no hay servidor DHCP accesible."
    },
    {
        id: 2,
        title: "Escenario 2 - DNS no resuelve nombres",
        description: `El equipo tiene conexión (ping 8.8.8.8 funciona) pero no puede abrir google.com.
Al hacer nslookup:
    Server:  UnKnown
    Address:  192.168.1.1

    Error: No se puede encontrar google.com`,
        file: `configuración DNS actual:
    servidor_dns_primario: 192.168.1.1
    servidor_dns_secundario: 127.0.0.1`,
        solutions: [/8\.8\.8\.8/, /1\.1\.1\.1/, /dns.*google/i, /dns.*cloudflare/i],
        correctFeedback: "¡Excelente! Cambiaste a un DNS público funcional (Google o Cloudflare).",
        wrongFeedback: "El router (192.168.1.1) no está dando servicio DNS. Necesitas un DNS externo."
    },
    {
        id: 3,
        title: "Escenario 3 - Máscara de subred incorrecta",
        description: `Red: 192.168.10.0/24
PC del usuario:
    IP: 192.168.10.50
    Máscara: 255.255.0.0
    Gateway: 192.168.10.1

No puede comunicarse con otros equipos de la misma red.`,
        file: `configuración estática:
    ip: 192.168.10.50
    mascara: 255.255.0.0
    gateway: 192.168.10.1`,
        solutions: [/255\.255\.255\.0/, /mascara.*24/],
        correctFeedback: "¡Perfecto! Corregiste la máscara a /24 (255.255.255.0). Ahora está en la misma subred.",
        wrongFeedback: "Con máscara 255.255.0.0 el equipo cree que todo 192.168.x.x está en su red local → conflicto."
    },
    {
        id: 4,
        title: "Escenario 4 - Gateway incorrecto",
        description: `El equipo obtiene IP por DHCP correctamente (192.168.1.150), pero no sale a Internet.
Ping al gateway 192.168.1.2 → falla.
El gateway real del router es 192.168.1.1`,
        file: `ipconfig muestra:
    Dirección IPv4: 192.168.1.150
    Máscara: 255.255.255.0
    Puerta de enlace: 192.168.1.2`,
        solutions: [/192\.168\.1\.1/, /gateway.*1\.1/, /puerta.*enlace.*1\.1/],
        correctFeedback: "¡Genial! Cambiaste la puerta de enlace al router correcto.",
        wrongFeedback: "La puerta de enlace está mal configurada. Debe ser la IP del router (192.168.1.1)."
    },
    {
        id: 5,
        title: "Escenario 5 - Cable cruzado (cableado físico)",
        description: `Dos PCs conectados directamente con cable de red. Ninguno ve al otro.
Luces del puerto encendidas, pero no parpadean al enviar datos.
Se sospecha cableado defectuoso.`,
        hint: "En conexiones directas PC-PC se necesita cable cruzado o puerto Auto-MDIX",
        file: `Diagnóstico físico:
    Tipo de cable usado viens: directo (straight-through)
    Puerto Auto-MDIX: desactivado en ambos equipos`,
        solutions: [/cruzado/i, /crossover/i, /auto.*mdix/i, /activar.*mdix/i],
        correctFeedback: "¡Correcto! Cambiaste a cable cruzado o activaste Auto-MDIX.",
        wrongFeedback: "Con cable directo y sin Auto-MDIX no hay enlace entre dos PCs."
    },
    {
        id: 6,
        title: "Escenario 6 - Dirección IP duplicada",
        description: `Dos equipos en la red tienen la misma IP 192.168.1.100.
Uno funciona intermitentemente, el otro no tiene conexión.
Mensaje en Windows: 'Conflicto de dirección IP'.`,
        file: `Equipo A:
    IP: 192.168.1.100 (estática)
Equipo B:
    IP: 192.168.1.100 (estática) ← ¡PROBLEMA!`,
        solutions: [/cambiar.*ip/i, /192\.168\.1\.[1-9][0-9]*[^0]*/i, /dhcp/i],
        correctFeedback: "¡Bien! Cambiaste una IP o la pusiste en DHCP. Conflicto resuelto.",
        wrongFeedback: "Dos dispositivos no pueden tener la misma IP en la misma red."
    },
    {
        id: 7,
        title: "Escenario 7 - Puerto switch bloqueado por STP",
        description: `Al conectar un nuevo switch, varios puertos quedan en estado BLOCKING.
Los equipos conectados a esos puertos no tienen red.
Mensaje en switch: "Port blocked by Spanning Tree"`,
        file: `configuración puerto:
    spanning-tree portfast disable
    bpduguard disable`,
        solutions: [/portfast/i, /bpduguard.*enable/i, /edge/i],
        correctFeedback: "¡Exacto! Activaste PortFast o lo configuraste como puerto edge.",
        wrongFeedback: "STP está bloqueando el puerto porque no detecta que es un equipo final."
    },
    {
        id: 8,
        title: "Escenario 8 - MTU incorrecto (Black Hole)",
        description: `Navegar por páginas normales funciona, pero sitios grandes (YouTube, descargas) fallan.
Ping con paquetes grandes falla:
ping google.com -l 1500 → falla
ping google.com -l 1400 → funciona`,
        file: `MTU actual de la interfaz: 1500
Se detecta PMTUD bloqueado en el camino.`,
        solutions: [/mtu.*14[0-9][0-9]/i, /mtu.*13[0-9][0-9]/i, /1300|1320|1400|1380/i],
        correctFeedback: "¡Perfecto! Bajaste el MTU para evitar fragmentación bloqueada.",
        wrongFeedback: "Hay un router en el camino que bloquea ICMP 'Fragmentation Needed' → Black Hole."
    }
];

let currentLevel = 0;
let score = 0;
let lives = 3;

function loadScenario() {
    if (currentLevel >= scenarios.length) {
        document.getElementById("scenario").innerHTML = "<h2>¡FELICIDADES! Completaste todos los niveles 🎉</h2>";
        document.getElementById("feedback").innerHTML = `Puntuación final: ${score} puntos`;
        return;
    }

    const s = scenarios[currentLevel];
    document.getElementById("level").textContent = s.id;
    document.getElementById("scenario").innerHTML = 
        `<strong>${s.title}</strong><br><br>${s.description.replace(/\n/g, '<br>')}`;
    document.getElementById("editor").value = s.file || "";
    document.getElementById("feedback").innerHTML = "Listo para diagnosticar. Modifica el archivo y envía tu solución.";
    document.getElementById("feedback").className = "";
}

function checkAnswer() {
    const userText = document.getElementById("editor").value;
    const s = scenarios[currentLevel];
    let correct = false;

    for (let regex of s.solutions) {
        if (regex.test(userText)) {
            correct = true;
            break;
        }
    }

    const feedback = document.getElementById("feedback");
    if (correct) {
        score += 100;
        feedback.innerHTML = `✔ ${s.correctFeedback}<br><br>¡+100 puntos!`;
        feedback.className = "success";
        currentLevel++;
        setTimeout(loadScenario, 3000);
    } else {
        lives--;
        document.getElementById("lives").textContent = "❤️".repeat(lives);
        feedback.innerHTML = `✘ ${s.wrongFeedback}<br><br>Pista: ${s.hint || ''}`;
        feedback.className = "error";
        if (lives <= 0) {
            feedback.innerHTML += "<br><br>¡Game Over! Reiniciando...";
            setTimeout(() => {
                currentLevel = 0;
                score = 0;
                lives = 3;
                document.getElementById("lives").textContent = "❤️❤️❤️";
                document.getElementById("score").textContent = "0";
                loadScenario();
            }, 4000);
        }
    }
    document.getElementById("score").textContent = score;
}

function nextScenario() {
    currentLevel++;
    loadScenario();
}

// Iniciar juego
loadScenario();
</script>

<audio id="success" src="https://www.soundjay.com/buttons/button-09.mp3" preload="auto"></audio>
<audio id="error" src="https://www.soundjay.com/buttons/button-10.mp3" preload="auto"></audio>

</body>
</html>
