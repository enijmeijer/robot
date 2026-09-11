// Explicit hardware overrides for micro:bit V2 edge pins
#define PIN_LEFT_SENSOR  13  // Physical P13 on the edge connector
#define PIN_RIGHT_SENSOR 14  // Physical P14 on the edge connector (Port 1, Pin 5)

void setup() {
  Serial.begin(115200);
  
  // Set the specific hardware pins as input
  pinMode(PIN_LEFT_SENSOR, INPUT);
  pinMode(PIN_RIGHT_SENSOR, INPUT);
}

void loop() {
  int leftState = digitalRead(PIN_LEFT_SENSOR);
  int rightState = digitalRead(PIN_RIGHT_SENSOR);

  Serial.print("Left Sensor: ");
  Serial.print(leftState == 0 ? "BLACK (0)" : "WHITE (1)");
  Serial.print("  |  Right Sensor: ");
  Serial.println(rightState == 0 ? "BLACK (0)" : "WHITE (1)");

  delay(200);
}

