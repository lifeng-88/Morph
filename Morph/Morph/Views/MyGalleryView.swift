import SwiftUI

struct MyGalleryView: View {
    @EnvironmentObject private var appState: AppState

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    MorphAppBar(title: L10n.tabMy)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            AppSettingsSection()
                            PrivacySettingsSection()
                            AppearanceSettingsSection()
                            LanguageSettingsSection()
                            favoritesSection
                            gallerySection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationDestination(item: $appState.selectedGalleryItem) { item in
                GalleryDetailView(item: item)
            }
            .sheet(isPresented: $appState.showCoinStore) {
                CoinStoreSheet()
                    .environmentObject(appState)
            }
        }
    }

    @ViewBuilder
    private var favoritesSection: some View {
        let favorites = appState.templates.filter { appState.isFavorite($0) }
        if !favorites.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.favoriteTemplates)
                    .font(MorphFont.headlineMD())
                    .foregroundStyle(MorphColors.onSurface)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(favorites) { template in
                            Button {
                                appState.selectedTemplate = template
                                appState.selectedTab = .templates
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    MorphImageView(assetName: template.imageAsset, alignment: .trailing)
                                        .frame(width: 100, height: 130)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    Text(template.localizedName)
                                        .font(MorphFont.labelSM())
                                        .foregroundStyle(MorphColors.onSurface)
                                        .lineLimit(1)
                                        .frame(width: 100, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var gallerySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.mySectionGallery)
                .font(MorphFont.headlineMD())
                .foregroundStyle(MorphColors.onSurface)

            if appState.gallery.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(appState.gallery) { item in
                        Button {
                            appState.selectedGalleryItem = item
                        } label: {
                            galleryCard(item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                appState.deleteGalleryItem(item)
                            } label: {
                                Label(L10n.galleryDelete, systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(MorphColors.secondary.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(MorphColors.onSurfaceVariant.opacity(0.5))
            }

            VStack(spacing: 8) {
                Text(L10n.galleryEmptyTitle)
                    .font(MorphFont.headlineMD())
                    .foregroundStyle(MorphColors.onSurface)
                Text(L10n.galleryEmptySubtitle)
                    .font(MorphFont.bodyMD())
                    .foregroundStyle(MorphColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }

            Button {
                appState.selectedTab = .templates
            } label: {
                Text(L10n.browseTemplates)
                    .font(MorphFont.labelMD())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(MorphGradient.primary)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func galleryCard(_ item: GalleryItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            GalleryImageView(item: item)
                .aspectRatio(3/4, contentMode: .fit)
                .clipped()

            LinearGradient(
                colors: [.clear, MorphColors.background.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.localizedTemplateName)
                    .font(MorphFont.labelMD())
                    .foregroundStyle(MorphColors.onSurface)
                Text(item.createdAt, style: .relative)
                    .font(MorphFont.labelSM())
                    .foregroundStyle(MorphColors.onSurfaceVariant)
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .glassPanel(cornerRadius: 16)
        .neonBorder(MorphColors.primary.opacity(0.2), cornerRadius: 16)
    }
}
