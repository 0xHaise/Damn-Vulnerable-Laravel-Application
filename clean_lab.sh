#!/usr/bin/env bash
set -euo pipefail

# clean_lab.sh
# Ejecutar desde la raíz del repo (donde está docker-compose.yml)
# Limpia contenedores, volúmenes y archivos generados del lab.

COMPOSE="docker compose"
PROJECT_DIR="$PWD"

echo "1) Deteniendo y eliminando contenedores del proyecto..."
$COMPOSE down -v --remove-orphans

echo "2) Eliminando imágenes de app y web (opcional, comenta si no quieres)..."
IMAGES=("lv_app" "lv_web")
for img in "${IMAGES[@]}"; do
  if docker images -q "$img" > /dev/null 2>&1; then
    echo "  -> Eliminando imagen $img"
    docker rmi -f "$img" || true
  fi
done

echo "3) Eliminando directorios generados por el lab..."
DIRS=("laravel" "storage" "tmp")
for d in "${DIRS[@]}"; do
  if [ -d "$PROJECT_DIR/$d" ]; then
    echo "  -> Eliminando $PROJECT_DIR/$d"
    rm -rf "$PROJECT_DIR/$d"
  fi
done

echo "4) Limpiando archivos temporales (descargas curl, logs locales)..."
FILES=("/tmp/hello_downloaded.txt")
for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    echo "  -> Eliminando $f"
    rm -f "$f"
  fi
done

echo "5) Eliminando volúmenes Docker adicionales (si los definiste fuera de compose)..."
# Lista volúmenes que empiecen con 'lv_' (según tu compose ejemplo)
VOLUMES=$(docker volume ls -q | grep '^lv_') || true
for v in $VOLUMES; do
  echo "  -> Eliminando volumen $v"
  docker volume rm -f "$v" || true
done

echo
echo "Limpieza completa. Puedes volver a correr el setup desde cero."

