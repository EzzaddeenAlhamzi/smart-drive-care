/**
 * Sensor bridge + Firestore persistence.
 *
 * Required env for Firestore:
 * - FIREBASE_SERVICE_ACCOUNT_JSON: service account JSON text
 *   OR
 * - GOOGLE_APPLICATION_CREDENTIALS: absolute path to service-account file
 *
 * Endpoints:
 * - GET /update?temp=&battery=&engineOil=&gearOil=
 * - GET /api/latest
 * - GET /api/health
 */

const http = require('http');
const admin = require('firebase-admin');

const PORT = process.env.PORT || 3000;
const ENGINE_OIL_LIMIT = 5000;
const GEAR_OIL_LIMIT = 20000;
const ALERT_COOLDOWN_MS = 60 * 1000;

let latest = {
  temp: 0,
  battery: 0,
  engineOil: 0,
  gearOil: 0,
  engineOilLimit: ENGINE_OIL_LIMIT,
  gearOilLimit: GEAR_OIL_LIMIT,
  updatedAt: null,
};

let db = null;
const lastAlertAt = new Map();

function initFirestore() {
  try {
    if (!admin.apps.length) {
      const jsonText = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
      if (jsonText) {
        const serviceAccount = JSON.parse(jsonText);
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
      } else {
        // Uses GOOGLE_APPLICATION_CREDENTIALS when present
        admin.initializeApp({
          credential: admin.credential.applicationDefault(),
        });
      }
    }
    db = admin.firestore();
    console.log('Firestore: connected');
  } catch (e) {
    console.warn('Firestore disabled (credentials missing/invalid).', e.message);
    db = null;
  }
}

function corsHeaders(extra = {}) {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Accept',
    ...extra,
  };
}

function toNumber(v, fallback = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

function classifyReading(r) {
  const statuses = [];
  if (r.temp > 95) statuses.push('TEMP_CRITICAL');
  else if (r.temp > 85) statuses.push('TEMP_WARNING');

  if (r.battery < 11) statuses.push('BATTERY_CRITICAL');
  else if (r.battery < 12) statuses.push('BATTERY_WARNING');

  const enginePct = (r.engineOil / ENGINE_OIL_LIMIT) * 100;
  const gearPct = (r.gearOil / GEAR_OIL_LIMIT) * 100;

  if (enginePct < 30) statuses.push('ENGINE_OIL_CRITICAL');
  else if (enginePct < 50) statuses.push('ENGINE_OIL_WARNING');

  if (gearPct < 30) statuses.push('GEAR_OIL_CRITICAL');
  else if (gearPct < 50) statuses.push('GEAR_OIL_WARNING');

  if (statuses.some((s) => s.endsWith('CRITICAL'))) return { level: 'CRITICAL', statuses };
  if (statuses.some((s) => s.endsWith('WARNING'))) return { level: 'WARNING', statuses };
  return { level: 'NORMAL', statuses: [] };
}

async function maybeCreateAlert(reading, classification) {
  if (!db) return;
  if (classification.level === 'NORMAL') return;

  const reason = classification.statuses.join('|');
  const key = `${classification.level}:${reason}`;
  const now = Date.now();
  const prev = lastAlertAt.get(key) ?? 0;
  if (now - prev < ALERT_COOLDOWN_MS) return;
  lastAlertAt.set(key, now);

  await db.collection('alerts').add({
    level: classification.level,
    reason,
    status: 'ACTIVE',
    reading,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function persistReading(reading) {
  if (!db) return;

  const classification = classifyReading(reading);
  const data = {
    ...reading,
    level: classification.level,
    flags: classification.statuses,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('sensor_readings').add(data);
  await db.collection('latest').doc('current').set(data, { merge: true });
  await maybeCreateAlert(reading, classification);
}

async function readLatestFromFirestore() {
  if (!db) return null;
  const snap = await db.collection('latest').doc('current').get();
  if (!snap.exists) return null;
  const data = snap.data();
  return {
    temp: toNumber(data.temp),
    battery: toNumber(data.battery),
    engineOil: toNumber(data.engineOil),
    gearOil: toNumber(data.gearOil),
    engineOilLimit: toNumber(data.engineOilLimit, ENGINE_OIL_LIMIT),
    gearOilLimit: toNumber(data.gearOilLimit, GEAR_OIL_LIMIT),
    updatedAt: data.updatedAt ?? null,
    level: data.level ?? 'NORMAL',
    flags: Array.isArray(data.flags) ? data.flags : [],
  };
}

initFirestore();

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || '/', `http://localhost:${PORT}`);

  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders());
    res.end();
    return;
  }

  if (url.pathname === '/update' || url.pathname.startsWith('/update')) {
    const reading = {
      temp: toNumber(url.searchParams.get('temp')),
      battery: toNumber(url.searchParams.get('battery')),
      engineOil: Math.max(0, Math.round(toNumber(url.searchParams.get('engineOil')))),
      gearOil: Math.max(0, Math.round(toNumber(url.searchParams.get('gearOil')))),
      engineOilLimit: ENGINE_OIL_LIMIT,
      gearOilLimit: GEAR_OIL_LIMIT,
      updatedAt: new Date().toISOString(),
    };

    latest = reading;

    try {
      await persistReading(reading);
      res.writeHead(200, corsHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
      res.end('ok');
    } catch (e) {
      console.error('Persist error:', e.message);
      res.writeHead(500, corsHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
      res.end('persist_error');
    }
    return;
  }

  if (url.pathname === '/api/latest' || url.pathname === '/api/latest/') {
    try {
      const remote = await readLatestFromFirestore();
      const payload = remote ?? latest;
      res.writeHead(200, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
      res.end(JSON.stringify(payload));
    } catch (e) {
      console.error('Read latest error:', e.message);
      res.writeHead(200, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
      res.end(JSON.stringify(latest));
    }
    return;
  }

  if (url.pathname === '/api/health' || url.pathname === '/api/health/') {
    const body = JSON.stringify({
      ok: true,
      firestoreConnected: Boolean(db),
      now: new Date().toISOString(),
    });
    res.writeHead(200, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
    res.end(body);
    return;
  }

  if (url.pathname === '/' || url.pathname === '') {
    res.writeHead(200, corsHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
    res.end('Smart Drive Care sensor bridge. GET /api/latest — target for ESP: /update?...');
    return;
  }

  res.writeHead(404, corsHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
  res.end('not found');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Sensor bridge: http://localhost:${PORT}`);
  console.log('  ESP/Wokwi → GET /update?temp=&battery=&engineOil=&gearOil=');
  console.log('  Flutter   → GET /api/latest');
  console.log('  Health    → GET /api/health');
});
