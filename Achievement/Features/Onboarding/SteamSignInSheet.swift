import SwiftUI
import WebKit
import AchievementCore

/// Steam sign-in via OpenID 2.0 in an embedded web view.
///
/// Steam offers no OAuth for third parties, and `ASWebAuthenticationSession`
/// requires a resolvable redirect we don't have without a server — so we host
/// the flow in `WKWebView` and intercept the `return_to` navigation before it
/// loads. The callback is then cryptographically verified with Steam
/// (`check_authentication`) before any SteamID is trusted.
struct SteamSignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCallback: (URL) -> Void

    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            SteamWebView(isLoading: $isLoading) { url in
                onCallback(url)
            }
            .overlay(alignment: .top) {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .padding(.top, 120)
                }
            }
            .navigationTitle("Steam Sign-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct SteamWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    let onCallback: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: SteamOpenID.authenticationURL(
            returnTo: AppConfig.openIDReturnTo,
            realm: AppConfig.openIDRealm
        )))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: SteamWebView
        private var didComplete = false

        init(_ parent: SteamWebView) {
            self.parent = parent
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               SteamOpenID.isCallback(url, returnTo: AppConfig.openIDReturnTo),
               !didComplete {
                didComplete = true
                decisionHandler(.cancel)
                parent.onCallback(url)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            parent.isLoading = false
        }
    }
}
