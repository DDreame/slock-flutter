import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let notificationMethodChannelName = "slock/notifications/methods"
  private let notificationTapEventChannelName = "slock/notifications/taps"
  private let notificationForegroundEventChannelName = "slock/notifications/foreground"
  private let apnsTokenDefaultsKey = "slock.notifications.apnsToken"

  private var tapEventSink: FlutterEventSink?
  private var foregroundEventSink: FlutterEventSink?
  private var pendingTapPayload: [String: Any]?
  private var initialNotificationPayload: [String: Any]?
  private var didConsumeInitialNotification = false
  private var cachedApnsToken: String?
  private var permissionRequestInFlight = false

  private let tapStreamHandler = StreamHandler()
  private let foregroundStreamHandler = StreamHandler()

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
      case "showLocalNotification":
        if let payload = call.arguments as? [String: Any] {
          self.postLocalNotification(payload: payload)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let tapEventChannel = FlutterEventChannel(
      name: notificationTapEventChannelName,
      binaryMessenger: messenger
    )
    tapStreamHandler.onSinkReady = { [weak self] sink in
      self?.tapEventSink = sink
      if let payload = self?.pendingTapPayload {
        self?.pendingTapPayload = nil
        sink(payload)
      }
    }
    tapStreamHandler.onSinkRemoved = { [weak self] in
      self?.tapEventSink = nil
    }
    tapEventChannel.setStreamHandler(tapStreamHandler)

    let foregroundEventChannel = FlutterEventChannel(
      name: notificationForegroundEventChannelName,
      binaryMessenger: messenger
    )
    foregroundStreamHandler.onSinkReady = { [weak self] sink in
      self?.foregroundEventSink = sink
    }
    foregroundStreamHandler.onSinkRemoved = { [weak self] in
      self?.foregroundEventSink = nil
    }
    foregroundEventChannel.setStreamHandler(foregroundStreamHandler)
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

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    if userInfo["slock.localRepost"] as? Bool == true {
      completionHandler([.banner, .sound])
      return
    }
    if let payload = notificationPayload(from: userInfo) {
      foregroundEventSink?(payload)
    }
    completionHandler([])
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

  private func postLocalNotification(payload: [String: Any]) {
    let content = UNMutableNotificationContent()
    content.title = payload["title"] as? String ?? ""
    content.body = payload["body"] as? String ?? ""
    content.sound = .default
    var userInfo = payload
    userInfo["slock.localRepost"] = true
    content.userInfo = userInfo

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
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

private class StreamHandler: NSObject, FlutterStreamHandler {
  var onSinkReady: ((FlutterEventSink) -> Void)?
  var onSinkRemoved: (() -> Void)?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    onSinkReady?(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onSinkRemoved?()
    return nil
  }
}
