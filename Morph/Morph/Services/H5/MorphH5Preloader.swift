import Foundation

/// 保证 B 面全局最多只有一个 `MorphH5WebViewModel` / `WKWebView`，
/// 避免预加载 + SwiftUI 重建反复创建 WebContent 进程导致 `ExceededProcessCountLimit`。
@MainActor
enum MorphH5Preloader {
    private static var sharedViewModel: MorphH5WebViewModel?
    private static var sharedURL: URL?

    /// 只记录即将展示的 URL，不立刻创建 WKWebView。
    static func prepare(url: URL) {
        if sharedURL == url { return }
        // URL 变化时丢弃旧实例，避免双 WebView 并存
        if sharedViewModel != nil, sharedURL != url {
            sharedViewModel = nil
        }
        sharedURL = url
    }

    /// 兼容旧调用：不再提前创建 WebProcess。
    static func preload(url: URL) {
        prepare(url: url)
    }

    /// 取用或创建唯一的 B 面 ViewModel。
    static func viewModel(for url: URL) -> MorphH5WebViewModel {
        if let sharedViewModel, sharedURL == url {
            return sharedViewModel
        }

        // 已有实例但 URL 不同：复用同一 ViewModel 并重新 load
        if let sharedViewModel {
            sharedURL = url
            sharedViewModel.replacePageURL(url)
            return sharedViewModel
        }

        sharedURL = url
        let viewModel = MorphH5WebViewModel(pageURL: url)
        sharedViewModel = viewModel
        return viewModel
    }

    /// BSideView 初始化用；与 `viewModel(for:)` 相同，保留旧命名。
    static func takeViewModel(for url: URL) -> MorphH5WebViewModel? {
        viewModel(for: url)
    }

    static func clear() {
        sharedViewModel = nil
        sharedURL = nil
    }
}
