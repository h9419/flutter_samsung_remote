package com.example.flutter_samsung_remote

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.view.KeyEvent
import io.flutter.plugin.common.EventChannel

class MainActivity: FlutterActivity() , EventChannel.StreamHandler {
  // EventChannel.StreamHandler functions
  private var streamSink: EventChannel.EventSink? = null
  override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
      this.streamSink = sink
  }
  override fun onCancel(args: Any?) {
      this.streamSink = null
  }
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    
    val volumeButtonChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.flutter_samsung_remote.volume_buttons")
    volumeButtonChannel.setStreamHandler(this)
  }
  
  
  override fun dispatchKeyEvent(event : KeyEvent) : Boolean {
    var action = event.getAction()
    var keycode = event.getKeyCode()
    if (action == KeyEvent.ACTION_DOWN) {
      if (keycode == KeyEvent.KEYCODE_VOLUME_UP) {
        this.streamSink?.success(24)
        return true
      }
      else if (keycode == KeyEvent.KEYCODE_VOLUME_DOWN) {
        this.streamSink?.success(25)
        return true
      }
    }
    return super.dispatchKeyEvent(event)
  }
}
