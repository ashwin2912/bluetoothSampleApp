import 'dart:async';
import 'dart:io' show Platform;
import 'package:location_permissions/location_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'models/bluetooth_device.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Bluetooth Sample App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final flutterReactiveBle = FlutterReactiveBle();
  bool _foundDeviceWaitingToConnect = false;
  bool _scanStarted = false;
  bool _connected = false;
  Timer? _timer;
  int _counter = 4;


// Bluetooth related variables
  late DiscoveredDevice _ubiqueDevice;
  late StreamSubscription<DiscoveredDevice> _scanStream;
  late QualifiedCharacteristic _rxCharacteristic;

// These are the UUIDs of your device
  final Uuid serviceUuid = Uuid.parse("75C276C3-8F97-20BC-A143-B354244886D4");
  final Uuid characteristicUuid =
      Uuid.parse("6ACF4F08-CC9D-D495-6B41-AA7E60C4E8A6");
  late List<BluetoothDevice> _bluetoothDevices;
  late List<String> _bluetoothDeviceIds;
  late List<String> _bluetoothDeviceNames;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _bluetoothDevices = [];
    _bluetoothDeviceIds = [];
  }

  void getDeviceStatus() {
    flutterReactiveBle.statusStream.listen((status) {
      print(status.toString());
      print(status.name);
      print(status.runtimeType.toString());
    });
  }

  bool addDeviceToList(DiscoveredDevice discoveredDevice){
    bool isPresent = false;
    BluetoothDevice bluetoothDevice = BluetoothDevice(deviceId: discoveredDevice.id, deviceName: discoveredDevice.name);
    if(_bluetoothDevices.contains(bluetoothDevice)){
      isPresent = true;
    }else{
      _bluetoothDevices.add(bluetoothDevice);
    }
    return isPresent;
  }

  void addDeviceIdToList(DiscoveredDevice discoveredDevice){
    if(!_bluetoothDeviceIds.contains(discoveredDevice.id)){
      setState((){
        BluetoothDevice bluetoothDevice = BluetoothDevice(deviceId: discoveredDevice.id, deviceName: discoveredDevice.name);
        _bluetoothDevices.add(bluetoothDevice);
        _bluetoothDeviceIds.add(discoveredDevice.id);
      });
    }
  }

  void scanDevices() {
    flutterReactiveBle.scanForDevices(
        withServices: [],
        scanMode: ScanMode.opportunistic,
        requireLocationServicesEnabled: false).listen((device) {
      print("Discovered device with id:${device.id}");
      print("Discovered device with name:${device.name}");
      print("Discovered device with rssi${device.rssi}");
    }, onError: (e) {
      print("Error with error code:" + e.toString());
      //code for handling error
    });
  }

  //Don't call the function too freuently
  //scan and stop, filter out LitedMed devices

  void _startScan() async {
// Platform permissions handling stuff
    bool permGranted = false;
    setState(() {
      _scanStarted = true;
    });
    PermissionStatus permission;
    if (Platform.isAndroid) {
      permission = await LocationPermissions().requestPermissions();
      if (permission == PermissionStatus.granted) permGranted = true;
    } else if (Platform.isIOS) {
      permGranted = true;
    }
// Main scanning logic happens here ⤵️
    if (permGranted) {
      _timer = Timer.periodic(Duration(seconds:1), (timer) {
        setState((){
          if (_counter > 1) {
            _counter--;
            _scanStream =
                flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
                  //Adding device to list
                  addDeviceIdToList(device);
                  if (device.id == 'D1:04:8F:5A:74:FB') {
                    setState(() {
                      _ubiqueDevice = device;
                      _foundDeviceWaitingToConnect = true;
                    });
                    _connectToDevice();
                  }
                });
            print("Counter:$_counter");
          } else {
            _timer!.cancel();
            _scanStream.cancel();
            _counter = 20;
          }
        });
      });
    }
  }

  void _connectToDevice() {
    // We're done scanning, we can cancel it
    _scanStream.cancel();
    // Let's listen to our connection so we can make updates on a state change
    Stream<ConnectionStateUpdate> _currentConnectionStream = flutterReactiveBle
        .connectToAdvertisingDevice(
            id: _ubiqueDevice.id,
            prescanDuration: const Duration(seconds: 1),
            withServices: []);
    _currentConnectionStream.listen((event) {
      switch (event.connectionState) {
        // We're connected and good to go!
        case DeviceConnectionState.connected:
          {
            _rxCharacteristic = QualifiedCharacteristic(
                serviceId: serviceUuid,
                characteristicId: characteristicUuid,
                deviceId: event.deviceId);
            setState(() {
              _foundDeviceWaitingToConnect = false;
              _connected = true;
            });
            break;
          }
        // Can add various state state updates on disconnect
        case DeviceConnectionState.disconnected:
          {
            break;
          }
        default:
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        child: Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  getDeviceStatus();
                },
                child: Container(
                  height: 50,
                  width: 100,
                  color: Colors.blue,
                  child: Center(child: Text("Get Device Status")),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _startScan();
                },
                child: Container(
                  height: 50,
                  width: 100,
                  color: Colors.blue,
                  child: Center(child: Text("Start Scan")),
                ),
              ),
              Expanded(
                child: ListView.builder(
                    itemCount: _bluetoothDevices.length,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                          trailing: Text(
                            _bluetoothDevices[index].deviceId,
                            style: TextStyle(color: Colors.green, fontSize: 15),
                          ),
                          leading: Text(
                            _bluetoothDevices[index].deviceName,
                            style: TextStyle(color: Colors.green, fontSize: 15),
                          ) ,
                          title: Text("List item $index"));
                    }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
