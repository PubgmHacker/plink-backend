import SwiftUI

// MARK: - AIAssistantView (Pack 6: AI Assistant UI)

@MainActor
final class AIViewModel: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var input: String = ""
    @Published var isLoading = false
    @Published var error: String?
    
    private let api = APIClient.shared
    
    func send() async {
        let userMsg = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMsg.isEmpty else { return }
        
        messages.append(AIMessage(role: .user, content: userMsg))
        input = ""
        isLoading = true
        error = nil
        
        let apiMessages = messages.suffix(10).map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        }
        
        do {
            let response = try await api.post("/ai/chat", body: [
                "messages": apiMessages,
                "mode": "general",
            ])
            
            let aiContent = response["message"] as? String ?? "Извините, не удалось получить ответ."
            messages.append(AIMessage(role: .assistant, content: aiContent))
            HapticManager.shared.success()
        } catch {
            self.error = error.localizedDescription
            HapticManager.shared.error()
        }
        
        isLoading = false
    }
    
    func clear() {
        messages.removeAll()
        error = nil
    }
}

struct AIMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    
    enum Role: String {
        case user
        case assistant
    }
}

struct AIAssistantView: View {
    @StateObject private var viewModel = AIViewModel()
    @FocusState private var inputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                        
                        if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                    .background(Color.plinkBgSecondary, in: RoundedRectangle(cornerRadius: 12))
                                Spacer()
                            }
                        }
                        
                        if let error = viewModel.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.plinkError)
                                .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                TextField("Спросите что-нибудь...", text: $viewModel.input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await viewModel.send() }
                    }
                
                Button {
                    Task { await viewModel.send() }
                    inputFocused = true
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            viewModel.input.isEmpty 
                            ? Color.gray.opacity(0.3) 
                            : Color.plinkGradient,
                            in: Circle()
                        )
                }
                .disabled(viewModel.input.isEmpty || viewModel.isLoading)
            }
            .padding()
            .background(Color.plinkBgSecondary.opacity(0.95))
        }
        .background(Color.plinkBgGradient)
        .navigationTitle("ИИ Помощник")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(viewModel.messages.isEmpty)
            }
        }
    }
}

private struct MessageBubble: View {
    let message: AIMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .assistant {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.plinkGradient)
                            .font(.caption)
                        Text("Plink AI")
                            .font(.caption.bold())
                            .foregroundStyle(.plinkTextSecondary)
                    }
                }
                
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user 
                        ? Color.plinkGradient 
                        : Color.plinkBgTertiary,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
            }
            
            if message.role == .assistant { Spacer() }
        }
    }
}

#Preview {
    NavigationStack {
        AIAssistantView()
    }
}
