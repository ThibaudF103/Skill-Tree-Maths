import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Gestes de l'Apple Pencil, transmis à Flutter.
  private var pencil: PencilBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VergerPencil") {
      pencil = PencilBridge(registrar: registrar)
    }
  }
}

/// Gestes de l'Apple Pencil (toucher deux fois ; presser, sur l'Apple
/// Pencil Pro) envoyés à Flutter sur le canal « verger/pencil », avec
/// l'action choisie dans Réglages > Apple Pencil.
final class PencilBridge: NSObject, UIPencilInteractionDelegate {
  private let channel: FlutterMethodChannel
  private weak var registrar: FlutterPluginRegistrar?
  private var interaction: UIPencilInteraction?

  init(registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(
      name: "verger/pencil", binaryMessenger: registrar.messenger())
    self.registrar = registrar
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "attach" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.attach()
      result(nil)
    }
  }

  /// Installe l'interaction sur la vue Flutter (une seule fois).
  private func attach() {
    guard interaction == nil, let view = registrar?.viewController?.view else { return }
    let pencilInteraction = UIPencilInteraction()
    pencilInteraction.delegate = self
    view.addInteraction(pencilInteraction)
    interaction = pencilInteraction
  }

  /// [location] : position du stylet au-dessus de l'écran, dans la vue
  /// Flutter (en points, comme les pixels logiques de Flutter).
  private func send(_ action: UIPencilPreferredAction, at location: CGPoint?) {
    guard let name = Self.name(of: action) else { return }
    var arguments: [String: Any] = ["action": name]
    if let location {
      arguments["x"] = location.x
      arguments["y"] = location.y
    }
    channel.invokeMethod("gesture", arguments: arguments)
  }

  private static func name(of action: UIPencilPreferredAction) -> String? {
    switch action {
    case .switchEraser: return "eraser"
    case .switchPrevious: return "previous"
    case .showColorPalette: return "palette"
    case .ignore: return nil
    default:
      // Actions plus récentes que la cible de déploiement (iOS 15).
      if #available(iOS 16.0, *), action == .showInkAttributes { return "palette" }
      if #available(iOS 17.5, *), action == .showContextualPalette { return "palette" }
      return nil
    }
  }

  @available(iOS 17.5, *)
  func pencilInteraction(
    _ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap
  ) {
    send(UIPencilInteraction.preferredTapAction, at: tap.hoverPose?.location)
  }

  @available(iOS 17.5, *)
  func pencilInteraction(
    _ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
  ) {
    guard squeeze.phase == .ended else { return }
    send(UIPencilInteraction.preferredSqueezeAction, at: squeeze.hoverPose?.location)
  }

  // Avant iOS 17.5 : toucher deux fois seulement, sans position.
  func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
    send(UIPencilInteraction.preferredTapAction, at: nil)
  }
}
