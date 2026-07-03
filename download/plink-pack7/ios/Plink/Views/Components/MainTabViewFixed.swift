import SwiftUI

// MARK: - MainTabView (Pack 7: Settings как отдельная вкладка)
// Баг: Settings открывались выдвижным окном
// Фикс: Settings — отдельная 5-я вкладка в таббаре
// + исправлены двойные нажатия (через @State вместо @EnvironmentObject)

@MainActor
final class TabRouter: ObservableObject {
    static let shared = TabRouter()
    
    enum Tab: Int, CaseIterable, Identifiable {
        case home = 0
        case rooms = 1
        case friends = 2
        case ai = 3
        case settings = 4
        
        var id: Int { rawValue }
        
        var title: String {
            switch self {
            case .home: return "Главная"
            case .rooms: return "Комнаты"
            case .friends: return "Друзья"
            case .ai: return "ИИ"
            case .settings: return "Настройки"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .rooms: return "tv.fill"
            case .friends: return "person.2.fill"
            case .ai: return "sparkles"
            case .settings: return "gearshape.fill"
            }
        }
        
        // Pack 7: каждый таб — свой цвет
        var color: Color {
            switch self {
            case .home: return .plinkPrimary
            case .rooms: return .plinkRooms
            case .friends: return .plinkFriends
            case .ai: return .plinkAI
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
            
            FriendsViewFixed()
                .tabItem {
                    Label(TabRouter.Tab.friends.title, systemImage: TabRouter.Tab.friends.icon)
                }
                .tag(TabRouter.Tab.friends)
            
            AIAssistantView()
                .tabItem {
                    Label(TabRouter.Tab.ai.title, systemImage: TabRouter.Tab.ai.icon)
                }
                .tag(TabRouter.Tab.ai)
            
            // Pack 7: Settings — отдельная вкладка
            SettingsViewFixed()
                .tabItem {
                    Label(TabRouter.Tab.settings.title, systemImage: TabRouter.Tab.settings.icon)
                }
                .tag(TabRouter.Tab.settings)
        }
        .tint(.plinkPrimary)
        // Pack 7: каждый таб подсвечивается своим цветом
        .onChange(of: router.selectedTab) { _, newTab in
            // Можно динамически менять tint, но SwiftUI использует tint для всех сразу
            // Поэтому используем .tint(.plinkPrimary) — фиолетовый, brand color
            HapticManager.shared.selectionChanged()
        }
    }
}

#Preview {
    MainTabViewFixed()
}
