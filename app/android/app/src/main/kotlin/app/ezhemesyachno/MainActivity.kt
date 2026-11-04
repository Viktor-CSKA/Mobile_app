package app.ezhemesyachno

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Dart сообщает, что кэш виджета обновился, и просит перерисовать его.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.ezhemesyachno/widget",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    PaymentWidgetProvider.updateAll(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
