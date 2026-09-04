package com.example.modelgo

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.Keep
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var pendingNotificationResult: MethodChannel.Result? = null
    private val inferenceExecutor = Executors.newSingleThreadExecutor()
    private lateinit var inferenceChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_PERMISSION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> requestNotificationPermission(result)
                else -> result.notImplemented()
            }
        }

        inferenceChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INFERENCE_CHANNEL,
        )
        inferenceChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val modelPath = call.argument<String>("modelPath")
                    if (modelPath == null) {
                        result.error("invalid_model_path", "A model path is required.", null)
                    } else {
                        runInferenceTask(result) { loadModel(modelPath) }
                    }
                }

                "infer" -> {
                    val prompt = call.argument<String>("prompt")
                    if (prompt == null) {
                        result.error("invalid_prompt", "A prompt is required.", null)
                    } else {
                        prepareInference()
                        val callback = InferenceCallback()
                        runInferenceTask(result) { infer(prompt, callback) }
                    }
                }

                "cancelInference" -> {
                    cancelInference()
                    result.success(true)
                }

                "resetChat" -> runInferenceTask(result) {
                    resetChat()
                    true
                }

                "unloadModel" -> runInferenceTask(result) {
                    unloadModel()
                    true
                }

                else -> result.notImplemented()
            }
        }
    }

    @Keep
    private inner class InferenceCallback {
        fun onToken(token: String) {
            runOnUiThread {
                inferenceChannel.invokeMethod(
                    "inferenceToken",
                    mapOf("token" to token),
                )
            }
        }

        fun onPromptProcessed(tokenCount: Int, seconds: Double) {
            runOnUiThread {
                inferenceChannel.invokeMethod(
                    "promptProcessed",
                    mapOf(
                        "tokenCount" to tokenCount,
                        "seconds" to seconds,
                    ),
                )
            }
        }

        fun onGenerationCompleted(
            tokenCount: Int,
            seconds: Double,
            cancelled: Boolean,
        ) {
            runOnUiThread {
                inferenceChannel.invokeMethod(
                    "generationCompleted",
                    mapOf(
                        "tokenCount" to tokenCount,
                        "seconds" to seconds,
                        "cancelled" to cancelled,
                    ),
                )
            }
        }
    }

    private fun runInferenceTask(result: MethodChannel.Result, task: () -> Any) {
        inferenceExecutor.execute {
            try {
                val value = task()
                runOnUiThread { result.success(value) }
            } catch (error: Throwable) {
                runOnUiThread {
                    result.error("native_inference_error", error.message, null)
                }
            }
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        if (pendingNotificationResult != null) {
            result.error("permission_request_active", "A notification permission request is already active.", null)
            return
        }

        pendingNotificationResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            pendingNotificationResult?.success(granted)
            pendingNotificationResult = null
        }
    }

    private external fun loadModel(modelPath: String): Boolean

    private external fun infer(prompt: String, callback: InferenceCallback): String

    private external fun prepareInference()

    private external fun cancelInference()

    private external fun resetChat()

    private external fun unloadModel()

    companion object {
        init {
            System.loadLibrary("native-lib")
        }

        private const val INFERENCE_CHANNEL = "com.example.modelgo/inference"
        private const val NOTIFICATION_PERMISSION_CHANNEL = "com.example.modelgo/permissions"
        private const val NOTIFICATION_PERMISSION_REQUEST = 1001
    }
}
