import Flutter
import UIKit
import AVKit

class CastingAdapter: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    private var externalWindow: UIWindow?
    private var currentTarget: [String: Any]?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = CastingAdapter()
        instance.setupChannels(registrar: registrar)
        registrar.addApplicationDelegate(instance)
    }
    
    private func setupChannels(registrar: FlutterPluginRegistrar) {
        methodChannel = FlutterMethodChannel(name: "com.retromesh.console/casting",
                                             binaryMessenger: registrar.messenger())
        eventChannel = FlutterEventChannel(name: "com.retromesh.console/casting_events",
                                           binaryMessenger: registrar.messenger())
        
        registrar.addMethodCallDelegate(self, channel: methodChannel!)
        eventChannel?.setStreamHandler(self)
        
        // Listen for screen connections (AirPlay/HDMI plug-in)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screenDidConnect),
                                               name: UIScreen.didConnectNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screenDidDisconnect),
                                               name: UIScreen.didDisconnectNotification,
                                               object: nil)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startScanning":
            updateDevices()
            result(nil)
        case "stopScanning":
            result(nil)
        case "connectToDevice":
            if let args = call.arguments as? [String: Any] {
                currentTarget = args
            }
            result(nil)
        case "projectGameplayCanvas":
            projectGameplay()
            result(nil)
        case "disconnect":
            externalWindow = nil
            currentTarget = nil
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        updateDevices()
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    @objc private func screenDidConnect() {
        updateDevices()
    }
    
    @objc private func screenDidDisconnect() {
        externalWindow = nil
        updateDevices()
    }
    
    private func updateDevices() {
        var targets: [[String: Any]] = []
        
        // Check if secondary screen is connected (AirPlay/HDMI secondary display active)
        if UIScreen.screens.count > 1 {
            let secondaryScreen = UIScreen.screens[1]
            let target: [String: Any] = [
                "id": "airplay_screen_0",
                "name": "Apple TV / AirPlay Display (\(Int(secondaryScreen.bounds.width))x\(Int(secondaryScreen.bounds.height)))",
                "protocolType": "appleAirPlay"
            ]
            targets.append(target)
        }
        
        if let json = try? JSONSerialization.data(withJSONObject: targets, options: []),
           let jsonString = String(data: json, encoding: .utf8) {
            eventSink?(jsonString)
        }
    }
    
    private func projectGameplay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard UIScreen.screens.count > 1 else { return }
            let secondaryScreen = UIScreen.screens[1]
            
            let windowFrame = secondaryScreen.bounds
            let extWindow = UIWindow(frame: windowFrame)
            extWindow.screen = secondaryScreen
            
            let externalViewController = UIViewController()
            externalViewController.view.backgroundColor = .black
            
            let label = UILabel()
            label.text = "Retro Mesh Console: Projection Active\nWebGL TV Viewport Projected via AirPlay Bridge"
            label.numberOfLines = 0
            label.textColor = .white
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
            label.frame = externalViewController.view.bounds
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            externalViewController.view.addSubview(label)
            extWindow.rootViewController = externalViewController
            extWindow.isHidden = false
            self.externalWindow = extWindow
        }
    }
}
