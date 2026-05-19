import AppKit
import ImageIO

let cellWidth = 192
let cellHeight = 208
let edgeCellWidth = 208
let edgeCellHeight = 192
let edgeFrameCount = 16
let scale: CGFloat = 0.45
let stateRows: [String: (row: Int, frames: Int)] = [
    "idle": (0, 6),
    "running-right": (1, 8),
    "running-left": (2, 8),
    "waving": (3, 4),
    "jumping": (4, 5),
    "failed": (5, 8),
    "waiting": (6, 6),
    "running": (7, 6),
    "review": (8, 6),
]
let edgeDirectionRows: [String: (row: Int, frames: Int)] = [
    "running-down-right-edge": (0, edgeFrameCount),
    "running-up-right-edge": (1, edgeFrameCount),
    "running-down-left-edge": (2, edgeFrameCount),
    "running-up-left-edge": (3, edgeFrameCount),
]
final class PatchletWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func mouseDown(with event: NSEvent) {
        performDrag(with: event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: PatchletWindow!
    var imageView: NSImageView!
    var sprites: [String: [NSImage]] = [:]
    var stateSizes: [String: NSSize] = [:]
    var state = "idle"
    var frameIndex = 0
    var timer: Timer?
    var patrolTimer: Timer?
    var triggerTimer: Timer?
    var lastTriggerDate: Date?
    var frameAccumulator: TimeInterval = 0
    var edge = "bottom"
    var edgeLoops = 0
    var clockwise = true
    var restingUntil: Date?
    var resourceAssets: URL!
    var localAssets: URL!
    var currentScreenIndex = 0
    let edgeStep: CGFloat = 2.4

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureAssetLocations()
        currentScreenIndex = preferredScreenIndex()
        if var loaded = loadSprites() {
            loadEdgeSprites(into: &loaded.sprites, sizes: &loaded.sizes)
            sprites = loaded.sprites
            stateSizes = loaded.sizes
        } else {
            let fallback = fallbackSprites()
            sprites = fallback.sprites
            stateSizes = fallback.sizes
        }

        let size = NSSize(width: CGFloat(cellWidth) * scale, height: CGFloat(cellHeight) * scale)
        let screen = currentScreenFrame()
        let origin = NSPoint(x: screen.maxX - size.width - 24, y: screen.minY + 8)

        window = PatchletWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.hasShadow = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false

        imageView = NSImageView(frame: NSRect(origin: .zero, size: size))
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.clear.cgColor
        imageView.layer?.magnificationFilter = .nearest
        imageView.image = sprites[state]?.first
        window.contentView = imageView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            self?.advanceFrame(delta: 0.04)
        }
        patrolTimer = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: true) { [weak self] _ in
            self?.moveAlongScreenEdge()
        }
        lastTriggerDate = taskCompletionSignalDate()
        triggerTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkTaskCompletionTrigger()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func advanceFrame(delta: TimeInterval) {
        guard let frames = sprites[state], !frames.isEmpty else { return }
        frameAccumulator += delta
        let interval = frameInterval(for: state)
        guard interval > 0 else { return }
        while frameAccumulator >= interval {
            frameAccumulator -= interval
            frameIndex = (frameIndex + 1) % frames.count
        }
        imageView.image = frames[frameIndex]
    }

    func frameInterval(for state: String) -> TimeInterval {
        if state.contains("-edge") {
            return 0.07
        }
        if state == "running-left" || state == "running-right" {
            return 0.12
        }
        if state == "idle" {
            return 0.18
        }
        return 0.14
    }

    func setState(_ newState: String) {
        if state != newState {
            state = newState
            frameIndex = 0
            frameAccumulator = 0
            applyStateGeometry()
            if let firstFrame = sprites[newState]?.first {
                imageView.image = firstFrame
            }
        }
    }

    func applyStateGeometry() {
        guard let size = stateSizes[state] else { return }
        var frame = window.frame
        frame.size = size
        imageView.frame = NSRect(origin: .zero, size: size)
        if state.contains("right-edge") {
            imageView.imageAlignment = .alignRight
        } else if state.contains("left-edge") {
            imageView.imageAlignment = .alignLeft
        } else {
            imageView.imageAlignment = .alignCenter
        }
        window.setFrame(frame, display: true)
    }

    func moveAlongScreenEdge() {
        if let until = restingUntil {
            if Date() < until {
                setState("idle")
                return
            }
            restingUntil = nil
        }
        let screen = currentScreenFrame()
        var frame = window.frame
        let left = screen.minX + 8
        let bottom = screen.minY + 8

        if clockwise {
            moveClockwise(frame: &frame, screen: screen, left: left, bottom: bottom)
        } else {
            moveCounterClockwise(frame: &frame, screen: screen, left: left, bottom: bottom)
        }

        window.setFrameOrigin(frame.origin)
    }

    func moveClockwise(frame: inout NSRect, screen: NSRect, left: CGFloat, bottom: CGFloat) {
        switch edge {
        case "bottom":
            setState("running-left")
            syncWindowSize(&frame)
            frame.origin.y = bottom
            frame.origin.x -= edgeStep
            if frame.origin.x <= left {
                frame.origin.x = left
                if !crossToAdjacentScreen(from: screen, side: "left", frame: &frame) {
                    edge = "left"
                }
            }
        case "left":
            setState("running-up-left-edge")
            syncWindowSize(&frame)
            let top = topEdge(for: frame, in: screen)
            frame.origin.x = left
            frame.origin.y += edgeStep
            if frame.origin.y >= top {
                frame.origin.y = top
                edge = "top"
            }
        case "top":
            setState("running-right")
            syncWindowSize(&frame)
            let right = rightEdge(for: frame, in: screen)
            let top = topEdge(for: frame, in: screen)
            frame.origin.y = top
            frame.origin.x += edgeStep
            if frame.origin.x >= right {
                frame.origin.x = right
                if !crossToAdjacentScreen(from: screen, side: "right", frame: &frame) {
                    edge = "right"
                }
            }
        default:
            setState("running-down-right-edge")
            syncWindowSize(&frame)
            let right = rightEdge(for: frame, in: screen)
            frame.origin.x = right
            frame.origin.y -= edgeStep
            if frame.origin.y <= bottom {
                frame.origin.y = bottom
                edge = "bottom"
                completeLoop()
            }
        }
    }

    func moveCounterClockwise(frame: inout NSRect, screen: NSRect, left: CGFloat, bottom: CGFloat) {
        switch edge {
        case "bottom":
            setState("running-right")
            syncWindowSize(&frame)
            let right = rightEdge(for: frame, in: screen)
            frame.origin.y = bottom
            frame.origin.x += edgeStep
            if frame.origin.x >= right {
                frame.origin.x = right
                if !crossToAdjacentScreen(from: screen, side: "right", frame: &frame) {
                    edge = "right"
                }
            }
        case "right":
            setState("running-up-right-edge")
            syncWindowSize(&frame)
            let right = rightEdge(for: frame, in: screen)
            let top = topEdge(for: frame, in: screen)
            frame.origin.x = right
            frame.origin.y += edgeStep
            if frame.origin.y >= top {
                frame.origin.y = top
                edge = "top"
            }
        case "top":
            setState("running-left")
            syncWindowSize(&frame)
            let top = topEdge(for: frame, in: screen)
            frame.origin.y = top
            frame.origin.x -= edgeStep
            if frame.origin.x <= left {
                frame.origin.x = left
                if !crossToAdjacentScreen(from: screen, side: "left", frame: &frame) {
                    edge = "left"
                }
            }
        default:
            setState("running-down-left-edge")
            syncWindowSize(&frame)
            frame.origin.x = left
            frame.origin.y -= edgeStep
            if frame.origin.y <= bottom {
                frame.origin.y = bottom
                edge = "bottom"
                completeLoop()
            }
        }
    }

    func syncWindowSize(_ frame: inout NSRect) {
        frame.size = window.frame.size
    }

    func rightEdge(for frame: NSRect, in screen: NSRect) -> CGFloat {
        screen.maxX - frame.width - 8
    }

    func topEdge(for frame: NSRect, in screen: NSRect) -> CGFloat {
        screen.maxY - frame.height - 8
    }

    func completeLoop() {
        edgeLoops += 1
        if Double.random(in: 0..<1) < 1.0 / 3.0 {
            restingUntil = Date().addingTimeInterval(Double.random(in: 4.0...8.0))
            setState("idle")
        }
        if Double.random(in: 0..<1) < 0.5 {
            clockwise.toggle()
        }
    }

    func patrolScreens() -> [NSRect] {
        let screens = NSScreen.screens.map(\.visibleFrame)
        guard !screens.isEmpty else {
            return [NSRect(x: 100, y: 100, width: 1200, height: 800)]
        }
        return screens.sorted { lhs, rhs in
            if lhs.minX == rhs.minX {
                return lhs.minY < rhs.minY
            }
            return lhs.minX < rhs.minX
        }
    }

    func currentScreenFrame() -> NSRect {
        let screens = patrolScreens()
        if currentScreenIndex >= screens.count {
            currentScreenIndex = 0
        }
        return screens[currentScreenIndex]
    }

    func mainScreenIndex() -> Int {
        guard let mainFrame = NSScreen.main?.visibleFrame else { return 0 }
        return patrolScreens().firstIndex { frame in
            abs(frame.minX - mainFrame.minX) < 1
                && abs(frame.minY - mainFrame.minY) < 1
                && abs(frame.width - mainFrame.width) < 1
                && abs(frame.height - mainFrame.height) < 1
        } ?? 0
    }

    func preferredScreenIndex() -> Int {
        let screens = patrolScreens()
        let mouseLocation = NSEvent.mouseLocation
        if let index = screens.firstIndex(where: { $0.contains(mouseLocation) }) {
            return index
        }
        return mainScreenIndex()
    }

    func crossToAdjacentScreen(from screen: NSRect, side: String, frame: inout NSRect) -> Bool {
        let screens = patrolScreens()
        guard screens.count > 1 else { return false }
        let overlapTolerance: CGFloat = 80
        let candidates = screens.enumerated().filter { index, candidate in
            guard index != currentScreenIndex else { return false }
            let verticallyConnected = candidate.maxY >= screen.minY + overlapTolerance
                && candidate.minY <= screen.maxY - overlapTolerance
            if side == "left" {
                return verticallyConnected && candidate.maxX <= screen.minX + 1
            }
            return verticallyConnected && candidate.minX >= screen.maxX - 1
        }
        guard let target = candidates.min(by: { lhs, rhs in
            let lhsDistance = abs(lhs.element.midX - screen.midX)
            let rhsDistance = abs(rhs.element.midX - screen.midX)
            return lhsDistance < rhsDistance
        }) else {
            return false
        }

        currentScreenIndex = target.offset
        let targetScreen = target.element
        let normalizedY = (frame.midY - screen.minY) / max(1, screen.height)
        let targetCenterY = targetScreen.minY + normalizedY * targetScreen.height
        frame.origin.y = min(
            max(targetScreen.minY + 8, targetCenterY - frame.height / 2),
            topEdge(for: frame, in: targetScreen)
        )

        if side == "left" {
            frame.origin.x = rightEdge(for: frame, in: targetScreen)
            setState("running-left")
        } else {
            frame.origin.x = targetScreen.minX + 8
            setState("running-right")
        }
        return true
    }

    func checkTaskCompletionTrigger() {
        guard let modified = taskCompletionSignalDate() else { return }
        if modified > (lastTriggerDate ?? .distantPast) {
            lastTriggerDate = modified
            playMeow()
        }
    }

    func playMeow() {
        let purrURL = URL(fileURLWithPath: "/System/Library/Sounds/Purr.aiff")
        if let sound = NSSound(contentsOf: purrURL, byReference: true) {
            sound.volume = 1.0
            sound.play()
        } else if let sound = NSSound(named: "Purr") ?? NSSound(named: "Glass") {
            sound.volume = 1.0
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    func taskCompletionSignalDate() -> Date? {
        let url = taskCompletionTriggerURL()
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attrs?[.modificationDate] as? Date
    }

    func taskCompletionTriggerURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = appSupport.appendingPathComponent("Patchlet", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("task-complete.signal")
    }

    func configureAssetLocations() {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0])
        let appURL = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        resourceAssets = appURL.appendingPathComponent("Contents/Resources/assets")
        localAssets = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("assets")
    }

    func loadSprites() -> (sprites: [String: [NSImage]], sizes: [String: NSSize])? {
        guard
            let spriteURL = assetURL(named: "spritesheet.webp", bundledAssets: resourceAssets, localAssets: localAssets),
            let source = CGImageSourceCreateWithURL(spriteURL as CFURL, [
                kCGImageSourceShouldCache: false,
            ] as CFDictionary),
            let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        var out: [String: [NSImage]] = [:]
        var sizes: [String: NSSize] = [:]
        for (state, spec) in stateRows {
            var frames: [NSImage] = []
            for column in 0..<spec.frames {
                let rect = CGRect(x: column * cellWidth, y: spec.row * cellHeight, width: cellWidth, height: cellHeight)
                if let cropped = atlas.cropping(to: rect) {
                    frames.append(scaledImage(cropped))
                }
            }
            out[state] = frames
            sizes[state] = maxSize(frames)
        }
        return (out, sizes)
    }

    func loadEdgeSprites(into out: inout [String: [NSImage]], sizes: inout [String: NSSize]) {
        let edgeSpriteURL = assetURL(named: "patchlet-edge-directions.png", bundledAssets: resourceAssets, localAssets: localAssets)
        if
            let edgeSpriteURL,
            FileManager.default.fileExists(atPath: edgeSpriteURL.path),
            let edgeSource = CGImageSourceCreateWithURL(edgeSpriteURL as CFURL, [
                kCGImageSourceShouldCache: false,
            ] as CFDictionary),
            let edgeAtlas = CGImageSourceCreateImageAtIndex(edgeSource, 0, nil)
        {
            for (state, spec) in edgeDirectionRows {
                var frames: [NSImage] = []
                for column in 0..<spec.frames {
                    let rect = CGRect(x: column * edgeCellWidth, y: spec.row * edgeCellHeight, width: edgeCellWidth, height: edgeCellHeight)
                    if let cropped = edgeAtlas.cropping(to: rect) {
                        frames.append(scaledImage(cropped))
                    }
                }
                out[state] = frames
                sizes[state] = maxSize(frames)
            }
        } else {
            for (key, fallbackState) in [
                ("running-up-left-edge", "idle"),
                ("running-up-right-edge", "idle"),
                ("running-down-left-edge", "idle"),
                ("running-down-right-edge", "idle"),
            ] {
                out[key] = out[fallbackState]
                sizes[key] = sizes[fallbackState]
            }
        }
    }

    func assetURL(named fileName: String, bundledAssets: URL, localAssets: URL) -> URL? {
        let bundled = bundledAssets.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        let local = localAssets.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: local.path) {
            return local
        }
        return nil
    }

    func fallbackSprites() -> (sprites: [String: [NSImage]], sizes: [String: NSSize]) {
        let fallback = NSImage(size: NSSize(width: cellWidth, height: cellHeight))
        fallback.lockFocus()
        NSColor.systemYellow.setFill()
        NSRect(x: 0, y: 0, width: cellWidth, height: cellHeight).fill()
        "Patchlet".draw(at: NSPoint(x: 28, y: 92), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 28),
            .foregroundColor: NSColor.black,
        ])
        fallback.unlockFocus()
        var fallbackFrames: [String: [NSImage]] = [:]
        for key in stateRows.keys {
            fallbackFrames[key] = [fallback]
        }
        for key in edgeDirectionRows.keys {
            fallbackFrames[key] = [fallback]
        }
        var sizes: [String: NSSize] = [:]
        for key in fallbackFrames.keys {
            sizes[key] = fallback.size
        }
        return (fallbackFrames, sizes)
    }

    func scaledImage(_ image: CGImage) -> NSImage {
        let targetWidth = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let targetHeight = max(1, Int((CGFloat(image.height) * scale).rounded()))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard
            let context = CGContext(
                data: nil,
                width: targetWidth,
                height: targetHeight,
                bitsPerComponent: 8,
                bytesPerRow: targetWidth * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return NSImage(cgImage: image, size: NSSize(width: CGFloat(targetWidth), height: CGFloat(targetHeight)))
        }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let scaled = context.makeImage() else {
            return NSImage(cgImage: image, size: NSSize(width: CGFloat(targetWidth), height: CGFloat(targetHeight)))
        }
        return NSImage(cgImage: scaled, size: NSSize(width: CGFloat(targetWidth), height: CGFloat(targetHeight)))
    }

    func maxSize(_ frames: [NSImage]) -> NSSize {
        var width: CGFloat = 1
        var height: CGFloat = 1
        for frame in frames {
            width = max(width, frame.size.width)
            height = max(height, frame.size.height)
        }
        return NSSize(width: width, height: height)
    }

    func trimTransparent(_ image: NSImage) -> NSImage {
        var rect = NSRect(origin: .zero, size: image.size)
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            return image
        }
        let width = cg.width
        let height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[(y * width + x) * 4 + 3]
                if alpha > 8 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }
        if minX > maxX || minY > maxY {
            return image
        }
        let pad = 2
        minX = max(0, minX - pad)
        minY = max(0, minY - pad)
        maxX = min(width - 1, maxX + pad)
        maxY = min(height - 1, maxY + pad)
        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let cropped = cg.cropping(to: cropRect) else {
            return image
        }
        return scaledImage(cropped)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
