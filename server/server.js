/**
 * سيرفر وسيط: يستقبل بيانات من ESP32/Wokwi ويعرضها للتطبيق.
 *
 * تشغيل: من مجلد server نفّذ: node server.js
 * ثم في Wokwi: serverURL = "http://<عنوانك>:3000/update"
 * وفي التطبيق (الإعدادات): نفس العنوان بدون /update مثلاً http://10.0.2.2:3000
 */

const http = require('http');

const PORT = process.env.PORT || 3000;

/** يطابق حدود كود Wokwi الافتراضية */
const ENGINE_OIL_LIMIT = 5000;
const GEAR_OIL_LIMIT = 20000;

let latest = {
  temp: 0,
  battery: 0,
  engineOil: 0,
  gearOil: 0,
  updatedAt: null,
};

function corsHeaders(extra = {}) {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Accept',
    ...extra,
  };
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url || '/', `http://localhost:${PORT}`);

  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders());
    res.end();
    return;
  }

  if (url.pathname === '/update' || url.pathname.startsWith('/update')) {
    const temp = url.searchParams.get('temp');
    const battery = url.searchParams.get('battery');
    const engineOil = url.searchParams.get('engineOil');
    const gearOil = url.searchParams.get('gearOil');

    if (temp != null) latest.temp = parseFloat(temp);
    if (battery != null) latest.battery = parseFloat(battery);
    if (engineOil != null) latest.engineOil = parseInt(engineOil, 10);
    if (gearOil != null) latest.gearOil = parseInt(gearOil, 10);
    latest.updatedAt = new Date().toISOString();

    res.writeHead(200, corsHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
    res.end('ok');
    return;
  }

  if (url.pathname === '/api/latest' || url.pathname === '/api/latest/') {
    const body = JSON.stringify({
      temp: latest.temp,
      battery: latest.battery,
      engineOil: latest.engineOil,
      gearOil: latest.gearOil,
      engineOilLimit: ENGINE_OIL_LIMIT,
      gearOilLimit: GEAR_OIL_LIMIT,
      updatedAt: latest.updatedAt,
    });
    res.writeHead(200, corsHeaders({ 'Content-Type': 'application/json; charset=utf-8' }));
    res.end(body);
    return;
  }

  if (url.pathname === '/' || url.pathname === '') {
    res.writeHead(200, corsHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
    res.end('Smart Drive Care sensor bridge. GET /api/latest — POST target for ESP: /update?...');
    return;
  }

  res.writeHead(404, corsHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
  res.end('not found');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Sensor bridge: http://localhost:${PORT}`);
  console.log(`  ESP/Wokwi → GET /update?temp=&battery=&engineOil=&gearOil=`);
  console.log(`  Flutter   → GET /api/latest`);
});
