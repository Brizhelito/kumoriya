package dev.kumoriya.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var passkeyChannel: PasskeyMethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val handler = PasskeyMethodChannel(this)
        passkeyChannel = handler
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PasskeyMethodChannel.CHANNEL,
        ).setMethodCallHandler(handler)
    }

    override fun onDestroy() {
        passkeyChannel?.dispose()
        passkeyChannel = null
        super.onDestroy()
    }
}
