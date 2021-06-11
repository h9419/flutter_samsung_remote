import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upnp/upnp.dart';
import 'package:wake_on_lan/wake_on_lan.dart';
import 'package:web_socket_channel/io.dart';

import 'key_codes.dart';

final int kConnectionTimeout = 60;
final kKeyDelay = 200;
final kWakeOnLanDelay = 5000;
final kUpnpTimeout = 1000;

class SamsungSmartTV {
  final List<Map<String, dynamic>> services;
  final String host;
  final String api;
  final String wsapi;
  bool isConnected = false;
  String token;
  // dynamic info;
  IOWebSocketChannel ws;
  Timer timer;

  SamsungSmartTV({this.host})
      : api = "http://$host:8001/api/v2/",
        wsapi = "wss://$host:8002/api/v2/",
        services = [];

  /**
     * add UPNP service
     * @param [Object] service  UPNP service description
     */
  addService(service) {
    this.services.add(service);
  }

  connect(updateState, {appName = 'SamsungSmartTVRemote'}) async {
    var completer = new Completer();

    try {
      ws?.sink?.close();
    } catch (e) {}
    // get device info
    // info = await getDeviceInfo();
    final prefs = await SharedPreferences.getInstance();
    if (token == null && this.host == prefs.getString('host')) {
      token = prefs.getString('token');
    }

    // establish socket connection
    final appNameBase64 = base64.encode(utf8.encode(appName));
    String channel =
        "${wsapi}channels/samsung.remote.control?name=$appNameBase64";
    if (token != null) {
      channel += '&token=$token';
    }

    // log.info(`Connect to ${channel}`)
    // ws = IOWebSocketChannel.connect(channel);
    ws = IOWebSocketChannel.connect(channel,
        badCertificateCallback: (X509Certificate cert, String host, int port) =>
            true);

    final info = await getDeviceInfo();
    ws.stream.listen((message) {
      // timer?.cancel();

      Map<String, dynamic> data;
      try {
        data = json.decode(message);
      } catch (e) {
        prefs.remove('token');
        throw ('Could not parse TV response $message');
      }

      if (data["data"] != null && data["data"]["token"] != null) {
        token = data["data"]["token"];
        prefs.setString('token', token);
        prefs.setString('host', info["ip"]);
        prefs.setString('mac', info["wifiMac"]);
      }

      if (data["event"] != 'ms.channel.connect') {
        print('TV responded with $data');
        isConnected = false;
        updateState();
        // throw ('Unable to connect to TV');
      }
      // print('Connection successfully established');
      isConnected = true;

      updateState();

      completer.complete();

      // timer = Timer(Duration(seconds: kConnectionTimeout), () {
      //   throw ('Unable to connect to TV: timeout');
      // });

      // ws.sink.add("received!");
    }, onError: (e) {
      isConnected = false;
      updateState();
    });

    return completer.future;
  }

  // request TV info like udid or model name

  Future<dynamic> getDeviceInfo() async {
    print("Get device info from $api");
    http.Response result = await http.get(this.api);
    return json.decode(result.body)["device"];
  }

  // disconnect from device

  disconnect() {
    // ws.sink.close(status.goingAway);
    ws.sink.close();
    isConnected = false;
  }

  sendKey(KEY_CODES key) async {
    if (!isConnected) {
      await connect(null);
    }

    // print("Send key command  ${key.toString().split('.').last}");
    final data = json.encode({
      "method": 'ms.remote.control',
      "params": {
        "Cmd": 'Click',
        "DataOfCmd": key.toString().split('.').last,
        "Option": false,
        "TypeOfRemote": 'SendRemoteKey',
      }
    });

    try {
      ws.sink.add(data);
    } catch (e) {
      isConnected = false;
      connect(null).then(() {
        ws?.sink?.add(data);
      });
    }

    // add a delay so TV has time to execute
    Timer(Duration(seconds: kConnectionTimeout), () async {
      throw ("TV timeout");
    });

    return Future.delayed(Duration(milliseconds: kKeyDelay));
  }

  //static method to discover Samsung Smart TVs in the network using the UPNP protocol

  static discover() async {
    // WoL known TV
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('host') != null && prefs.getString('mac') != null) {
      await WakeOnLAN.from(
        IPv4Address.from(prefs.getString('host')),
        MACAddress.from(prefs.getString('mac')),
        port: 55,
      ).wake();
      return SamsungSmartTV(host: prefs.getString('host'));
    }
    // discover

    var completer = new Completer();
    final client = DeviceDiscoverer();
    final List<SamsungSmartTV> tvs = [];

    await client.start(ipv6: false);

    client.quickDiscoverClients().listen((client) async {
      RegExp re = RegExp(r'^.*?Samsung.+UPnP.+SDK\/1\.0$');

      //ignore other devices
      if (!re.hasMatch(client.server)) {
        return;
      }
      try {
        final device = await client.getDevice();

        Uri locaion = Uri.parse(client.location);
        final deviceExists =
            tvs.firstWhere((tv) => tv.host == locaion.host, orElse: () => null);

        if (deviceExists == null) {
          print("Found ${device.friendlyName} on IP ${locaion.host}");
          final tv = SamsungSmartTV(host: locaion.host);
          tv.addService({
            "location": client.location,
            "server": client.server,
            "st": client.st,
            "usn": client.usn
          });
          tvs.add(tv);
        }
      } catch (e, stack) {
        print("ERROR: $e - ${client.location}");
        print(stack);
      }
    }).onDone(() {
      if (tvs.isEmpty) {
        completer.completeError(
            "No Samsung TVs found. Make sure the UPNP protocol is enabled in your network.");
      }
      completer.complete(tvs.first);
    });

    return completer.future;
  }
}
