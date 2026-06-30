import SwiftUI

struct GalleryDetailView: View {
    let item: GalleryItem
    @EnvironmentObject private var appState: AppState
    @State private var showShareSheet = false
    @State private var showDeleteConfirm = false
    @State private var downloadState: ResultShareView.DownloadState = .idle

    var body: some View {
        ZStack {
            MorphColors.backgroundDeep.ignoresSafeArea()

            VStack(spacing: 0) {
                MorphAppBar(title: item.localizedTemplateName, showBack: true, onBack: {
                    appState.selectedGalleryItem = nil
                })

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        GalleryImageView(item: item)
                            .aspectRatio(3/4, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .neonBorder(MorphColors.primary.opacity(0.25), cornerRadius: 24)

                        if item.showsTransformationInputs {
                            TransformationInputComparisonView(
                                sourceImage: item.loadSourceUIImage(),
                                template: item.linkedTemplate
                            )
                        }

                        Text(item.createdAt, style: .date)
                            .font(MorphFont.labelMD())
                            .foregroundStyle(MorphColors.onSurfaceVariant)

                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            if let image = item.loadUIImage() {
                ShareSheet(items: [image, L10n.shareMessage])
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(L10n.share)
                }
                .font(MorphFont.headlineMD())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(MorphGradient.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button {
                saveImage()
            } label: {
                HStack(spacing: 8) {
                    switch downloadState {
                    case .idle:
                        Image(systemName: "arrow.down.circle")
                        Text(L10n.downloadHighRes)
                    case .saving:
                        ProgressView().tint(MorphColors.primary)
                        Text(L10n.saving)
                    case .saved:
                        Image(systemName: "checkmark.circle.fill")
                        Text(L10n.savedToGallery)
                    }
                }
                .font(MorphFont.labelMD())
                .foregroundStyle(MorphColors.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(MorphGradient.pinkPurple, lineWidth: 1.5))
            }
            .disabled(downloadState != .idle)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text(L10n.galleryDelete)
                }
                .font(MorphFont.labelMD())
                .foregroundStyle(.red.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
        }
        .confirmationDialog(L10n.galleryDeleteConfirm, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(L10n.galleryDelete, role: .destructive) {
                appState.deleteGalleryItem(item)
            }
            Button(L10n.cancel, role: .cancel) {}
        }
    }

    private func saveImage() {
        guard let image = item.loadUIImage() else { return }
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
