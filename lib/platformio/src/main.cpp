#include <BluetoothSerial.h>

BluetoothSerial SerialBT;

const int GSR_PIN_1 = 34; // GPIO pin for first GSR sensor
const int GSR_PIN_2 = 35; // GPIO pin for second GSR sensor

int sensorValue1 = 0;
int sensorValue2 = 0;

void setup() {
    Serial.begin(9600);
    SerialBT.begin("ESP32_GSR"); // Bluetooth device name
    Serial.println("The device started, now you can pair it with Bluetooth!");

    pinMode(GSR_PIN_1, INPUT);
    pinMode(GSR_PIN_2, INPUT);
}

void loop() {
    sensorValue1 = analogRead(GSR_PIN_1);
    delay(10);
    sensorValue2 = analogRead(GSR_PIN_2);

    if ((sensorValue1 >= 315 && sensorValue1 <= 330) && (sensorValue2 >= 315 && sensorValue2 <= 330)) {
        Serial.println("No sensors detected");
    } else {
        Serial.print("Sensor 1: ");
        Serial.print(sensorValue1);
        Serial.print("\t");
        Serial.print("Sensor 2: ");
        Serial.println(sensorValue2);

        String data = String(sensorValue1) + "," + String(sensorValue2);
        SerialBT.println(data);
    }

    delay(100);
}