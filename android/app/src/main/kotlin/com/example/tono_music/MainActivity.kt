package com.example.tono_music

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "app.navigation"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"moveTaskToBack" -> {
						// Hide app to background instead of finishing
						moveTaskToBack(true)
						result.success(true)
					}
					else -> result.notImplemented()
				}
			}
	}

	override fun onBackPressed() {
		super.onBackPressed()
	}
}
