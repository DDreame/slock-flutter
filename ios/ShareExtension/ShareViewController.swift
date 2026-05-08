import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedContent()
    }

    // MARK: - Share handling

    private func handleSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }

        let group = DispatchGroup()
        var sharedItems: [[String: Any]] = []

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                group.enter()

                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { data, _ in
                        if let url = data as? URL {
                            sharedItems.append([
                                "type": "url",
                                "path": url.absoluteString,
                            ])
                        }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.text.identifier) { data, _ in
                        if let text = data as? String {
                            sharedItems.append([
                                "type": "text",
                                "path": text,
                            ])
                        }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier) { data, _ in
                        if let url = data as? URL {
                            sharedItems.append([
                                "type": "image",
                                "path": url.path,
                                "mimeType": "image/jpeg",
                            ])
                        }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.movie.identifier) { data, _ in
                        if let url = data as? URL {
                            sharedItems.append([
                                "type": "video",
                                "path": url.path,
                                "mimeType": "video/mp4",
                            ])
                        }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.data.identifier) { data, _ in
                        if let url = data as? URL {
                            sharedItems.append([
                                "type": "file",
                                "path": url.path,
                                "mimeType": "application/octet-stream",
                            ])
                        }
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.saveSharedItems(sharedItems)
            self?.openMainApp()
            self?.completeRequest()
        }
    }

    // MARK: - Data passing

    private func saveSharedItems(_ items: [[String: Any]]) {
        guard let userDefaults = UserDefaults(suiteName: "group.app.slock.shared") else { return }
        userDefaults.set(items, forKey: "SharedMedia")
        userDefaults.synchronize()
    }

    private func openMainApp() {
        guard let url = URL(string: "slock://share") else { return }
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let application = nextResponder as? UIApplication {
                application.open(url)
                return
            }
            responder = nextResponder
        }
    }

    // MARK: - Completion

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
