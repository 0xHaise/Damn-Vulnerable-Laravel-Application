#!/usr/bin/env bash
set -euo pipefail

# init_lab.sh
# Reinicia entorno Docker y crea un Laravel mínimo + ruta vulnerable /download
# ADVERTENCIA: destructivo sobre ./laravel y recursos Docker del compose.

echo "1) Parando y eliminando contenedores, redes, volúmenes e imágenes del compose (si existen)..."
docker compose down --volumes --remove-orphans --rmi all || true

echo "2) Eliminando carpeta ./laravel (si existe) para empezar limpio..."
rm -rf ./laravel
mkdir -p ./laravel

echo "3) Creando proyecto Laravel en ./laravel usando la imagen oficial composer..."
docker run --rm -it \
  -v "$PWD/laravel":/app \
  -w /app \
  composer:2 create-project laravel/laravel . --prefer-dist --no-interaction

echo "4) Asegurando permisos iniciales en host (para evitar problemas de escritura desde contenedor)..."
# Esto deja los archivos con tu UID:GID local para editar desde host
sudo chown -R "$(id -u):$(id -g)" laravel || true
chmod -R u+rwX laravel || true

echo "5) Escribiendo la ruta vulnerable /download en routes/web.php (sobrescribe el routes/web.php generado)..."
cat > ./laravel/routes/web.php <<'PHP'
<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response('Vulnerable Laravel Lab');
});

/*
 * Vulnerable download endpoint (PATH TRAVERSAL)
 * e.g. GET /download?filename=../../.env
 */
Route::get('/download', function(Request $request) {
    $filename = $request->input('filename');

    // Vulnerable: concat sin sanitizar
    $path = storage_path('content/') . $filename;

    if (!file_exists($path)) {
        return response('File not found', 404);
    }

    return response()->download($path);
});
PHP

echo "6) Levantando los contenedores (build)..."
docker compose up -d --build

echo "7) Generando APP_KEY dentro del contenedor app (si falla, lo informamos)..."
docker compose run --rm app php artisan key:generate --ansi || true

echo "8) Creando directorio storage/content y archivos de prueba desde dentro del contenedor app..."
docker compose exec app bash -lc "\
  mkdir -p /var/www/html/storage/content && \
  echo 'contenido de prueba' > /var/www/html/storage/content/hello.txt && \
  echo 'APP_SECRET=supersecreto' > /var/www/html/.env && \
  chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/.env || true"

echo "9) Ajustando permisos finales (dentro del contenedor)..."
docker compose exec app bash -lc "chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache || true"

echo "10) Mostrar rutas registradas (comprobación):"
docker compose exec app bash -lc "php artisan route:list --no-ansi"

echo "11) Pruebas desde host (curl):"
echo " - Sanity: GET /"
curl -sS -I "http://localhost:8080/" || true
echo
echo " - Archivo válido (hello.txt):"
curl -sS "http://localhost:8080/download?filename=hello.txt" -o /tmp/hello_downloaded.txt || true
echo "   -> /tmp/hello_downloaded.txt size: $(stat -c%s /tmp/hello_downloaded.txt || echo 0) bytes"
echo
echo " - Path traversal test (../../.env):"
curl -sS -I "http://localhost:8080/download?filename=../../.env" || true

echo
echo "HECHO. Si ves 200/Content para hello.txt y potencial exposición de .env con ../../.env, la ruta vulnerable está activa."
echo "Si algo falla, pega la salida de: docker compose logs --tail=200 app   y   docker compose exec app bash -lc 'tail -n 200 /var/www/html/storage/logs/laravel.log'"


