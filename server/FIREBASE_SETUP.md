# Firebase Setup For Server

This server uses Firebase Admin SDK to write sensor data to Firestore.

## 1) Local Run

Use one of these methods:

- `GOOGLE_APPLICATION_CREDENTIALS` pointing to service-account file path
- `FIREBASE_SERVICE_ACCOUNT_JSON` containing full JSON text

### Option A: file path (recommended locally)

1. Download service account JSON from Firebase Console:
   - Project Settings -> Service accounts -> Generate new private key
2. Save file outside git repo (example: `C:\secrets\smart-drive-care-service-account.json`)
3. Run:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\secrets\smart-drive-care-service-account.json"
node server.js
```

### Option B: JSON text in env var

```powershell
$json = Get-Content "C:\secrets\smart-drive-care-service-account.json" -Raw
$env:FIREBASE_SERVICE_ACCOUNT_JSON = $json
node server.js
```

## 2) Render Deployment

In Render service settings -> Environment:

- Add secret env var: `FIREBASE_SERVICE_ACCOUNT_JSON`
- Value: full service-account JSON text (single line or pasted as-is)

Redeploy after saving env var.

## 3) Firestore Collections Used

- `sensor_readings` (all incoming readings history)
- `latest/current` (latest snapshot)
- `alerts` (generated warning/critical alerts)

## 4) Health Check

Use:

- `/api/health`

Expected:

```json
{
  "ok": true,
  "firestoreConnected": true,
  "now": "..."
}
```
