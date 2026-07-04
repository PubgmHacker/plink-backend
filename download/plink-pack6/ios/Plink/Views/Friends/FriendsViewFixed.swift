import SwiftUI

// MARK: - FriendsView (Pack 6: фикс позиции иконок и заголовка)
// Баг: иконки "Добавить друга" и "Запросы" были слишком высоко
// Фикс:
//   - Иконки опущены ниже
//   - Заголовок "Друзья" с количеством отображается правильно
//   - Правильные отступы

struct FriendsViewFixed: View {
    @State private var selectedTab: FriendsTab = .friends
    @State private var showAddFriend = false
    @State private var showRequests = false
    
    enum FriendsTab: String, CaseIterable, Identifiable {
        case friends = "Друзья"
        case requests = "Запросы"
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                
                actionsRow
                    .padding(.bottom, 16)
                
                Picker("", selection: $selectedTab) {
                    ForEach(FriendsTab.allCases) { tab in
                        Text(tab.rawValue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                if selectedTab == .friends {
                    friendsList
                } else {
                    requestsList
                }
            }
            .background(Color.plinkBgGradient)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddFriend) { AddFriendView() }
            .sheet(isPresented: $showRequests) { RequestsListView() }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Друзья").font(.largeTitle.bold()).foregroundStyle(.plinkTextPrimary)
                Text("12 друзей").font(.subheadline).foregroundStyle(.plinkTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var actionsRow: some View {
        HStack(spacing: 12) {
            Button {
                showAddFriend = true
                HapticManager.shared.tap()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.plinkGradient, in: Circle())
                        .foregroundStyle(.white)
                    Text("Добавить").font(.caption.bold()).foregroundStyle(.plinkTextPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            .accessibleButton("Добавить друга")
            
            Button {
                showRequests = true
                HapticManager.shared.tap()
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        Image(systemName: "envelope.fill")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Color.plinkWarmGradient, in: Circle())
                            .foregroundStyle(.white)
                        Text("3").font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.plinkError, in: Capsule())
                            .foregroundStyle(.white)
                            .offset(x: 14, y: -14)
                    }
                    Text("Запросы").font(.caption.bold()).foregroundStyle(.plinkTextPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            .accessibleButton("Запросы в друзья")
        }
        .padding(.horizontal)
    }
    
    private var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<8, id: \.self) { _ in
                    FriendRow(name: "Friend name", isOnline: true)
                }
            }
            .padding()
        }
    }
    
    private var requestsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    RequestRow(name: "Requester name")
                }
            }
            .padding()
        }
    }
}

private struct FriendRow: View {
    let name: String
    let isOnline: Bool
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle().fill(Color.plinkGradient).frame(width: 44, height: 44)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.white))
                Circle().fill(isOnline ? .plinkSuccess : .gray)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.plinkBgPrimary, lineWidth: 2))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.bold())
                Text(isOnline ? "В сети" : "Не в сети").font(.caption).foregroundStyle(.plinkTextSecondary)
            }
            Spacer()
            Button { HapticManager.shared.tap() } label: {
                Image(systemName: "message.fill")
                    .padding(8).background(Color.plinkBgTertiary, in: Circle())
                    .foregroundStyle(.plinkTextPrimary)
            }
        }
        .padding().background(Color.plinkBgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct RequestRow: View {
    let name: String
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.plinkWarmGradient).frame(width: 44, height: 44)
                .overlay(Image(systemName: "person.fill").foregroundStyle(.white))
            Text(name).font(.subheadline.bold())
            Spacer()
            Button { HapticManager.shared.success() } label: {
                Image(systemName: "checkmark")
                    .padding(8).background(Color.plinkSuccess, in: Circle()).foregroundStyle(.white)
            }
            Button { HapticManager.shared.error() } label: {
                Image(systemName: "xmark")
                    .padding(8).background(Color.plinkError, in: Circle()).foregroundStyle(.white)
            }
        }
        .padding().background(Color.plinkBgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Поиск по имени", text: $search).textFieldStyle(.roundedBorder).padding()
                Spacer()
                Text("Введите имя друга").foregroundStyle(.secondary)
                Spacer()
            }
            .navigationTitle("Добавить друга").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
        }
    }
}

private struct RequestsListView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<3, id: \.self) { _ in
                    HStack {
                        Circle().fill(.plinkSecondary.opacity(0.3)).frame(width: 40, height: 40)
                        Text("User name")
                    }
                }
            }
            .navigationTitle("Запросы").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } }
            }
        }
    }
}

#Preview {
    FriendsViewFixed()
}
