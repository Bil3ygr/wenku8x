package cc.zsakvo.wenku8x

import android.os.SystemClock
import android.view.KeyEvent
import android.view.Window
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var interceptVolume = false
    private var channel: MethodChannel? = null
    private var lastVolumeAt = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wenku8x/volume")
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "setIntercept") {
                interceptVolume = readEnabled(call.arguments)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        installVolumeCallback()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) installVolumeCallback()
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (consumeVolume(event)) return true
        return super.dispatchKeyEvent(event)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (consumeVolume(event)) return true
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if (interceptVolume && isVolumeKey(keyCode)) return true
        return super.onKeyUp(keyCode, event)
    }

    private fun installVolumeCallback() {
        val current = window.callback ?: return
        if (current is VolumeKeyCallback) return
        window.callback = VolumeKeyCallback(current)
    }

    private fun readEnabled(args: Any?): Boolean {
        return when (args) {
            is Boolean -> args
            is Map<*, *> -> {
                val value = args["enabled"]
                value == true || value == 1 || value == "true"
            }
            else -> false
        }
    }

    private fun consumeVolume(event: KeyEvent): Boolean {
        if (!interceptVolume || !isVolumeKey(event.keyCode)) return false
        // 按下和松开都吃掉，否则系统仍会弹出音量条。翻页只在按下时发。
        if (event.action == KeyEvent.ACTION_DOWN) {
            val now = SystemClock.uptimeMillis()
            val gap = if (event.repeatCount == 0) 80L else 260L
            if (now - lastVolumeAt >= gap) {
                lastVolumeAt = now
                val key = if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) "up" else "down"
                try {
                    channel?.invokeMethod("key", key)
                } catch (_: Exception) {
                }
            }
        }
        return true
    }

    private fun isVolumeKey(keyCode: Int): Boolean {
        return keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
    }

    private inner class VolumeKeyCallback(
        private val base: Window.Callback,
    ) : Window.Callback by base {
        override fun dispatchKeyEvent(event: KeyEvent): Boolean {
            if (consumeVolume(event)) return true
            return base.dispatchKeyEvent(event)
        }
    }
}
