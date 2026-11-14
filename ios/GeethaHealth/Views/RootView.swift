import SwiftUI
import SwiftData

struct RootView: View {
    /// The Ask tab (AskView / SymptomAssistant) is hidden for 1.0. In November
    /// 2026 App Review asked for clinical evaluation evidence for the assistant
    /// (red-team recall/precision, external clinician review) that doesn't exist
    /// yet. The code stays so the tab can return once that evidence does.
    static let showsAskTab = false

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
                    if Self.showsAskTab {
                        AskView(profile: profile)
                            .tabItem { Label("Ask", systemImage: "sparkles") }
                    }
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
