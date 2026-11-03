import AppKit

// Lays screenshots out three to a landscape page, each with its caption below,
// for attaching to an App Review reply as a single file.
//
//   swift make-pdf.swift <out.pdf> <captions.txt> <shot.png>...
//
// captions.txt holds one caption per line, in the same order as the shots.

let args = CommandLine.arguments
guard args.count > 3 else {
    print("usage: swift make-pdf.swift <out.pdf> <captions.txt> <shot.png>...")
    exit(1)
}
let captions = try String(contentsOfFile: args[2], encoding: .utf8)
    .split(separator: "\n").map(String.init)
let shots = Array(args.dropFirst(3))
guard captions.count == shots.count else {
    print("\(captions.count) captions for \(shots.count) screenshots")
    exit(1)
}

var page = CGRect(x: 0, y: 0, width: 1650, height: 1275)
let context = CGContext(URL(fileURLWithPath: args[1]) as CFURL, mediaBox: &page, nil)!
let shotHeight: CGFloat = 960, gap: CGFloat = 90
let pages = stride(from: 0, to: shots.count, by: 3).map { Array($0..<min($0 + 3, shots.count)) }

for (number, indices) in pages.enumerated() {
    context.beginPDFPage(nil)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    let images = indices.map { NSImage(contentsOfFile: shots[$0])! }
    let shotWidth = shotHeight * images[0].size.width / images[0].size.height
    let left = (page.width - 3 * shotWidth - 2 * gap) / 2

    let title = "Geetha Health: Clinical Health Records permission flow (page \(number + 1) of \(pages.count))"
    (title as NSString).draw(at: NSPoint(x: left, y: page.height - 70),
                             withAttributes: [.font: NSFont.boldSystemFont(ofSize: 26)])
    for (column, index) in indices.enumerated() {
        let frame = NSRect(x: left + CGFloat(column) * (shotWidth + gap),
                           y: page.height - 110 - shotHeight, width: shotWidth, height: shotHeight)
        images[column].draw(in: frame)
        NSColor.lightGray.setStroke()
        NSBezierPath(rect: frame).stroke()
        (captions[index] as NSString).draw(
            in: NSRect(x: frame.minX, y: 20, width: shotWidth, height: frame.minY - 32),
            withAttributes: [.font: NSFont.systemFont(ofSize: 17)])
    }
    NSGraphicsContext.current = nil
    context.endPDFPage()
}
context.closePDF()
