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

  setStatus("Cargando pÃ¡ginas...");

  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${finalToken}`,
    },
  });

  if (!res.ok) {
    if (res.status === 401) {
      throw new Error("Airtable 401: token invÃ¡lido. Pulsa 'Cambiar token Airtable'.");
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
        bag.Coleccion ?? bag.ColecciÃ³n ?? bag.Tipo ?? bag.Tag ?? bag.Codigo ?? bag.CÃ³digo;
      if (!candidate) return true;
      return String(candidate).toUpperCase() === state.dataset;
    });
  state.index = 0;
  render();
  setStatus(`${state.records.length} pÃ¡ginas cargadas.`);
}

function animateFlip() {
  els.pageCard.classList.add("flip");
  setTimeout(() => els.pageCard.classList.remove("flip"), 220);
}

function render() {
  const total = state.records.length;

  if (!total) {
    els.pageNumber.textContent = "PÃ¡gina 0/0";
    els.placeName.textContent = "Sin resultados";
    els.coords.textContent = "Revisa la colecciÃ³n o el token.";
    els.placeUrl.hidden = true;
    els.stampDate.textContent = "";
    els.stampBadge.hidden = true;
    return;
  }

  const rec = state.records[state.index];
  const stamp = state.stamps[recordKey(rec)];

  els.datasetLabel.textContent = `ColecciÃ³n: ${state.dataset}`;
  els.pageNumber.textContent = `PÃ¡gina ${state.index + 1}/${total}`;
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
      : "AÃºn sin sello";
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
    setStatus("PÃ¡gina sellada.");
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
  setStatus("Token borrado. Recarga la pÃ¡gina para introducir uno nuevo.");
});

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("./sw.js").catch(() => {
    // ignore in prototype
  });
}

fetchRecords().catch((err) => {
  setStatus(`No se pudo cargar: ${err.message}`);
});

