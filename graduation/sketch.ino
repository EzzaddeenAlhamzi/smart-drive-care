#include <WiFi.h>
#include <HTTPClient.h>

//  WiFi Settings 
const char* ssid = "Ses-GUEST";
const char* password = "0987654321";

//  Server 
String serverURL = "http://your-server-ip/update";

// Pins 
#define TEMP_PIN 34
#define BAT_PIN 35
#define LED_PIN 2
#define BUZZER_PIN 18  

//  Limits 
const int engineOilLimit = 5000;
const int gearOilLimit = 20000;

unsigned long lastKMUpdate = 0;
int currentKM = 0;

void setup() {
  Serial.begin(115200);

  pinMode(LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  digitalWrite(LED_PIN, LOW);
  digitalWrite(BUZZER_PIN, LOW);

  // WiFi Connect 
  WiFi.begin(ssid, password);

  Serial.print("Connecting to WiFi");

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi Connected!");
}

void loop() {

  //  قراءة الحرارة 
  int tempRaw = analogRead(TEMP_PIN);
  float temperature = (tempRaw / 4095.0) * 120.0;

  //  قراءة البطارية 
  int batRaw = analogRead(BAT_PIN);
  float batteryVoltage = (batRaw / 4095.0) * 14.0;

  // كيلومترات افتراضية 
  if (millis() - lastKMUpdate > 5000) {
    currentKM += 100;
    lastKMUpdate = millis();
  }

  //  الزيت 
  int engineOilRemaining = engineOilLimit - currentKM;
  int gearOilRemaining = gearOilLimit - currentKM;

  if (engineOilRemaining < 0) engineOilRemaining = 0;
  if (gearOilRemaining < 0) gearOilRemaining = 0;

  //  إنذار 
  bool alert = false;

  if (temperature > 95) alert = true;
  if (batteryVoltage < 11) alert = true;
  if (engineOilRemaining == 0) alert = true;
  if (gearOilRemaining == 0) alert = true;

  //  تشغيل الإنذار 
  if (alert) {
    digitalWrite(LED_PIN, HIGH);
    digitalWrite(BUZZER_PIN, HIGH);   
  } else {
    digitalWrite(LED_PIN, LOW);
    digitalWrite(BUZZER_PIN, LOW);
  }

  //  إرسال البيانات 
  if (WiFi.status() == WL_CONNECTED) {

    WiFiClient client;
    HTTPClient http;

    String url = serverURL +
      "?temp=" + String(temperature) +
      "&battery=" + String(batteryVoltage) +
      "&engineOil=" + String(engineOilRemaining) +
      "&gearOil=" + String(gearOilRemaining);

    http.begin(client, url);
    int httpCode = http.GET();

    Serial.print("HTTP Response: ");
    Serial.println(httpCode);

    http.end();
  }

  //  Serial Monitor 
  Serial.println("===== SYSTEM DATA =====");
  Serial.print("Temperature: "); Serial.println(temperature);
  Serial.print("Battery: "); Serial.println(batteryVoltage);
  Serial.print("Engine Oil KM: "); Serial.println(engineOilRemaining);
  Serial.print("Gear Oil KM: "); Serial.println(gearOilRemaining);
  Serial.println("=======================");

  delay(2000);
}