import { initializeApp } from "firebase/app";
import { getFirestore, doc, onSnapshot, setDoc, getDoc, serverTimestamp } from "firebase/firestore";
import { getAuth, signInAnonymously, onAuthStateChanged } from "firebase/auth";

export async function initFirebase(){
  const cfg = (window as any).FB_CONFIG || {};
  if (!cfg.apiKey) {
    console.error("[Firebase] window.FB_CONFIG no definido o sin apiKey. Revisa firebase-config.js");
    throw new Error("FB_CONFIG vacío (edita firebase-config.js).");
  }
  const app = initializeApp(cfg);
  const db = getFirestore(app);
  const auth = getAuth(app);
  await new Promise<void>((res)=>{
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) {
        try { await signInAnonymously(auth); } catch {}
      }
      unsub();
      res();
    });
  });
  const ref = doc(db, "state", "global");
  const subscribe = (cb:(s:any)=>void)=> onSnapshot(ref, (snap)=>{ if(snap.exists()) cb(snap.data()); });
  const save = async (state:any)=> setDoc(ref, { ...state, updatedAt: serverTimestamp() }, { merge:true });
  const ex = await getDoc(ref);
  if(!ex.exists()) await setDoc(ref, { updatedAt: serverTimestamp() }, { merge:true });
  return { save, subscribe };
}

