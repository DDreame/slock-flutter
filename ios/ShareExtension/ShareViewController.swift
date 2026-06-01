import UIKit
import UniformTypeIdentifiers

private let appGroupId = "group.app.slock.shared"
private let userDefaultsKey = "ShareKey"
private let userDefaultsMessageKey = "ShareMessageKey"
private let hostBundleIdentifier = "com.slock.slockApp"

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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        handleSharedContent()
    }

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
            let items = self.sharedItemsQueue.sync { self.sharedItems }
            self.saveSharedItems(items)
            self.openMainApp()
            self.completeRequest()
        }
    }

    private func loadLiteral(
        _ provider: NSItemProvider,
        typeIdentifier: String,
        type: SharedMediaType,
        group: DispatchGroup
    ) {
        group.enter()
        provider.loadItem(forTypeIdentifier: typeIdentifier) { [weak self] data, _ in
            defer { group.leave() }
            let value: String?
            if let text = data as? String {
                value = text
            } else if let url = data as? URL {
                value = url.absoluteString
            } else {
                value = nil
            }
            guard let value, !value.isEmpty else { return }
            self?.append(
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

    private func loadFile(
        _ provider: NSItemProvider,
        typeIdentifier: String,
        type: SharedMediaType,
        defaultMimeType: String,
        group: DispatchGroup
    ) {
        group.enter()
        provider.loadItem(forTypeIdentifier: typeIdentifier) { [weak self] data, _ in
            defer { group.leave() }
            guard let self else { return }

            if let url = data as? URL,
               let copied = self.copyToSharedContainer(url) {
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

            if let image = data as? UIImage,
               let copied = self.writeImageToSharedContainer(image) {
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
            }
        }
    }

    private func append(_ item: SharedMediaFile) {
        sharedItemsQueue.sync {
            sharedItems.append(item)
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
