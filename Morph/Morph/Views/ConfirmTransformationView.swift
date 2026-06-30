import PhotosUI
import SwiftUI

struct ConfirmTransformationView: View {
    let template: TemplateItem
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToResult = false
    @State private var showSourceOptions = false
    @State private var showTemplatePicker = false
    @State private var showCamera = false
    @State private var photoPickerItem: PhotosPickerItem?

    private var activeTemplate: TemplateItem {
        appState.selectedTemplate ?? template
    }

    var body: some View {
        ZStack {
            MorphColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                MorphAppBar(title: L10n.appName, showBack: true, onBack: {
                    appState.selectedTemplate = nil
                    dismiss()
                })

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        comparisonSection
                        settingsSection
                        infoBanner
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 110)
                }
            }

            VStack {
                Spacer()
                bottomActionBar
            }
        }
        .navigationBarHidden(true)
        .onChange(of: appState.showResult) { _, show in
            if show { navigateToResult = true }
        }
        .navigationDestination(isPresented: $navigateToResult) {
            ResultShareView()
        }
        .sheet(isPresented: $showSourceOptions) {
            sourcePhotoPickerSheet
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet(currentTemplateID: activeTemplate.id)
                .environmentObject(appState)
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        appState.selectPhoto(image)
                        photoPickerItem = nil
                        showSourceOptions = false
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                appState.selectPhoto(image)
            }
            .ignoresSafeArea()
        }
        .alert(L10n.insufficientCoinsTitle, isPresented: $appState.showInsufficientCoins) {
            Button(L10n.getCoins) {
                appState.showCoinStore = true
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.insufficientCoinsMessage)
        }
        .sheet(isPresented: $appState.showCoinStore) {
            CoinStoreSheet()
                .environmentObject(appState)
        }
        .alert(L10n.processingErrorTitle, isPresented: .init(
            get: { appState.processingError != nil },
            set: { if !$0 { appState.processingError = nil } }
        )) {
            Button(L10n.done) { appState.processingError = nil }
        } message: {
            Text(appState.processingError ?? "")
        }
    }

    private var comparisonSection: some View {
        HStack(alignment: .center, spacing: 8) {
            comparisonCard(
                label: L10n.sourcePhoto,
                labelColor: MorphColors.primary,
                borderColor: MorphColors.primary,
                action: { showSourceOptions = true },
                showsChangeBadge: appState.hasSourcePhoto
            ) {
                if appState.hasSourcePhoto {
                    MorphPhotoView(
                        assetName: appState.sourcePhotoAsset,
                        uiImage: appState.sourceImage
                    )
                } else {
                    sourcePhotoPlaceholder
                }
            }

            swapIndicator

            comparisonCard(
                label: L10n.selectedTemplate,
                labelColor: MorphColors.secondary,
                borderColor: MorphColors.secondary,
                action: { showTemplatePicker = true },
                showsChangeBadge: true
            ) {
                MorphImageView(assetName: activeTemplate.imageAsset, alignment: .trailing)
            }
        }
    }

    private var sourcePhotoPlaceholder: some View {
        ZStack {
            MorphColors.surfaceContainer
            VStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 28))
                    .foregroundStyle(MorphColors.primary)
                Text(L10n.selectSourcePhoto)
                    .font(MorphFont.labelMD())
                    .foregroundStyle(MorphColors.onSurfaceVariant)
            }
            .padding(.horizontal, 8)
        }
    }

    private var swapIndicator: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(MorphColors.primary.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(MorphColors.primary.opacity(0.35), lineWidth: 1))
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MorphColors.primary)
                    .symbolEffect(.pulse, options: .repeating)
            }

            Capsule()
                .fill(MorphColors.primary.opacity(0.3))
                .frame(width: 2, height: 20)
        }
        .frame(width: 44)
    }

    private func comparisonCard<Content: View>(
        label: String,
        labelColor: Color,
        borderColor: Color,
        action: @escaping () -> Void,
        showsChangeBadge: Bool = true,
        @ViewBuilder image: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    image()
                        .allowsHitTesting(false)
                }
                .clipShape(Rectangle())
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, MorphColors.background.opacity(0.9)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 56)
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topTrailing) {
                    if showsChangeBadge {
                        changeBadge
                            .allowsHitTesting(false)
                    }
                }

            Text(label)
                .font(MorphFont.labelSM())
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(MorphColors.surfaceContainer.opacity(0.95))
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: borderColor.opacity(0.2), radius: 8)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(perform: action)
    }

    private var sourcePhotoPickerSheet: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(MorphColors.pullIndicator)
                .frame(width: 48, height: 6)
                .padding(.top, 12)

            Text(L10n.changeSourcePhoto)
                .font(MorphFont.headlineMD())
                .foregroundStyle(MorphColors.onSurface)

            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle")
                    Text(L10n.guideSelectGallery)
                        .font(MorphFont.labelMD())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(MorphGradient.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button {
                showSourceOptions = false
                showCamera = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                    Text(L10n.takePhoto)
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

            Button(L10n.cancel) {
                showSourceOptions = false
            }
            .font(MorphFont.labelMD())
            .foregroundStyle(MorphColors.onSurfaceVariant)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(MorphColors.surfaceContainer)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.hidden)
    }

    private var changeBadge: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(MorphColors.onImage)
            .padding(7)
            .background(MorphColors.imageBadgeFill)
            .clipShape(Circle())
            .padding(8)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(MorphColors.secondary)
                Text(L10n.processingSettings)
                    .font(MorphFont.headlineMD())
                    .foregroundStyle(MorphColors.onSurface)
            }

            VStack(spacing: 20) {
                MorphToggleRow(
                    icon: "sparkle",
                    iconColor: MorphColors.tertiary,
                    title: L10n.hdQuality,
                    subtitle: L10n.hdQualitySubtitle,
                    isOn: $appState.hdQuality
                )

                Rectangle()
                    .fill(MorphGradient.cyberLine)
                    .frame(height: 1)
                    .opacity(0.2)

                MorphToggleRow(
                    icon: "face.smiling",
                    iconColor: MorphColors.secondary,
                    title: L10n.faceEnhancement,
                    subtitle: L10n.faceEnhancementSubtitle,
                    isOn: $appState.faceEnhancement
                )
            }
            .padding(20)
            .glassPanel(cornerRadius: 16)
        }
    }

    private var infoBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(MorphColors.primary)
                .padding(.top, 1)
            Text(L10n.confirmInfo)
                .font(MorphFont.labelSM())
                .foregroundStyle(MorphColors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MorphColors.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MorphColors.primary.opacity(0.1), lineWidth: 1))
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(MorphColors.separator)
                .frame(height: 1)

            GradientButton(
                title: L10n.startTransformation,
                icon: "wand.and.stars",
                subtitle: L10n.coins(activeTemplate.coinCost),
                isEnabled: appState.hasSourcePhoto
            ) {
                guard appState.hasSourcePhoto else {
                    showSourceOptions = true
                    return
                }
                appState.startTransformation()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
            .background(.ultraThinMaterial)
            .background(MorphColors.background.opacity(0.92))
        }
    }
}
