import AppKit
// Génère assets/icon.icns : coffret d'archive (couvercle + fermeture éclair) sur fond sombre Socle.
let size = 1024.0
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let bg = NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 215, yRadius: 215)
NSColor(calibratedWhite: 0.13, alpha: 1).setFill(); bg.fill()
let blue = NSColor(calibratedRed: 0.22, green: 0.74, blue: 0.97, alpha: 1)
let light = NSColor(calibratedWhite: 0.93, alpha: 1)
light.setFill()
NSBezierPath(roundedRect: NSRect(x: 212, y: 250, width: 600, height: 330), xRadius: 40, yRadius: 40).fill()   // caisse
NSBezierPath(roundedRect: NSRect(x: 172, y: 560, width: 680, height: 170), xRadius: 40, yRadius: 40).fill()   // couvercle
NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 412, y: 604, width: 200, height: 46), xRadius: 23, yRadius: 23).fill()   // poignée
blue.setFill()
for i in 0..<6 {   // fermeture éclair
    let y = 250.0 + Double(i) * 54
    NSBezierPath(rect: NSRect(x: i % 2 == 0 ? 488 : 520, y: y, width: 16, height: 36)).fill()
}
NSBezierPath(roundedRect: NSRect(x: 478, y: 250 + 5 * 54 - 10, width: 68, height: 70), xRadius: 14, yRadius: 14).fill()
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
