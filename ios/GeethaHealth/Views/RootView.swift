import SwiftUI
import SwiftData

struct RootView: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]

    var body: some View {
        if let profile = profiles.first {
            TabView {
                RecordsHomeView(profile: profile)
                    .tabItem { Label("Records", systemImage: "heart.text.square") }
                DocumentsView(profile: profile)
                    .tabItem { Label("Documents", systemImage: "doc.on.doc") }
                ProfileView(profile: profile)
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            }
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Profile.self, inMemory: true)
}
