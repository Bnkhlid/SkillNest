import Social
import UIKit

final class ShareViewController: SLComposeServiceViewController {
  private let appGroup = "group.com.learningvault.learningVault"
  private let sharedTextKey = "skillnest.sharedText"
  private var hasSubmitted = false

  override func isContentValid() -> Bool { true }
  override func configurationItems() -> [Any]! { [] }

  // SkillNest is a capture destination, not a social post: continue directly
  // to the app as soon as the user selects it from the system share sheet.
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !hasSubmitted else { return }
    hasSubmitted = true
    didSelectPost()
  }

  override func didSelectPost() {
    extractSharedText { [weak self] text in
      guard let self else { return }
      if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        UserDefaults(suiteName: self.appGroup)?.set(text, forKey: self.sharedTextKey)
      }
      self.openSkillNest()
    }
  }

  private func extractSharedText(completion: @escaping (String?) -> Void) {
    guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
          let providers = item.attachments else { completion(contentText); return }
    let urlProvider = providers.first { $0.hasItemConformingToTypeIdentifier("public.url") }
    if let urlProvider {
      urlProvider.loadItem(forTypeIdentifier: "public.url", options: nil) { item, _ in
        if let url = item as? URL { completion(url.absoluteString); return }
        if let text = item as? String { completion(text); return }
        completion(self.contentText)
      }
      return
    }
    let textProvider = providers.first { $0.hasItemConformingToTypeIdentifier("public.text") }
    textProvider?.loadItem(forTypeIdentifier: "public.text", options: nil) { item, _ in
      completion((item as? String) ?? self.contentText)
    } ?? completion(contentText)
  }

  private func openSkillNest() {
    guard let url = URL(string: "skillnest://shared") else { finish(); return }
    extensionContext?.open(url) { [weak self] _ in self?.finish() }
  }

  private func finish() { extensionContext?.completeRequest(returningItems: nil) }
}
