#include <Wire.h>
#include "MAX30100_PulseOximeter.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Define UUIDs for services and characteristics
#define SERVICE_UUID        "0000180d-0000-1000-8000-00805f9b34fc"
#define CHARACTERISTIC_UUID "00002a37-0000-1000-8000-00805f9b34fc"
#define LED_PIN 2 // GPIO pin for LED

PulseOximeter pox;
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;

uint32_t tsLastReport = 0;
bool deviceConnected = false;
bool measurementStarted = false;
bool isSensorInitialized = false; // Flag to check sensor initialization

class MyServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        Serial.println("Device connected");
        digitalWrite(LED_PIN, HIGH); // Turn on LED when connected
        deviceConnected = true;
    }

    void onDisconnect(BLEServer* pServer) {
        Serial.println("Device disconnected");
        digitalWrite(LED_PIN, LOW); // Turn off LED when disconnected
        deviceConnected = false;
        measurementStarted = false;

        // Stop the sensor if it's running
        if (isSensorInitialized) {
            pox.shutdown();
            isSensorInitialized = false;
        }

        // Restart advertising
        pServer->getAdvertising()->start();
        Serial.println("Advertising restarted");
    }
};

class MyCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        String value = pCharacteristic->getValue().c_str(); // Read value from client

        if (value == "START") {
            Serial.println("Measurement START command received");
            measurementStarted = true;

            // Blink LED to indicate start
            for (int i = 0; i < 5; i++) {
                digitalWrite(LED_PIN, LOW);
                delay(200);
                digitalWrite(LED_PIN, HIGH);
                delay(200);
            }

            // Initialize MAX30100 if not already initialized
            if (!isSensorInitialized) {
                if (!pox.begin()) {
                    Serial.println("FAILED to initialize MAX30100");
                } else {
                    Serial.println("MAX30100 initialized SUCCESSFULLY");
                    pox.setIRLedCurrent(MAX30100_LED_CURR_7_6MA);
                    isSensorInitialized = true;

                    // Allow the sensor to stabilize
                    delay(2000);
                }
            }
        } 
    }
};

void setup() {
    Serial.begin(115200);

    // Initialize BLE
    BLEDevice::init("BLE Device");
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    // Create BLE Service and Characteristic
    BLEService* pService = pServer->createService(SERVICE_UUID);
    pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_WRITE |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pCharacteristic->addDescriptor(new BLE2902());
    pCharacteristic->setCallbacks(new MyCallbacks());

    // Start the service and advertising
    pService->start();
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->start();

    // Setup LED pin
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, LOW);
}

void loop() {
    static int count = 0; // Biến đếm số lần gửi dữ liệu
    if (deviceConnected && measurementStarted) {
        pox.update();

        if (millis() - tsLastReport > 1000) { // Send data every second
            float heartRate = pox.getHeartRate();
            float spO2 = pox.getSpO2();

            if (heartRate >= 60 && spO2 >= 70) {
                String data = String(heartRate) + "," + String(spO2);
                pCharacteristic->setValue(data.c_str());
                pCharacteristic->notify();
                Serial.println(data);
                count++;
            } else {
                Serial.println("Invalid sensor data, not sending.");
            }

            if (count >= 10) { 
                Serial.println("Sent 10 data points. Stopping measurements.");
                measurementStarted = false; // Dừng việc đo
                digitalWrite(LED_PIN, LOW);
                count = 0; // Reset bộ đếm nếu cần
            }

            tsLastReport = millis();
        }
    }
}



  

