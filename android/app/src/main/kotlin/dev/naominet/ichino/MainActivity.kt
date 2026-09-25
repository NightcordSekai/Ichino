package dev.naominet.ichino

import android.graphics.BitmapFactory
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "dev.naominet.ichino/qr_scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "decodeQRFromBytes") {
                val bytes = call.arguments as? ByteArray
                if (bytes == null) {
                    result.success(null)
                    return@setMethodCallHandler
                }

                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bitmap == null) {
                    result.success(null)
                    return@setMethodCallHandler
                }

                val image = InputImage.fromBitmap(bitmap, 0)
                val scanner = BarcodeScanning.getClient()

                scanner.process(image)
                    .addOnSuccessListener { barcodes ->
                        val qr = barcodes.firstOrNull { it.valueType == Barcode.TYPE_TEXT }
                        result.success(qr?.rawValue)
                    }
                    .addOnFailureListener {
                        result.success(null)
                    }
            } else {
                result.notImplemented()
            }
        }
    }
}
