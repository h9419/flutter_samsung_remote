package com.example.flutter_samsung_remote

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.view.KeyEvent
import io.flutter.plugin.common.EventChannel
import android.content.Intent

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
    if (action == KeyEvent.ACTION_DOWN) {
      var keycode = event.getKeyCode()
      if (keycode == KeyEvent.KEYCODE_VOLUME_UP) {
        this.streamSink?.success(keycode)
        return true
      }
      else if (keycode == KeyEvent.KEYCODE_VOLUME_DOWN) {
        this.streamSink?.success(keycode)
        return true
      }
      else if (keycode == KeyEvent.KEYCODE_MENU) {
        this.streamSink?.success(keycode)
        return true
      }
      else if (keycode == 228) { // switch sim button on LG E435
        this.streamSink?.success(keycode)
        return true
      }
    }
    return super.dispatchKeyEvent(event)
  }
  // override fun onNewIntent(intent : Intent) {
  //   this.streamSink?.success(3)
  //   super.onNewIntent(intent);
  // }
  // override fun onResume() {
  //   this.streamSink?.success(3)
  //   super.onResume();
  // }
}
