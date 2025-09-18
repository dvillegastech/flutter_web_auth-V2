package com.linusu.flutter_web_auth

import android.app.Activity
import android.app.Application
import android.app.Application.ActivityLifecycleCallbacks
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import androidx.browser.customtabs.CustomTabsClient

import androidx.browser.customtabs.CustomTabsIntent
import androidx.browser.customtabs.CustomTabsServiceConnection
import androidx.browser.customtabs.CustomTabsSession

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class FlutterWebAuthPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private var context: Context? = null
    private var channel: MethodChannel? = null
    private var customTabsSession: CustomTabsSession? = null
    private lateinit var customTabsClient: CustomTabsClient
    private var activity: Activity? = null
    private var binaryMessenger: BinaryMessenger? = null
    private val lifecycleCallback = object : ActivityLifecycleCallbacks {
        override fun onActivityCreated(activity: Activity, bundle: Bundle?) {}

        override fun onActivityStarted(activity: Activity) {}

        @RequiresApi(Build.VERSION_CODES.Q)
        override fun onActivityResumed(activity: Activity) {
            cleanupDanglingCalls()
        }

        override fun onActivityPaused(activity: Activity) {}

        override fun onActivityStopped(activvity: Activity) {}

        override fun onActivitySaveInstanceState(activity: Activity, bundle: Bundle) {}

        override fun onActivityDestroyed(activity: Activity) {}
    }

    companion object {
        val callbacks = mutableMapOf<String, Result>()
    }

    private fun initInstance() {
        channel = MethodChannel(binaryMessenger!!, "flutter_web_auth")
        channel?.setMethodCallHandler(this)
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        binaryMessenger = binding.binaryMessenger
        initInstance()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = null
        channel = null
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        val connection: CustomTabsServiceConnection = object : CustomTabsServiceConnection() {
            override fun onCustomTabsServiceConnected(name: ComponentName, client: CustomTabsClient) {
                customTabsClient = client
                client.warmup(0)
                customTabsSession = client.newSession(null)
            }

            override fun onServiceDisconnected(name: ComponentName) {}
        }
        CustomTabsClient.bindCustomTabsService(context!!, activity!!.packageName, connection)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun onMethodCall(call: MethodCall, resultCallback: Result) {
        val activity = this.activity
        if (activity == null) {
            resultCallback.error(CODE_LAUNCH_ERROR, "Launching a CustomTabs requires a foreground activity.", null)
            return
        }
        when (call.method) {
            "warmupUrl" -> {
                val url = Uri.parse(call.argument("url"))
                customTabsSession?.mayLaunchUrl(url, null, null)
            }
            "logout" -> {
                val url = Uri.parse(call.argument("url"))
                val callbackUrlScheme = call.argument<String>("callbackUrlScheme")!!
                val intent = CustomTabsIntent.Builder(customTabsSession).build()
                callbacks[callbackUrlScheme] = resultCallback
                val keepAliveIntent = Intent(context, KeepAliveService::class.java)
                intent.intent.putExtra("android.support.customtabs.extra.KEEP_ALIVE", keepAliveIntent)
                intent.launchUrl(activity, url)
                activity.application.unregisterActivityLifecycleCallbacks(lifecycleCallback)
                activity.application.registerActivityLifecycleCallbacks(lifecycleCallback)
            }
            "authenticate" -> {
                val url = Uri.parse(call.argument("url"))
                val callbackUrlScheme = call.argument<String>("callbackUrlScheme")!!
                val preferEphemeral = call.argument<Boolean>("preferEphemeral")!!
                val intent = CustomTabsIntent.Builder(customTabsSession).build()
                callbacks[callbackUrlScheme] = resultCallback
                val keepAliveIntent = Intent(context, KeepAliveService::class.java)
                if (preferEphemeral) {
                    intent.intent.addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
                }
                intent.intent.putExtra("android.support.customtabs.extra.KEEP_ALIVE", keepAliveIntent)

                intent.launchUrl(activity, url)
                activity.application.unregisterActivityLifecycleCallbacks(lifecycleCallback)
                activity.application.registerActivityLifecycleCallbacks(lifecycleCallback)
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun cleanupDanglingCalls() {
        callbacks.forEach { (_, danglingResultCallback) ->
            danglingResultCallback.error("CANCELED", "User canceled login", null)
        }
        callbacks.clear()
        activity?.application?.unregisterActivityLifecycleCallbacks(lifecycleCallback)
    }
}

private const val CODE_LAUNCH_ERROR = "LAUNCH_ERROR"
