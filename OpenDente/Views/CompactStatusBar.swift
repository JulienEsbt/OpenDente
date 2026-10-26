import AppKit

/// A single template image, shared by the menu bar and its live settings preview.
/// Digits keep a solid face; a separate lower track shows the charge level.
@MainActor
enum CompactStatusBar {
    static func image(state: BatteryState, mode: ChargingMode, settings: AppSettings) -> NSImage {
        let known = state != .unknown
        let pct = min(100, max(0, state.effectivePercentage(useHardware: settings.useHardwareBatteryPercentage)))
        let number = known ? "\(pct)" : "—"
        let metrics = [
            state.statusBarText(effectivePercentage: pct, showPercentage: false,
                showTemperature: settings.statusBarShowTemperature, showPower: false),
            state.statusBarText(effectivePercentage: pct, showPercentage: false,
                showTemperature: false, showPower: settings.statusBarShowPower)
        ].filter { !$0.isEmpty }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let badge = settings.statusBarShowMode && mode != .onBattery && mode != .idle
            ? NSImage(systemSymbolName: mode.statusBarIcon, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 10, weight: .semibold)) : nil
        let metricsX: CGFloat = badge == nil ? 37 : 50
        let metricsWidth = metrics.map { ($0 as NSString).size(withAttributes: attrs).width }.max() ?? 0
        let width = metrics.isEmpty ? (badge == nil ? 34 : 47) : metricsX + ceil(metricsWidth)
        let showNumber = settings.statusBarShowPercentage
        let image = NSImage(size: NSSize(width: width, height: 20), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let body = NSRect(x: 0.5, y: showNumber ? 5 : 3, width: 30, height: showNumber ? 13 : 14)
            let outline = NSBezierPath(roundedRect: body, xRadius: 3.5, yRadius: 3.5)
            NSColor.black.withAlphaComponent(0.55).setFill()
            NSBezierPath(roundedRect: NSRect(x: 32, y: showNumber ? 9 : 7, width: 2, height: 6), xRadius: 1, yRadius: 1).fill()
            let inside = body.insetBy(dx: 1.5, dy: 1.5)
            if showNumber {
                // A moving fill boundary must never cross the digits.
                NSColor.black.setFill(); outline.fill()
                let track = NSRect(x: 0.5, y: 1, width: 30, height: 2)
                let trackPath = NSBezierPath(roundedRect: track, xRadius: 1, yRadius: 1)
                NSColor.black.withAlphaComponent(0.25).setFill(); trackPath.fill()
                context.saveGState()
                trackPath.addClip()
                NSColor.black.setFill()
                NSRect(x: track.minX, y: track.minY,
                    width: track.width * CGFloat(known ? pct : 0) / 100, height: track.height).fill()
                context.restoreGState()
                let numberAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold),
                    .foregroundColor: NSColor.black]
                let size = (number as NSString).size(withAttributes: numberAttrs)
                let point = NSPoint(x: body.midX - size.width / 2, y: body.midY - size.height / 2 + 0.5)
                context.saveGState()
                context.setBlendMode(.destinationOut)
                (number as NSString).draw(at: point, withAttributes: numberAttrs)
                context.restoreGState()
            } else {
                NSColor.black.withAlphaComponent(0.55).setStroke()
                outline.lineWidth = 1; outline.stroke()
                context.saveGState()
                NSBezierPath(roundedRect: inside, xRadius: 2, yRadius: 2).addClip()
                NSColor.black.withAlphaComponent(0.22).setFill(); inside.fill()
                NSColor.black.setFill()
                NSRect(x: inside.minX, y: inside.minY,
                    width: inside.width * CGFloat(known ? pct : 0) / 100, height: inside.height).fill()
                context.restoreGState()
            }
            badge?.draw(in: NSRect(x: 36, y: 5, width: 11, height: 11))
            for (index, text) in metrics.enumerated() {
                (text as NSString).draw(at: NSPoint(x: metricsX, y: metrics.count == 1 ? 4 : (index == 0 ? 10 : 0)),
                    withAttributes: attrs)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = ([known ? "Batterie \(pct) %" : "Lecture en cours", mode.frenchTitle] + metrics).joined(separator: ", ")
        return image
    }
}
