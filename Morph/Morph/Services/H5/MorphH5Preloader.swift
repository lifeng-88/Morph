import Foundation

@MainActor
enum MorphH5Preloader {
    private static var preloadedViewModel: MorphH5WebViewModel?
    private static var preloadedURL: URL?

    static func preload(url: URL) {
        if preloadedURL == url, let preloadedViewModel {
            preloadedViewModel.loadIfNeeded()
            return
        }

        preloadedURL = url
        let viewModel = MorphH5WebViewModel(pageURL: url)
        preloadedViewModel = viewModel
        viewModel.loadIfNeeded()
    }

    static func takeViewModel(for url: URL) -> MorphH5WebViewModel? {
        guard preloadedURL == url, let viewModel = preloadedViewModel else { return nil }
        preloadedViewModel = nil
        preloadedURL = nil
        return viewModel
    }

    static func clear() {
        preloadedViewModel = nil
        preloadedURL = nil
    }
}
