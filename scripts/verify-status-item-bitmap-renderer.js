#!/usr/bin/env node
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const source = path.join(repoRoot, "Sources", "StatusItemBitmapRenderer.swift");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "codex-status-bitmap-"));
const verifier = path.join(tmp, "VerifyStatusItemBitmapRenderer.swift");
const binary = path.join(tmp, "verify-status-item-bitmap-renderer");

function fail(message) {
  console.error(`FAIL ${message}`);
  process.exit(1);
}

try {
  if (!fs.existsSync(source)) {
    fail("StatusItemBitmapRenderer.swift is missing");
  }

  fs.writeFileSync(verifier, `
import AppKit

func require(_ condition: @autoclosure () -> Bool, _ label: String) {
    if !condition() {
        fputs("FAIL \\(label)\\n", stderr)
        exit(1)
    }
}

func opaquePixelCount(in representation: NSBitmapImageRep, pointRect: NSRect) -> Int {
    let scale = CGFloat(representation.pixelsWide) / representation.size.width
    let minX = max(0, Int(floor(pointRect.minX * scale)))
    let maxX = min(representation.pixelsWide, Int(ceil(pointRect.maxX * scale)))
    let minY = max(0, Int(floor(pointRect.minY * scale)))
    let maxY = min(representation.pixelsHigh, Int(ceil(pointRect.maxY * scale)))
    var count = 0
    for y in minY..<maxY {
        for x in minX..<maxX where representation.colorAt(x: x, y: y)?.alphaComponent ?? 0 > 0.01 {
            count += 1
        }
    }
    return count
}

@main
struct VerifyStatusItemBitmapRenderer {
    static func main() {
        let icon = NSImage(size: NSSize(width: 18, height: 18))
        icon.lockFocus()
        NSColor.systemGreen.setFill()
        NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 16, height: 16)).fill()
        icon.unlockFocus()

        let content = StatusItemBitmapContent(
            size: NSSize(width: 140, height: 22),
            icon: icon,
            iconRect: NSRect(x: 1, y: 2, width: 18, height: 18),
            label: "Thinking",
            labelRect: NSRect(x: 21, y: 0, width: 72, height: 22),
            timer: "12s",
            timerRect: NSRect(x: 96, y: 0, width: 43, height: 22),
            font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular),
            textColor: .labelColor
        )
        let renderer = StatusItemBitmapRenderer()
        let first = renderer.image(cacheKey: "active|thinking|12s", content: content)
        let cached = renderer.image(cacheKey: "active|thinking|12s", content: content)

        require(first === cached, "renderer reuses the current rasterized image")
        require(first.size == content.size, "image preserves point dimensions")

        let bitmapRepresentations = first.representations.compactMap { $0 as? NSBitmapImageRep }
        require(bitmapRepresentations.count == 2, "image has 1x and 2x bitmap representations")
        require(bitmapRepresentations.contains { $0.pixelsWide == 140 && $0.pixelsHigh == 22 }, "image has a 1x representation")
        require(bitmapRepresentations.contains { $0.pixelsWide == 280 && $0.pixelsHigh == 44 }, "image has a 2x representation")

        guard let retina = bitmapRepresentations.first(where: { $0.pixelsWide == 280 }) else {
            fputs("FAIL missing retina representation\\n", stderr)
            exit(1)
        }
        require(opaquePixelCount(in: retina, pointRect: content.iconRect) > 0, "icon pixels are rasterized")
        require(opaquePixelCount(in: retina, pointRect: content.labelRect) > 0, "label pixels are rasterized")
        require(opaquePixelCount(in: retina, pointRect: content.timerRect) > 0, "timer pixels are rasterized")

        print("PASS status item bitmap renderer")
    }
}
`);

  cp.execFileSync("/usr/bin/swiftc", [source, verifier, "-o", binary, "-framework", "Cocoa"], {
    stdio: "inherit",
  });
  cp.execFileSync(binary, [], { stdio: "inherit" });
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
