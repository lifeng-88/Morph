import SwiftUI

struct ProcessingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var hasStarted = false

    var body: some View {
        ZStack {
            MorphColors.backgroundDeep.ignoresSafeArea()
            ParticleBackground().ignoresSafeArea()

            VStack(spacing: 48) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(MorphColors.tertiary.opacity(0.2), lineWidth: 2)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: appState.processingProgress)
                        .stroke(
                            LinearGradient(
                                colors: [MorphColors.tertiary, MorphColors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundStyle(MorphColors.primary)
                        .symbolEffect(.pulse, options: .repeating)
                }

                VStack(spacing: 12) {
                    Text(L10n.processingTitle)
                        .font(MorphFont.headlineMD())
                        .foregroundStyle(MorphColors.onSurface)

                    Text(processingSubtitle)
                        .font(MorphFont.bodyMD())
                        .foregroundStyle(MorphColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }

                progressBar

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await appState.performTransformation()
        }
    }

    private var processingSubtitle: String {
        MorphAPIConfig.isConfigured ? L10n.processingSubtitleRemote : L10n.processingSubtitle
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MorphColors.surfaceContainer)
                    .frame(height: 4)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [MorphColors.tertiary, MorphColors.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * appState.processingProgress, height: 4)
                    .shadow(color: MorphColors.tertiary.opacity(0.5), radius: 8)

                Image(systemName: "sparkle")
                    .font(.system(size: 14))
                    .foregroundStyle(MorphColors.tertiary)
                    .offset(x: geo.size.width * appState.processingProgress - 8)
                    .shadow(color: MorphColors.tertiary, radius: 6)
            }
        }
        .frame(height: 4)
    }
}
