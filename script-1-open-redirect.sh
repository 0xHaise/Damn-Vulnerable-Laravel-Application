#!/usr/bin/env bash
set -euo pipefail

# add_redirects_fixed.sh
# Inserta rutas Open Redirect (vulnerable + seguras) en laravel/routes/web.php
# Evita problemas de import duplicadas usando clases totalmente cualificadas.
# IDÉNTICO a add_redirects.sh pero corrige las maniobras que ocasionaban el error.
#
# Ejecutar desde la raíz del repo (donde está docker-compose.yml).

COMPOSE="docker compose"
ROUTES_FILE="./laravel/routes/web.php"
BACKUP_DIR="./backups_routes"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

echo "=== add_redirects_fixed.sh: Inicio ==="

if [ ! -f "$ROUTES_FILE" ]; then
  echo "ERROR: No encuentro $ROUTES_FILE. Asegúrate de haber corrido init_lab.sh previamente."
  exit 1
fi

# Backup
mkdir -p "$BACKUP_DIR"
cp "$ROUTES_FILE" "$BACKUP_DIR/routes.web.php.$TIMESTAMP.bak"
echo "Backup guardado en $BACKUP_DIR/routes.web.php.$TIMESTAMP.bak"

# Idempotencia: si ya contiene redirect-vuln saltar la inserción
if grep -q "redirect-vuln" "$ROUTES_FILE"; then
  echo "El bloque de redirect ya está presente en $ROUTES_FILE. No se añadirá de nuevo."
else
  echo "Añadiendo rutas Open Redirect (vulnerable y seguras) al final de $ROUTES_FILE ..."
  cat >> "$ROUTES_FILE" <<'PHP'

// ----------------- LAB: Open Redirect routes (added by add_redirects_fixed.sh) -----------------
/*
 * Vulnerable Open Redirect (intencional para lab)
 * Example: /redirect-vuln?url=http://evil.example.com
 *
 * Este bloque usa nombres totalmente cualificados para Request y Str
 * (\Illuminate\Http\Request y \Illuminate\Support\Str) para evitar
 * dependencias de declaraciones `use` y problemas de import duplicadas.
 */
Route::get('/redirect-vuln', function(\Illuminate\Http\Request $request) {
    $target = $request->input('url', '/');
    return redirect($target);
});

/*
 * Safe redirect: allow-list de hosts y validación de esquema
 */
Route::get('/redirect-safe', function(\Illuminate\Http\Request $request) {
    $target = $request->input('url', '');
    if (empty($target)) {
        return response('Missing url parameter', 400);
    }

    $parts = parse_url($target);
    if ($parts === false) {
        return response('Invalid URL', 400);
    }

    $allowedHosts = [
        'localhost',
        '127.0.0.1',
        'example.com',
    ];

    if (isset($parts['host'])) {
        $scheme = isset($parts['scheme']) ? strtolower($parts['scheme']) : '';
        $host = strtolower($parts['host']);
        if (!in_array($host, $allowedHosts, true) || !in_array($scheme, ['http','https'], true)) {
            return response('Redirect not allowed', 403);
        }
        return redirect($target);
    }

    if (isset($parts['path']) && \Illuminate\Support\Str::startsWith($parts['path'], '/')) {
        return redirect($target);
    }

    return response('Redirect not allowed', 403);
});

/*
 * Validate-only: solo rutas relativas (dentro del mismo sitio)
 */
Route::get('/redirect-validate', function(\Illuminate\Http\Request $request) {
    $target = $request->input('url', '/');
    if (filter_var($target, FILTER_VALIDATE_URL)) {
        return response('Only relative paths allowed', 403);
    }
    if (\Illuminate\Support\Str::startsWith($target, '/')) {
        return redirect($target);
    }
    return response('Invalid redirect target', 400);
});
// ---------------------------------------------------------------------------------------------
PHP

  echo "Rutas añadidas correctamente."
fi

# Limpiar caches y recargar rutas
echo "Limpiando caches de Laravel..."
$COMPOSE exec app bash -lc "php artisan config:clear || true; php artisan route:clear || true; php artisan cache:clear || true; php artisan view:clear || true"

# Reiniciar servicios
echo "Reiniciando servicios app y web..."
$COMPOSE restart app web || true

# Mostrar rutas añadidas
echo "Rutas agregadas (filtro 'redirect'):"
$COMPOSE exec app bash -lc "php artisan route:list --no-ansi | grep redirect || true"

# Pruebas automáticas básicas con curl (no sigue redirecciones)
echo
echo "Ejecutando pruebas curl básicas (no se siguen redirecciones):"
TESTS=(
  "http://localhost:8080/redirect-vuln?url=http://evil.example.com/"
  "http://localhost:8080/redirect-vuln?url=http%3A%2F%2Fevil.example.com%2Fphish"
  "http://localhost:8080/redirect-safe?url=http://evil.example.com/"
  "http://localhost:8080/redirect-safe?url=http://localhost:8080/"
  "http://localhost:8080/redirect-validate?url=/download?filename=hello.txt"
  "http://localhost:8080/redirect-validate?url=http://evil.example.com/"
)

for url in "${TESTS[@]}"; do
  printf "\n* Probando: %s\n" "$url"
  status=$(curl -s -o /dev/null -w "%{http_code}" -L --max-redirs 0 "$url" || true)
  headers=$(curl -s -D - -o /dev/null -L --max-redirs 0 "$url" || true)
  echo "  HTTP status: $status"
  echo "  Headers:"
  echo "$headers" | sed -n '1,120p'
done

echo
echo "Pruebas finalizadas. Backup original guardado en $BACKUP_DIR."
echo "Si quieres revertir, copia el backup:"
echo "  cp $BACKUP_DIR/routes.web.php.<TIMESTAMP>.bak $ROUTES_FILE"
echo "=== add_redirects_fixed.sh: Fin ==="

