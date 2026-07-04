import SwiftUI

// MARK: - MainTabView (Pack 7.1: ИИ по центру)
// Изменение: ИИ перемещён на 3-ю позицию (в центр таббара)
// Порядок: Главная → Комнаты → ИИ → Друзья → Настройки

@MainActor
final class TabRouter: ObservableObject {
    static let shared = TabRouter()
    
    enum Tab: Int, CaseIterable, Identifiable {
        case home = 0
        case rooms = 1
        case ai = 2          // ← Pack 7.1: ИИ по центру
        case friends = 3
        case settings = 4
        
        var id: Int { rawValue }
        
        var title: String {
            switch self {
            case .home: return "Главная"
            case .rooms: return "Комнаты"
            case .ai: return "ИИ"
            case .friends: return "Друзья"
            case .settings: return "Настройки"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .rooms: return "tv.fill"
            case .ai: return "sparkles"
            case .friends: return "person.2.fill"
            case .settings: return "gearshape.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .home: return .plinkPrimary
            case .rooms: return .plinkRooms
            case .ai: return .plinkAI
            case .friends: return .plinkFriends
            case .settings: return .plinkSettings
            }
        }
    }
    
    @Published var selectedTab: Tab = .home
    @Published var roomsSubTab: RoomsSubTab = .myRooms
    
    enum RoomsSubTab: String, CaseIterable {
        case myRooms = "Мои"
        case join = "Войти"
        case requests = "Запросы"
    }
    
    func switchToJoinRoom() {
        selectedTab = .rooms
        roomsSubTab = .join
    }
    
    func switchToCreateRoom() {
        selectedTab = .rooms
        roomsSubTab = .myRooms
    }
}

struct MainTabViewFixed: View {
    @StateObject private var router = TabRouter.shared
    
    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeViewFixed()
                .tabItem {
                    Label(TabRouter.Tab.home.title, systemImage: TabRouter.Tab.home.icon)
                }
                .tag(TabRouter.Tab.home)
            
            RoomsViewFixed()
                .tabItem {
                    Label(TabRouter.Tab.rooms.title, systemImage: TabRouter.Tab.rooms.icon)
                }
                .tag(TabRouter.Tab.rooms)
            
            // Pack 7.1: ИИ по центру (3-я позиция)
            AIAssistantView()
                .tabItem {
                    Label(TabRouter.Tab.ai.title, systemImage: TabRouter.Tab.ai.icon)
                }
                .tag(TabRouter.Tab.ai)
            
            FriendsViewFixed()
                .tabItem {
                    Label(TabRouter.Tab.friends.title, systemImage: TabRouter.Tab.friends.icon)
                }
                .tag(TabRouter.Tab.friends)
            
            SettingsViewFixed()
                .tabItem {
                    Label(TabRouter.Tab.settings.title, systemImage: TabRouter.Tab.settings.icon)
                }
                .tag(TabRouter.Tab.settings)
        }
        .tint(.plinkPrimary)
        .onChange(of: router.selectedTab) { _, _ in
            HapticManager.shared.selectionChanged()
        }
    }
}

#Preview {
    MainTabViewFixed()
}
