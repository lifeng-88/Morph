import SwiftUI

private enum TemplatePagination {
    static let gridInitial = 4
    static let gridPageSize = 4
    static let pickerInitial = 8
    static let pickerPageSize = 6
    static let loadDelayNs: UInt64 = 900_000_000
}

struct TemplatesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedCategory = 0
    @State private var searchText = ""
    @State private var showFavoritesOnly = false
    @State private var visibleGridCount = TemplatePagination.gridInitial
    @State private var isLoadingMore = false

    private let categoryColors: [Color] = [
        MorphColors.tertiary,
        MorphColors.primary,
        MorphColors.secondary,
        MorphColors.tertiary
    ]

    private var categories: [String] {
        appState.categoryKeys.map { L10n.localized($0) }
    }

    private var activeCategoryKey: String {
        appState.categoryKeys[selectedCategory]
    }

    private var filteredTemplates: [TemplateItem] {
        var items = appState.templates(for: activeCategoryKey)
        if showFavoritesOnly {
            items = items.filter { appState.isFavorite($0) }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter { $0.localizedName.localizedCaseInsensitiveContains(query) }
        }
        return items
    }

    private var featuredTemplate: TemplateItem? {
        filteredTemplates.first(where: \.isLarge) ?? filteredTemplates.first
    }

    private var gridTemplates: [TemplateItem] {
        guard let featured = featuredTemplate else { return filteredTemplates }
        return filteredTemplates.filter { $0.id != featured.id }
    }

    private var paginatedGridTemplates: [TemplateItem] {
        Array(gridTemplates.prefix(visibleGridCount))
    }

    private var canLoadMoreGrid: Bool {
        visibleGridCount < gridTemplates.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()
                circuitBackground

                VStack(spacing: 0) {
                    MorphAppBar(title: L10n.templatesTitle)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            headerSection
                            searchBar
                            categoryChips
                            if filteredTemplates.isEmpty {
                                emptyCategoryState
                            } else {
                                featuredSection
                                templateGrid
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationDestination(item: $appState.selectedTemplate) { template in
                ConfirmTransformationView(template: template)
            }
            .sheet(isPresented: $appState.showCoinStore) {
                CoinStoreSheet()
                    .environmentObject(appState)
            }
        }
        .onChange(of: selectedCategory) { _, _ in resetGridPagination() }
        .onChange(of: searchText) { _, _ in resetGridPagination() }
        .onChange(of: showFavoritesOnly) { _, _ in resetGridPagination() }
    }

    private func resetGridPagination() {
        visibleGridCount = TemplatePagination.gridInitial
        isLoadingMore = false
    }

    private func loadMoreGridIfNeeded() {
        guard canLoadMoreGrid, !isLoadingMore else { return }
        isLoadingMore = true
        Task {
            try? await Task.sleep(nanoseconds: TemplatePagination.loadDelayNs)
            await MainActor.run {
                visibleGridCount = min(
                    visibleGridCount + TemplatePagination.gridPageSize,
                    gridTemplates.count
                )
                isLoadingMore = false
            }
        }
    }

    private var circuitBackground: some View {
        ZStack {
            RadialGradient(
                colors: [MorphColors.secondary.opacity(0.05), .clear],
                center: .init(x: 0.2, y: 0.3),
                startRadius: 0,
                endRadius: 300
            )
            RadialGradient(
                colors: [MorphColors.primary.opacity(0.05), .clear],
                center: .init(x: 0.8, y: 0.7),
                startRadius: 0,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        let info = TemplateCatalog.categoryInfo(for: activeCategoryKey)
        return VStack(alignment: .leading, spacing: 6) {
            Text(L10n.localized(info.titleKey))
                .font(MorphFont.headlineLGMobile())
                .foregroundStyle(MorphColors.onSurface)
            Text(L10n.localized(info.subtitleKey))
                .font(MorphFont.bodyMD())
                .foregroundStyle(MorphColors.onSurfaceVariant)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(MorphColors.onSurfaceVariant)
                TextField(L10n.searchTemplates, text: $searchText)
                    .font(MorphFont.bodyMD())
                    .foregroundStyle(MorphColors.onSurface)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassPanel(cornerRadius: 14)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFavoritesOnly.toggle()
                }
            } label: {
                Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundStyle(showFavoritesOnly ? MorphColors.primary : MorphColors.onSurfaceVariant)
                    .frame(width: 44, height: 44)
                    .glassPanel(cornerRadius: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(showFavoritesOnly ? MorphColors.primary.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(categories.enumerated()), id: \.offset) { index, title in
                    CategoryChip(
                        title: title,
                        isActive: selectedCategory == index,
                        color: categoryColors[index]
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = index
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.horizontal, -20)
        .padding(.leading, 20)
    }

    private var emptyCategoryState: some View {
        VStack(spacing: 12) {
            Image(systemName: showFavoritesOnly ? "heart.slash" : "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(MorphColors.onSurfaceVariant.opacity(0.5))
            Text(showFavoritesOnly ? L10n.noFavorites : L10n.noTemplatesInCategory)
                .font(MorphFont.bodyMD())
                .foregroundStyle(MorphColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    @ViewBuilder
    private var featuredSection: some View {
        if let featured = featuredTemplate, featured.isLarge {
            TemplateCard(template: featured, style: .featured)
        }
    }

    @ViewBuilder
    private var templateGrid: some View {
        if !gridTemplates.isEmpty {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(paginatedGridTemplates) { template in
                    TemplateCard(template: template, style: .compact)
                        .onAppear {
                            if template.id == paginatedGridTemplates.last?.id {
                                loadMoreGridIfNeeded()
                            }
                        }
                }
            }

            TemplateLoadMoreFooter(
                canLoadMore: canLoadMoreGrid,
                isLoading: isLoadingMore,
                showEndHint: !gridTemplates.isEmpty && !canLoadMoreGrid && !isLoadingMore,
                onLoadMore: loadMoreGridIfNeeded
            )
        } else if let featured = featuredTemplate, !featured.isLarge {
            TemplateCard(template: featured, style: .compact)
        }
    }
}

struct TemplateCard: View {
    enum Style {
        case featured, compact

        var aspectRatio: CGFloat { self == .featured ? 4 / 5 : 3 / 4 }
        var cornerRadius: CGFloat { self == .featured ? 20 : 16 }
        var contentPadding: CGFloat { self == .featured ? 20 : 14 }
        var titleFont: Font {
            self == .featured ? MorphFont.headlineMD() : MorphFont.labelMD()
        }
    }

    let template: TemplateItem
    var style: Style = .compact
    @EnvironmentObject private var appState: AppState

    private var isFavorite: Bool {
        appState.isFavorite(template)
    }

    var body: some View {
        VStack(spacing: 0) {
            imageArea
            infoBar
        }
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .stroke(MorphColors.primary.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: MorphColors.primary.opacity(0.12), radius: style == .featured ? 16 : 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: style.cornerRadius))
        .onTapGesture {
            appState.selectedTemplate = template
        }
    }

    private var imageArea: some View {
        Color.clear
            .aspectRatio(style.aspectRatio, contentMode: .fit)
            .overlay {
                MorphImageView(assetName: template.imageAsset, alignment: .trailing)
            }
            .clipped()
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        appState.toggleFavorite(template)
                    }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: style == .featured ? 16 : 14))
                        .foregroundStyle(isFavorite ? MorphColors.primary : MorphColors.onImage.opacity(0.85))
                        .padding(8)
                        .background(MorphColors.imageBadgeFill)
                        .clipShape(Circle())
                }
                .padding(10)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, MorphColors.background.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: style == .featured ? 120 : 80)
            }
    }

    private var infoBar: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.coins(template.coinCost))
                    .font(MorphFont.labelSM())
                    .foregroundStyle(MorphColors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(MorphColors.primary.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MorphColors.primary.opacity(0.25), lineWidth: 1))

                Text(template.localizedName)
                    .font(style.titleFont)
                    .foregroundStyle(MorphColors.onSurface)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if style == .featured {
                Button {
                    appState.selectedTemplate = template
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MorphColors.onPrimary)
                        .frame(width: 44, height: 44)
                        .background(MorphGradient.primary)
                        .clipShape(Circle())
                        .shadow(color: MorphColors.primary.opacity(0.45), radius: 10)
                }
            }
        }
        .padding(.horizontal, style.contentPadding)
        .padding(.vertical, 12)
        .background(MorphColors.surfaceContainer.opacity(0.95))
    }
}

struct TemplatePickerSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let currentTemplateID: String
    @State private var searchText = ""
    @State private var visibleCount = TemplatePagination.pickerInitial
    @State private var isLoadingMore = false

    private var filteredTemplates: [TemplateItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.templates }
        return appState.templates.filter {
            $0.localizedName.localizedCaseInsensitiveContains(query)
                || $0.localizedCategory.localizedCaseInsensitiveContains(query)
        }
    }

    private var paginatedTemplates: [TemplateItem] {
        Array(filteredTemplates.prefix(visibleCount))
    }

    private var canLoadMore: Bool {
        visibleCount < filteredTemplates.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                searchBar

                if filteredTemplates.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(paginatedTemplates) { item in
                                TemplatePickerRow(
                                    template: item,
                                    isSelected: item.id == currentTemplateID
                                ) {
                                    appState.selectedTemplate = item
                                    dismiss()
                                }
                                .onAppear {
                                    if item.id == paginatedTemplates.last?.id {
                                        loadMoreIfNeeded()
                                    }
                                }
                            }

                            TemplateLoadMoreFooter(
                                canLoadMore: canLoadMore,
                                isLoading: isLoadingMore,
                                showEndHint: !filteredTemplates.isEmpty && !canLoadMore && !isLoadingMore,
                                onLoadMore: loadMoreIfNeeded
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .padding(.top, 8)
            .background(MorphColors.background.ignoresSafeArea())
            .navigationTitle(L10n.changeTemplate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: searchText) { _, _ in resetPagination() }
    }

    private func resetPagination() {
        visibleCount = TemplatePagination.pickerInitial
        isLoadingMore = false
    }

    private func loadMoreIfNeeded() {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        Task {
            try? await Task.sleep(nanoseconds: TemplatePagination.loadDelayNs)
            await MainActor.run {
                visibleCount = min(
                    visibleCount + TemplatePagination.pickerPageSize,
                    filteredTemplates.count
                )
                isLoadingMore = false
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(MorphColors.onSurfaceVariant)
            TextField(L10n.searchTemplates, text: $searchText)
                .font(MorphFont.bodyMD())
                .foregroundStyle(MorphColors.onSurface)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MorphColors.onSurfaceVariant.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 14)
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(MorphColors.onSurfaceVariant.opacity(0.5))
            Text(L10n.noTemplatesInCategory)
                .font(MorphFont.bodyMD())
                .foregroundStyle(MorphColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }
}

struct TemplatePickerRow: View {
    let template: TemplateItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                MorphImageView(assetName: template.imageAsset, alignment: .trailing)
                    .frame(width: 56, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? MorphColors.secondary : MorphColors.primary.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(template.localizedName)
                        .font(MorphFont.labelMD())
                        .foregroundStyle(MorphColors.onSurface)
                        .lineLimit(1)

                    Text(template.localizedCategory)
                        .font(MorphFont.labelSM())
                        .foregroundStyle(MorphColors.onSurfaceVariant)
                        .lineLimit(1)

                    Text(L10n.coins(template.coinCost))
                        .font(MorphFont.labelSM())
                        .foregroundStyle(MorphColors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(MorphColors.primary.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(MorphColors.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MorphColors.onSurfaceVariant.opacity(0.5))
                }
            }
            .padding(12)
            .background(MorphColors.surfaceContainer.opacity(isSelected ? 0.95 : 0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? MorphColors.secondary.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct TemplateLoadMoreFooter: View {
    let canLoadMore: Bool
    let isLoading: Bool
    let showEndHint: Bool
    let onLoadMore: () -> Void

    var body: some View {
        Group {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(MorphColors.primary)
                    Text(L10n.loadingMoreTemplates)
                        .font(MorphFont.labelMD())
                        .foregroundStyle(MorphColors.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else if canLoadMore {
                Button(action: onLoadMore) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle")
                        Text(L10n.loadMoreTemplates)
                            .font(MorphFont.labelMD())
                    }
                    .foregroundStyle(MorphColors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(MorphColors.primary.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.vertical, 8)
            } else if showEndHint {
                Text(L10n.noMoreTemplates)
                    .font(MorphFont.labelSM())
                    .foregroundStyle(MorphColors.onSurfaceVariant.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }
}
