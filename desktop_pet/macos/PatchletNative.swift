import AppKit
import ImageIO

let cellWidth = 192
let cellHeight = 208
let scale: CGFloat = 1.35

final class PatchletWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: PatchletWindow!
    var imageView: NSImageView!
    var frames: [NSImage] = []
    var frameIndex = 0
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        frames = loadFrames()

        let size = NSSize(width: CGFloat(cellWidth) * scale, height: CGFloat(cellHeight) * scale)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 1200, height: 800)
        let origin = NSPoint(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2)

        window = PatchletWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "小补丁 Native"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.4, alpha: 1.0)

        imageView = NSImageView(frame: NSRect(origin: .zero, size: size))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = window.backgroundColor?.cgColor
        imageView.image = frames.first
        window.contentView = imageView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        timer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func advanceFrame() {
        guard !frames.isEmpty else { return }
        frameIndex = (frameIndex + 1) % frames.count
        imageView.image = frames[frameIndex]
    }

    func loadFrames() -> [NSImage] {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0])
        let appURL = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bundled = appURL.appendingPathComponent("Contents/Resources/assets/spritesheet.webp")
        let local = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("assets/spritesheet.webp")
        let spriteURL = FileManager.default.fileExists(atPath: bundled.path) ? bundled : local

        guard
            let source = CGImageSourceCreateWithURL(spriteURL as CFURL, nil),
            let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            let fallback = NSImage(size: NSSize(width: cellWidth, height: cellHeight))
            fallback.lockFocus()
            NSColor.systemYellow.setFill()
            NSRect(x: 0, y: 0, width: cellWidth, height: cellHeight).fill()
            "Patchlet".draw(at: NSPoint(x: 28, y: 92), withAttributes: [
                .font: NSFont.boldSystemFont(ofSize: 28),
                .foregroundColor: NSColor.black,
            ])
            fallback.unlockFocus()
            return [fallback]
        }

        var out: [NSImage] = []
        for column in 0..<6 {
            let rect = CGRect(x: column * cellWidth, y: 0, width: cellWidth, height: cellHeight)
            if let cropped = atlas.cropping(to: rect) {
                out.append(NSImage(cgImage: cropped, size: NSSize(width: cellWidth, height: cellHeight)))
            }
        }
        return out
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
