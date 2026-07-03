import SwiftUI

// MARK: - RoomView (Pack 7.2: Telegram-style chat bottom sheet)
// Баги исправлены:
// 1. Чат — bottom sheet (снизу), Telegram-style
// 2. Свайп вниз из любого места чата закрывает его
// 3. Кнопка чата не перекрывает сворачивание видео
// 4. Share только в portrait
// 5. Убрана непонятная иконка сверху
// 6. Кнопка участников не перекрывается

struct RoomViewFixed: View {
    @State private var showChat: Bool = false
    @State private var showParticipants: Bool = false
    @State private var showShareSheet: Bool = false
    
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VideoContainerView()
                    .ignoresSafeArea()
                
                VStack {
                    topBar
                    Spacer()
                    bottomControls
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .statusBarHidden(true)
        .sheet(isPresented: $showChat) {
            ChatBottomSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.thinMaterial)
        }
        .sheet(isPresented: $showParticipants) {
            ParticipantListView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["Join my Plink room: AB12CD"])
        }
    }
    
    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                HapticManager.shared.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibleButton("Закрыть комнату")
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Lofi beats 🎵")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("5 участников")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            
            Button {
                HapticManager.shared.tap()
                showParticipants = true
            } label: {
                Image(systemName: "person.2.fill")
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibleButton("Участники")
            
            if hSizeClass == .compact {
                Button {
                    HapticManager.shared.tap()
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .accessibleButton("Поделиться")
            }
        }
    }
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 32) {
                Button {
                    HapticManager.shared.seek()
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .accessibleButton("Назад 10 секунд")
                
                Button {
                    HapticManager.shared.playToggle()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(.white.opacity(0.15), in: Circle())
                }
                .accessibleButton("Воспроизведение")
                
                Button {
                    HapticManager.shared.seek()
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .accessibleButton("Вперёд 10 секунд")
            }
            
            Button {
                HapticManager.shared.tap()
                showChat = true
            } label: {
                Label("Чат", systemImage: "message.fill")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.5), in: Capsule())
                    .foregroundStyle(.white)
            }
            .accessibleButton("Открыть чат")
        }
    }
}

// MARK: - Chat Bottom Sheet (Telegram-style)

private struct ChatBottomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input: String = ""
    @FocusState private var inputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Чат").font(.headline)
                Spacer()
                Button {
                    HapticManager.shared.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(0..<8, id: \.self) { i in
                            ChatBubble(text: "Message #\(i)", isMe: i % 2 == 0)
                        }
                    }
                    .padding()
                }
            }
            
            HStack(spacing: 12) {
                TextField("Сообщение", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                
                Button {
                    HapticManager.shared.sendMessage()
                    input = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.plinkGradient, in: Circle())
                }
                .disabled(input.isEmpty)
            }
            .padding()
            .background(.thinMaterial)
        }
    }
}

private struct ChatBubble: View {
    let text: String
    let isMe: Bool
    
    var body: some View {
        HStack {
            if isMe { Spacer() }
            Text(text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isMe ? Color.plinkGradient : Color.white.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .foregroundStyle(.white)
            if !isMe { Spacer() }
        }
    }
}

private struct VideoContainerView: View {
    var body: some View {
        Color.black
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.3))
            )
    }
}

private struct ParticipantListView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<5, id: \.self) { _ in
                    HStack {
                        Circle().fill(.plinkPrimary.opacity(0.3)).frame(width: 40, height: 40)
                        VStack(alignment: .leading) {
                            Text("User name").font(.subheadline.bold())
                            Text("Хост").font(.caption).foregroundStyle(.plinkAccent)
                        }
                    }
                }
            }
            .navigationTitle("Участники")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    RoomViewFixed()
}
