import Flutter
import UIKit
import Vision

class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let controller = window?.rootViewController as? FlutterViewController else { return }

    let channel = FlutterMethodChannel(
      name: "dev.naominet.purarine/qr_scanner",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { (call, result) in
      guard call.method == "decodeQRFromBytes" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let args = call.arguments as? FlutterStandardTypedData,
        let image = UIImage(data: args.data),
        let cgImage = image.cgImage
      else {
        result(nil)
        return
      }

      let request = VNDetectBarcodesRequest { (request, error) in
        if error != nil {
          result(nil)
          return
        }
        let payload = (request.results as? [VNBarcodeObservation])?
          .first { $0.symbology == .qr }?
          .payloadStringValue
        result(payload)
      }

      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try handler.perform([request])
        } catch {
          result(nil)
        }
      }
    }
  }
}
