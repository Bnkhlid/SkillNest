import Social
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
  private let appGroup = "group.com.learningvault.learningVault"
  private let sharedTextKey = "skillnest.sharedText"
  private var hasSubmitted = false

  override func isContentValid() -> Bool { true }
  override func configurationItems() -> [Any]! { [] }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !hasSubmitted else { return }
    hasSubmitted = true
    didSelectPost()
  }

  override func didSelectPost() {
    extractSharedText { [weak self] text in
      guard let self = self else { return }
      let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
      if let trimmed = trimmed, !trimmed.isEmpty {
        UserDefaults(suiteName: self.appGroup)?.set(trimmed, forKey: self.sharedTextKey)
        UserDefaults(suiteName: self.appGroup)?.synchronize()
      }
      self.openSkillNest()
    }
  }

  private func extractSharedText(completion: @escaping (String?) -> Void) {
    guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
          let providers = item.attachments, !providers.isEmpty else {
      completion(contentText)
      return
    }

    // 1. Check for public.url in all providers first
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier("public.url") {
        provider.loadItem(forTypeIdentifier: "public.url", options: nil) { item, _ in
          if let url = item as? URL {
            completion(url.absoluteString)
            return
          } else if let str = item as? String, !str.isEmpty {
            completion(str)
            return
          }
          completion(self.contentText)
        }
        return
      }
    }

    // 2. Check for public.plain-text or public.text
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier("public.plain-text") ||
         provider.hasItemConformingToTypeIdentifier("public.text") {
        let typeId = provider.hasItemConformingToTypeIdentifier("public.plain-text") ? "public.plain-text" : "public.text"
        provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
          if let text = item as? String, !text.isEmpty {
            completion(text)
            return
          } else if let url = item as? URL {
            completion(url.absoluteString)
            return
          }
          completion(self.contentText)
        }
        return
      }
    }

    completion(contentText)
  }

  private func openSkillNest() {
    guard let url = URL(string: "skillnest://shared") else {
      finish()
      return
    }

    // Standard responder chain method to open host app from iOS Share Extension
    var responder: UIResponder? = self
    let selector = sel_registerName("openURL:")
    var opened = false

    while let r = responder {
      if r.responds(to: selector) {
        r.perform(selector, with: url)
        opened = true
        break
      }
      responder = r.next
    }

    if !opened {
      extensionContext?.open(url) { [weak self] _ in
        self?.finish()
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
        self?.finish()
      }
    }
  }

  private func finish() {
    extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
  }
}
