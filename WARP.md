# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

Project overview
- This is a small React 18 single-page app. The entire app is defined in main.txt (TSX). It is mounted by shell-scripts/code/mount_entry.tsx into a <div id="app"> in index.html, using ReactDOM createRoot.
- Styling is via Tailwind CSS from CDN (no local build). No routing; all UI is a single component that renders tables/sections and supports print styling.
- State and persistence:
  - Primary component export default function IncofemarComparativa() (in main.txt) manages people, residential branches, devices, plan tiers, contacts, and theme via useState.
  - Persistence is layered: on load it tries to hydrate from https://raw.githubusercontent.com/diegocantarero/INCOFEMAR/main/state.json, then falls back to localStorage. On changes, it writes back to localStorage and (if a GH token is present in the browser) PUTs state.json to the GitHub Contents API.
  - Undo support exists for recent deletions (10s countdown).
- Build and deploy:
  - Builds are done with esbuild via CLI, mapping .txt files as TSX. Output goes to dist/ (dist/main.js + dist/index.html).
  - GitHub Pages deploy is automated on push to main via .github/workflows/pages.yml, which runs esbuild and uploads dist/ as the artifact.
  - docs/ contains a prebuilt copy of a previous bundle; CI now deploys dist/. Prefer dist/ for local preview.

Common terminal commands
- Prereqs (Node 18+). Install deps:
  - npm i
- One-command local build and preview (macOS-safe script):
  - bash shell-scripts/master_build.sh
  - What it does: installs esbuild if missing, bundles to dist/main.js, generates dist/index.html, copies assets/ to dist/assets/ (if present), starts a local server at http://127.0.0.1:8000, and opens the browser. PID is written to shell-scripts/state/devserver.pid.
  - Stop the dev server:
    - kill "$(cat shell-scripts/state/devserver.pid 2>/dev/null)" 2>/dev/null || true
- Minimal manual build (no server):
  1) Ensure mount entry exists (already in repo): shell-scripts/code/mount_entry.tsx
  2) Bundle:
     - npx esbuild shell-scripts/code/mount_entry.tsx \
       --bundle --format=esm --platform=browser --target=es2018 \
       --sourcemap --jsx=automatic --loader:.txt=tsx \
       --define:process.env.NODE_ENV="production" \
       --outfile=dist/main.js
  3) Create a minimal dist/index.html (if missing). See the CI workflow for the exact HTML snippet.
  4) Optional: copy static assets if you have them:
     - mkdir -p dist/assets && cp -R assets/. dist/assets/ 2>/dev/null || true
     - Note: If your images live under docs/assets/, you can sync them to assets/ first: mkdir -p assets && cp -R docs/assets/. assets/
- Linting and tests:
  - None are configured in package.json at this time (no lint/test commands).
- CI/CD (GitHub Pages):
  - Push to main triggers the Pages workflow, which builds with esbuild and deploys dist/.

Big-picture architecture details (for faster productivity)
- main.txt (TSX treated via esbuild):
  - Constants define per-line plan pricing (with/without ISV) and a map of residential internet offerings for Claro/Tigo.
  - Types: Person, Branch, PlanTier, DeviceKey. Defaults are seeded for people and branches.
  - Derived computations: directoryRows (per-person costs including financed devices and ISV), branchTotals/residenciaTotal, directoryTotalsSum, financeTotalsSum, totalSinEquipo. Currency formatting helper L() formats to Lempiras.
  - Persistence: localStorage key STORAGE_KEY = "incofemar_comp_vs_v6". Remote persistence uses window.GH_TOKEN or localStorage.GH_TOKEN to PUT state.json (content base64) to the repo via GitHub API (reads current sha first).
  - UI: Tailwind utility classes, drag-and-drop row reordering, device/plan selectors, residential plan selectors, theme toggle, print button (Ctrl+P tooltip), and print-specific CSS (A4 landscape, hide interactive UI when printing).
  - SmartImg: resilient image loader that falls back across multiple candidate paths, with <object> fallback if loading fails.
- shell-scripts/master_build.sh:
  - Portable build script that also manages deps (react/react-dom/esbuild), writes the mount entry, bundles, generates HTML, copies assets, starts a Python http.server on 127.0.0.1:8000, and logs to shell-scripts/logs/.
- .github/workflows/pages.yml:
  - Uses Node 18, runs esbuild with the same flags as local, ensures dist/.nojekyll and a 404.html copy, and copies assets/ into dist/assets/ if present.

Notes for assistants
- Edit source in main.txt (default export is the app). Do not manually edit files in dist/ or docs/; they are build artifacts.
- The project intentionally compiles TSX from a .txt file (using esbuild --loader:.txt=tsx). There is no TypeScript type checking step.
- Remote GitHub persistence is a runtime browser feature; it is not part of the Node build. You can set a GH token for manual testing in a browser console: localStorage.setItem('GH_TOKEN', '<token>').
- If the favicon/image is missing in local preview, ensure assets/Postpago.png exists (see asset copy notes above).

Place this file at: WARP.md in the repository root.

After writing the file, run:
- git add WARP.md
- git commit -m "docs: add WARP.md for Warp assistants"


Firebase integration
- The app uses the Firebase Web SDK via npm inside the bundle. Do not import the SDK in firebase-config.js.
- Configuration must be provided at runtime via window.FB_CONFIG in a plain script firebase-config.js at the repo root.
- Precedence at load: if FB_CONFIG is present, the app uses Firestore only (GitHub JSON and localStorage hydration are skipped). If FB_CONFIG is missing, it tries GitHub JSON first and falls back to localStorage.
- Local build: shell-scripts/master_build.sh copies firebase-config.js to dist/ if present; otherwise it writes a placeholder.
- CI build: .github/workflows/pages.yml copies firebase-config.js from the repo root to dist/ if present.
- Initialization happens in shell-scripts/code/firebase_client.ts using initializeApp(window.FB_CONFIG) and Anonymous Auth + Firestore sync.
- If window.FB_CONFIG is missing or incomplete, initialization logs a console error and throws early.

Reversion/fallback plan
- If npm SDK inclusion becomes problematic, you can keep window.FB_CONFIG and swap to CDN loader (gstatic) that calls initializeApp and exposes the app on window; however, the preferred path is npm + config file as above.

