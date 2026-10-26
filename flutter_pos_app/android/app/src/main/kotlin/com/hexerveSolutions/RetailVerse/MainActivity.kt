package com.hexerveSolutions.RetailVerse

import android.content.Context
import android.content.Intent
import android.hardware.input.InputManager
import android.provider.Settings
import android.view.InputDevice
import android.view.inputmethod.InputMethodManager
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
            when (call.method) {
                "isScannerConnected" -> {
                    result.success(isHardwareKeyboardConnected())
                }
                "forceShowKeyboard" -> {
                    try {
                        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                        val view = currentFocus ?: window.decorView
                        imm?.showSoftInput(view, InputMethodManager.SHOW_FORCED)
                        imm?.toggleSoftInput(InputMethodManager.SHOW_FORCED, InputMethodManager.HIDE_IMPLICIT_ONLY)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openKeyboardSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_HARD_KEYBOARD_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("ERROR", e2.message, null)
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        val inputManager = getSystemService(Context.INPUT_SERVICE) as? InputManager
        inputManager?.registerInputDeviceListener(this, null)
    }

    private fun isHardwareKeyboardConnected(): Boolean {
        val inputManager = getSystemService(Context.INPUT_SERVICE) as? InputManager ?: return false
        for (deviceId in inputManager.inputDeviceIds) {
            val device = inputManager.getInputDevice(deviceId) ?: continue
            val isExternal = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                device.isExternal
            } else {
                !device.isVirtual
            }
            if (isExternal && !device.isVirtual && (device.sources and InputDevice.SOURCE_KEYBOARD) == InputDevice.SOURCE_KEYBOARD && device.keyboardType == InputDevice.KEYBOARD_TYPE_ALPHABETIC) {
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
