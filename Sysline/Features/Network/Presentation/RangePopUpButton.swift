import SwiftUI
import AppKit

// The main window's compact range dropdown. An AppKit pop-up rather than a
// SwiftUI Picker/Menu because the toolbar hosts SwiftUI-drawn menu controls
// in views it gives almost no width — their labels collapse to a bare arrow.
// NSPopUpButton draws its own title ("Today", "7 Days", …) and sizes itself.
struct RangePopUpButton: NSViewRepresentable {
    @Binding var selection: DateRange

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.addItems(withTitles: DateRange.allCases.map(\.rawValue))
        button.target = context.coordinator
        button.action = #selector(Coordinator.changed(_:))
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        button.selectItem(withTitle: selection.rawValue)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        let parent: RangePopUpButton
        init(_ parent: RangePopUpButton) { self.parent = parent }

        @objc func changed(_ sender: NSPopUpButton) {
            if let title = sender.selectedItem?.title,
               let value = DateRange(rawValue: title) {
                parent.selection = value
            }
        }
    }
}
