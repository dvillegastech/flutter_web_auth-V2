package com.linusu.flutter_web_auth

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle

class CallbackActivity: Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    val url = intent?.data
    val scheme = url?.scheme

    if (scheme != null) {
      FlutterWebAuthPlugin.callbacks.remove(scheme)?.success(url.toString())
    }

    val context = applicationContext
    val pm: PackageManager = context.packageManager
    val intent = pm.getLaunchIntentForPackage(context.packageName)
    // Makes sure the custom tab will be closed
    intent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    startActivity(intent)
    finish()
  }
}
