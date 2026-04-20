import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, FlutterStreamHandler,
  UNUserNotificationCenterDelegate {
  private let notificationMethodChannelName = "slock/notifications/methods"
  private let notificationTapEventChannelName = "slock/notifications/taps"
  private let apnsTokenDefaultsKey = "slock.notifications.apnsToken"

  private var tapEventSink: FlutterEventSink?
  private var pendingTapPayload: [String: Any]?
  private var initialNotificationPayload: [String: Any]?
  private var didConsumeInitialNotification = false
  private var cachedApnsToken: String?
  private var permissionRequestInFlight = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    cachedApnsToken = UserDefaults.standard.string(forKey: apnsTokenDefaultsKey)
    initialNotificationPayload = notificationPayload(
      from: launchOptions?[.remoteNotification] as? [AnyHashable: Any]
    )
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let methodChannel = FlutterMethodChannel(
      name: notificationMethodChannelName,
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "init":
        self.initializeNotifications(result: result)
      case "requestPermission":
        self.requestNotificationPermission(result: result)
      case "getToken":
        result(self.cachedApnsToken)
      case "getInitialNotification":
        self.didConsumeInitialNotification = true
        if let payload = self.initialNotificationPayload {
          self.initialNotificationPayload = nil
          result(payload)
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let tapEventChannel = FlutterEventChannel(
      name: notificationTapEventChannelName,
      binaryMessenger: messenger
    )
    tapEventChannel.setStreamHandler(self)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    cachedApnsToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    UserDefaults.standard.set(cachedApnsToken, forKey: apnsTokenDefaultsKey)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    defer {
      super.userNotificationCenter(
        center,
        didReceive: response,
        withCompletionHandler: completionHandler
      )
    }

    guard let payload = notificationPayload(from: response.notification.request.content.userInfo) else {
      return
    }

    if let tapEventSink {
      tapEventSink(payload)
      return
    }

    if !didConsumeInitialNotification {
      initialNotificationPayload = payload
    } else {
      pendingTapPayload = payload
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    tapEventSink = events
    if let payload = pendingTapPayload {
      pendingTapPayload = nil
      events(payload)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    tapEventSink = nil
    return nil
  }

  private func initializeNotifications(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().delegate = self
    resolvePermissionStatus { [weak self] status in
      guard let self else {
        result(nil)
        return
      }

      if status == "granted" || status == "provisional" {
        self.registerForRemoteNotificationsIfPossible()
      }
      result(nil)
    }
  }

  private func requestNotificationPermission(result: @escaping FlutterResult) {
    resolvePermissionStatus { [weak self] status in
      guard let self else {
        result("unknown")
        return
      }

      if status == "granted" || status == "provisional" || status == "denied" {
        if status == "granted" || status == "provisional" {
          self.registerForRemoteNotificationsIfPossible()
        }
        result(status)
        return
      }

      if self.permissionRequestInFlight {
        result(status)
        return
      }

      self.permissionRequestInFlight = true
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
        _, _ in
        self.resolvePermissionStatus { resolvedStatus in
          self.permissionRequestInFlight = false
          if resolvedStatus == "granted" || resolvedStatus == "provisional" {
            self.registerForRemoteNotificationsIfPossible()
          }
          result(resolvedStatus)
        }
      }
    }
  }

  private func registerForRemoteNotificationsIfPossible() {
    DispatchQueue.main.async {
      UIApplication.shared.registerForRemoteNotifications()
    }
  }

  private func resolvePermissionStatus(completion: @escaping (String) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let status = switch settings.authorizationStatus {
      case .authorized, .ephemeral:
        "granted"
      case .denied:
        "denied"
      case .provisional:
        "provisional"
      case .notDetermined:
        "unknown"
      @unknown default:
        "unknown"
      }

      DispatchQueue.main.async {
        completion(status)
      }
    }
  }

  private func notificationPayload(from userInfo: [AnyHashable: Any]?) -> [String: Any]? {
    guard let userInfo, !userInfo.isEmpty else {
      return nil
    }

    return userInfo.reduce(into: [String: Any]()) { result, entry in
      result[String(describing: entry.key)] = entry.value
    }
  }
}
