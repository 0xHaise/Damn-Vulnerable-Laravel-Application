#!/usr/bin/env bash
set -euo pipefail

# fix_lab_env.sh
# Ejecutar desde la raíz del repo (donde está docker-compose.yml).
# Repara APP_KEY, SESSION_DRIVER y permisos para que el lab funcione sin BD.

COMPOSE="docker compose"

echo "1) Levantando contenedores (si no están arriba)..."
$COMPOSE up -d --build

echo "2) Asegurando que exista /var/www/html/.env dentro del contenedor app..."
$COMPOSE exec app bash -lc "test -f /var/www/html/.env || (echo 'APP_SECRET=supersecreto' > /var/www/html/.env && echo 'Se creó /var/www/html/.env de prueba')"

echo "3) Añadiendo APP_KEY= si falta (necesario para php artisan key:generate)..."
$COMPOSE exec app bash -lc "grep -q '^APP_KEY=' /var/www/html/.env || echo 'APP_KEY=' >> /var/www/html/.env; sed -n '1,80p' /var/www/html/.env"

echo "4) Generando APP_KEY con artisan (o insertando manualmente si falla)..."
if $COMPOSE exec app bash -lc "php artisan key:generate --ansi"; then
  echo "  -> APP_KEY generado con succes."
else
  echo "  -> php artisan key:generate falló; insertando APP_KEY manualmente..."
  $COMPOSE exec app bash -lc "\
    KEY=\$(php -r \"echo 'base64:'.base64_encode(random_bytes(32));\"); \
    sed -i '/^APP_KEY=/d' /var/www/html/.env || true; \
    printf 'APP_KEY=%s\n' \"\$KEY\" >> /var/www/html/.env; \
    echo 'APP_KEY escrita en /var/www/html/.env'; sed -n '1,40p' /var/www/html/.env"
fi

echo "5) Forzando SESSION_DRIVER=file en .env (para evitar uso de sqlite/BD temporalmente)..."
$COMPOSE exec app bash -lc "sed -i '/^SESSION_DRIVER=/d' /var/www/html/.env || true; printf 'SESSION_DRIVER=file\n' >> /var/www/html/.env; grep '^SESSION_DRIVER=' /var/www/html/.env || true"

echo "6) Creando directorios de storage necesarios y archivo de prueba (inside container)..."
$COMPOSE exec app bash -lc "\
  mkdir -p /var/www/html/storage/framework/sessions /var/www/html/storage/framework/views /var/www/html/storage/framework/cache /var/www/html/storage/content; \
  test -f /var/www/html/storage/content/hello.txt || echo 'contenido de prueba' > /var/www/html/storage/content/hello.txt; \
  chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/.env || true; \
  chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache || true; \
  chmod 644 /var/www/html/.env || true; \
  echo '  -> Storage y hello.txt creados y permisos ajustados.'"

echo "7) Limpiando caches de Laravel (config, route, view, cache)..."
$COMPOSE exec app bash -lc "php artisan config:clear || true; php artisan cache:clear || true; php artisan route:clear || true; php artisan view:clear || true"

echo "8) Reiniciando servicios (opcional pero recomendado para recoger cambios)..."
$COMPOSE restart app web || true

echo "9) Verificación rápida:"
echo " - Listado de rutas (busca /download):"
$COMPOSE exec app bash -lc "php artisan route:list --no-ansi | sed -n '1,200p'"

echo " - Comprobación de archivos:"
$COMPOSE exec app bash -lc "ls -la /var/www/html/storage/content || true; sed -n '1,40p' /var/www/html/storage/content/hello.txt || true; sed -n '1,120p' /var/www/html/.env || true"

echo " - Prueba curl al endpoint /download?filename=hello.txt (output guardado en /tmp/hello_downloaded.txt):"
curl -sS "http://localhost:8080/download?filename=hello.txt" -o /tmp/hello_downloaded.txt || true
echo "   -> /tmp/hello_downloaded.txt tamaño: $(stat -c%s /tmp/hello_downloaded.txt || echo 0) bytes"
echo "   -> Primeras 40 líneas:"
sed -n '1,40p' /tmp/hello_downloaded.txt || true

echo
echo "FINALIZADO. Si aún obtienes 500, pega la salida de:"
echo "  $COMPOSE exec app bash -lc 'tail -n 200 /var/www/html/storage/logs/laravel.log'"
echo "  $COMPOSE logs --tail=200 app"

