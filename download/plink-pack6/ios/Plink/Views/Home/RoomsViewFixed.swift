import SwiftUI

// MARK: - RoomsView (Pack 6: вкладка "Запросы" влезает в одну строку)
// Баг: "Запросы" отображалось как "Запрос Ы" — не помещалось
// Фикс: использовать shorter labels + .lineLimit(1) + .minimumScaleFactor

struct RoomsViewFixed: View {
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var selectedTab: Tab = .myRooms
    
    enum Tab: String, CaseIterable, Identifiable {
        case myRooms = "Мои"
        case join = "Войти"
        case requests = "Запросы"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pack 6: Compact segmented control
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue)
                            .lineLimit(1)           // ← Pack 6: запрет переноса
                            .minimumScaleFactor(0.7) // ← Pack 6: ужимается если не влезает
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                switch selectedTab {
                case .myRooms:
                    MyRoomsList()
                case .join:
                    JoinRoomView()
                case .requests:
                    RequestsList()
                }
            }
            .background(Color.plinkBgGradient)
            .navigationTitle("Комнаты")
            .onReceive(tabRouter.$roomsSubTab) { subTab in
                // Pack 6: когда из Home нажимают "Присоединиться" — переключиться на .join
                if let tab = Tab(rawValue: subTab.rawValue) {
                    withAnimation { selectedTab = tab }
                }
            }
        }
    }
}

// MARK: - Stubs

private struct MyRoomsList: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<2) { _ in
                    RoomCard(code: "AB12CD", title: "Lofi beats", participants: 5)
                }
            }
            .padding()
        }
    }
}

private struct JoinRoomView: View {
    @State private var code = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.plinkGradient)
                
                Text("Введите код комнаты")
                    .font(.headline)
                
                TextField("AB12CD", text: $code)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospaced().bold())
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .textInputAutocapitalization(.characters)
                
                Button {
                    // Join logic
                    HapticManager.shared.success()
                } label: {
                    Text("Войти")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.plinkGradient, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

private struct RequestsList: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Нет новых запросов")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
}

private struct RoomCard: View {
    let code: String
    let title: String
    let participants: Int
    
    var body: some View {
        HStack {
            Circle().fill(.plinkPrimary.opacity(0.3)).frame(width: 40, height: 40)
            VStack(alignment: .leading) {
                Text(title).font(.subheadline.bold())
                Text("\(participants) участников").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(code).font(.caption.monospaced())
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    RoomsViewFixed()
        .environmentObject(TabRouter.shared)
}
