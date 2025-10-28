package com.example.tono_music

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onBackPressed() {
		moveTaskToBack(true)
	}
}
