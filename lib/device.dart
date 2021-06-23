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
final kKeyDelay = 400;
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

    disconnect();
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
    }, onDone: () {
      isConnected = false;
      // reconnect upon finishing
      connect(updateState);
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
    ws?.sink?.close();
    isConnected = false;
  }

  Future<bool> sendKey(KEY_CODES key) async {
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
      return false;
    }

    // add a delay so TV has time to execute
    // Timer(Duration(seconds: kConnectionTimeout), () async {
    //   throw ("TV timeout");
    // });

    return Future.delayed(Duration(milliseconds: kKeyDelay));
  }

  Future<void> input(String text) async {
    if (!isConnected) {
      await connect(null);
    }
    // // sending base 64 string, does not work for youtube
    // final data = json.encode({
    //   "method": 'ms.remote.control',
    //   "params": {
    //     "Cmd": base64.encode(utf8.encode(text)),
    //     "TypeOfRemote": "SendInputString",
    //     "DataOfCmd": 'base64',
    //   }
    // });
    // try {
    //   ws.sink.add(data);
    // } catch (e) {
    //   return;
    // }
    List<String> commands = [
      'KEY_RETURN',
      'KEY_RETURN',
      'KEY_RETURN',
      'KEY_RETURN',
      'KEY_ENTER',
      'KEY_LEFT',
      'KEY_UP',
      'KEY_RIGHT',
      'KEY_RIGHT',
      'KEY_RIGHT'
    ];

    List<int> lastPos = [0, 0, 0];
    for (int rune in text.toUpperCase().runes) {
      List<int> newPos = [0, 0, 0];
      if ('A'.runes.first <= rune && rune <= 'Z'.runes.first) {
        rune -= 'A'.runes.first;
        newPos = [rune % 7, rune ~/ 7, 0];
      } else if ('1'.runes.first <= rune && rune <= '9'.runes.first) {
        rune -= '1'.runes.first;
        newPos = [rune % 3, rune ~/ 3, 1];
      } else if (' '.runes.first == rune) {
        newPos = [lastPos[0], lastPos[2] == 0 ? 4 : 3, lastPos[2]];
      } else if ('0'.runes.first == rune) {
        newPos = [2, 3, 1];
      } else {
        continue;
      }

      int tmp;
      // flip
      if (newPos[2] != lastPos[2]) {
        // vertical move
        tmp = 1 - lastPos[1];
        for (int i = 0; i < tmp; ++i) commands.add("KEY_DOWN");
        for (int i = 0; i < -tmp; ++i) commands.add("KEY_UP");
        // horizontal move
        tmp = 7 - lastPos[0];
        for (int i = 0; i < tmp; ++i) commands.add("KEY_RIGHT");
        for (int i = 0; i < -tmp; ++i) commands.add("KEY_LEFT");
        commands.add("KEY_ENTER");
        lastPos = [7, 1, newPos[2]];
      }
      // vertical move
      tmp = newPos[1] - lastPos[1];
      for (int i = 0; i < tmp; ++i) commands.add("KEY_DOWN");
      for (int i = 0; i < -tmp; ++i) commands.add("KEY_UP");
      // horizontal move
      tmp = newPos[0] - lastPos[0];
      for (int i = 0; i < tmp; ++i) commands.add("KEY_RIGHT");
      for (int i = 0; i < -tmp; ++i) commands.add("KEY_LEFT");
      commands.add("KEY_ENTER");
      lastPos = newPos;
    }
    for (int i = 0; i < 5 - lastPos[1] + lastPos[2]; ++i)
      commands.add("KEY_DOWN");

    // print("Send key command  ${key.toString().split('.').last}");
    for (var i = 0; i < commands.length; i++) {
      final data = json.encode({
        "method": 'ms.remote.control',
        "params": {
          "Cmd": 'Click',
          "DataOfCmd": commands[i],
          "Option": false,
          "TypeOfRemote": 'SendRemoteKey',
        }
      });
      if (i == 4)
        await Future.delayed(const Duration(milliseconds: 1000));
      else if (i < 10 && i > 4 || commands[i] == 'KEY_ENTER')
        await Future.delayed(const Duration(milliseconds: 300));
      else
        await Future.delayed(const Duration(milliseconds: 100));
      try {
        await ws.sink.add(data);
      } catch (e) {
        return;
      }
    }
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
