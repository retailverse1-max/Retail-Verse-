package com.hexerveSolutions.RetailVerse

import android.content.Context
import android.hardware.input.InputManager
import android.view.InputDevice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), InputManager.InputDeviceListener {
    private val CHANNEL = "com.hexerveSolutions.RetailVerse/hardware_scanner"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "isScannerConnected") {
                result.success(isHardwareKeyboardConnected())
            } else {
                result.notImplemented()
            }
        }

        val inputManager = getSystemService(Context.INPUT_SERVICE) as? InputManager
        inputManager?.registerInputDeviceListener(this, null)
    }

    private fun isHardwareKeyboardConnected(): Boolean {
        val inputManager = getSystemService(Context.INPUT_SERVICE) as? InputManager ?: return false
        for (deviceId in inputManager.inputDeviceIds) {
            val device = inputManager.getInputDevice(deviceId) ?: continue
            if (!device.isVirtual && (device.sources and InputDevice.SOURCE_KEYBOARD) == InputDevice.SOURCE_KEYBOARD && device.keyboardType == InputDevice.KEYBOARD_TYPE_ALPHABETIC) {
                return true
            }
        }
        return false
    }

    private fun notifyFlutterScannerState() {
        val connected = isHardwareKeyboardConnected()
        runOnUiThread {
            methodChannel?.invokeMethod("onScannerConnectionChanged", connected)
        }
    }

    override fun onInputDeviceAdded(deviceId: Int) {
        notifyFlutterScannerState()
    }

    override fun onInputDeviceRemoved(deviceId: Int) {
        notifyFlutterScannerState()
    }

    override fun onInputDeviceChanged(deviceId: Int) {
        notifyFlutterScannerState()
    }

    override fun onDestroy() {
        val inputManager = getSystemService(Context.INPUT_SERVICE) as? InputManager
        inputManager?.unregisterInputDeviceListener(this)
        super.onDestroy()
    }
}
