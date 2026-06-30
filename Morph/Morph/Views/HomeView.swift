import SwiftUI
import PhotosUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()
                CircuitLinesBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    MorphAppBar(title: L10n.appName)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            heroSection
                            if appState.hasSourcePhoto {
                                continueSection
                            }
                            if !appState.recentGalleryItems.isEmpty {
                                recentSection
                            }
                            uploadPrompt
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, appState.showPhotoGuide ? 280 : 120)
                    }
                }

                if appState.showPhotoGuide {
                    PhotoGuideSheet(isPresented: $appState.showPhotoGuide)
                        .transition(.move(edge: .bottom))
                }
            }
            .navigationDestination(item: $appState.selectedGalleryItem) { item in
                GalleryDetailView(item: item)
            }
        }
        .onAppear(perform: schedulePhotoGuideIfNeeded)
        .onChange(of: appState.showOnboarding) { _, showing in
            if !showing { schedulePhotoGuideIfNeeded() }
        }
    }

    private func schedulePhotoGuideIfNeeded() {
        guard !appState.showOnboarding, !appState.hasSourcePhoto else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5)) {
                appState.showPhotoGuide = true
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(MorphColors.secondary.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)

                Image(systemName: "sparkles")
                    .font(.system(size: 52))
                    .foregroundStyle(MorphColors.secondary)
                    .symbolEffect(.pulse, options: .repeating)
            }

            Text(L10n.homeHeroTitle)
                .font(MorphFont.headlineLGMobile())
                .foregroundStyle(MorphColors.onSurface)

            Text(L10n.homeHeroSubtitle)
                .font(MorphFont.bodyMD())
                .foregroundStyle(MorphColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var continueSection: some View {
        Button {
            appState.selectedTab = .templates
        } label: {
            HStack(spacing: 14) {
                MorphPhotoView(
                    assetName: appState.sourcePhotoAsset,
                    uiImage: appState.sourceImage
                )
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.homeContinueTitle)
                        .font(MorphFont.headlineMD())
                        .foregroundStyle(MorphColors.onSurface)
                    Text(L10n.homeContinueSubtitle)
                        .font(MorphFont.labelSM())
                        .foregroundStyle(MorphColors.onSurfaceVariant)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(MorphColors.primary)
            }
            .padding(16)
            .glassPanel(cornerRadius: 16)
            .neonBorder(MorphColors.primary.opacity(0.3), cornerRadius: 16)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.homeRecentTitle)
                .font(MorphFont.headlineMD())
                .foregroundStyle(MorphColors.onSurface)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appState.recentGalleryItems) { item in
                        Button {
                            appState.selectedGalleryItem = item
                        } label: {
                            GalleryImageView(item: item)
                                .frame(width: 100, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(MorphColors.primary.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var uploadPrompt: some View {
        Button {
            withAnimation(.spring(response: 0.5)) {
                appState.showPhotoGuide = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                Text(L10n.homeUploadPhoto)
                    .font(MorphFont.labelMD())
            }
            .foregroundStyle(MorphColors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MorphGradient.pinkPurple, lineWidth: 1.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct PhotoGuideSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var appState: AppState
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCamera = false

    private var tips: [(icon: String, color: Color, title: String, subtitle: String)] {
        [
            ("face.smiling", MorphColors.primary, L10n.tipFrontFacingTitle, L10n.tipFrontFacingSubtitle),
            ("lightbulb.fill", MorphColors.tertiary, L10n.tipLightingTitle, L10n.tipLightingSubtitle),
            ("camera.fill.badge.ellipsis", MorphColors.secondary, L10n.tipNoCoveringTitle, L10n.tipNoCoveringSubtitle)
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                Capsule()
                    .fill(MorphColors.pullIndicator)
                    .frame(width: 48, height: 6)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Text(L10n.guideBestResults)
                                .font(MorphFont.headlineMD())
                                .foregroundStyle(MorphColors.onSurface)
                            Spacer()
                            CategoryChip(title: L10n.guideProTips, isActive: true, color: MorphColors.tertiary)
                        }

                        referenceCard

                        ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(tip.color.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                        .overlay(Circle().stroke(tip.color.opacity(0.2), lineWidth: 1))
                                    Image(systemName: tip.icon)
                                        .foregroundStyle(tip.color)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tip.title)
                                        .font(MorphFont.labelMD())
                                        .foregroundStyle(MorphColors.onSurface)
                                    Text(tip.subtitle)
                                        .font(MorphFont.labelSM())
                                        .foregroundStyle(MorphColors.onSurfaceVariant)
                                }
                            }
                            .padding(16)
                            .glassPanel(cornerRadius: 12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }

                actionBar
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.65)
            .background(.ultraThinMaterial)
            .background(MorphColors.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(MorphColors.glassBorder, lineWidth: 1)
            )
        }
        .background(MorphColors.scrim.ignoresSafeArea().onTapGesture {
            withAnimation { isPresented = false }
        })
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                finishPhotoSelection(image)
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        finishPhotoSelection(image)
                        photoPickerItem = nil
                    }
                }
            }
        }
    }

    private func finishPhotoSelection(_ image: UIImage) {
        appState.selectPhoto(image)
        withAnimation { isPresented = false }
        appState.selectedTab = .templates
    }

    private var referenceCard: some View {
        ZStack(alignment: .bottomLeading) {
            MorphImageView(assetName: SampleImages.reference)
                .aspectRatio(16/9, contentMode: .fill)
                .clipped()

            HStack {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(MorphColors.success)
                    .padding(16)
            }

            Text(L10n.guideGoodReference)
                .font(MorphFont.labelMD())
                .foregroundStyle(MorphColors.onImage)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [.clear, MorphColors.imageGradientEnd], startPoint: .top, endPoint: .bottom)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(MorphColors.onImage.opacity(0.1), lineWidth: 1))
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                    Text(L10n.guideSelectGallery)
                        .font(MorphFont.labelMD())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(MorphGradient.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: MorphColors.primaryContainer.opacity(0.4), radius: 15)
            }

            Button {
                showCamera = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(MorphColors.primary)
                    .frame(width: 56, height: 56)
                    .glassPanel(cornerRadius: 16)
                    .neonBorder(MorphColors.primary.opacity(0.4), cornerRadius: 16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .background(MorphColors.surfaceContainer.opacity(0.8))
    }
}
