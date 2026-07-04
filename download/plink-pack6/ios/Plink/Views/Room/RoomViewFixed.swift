import SwiftUI

// MARK: - RoomView (Pack 6: фиксы UI багов)
// Баги которые исправлены:
// 1. Кнопка чата перекрывала сворачивание экрана → убрано перекрытие
// 2. Чат не открывался свайпом влево → добавлен swipe gesture
// 3. Кнопка "Поделиться" слишком низко в landscape → только в portrait
// 4. Непонятная иконка сверху в углу (не нажимается) → убрана
// 5. Кнопка участников перекрывалась в правом углу → перестроен layout
// 6. Чат не сворачивается свайпом вниз → добавлен swipe-down gesture

struct RoomViewFixed: View {
    @State private var chatOffset: CGFloat = 0      // 0 = closed, 1 = open
    @State private var chatIsOpen: Bool = false
    @State private var showParticipants: Bool = false
    @State private var showShareSheet: Bool = false
    
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Video background (full screen)
                Color.black.ignoresSafeArea()
                
                // Video content
                VideoContainerView()
                    .ignoresSafeArea()
                
                // Controls overlay
                VStack {
                    topBar
                    Spacer()
                    bottomControls
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                
                // Pack 6: Chat panel with swipe gestures
                ChatPanel(
                    isOpen: $chatIsOpen,
                    offset: $chatOffset,
                    maxHeight: geo.size.height * 0.6
                )
                .zIndex(10)
            }
        }
        .statusBarHidden(true)
        .sheet(isPresented: $showParticipants) {
            ParticipantListView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["Join my Plink room: AB12CD"])
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack(spacing: 12) {
            // Exit button
            Button {
                HapticManager.shared.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibleButton("Закрыть комнату")
            
            // Room info
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
            
            // Pack 6: убрана непонятная иконка сверху-справа
            
            // Participants button (Pack 6: не перекрывается)
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
            
            // Pack 6: Share button ТОЛЬКО в portrait
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
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Playback controls
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
            
            // Pack 6: Chat button НЕ перекрывает сворачивание
            // (раньше был поверх всего, теперь в нормальном layout)
            Button {
                toggleChat()
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
    
    // MARK: - Chat Toggle
    
    private func toggleChat() {
        HapticManager.shared.tap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            chatIsOpen.toggle()
            chatOffset = chatIsOpen ? 1 : 0
        }
    }
}

// MARK: - Chat Panel с swipe gestures (Pack 6)

private struct ChatPanel: View {
    @Binding var isOpen: Bool
    @Binding var offset: CGFloat
    let maxHeight: CGFloat
    
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        // Pack 6: чат закреплён справа, выезжает влево
        HStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                // Drag handle
                VStack(spacing: 4) {
                    Capsule()
                        .fill(.white.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .padding(.top, 8)
                    
                    // Header
                    HStack {
                        Text("Чат")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            closeChat()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding()
                }
                .background(Color.plinkBgSecondary.opacity(0.95))
                
                // Messages
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(0..<5) { _ in
                            ChatBubble(text: "Привет! 👋", isMe: false)
                            ChatBubble(text: "Какое классное видео!", isMe: true)
                        }
                    }
                    .padding()
                }
                
                // Input
                HStack {
                    TextField("Сообщение", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                    Button {
                        HapticManager.shared.sendMessage()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.plinkGradient, in: Circle())
                    }
                }
                .padding()
                .background(Color.plinkBgSecondary.opacity(0.95))
            }
            .frame(width: 320, height: maxHeight)
            .background(Color.plinkBgPrimary.opacity(0.97))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .offset(x: isOpen ? 0 : 320 + dragOffset, y: 0)
        }
        .ignoresSafeArea()
        // Pack 6: swipe-left чтобы открыть
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Если закрыт и свайп влево — открываем
                    if !isOpen && value.translation.width < -30 {
                        dragOffset = max(value.translation.width + 320, 0)
                    }
                    // Если открыт и свайп вправо — закрываем
                    if isOpen && value.translation.width > 0 {
                        dragOffset = min(value.translation.width, 320)
                    }
                }
                .onEnded { value in
                    if !isOpen {
                        // Открытие: достаточно сильный свайп влево
                        if value.translation.width < -50 {
                            openChat()
                        }
                    } else {
                        // Закрытие: свайп вправо ИЛИ вниз
                        if value.translation.width > 50 || value.translation.height > 50 {
                            closeChat()
                        }
                    }
                    dragOffset = 0
                }
        )
        // Pack 6: swipe-down чтобы закрыть (отдельный жест)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if isOpen && value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if isOpen && value.translation.height > 80 {
                        closeChat()
                    }
                    dragOffset = 0
                }
        )
    }
    
    private func openChat() {
        HapticManager.shared.tap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isOpen = true
            offset = 1
        }
    }
    
    private func closeChat() {
        HapticManager.shared.tap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isOpen = false
            offset = 0
        }
    }
}

// MARK: - Chat Bubble

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

// MARK: - Stubs

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
                ForEach(0..<5) { _ in
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
