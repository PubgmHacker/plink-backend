import SwiftUI

// MARK: - RoomSetupView (Pack 6: фикс счётчика участников)
// Баг: с 10 человек если уменьшать — сразу падает на 3
// Фикс: правильная логика Stepper + отсутствие бесконечного декремента

struct RoomSetupViewFixed: View {
    @State private var maxParticipants: Int = 10
    @State private var name: String = ""
    @State private var privacy: RoomPrivacy = .publicRoom
    @State private var password: String = ""
    
    private let minParticipants = 2
    private let maxParticipantsLimit = 20  // Premium — 20, Free — 10
    private let freeLimit = 10
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Комната") {
                    TextField("Название комнаты", text: $name)
                }
                
                Section("Участники") {
                    // Pack 6: правильный Stepper с диапазоном
                    Stepper(value: $maxParticipants, in: minParticipants...maxParticipantsLimit) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.plinkPrimary)
                            Text("Максимум: \(maxParticipants)")
                            Spacer()
                            Text(freeLimitExceeded ? "Premium" : "Free")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(freeLimitExceeded ? Color.plinkRainbow : Color.gray.opacity(0.3), 
                                           in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    
                    // Pack 6: быстрый выбор через chips
                    HStack {
                        ForEach([5, 10, 15, 20], id: \.self) { count in
                            Button {
                                HapticManager.shared.selectionChanged()
                                maxParticipants = count
                            } label: {
                                Text("\(count)")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        maxParticipants == count 
                                        ? Color.plinkGradient 
                                        : Color.gray.opacity(0.2),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                
                Section("Приватность") {
                    Picker("Тип", selection: $privacy) {
                        Text("Публичная").tag(RoomPrivacy.publicRoom)
                        Text("По ссылке").tag(RoomPrivacy.byLink)
                        Text("Приватная").tag(RoomPrivacy.privateRoom)
                    }
                    
                    if privacy == .byLink || privacy == .privateRoom {
                        SecureField("Пароль (опц.)", text: $password)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.plinkBgPrimary)
            .navigationTitle("Создать комнату")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        // Create logic
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private var freeLimitExceeded: Bool {
        maxParticipants > freeLimit
    }
}

enum RoomPrivacy: String, CaseIterable {
    case publicRoom
    case byLink
    case privateRoom
}

#Preview {
    RoomSetupViewFixed()
}
