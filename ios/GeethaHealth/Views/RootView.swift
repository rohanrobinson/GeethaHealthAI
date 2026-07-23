import SwiftUI
import SwiftData

struct RootView: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @AppStorage(AppLock.enabledKey) private var appLockEnabled = false
    @State private var isUnlocked = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appLockEnabled && !isUnlocked {
                LockScreenView { isUnlocked = true }
            } else if let profile = profiles.first {
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && appLockEnabled {
                isUnlocked = false
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Profile.self, inMemory: true)
}
