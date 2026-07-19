//
//  RenderShot.swift
//  Sysline
//
//  DEBUG-only: `Sysline --shot <path>` renders the popover offscreen to a PNG
//  and exits. Lets us preview the UI without screen-recording permission.
//  ponytail: throwaway dev aid — delete once the design is settled.
//

#if DEBUG
import SwiftUI
import AppKit

enum RenderShot {
    static func runIfRequested() {
        guard let i = CommandLine.arguments.firstIndex(of: "--shot") else { return }
        let path = CommandLine.arguments.count > i + 1
            ? CommandLine.arguments[i + 1]
            : NSTemporaryDirectory() + "sysline_shot.png"

        MainActor.assumeIsolated {
            let view = NetworkView()
                .frame(width: 340)
                .background(Color(nsColor: .windowBackgroundColor))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            if let img = renderer.nsImage,
               let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
                FileHandle.standardOutput.write(Data("shot:\(path)\n".utf8))
            }
        }
        exit(0)
    }
}
#endif
