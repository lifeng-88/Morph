import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var page = 0
    @State private var showConsentSheet = false

    private var pages: [(icon: String, color: Color, title: String, subtitle: String)] {
        [
            ("sparkles", MorphColors.primary, L10n.onboardingPage1Title, L10n.onboardingPage1Subtitle),
            ("photo.on.rectangle.angled", MorphColors.secondary, L10n.onboardingPage2Title, L10n.onboardingPage2Subtitle),
            ("wand.and.stars", MorphColors.tertiary, L10n.onboardingPage3Title, L10n.onboardingPage3Subtitle),
            ("shield.lefthalf.filled", MorphColors.primary, L10n.onboardingPage4Title, L10n.onboardingPage4Subtitle)
        ]
    }

    var body: some View {
        ZStack {
            MorphColors.backgroundDeep.ignoresSafeArea()
            ParticleBackground().ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                let current = pages[page]
                ZStack {
                    Circle()
                        .fill(current.color.opacity(0.12))
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                    Image(systemName: current.icon)
                        .font(.system(size: 56))
                        .foregroundStyle(current.color)
                        .symbolEffect(.pulse, options: .repeating)
                }

                VStack(spacing: 12) {
                    Text(current.title)
                        .font(MorphFont.headlineLGMobile())
                        .foregroundStyle(MorphColors.onSurface)
                        .multilineTextAlignment(.center)
                    Text(current.subtitle)
                        .font(MorphFont.bodyMD())
                        .foregroundStyle(MorphColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? MorphColors.primary : MorphColors.onSurfaceVariant.opacity(0.3))
                            .frame(width: index == page ? 24 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: page)
                    }
                }

                Spacer()

                Button {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        showConsentSheet = true
                    }
                } label: {
                    Text(page < pages.count - 1 ? L10n.onboardingNext : L10n.onboardingStart)
                        .font(MorphFont.headlineMD())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(MorphGradient.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)

                if page < pages.count - 1 {
                    Button(L10n.onboardingSkip) {
                        appState.completeOnboarding()
                    }
                    .font(MorphFont.labelMD())
                    .foregroundStyle(MorphColors.onSurfaceVariant)
                }
            }
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showConsentSheet) {
            AIDataConsentSheet(
                onGrant: { appState.completeOnboarding() },
                onDecline: { showConsentSheet = false }
            )
            .interactiveDismissDisabled()
        }
    }
}
