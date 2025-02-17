import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'sendmessage.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  BluetoothCharacteristic? _characteristic;
  String _receivedData = "No data received";
  int _dataCount = 0;

  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = widget.device.connectionState.listen((state) {
      setState(() {
        _connectionState = state;
      });

      if (state == BluetoothConnectionState.connected) {
        _discoverServices();
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _discoverServices() async {
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify || characteristic.properties.write) {
            _characteristic = characteristic;
            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              characteristic.value.listen((value) {
                setState(() {
                  _receivedData = String.fromCharCodes(value);
                  _dataCount++;
                });

                // Gửi dữ liệu lần thứ 10
                if (_dataCount == 10) {
                  List<String> splitData = _receivedData.split(',');
                  String heartRate = splitData.isNotEmpty ? splitData[0] : "No HR data";
                  String spO2 = splitData.length > 1 ? splitData[1] : "No SpO2 data";

                  sendmessage("Heart Rate: $heartRate bpm, SpO2: $spO2%");
                  print("Data sent to Telegram: Heart Rate: $heartRate bpm, SpO2: $spO2%");

                  _dataCount = 0; // Đặt lại bộ đếm
                }
              });
            }
          }
        }
      }
    } catch (e) {
      print("Error discovering services: $e");
    }
  }

  Future<void> _sendCommand(String command) async {
    if (_characteristic != null) {
      try {
        await _characteristic!.write(command.codeUnits);
        print("Sent command: $command");
      } catch (e) {
        print("Error sending command: $e");
      }
    } else {
      print("Characteristic not found");
    }
  }

  Future<void> _connect() async {
    try {
      await widget.device.connect();
    } catch (e) {
      print("Connect error: $e");
    }
  }

  Future<void> _disconnect() async {
    try {
      await widget.device.disconnect();
    } catch (e) {
      print("Disconnect error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tách dữ liệu tại khoảng trắng
    List<String> splitData = _receivedData.split(',');
    String heartRate = splitData.isNotEmpty ? splitData[0] : "No HR data";
    String spO2 = splitData.length > 1 ? splitData[1] : "No SpO2 data";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
        actions: [
          TextButton(
            onPressed: _connectionState == BluetoothConnectionState.connected ? _disconnect : _connect,
            child: Text(
              _connectionState == BluetoothConnectionState.connected ? "DISCONNECT" : "CONNECT",
              style: const TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            "Đặt ngón tay vào cảm biến",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Image.asset(
            'lib/assets/images/anh.png',
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width * 0.6,
            fit: BoxFit.cover,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.monitor_heart, color: Colors.red),
              const SizedBox(width: 10),
              Text(
                "$heartRate bpm",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'lib/assets/icon/spo2.svg',
                width: 24,
                height: 24,
                color: Colors.green,
              ),
              const SizedBox(width: 10),
              Text(
                "$spO2 %",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 40),
          // Nút đo
          ElevatedButton(
            onPressed: () {
              _sendCommand("START");
            },
            child: const Text("BẮT ĐẦU ĐO"),
          ),
        ],
      ),
    );
  }
}
