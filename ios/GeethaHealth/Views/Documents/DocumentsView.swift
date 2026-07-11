import SwiftUI

// Placeholder until M3 (scan/photo/PDF import).
struct DocumentsView: View {
    var profile: Profile

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No documents yet",
                systemImage: "doc.on.doc",
                description: Text("Scanning and importing medical documents is coming soon.")
            )
            .navigationTitle("Documents")
        }
    }
}
