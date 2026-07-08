import PhotosUI
import PencilKit
import SwiftUI

struct DrawingView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var canvasController = CanvasController()
    @State private var selectedColor: DrawingColor = .primary
    @State private var customInkColor: Color = MorphColors.primary
    @State private var usesCustomColor = false
    @State private var brushSize: CGFloat = 4
    @State private var selectedStyle: SmartDrawStyle = .sketch
    @State private var isEraser = false
    @State private var isBrushActive = false
    @State private var saveState: SaveState = .idle
    @State private var referenceImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isGenerating = false
    @State private var generateProgress: Double = 0
    @State private var smartDrawError: String?
    @State private var generatedInitialImage: UIImage?
    @State private var showFullscreenDrawing = false

    fileprivate enum SaveState {
        case idle, saving, saved
    }

    var body: some View {
        ZStack {
            MorphColors.background.ignoresSafeArea()
            CircuitLinesBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                MorphAppBar(title: L10n.tabDraw)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        smartDrawSection
                        canvasArea
                        toolBar
                        actionBar
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        referenceImage = image
                        photoPickerItem = nil
                        saveState = .idle
                        generatedInitialImage = nil
                    }
                }
            }
        }
        .alert(L10n.drawSmartTitle, isPresented: .init(
            get: { smartDrawError != nil },
            set: { if !$0 { smartDrawError = nil } }
        )) {
            Button(L10n.done) { smartDrawError = nil }
        } message: {
            Text(smartDrawError ?? "")
        }
        .alert(L10n.insufficientCoinsTitle, isPresented: $appState.showInsufficientCoins) {
            Button(L10n.getCoins) {
                appState.showCoinStore = true
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.insufficientCoinsDrawMessage)
        }
        .fullScreenCover(isPresented: $showFullscreenDrawing, onDismiss: {
            canvasController.finishLeavingFullscreen()
        }) {
            FullscreenDrawingView(
                isPresented: $showFullscreenDrawing,
                controller: canvasController,
                backgroundImage: canvasController.backgroundImage,
                selectedColor: $selectedColor,
                customInkColor: $customInkColor,
                usesCustomColor: $usesCustomColor,
                brushSize: $brushSize,
                isEraser: $isEraser,
                saveState: $saveState,
                isGenerating: isGenerating,
                generateProgress: generateProgress,
                onSave: saveDrawing,
                onClear: {
                    canvasController.clearAll()
                    saveState = .idle
                    generatedInitialImage = nil
                },
                canRestoreInitial: generatedInitialImage != nil,
                onRestoreInitial: restoreInitialImage
            )
        }
        .onChange(of: showFullscreenDrawing) { _, isShowing in
            if isShowing {
                canvasController.prepareForFullscreen()
            }
        }
    }

    private var smartDrawSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.drawSmartTitle)
                    .font(MorphFont.headlineMD())
                    .foregroundStyle(MorphColors.onSurface)
                Text(L10n.drawSmartSubtitle)
                    .font(MorphFont.labelSM())
                    .foregroundStyle(MorphColors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    referencePicker
                    ForEach(SmartDrawStyle.allCases) { style in
                        styleChip(style)
                    }
                }
                .padding(.vertical, 2)
            }

            Button {
                generateSmartDrawing()
            } label: {
                HStack(spacing: 10) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(L10n.drawSmartGenerate)
                        .font(MorphFont.labelMD())
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 14))
                        Text(L10n.coins(selectedStyle.coinCost))
                            .font(MorphFont.labelSM())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MorphColors.onPrimary.opacity(0.18))
                    .clipShape(Capsule())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    referenceImage == nil || isGenerating
                        ? AnyShapeStyle(MorphColors.surfaceVariant.opacity(0.5))
                        : AnyShapeStyle(MorphGradient.primary)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(referenceImage == nil || isGenerating)
        }
        .padding(16)
        .glassPanel(cornerRadius: 16)
    }

    private var referencePicker: some View {
        PhotosPicker(selection: $photoPickerItem, matching: .images) {
            VStack(spacing: 6) {
                Group {
                    if let referenceImage {
                        Image(uiImage: referenceImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 22))
                            .foregroundStyle(MorphColors.primary)
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MorphColors.primary.opacity(0.35), lineWidth: 1)
                )

                Text(L10n.drawSmartPick)
                    .font(MorphFont.labelSM())
                    .foregroundStyle(MorphColors.onSurfaceVariant)
            }
        }
        .buttonStyle(.plain)
    }

    private func styleChip(_ style: SmartDrawStyle) -> some View {
        let isActive = selectedStyle == style
        return Button {
            selectedStyle = style
        } label: {
            VStack(spacing: 6) {
                Image(systemName: style.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isActive ? MorphColors.secondary : MorphColors.onSurfaceVariant)
                    .frame(width: 72, height: 72)
                    .background(MorphColors.surfaceContainer.opacity(isActive ? 0.95 : 0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isActive ? MorphColors.secondary.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )

                VStack(spacing: 2) {
                    Text(style.localizedName)
                        .font(MorphFont.labelSM())
                        .foregroundStyle(isActive ? MorphColors.secondary : MorphColors.onSurfaceVariant)
                        .lineLimit(1)
                    Text(L10n.coins(style.coinCost))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isActive ? MorphColors.tertiary : MorphColors.onSurfaceVariant.opacity(0.7))
                }
                .frame(width: 72)
            }
        }
        .buttonStyle(.plain)
    }

    private var canvasAspectRatio: CGFloat {
        guard let image = canvasController.backgroundImage, image.size.height > 0 else {
            return 3 / 4
        }
        let ratio = image.size.width / image.size.height
        return min(max(ratio, 0.55), 1.8)
    }

    private var canvasArea: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(MorphColors.surfaceContainer)

            PencilCanvasView(
                controller: canvasController,
                backgroundImage: canvasController.backgroundImage,
                rebindToken: canvasController.rebindToken,
                isBindingEnabled: !showFullscreenDrawing,
                inkColor: activeInkColor,
                isEraser: isEraser,
                inkWidth: brushSize,
                isDrawingEnabled: isBrushActive
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .allowsHitTesting(isBrushActive)

            if canvasController.backgroundImage == nil && !isGenerating {
                Text(isBrushActive ? L10n.drawHint : L10n.drawSelectBrushHint)
                    .font(MorphFont.labelSM())
                    .foregroundStyle(MorphColors.onSurfaceVariant)
                    .padding(14)
                    .allowsHitTesting(false)
            }

            if isGenerating {
                ZStack {
                    MorphColors.overlay
                    VStack(spacing: 12) {
                        ProgressView(value: generateProgress)
                            .tint(MorphColors.primary)
                            .frame(width: 160)
                        Text(L10n.drawSmartProcessing)
                            .font(MorphFont.labelMD())
                            .foregroundStyle(MorphColors.onSurface)
                    }
                    .padding(24)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            Button {
                showFullscreenDrawing = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.drawFullscreen)
                        .font(MorphFont.labelSM())
                }
                .foregroundStyle(MorphColors.canvasChipForeground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .background(MorphColors.canvasChipFill)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(MorphColors.primary.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: MorphColors.elevatedShadow, radius: 6, y: 2)
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(12)
            .disabled(isGenerating)

            if generatedInitialImage != nil, !isGenerating {
                Button(action: restoreInitialImage) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text(L10n.drawRestoreInitial)
                            .font(MorphFont.labelSM())
                    }
                    .foregroundStyle(MorphColors.canvasChipForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial)
                    .background(MorphColors.canvasChipFill)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(MorphColors.primary.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: MorphColors.elevatedShadow, radius: 6, y: 2)
                }
                .buttonStyle(ScaleButtonStyle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(canvasAspectRatio, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(MorphColors.canvasStroke, lineWidth: 1)
        )
        .shadow(color: MorphColors.canvasShadow, radius: 12, y: 4)
    }

    private var toolBar: some View {
        DrawingToolPanel(
            selectedColor: $selectedColor,
            customInkColor: $customInkColor,
            usesCustomColor: $usesCustomColor,
            brushSize: $brushSize,
            isEraser: $isEraser,
            isBrushActive: $isBrushActive,
            canUndo: canvasController.canUndo,
            onUndo: { canvasController.undo() },
            layout: .standard
        )
    }

    private var activeInkColor: UIColor {
        usesCustomColor ? UIColor(customInkColor) : selectedColor.uiColor
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                canvasController.clearAll()
                saveState = .idle
                generatedInitialImage = nil
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text(L10n.drawClear)
                        .font(MorphFont.labelMD())
                }
                .foregroundStyle(MorphColors.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .glassPanel(cornerRadius: 14)
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                saveDrawing()
            } label: {
                HStack(spacing: 8) {
                    switch saveState {
                    case .idle:
                        Image(systemName: "square.and.arrow.down")
                        Text(L10n.drawSave)
                    case .saving:
                        ProgressView().tint(.white)
                        Text(L10n.saving)
                    case .saved:
                        Image(systemName: "checkmark.circle.fill")
                        Text(L10n.savedToGallery)
                    }
                }
                .font(MorphFont.labelMD())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background {
                    if saveState == .saved {
                        Color.green.opacity(0.85)
                    } else {
                        MorphGradient.primary
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(saveState == .saving || isGenerating)
        }
    }

    private func generateSmartDrawing() {
        guard let referenceImage else { return }
        appState.requestAIDataConsentThenPerform {
            performSmartDrawing(with: referenceImage)
        }
    }

    private func performSmartDrawing(with referenceImage: UIImage) {
        let style = selectedStyle
        let cost = style.coinCost
        guard appState.startSmartDraw(style: style) else { return }

        isGenerating = true
        generateProgress = 0
        saveState = .idle

        Task {
            do {
                let service = SmartDrawServiceFactory.make()
                let result = try await service.generate(
                    SmartDrawRequest(sourceImage: referenceImage, style: style)
                ) { value in
                    Task { @MainActor in
                        generateProgress = value
                    }
                }
                await MainActor.run {
                    generatedInitialImage = result
                    isGenerating = false
                    generateProgress = 1
                }
                await MainActor.run {
                    canvasController.clearStrokes()
                    canvasController.setBackground(result)
                }
            } catch {
                await MainActor.run {
                    appState.failSmartDraw(refund: cost)
                    isGenerating = false
                    generateProgress = 0
                    smartDrawError = error.localizedDescription
                }
            }
        }
    }

    private func restoreInitialImage() {
        guard let generatedInitialImage else { return }
        let image = generatedInitialImage
        Task { @MainActor in
            canvasController.clearStrokes()
            canvasController.setBackground(image)
            saveState = .idle
        }
    }

    private func saveDrawing() {
        guard let image = canvasController.snapshot() else { return }
        saveState = .saving
        Task {
            do {
                try await PhotoLibraryService.save(image)
                await MainActor.run {
                    appState.addDrawingToGallery(image)
                    withAnimation { saveState = .saved }
                }
            } catch {
                await MainActor.run { saveState = .idle }
            }
        }
    }
}

private struct FullscreenDrawingView: View {
    @Binding var isPresented: Bool
    @ObservedObject var controller: CanvasController
    var backgroundImage: UIImage?
    @Binding var selectedColor: DrawingColor
    @Binding var customInkColor: Color
    @Binding var usesCustomColor: Bool
    @Binding var brushSize: CGFloat
    @Binding var isEraser: Bool
    @Binding var saveState: DrawingView.SaveState
    var isGenerating: Bool
    var generateProgress: Double
    var onSave: () -> Void
    var onClear: () -> Void
    var canRestoreInitial: Bool = false
    var onRestoreInitial: (() -> Void)?

    @State private var showTools = false
    @State private var isDockCollapsed = false

    private var activeInkColor: UIColor {
        usesCustomColor ? UIColor(customInkColor) : selectedColor.uiColor
    }

    private var activeSwiftUIColor: Color {
        usesCustomColor ? customInkColor : selectedColor.swiftUIColor
    }

    var body: some View {
        GeometryReader { geo in
            let chromeInsets = fullscreenChromeInsets(safeArea: geo.safeAreaInsets)

            ZStack {
                MorphColors.backgroundDeep

                ZoomablePencilCanvasView(
                    controller: controller,
                    backgroundImage: backgroundImage,
                    rebindToken: controller.rebindToken,
                    contentInsets: chromeInsets,
                    inkColor: activeInkColor,
                    isEraser: isEraser,
                    inkWidth: brushSize
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if shouldShowCanvasHint {
                    VStack(spacing: 8) {
                        Text(L10n.drawHint)
                            .font(MorphFont.labelMD())
                            .foregroundStyle(MorphColors.onSurfaceVariant.opacity(0.45))
                        Text(L10n.drawFullscreenImmersive)
                            .font(MorphFont.labelSM())
                            .foregroundStyle(MorphColors.onSurfaceVariant.opacity(0.35))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
                    .padding(.top, chromeInsets.top)
                    .padding(.bottom, chromeInsets.bottom)
                    .allowsHitTesting(false)
                }

                if isGenerating {
                    MorphColors.overlayHeavy
                    VStack(spacing: 14) {
                        ProgressView(value: generateProgress)
                            .tint(MorphColors.primary)
                            .frame(width: 200)
                        Text(L10n.drawSmartProcessing)
                            .font(MorphFont.labelMD())
                            .foregroundStyle(MorphColors.onSurface)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .background(MorphColors.backgroundDeep)
        .overlay(alignment: .top) {
            floatingTopBar
        }
        .overlay(alignment: .bottom) {
            Group {
                if showTools {
                    toolsSheet
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if isDockCollapsed {
                    collapsedDockHandle
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    miniDock
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showTools)
        .animation(.easeInOut(duration: 0.22), value: isDockCollapsed)
    }

    private var shouldShowCanvasHint: Bool {
        backgroundImage == nil && !isGenerating && !showTools && !controller.canUndo
    }

    private func fullscreenChromeInsets(safeArea: EdgeInsets) -> UIEdgeInsets {
        let top = safeArea.top + 52
        let bottom: CGFloat = if showTools {
            safeArea.bottom + 300
        } else if isDockCollapsed {
            safeArea.bottom + 52
        } else {
            safeArea.bottom + 96
        }
        return UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
    }

    private func exitFullscreen() {
        controller.commitDrawing()
        controller.resetZoom(animated: false)
        controller.unbind()
        isPresented = false
    }

    private var floatingTopBar: some View {
        HStack(spacing: 10) {
            if showTools {
                Text(L10n.drawFullscreenTools)
                    .font(MorphFont.labelMD())
                    .foregroundStyle(MorphColors.onSurface.opacity(0.9))
            }

            Spacer()

            if canRestoreInitial, let onRestoreInitial {
                fullscreenToolbarButton(
                    icon: "arrow.counterclockwise",
                    label: L10n.drawRestoreInitial,
                    action: onRestoreInitial
                )
            }

            fullscreenToolbarButton(
                icon: "minus.magnifyingglass",
                label: L10n.drawZoomOut,
                action: { controller.zoomOut() },
                disabled: controller.isDisplayZoomAtMinimum
            )

            Text("\(controller.displayZoomPercent)%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(MorphColors.onSurface.opacity(0.8))
                .frame(minWidth: 38)

            fullscreenToolbarButton(
                icon: "plus.magnifyingglass",
                label: L10n.drawZoomIn,
                action: { controller.zoomIn() },
                disabled: controller.isDisplayZoomAtMaximum
            )

            if controller.isZoomedIn {
                fullscreenToolbarButton(
                    icon: "arrow.up.left.and.arrow.down.right",
                    label: L10n.drawZoomReset,
                    action: { controller.resetZoom() }
                )
            }

            Button {
                controller.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 17))
                    .foregroundStyle(controller.canUndo ? MorphColors.onSurface : MorphColors.onSurfaceVariant.opacity(0.35))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .background(MorphColors.floatingFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!controller.canUndo)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    private func fullscreenToolbarButton(
        icon: String,
        label: String,
        action: @escaping () -> Void,
        disabled: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(disabled ? MorphColors.onSurfaceVariant.opacity(0.35) : MorphColors.onSurface)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .background(MorphColors.floatingFill)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .disabled(disabled)
    }

    private var miniDock: some View {
        VStack(spacing: 6) {
            Button {
                collapseDock()
            } label: {
                Capsule()
                    .fill(MorphColors.onSurfaceVariant.opacity(0.35))
                    .frame(width: 32, height: 4)
            }
            .buttonStyle(.plain)

            HStack(spacing: 14) {
                Button(action: exitFullscreen) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MorphColors.onSurface.opacity(0.85))
                        .frame(width: 32, height: 32)
                        .background(MorphColors.surfaceContainer.opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.drawExitFullscreen)

                Button {
                    withAnimation { showTools = true }
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isEraser ? MorphColors.onSurfaceVariant.opacity(0.35) : activeSwiftUIColor)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke(MorphColors.chromeAccentStroke, lineWidth: 1)
                            )

                        Text(isEraser ? "—" : "\(Int(brushSize))pt")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MorphColors.onSurface.opacity(0.85))
                            .shadow(color: MorphColors.labelShadow, radius: 2, y: 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.drawFullscreenTools)

                Spacer()

                Button {
                    withAnimation { showTools = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paintbrush.pointed.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(L10n.drawFullscreenTools)
                            .font(MorphFont.labelSM())
                    }
                    .foregroundStyle(MorphColors.onSurface)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(MorphColors.surfaceContainer.opacity(0.85))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if canRestoreInitial, let onRestoreInitial {
                    Button(action: onRestoreInitial) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MorphColors.onSurface)
                            .frame(width: 40, height: 40)
                            .background(MorphColors.surfaceContainer.opacity(0.85))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.drawRestoreInitial)
                }

                Button(action: onSave) {
                    Group {
                        switch saveState {
                        case .idle:
                            Image(systemName: "square.and.arrow.down")
                        case .saving:
                            ProgressView().tint(.white)
                        case .saved:
                            Image(systemName: "checkmark")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background {
                        if saveState == .saved {
                            Color.green.opacity(0.9)
                        } else {
                            MorphGradient.primary
                        }
                    }
                    .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(saveState == .saving)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial)
            .background(MorphColors.floatingFill)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(MorphColors.chromeStroke, lineWidth: 1)
            )
            .shadow(color: MorphColors.elevatedShadow, radius: 12, y: 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .simultaneousGesture(dockDragGesture(allowsExpand: true))
    }

    private var collapsedDockHandle: some View {
        Button {
            withAnimation { isDockCollapsed = false }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(isEraser ? MorphColors.onSurfaceVariant.opacity(0.35) : activeSwiftUIColor)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .stroke(MorphColors.chromeAccentStroke, lineWidth: 1)
                    )

                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MorphColors.onSurface.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .background(MorphColors.floatingFill)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(MorphColors.chromeStroke, lineWidth: 1)
            )
            .shadow(color: MorphColors.elevatedShadow, radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 12)
        .simultaneousGesture(dockDragGesture(allowsExpand: true))
    }

    private func dockDragGesture(allowsExpand: Bool) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                if value.translation.height > 30 {
                    collapseDock()
                } else if allowsExpand && value.translation.height < -30 {
                    expandDock()
                }
            }
    }

    private func collapseDock() {
        withAnimation { isDockCollapsed = true }
    }

    private func expandDock() {
        withAnimation {
            isDockCollapsed = false
            showTools = true
        }
    }

    private var toolsSheet: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(MorphColors.onSurfaceVariant.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    DrawingToolPanel(
                        selectedColor: $selectedColor,
                        customInkColor: $customInkColor,
                        usesCustomColor: $usesCustomColor,
                        brushSize: $brushSize,
                        isEraser: $isEraser,
                        isBrushActive: .constant(true),
                        canUndo: controller.canUndo,
                        onUndo: { controller.undo() },
                        layout: .immersive
                    )

                    HStack(spacing: 10) {
                        if canRestoreInitial, let onRestoreInitial {
                            Button(action: onRestoreInitial) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text(L10n.drawRestoreInitial)
                                }
                                .font(MorphFont.labelSM())
                                .foregroundStyle(MorphColors.onSurface)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(MorphColors.surfaceContainer.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: onClear) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text(L10n.drawClear)
                            }
                            .font(MorphFont.labelSM())
                            .foregroundStyle(MorphColors.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(MorphColors.surfaceContainer.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation { showTools = false }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                Text(L10n.drawFullscreen)
                            }
                            .font(MorphFont.labelSM())
                            .foregroundStyle(MorphColors.onSurface)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(MorphColors.surfaceContainer.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button(action: onSave) {
                            HStack(spacing: 6) {
                                switch saveState {
                                case .idle:
                                    Image(systemName: "square.and.arrow.down")
                                    Text(L10n.drawSave)
                                case .saving:
                                    ProgressView().tint(.white)
                                case .saved:
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(L10n.savedToGallery)
                                }
                            }
                            .font(MorphFont.labelSM())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background {
                                if saveState == .saved {
                                    Color.green.opacity(0.85)
                                } else {
                                    MorphGradient.primary
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(saveState == .saving)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: 260)
        }
        .background(.ultraThinMaterial)
        .background(MorphColors.overlay)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MorphColors.primary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 40 {
                        withAnimation { showTools = false }
                    }
                }
        )
    }
}

private enum DrawingToolLayout {
    case standard
    case immersive
}

private struct DrawingToolPanel: View {
    @Binding var selectedColor: DrawingColor
    @Binding var customInkColor: Color
    @Binding var usesCustomColor: Bool
    @Binding var brushSize: CGFloat
    @Binding var isEraser: Bool
    @Binding var isBrushActive: Bool
    var canUndo: Bool
    var onUndo: () -> Void
    var layout: DrawingToolLayout = .standard

    private let brushPresets: [CGFloat] = [2, 6, 12, 20]

    private var isCompact: Bool { layout == .standard }
    private var isImmersive: Bool { layout == .immersive }

    private var activeInkColor: Color {
        usesCustomColor ? customInkColor : selectedColor.swiftUIColor
    }

    var body: some View {
        VStack(spacing: isImmersive ? 8 : (isCompact ? 10 : 12)) {
            colorRow
            if usesCustomColor {
                hexLabel
            }
            brushSizeRow
        }
        .padding(.horizontal, isCompact ? 4 : 0)
    }

    private var colorRow: some View {
        HStack(spacing: isImmersive ? 8 : (isCompact ? 10 : 12)) {
            ForEach(DrawingColor.allCases) { color in
                Button {
                    DispatchQueue.main.async {
                        isEraser = false
                        selectedColor = color
                        usesCustomColor = false
                        isBrushActive = true
                    }
                } label: {
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: swatchSize, height: swatchSize)
                        .overlay(
                            Circle()
                                .stroke(
                                    color == .white ? MorphColors.swatchBorder : Color.clear,
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    selectedColor == color && !isEraser && !usesCustomColor && isBrushActive
                                        ? MorphColors.onSurface : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: color.swiftUIColor.opacity(0.4),
                            radius: selectedColor == color && !usesCustomColor && isBrushActive ? 6 : 0
                        )
                }
                .buttonStyle(.plain)
            }

            customColorPicker

            Spacer(minLength: 0)

            if isCompact {
                cancelBrushButton
            }

            Button {
                DispatchQueue.main.async {
                    isEraser.toggle()
                    isBrushActive = true
                }
            } label: {
                Image(systemName: "eraser.fill")
                    .font(.system(size: isImmersive ? 16 : (isCompact ? 18 : 20)))
                    .foregroundStyle(isEraser && isBrushActive ? MorphColors.tertiary : MorphColors.onSurfaceVariant)
                    .frame(width: toolButtonSize, height: toolButtonSize)
                    .background(isEraser && isBrushActive ? MorphColors.tertiary.opacity(0.15) : MorphColors.surfaceContainer.opacity(0.6))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isEraser && isBrushActive ? MorphColors.tertiary.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            if isCompact {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18))
                        .foregroundStyle(canUndo ? MorphColors.onSurface : MorphColors.disabledControl)
                        .frame(width: 40, height: 40)
                        .glassPanel(cornerRadius: 20)
                }
                .buttonStyle(.plain)
                .disabled(!canUndo)
            }
        }
    }

    private var cancelBrushButton: some View {
        Button {
            DispatchQueue.main.async {
                isBrushActive = false
                isEraser = false
            }
        } label: {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 18))
                .foregroundStyle(!isBrushActive ? MorphColors.primary : MorphColors.onSurfaceVariant)
                .frame(width: toolButtonSize, height: toolButtonSize)
                .background(!isBrushActive ? MorphColors.primary.opacity(0.15) : MorphColors.surfaceContainer.opacity(0.6))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(!isBrushActive ? MorphColors.primary.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.drawCancelBrush)
    }

    private var swatchSize: CGFloat {
        switch layout {
        case .standard: return 32
        case .immersive: return 30
        }
    }

    private var toolButtonSize: CGFloat {
        switch layout {
        case .standard: return 40
        case .immersive: return 36
        }
    }

    private func activateCustomColor() {
        DispatchQueue.main.async {
            isEraser = false
            usesCustomColor = true
            isBrushActive = true
        }
    }

    private var customColorPicker: some View {
        ColorPicker(selection: $customInkColor, supportsOpacity: false) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center
                        )
                    )
                    .opacity(usesCustomColor && isBrushActive ? 1 : 0.85)

                Circle()
                    .fill(customInkColor)
                    .frame(width: swatchSize - 8, height: swatchSize - 8)
            }
            .frame(width: swatchSize, height: swatchSize)
            .overlay(
                Circle()
                    .stroke(
                        usesCustomColor && !isEraser && isBrushActive ? MorphColors.onSurface : MorphColors.onSurfaceVariant.opacity(0.35),
                        lineWidth: usesCustomColor && !isEraser && isBrushActive ? 2 : 1
                    )
            )
            .shadow(color: customInkColor.opacity(usesCustomColor && isBrushActive ? 0.45 : 0), radius: 6)
        }
        .labelsHidden()
        .frame(width: swatchSize, height: swatchSize)
        .contentShape(Circle())
        .simultaneousGesture(
            TapGesture().onEnded { activateCustomColor() }
        )
        .onChange(of: customInkColor) { _, _ in
            activateCustomColor()
        }
    }

    private var hexLabel: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(customInkColor)
                .frame(width: 12, height: 12)
            Text(L10n.drawColorHex(customInkColor.hexRGB()))
                .font(.system(size: isImmersive ? 10 : (isCompact ? 11 : 12), weight: .medium, design: .monospaced))
                .foregroundStyle(MorphColors.onSurfaceVariant)
            Spacer()
        }
    }

    private var brushSizeRow: some View {
        VStack(spacing: isImmersive ? 6 : 8) {
            HStack(spacing: 10) {
                Text(L10n.drawBrushSize)
                    .font(MorphFont.labelSM())
                    .foregroundStyle(MorphColors.onSurfaceVariant)

                Spacer()

                Circle()
                    .fill(isEraser ? MorphColors.onSurfaceVariant.opacity(0.3) : activeInkColor)
                    .frame(width: max(8, min(brushSize * 1.6, isImmersive ? 22 : 28)), height: max(8, min(brushSize * 1.6, isImmersive ? 22 : 28)))
                    .overlay(
                        Circle()
                            .stroke(MorphColors.onSurfaceVariant.opacity(0.25), lineWidth: 1)
                    )

                Text("\(Int(brushSize))pt")
                    .font(.system(size: isImmersive ? 10 : (isCompact ? 11 : 12), weight: .semibold, design: .monospaced))
                    .foregroundStyle(MorphColors.onSurface)
                    .frame(minWidth: 32, alignment: .trailing)
            }

            Slider(value: $brushSize, in: 1...24, step: 1)
                .tint(MorphColors.primary)

            HStack(spacing: isImmersive ? 6 : 8) {
                ForEach(brushPresets, id: \.self) { size in
                    Button {
                        brushSize = size
                    } label: {
                        Text("\(Int(size))")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Int(brushSize) == Int(size) ? MorphColors.onPrimary : MorphColors.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .frame(height: isImmersive ? 26 : 28)
                            .background(
                                Int(brushSize) == Int(size)
                                    ? AnyShapeStyle(MorphGradient.primary)
                                    : AnyShapeStyle(MorphColors.surfaceContainer.opacity(0.7))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(isImmersive ? 8 : (isCompact ? 10 : 12))
        .background(MorphColors.surfaceContainer.opacity(isImmersive ? 0.35 : 0.45))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private enum DrawingColor: String, CaseIterable, Identifiable {
    case primary, secondary, tertiary, white

    var id: String { rawValue }

    var swiftUIColor: Color {
        switch self {
        case .primary: return MorphColors.primary
        case .secondary: return MorphColors.secondary
        case .tertiary: return MorphColors.tertiary
        case .white: return .white
        }
    }

    var uiColor: UIColor {
        switch self {
        case .primary: return UIColor(MorphColors.primary)
        case .secondary: return UIColor(MorphColors.secondary)
        case .tertiary: return UIColor(MorphColors.tertiary)
        case .white: return .white
        }
    }
}

private extension Color {
    func hexRGB() -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

private enum CanvasMetrics {
    static let contentSize = CGSize(width: 768, height: 1024)
    static let maxRelativeZoom: CGFloat = 4
}

@MainActor
final class CanvasController: ObservableObject {
    @Published private(set) var canUndo = false
    @Published private(set) var backgroundImage: UIImage?
    @Published private(set) var rebindToken = UUID()
    @Published private(set) var zoomScale: CGFloat = 1
    @Published private(set) var canvasFitScale: CGFloat = 1

    private(set) var isFullscreenMode = false

    var relativeZoomPercent: Int {
        guard canvasFitScale > 0.001 else { return 100 }
        return Int((zoomScale / canvasFitScale * 100).rounded())
    }

    var isZoomAtMinimum: Bool {
        guard canvasFitScale > 0.001 else { return true }
        return zoomScale <= canvasFitScale * 1.01
    }

    var isZoomAtMaximum: Bool {
        guard canvasFitScale > 0.001 else { return true }
        let maxScale = canvasFitScale * CanvasMetrics.maxRelativeZoom
        return zoomScale >= maxScale * 0.99
    }

    var isZoomedIn: Bool {
        if isFullscreenMode {
            return zoomScale > 1.01
        }
        guard canvasFitScale > 0.001 else { return false }
        return zoomScale > canvasFitScale * 1.01
    }

    var displayZoomPercent: Int {
        if isFullscreenMode {
            return Int((zoomScale * 100).rounded())
        }
        return relativeZoomPercent
    }

    var isDisplayZoomAtMinimum: Bool {
        if isFullscreenMode {
            return zoomScale <= 1.01
        }
        return isZoomAtMinimum
    }

    var isDisplayZoomAtMaximum: Bool {
        if isFullscreenMode {
            return zoomScale >= CanvasMetrics.maxRelativeZoom * 0.99
        }
        return isZoomAtMaximum
    }

    weak var hostView: CanvasHostView?
    weak var zoomContainer: ZoomableCanvasContainer?

    private var storedDrawing = PKDrawing()
    private var storedBackgroundImage: UIImage?
    private var shouldResetFullscreenZoom = true

    func commitDrawing() {
        if let host = hostView {
            let canvas = host.canvasView
            let delegate = canvas.delegate
            canvas.delegate = nil
            storedDrawing = canvas.drawing
            canvas.delegate = delegate
        }
    }

    func prepareForFullscreen() {
        commitDrawing()
        unbind()
        isFullscreenMode = true
        shouldResetFullscreenZoom = true
    }

    func finishLeavingFullscreen() {
        isFullscreenMode = false
        triggerRebind()
        DispatchQueue.main.async { [weak self] in
            self?.refitActiveCanvas()
        }
    }

    func bind(_ host: CanvasHostView) {
        hostView = host
        host.imageView.image = storedBackgroundImage
        host.setNeedsLayout()
        host.layoutIfNeeded()

        let canvas = host.canvasView
        canvas.isUserInteractionEnabled = true
        canvas.drawingPolicy = .anyInput
        canvas.contentSize = logicalContentSize()
        applyDrawing(storedDrawing, to: canvas)
        if let container = zoomContainer, container.hostView === host {
            container.applyZoomConfiguration(resetZoom: shouldResetFullscreenZoom)
            shouldResetFullscreenZoom = false
            publishFitScale(1)
            publishZoom(container.scrollView.zoomScale)
        } else {
            fitCanvasToDisplay(in: host)
        }
        publishUndoState()
    }

    private func logicalContentSize() -> CGSize {
        let base = CanvasHostView.logicalContentSize(for: storedBackgroundImage)
        let strokeBounds = storedDrawing.bounds
        guard !strokeBounds.isEmpty else { return base }
        let padded = strokeBounds.insetBy(dx: -24, dy: -24)
        return CGSize(
            width: max(base.width, padded.maxX),
            height: max(base.height, padded.maxY)
        )
    }

    func unbind() {
        if let host = hostView {
            let canvas = host.canvasView
            let delegate = canvas.delegate
            canvas.delegate = nil
            resetHostZoomIfNeeded(host)
            host.layoutIfNeeded()
            storedDrawing = canvas.drawing
            canvas.delegate = delegate
        }
        hostView = nil
        zoomContainer = nil
        publishZoom(1)
    }

    func triggerRebind() {
        DispatchQueue.main.async { [weak self] in
            self?.rebindToken = UUID()
        }
    }

    func setBackground(_ image: UIImage?) {
        storedBackgroundImage = image
        hostView?.imageView.image = image
        publishBackgroundImage(image)
    }

    func syncDrawing(_ drawing: PKDrawing) {
        storedDrawing = drawing
        publishUndoState()
    }

    func clearStrokes() {
        storedDrawing = PKDrawing()
        if let host = hostView {
            let delegate = host.canvasView.delegate
            host.canvasView.delegate = nil
            host.canvasView.drawing = PKDrawing()
            host.canvasView.delegate = delegate
        }
        publishUndoState()
    }

    func clearAll() {
        clearStrokes()
        setBackground(nil)
    }

    func undo() {
        hostView?.canvasView.undoManager?.undo()
        if let host = hostView {
            storedDrawing = host.canvasView.drawing
        }
        publishUndoState()
    }

    private func publishUndoState() {
        let newValue = hostView?.canvasView.undoManager?.canUndo ?? !storedDrawing.strokes.isEmpty
        publish(\.canUndo, newValue)
    }

    func updateUndoState() {
        publishUndoState()
    }

    func updateZoomScale(_ scale: CGFloat) {
        publishZoom(scale)
    }

    private func publishZoom(_ scale: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let self, abs(self.zoomScale - scale) > 0.0001 else { return }
            self.zoomScale = scale
        }
    }

    private func publishFitScale(_ scale: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let self, abs(self.canvasFitScale - scale) > 0.0001 else { return }
            self.canvasFitScale = scale
        }
    }

    private func publishBackgroundImage(_ image: UIImage?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.backgroundImage !== image else { return }
            self.backgroundImage = image
        }
    }

    private func publish<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<CanvasController, T>, _ newValue: T) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self[keyPath: keyPath] != newValue else { return }
            self[keyPath: keyPath] = newValue
        }
    }

    func zoomIn() {
        guard let container = zoomContainer else { return }
        container.zoomIn()
    }

    func zoomOut() {
        guard let container = zoomContainer else { return }
        container.zoomOut()
    }

    func resetZoom(animated: Bool = true) {
        if let container = zoomContainer {
            container.resetZoom(animated: animated)
            publishFitScale(1)
        } else if let host = hostView {
            fitCanvasToDisplay(in: host, animated: animated)
        }
    }

    func resetZoomState() {
        publishZoom(1)
        publishFitScale(1)
    }

    private func fitCanvasToDisplay(in host: CanvasHostView, animated: Bool = false) {
        let canvas = host.canvasView
        host.layoutIfNeeded()
        let displaySize = canvas.frame.size
        guard displaySize.width > 1, displaySize.height > 1 else { return }

        let contentSize = canvas.contentSize
        guard contentSize.width > 1, contentSize.height > 1 else { return }

        let fitScale = min(
            displaySize.width / contentSize.width,
            displaySize.height / contentSize.height
        )
        let maxScale = fitScale * CanvasMetrics.maxRelativeZoom
        canvas.minimumZoomScale = fitScale
        canvas.maximumZoomScale = maxScale
        guard let scrollView = canvas.zoomScrollView else { return }
        scrollView.minimumZoomScale = fitScale
        scrollView.maximumZoomScale = maxScale
        scrollView.isScrollEnabled = true
        scrollView.bouncesZoom = true
        scrollView.setZoomScale(fitScale, animated: animated)
        scrollView.contentOffset = .zero
        publishFitScale(fitScale)
        publishZoom(fitScale)
    }

    func refitActiveCanvas() {
        guard let host = hostView else { return }
        fitCanvasToDisplay(in: host)
    }

    private func applyDrawing(_ drawing: PKDrawing, to canvasView: PKCanvasView) {
        let delegate = canvasView.delegate
        canvasView.delegate = nil
        canvasView.drawing = drawing
        canvasView.delegate = delegate
    }

    private func resetHostZoomIfNeeded(_ host: CanvasHostView) {
        if let container = zoomContainer, container.hostView === host {
            container.resetZoom(animated: false)
        } else {
            host.canvasView.zoomScrollView?.setZoomScale(host.canvasView.minimumZoomScale, animated: false)
        }
    }

    func snapshot() -> UIImage? {
        guard let host = hostView else { return nil }
        let bounds = host.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { _ in
            host.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
    }
}

final class CanvasHostView: UIView {
    let contentView = UIView()
    let imageView = UIImageView()
    let canvasView = PKCanvasView()

    private var lastLayoutBounds: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        addSubview(contentView)
        contentView.addSubview(imageView)
        contentView.addSubview(canvasView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1, bounds.height > 1 else { return }
        guard bounds.size != lastLayoutBounds || contentView.frame == .zero else { return }
        lastLayoutBounds = bounds.size

        let contentSize = CanvasHostView.logicalContentSize(for: imageView.image)
        let fitFrame = Self.aspectFitFrame(for: contentSize, in: bounds)
        contentView.frame = fitFrame
        imageView.frame = contentView.bounds
        canvasView.frame = contentView.bounds
    }

    static func logicalContentSize(for image: UIImage?) -> CGSize {
        if let image, image.size.width > 0, image.size.height > 0 {
            return image.size
        }
        return CanvasMetrics.contentSize
    }

    private static func aspectFitFrame(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - size.width * 0.5,
            y: bounds.midY - size.height * 0.5,
            width: size.width,
            height: size.height
        )
    }

    static func aspectFitSize(for image: UIImage?, in bounds: CGSize) -> CGSize {
        let contentSize = logicalContentSize(for: image)
        guard bounds.width > 0, bounds.height > 0 else { return bounds }
        let scale = min(bounds.width / contentSize.width, bounds.height / contentSize.height)
        return CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
    }

    func resetLayoutCache() {
        lastLayoutBounds = .zero
    }
}

final class ZoomableCanvasContainer: UIView, UIScrollViewDelegate {
    let scrollView = UIScrollView()
    let hostView = CanvasHostView()

    var onZoomScaleChanged: ((CGFloat) -> Void)?
    var onBoundsReady: (() -> Void)?
    var contentInsets: UIEdgeInsets = .zero

    private var configuredBounds: CGSize = .zero
    private var configuredContentInsets: UIEdgeInsets = .zero
    private var didDisableInternalCanvasZoom = false
    private lazy var doubleTapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        recognizer.numberOfTapsRequired = 2
        return recognizer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
        scrollView.delegate = self
        scrollView.clipsToBounds = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .clear
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.addGestureRecognizer(doubleTapRecognizer)
        addSubview(scrollView)
        scrollView.addSubview(hostView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        guard bounds.width > 1, bounds.height > 1 else { return }

        let layoutChanged = configuredBounds != bounds.size || configuredContentInsets != contentInsets
        if layoutChanged {
            configuredBounds = bounds.size
            configuredContentInsets = contentInsets
            hostView.resetLayoutCache()
            layoutHostViewForCurrentBounds()
            scrollView.minimumZoomScale = 1
            scrollView.maximumZoomScale = CanvasMetrics.maxRelativeZoom
            if scrollView.zoomScale < scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
            }
            didDisableInternalCanvasZoom = false
            onBoundsReady?()
        }

        if !didDisableInternalCanvasZoom {
            disableInternalCanvasZoom()
            didDisableInternalCanvasZoom = true
        }
        centerScrollContent()
    }

    func applyZoomConfiguration(resetZoom: Bool) {
        scrollView.frame = bounds
        configuredBounds = bounds.size
        configuredContentInsets = contentInsets
        hostView.resetLayoutCache()
        layoutHostViewForCurrentBounds()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = CanvasMetrics.maxRelativeZoom
        didDisableInternalCanvasZoom = false
        disableInternalCanvasZoom()
        didDisableInternalCanvasZoom = true
        if resetZoom {
            scrollView.setZoomScale(1, animated: false)
        }
        centerScrollContent()
        onZoomScaleChanged?(scrollView.zoomScale)
    }

    private func layoutHostViewForCurrentBounds() {
        let fitSize = CanvasHostView.aspectFitSize(for: hostView.imageView.image, in: bounds.size)
        hostView.frame = CGRect(origin: .zero, size: fitSize)
        hostView.setNeedsLayout()
        hostView.layoutIfNeeded()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        hostView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerScrollContent()
        onZoomScaleChanged?(scrollView.zoomScale)
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        centerScrollContent()
        onZoomScaleChanged?(scale)
    }

    private func centerScrollContent() {
        let visibleWidth = bounds.width - contentInsets.left - contentInsets.right
        let visibleHeight = bounds.height - contentInsets.top - contentInsets.bottom
        let scaledWidth = hostView.frame.width * scrollView.zoomScale
        let scaledHeight = hostView.frame.height * scrollView.zoomScale
        let offsetX = contentInsets.left + max((visibleWidth - scaledWidth) * 0.5, 0)
        let offsetY = contentInsets.top + max((visibleHeight - scaledHeight) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(
            top: offsetY,
            left: offsetX,
            bottom: max(bounds.height - scaledHeight - offsetY, 0),
            right: max(bounds.width - scaledWidth - offsetX, 0)
        )
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        let target: CGFloat = scrollView.zoomScale > 1.15
            ? scrollView.minimumZoomScale
            : min(2, scrollView.maximumZoomScale)
        scrollView.setZoomScale(target, animated: true)
    }

    private func disableInternalCanvasZoom() {
        let canvas = hostView.canvasView
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        guard let internalScroll = canvas.zoomScrollView else { return }
        internalScroll.minimumZoomScale = 1
        internalScroll.maximumZoomScale = 1
        internalScroll.isScrollEnabled = false
        internalScroll.pinchGestureRecognizer?.isEnabled = false
    }

    func zoomIn() {
        let target = min(scrollView.zoomScale * 1.25, scrollView.maximumZoomScale)
        scrollView.setZoomScale(target, animated: true)
        onZoomScaleChanged?(target)
    }

    func zoomOut() {
        let target = max(scrollView.zoomScale / 1.25, scrollView.minimumZoomScale)
        scrollView.setZoomScale(target, animated: true)
        onZoomScaleChanged?(target)
    }

    func resetZoom(animated: Bool = true) {
        scrollView.setZoomScale(1, animated: animated)
        onZoomScaleChanged?(1)
    }
}

private extension UIView {
    var embeddedScrollView: UIScrollView? {
        if let scrollView = self as? UIScrollView { return scrollView }
        for subview in subviews {
            if let scrollView = subview.embeddedScrollView { return scrollView }
        }
        return nil
    }
}

private extension PKCanvasView {
    var zoomScrollView: UIScrollView? {
        embeddedScrollView
    }
}

private struct ZoomablePencilCanvasView: UIViewRepresentable {
    var controller: CanvasController
    var backgroundImage: UIImage?
    var rebindToken: UUID
    var contentInsets: UIEdgeInsets = .zero
    var inkColor: UIColor
    var isEraser: Bool
    var inkWidth: CGFloat = 4

    func makeUIView(context: Context) -> ZoomableCanvasContainer {
        let container = ZoomableCanvasContainer()
        let canvas = container.hostView.canvasView
        canvas.drawingPolicy = .anyInput
        canvas.isUserInteractionEnabled = true
        canvas.delegate = context.coordinator
        container.onBoundsReady = { [weak coordinator = context.coordinator] in
            coordinator?.retrySyncHost()
        }
        container.onZoomScaleChanged = { [weak controller] scale in
            DispatchQueue.main.async {
                controller?.updateZoomScale(scale)
            }
        }
        context.coordinator.attachContainer(container)
        return container
    }

    func updateUIView(_ container: ZoomableCanvasContainer, context: Context) {
        container.contentInsets = contentInsets
        container.hostView.imageView.image = backgroundImage
        container.setNeedsLayout()
        container.layoutIfNeeded()
        context.coordinator.updateSync(
            host: container.hostView,
            rebindToken: rebindToken,
            inkColor: inkColor,
            isEraser: isEraser,
            inkWidth: inkWidth
        )
    }

    static func dismantleUIView(_ uiView: ZoomableCanvasContainer, coordinator: Coordinator) {
        uiView.onZoomScaleChanged = nil
        uiView.onBoundsReady = nil
        coordinator.commitBeforeDetach()
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let controller: CanvasController
        weak var container: ZoomableCanvasContainer?
        private var lastAppliedRebindToken: UUID?
        private var pendingHost: CanvasHostView?
        private var pendingRebindToken: UUID?
        private var pendingInkColor: UIColor = .black
        private var pendingIsEraser = false
        private var pendingInkWidth: CGFloat = 4

        init(controller: CanvasController) {
            self.controller = controller
        }

        func attachContainer(_ container: ZoomableCanvasContainer) {
            self.container = container
            controller.zoomContainer = container
        }

        func updateSync(
            host: CanvasHostView,
            rebindToken: UUID,
            inkColor: UIColor,
            isEraser: Bool,
            inkWidth: CGFloat
        ) {
            pendingHost = host
            pendingRebindToken = rebindToken
            pendingInkColor = inkColor
            pendingIsEraser = isEraser
            pendingInkWidth = inkWidth
            syncHostIfReady(host, rebindToken: rebindToken)
            applyTool(to: host)
        }

        func retrySyncHost() {
            guard let host = pendingHost, let rebindToken = pendingRebindToken else { return }
            syncHostIfReady(host, rebindToken: rebindToken)
            applyTool(to: host)
        }

        private func syncHostIfReady(_ host: CanvasHostView, rebindToken: UUID) {
            host.superview?.layoutIfNeeded()
            host.layoutIfNeeded()
            guard host.bounds.width > 1, host.bounds.height > 1 else {
                DispatchQueue.main.async { [weak self] in
                    self?.retrySyncHost()
                }
                return
            }
            let needsSync = controller.hostView !== host || lastAppliedRebindToken != rebindToken
            guard needsSync else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let stillNeedsSync = self.controller.hostView !== host || self.lastAppliedRebindToken != rebindToken
                guard stillNeedsSync else { return }
                if let zoomContainer = self.container {
                    self.controller.zoomContainer = zoomContainer
                }
                self.controller.bind(host)
                self.lastAppliedRebindToken = rebindToken
            }
        }

        private func applyTool(to host: CanvasHostView) {
            if pendingIsEraser {
                host.canvasView.tool = PKEraserTool(.bitmap)
            } else {
                host.canvasView.tool = PKInkingTool(.pen, color: pendingInkColor, width: pendingInkWidth)
            }
        }

        func commitBeforeDetach() {
            if let host = container?.hostView, controller.hostView === host {
                controller.commitDrawing()
            }
        }

        func detach() {
            container?.onZoomScaleChanged = nil
            container?.onBoundsReady = nil
            controller.zoomContainer = nil
            controller.resetZoomState()
            container = nil
            lastAppliedRebindToken = nil
            pendingHost = nil
            pendingRebindToken = nil
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            Task { @MainActor in
                guard controller.hostView != nil else { return }
                controller.syncDrawing(canvasView.drawing)
            }
        }
    }
}

private struct PencilCanvasView: UIViewRepresentable {
    var controller: CanvasController
    var backgroundImage: UIImage?
    var rebindToken: UUID
    var isBindingEnabled: Bool = true
    var inkColor: UIColor
    var isEraser: Bool
    var inkWidth: CGFloat = 4
    var isDrawingEnabled: Bool = true

    func makeUIView(context: Context) -> CanvasHostView {
        let host = CanvasHostView()
        host.canvasView.drawingPolicy = .anyInput
        host.canvasView.isUserInteractionEnabled = isDrawingEnabled
        host.canvasView.delegate = context.coordinator
        context.coordinator.containerHost = host
        return host
    }

    func updateUIView(_ host: CanvasHostView, context: Context) {
        host.canvasView.isUserInteractionEnabled = isDrawingEnabled
        host.imageView.image = backgroundImage
        host.setNeedsLayout()
        host.layoutIfNeeded()
        context.coordinator.updateSync(
            host: host,
            rebindToken: rebindToken,
            isBindingEnabled: isBindingEnabled
        )
        if isEraser {
            host.canvasView.tool = PKEraserTool(.bitmap)
        } else {
            host.canvasView.tool = PKInkingTool(.pen, color: inkColor, width: inkWidth)
        }
    }

    static func dismantleUIView(_ uiView: CanvasHostView, coordinator: Coordinator) {
        coordinator.commitBeforeDetach()
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let controller: CanvasController
        weak var containerHost: CanvasHostView?
        private var lastAppliedRebindToken: UUID?
        private var pendingHost: CanvasHostView?
        private var pendingRebindToken: UUID?
        private var pendingBindingEnabled = true

        init(controller: CanvasController) {
            self.controller = controller
        }

        func updateSync(host: CanvasHostView, rebindToken: UUID, isBindingEnabled: Bool) {
            pendingHost = host
            pendingRebindToken = rebindToken
            pendingBindingEnabled = isBindingEnabled
            syncHostIfReady(host, rebindToken: rebindToken, isBindingEnabled: isBindingEnabled)
        }

        private func syncHostIfReady(
            _ host: CanvasHostView,
            rebindToken: UUID,
            isBindingEnabled: Bool
        ) {
            guard isBindingEnabled, !controller.isFullscreenMode else { return }
            host.layoutIfNeeded()
            guard host.bounds.width > 1, host.bounds.height > 1 else {
                DispatchQueue.main.async { [weak self] in
                    guard let self, let host = self.pendingHost, let token = self.pendingRebindToken else { return }
                    self.syncHostIfReady(host, rebindToken: token, isBindingEnabled: self.pendingBindingEnabled)
                }
                return
            }
            let needsSync = controller.hostView !== host || lastAppliedRebindToken != rebindToken
            guard needsSync else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.pendingBindingEnabled, !self.controller.isFullscreenMode else { return }
                let stillNeedsSync = self.controller.hostView !== host || self.lastAppliedRebindToken != rebindToken
                guard stillNeedsSync else { return }
                self.controller.zoomContainer = nil
                self.controller.resetZoomState()
                self.controller.bind(host)
                self.lastAppliedRebindToken = rebindToken
            }
        }

        func commitBeforeDetach() {
            if let host = containerHost, controller.hostView === host {
                controller.commitDrawing()
            }
        }

        func detach() {
            controller.zoomContainer = nil
            containerHost = nil
            lastAppliedRebindToken = nil
            pendingHost = nil
            pendingRebindToken = nil
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            Task { @MainActor in
                guard controller.hostView != nil else { return }
                controller.syncDrawing(canvasView.drawing)
            }
        }
    }
}
