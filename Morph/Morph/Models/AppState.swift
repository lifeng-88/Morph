import SwiftUI
import UIKit

enum MorphTab: Int, CaseIterable {
    case home, templates, draw, my

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .templates: return "sparkles.rectangle.stack.fill"
        case .draw: return "paintbrush.fill"
        case .my: return "person.fill"
        }
    }
}

struct TemplateItem: Identifiable, Hashable {
    var id: String { nameKey }
    let nameKey: String
    let categoryKey: String
    let coinCost: Int
    let imageAsset: String
    var isLarge: Bool = false
}

struct GalleryItem: Identifiable, Codable, Hashable {
    let id: UUID
    let templateNameKey: String
    let imageAsset: String?
    let localImageFilename: String?
    let sourceLocalImageFilename: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        templateNameKey: String,
        imageAsset: String? = nil,
        localImageFilename: String? = nil,
        sourceLocalImageFilename: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.templateNameKey = templateNameKey
        self.imageAsset = imageAsset
        self.localImageFilename = localImageFilename
        self.sourceLocalImageFilename = sourceLocalImageFilename
        self.createdAt = createdAt
    }

    func loadUIImage() -> UIImage? {
        if let localImageFilename,
           let image = ResultImageStore.load(localImageFilename) {
            return image
        }
        if let imageAsset,
           let image = PhotoLibraryService.loadUIImage(named: imageAsset) {
            return image
        }
        return nil
    }

    func loadSourceUIImage() -> UIImage? {
        guard let sourceLocalImageFilename else { return nil }
        return ResultImageStore.load(sourceLocalImageFilename)
    }

    var linkedTemplate: TemplateItem? {
        TemplateCatalog.templates.first { $0.nameKey == templateNameKey }
    }

    var showsTransformationInputs: Bool {
        loadSourceUIImage() != nil || linkedTemplate != nil
    }
}

struct CoinPack: Identifiable, Hashable {
    let id: String
    let packageId: Int
    let gold: Int
    let bonus: Int
    let productID: String
    let fallbackPrice: String
    let isRecommended: Bool

    var totalCoins: Int { gold + bonus }

    var bonusLabel: String? {
        guard bonus > 0 else { return nil }
        return "+\(bonus)"
    }
}

@MainActor
final class AppState: ObservableObject {
    private enum StorageKey {
        static let coins = "morph.coins"
        static let favorites = "morph.favoriteTemplateIDs"
        static let gallery = "morph.gallery"
        static let onboardingCompleted = "morph.onboarding.completed"
    }

    @Published var selectedTab: MorphTab = .home
    @Published var coins: Int {
        didSet { UserDefaults.standard.set(coins, forKey: StorageKey.coins) }
    }
    @Published var sourcePhotoAsset: String?
    @Published var sourceImage: UIImage?
    @Published var selectedTemplate: TemplateItem?
    @Published var resultPhotoAsset: String?
    @Published var resultImage: UIImage?
    @Published var hdQuality = true
    @Published var faceEnhancement = true
    @Published var showPhotoGuide = false
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    @Published var processingError: String?
    @Published var showResult = false
    @Published var gallery: [GalleryItem] = []
    @Published var favoriteTemplateIDs: Set<String> = []
    @Published var showInsufficientCoins = false
    @Published var showCoinStore = false
    @Published var selectedGalleryItem: GalleryItem?
    @Published var showOnboarding: Bool
    @Published var showAIDataConsent = false

    private var pendingConsentAction: (() -> Void)?

    let categoryKeys: [String] = [
        "category.all",
        "category.classic_portraits",
        "category.cyberpunk",
        "category.goddess",
        "category.anime"
    ]

    var coinPacks: [CoinPack] {
        MorphCoinCatalog.activePacks
    }

    let templates: [TemplateItem] = TemplateCatalog.templates

    init() {
        showOnboarding = !UserDefaults.standard.bool(forKey: StorageKey.onboardingCompleted)

        let storedCoins = UserDefaults.standard.object(forKey: StorageKey.coins) as? Int
        coins = storedCoins ?? 200

        if let favoriteIDs = UserDefaults.standard.stringArray(forKey: StorageKey.favorites) {
            favoriteTemplateIDs = Set(favoriteIDs)
        } else {
            favoriteTemplateIDs = ["template.royal_noir"]
            persistFavorites()
        }

        if let data = UserDefaults.standard.data(forKey: StorageKey.gallery),
           let items = try? JSONDecoder().decode([GalleryItem].self, from: data) {
            gallery = items
        }
    }

    func isFavorite(_ template: TemplateItem) -> Bool {
        favoriteTemplateIDs.contains(template.id)
    }

    func toggleFavorite(_ template: TemplateItem) {
        if favoriteTemplateIDs.contains(template.id) {
            favoriteTemplateIDs.remove(template.id)
        } else {
            favoriteTemplateIDs.insert(template.id)
        }
        persistFavorites()
    }

    func selectPhoto(_ image: UIImage? = nil) {
        if let image {
            sourceImage = image
            sourcePhotoAsset = nil
        } else {
            sourceImage = nil
            sourcePhotoAsset = nil
        }
        showPhotoGuide = false
    }

    func sourceUIImage() -> UIImage? {
        if let sourceImage { return sourceImage }
        if let sourcePhotoAsset {
            return PhotoLibraryService.loadUIImage(named: sourcePhotoAsset)
        }
        return nil
    }

    @discardableResult
    func startTransformation() -> Bool {
        guard let template = selectedTemplate else { return false }
        guard hasSourcePhoto else { return false }
        guard coins >= template.coinCost else {
            showInsufficientCoins = true
            return false
        }
        coins -= template.coinCost
        processingProgress = 0
        processingError = nil
        isProcessing = true
        return true
    }

    func performTransformation() async {
        guard AIDataConsentManager.hasGranted else {
            failTransformation(refund: selectedTemplate?.coinCost ?? 0, message: L10n.aiConsentRequiredError)
            return
        }

        guard let template = selectedTemplate else {
            isProcessing = false
            return
        }

        guard let source = sourceUIImage(),
              let templateImage = PhotoLibraryService.loadUIImage(named: template.imageAsset) else {
            failTransformation(refund: template.coinCost, message: L10n.processingErrorNoPhoto)
            return
        }

        let service = FaceSwapServiceFactory.make()
        let request = FaceSwapRequest(
            sourceImage: source,
            templateId: template.id,
            templateImage: templateImage,
            templateCategoryKey: template.categoryKey,
            hdQuality: hdQuality,
            faceEnhancement: faceEnhancement
        )

        do {
            let result = try await service.swap(request) { [weak self] value in
                Task { @MainActor in
                    self?.processingProgress = value
                }
            }
            completeTransformation(with: result)
        } catch {
            failTransformation(refund: template.coinCost, message: error.localizedDescription)
        }
    }

    func completeTransformation(with image: UIImage) {
        resultImage = image
        resultPhotoAsset = nil
        isProcessing = false
        processingProgress = 1
        showResult = true

        if let template = selectedTemplate {
            let filename = (try? ResultImageStore.save(image)) ?? nil
            let sourceFilename = sourceUIImage().flatMap { try? ResultImageStore.save($0) }
            gallery.insert(
                GalleryItem(
                    templateNameKey: template.nameKey,
                    imageAsset: filename == nil ? SampleImages.result : nil,
                    localImageFilename: filename,
                    sourceLocalImageFilename: sourceFilename,
                    createdAt: Date()
                ),
                at: 0
            )
            persistGallery()
        }
    }

    func failTransformation(refund: Int, message: String) {
        coins += refund
        processingError = message
        isProcessing = false
        processingProgress = 0
    }

    @discardableResult
    func startSmartDraw(style: SmartDrawStyle) -> Bool {
        let cost = style.coinCost
        guard coins >= cost else {
            showInsufficientCoins = true
            return false
        }
        coins -= cost
        return true
    }

    func failSmartDraw(refund: Int) {
        coins += refund
    }

    func purchaseCoins(_ amount: Int) {
        coins += amount
        showCoinStore = false
        showInsufficientCoins = false
    }

    func grantPurchasedCoins(_ amount: Int) {
        guard amount > 0 else { return }
        coins += amount
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: StorageKey.onboardingCompleted)
        showOnboarding = false
    }

    func requestAIDataConsentThenPerform(_ action: @escaping () -> Void) {
        if AIDataConsentManager.hasGranted {
            action()
            return
        }
        pendingConsentAction = action
        showAIDataConsent = true
    }

    func grantAIDataConsentAndContinue() {
        AIDataConsentManager.grant()
        showAIDataConsent = false
        pendingConsentAction?()
        pendingConsentAction = nil
    }

    func declineAIDataConsent() {
        showAIDataConsent = false
        pendingConsentAction = nil
    }

    var hasSourcePhoto: Bool {
        sourceImage != nil || sourcePhotoAsset != nil
    }

    var recentGalleryItems: [GalleryItem] {
        Array(gallery.prefix(6))
    }

    func deleteGalleryItem(_ item: GalleryItem) {
        if let filename = item.localImageFilename {
            ResultImageStore.delete(filename)
        }
        if let sourceFilename = item.sourceLocalImageFilename {
            ResultImageStore.delete(sourceFilename)
        }
        gallery.removeAll { $0.id == item.id }
        if selectedGalleryItem?.id == item.id {
            selectedGalleryItem = nil
        }
        persistGallery()
    }

    func templates(for categoryKey: String) -> [TemplateItem] {
        TemplateCatalog.templates(for: categoryKey)
    }

    func returnToTemplatesFromResult() {
        resultPhotoAsset = nil
        resultImage = nil
        selectedTemplate = nil
        showResult = false
        selectedTab = .templates
    }

    func addDrawingToGallery(_ image: UIImage) {
        let filename = try? ResultImageStore.save(image)
        gallery.insert(
            GalleryItem(
                templateNameKey: "draw.creation",
                imageAsset: filename == nil ? SampleImages.result : nil,
                localImageFilename: filename,
                createdAt: Date()
            ),
            at: 0
        )
        persistGallery()
    }

    func resultUIImage() -> UIImage? {
        if let resultImage { return resultImage }
        if let asset = resultPhotoAsset {
            return PhotoLibraryService.loadUIImage(named: asset)
        }
        return nil
    }

    private func persistFavorites() {
        UserDefaults.standard.set(Array(favoriteTemplateIDs), forKey: StorageKey.favorites)
    }

    private func persistGallery() {
        if let data = try? JSONEncoder().encode(gallery) {
            UserDefaults.standard.set(data, forKey: StorageKey.gallery)
        }
    }
}

enum MorphCoinCatalog {
    /// 与 B 面 H5 充值套餐一致（packageId + App Store productID + 金币数量）
    static let packs: [CoinPack] = [
        CoinPack(
            id: "coins_20",
            packageId: 1_780_024_391,
            gold: 20,
            bonus: 0,
            productID: "com.morph.app.coins_20",
            fallbackPrice: "$4.99",
            isRecommended: false
        ),
        CoinPack(
            id: "coins_40",
            packageId: 1_780_024_409,
            gold: 40,
            bonus: 10,
            productID: "com.morph.app.coins_40",
            fallbackPrice: "$9.99",
            isRecommended: true
        ),
        CoinPack(
            id: "coins_80",
            packageId: 1_780_024_435,
            gold: 80,
            bonus: 40,
            productID: "com.morph.app.coins_80",
            fallbackPrice: "$19.99",
            isRecommended: false
        ),
        CoinPack(
            id: "coins_200",
            packageId: 1_780_024_488,
            gold: 200,
            bonus: 140,
            productID: "com.morph.app.coins_200",
            fallbackPrice: "$49.99",
            isRecommended: false
        ),
        CoinPack(
            id: "coins_400",
            packageId: 1_780_024_507,
            gold: 400,
            bonus: 400,
            productID: "com.morph.app.coins_400",
            fallbackPrice: "$99.99",
            isRecommended: false
        ),
        CoinPack(
            id: "coins_800",
            packageId: 1_780_024_556,
            gold: 800,
            bonus: 1200,
            productID: "com.morph.app.coins_800",
            fallbackPrice: "$199.99",
            isRecommended: false
        ),
        CoinPack(
            id: "coins_1200",
            packageId: 1_780_024_583,
            gold: 1200,
            bonus: 2400,
            productID: "com.morph.app.coins_1200",
            fallbackPrice: "$299.99",
            isRecommended: false
        )
    ]

    static var activePacks: [CoinPack] { packs }

    static var productIDs: Set<String> {
        Set(packs.map(\.productID))
    }

    static func totalCoins(for productID: String) -> Int? {
        packs.first { $0.productID == productID }?.totalCoins
    }

    static func pack(for productID: String) -> CoinPack? {
        packs.first { $0.productID == productID }
    }

    static func pack(forPackageId packageId: Int) -> CoinPack? {
        packs.first { $0.packageId == packageId }
    }
}
