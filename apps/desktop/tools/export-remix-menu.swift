// Generate native menu template images from the same Remix font used by the renderer.
import AppKit
import CoreText

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("src/renderer/assets/remix")
let fontURL = assets.appendingPathComponent("remixicon.ttf")
var registrationError: Unmanaged<CFError>?
guard CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &registrationError) else {
    fatalError("Cannot register bundled Remix font: \(String(describing: registrationError?.takeRetainedValue()))")
}
let mapping = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: root.appendingPathComponent("src/renderer/components/remix-symbols.json")))
let codepoints = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: assets.appendingPathComponent("remixicon-codepoints.json")))
let ipc = try String(contentsOf: root.appendingPathComponent("src/shared/ipc.ts"), encoding: .utf8)
let block = ipc.components(separatedBy: "export const TRAY_SYMBOLS = [")[1].components(separatedBy: "] as const")[0]
let names = block.split(separator: "\n").compactMap { line -> String? in
    let parts = line.split(separator: "'")
    return parts.count >= 2 ? String(parts[1]) : nil
}
let out = root.appendingPathComponent("resources/remix-menu")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
guard let font = NSFont(name: "remixicon", size: 16) else { fatalError("Bundled Remix font is unavailable") }

for name in names {
    guard let remix = mapping[name], let hex = codepoints[remix], let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) else {
        fatalError("Missing Remix menu mapping: \(name)")
    }
    let text = NSAttributedString(string: String(scalar), attributes: [.font: font, .foregroundColor: NSColor.black])
    for scale in [1, 2] {
        let size = NSSize(width: 16, height: 16)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 16 * scale, pixelsHigh: 16 * scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            fatalError("Cannot allocate Remix menu image")
        }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let bounds = text.boundingRect(with: NSSize(width: 32, height: 32), options: [.usesLineFragmentOrigin, .usesFontLeading])
        text.draw(at: NSPoint(x: (16 - bounds.width) / 2 - bounds.minX, y: (16 - bounds.height) / 2 - bounds.minY))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("Cannot encode Remix menu image") }
        try png.write(to: out.appendingPathComponent("\(name)\(scale == 2 ? "@2x" : "").png"))
    }
}
print("exported \(names.count) Remix menu icons at 1x and 2x")
