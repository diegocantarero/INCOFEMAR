#!/usr/bin/env bash
set -Eeuo pipefail

# === Config & rutas (dinámicas para Warp) ===
PROJ="${PROJ_OVERRIDE:-$PWD}"
[[ -d "$PROJ" ]] || { echo "❌ Directorio inválido: $PROJ"; exit 1; }
cd "$PROJ"

ART="$PROJ/shell-scripts"; mkdir -p "$ART"/{logs,code,state}
RUN="$ART/logs/web_master_run_$(date +%Y%m%d_%H%M%S).log"
ERR="$ART/logs/web_master_err_$(date +%Y%m%d_%H%M%S).log"
: >"$RUN"; : >"$ERR"
say(){ echo -e "$*" | tee -a "$RUN"; }
warn(){ echo -e "⚠ $*" | tee -a "$ERR"; }
fail(){ echo -e "❌ $*" | tee -a "$ERR"; }

say "== SAM 🧠 MASTER BUILD (React18 + esbuild · Warp) =="
say "Proyecto → $PROJ"
[[ -f main.txt ]] || { fail "No existe main.txt en $PROJ"; exit 1; }

# Mantener despierto (macOS)
if command -v caffeinate >/dev/null 2>&1; then caffeinate -dimsu -w $$ & CAFF=$!; fi
trap '[[ -n "${CAFF:-}" ]] && kill "$CAFF" 2>/dev/null || true' EXIT

# === Node/NPM + deps ===
if ! command -v node >/dev/null 2>&1; then
  say "Node no encontrado. Intentando instalar…"
  if command -v brew >/dev/null 2>&1; then brew install node >>"$RUN" 2>>"$ERR" || true; fi
  if ! command -v node >/dev/null 2>&1 && [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    # shellcheck disable=SC1090
    source "$HOME/.nvm/nvm.sh"; nvm install --lts >>"$RUN" 2>>"$ERR" || true; nvm use --lts >>"$RUN" 2>>"$ERR" || true
  fi
fi
command -v node >/dev/null 2>&1 || { fail "Node no disponible."; exit 1; }
say "Node: $(node -v)  NPM: $(npm -v)"

[[ -f package.json ]] || { say "Creando package.json…"; npm init -y >>"$RUN" 2>>"$ERR" || true; }

need_react=0; node -e "require('react');require('react-dom')" >>"$RUN" 2>>"$ERR" || need_react=1
(( need_react )) && { say "Instalando react@18 y react-dom@18…"; npm i react@18 react-dom@18 >>"$RUN" 2>>"$ERR" || fail "Fallo instalando react/react-dom"; }

npx --yes esbuild --version >>"$RUN" 2>>"$ERR" || { say "Instalando esbuild…"; npm i -D esbuild >>"$RUN" 2>>"$ERR" || fail "Fallo instalando esbuild"; }

# === Entry de montaje ===
ENTRY="$ART/code/mount_entry.tsx"; mkdir -p "$(dirname "$ENTRY")"
cat > "$ENTRY" <<'TSX'
// Auto-generado por SAM 🧠 (Warp)
import * as React from "react";
import { createRoot } from "react-dom/client";
import App from "../../main.txt"; // tratado como TSX por esbuild (loader .txt=tsx)

function ensureAppRoot(): HTMLElement {
  let el = document.getElementById("app");
  if (!el) {
    el = document.createElement("div");
    el.id = "app";
    document.body.appendChild(el);
  }
  return el as HTMLElement;
}

createRoot(ensureAppRoot()).render(React.createElement(App));
TSX

# === Build con esbuild (bundle completo, ESM, target es2018) ===
mkdir -p dist
BUILDLOG="$ART/logs/esbuild_$(date +%Y%m%d_%H%M%S).log"
say "Compilando TSX → dist/main.js …"
npx --yes esbuild "$ENTRY" \
  --bundle \
  --format=esm \
  --platform=browser \
  --target=es2018 \
  --sourcemap \
  --jsx=automatic \
  --loader:.txt=tsx \
  --define:process.env.NODE_ENV=\"production\" \
  --outfile=dist/main.js >>"$BUILDLOG" 2>>"$ERR" || { fail "esbuild falló (ver $BUILDLOG)"; }

[[ -s dist/main.js ]] || { fail "No se generó dist/main.js"; exit 1; }

# === index.html con Tailwind CDN ===
BUST="$(date +%s)"
cat > dist/index.html <<HTML
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>INCOFEMAR · Comparativa</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link rel="icon" href="./assets/Postpago.png">
  <style>
    :root{--c:#0e5fd8} body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;line-height:1.5;margin:0;background:#0b1020;color:#f5f7fb}
    #app{min-height:100vh}
    a{color:var(--c)}
  </style>
</head>
<body>
  <div id="app"></div>
  <script type="module" src="./main.js?v=${BUST}"></script>
</body>
</html>
HTML

# === Copiar assets/ → dist/assets/ ===
if [[ -d assets ]]; then
  say "Copiando assets/ → dist/assets/ …"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete assets/ dist/assets/ >>"$RUN" 2>>"$ERR" || true
  else
    mkdir -p dist/assets
    if command -v tar >/dev/null 2>&1; then (cd assets && tar cf - .) | (cd dist/assets && tar xf -) 2>>"$ERR" || true
    else cp -R assets/. dist/assets/ 2>>"$ERR" || true
    fi
  fi
else
  warn "No existe assets/ (continuo)."
fi

# === Servidor local (fijo 8000) + auto-open ===
PORT=8000
# Terminar servidores previos de este proyecto en cualquier puerto
if command -v pgrep >/dev/null 2>&1; then
  for pid in $(pgrep -f 'python(3)?[[:space:]]+-m[[:space:]]+http\.server' || true); do
    cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')"
    if [[ "$cwd" == "$PROJ/dist" ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  done
fi
# Si 8000 está ocupado, terminar el proceso que escucha en ese puerto
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  pid8000="$(lsof -t -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "${pid8000:-}" ]]; then
    kill "$pid8000" 2>/dev/null || true
    sleep 0.3
  fi
fi
( cd dist && python3 -m http.server "$PORT" --bind 127.0.0.1 >>"$RUN" 2>>"$ERR" & echo $! > "$ART/state/devserver.pid" )
sleep 0.7
PID="$(cat "$ART/state/devserver.pid" 2>/dev/null || true)"
URL="http://127.0.0.1:$PORT/"

if command -v open >/dev/null 2>&1; then open "$URL" >/dev/null 2>&1 || true; fi

# === Verificaciones ===
ok=1
[[ -s dist/index.html ]] || { fail "Falta dist/index.html"; ok=0; }
[[ -s dist/main.js   ]] || { fail "Falta dist/main.js";   ok=0; }

if command -v curl >/dev/null 2>&1; then
  code="$(curl -s -o /dev/null -w '%{http_code}' "$URL")" || code="000"
  say "HTTP GET / → $code"
  [[ "$code" == "200" ]] || warn "El servidor respondió $code; abre la URL para revisar."
  if [[ -f dist/assets/Postpago.png ]]; then
    acode="$(curl -s -o /dev/null -w '%{http_code}' "${URL}assets/Postpago.png")" || acode="000"
    say "HTTP GET /assets/Postpago.png → $acode"
  fi
else
  warn "curl no disponible; omito chequeos HTTP."
fi

# === Resumen ===
size_js="$(wc -c < dist/main.js | tr -d ' ' || echo 0)"
say ""
say "=== RESUMEN SAM 🧠 ==="
say "Proyecto:   $PROJ"
say "Bundle:     dist/main.js (${size_js} bytes)"
say "HTML:       dist/index.html"
[[ -f dist/assets/Postpago.png ]] && say "Imagen:    ✓ dist/assets/Postpago.png" || say "Imagen:    (no encontrada en dist/assets)"
say "Server:     $URL (PID=${PID:-?})"
say "Logs:       $RUN"
say "Errores:    $ERR"
say ""
say "Criterios:"
say "  - dist/index.html existe:            $([[ -s dist/index.html ]] && echo '✅' || echo '❌')"
say "  - dist/main.js cargado:              $([[ -s dist/main.js   ]] && echo '✅' || echo '❌')"
say "  - /assets/Postpago.png disponible:   $([[ -f dist/assets/Postpago.png ]] && echo '✅' || echo '⚠'))"
say "  - Server en 127.0.0.1:$PORT:         ✅ (abre en el navegador)"
say ""
say "TIP: Para detener el server: kill '${PID:-$(cat "$ART/state/devserver.pid" 2>/dev/null || echo "")}' 2>/dev/null || true"

exit $(( ok ? 0 : 1 ))

