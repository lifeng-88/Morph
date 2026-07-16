import Foundation

enum L10n {
    static var appName: String { tr("app.name") }

    // MARK: - Tabs
    static var tabHome: String { tr("tab.home") }
    static var tabTemplates: String { tr("tab.templates") }
    static var tabDraw: String { tr("tab.draw") }
    static var tabMy: String { tr("tab.my") }

    // MARK: - Home
    static var homeHeroTitle: String { tr("home.hero.title") }
    static var homeHeroSubtitle: String { tr("home.hero.subtitle") }
    static var homeContinueTitle: String { tr("home.continue.title") }
    static var homeContinueSubtitle: String { tr("home.continue.subtitle") }
    static var homeRecentTitle: String { tr("home.recent.title") }
    static var homeUploadPhoto: String { tr("home.upload_photo") }
    static var guideBestResults: String { tr("guide.best_results") }
    static var guideProTips: String { tr("guide.pro_tips") }
    static var guideGoodReference: String { tr("guide.good_reference") }
    static var guideSelectGallery: String { tr("guide.select_gallery") }
    static var tipFrontFacingTitle: String { tr("tip.front_facing.title") }
    static var tipFrontFacingSubtitle: String { tr("tip.front_facing.subtitle") }
    static var tipLightingTitle: String { tr("tip.lighting.title") }
    static var tipLightingSubtitle: String { tr("tip.lighting.subtitle") }
    static var tipNoCoveringTitle: String { tr("tip.no_covering.title") }
    static var tipNoCoveringSubtitle: String { tr("tip.no_covering.subtitle") }

    // MARK: - Templates
    static var templatesTitle: String { tr("templates.title") }
    static var templatesHeaderTitle: String { tr("templates.header.title") }
    static var templatesHeaderSubtitle: String { tr("templates.header.subtitle") }
    static var categoryAll: String { tr("category.all") }
    static var categoryClassicPortraits: String { tr("category.classic_portraits") }
    static var categoryCyberpunk: String { tr("category.cyberpunk") }
    static var categoryGoddess: String { tr("category.goddess") }
    static var categoryAnime: String { tr("category.anime") }
    static var searchTemplates: String { tr("templates.search") }
    static var loadMoreTemplates: String { tr("templates.load_more") }
    static var loadingMoreTemplates: String { tr("templates.loading_more") }
    static var noMoreTemplates: String { tr("templates.no_more") }
    static var noTemplatesInCategory: String { tr("templates.empty.category") }
    static var noFavorites: String { tr("templates.empty.favorites") }
    static var favoriteTemplates: String { tr("my.section.favorites") }

    // MARK: - Confirm
    static var sourcePhoto: String { tr("confirm.source_photo") }
    static var selectedTemplate: String { tr("confirm.selected_template") }
    static var processingSettings: String { tr("confirm.processing_settings") }
    static var hdQuality: String { tr("confirm.hd_quality") }
    static var hdQualitySubtitle: String { tr("confirm.hd_quality.subtitle") }
    static var faceEnhancement: String { tr("confirm.face_enhancement") }
    static var faceEnhancementSubtitle: String { tr("confirm.face_enhancement.subtitle") }
    static var confirmInfo: String { tr("confirm.info") }
    static var startTransformation: String { tr("confirm.start") }
    static var changeSourcePhoto: String { tr("confirm.change_source") }
    static var takePhoto: String { tr("confirm.take_photo") }
    static var changeTemplate: String { tr("confirm.change_template") }
    static var selectSourcePhoto: String { tr("confirm.select_photo") }

    // MARK: - Draw
    static var drawHint: String { tr("draw.hint") }
    static var drawSelectBrushHint: String { tr("draw.select_brush.hint") }
    static var drawCancelBrush: String { tr("draw.cancel_brush") }
    static var drawClear: String { tr("draw.clear") }
    static var drawSave: String { tr("draw.save") }
    static var drawSmartTitle: String { tr("draw.smart.title") }
    static var drawSmartSubtitle: String { tr("draw.smart.subtitle") }
    static var drawSmartPick: String { tr("draw.smart.pick") }
    static var drawSmartGenerate: String { tr("draw.smart.generate") }
    static var drawSmartProcessing: String { tr("draw.smart.processing") }
    static var drawSmartFailed: String { tr("draw.smart.failed") }
    static var drawRestoreInitial: String { tr("draw.restore.initial") }
    static var drawZoomIn: String { tr("draw.zoom.in") }
    static var drawZoomOut: String { tr("draw.zoom.out") }
    static var drawZoomReset: String { tr("draw.zoom.reset") }
    static var drawFullscreen: String { tr("draw.fullscreen") }
    static var drawExitFullscreen: String { tr("draw.exit_fullscreen") }
    static var drawFullscreenHint: String { tr("draw.fullscreen.hint") }
    static var drawBrushSize: String { tr("draw.brush.size") }
    static var drawColorCustom: String { tr("draw.color.custom") }
    static func drawColorHex(_ hex: String) -> String {
        String(format: tr("draw.color.hex"), hex)
    }
    static var drawFullscreenTools: String { tr("draw.fullscreen.tools") }
    static var drawFullscreenImmersive: String { tr("draw.fullscreen.immersive") }

    // MARK: - Processing
    static var processingTitle: String { tr("processing.title") }
    static var processingSubtitle: String { tr("processing.subtitle") }
    static var processingSubtitleRemote: String { tr("processing.subtitle.remote") }
    static var processingErrorTitle: String { tr("processing.error.title") }
    static var processingErrorNoPhoto: String { tr("processing.error.no_photo") }

    // MARK: - Result
    static var createdWithMorph: String { tr("result.watermark") }
    static var shareMetamorphosis: String { tr("result.share_title") }
    static var downloadHighRes: String { tr("result.download") }
    static var saving: String { tr("result.saving") }
    static var savedToGallery: String { tr("result.saved") }
    static var tryAnotherTemplate: String { tr("result.try_another") }
    static var share: String { tr("result.share") }
    static var shareMessage: String { tr("result.share.message") }

    // MARK: - Gallery
    static var myGalleryTitle: String { tr("gallery.title") }
    static var galleryEmptyTitle: String { tr("gallery.empty.title") }
    static var galleryEmptySubtitle: String { tr("gallery.empty.subtitle") }
    static var browseTemplates: String { tr("gallery.browse") }
    static var galleryDelete: String { tr("gallery.delete") }
    static var galleryDeleteConfirm: String { tr("gallery.delete.confirm") }

    // MARK: - Onboarding
    static var onboardingPage1Title: String { tr("onboarding.page1.title") }
    static var onboardingPage1Subtitle: String { tr("onboarding.page1.subtitle") }
    static var onboardingPage2Title: String { tr("onboarding.page2.title") }
    static var onboardingPage2Subtitle: String { tr("onboarding.page2.subtitle") }
    static var onboardingPage3Title: String { tr("onboarding.page3.title") }
    static var onboardingPage3Subtitle: String { tr("onboarding.page3.subtitle") }
    static var onboardingPage4Title: String { tr("onboarding.page4.title") }
    static var onboardingPage4Subtitle: String { tr("onboarding.page4.subtitle") }
    static var onboardingNext: String { tr("onboarding.next") }
    static var onboardingSkip: String { tr("onboarding.skip") }
    static var onboardingStart: String { tr("onboarding.start") }

    // MARK: - Settings
    static var settingsLanguage: String { tr("settings.language") }
    static var settingsLanguageHint: String { tr("settings.language.hint") }
    static var languageSystem: String { tr("settings.language.system") }
    static var languageEnglish: String { tr("settings.language.english") }
    static var languageTraditionalChinese: String { tr("settings.language.traditional_chinese") }
    static var languageSimplifiedChinese: String { tr("settings.language.simplified_chinese") }
    static var mySectionGallery: String { tr("my.section.gallery") }
    static var settingsGeneral: String { tr("settings.general") }
    static var settingsVersion: String { tr("settings.version") }
    static var settingsAPIStatus: String { tr("settings.api_status") }
    static var settingsAPIConnected: String { tr("settings.api.connected") }
    static var settingsAPILocal: String { tr("settings.api.local") }
    static var settingsRestorePurchases: String { tr("settings.restore_purchases") }
    static var settingsRestoreTitle: String { tr("settings.restore.title") }
    static var settingsRestoreMessage: String { tr("settings.restore.message") }
    static var settingsDevIdCopiedTitle: String { tr("settings.dev_id.copied.title") }
    static var settingsDevIdCopiedMessage: String { tr("settings.dev_id.copied.message") }
    static var settingsAppearance: String { tr("settings.appearance") }
    static var settingsAppearanceHint: String { tr("settings.appearance.hint") }
    static var appearanceSystem: String { tr("settings.appearance.system") }
    static var appearanceLight: String { tr("settings.appearance.light") }
    static var appearanceDark: String { tr("settings.appearance.dark") }
    static var settingsBSideTitle: String { tr("settings.bside.title") }
    static var settingsBSideHint: String { tr("settings.bside.hint") }
    static var settingsBSideOpen: String { tr("settings.bside.open") }
    static var panelClose: String { tr("panel.close") }

    // MARK: - Coins
    static var coinStoreTitle: String { tr("coin_store.title") }
    static var coinStoreBalance: String { tr("coin_store.balance") }
    static var coinStorePacks: String { tr("coin_store.packs") }
    static var insufficientCoinsTitle: String { tr("coins.insufficient.title") }
    static var insufficientCoinsMessage: String { tr("coins.insufficient.message") }
    static var insufficientCoinsDrawMessage: String { tr("coins.insufficient.draw.message") }
    static var getCoins: String { tr("coins.get") }
    static var coinStoreSandboxHint: String { tr("coin_store.sandbox_hint") }
    static var coinStoreRecommended: String { tr("coin_store.recommended") }
    static var coinStoreProductUnavailable: String { tr("coin_store.product_unavailable") }
    static var coinStorePurchaseFailed: String { tr("coin_store.purchase_failed") }
    static var coinStorePurchasePending: String { tr("coin_store.purchase_pending") }
    static var coinStoreProductsUnavailable: String { tr("coin_store.products_unavailable") }
    static var coinStoreRetry: String { tr("coin_store.retry") }
    static var coinStorePurchaseSuccessTitle: String { tr("coin_store.purchase_success.title") }
    static var coinStoreRestore: String { tr("coin_store.restore") }
    static var coinStoreConsumableNotice: String { tr("coin_store.consumable_notice") }
    static var coinStoreVerificationFailed: String { tr("coin_store.verification_failed") }
    static var coinStorePurchaseNotAllowed: String { tr("coin_store.purchase_not_allowed") }
    static var coinStorePartialProducts: String { tr("coin_store.partial_products") }
    static var coinStoreEstimatedPrice: String { tr("coin_store.estimated_price") }

    static func coinStorePurchaseSuccessMessage(_ coins: Int) -> String {
        String(format: tr("coin_store.purchase_success.message"), coins)
    }

    // MARK: - Privacy & AI Consent
    static var privacySectionTitle: String { tr("privacy.section.title") }
    static var privacyPolicyTitle: String { tr("privacy.policy.title") }
    static var aiConsentTitle: String { tr("ai.consent.title") }
    static var aiConsentSubtitle: String { tr("ai.consent.subtitle") }
    static var aiConsentDataTitle: String { tr("ai.consent.data.title") }
    static var aiConsentDataBody: String { tr("ai.consent.data.body") }
    static var aiConsentRecipientTitle: String { tr("ai.consent.recipient.title") }
    static var aiConsentRecipientBody: String { tr("ai.consent.recipient.body") }
    static var aiConsentPurposeTitle: String { tr("ai.consent.purpose.title") }
    static var aiConsentPurposeBody: String { tr("ai.consent.purpose.body") }
    static var aiConsentRetentionTitle: String { tr("ai.consent.retention.title") }
    static var aiConsentRetentionBody: String { tr("ai.consent.retention.body") }
    static var aiConsentPrivacyLink: String { tr("ai.consent.privacy_link") }
    static var aiConsentAgree: String { tr("ai.consent.agree") }
    static var aiConsentDecline: String { tr("ai.consent.decline") }
    static var aiConsentFootnote: String { tr("ai.consent.footnote") }
    static var aiConsentRequiredError: String { tr("ai.consent.required_error") }
    static var aiConsentBlocked: String { tr("ai.consent.blocked") }
    static var aiConsentStatusTitle: String { tr("ai.consent.status.title") }
    static var aiConsentStatusGranted: String { tr("ai.consent.status.granted") }
    static var aiConsentStatusNotGranted: String { tr("ai.consent.status.not_granted") }
    static var aiConsentRevoke: String { tr("ai.consent.revoke") }
    static var aiConsentRevokeTitle: String { tr("ai.consent.revoke.title") }
    static var aiConsentRevokeConfirm: String { tr("ai.consent.revoke.confirm") }
    static var aiConsentRevokeMessage: String { tr("ai.consent.revoke.message") }

    static var cancel: String { tr("common.cancel") }
    static var done: String { tr("common.done") }
    static var retry: String { tr("common.retry") }

    // MARK: - Helpers
    static func coins(_ count: Int) -> String {
        String(format: tr("coins.format"), count)
    }

    static func localized(_ key: String) -> String {
        tr(key)
    }

    private static func tr(_ key: String) -> String {
        LanguageManager.shared.localizedString(key)
    }
}

extension AppLanguage {
    var displayName: String {
        switch self {
        case .system: return L10n.languageSystem
        case .english: return L10n.languageEnglish
        case .simplifiedChinese: return L10n.languageSimplifiedChinese
        case .traditionalChinese: return L10n.languageTraditionalChinese
        }
    }
}

extension AppAppearance {
    var displayName: String {
        switch self {
        case .system: return L10n.appearanceSystem
        case .light: return L10n.appearanceLight
        case .dark: return L10n.appearanceDark
        }
    }
}

extension TemplateItem {
    var localizedName: String { L10n.localized(nameKey) }
    var localizedCategory: String { L10n.localized(categoryKey) }
}

extension GalleryItem {
    var localizedTemplateName: String { L10n.localized(templateNameKey) }
}

extension SmartDrawStyle {
    var localizedName: String { L10n.localized(nameKey) }
}

extension MorphTab {
    var localizedTitle: String {
        switch self {
        case .home: return L10n.tabHome
        case .templates: return L10n.tabTemplates
        case .draw: return L10n.tabDraw
        case .my: return L10n.tabMy
        }
    }
}
