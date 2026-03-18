# Ejecuta este script en PowerShell dentro de una carpeta vacía.

$ErrorActionPreference = 'Stop'

Write-Host 'Creando proyecto Pasaporte Digital...'

@'
<!doctype html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
    <title>Pasaporte Digital</title>
    <meta name="theme-color" content="#6e2b1f" />
    <link rel="manifest" href="manifest.webmanifest" />
    <link rel="stylesheet" href="styles.css" />
  </head>
  <body>
    <main class="app">
      <header class="app__header">
        <h1>Pasaporte Digital</h1>
        <p id="datasetLabel">Colección: LOG</p>
      </header>

      <section class="controls">
        <label for="datasetSelect">Colección</label>
        <select id="datasetSelect">
          <option value="LOG">LOG</option>
          <option value="RIO">RIO</option>
          <option value="ESP">ESP</option>
          <option value="EUR">EUR</option>
          <option value="MUN">MUN</option>
          <option value="MAR">MAR</option>
        </select>
        <button id="resetTokenBtn" type="button">Cambiar token Airtable</button>
      </section>

      <section class="passport" id="passport">
        <article class="page" id="pageCard">
          <div class="page__top">
            <p class="page__number" id="pageNumber">Página 1/1</p>
            <span class="stamp" id="stampBadge" hidden>SELLADO</span>
          </div>
          <h2 id="placeName">Cargando...</h2>
          <p id="coords">—</p>
          <a id="placeUrl" href="#" target="_blank" rel="noreferrer noopener" hidden>Abrir enlace</a>
          <p id="stampDate"></p>

          <div class="page__actions">
            <button id="stampBtn" type="button">Sellar</button>
          </div>
        </article>
      </section>

      <nav class="pager">
        <button id="prevBtn" type="button">◀ Anterior</button>
        <button id="nextBtn" type="button">Siguiente ▶</button>
      </nav>

      <p class="status" id="status"></p>
    </main>

    <script src="app.js" type="module"></script>
  </body>
</html>

'@ | Set-Content -Encoding UTF8 'index.html'

@'
:root {
  color-scheme: light;
  --ink: #2a1d17;
  --bg: #efe7dd;
  --paper: #f8f3eb;
  --accent: #6e2b1f;
}

* { box-sizing: border-box; }

body {
  margin: 0;
  font-family: Inter, system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
  background: radial-gradient(circle at top, #fff9f2, var(--bg));
  color: var(--ink);
}

.app {
  min-height: 100dvh;
  padding: 1rem;
  max-width: 460px;
  margin: 0 auto;
  display: grid;
  gap: 1rem;
}

.app__header h1 { margin: 0; font-size: 1.6rem; }
.app__header p { margin: 0.3rem 0 0; opacity: 0.8; }

.controls { display: grid; gap: 0.4rem; }
select, button {
  font: inherit;
  border-radius: 10px;
  border: 1px solid #c8b7a7;
  padding: 0.65rem 0.8rem;
}

#resetTokenBtn {
  background: #fff;
  color: var(--ink);
}

.passport { perspective: 1200px; }
.page {
  background: var(--paper);
  border: 2px solid #d8c5af;
  border-radius: 14px;
  padding: 1rem;
  min-height: 300px;
  box-shadow: 0 8px 20px rgba(0,0,0,0.08);
  transition: transform 0.35s ease;
}

.page.flip { transform: rotateY(-14deg); }

.page__top {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.page__number { margin: 0; opacity: .7; font-size: .95rem; }

.stamp {
  color: white;
  background: var(--accent);
  border-radius: 999px;
  padding: 0.2rem 0.6rem;
  font-weight: 700;
  font-size: 0.75rem;
}

#placeName { margin: .8rem 0 .4rem; font-size: 1.5rem; }
#coords { margin: 0 0 .5rem; opacity: .85; }
#stampDate { font-size: .9rem; color: #7a4d37; }

#placeUrl { color: var(--accent); font-weight: 600; }

.page__actions {
  margin-top: 1rem;
}

#stampBtn {
  width: 100%;
  background: var(--accent);
  color: #fff;
  border-color: var(--accent);
}

.pager {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: .5rem;
}

.status {
  margin: 0;
  min-height: 1.2rem;
  font-size: .9rem;
  opacity: .8;
}

'@ | Set-Content -Encoding UTF8 'styles.css'

@'
const AIRTABLE_BASE_ID = "appnTZhjlhMsjKmuR";
const AIRTABLE_TABLE_ID = "tblJRM15UIYHuX9mU";
const AIRTABLE_VIEW_ID = "viwHZFsEpXlWVRFWO";

const state = {
  records: [],
  index: 0,
  dataset: "LOG",
  stamps: JSON.parse(localStorage.getItem("passport-stamps") ?? "{}"),
};

const els = {
  datasetSelect: document.getElementById("datasetSelect"),
  resetTokenBtn: document.getElementById("resetTokenBtn"),
  datasetLabel: document.getElementById("datasetLabel"),
  pageNumber: document.getElementById("pageNumber"),
  placeName: document.getElementById("placeName"),
  coords: document.getElementById("coords"),
  placeUrl: document.getElementById("placeUrl"),
  stampDate: document.getElementById("stampDate"),
  stampBadge: document.getElementById("stampBadge"),
  stampBtn: document.getElementById("stampBtn"),
  prevBtn: document.getElementById("prevBtn"),
  nextBtn: document.getElementById("nextBtn"),
  status: document.getElementById("status"),
  pageCard: document.getElementById("pageCard"),
};

function getToken() {
  return localStorage.getItem("airtable-token") || "";
}

function setStatus(text) {
  els.status.textContent = text;
}

function recordKey(record) {
  return `${state.dataset}:${record.id}`;
}

function saveStamps() {
  localStorage.setItem("passport-stamps", JSON.stringify(state.stamps));
}

function parseRecord(record) {
  const f = record.fields;
  return {
    id: record.id,
    name: f.Nombre ?? "Sin nombre",
    coords: f.Coordenadas ?? "",
    url: f.URL ?? "",
    sealDateFromAirtable: f.Sello ?? "",
  };
}

async function fetchRecords() {
  const token = getToken();

  if (!token) {
    const typed = window.prompt(
      "Pega tu Airtable Personal Access Token (solo se guarda en tu navegador):"
    );
    if (!typed) {
      setStatus("Necesitas token de Airtable para cargar datos.");
      return;
    }
    localStorage.setItem("airtable-token", typed.trim());
  }

  const finalToken = getToken();
  const url = new URL(
    `https://api.airtable.com/v0/${AIRTABLE_BASE_ID}/${AIRTABLE_TABLE_ID}`
  );
  url.searchParams.set("view", AIRTABLE_VIEW_ID);
  url.searchParams.set("maxRecords", "200");

  setStatus("Cargando páginas...");

  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${finalToken}`,
    },
  });

  if (!res.ok) {
    if (res.status === 401) {
      throw new Error("Airtable 401: token inválido. Pulsa 'Cambiar token Airtable'.");
    }
    if (res.status === 403) {
      throw new Error(
        "Airtable 403: el token existe pero no tiene permisos sobre la base/tabla. Revisa scopes y acceso."
      );
    }
    throw new Error(`Error Airtable ${res.status}`);
  }

  const data = await res.json();
  state.records = data.records
    .map((record) => ({ ...parseRecord(record), rawFields: record.fields }))
    .filter((r) => {
      const bag = r.rawFields;
      const candidate =
        bag.Coleccion ?? bag.Colección ?? bag.Tipo ?? bag.Tag ?? bag.Codigo ?? bag.Código;
      if (!candidate) return true;
      return String(candidate).toUpperCase() === state.dataset;
    });
  state.index = 0;
  render();
  setStatus(`${state.records.length} páginas cargadas.`);
}

function animateFlip() {
  els.pageCard.classList.add("flip");
  setTimeout(() => els.pageCard.classList.remove("flip"), 220);
}

function render() {
  const total = state.records.length;

  if (!total) {
    els.pageNumber.textContent = "Página 0/0";
    els.placeName.textContent = "Sin resultados";
    els.coords.textContent = "Revisa la colección o el token.";
    els.placeUrl.hidden = true;
    els.stampDate.textContent = "";
    els.stampBadge.hidden = true;
    return;
  }

  const rec = state.records[state.index];
  const stamp = state.stamps[recordKey(rec)];

  els.datasetLabel.textContent = `Colección: ${state.dataset}`;
  els.pageNumber.textContent = `Página ${state.index + 1}/${total}`;
  els.placeName.textContent = rec.name;
  els.coords.textContent = rec.coords || "Coordenadas no disponibles";

  if (rec.url) {
    els.placeUrl.href = rec.url;
    els.placeUrl.hidden = false;
  } else {
    els.placeUrl.hidden = true;
  }

  if (stamp) {
    els.stampBadge.hidden = false;
    els.stampDate.textContent = `Sellado el ${new Date(stamp).toLocaleDateString("es-ES")}`;
    els.stampBtn.textContent = "Quitar sello";
  } else {
    els.stampBadge.hidden = true;
    els.stampDate.textContent = rec.sealDateFromAirtable
      ? `Sello BD: ${rec.sealDateFromAirtable}`
      : "Aún sin sello";
    els.stampBtn.textContent = "Sellar";
  }

  els.prevBtn.disabled = state.index === 0;
  els.nextBtn.disabled = state.index >= total - 1;
}

function toggleStamp() {
  const rec = state.records[state.index];
  if (!rec) return;

  const key = recordKey(rec);
  if (state.stamps[key]) {
    delete state.stamps[key];
    setStatus("Sello quitado.");
  } else {
    state.stamps[key] = new Date().toISOString();
    setStatus("Página sellada.");
  }
  saveStamps();
  render();
}

els.prevBtn.addEventListener("click", () => {
  if (state.index > 0) {
    state.index -= 1;
    animateFlip();
    render();
  }
});

els.nextBtn.addEventListener("click", () => {
  if (state.index < state.records.length - 1) {
    state.index += 1;
    animateFlip();
    render();
  }
});

els.stampBtn.addEventListener("click", toggleStamp);

els.datasetSelect.addEventListener("change", async (e) => {
  state.dataset = e.target.value;
  try {
    await fetchRecords();
  } catch (err) {
    setStatus(`No se pudo cargar: ${err.message}`);
  }
});

els.resetTokenBtn.addEventListener("click", () => {
  localStorage.removeItem("airtable-token");
  setStatus("Token borrado. Recarga la página para introducir uno nuevo.");
});

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("./sw.js").catch(() => {
    // ignore in prototype
  });
}

fetchRecords().catch((err) => {
  setStatus(`No se pudo cargar: ${err.message}`);
});

'@ | Set-Content -Encoding UTF8 'app.js'

@'
{
  "name": "Pasaporte Digital",
  "short_name": "Pasaporte",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#efe7dd",
  "theme_color": "#6e2b1f",
  "icons": []
}

'@ | Set-Content -Encoding UTF8 'manifest.webmanifest'

@'
const CACHE_NAME = "passport-proto-v1";
const ASSETS = ["./", "./index.html", "./styles.css", "./app.js", "./manifest.webmanifest"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS)));
});

self.addEventListener("fetch", (event) => {
  event.respondWith(caches.match(event.request).then((cached) => cached || fetch(event.request)));
});

'@ | Set-Content -Encoding UTF8 'sw.js'

@'
@echo off
setlocal
cd /d %~dp0

echo Iniciando servidor en: %cd%
echo Abre: http://localhost:8080/index.html

python -m http.server 8080
if errorlevel 1 (
  py -m http.server 8080
)

'@ | Set-Content -Encoding UTF8 'run_local.bat'

Write-Host 'Listo. Archivos creados.'
Write-Host 'Ahora abre run_local.bat o ejecuta: python -m http.server 8080'
