import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  var locationManager = CLLocationManager()
  private let locationChannelName = "com.example.native_location"
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let locationChannel = FlutterMethodChannel(name: locationChannelName, binaryMessenger: controller.binaryMessenger)
    
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    locationManager.requestWhenInUseAuthorization()
    locationManager.startUpdatingLocation()
    
    locationChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getLocation" {
        if let location = self.locationManager.location {
          let locData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy
          ]
          result(locData)
        } else {
          result(FlutterError(code: "UNAVAILABLE", message: "Location not available", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
