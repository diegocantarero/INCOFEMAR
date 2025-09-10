export type AppState = {
  people?: any[];
  dark?: boolean;
  branches?: any[];
  mobilePlan?: string;
  devicesByPerson?: Record<string, any[]>;
  planByPerson?: Record<string, any>;
  contactsByPerson?: Record<string, any>;
  updatedAt?: number; // epoch ms
  origin?: string; // clientId
  _v?: number; // schema version
};

export const STORAGE_KEY = "incofemar_comp_vs_v6";
const VERSION = 2;

export function now() {
  return Date.now();
}

export function clientId() {
  try {
    const k = "__SAM_CLIENT_ID__";
    let cid = localStorage.getItem(k);
    if (!cid) {
      cid = `${Math.random().toString(36).slice(2, 8)}_${Date.now()}`;
      localStorage.setItem(k, cid);
    }
    return cid;
  } catch {
    return "unknown";
  }
}

export function getLocal(): AppState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { _v: VERSION };
    const s: AppState = JSON.parse(raw);
    if (!("_v" in (s as any))) (s as any)._v = VERSION;
    return s;
  } catch {
    return { _v: VERSION };
  }
}

export function setLocal(state: AppState) {
  try {
    const snap = { ...state, _v: VERSION } as any;
    localStorage.setItem(STORAGE_KEY, JSON.stringify(snap));
  } catch {}
}

// Mezcla superficial con preferencia al más fresco (por updatedAt) y mayor "densidad" de datos.
export function mergeStates(local: AppState, remote: AppState): AppState {
  const lu = Number(local?.updatedAt || 0);
  const ru = Number(remote?.updatedAt || 0);
  if (ru > lu) return { ...local, ...remote };
  if (lu > ru) return { ...remote, ...local };
  const score = (s: AppState) =>
    Number(!!s.people) +
    Number(!!s.branches) +
    Number(!!s.devicesByPerson) +
    Number(!!s.planByPerson) +
    Number(!!s.contactsByPerson);
  return score(remote) > score(local) ? { ...local, ...remote } : { ...remote, ...local };
}

export function debounce<T extends (...a: any[]) => any>(fn: T, ms = 800) {
  let q: any = null;
  return ((...a: any[]) => {
    if (q) clearTimeout(q);
    q = setTimeout(() => fn(...a), ms);
  }) as T;
}

