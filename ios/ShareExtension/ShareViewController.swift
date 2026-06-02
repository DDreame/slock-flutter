import UIKit
import UniformTypeIdentifiers

private let appGroupId = "group.app.slock.shared"
private let userDefaultsKey = "ShareKey"
private let userDefaultsMessageKey = "ShareMessageKey"
private let hostBundleIdentifier = "com.slock.slockApp"

/// Maximum file size allowed for share (80 MB). iOS extensions have ~120 MB
/// memory limit; this margin prevents OOM crashes during copy.
private let maxFileSizeBytes: UInt64 = 80 * 1024 * 1024

/// Timeout for loadItem calls (seconds). Prevents indefinite hangs when
/// iCloud files aren't downloaded or providers are unresponsive.
private let loadItemTimeoutSeconds: TimeInterval = 15

private struct SharedMediaFile: Codable {
    let path: String
    let mimeType: String?
    let thumbnail: String?
    let duration: Double?
    let message: String?
    let type: SharedMediaType
}

private enum SharedMediaType: String, Codable {
    case image
    case video
    case text
    case file
    case url
}

class ShareViewController: UIViewController {
    private let sharedItemsQueue = DispatchQueue(label: "app.slock.share-extension.items")
    private var sharedItems: [SharedMediaFile] = []
    private var errors: [String] = []

    // MARK: - Loading UI (P2-1)

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var loadingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Preparing to share…"
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textAlignment = .center
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLoadingUI()
        handleSharedContent()
    }

    private func setupLoadingUI() {
        view.addSubview(loadingIndicator)
        view.addSubview(loadingLabel)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 12),
            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            loadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
        loadingIndicator.startAnimating()
    }

    // MARK: - Content handling

    private func handleSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }

        let group = DispatchGroup()

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                let typeIds = ShareTypeIdentifiers.current
                if provider.hasItemConformingToTypeIdentifier(typeIds.url) {
                    loadLiteral(provider, typeIdentifier: typeIds.url, type: .url, group: group)
                } else if provider.hasItemConformingToTypeIdentifier(typeIds.text) {
                    loadLiteral(provider, typeIdentifier: typeIds.text, type: .text, group: group)
                } else if provider.hasItemConformingToTypeIdentifier(typeIds.image) {
                    loadFile(provider, typeIdentifier: typeIds.image, type: .image, defaultMimeType: "image/jpeg", group: group)
                } else if provider.hasItemConformingToTypeIdentifier(typeIds.movie) {
                    loadFile(provider, typeIdentifier: typeIds.movie, type: .video, defaultMimeType: "video/mp4", group: group)
                } else if provider.hasItemConformingToTypeIdentifier(typeIds.fileURL) {
                    loadFile(provider, typeIdentifier: typeIds.fileURL, type: .file, defaultMimeType: "application/octet-stream", group: group)
                } else if provider.hasItemConformingToTypeIdentifier(typeIds.data) {
                    loadFile(provider, typeIdentifier: typeIds.data, type: .file, defaultMimeType: "application/octet-stream", group: group)
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.loadingIndicator.stopAnimating()
            let items = self.sharedItemsQueue.sync { self.sharedItems }
            let errors = self.sharedItemsQueue.sync { self.errors }

            if items.isEmpty && !errors.isEmpty {
                // All items failed — show error and dismiss.
                self.showErrorAlert(errors)
            } else if !errors.isEmpty {
                // Partial success — share what we have but warn user.
                self.saveSharedItems(items)
                self.openMainApp()
                self.completeRequest()
            } else {
                // Full success.
                self.saveSharedItems(items)
                self.openMainApp()
                self.completeRequest()
            }
        }
    }

    // MARK: - Error UI (P2-1)

    private func showErrorAlert(_ errors: [String]) {
        let message = errors.count == 1
            ? errors[0]
            : errors.enumerated().map { "• \($0.element)" }.joined(separator: "\n")

        let alert = UIAlertController(
            title: "Unable to Share",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.completeRequest()
        })
        present(alert, animated: true)
    }

    // MARK: - Load literal (text/URL)

    private func loadLiteral(
        _ provider: NSItemProvider,
        typeIdentifier: String,
        type: SharedMediaType,
        group: DispatchGroup
    ) {
        group.enter()
        loadItemWithTimeout(provider, typeIdentifier: typeIdentifier) { [weak self] data, error in
            defer { group.leave() }
            guard let self else { return }

            if let error {
                self.appendError("Could not load content: \(error.localizedDescription)")
                return
            }

            let value: String?
            if let text = data as? String {
                value = text
            } else if let url = data as? URL {
                value = url.absoluteString
            } else {
                value = nil
            }
            guard let value, !value.isEmpty else { return }
            self.append(
                SharedMediaFile(
                    path: value,
                    mimeType: type == .text ? "text/plain" : nil,
                    thumbnail: nil,
                    duration: nil,
                    message: nil,
                    type: type
                )
            )
        }
    }

    // MARK: - Load file (image/video/file)

    private func loadFile(
        _ provider: NSItemProvider,
        typeIdentifier: String,
        type: SharedMediaType,
        defaultMimeType: String,
        group: DispatchGroup
    ) {
        group.enter()
        loadItemWithTimeout(provider, typeIdentifier: typeIdentifier) { [weak self] data, error in
            defer { group.leave() }
            guard let self else { return }

            if let error {
                self.appendError("Could not load file: \(error.localizedDescription)")
                return
            }

            if let url = data as? URL {
                // P1-1: File size check before copy.
                if let fileSize = self.fileSize(at: url), fileSize > maxFileSizeBytes {
                    let sizeMB = fileSize / (1024 * 1024)
                    self.appendError("File too large (\(sizeMB) MB). Maximum is 80 MB.")
                    return
                }
                // P2-2: Handle nil copy result with error feedback.
                guard let copied = self.copyToSharedContainer(url) else {
                    self.appendError("Failed to prepare "\(url.lastPathComponent)" for sharing.")
                    return
                }
                self.append(
                    SharedMediaFile(
                        path: copied.path,
                        mimeType: url.mimeType(defaultValue: defaultMimeType),
                        thumbnail: nil,
                        duration: nil,
                        message: nil,
                        type: type
                    )
                )
                return
            }

            if let image = data as? UIImage {
                guard let copied = self.writeImageToSharedContainer(image) else {
                    self.appendError("Failed to prepare image for sharing.")
                    return
                }
                self.append(
                    SharedMediaFile(
                        path: copied.path,
                        mimeType: "image/png",
                        thumbnail: nil,
                        duration: nil,
                        message: nil,
                        type: .image
                    )
                )
                return
            }

            // Neither URL nor UIImage — unsupported format.
            self.appendError("Unsupported file format.")
        }
    }

    // MARK: - Timeout wrapper (P1-2)

    /// Wraps `NSItemProvider.loadItem` with a timeout. Calls completion with
    /// a timeout error if the provider doesn't respond within `loadItemTimeoutSeconds`.
    private func loadItemWithTimeout(
        _ provider: NSItemProvider,
        typeIdentifier: String,
        completion: @escaping (NSSecureCoding?, Error?) -> Void
    ) {
        var completed = false
        let lock = NSLock()

        // Start the actual load.
        provider.loadItem(forTypeIdentifier: typeIdentifier) { data, error in
            lock.lock()
            guard !completed else {
                lock.unlock()
                return
            }
            completed = true
            lock.unlock()
            completion(data, error)
        }

        // Timeout after configured duration.
        DispatchQueue.global().asyncAfter(deadline: .now() + loadItemTimeoutSeconds) {
            lock.lock()
            guard !completed else {
                lock.unlock()
                return
            }
            completed = true
            lock.unlock()
            let timeoutError = NSError(
                domain: "app.slock.share-extension",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Loading timed out. The file may not be downloaded."]
            )
            completion(nil, timeoutError)
        }
    }

    // MARK: - File size check (P1-1)

    private func fileSize(at url: URL) -> UInt64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64 else {
            return nil
        }
        return size
    }

    // MARK: - Helpers

    private func append(_ item: SharedMediaFile) {
        sharedItemsQueue.sync {
            sharedItems.append(item)
        }
    }

    private func appendError(_ message: String) {
        sharedItemsQueue.sync {
            errors.append(message)
        }
    }

    private func saveSharedItems(_ items: [SharedMediaFile]) {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else { return }
        let data = try? JSONEncoder().encode(items)
        userDefaults.set(data, forKey: userDefaultsKey)
        userDefaults.set(nil, forKey: userDefaultsMessageKey)
        userDefaults.synchronize()
    }

    private func copyToSharedContainer(_ sourceURL: URL) -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        let destination = container.appendingPathComponent(uniqueFilename(for: sourceURL))
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    private func writeImageToSharedContainer(_ image: UIImage) -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId),
              let data = image.pngData() else {
            return nil
        }
        let destination = container.appendingPathComponent("shared-image-\(UUID().uuidString).png")
        do {
            try data.write(to: destination, options: .atomic)
            return destination
        } catch {
            return nil
        }
    }

    private func uniqueFilename(for url: URL) -> String {
        let name = url.lastPathComponent.isEmpty ? "shared-file" : url.lastPathComponent
        return "\(UUID().uuidString)-\(name)"
    }

    private func openMainApp() {
        guard let url = URL(string: "ShareMedia-\(hostBundleIdentifier):share") else { return }
        var responder: UIResponder? = self

        if #available(iOS 18.0, *) {
            while let current = responder {
                if let application = current as? UIApplication {
                    application.open(url, options: [:], completionHandler: nil)
                    return
                }
                responder = current.next
            }
            return
        }

        let selector = sel_registerName("openURL:")
        while let current = responder {
            if current.responds(to: selector) {
                _ = current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

private extension URL {
    func mimeType(defaultValue: String) -> String {
        if #available(iOS 14.0, *),
           let type = try? resourceValues(forKeys: [.contentTypeKey]).contentType,
           let mimeType = type.preferredMIMEType {
            return mimeType
        }
        return defaultValue
    }
}


private struct ShareTypeIdentifiers {
    let url: String
    let text: String
    let image: String
    let movie: String
    let fileURL: String
    let data: String

    static var current: ShareTypeIdentifiers {
        if #available(iOS 14.0, *) {
            return ShareTypeIdentifiers(
                url: UTType.url.identifier,
                text: UTType.text.identifier,
                image: UTType.image.identifier,
                movie: UTType.movie.identifier,
                fileURL: UTType.fileURL.identifier,
                data: UTType.data.identifier
            )
        }
        return ShareTypeIdentifiers(
            url: "public.url",
            text: "public.text",
            image: "public.image",
            movie: "public.movie",
            fileURL: "public.file-url",
            data: "public.data"
        )
    }
}
