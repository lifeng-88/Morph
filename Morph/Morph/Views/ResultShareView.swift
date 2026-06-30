import SwiftUI

struct ResultShareView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var downloadState: DownloadState = .idle
    @State private var showShareSheet = false

    enum DownloadState {
        case idle, saving, saved
    }

    var body: some View {
        ZStack {
            MorphColors.backgroundDeep.ignoresSafeArea()
            ParticleBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                MorphAppBar(title: L10n.appName, showBack: true, onBack: returnToTemplates)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        resultPortrait
                        shareSection
                        downloadButton
                        tryAnotherButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            if let image = appState.resultUIImage() {
                ShareSheet(items: [image, L10n.shareMessage])
            }
        }
    }

    private var resultPortrait: some View {
        ZStack(alignment: .bottomTrailing) {
            MorphPhotoView(
                assetName: appState.resultPhotoAsset ?? SampleImages.result,
                uiImage: appState.resultImage
            )
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(MorphColors.glassBorder, lineWidth: 1)
                )
                .shadow(color: MorphColors.elevatedShadow, radius: 20, y: 8)

            LinearGradient(
                colors: [.clear, MorphColors.background.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .allowsHitTesting(false)

            HStack(spacing: 6) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(MorphColors.secondary)
                Text(L10n.createdWithMorph)
                    .font(MorphFont.labelSM())
                    .foregroundStyle(MorphColors.onSurface.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassPanel(cornerRadius: 20)
            .padding(24)
        }
        .padding(.top, 8)
    }

    private var shareSection: some View {
        VStack(spacing: 16) {
            Text(L10n.shareMetamorphosis)
                .font(MorphFont.labelMD())
                .tracking(2)
                .foregroundStyle(MorphColors.onSurfaceVariant)

            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22))
                    Text(L10n.share)
                        .font(MorphFont.headlineMD())
                }
                .foregroundStyle(MorphColors.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .glassPanel(cornerRadius: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(MorphColors.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    @ViewBuilder
    private var downloadButton: some View {
        Button {
            saveResult()
        } label: {
            HStack(spacing: 12) {
                switch downloadState {
                case .idle:
                    Image(systemName: "arrow.down.circle")
                    Text(L10n.downloadHighRes)
                case .saving:
                    ProgressView().tint(.white)
                    Text(L10n.saving)
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                    Text(L10n.savedToGallery)
                }
            }
            .font(MorphFont.headlineMD())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                downloadState == .saved
                    ? LinearGradient(colors: [Color(hex: "4CAF50"), Color(hex: "2E7D32")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : MorphGradient.primary
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: (downloadState == .saved ? Color.green : MorphColors.primaryContainer).opacity(0.4), radius: 20)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(downloadState != .idle)
    }

    private var tryAnotherButton: some View {
        Button(action: returnToTemplates) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                Text(L10n.tryAnotherTemplate)
                    .font(MorphFont.labelMD())
            }
            .foregroundStyle(MorphColors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
    }

    private func returnToTemplates() {
        appState.returnToTemplatesFromResult()
        dismiss()
    }

    private func saveResult() {
        guard let image = appState.resultUIImage() else { return }
        downloadState = .saving
        Task {
            do {
                try await PhotoLibraryService.save(image)
                await MainActor.run {
                    withAnimation { downloadState = .saved }
                }
            } catch {
                await MainActor.run { downloadState = .idle }
            }
        }
    }
}
