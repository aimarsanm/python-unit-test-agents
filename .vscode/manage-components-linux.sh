#!/usr/bin/env bash
set -euo pipefail

mode=""
wants_agents="No"
wants_skills="No"
wants_readme="No"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) mode="${2:-}"; shift 2 ;;
    --wants-agents) wants_agents="${2:-}"; shift 2 ;;
    --wants-skills) wants_skills="${2:-}"; shift 2 ;;
    --wants-readme) wants_readme="${2:-}"; shift 2 ;;
    *) echo "Argumento no reconocido: $1" >&2; exit 1 ;;
  esac
done

if [[ "$mode" != download && "$mode" != update ]]; then
  echo "Uso: $0 --mode download|update [--wants-agents Sí|No] [--wants-skills Sí|No] [--wants-readme Sí|No]" >&2
  exit 1
fi

repository_url='https://github.com/aimarsanm/python-unit-test-agents.git'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(dirname "$script_dir")"
inventory_path="$script_dir/installed-components.json"

fail() { echo "$1" >&2; exit 1; }

cd "$repository_root"

sources=()
destinations=()
installed_versions=()

if [[ "$mode" == download ]]; then
  if [[ "$wants_agents" == "Sí" ]]; then
    sources+=('.github/agents'); destinations+=('.github/agents')
  fi
  if [[ "$wants_skills" == "Sí" ]]; then
    sources+=('skills'); destinations+=('.github/skills')
  fi
  if [[ "$wants_readme" == "Sí" ]]; then
    sources+=('README.md'); destinations+=('.')
  fi
  if [[ ${#sources[@]} -eq 0 ]]; then
    echo 'No has seleccionado nada para descargar.'
    exit 0
  fi
else
  if [[ ! -f "$inventory_path" ]]; then
    echo 'No hay un inventario de componentes instalados.'
    exit 0
  fi
  # El inventario se escribe con un objeto por línea, así que se puede parsear línea a línea.
  re_source='"Source": *"([^"]*)"'
  re_destination='"Destination": *"([^"]*)"'
  re_version='"Version": *"([^"]*)"'
  while IFS= read -r line; do
    if [[ $line =~ $re_source ]]; then
      sources+=("${BASH_REMATCH[1]}")
      if [[ $line =~ $re_destination ]]; then destinations+=("${BASH_REMATCH[1]}"); fi
      if [[ $line =~ $re_version ]]; then installed_versions+=("${BASH_REMATCH[1]}"); else installed_versions+=(''); fi
    fi
  done < "$inventory_path"
fi

git fetch "$repository_url" main || fail 'No se pudieron consultar las versiones remotas.'

remote_versions=()
update_indexes=()
for i in "${!sources[@]}"; do
  src="${sources[i]}"
  remote=$(git rev-parse "FETCH_HEAD:$src") || fail "No se pudo obtener la versión remota de $src."
  [[ -n "$remote" ]] || fail "No se pudo obtener la versión remota de $src."
  remote_versions+=("$remote")
  installed="${installed_versions[i]:-}"
  if [[ "$mode" == download || -z "$installed" || "$installed" != "$remote" ]]; then
    if [[ "$mode" == update ]]; then
      echo "¡Hay cambios en: $src!"
    fi
    update_indexes+=("$i")
  fi
done

if [[ "$mode" == update ]]; then
  if [[ ${#update_indexes[@]} -eq 0 ]]; then
    echo 'No hay actualizaciones en tus componentes instalados. Todo está al día.'
    exit 0
  fi
  read -r -p '¿Deseas actualizar los componentes? (Sí/No) ' confirmation || confirmation=''
  case "$confirmation" in
    s|S|si|Si|SI|sí|Sí|SÍ|y|Y|yes|Yes|YES) ;;
    *)
      echo 'Actualización omitida por el usuario.'
      exit 0
      ;;
  esac
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

for i in "${update_indexes[@]}"; do
  src="${sources[i]}"
  dest="${destinations[i]}"
  expanded="$tmp_dir/expanded"
  rm -rf "$expanded"
  mkdir -p "$expanded"

  git archive --format=tar FETCH_HEAD -- "$src" | tar -x -C "$expanded" || fail "No se pudo descargar $src."
  source_path="$expanded/$src"
  [[ -e "$source_path" ]] || fail "No se encontró la ruta: $src"

  if [[ "$dest" != "." ]]; then
    mkdir -p "$dest"
  fi
  if [[ -d "$source_path" ]]; then
    cp -R "$source_path/." "$dest/"
  else
    cp "$source_path" "$dest/"
  fi
  echo "Actualizado con éxito: $src"
done

last=$(( ${#sources[@]} - 1 ))
{
  echo '['
  for i in "${!sources[@]}"; do
    sep=','
    if [[ $i -eq $last ]]; then sep=''; fi
    printf '  {"Source": "%s", "Destination": "%s", "Version": "%s"}%s\n' \
      "${sources[i]}" "${destinations[i]}" "${remote_versions[i]}" "$sep"
  done
  echo ']'
} > "$inventory_path"

if [[ "$mode" == download ]]; then
  echo '¡Descarga completada y componentes guardados en el inventario!'
fi