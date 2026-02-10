<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Laboratorio de Seguridad</title>
    <style>
        body{font-family:system-ui,Arial;margin:24px;color:#111}
        h1{margin-bottom:8px}
        .grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}
        .card{border:1px solid #ddd;padding:16px;border-radius:8px;background:#fff}
        label{display:block;margin-bottom:8px;font-weight:600}
        input[type=text]{width:100%;padding:8px;margin-bottom:8px;border:1px solid #ccc;border-radius:4px}
        .examples button{margin-right:6px;margin-top:6px}
        .note{font-size:0.9rem;color:#555}
    </style>
</head>
<body>
    <h1>Damn-Vulnerable-Laravel-Application</h1>
    <p class="note">Usa esta UI para probar los endpoints de descarga y redirección del laboratorio.</p>

    <div class="grid">
        <div class="card">
            <h2>Descargas - Path traversal</h2>
            <form action="/download" method="get">
                <label>Filename (vulnerable)</label>
                <input type="text" name="filename" id="file-vuln" placeholder="hello.txt">
                <button type="submit">Descargar (vulnerable)</button>
            </form>

            <form action="/download-secure" method="get">
                <label>Filename (basename)</label>
                <input type="text" name="filename" id="file-bn" placeholder="hello.txt">
                <button type="submit">Descargar (secure)</button>
            </form>

            <form action="/download-realpath" method="get">
                <label>Filename (realpath)</label>
                <input type="text" name="filename" id="file-rp" placeholder="hello.txt">
                <button type="submit">Descargar (realpath)</button>
            </form>

            <form action="/download-allowlist" method="get">
                <label>Filename (allow-list)</label>
                <input type="text" name="filename" id="file-al" placeholder="hello.txt">
                <button type="submit">Descargar (allow-list)</button>
            </form>

            <div class="examples">
                <p class="note">Ejemplos rápidos:</p>
                <button onclick="setFile('file-vuln','hello.txt')">hello.txt</button>
                <button onclick="setFile('file-vuln','../../composer.json')">../../composer.json</button>
                <button onclick="setFile('file-al','document.pdf')">document.pdf</button>
            </div>
        </div>

        <div class="card">
            <h2>Open Redirect</h2>

            <form action="/redirect-vuln" method="get">
                <label>URL (vulnerable)</label>
                <input type="text" name="url" id="url-vuln" placeholder="http://evil.example.com">
                <button type="submit">Ir (vulnerable)</button>
            </form>

            <form action="/redirect-safe" method="get">
                <label>URL (allow-list hosts)</label>
                <input type="text" name="url" id="url-safe" placeholder="http://example.com/path">
                <button type="submit">Ir (safe)</button>
            </form>

            <form action="/redirect-validate" method="get">
                <label>Path (solo relativo)</label>
                <input type="text" name="url" id="url-validate" placeholder="/some/path">
                <button type="submit">Ir (validate)</button>
            </form>

            <div class="examples">
                <p class="note">Ejemplos rápidos:</p>
                <button onclick="setUrl('url-vuln','http://evil.example.com')">evil.example.com</button>
                <button onclick="setUrl('url-safe','http://example.com/')">example.com</button>
                <button onclick="setUrl('url-validate','/download?filename=hello.txt')">/download?filename=hello.txt</button>
            </div>
        </div>
    </div>

    <script>
        function setFile(id, value){
            var el = document.getElementById(id);
            if(el) el.value = value;
        }
        function setUrl(id, value){
            var el = document.getElementById(id);
            if(el) el.value = value;
        }
    </script>
</body>
</html>
