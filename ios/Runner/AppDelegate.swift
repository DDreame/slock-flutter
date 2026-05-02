import Flutter
import UIKit
import UserNotifications
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let notificationMethodChannelName = "slock/notifications/methods"
  private let notificationTapEventChannelName = "slock/notifications/taps"
  private let notificationForegroundEventChannelName = "slock/notifications/foreground"
  private let backgroundSyncChannelName = "slock/notifications/background_sync"
  private let apnsTokenDefaultsKey = "slock.notifications.apnsToken"

  // Background sync constants
  private static let bgSyncTaskIdentifier = "com.slock.app.bgSync"
  private static let syncConfigApiBaseUrlKey = "slock.bgSync.apiBaseUrl"
  private static let syncConfigServerIdKey = "slock.bgSync.serverId"
  private static let syncLastTimestampKey = "slock.bgSync.lastTimestamp"
  /// flutter_secure_storage key for session token.
  private static let keychainTokenKey = "session_token"

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
    registerBackgroundSyncTask()
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
      case "getPermissionStatus":
        self.resolvePermissionStatus { status in
          result(status)
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

    // Background sync MethodChannel
    let bgSyncChannel = FlutterMethodChannel(
      name: backgroundSyncChannelName,
      binaryMessenger: messenger
    )
    bgSyncChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "schedulePeriodicSync":
        self.scheduleBackgroundSync()
        result(nil)
      case "cancelPeriodicSync":
        self.cancelBackgroundSync()
        result(nil)
      case "persistSyncConfig":
        if let config = call.arguments as? [String: String] {
          self.persistSyncConfig(config)
        }
        result(nil)
      case "clearSyncConfig":
        self.clearSyncConfig()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
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
      if #available(iOS 14.0, *) {
        completionHandler([.banner, .sound])
      } else {
        completionHandler([.alert, .sound])
      }
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

  // MARK: - Background Sync

  /// Register the BGAppRefreshTask with the system.
  ///
  /// **Important:** iOS Background App Refresh is not guaranteed.
  /// iOS may throttle, delay, or skip tasks based on battery,
  /// network, and app usage patterns.
  private func registerBackgroundSyncTask() {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: AppDelegate.bgSyncTaskIdentifier,
      using: nil
    ) { [weak self] task in
      guard let bgTask = task as? BGAppRefreshTask else { return }
      self?.handleBackgroundSync(task: bgTask)
    }
  }

  /// Schedule the next BGAppRefreshTask.
  private func scheduleBackgroundSync() {
    let request = BGAppRefreshTaskRequest(
      identifier: AppDelegate.bgSyncTaskIdentifier
    )
    // Request earliest execution 15 minutes from now.
    // iOS may delay further based on usage patterns.
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      NSLog("[SlockBgSync] Failed to schedule: \(error)")
    }
  }

  /// Cancel any pending BGAppRefreshTasks.
  private func cancelBackgroundSync() {
    BGTaskScheduler.shared.cancel(
      taskRequestWithIdentifier: AppDelegate.bgSyncTaskIdentifier
    )
  }

  /// Persist the sync config to UserDefaults.
  private func persistSyncConfig(_ config: [String: String]) {
    let defaults = UserDefaults.standard
    if let apiBaseUrl = config["apiBaseUrl"] {
      defaults.set(apiBaseUrl, forKey: AppDelegate.syncConfigApiBaseUrlKey)
    }
    if let serverId = config["serverId"] {
      defaults.set(serverId, forKey: AppDelegate.syncConfigServerIdKey)
    }
  }

  /// Clear sync config from UserDefaults.
  private func clearSyncConfig() {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: AppDelegate.syncConfigApiBaseUrlKey)
    defaults.removeObject(forKey: AppDelegate.syncConfigServerIdKey)
    defaults.removeObject(forKey: AppDelegate.syncLastTimestampKey)
  }

  /// Handle the BGAppRefreshTask when iOS grants execution time.
  private func handleBackgroundSync(task: BGAppRefreshTask) {
    // Schedule the next refresh immediately so the chain continues.
    scheduleBackgroundSync()

    let defaults = UserDefaults.standard
    guard
      let apiBaseUrl = defaults.string(forKey: AppDelegate.syncConfigApiBaseUrlKey),
      let serverId = defaults.string(forKey: AppDelegate.syncConfigServerIdKey),
      let token = readKeychainToken()
    else {
      NSLog("[SlockBgSync] Missing config or token — skipping")
      task.setTaskCompleted(success: true)
      return
    }

    let lastTimestamp = defaults.double(forKey: AppDelegate.syncLastTimestampKey)

    task.expirationHandler = {
      NSLog("[SlockBgSync] Task expired before completion")
    }

    fetchNewMessageCount(
      apiBaseUrl: apiBaseUrl,
      serverId: serverId,
      token: token,
      sinceTimestamp: lastTimestamp
    ) { [weak self] count in
      if count > 0 {
        self?.showSyncNotification(messageCount: count)
      }
      defaults.set(Date().timeIntervalSince1970, forKey: AppDelegate.syncLastTimestampKey)
      task.setTaskCompleted(success: true)
    }
  }

  /// Read the session token from the iOS Keychain where
  /// flutter_secure_storage stores it.
  private func readKeychainToken() -> String? {
    // flutter_secure_storage on iOS uses a fixed service name
    // ("flutter_secure_storage_service") and stores the logical
    // key as the account attribute.
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "flutter_secure_storage_service",
      kSecAttrAccount as String: AppDelegate.keychainTokenKey,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  /// Fetch the count of channels/DMs with activity newer than
  /// `sinceTimestamp`. Uses the same REST endpoints that the
  /// Dart workspace loader calls.
  private func fetchNewMessageCount(
    apiBaseUrl: String,
    serverId: String,
    token: String,
    sinceTimestamp: TimeInterval,
    completion: @escaping (Int) -> Void
  ) {
    let session = URLSession(configuration: .ephemeral)
    var channelCount = 0
    var dmCount = 0
    let group = DispatchGroup()

    let headers = [
      "Authorization": "Bearer \(token)",
      "X-Server-Id": serverId,
      "Accept": "application/json",
    ]

    // Fetch channels
    group.enter()
    if var components = URLComponents(string: "\(apiBaseUrl)/channels") {
      var request = URLRequest(url: components.url!)
      headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
      request.timeoutInterval = 20

      session.dataTask(with: request) { data, _, error in
        defer { group.leave() }
        guard error == nil, let data else { return }
        channelCount = self.countNewItems(
          data: data,
          sinceTimestamp: sinceTimestamp,
          activityKey: "lastActivityAt"
        )
      }.resume()
    } else {
      group.leave()
    }

    // Fetch DMs
    group.enter()
    if var components = URLComponents(string: "\(apiBaseUrl)/channels/dm") {
      var request = URLRequest(url: components.url!)
      headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
      request.timeoutInterval = 20

      session.dataTask(with: request) { data, _, error in
        defer { group.leave() }
        guard error == nil, let data else { return }
        dmCount = self.countNewItems(
          data: data,
          sinceTimestamp: sinceTimestamp,
          activityKey: "lastActivityAt"
        )
      }.resume()
    } else {
      group.leave()
    }

    group.notify(queue: .main) {
      completion(channelCount + dmCount)
    }
  }

  /// Count items in a JSON array that have a date field newer than
  /// the given timestamp.
  private func countNewItems(
    data: Data,
    sinceTimestamp: TimeInterval,
    activityKey: String
  ) -> Int {
    guard sinceTimestamp > 0 else {
      // No previous sync — don't spam the user with all
      // existing messages. Just record the timestamp.
      return 0
    }

    guard let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return 0
    }

    let sinceDate = Date(timeIntervalSince1970: sinceTimestamp)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    return items.filter { item in
      guard let dateString = item[activityKey] as? String,
            let date = formatter.date(from: dateString) else {
        return false
      }
      return date > sinceDate
    }.count
  }

  /// Show a local notification summarizing new messages found
  /// during background sync.
  private func showSyncNotification(messageCount: Int) {
    let content = UNMutableNotificationContent()
    content.title = "Slock"
    content.body = messageCount == 1
      ? "You have a new message"
      : "You have new messages in \(messageCount) conversations"
    content.sound = .default
    content.badge = NSNumber(value: messageCount)
    content.userInfo = ["slock.bgSync": true]

    let request = UNNotificationRequest(
      identifier: "slock-bg-sync-\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }
}

private class StreamHandler: NSObject, FlutterStreamHandler {
  var onSinkReady: ((@escaping FlutterEventSink) -> Void)?
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
