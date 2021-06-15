import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hardware_buttons/hardware_buttons.dart' as HardwareButtons;

import 'device.dart';
import 'key_codes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    // For Android.
    // Use [light] for white status bar and [dark] for black status bar.
    statusBarIconBrightness: Brightness.light,
    // For iOS.
    // Use [dark] for white status bar and [light] for black status bar.
    statusBarBrightness: Brightness.dark,
  ));
  return runApp(SamgungRemoteController());
}

class SamgungRemoteController extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FlutterRemote',
      home: Scaffold(
        backgroundColor: Color(0XFF2e2e2e),
        body: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  StreamSubscription<HardwareButtons.VolumeButtonEvent>
      _volumeButtonSubscription;
  SamsungSmartTV tv;
  bool _touchpadShown = false;
  Offset initialOffset;

  void setInitialOffset(details) async {
    if (initialOffset == null) {
      initialOffset = details.localPosition;
    }
  }

  void updateOffset(details) async {
    const double threshold = 60;
    if (initialOffset == null) {
      return;
    }
    Offset tmp = details.localPosition - initialOffset;
    if (tmp.dx > 50) {
      initialOffset = initialOffset + Offset(threshold, 0);
      tv.sendKey(KEY_CODES.KEY_RIGHT);
    } else if (tmp.dx < -50) {
      initialOffset = initialOffset + Offset(-threshold, 0);
      tv.sendKey(KEY_CODES.KEY_LEFT);
    }
    if (tmp.dy > 50) {
      initialOffset = initialOffset + Offset(0, threshold);
      tv.sendKey(KEY_CODES.KEY_DOWN);
    } else if (tmp.dy < -50) {
      initialOffset = initialOffset + Offset(0, -threshold);
      tv.sendKey(KEY_CODES.KEY_UP);
    }
  }

  void resetOffset(details) async {
    initialOffset = null;
  }

  @override
  void initState() {
    super.initState();
    connectTV();
    // connect to volumn buttons
    _volumeButtonSubscription =
        HardwareButtons.volumeButtonEvents.listen((event) {
      if (tv.isConnected) {
        if (event == HardwareButtons.VolumeButtonEvent.VOLUME_UP) {
          tv.sendKey(KEY_CODES.KEY_VOLUP);
        } else {
          tv.sendKey(KEY_CODES.KEY_VOLDOWN);
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _volumeButtonSubscription?.cancel();
  }

  Future<void> connectTV() async {
    try {
      setState(() async {
        if (tv == null) tv = await SamsungSmartTV.discover();
        await tv.connect(() {
          setState(() {});
        });
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        setState(() {
          _touchpadShown = !_touchpadShown;
        });
        return false;
      },
      child: SafeArea(
        child: _touchpadShown
            ? Container(
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        // just max out
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child: GestureDetector(
                          child: null,
                          onTap: () async {
                            // enter
                            await tv.sendKey(KEY_CODES.KEY_ENTER);
                          },
                          onVerticalDragStart: setInitialOffset,
                          onHorizontalDragStart: setInitialOffset,
                          onVerticalDragUpdate: updateOffset,
                          onHorizontalDragUpdate: updateOffset,
                          onVerticalDragEnd: resetOffset,
                          onHorizontalDragEnd: resetOffset,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: ControllerButton(
                        child: Text(
                          "MENU",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54),
                        ),
                        onPressed: () async {
                          await tv.sendKey(KEY_CODES.KEY_CHUP);
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: ControllerButton(
                        child: Text(
                          "INFO",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54),
                        ),
                        onPressed: () async {
                          await tv.sendKey(KEY_CODES.KEY_PRECH);
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: ControllerButton(
                        child: Text(
                          "BACK",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54),
                        ),
                        onPressed: () async {
                          await tv.sendKey(KEY_CODES.KEY_RETURN);
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ControllerButton(
                        child: Text(
                          "EXIT",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54),
                        ),
                        onPressed: () async {
                          await tv.sendKey(KEY_CODES.KEY_EXIT);
                        },
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ControllerButton(
                          child: Icon(Icons.power_settings_new,
                              size: 30, color: Colors.red),
                          onPressed: () async {
                            await tv.sendKey(KEY_CODES.KEY_POWER);
                          },
                        ),
                        (tv == null ? false : tv.isConnected)
                            ? MaterialButton(
                                minWidth: 64,
                                shape: CircleBorder(),
                                onPressed: connectTV,
                                child: null,
                              )
                            : ControllerButton(
                                child: Icon(Icons.connected_tv,
                                    size: 30, color: Colors.white70),
                                onPressed: connectTV,
                              ),
                        ControllerButton(
                          child: Icon(Icons.input,
                              size: 30, color: Colors.white70),
                          onPressed: () async {
                            await tv.sendKey(KEY_CODES.KEY_SOURCE);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 50),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ControllerButton(
                          borderRadius: 15,
                          child: Column(
                            children: [
                              MaterialButton(
                                height: 50,
                                minWidth: 50,
                                shape: CircleBorder(),
                                child: Icon(Icons.keyboard_arrow_up,
                                    size: 20, color: Colors.white54),
                                onPressed: () async {
                                  await tv.sendKey(KEY_CODES.KEY_VOLUP);
                                },
                              ),
                              MaterialButton(
                                height: 50,
                                minWidth: 50,
                                shape: CircleBorder(),
                                child: Icon(Icons.volume_off,
                                    size: 20, color: Colors.white70),
                                onPressed: () async {
                                  await tv.sendKey(KEY_CODES.KEY_MUTE);
                                },
                              ),
                              MaterialButton(
                                height: 50,
                                minWidth: 50,
                                shape: CircleBorder(),
                                child: Icon(Icons.keyboard_arrow_down,
                                    size: 20, color: Colors.white54),
                                onPressed: () async {
                                  await tv.sendKey(KEY_CODES.KEY_VOLDOWN);
                                },
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            ControllerButton(
                              borderRadius: 15,
                              child: Text(
                                "home".toUpperCase(),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white54),
                              ),
                              onPressed: () async {
                                await tv.sendKey(KEY_CODES.KEY_HOME);
                              },
                            ),
                            SizedBox(height: 35),
                            ControllerButton(
                              borderRadius: 15,
                              child: Text(
                                "guide".toUpperCase(),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white54),
                              ),
                              onPressed: () async {
                                await tv.sendKey(KEY_CODES.KEY_GUIDE);
                              },
                            ),
                          ],
                        ),
                        ControllerButton(
                          borderRadius: 15,
                          child: Column(
                            children: [
                              MaterialButton(
                                height: 50,
                                minWidth: 50,
                                shape: CircleBorder(),
                                child: Icon(Icons.keyboard_arrow_up,
                                    size: 20, color: Colors.white54),
                                onPressed: () async {
                                  await tv.sendKey(KEY_CODES.KEY_CHUP);
                                },
                              ),
                              MaterialButton(
                                height: 50,
                                minWidth: 50,
                                shape: CircleBorder(),
                                child: Text(
                                  'CH',
                                  style: TextStyle(
                                      fontSize: 15, color: Colors.white70),
                                ),
                                onPressed: () async {
                                  await tv.sendKey(KEY_CODES.KEY_PRECH);
                                },
                              ),
                              MaterialButton(
                                height: 50,
                                minWidth: 50,
                                shape: CircleBorder(),
                                child: Icon(Icons.keyboard_arrow_down,
                                    size: 20, color: Colors.white54),
                                onPressed: () async {
                                  await tv.sendKey(KEY_CODES.KEY_CHDOWN);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 50),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ControllerButton(
                          child: Icon(Icons.fast_rewind,
                              size: 20, color: Colors.white54),
                          onPressed: () async {
                            await tv.sendKey(KEY_CODES.KEY_REWIND);
                          },
                        ),
                        ControllerButton(
                          child: Icon(Icons.play_arrow,
                              size: 20, color: Colors.white54),
                          onPressed: () async {
                            await tv.sendKey(KEY_CODES.KEY_PLAY);
                          },
                        ),
                        ControllerButton(
                          child: Icon(Icons.pause,
                              size: 20, color: Colors.white54),
                          onPressed: () async {
                            await tv.sendKey(KEY_CODES.KEY_PAUSE);
                          },
                        ),
                        ControllerButton(
                          child: Icon(Icons.fast_forward,
                              size: 20, color: Colors.white54),
                          onPressed: () async {
                            await tv.sendKey(KEY_CODES.KEY_FF);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 25),
                  ],
                ),
              ),
      ),
    );
  }
}

class ControllerButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double borderRadius;
  final Color color;
  const ControllerButton(
      {Key key, this.child, this.borderRadius = 30, this.color, this.onPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        color: Color(0XFF2e2e2e),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          colors: [Color(0XFF1c1c1c), Color(0XFF383838)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0XFF1c1c1c),
            offset: Offset(5.0, 5.0),
            blurRadius: 10.0,
          ),
          BoxShadow(
            color: Color(0XFF404040),
            offset: Offset(-5.0, -5.0),
            blurRadius: 10.0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                colors: [Color(0XFF303030), Color(0XFF1a1a1a)]),
          ),
          child: MaterialButton(
            color: color,
            minWidth: 0,
            onPressed: onPressed,
            shape: CircleBorder(),
            child: child,
          ),
        ),
      ),
    );
  }
}
