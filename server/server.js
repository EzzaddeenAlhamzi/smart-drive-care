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
 * - GET /api/alerts
 * - GET /api/alerts/ack?id=<alertDocId>
 * - GET /api/history?period=today|week|month&limit=...
 * - GET /api/settings
 * - POST /api/settings
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
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
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

function flagToLevel(flag) {
  return String(flag || '').includes('CRITICAL') ? 'CRITICAL' : 'WARNING';
}

async function maybeCreateAlert(reading, classification) {
  if (!db) return;
  if (!classification.statuses || classification.statuses.length === 0) return;

  const now = Date.now();
  for (const reason of classification.statuses) {
    const level = flagToLevel(reason);
    const key = `${level}:${reason}`;
    const prev = lastAlertAt.get(key) ?? 0;
    if (now - prev < ALERT_COOLDOWN_MS) {
      continue;
    }
    lastAlertAt.set(key, now);

    await db.collection('alerts').add({
      level,
      reason,
      status: 'ACTIVE',
      acknowledged: false,
      reading,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

function reasonToMessage(reason) {
  const r = reason || '';
  if (r.includes('TEMP_CRITICAL')) return 'ارتفاع درجة حرارة المحرك بشكل خطير';
  if (r.includes('TEMP_WARNING')) return 'ارتفاع حرارة المحرك';
  if (r.includes('BATTERY_CRITICAL')) return 'انخفاض حرج في جهد البطارية';
  if (r.includes('BATTERY_WARNING')) return 'انخفاض جهد البطارية';
  if (r.includes('ENGINE_OIL_CRITICAL')) return 'انخفاض حرج في زيت المحرك';
  if (r.includes('ENGINE_OIL_WARNING')) return 'انخفاض زيت المحرك';
  if (r.includes('GEAR_OIL_CRITICAL')) return 'انخفاض حرج في زيت القير';
  if (r.includes('GEAR_OIL_WARNING')) return 'انخفاض زيت القير';
  return 'تنبيه من الحساسات';
}

function reasonToAction(reason) {
  const r = reason || '';
  if (r.includes('TEMP')) {
    return 'افحص نظام التبريد وأوقف المركبة إذا استمرت الحرارة بالارتفاع.';
  }
  if (r.includes('BATTERY')) {
    return 'افحص البطارية والدينمو والتوصيلات الكهربائية.';
  }
  if (r.includes('ENGINE_OIL')) {
    return 'افحص مستوى زيت المحرك وقم بالتغيير أو التعبئة عند الحاجة.';
  }
  if (r.includes('GEAR_OIL')) {
    return 'افحص زيت القير وجدول الصيانة الخاص بناقل الحركة.';
  }
  return 'راجع نظام الصيانة واتخذ الإجراء المناسب.';
}

function reasonToSensorType(reason) {
  const r = reason || '';
  if (r.includes('TEMP')) return 'TEMP';
  if (r.includes('BATTERY')) return 'BATTERY';
  if (r.includes('ENGINE_OIL')) return 'OIL';
  if (r.includes('GEAR_OIL')) return 'TRANS';
  return 'GENERIC';
}

async function readAlertsFromFirestore(limit = 200) {
  if (!db) return [];
  const snap = await db
    .collection('alerts')
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();
  return snap.docs.map((doc) => {
    const d = doc.data();
    const createdAt =
      d.createdAt && typeof d.createdAt.toDate === 'function'
        ? d.createdAt.toDate().toISOString()
        : null;
    return {
      id: doc.id,
      level: d.level ?? 'WARNING',
      status: d.status ?? 'ACTIVE',
      acknowledged: Boolean(d.acknowledged ?? false) || d.status === 'ACKNOWLEDGED',
      reason: d.reason ?? '',
      message: reasonToMessage(d.reason),
      suggestedAction: reasonToAction(d.reason),
      sensorType: reasonToSensorType(d.reason),
      createdAt,
      reading: d.reading ?? null,
    };
  });
}

async function acknowledgeAlert(alertId) {
  if (!db || !alertId) return false;
  const ref = db.collection('alerts').doc(alertId);
  const snap = await ref.get();
  if (!snap.exists) return false;
  await ref.set(
    {
      status: 'ACKNOWLEDGED',
      acknowledged: true,
      acknowledgedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return true;
}

function periodToDurationMs(period) {
  switch ((period || '').toLowerCase()) {
    case 'week':
      return 7 * 24 * 60 * 60 * 1000;
    case 'month':
      return 30 * 24 * 60 * 60 * 1000;
    case 'today':
    default:
      return 24 * 60 * 60 * 1000;
  }
}

async function readHistoryFromFirestore(period = 'today', limit = 200) {
  if (!db) return [];
  const now = Date.now();
  const sinceMs = now - periodToDurationMs(period);

  const snap = await db
    .collection('sensor_readings')
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();

  const rows = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    const createdAt =
      d.createdAt && typeof d.createdAt.toDate === 'function' ? d.createdAt.toDate() : null;
    if (!createdAt) continue;
    if (createdAt.getTime() < sinceMs) continue;

    const oilPct = d.engineOilLimit
      ? Math.max(0, Math.min(100, (toNumber(d.engineOil) / toNumber(d.engineOilLimit, ENGINE_OIL_LIMIT)) * 100))
      : 0;
    const transPct = d.gearOilLimit
      ? Math.max(0, Math.min(100, (toNumber(d.gearOil) / toNumber(d.gearOilLimit, GEAR_OIL_LIMIT)) * 100))
      : 0;

    rows.push({
      id: doc.id,
      timestamp: createdAt.toISOString(),
      oil: Number(oilPct.toFixed(2)),
      temp: Number(toNumber(d.temp).toFixed(2)),
      battery: Number(toNumber(d.battery).toFixed(2)),
      trans: Number(transPct.toFixed(2)),
    });
  }

  // ascending for charts
  rows.sort((a, b) => String(a.timestamp).compareTo(String(b.timestamp)));
  return rows;
}

const DEFAULT_APP_SETTINGS = {
  temperatureUnit: 'celsius',
  updateInterval: 3,
  notificationsEnabled: true,
  criticalAlertsOnly: false,
  autoReconnect: true,
  darkMode: false,
  dataRetentionDays: 30,
  sensorServerBaseUrl: '',
};

async function readAppSettings() {
  if (!db) return DEFAULT_APP_SETTINGS;
  const ref = db.collection('app_settings').doc('global');
  const snap = await ref.get();
  if (!snap.exists) return DEFAULT_APP_SETTINGS;
  const data = snap.data() || {};
  return {
    ...DEFAULT_APP_SETTINGS,
    ...data,
  };
}

async function saveAppSettings(settings) {
  if (!db) return false;
  const ref = db.collection('app_settings').doc('global');
  await ref.set(
    {
      ...DEFAULT_APP_SETTINGS,
      ...settings,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return true;
}

function parseJsonBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > 1_000_000) {
        reject(new Error('Payload too large'));
      }
    });
    req.on('end', () => {
      try {
        const parsed = body ? JSON.parse(body) : {};
        resolve(parsed);
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
}

async function persistReading(reading, classification = null) {
  if (!db) return;

  const c = classification ?? classifyReading(reading);
  const data = {
    ...reading,
    level: c.level,
    flags: c.statuses,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('sensor_readings').add(data);
  await db.collection('latest').doc('current').set(data, { merge: true });
  await maybeCreateAlert(reading, c);
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

    const classification = classifyReading(reading);
    latest = {
      ...reading,
      level: classification.level,
      flags: classification.statuses,
    };

    // Return immediately for real-time UX, persist asynchronously.
    res.writeHead(200, corsHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
    res.end('ok');

    persistReading(reading, classification).catch((e) => {
      console.error('Persist error:', e.message);
    });
    return;
  }

  if (url.pathname === '/api/latest' || url.pathname === '/api/latest/') {
    res.writeHead(200, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
    res.end(JSON.stringify(latest));
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

  if (url.pathname === '/api/alerts' || url.pathname === '/api/alerts/') {
    try {
      const limit = Math.max(1, Math.min(500, Math.round(toNumber(url.searchParams.get('limit'), 200))));
      const alerts = await readAlertsFromFirestore(limit);
      res.writeHead(200, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
      res.end(JSON.stringify({ alerts }));
    } catch (e) {
      console.error('Read alerts error:', e.message);
      res.writeHead(200, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
      res.end(JSON.stringify({ alerts: [] }));
    }
    return;
  }

  if (url.pathname === '/api/alerts/ack' || url.pathname === '/api/alerts/ack/') {
    try {
      const id = url.searchParams.get('id');
      const ok = await acknowledgeAlert(id);
      res.writeHead(ok ? 200 : 404, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
      res.end(JSON.stringify({ ok }));
    } catch (e) {
      console.error('Acknowledge alert error:', e.message);
      res.writeHead(500, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
      res.end(JSON.stringify({ ok: false }));
    }
    return;
  }

  if (url.pathname === '/api/history' || url.pathname === '/api/history/') {
    try {
      const period = url.searchParams.get('period') || 'today';
      const limit = Math.max(10, Math.min(1000, Math.round(toNumber(url.searchParams.get('limit'), 240))));
      const rows = await readHistoryFromFirestore(period, limit);
      res.writeHead(200, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
      res.end(JSON.stringify({ period, count: rows.length, rows }));
    } catch (e) {
      console.error('Read history error:', e.message);
      res.writeHead(200, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
      res.end(JSON.stringify({ period: 'today', count: 0, rows: [] }));
    }
    return;
  }

  if (url.pathname === '/api/settings' || url.pathname === '/api/settings/') {
    if (req.method === 'GET') {
      try {
        const settings = await readAppSettings();
        res.writeHead(200, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
        res.end(JSON.stringify({ ok: true, settings }));
      } catch (e) {
        console.error('Read settings error:', e.message);
        res.writeHead(500, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
        res.end(JSON.stringify({ ok: false, settings: DEFAULT_APP_SETTINGS }));
      }
      return;
    }

    if (req.method === 'POST') {
      try {
        const body = await parseJsonBody(req);
        const settings = (body && body.settings) || {};
        const ok = await saveAppSettings(settings);
        res.writeHead(ok ? 200 : 500, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
        res.end(JSON.stringify({ ok }));
      } catch (e) {
        console.error('Save settings error:', e.message);
        res.writeHead(400, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
        res.end(JSON.stringify({ ok: false }));
      }
      return;
    }
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
  console.log('  Alerts    → GET /api/alerts , GET /api/alerts/ack?id=');
  console.log('  History   → GET /api/history?period=today|week|month');
  console.log('  Settings  → GET/POST /api/settings');
  console.log('  Health    → GET /api/health');
});
