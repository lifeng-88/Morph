import Foundation

enum SampleImages {
    static let reference = "sample_reference"
    static let source = "sample_source"
    static let result = "sample_result"

    static let templates: [String: String] = [
        "template.royal_noir": "template_royal_noir",
        "template.silk_whisper": "template_silk_whisper",
        "template.pearl_glow": "template_pearl_glow",
        "template.ceo_core": "template_ceo_core",
        "template.ivory_grace": "template_ivory_grace",
        "template.vogue_edge": "template_vogue_edge",
        "template.cyber_monolith": "template_cyber_monolith",
        "template.neon_ronin": "template_neon_ronin",
        "template.cyber_glitch": "template_cyber_glitch",
        "template.chrome_phantom": "template_chrome_phantom",
        "template.digital_bloom": "template_digital_bloom",
        "template.goddess_celestial": "template_goddess_celestial",
        "template.ethereal_light": "template_ethereal_light",
        "template.moonlit_queen": "template_moonlit_queen",
        "template.anime_sakura": "template_anime_sakura",
        "template.cherry_bloom": "template_cherry_bloom",
        "template.anime_neon_dream": "template_anime_neon_dream",
        "template.pastel_wave": "template_pastel_wave"
    ]
}

struct TemplateCategoryInfo {
    let titleKey: String
    let subtitleKey: String
}

enum TemplateCatalog {
    static let templates: [TemplateItem] = [
        // Classic Portraits — 30 ~ 80 coins
        TemplateItem(
            nameKey: "template.royal_noir",
            categoryKey: "category.classic_portraits",
            coinCost: 80,
            imageAsset: "template_royal_noir",
            isLarge: true
        ),
        TemplateItem(
            nameKey: "template.silk_whisper",
            categoryKey: "category.classic_portraits",
            coinCost: 35,
            imageAsset: "template_silk_whisper"
        ),
        TemplateItem(
            nameKey: "template.pearl_glow",
            categoryKey: "category.classic_portraits",
            coinCost: 30,
            imageAsset: "template_pearl_glow"
        ),
        TemplateItem(
            nameKey: "template.ceo_core",
            categoryKey: "category.classic_portraits",
            coinCost: 50,
            imageAsset: "template_ceo_core"
        ),
        TemplateItem(
            nameKey: "template.ivory_grace",
            categoryKey: "category.classic_portraits",
            coinCost: 65,
            imageAsset: "template_ivory_grace"
        ),
        TemplateItem(
            nameKey: "template.vogue_edge",
            categoryKey: "category.classic_portraits",
            coinCost: 70,
            imageAsset: "template_vogue_edge"
        ),

        // Cyberpunk — 40 ~ 100 coins
        TemplateItem(
            nameKey: "template.cyber_glitch",
            categoryKey: "category.cyberpunk",
            coinCost: 90,
            imageAsset: "template_cyber_glitch",
            isLarge: true
        ),
        TemplateItem(
            nameKey: "template.cyber_monolith",
            categoryKey: "category.cyberpunk",
            coinCost: 45,
            imageAsset: "template_cyber_monolith"
        ),
        TemplateItem(
            nameKey: "template.neon_ronin",
            categoryKey: "category.cyberpunk",
            coinCost: 55,
            imageAsset: "template_neon_ronin"
        ),
        TemplateItem(
            nameKey: "template.chrome_phantom",
            categoryKey: "category.cyberpunk",
            coinCost: 75,
            imageAsset: "template_chrome_phantom"
        ),

        // Goddess — 50 ~ 100 coins
        TemplateItem(
            nameKey: "template.goddess_celestial",
            categoryKey: "category.goddess",
            coinCost: 100,
            imageAsset: "template_goddess_celestial",
            isLarge: true
        ),
        TemplateItem(
            nameKey: "template.digital_bloom",
            categoryKey: "category.goddess",
            coinCost: 55,
            imageAsset: "template_digital_bloom"
        ),
        TemplateItem(
            nameKey: "template.ethereal_light",
            categoryKey: "category.goddess",
            coinCost: 70,
            imageAsset: "template_ethereal_light"
        ),
        TemplateItem(
            nameKey: "template.moonlit_queen",
            categoryKey: "category.goddess",
            coinCost: 85,
            imageAsset: "template_moonlit_queen"
        ),

        // Anime — 35 ~ 60 coins
        TemplateItem(
            nameKey: "template.anime_sakura",
            categoryKey: "category.anime",
            coinCost: 60,
            imageAsset: "template_anime_sakura",
            isLarge: true
        ),
        TemplateItem(
            nameKey: "template.cherry_bloom",
            categoryKey: "category.anime",
            coinCost: 40,
            imageAsset: "template_cherry_bloom"
        ),
        TemplateItem(
            nameKey: "template.anime_neon_dream",
            categoryKey: "category.anime",
            coinCost: 45,
            imageAsset: "template_anime_neon_dream"
        ),
        TemplateItem(
            nameKey: "template.pastel_wave",
            categoryKey: "category.anime",
            coinCost: 35,
            imageAsset: "template_pastel_wave"
        )
    ]

    static func categoryInfo(for categoryKey: String) -> TemplateCategoryInfo {
        switch categoryKey {
        case "category.all":
            return TemplateCategoryInfo(
                titleKey: "templates.header.all.title",
                subtitleKey: "templates.header.all.subtitle"
            )
        case "category.classic_portraits":
            return TemplateCategoryInfo(
                titleKey: "templates.header.classic.title",
                subtitleKey: "templates.header.classic.subtitle"
            )
        case "category.cyberpunk":
            return TemplateCategoryInfo(
                titleKey: "templates.header.cyberpunk.title",
                subtitleKey: "templates.header.cyberpunk.subtitle"
            )
        case "category.goddess":
            return TemplateCategoryInfo(
                titleKey: "templates.header.goddess.title",
                subtitleKey: "templates.header.goddess.subtitle"
            )
        case "category.anime":
            return TemplateCategoryInfo(
                titleKey: "templates.header.anime.title",
                subtitleKey: "templates.header.anime.subtitle"
            )
        default:
            return TemplateCategoryInfo(
                titleKey: "templates.header.title",
                subtitleKey: "templates.header.subtitle"
            )
        }
    }

    static func templates(for categoryKey: String) -> [TemplateItem] {
        if categoryKey == "category.all" {
            return templates
        }
        return templates.filter { $0.categoryKey == categoryKey }
    }
}
