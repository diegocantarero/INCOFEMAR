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
