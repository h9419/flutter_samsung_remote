import 'dart:async';

import 'package:flutter/services.dart';

const _VOLUME_BUTTON_CHANNEL_NAME =
    'com.example.flutter_samsung_remote.volume_buttons';

const EventChannel _volumeButtonEventChannel =
    EventChannel(_VOLUME_BUTTON_CHANNEL_NAME);
Stream<VolumeButtonEvent> _volumeButtonEvents;

/// A broadcast stream of volume button events
Stream<VolumeButtonEvent> get volumeButtonEvents {
  if (_volumeButtonEvents == null) {
    _volumeButtonEvents = _volumeButtonEventChannel
        .receiveBroadcastStream()
        .map((dynamic event) => _eventToVolumeButtonEvent(event));
  }
  return _volumeButtonEvents;
}

/// Volume button events
/// Applies both to device and earphone buttons
enum VolumeButtonEvent {
  VOLUME_UP,
  VOLUME_DOWN,
  HOME_KEY,
  MENU_KEY,
  SWITCH_KEY,
}

VolumeButtonEvent _eventToVolumeButtonEvent(dynamic event) {
  if (event == 24) {
    return VolumeButtonEvent.VOLUME_UP;
  } else if (event == 25) {
    return VolumeButtonEvent.VOLUME_DOWN;
  } else if (event == 3) {
    return VolumeButtonEvent.HOME_KEY;
  } else if (event == 82) {
    return VolumeButtonEvent.MENU_KEY;
  } else if (event == 228) {
    return VolumeButtonEvent.SWITCH_KEY;
  } else {
    throw Exception('Invalid volume button event');
  }
}
