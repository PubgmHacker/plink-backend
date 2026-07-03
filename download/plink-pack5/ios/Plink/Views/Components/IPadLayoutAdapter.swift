import SwiftUI

// MARK: - iPadLayoutAdapter (Pack 5: iPad-optimized layouts)
/// Адаптер для iPad-специфичных layout'ов

struct IPadLayoutAdapter<Content: View>: View {
    let content: Content
    @Environment(\.horizontalSizeClass) private var hSizeClass
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if hSizeClass == .regular {
            // iPad
            content
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
        } else {
            // iPhone
            content
        }
    }
}

// MARK: - Split View для iPad

struct IPadSplitView<Sidebar: View, Detail: View>: View {
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let detail: () -> Detail
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebar()
            } detail: {
                detail()
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            detail()
        }
    }
}

// MARK: - Room View (iPad vs iPhone)

struct AdaptiveRoomLayout<Content: View>: View {
    let content: Content
    @Environment(\.horizontalSizeClass) private var hSizeClass
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if hSizeClass == .regular {
            // iPad: video налево, chat + participants направо
            HStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity)
                
                // Right sidebar: chat + participants
                VStack(spacing: 0) {
                    ChatSidebar()
                    ParticipantsSidebar()
                }
                .frame(width: 360)
                .background(.regularMaterial)
            }
        } else {
            // iPhone: video fullscreen, chat как overlay
            content
        }
    }
}

// MARK: - Stubs (replace with real views)

private struct ChatSidebar: View {
    var body: some View {
        VStack {
            Text("Chat")
                .font(.headline)
                .padding()
            Spacer()
        }
    }
}

private struct ParticipantsSidebar: View {
    var body: some View {
        VStack {
            Text("Participants")
                .font(.headline)
                .padding()
            Spacer()
        }
    }
}

// MARK: - Adaptive Grid

struct AdaptiveGrid<Content: View>: View {
    let content: Content
    @Environment(\.horizontalSizeClass) private var hSizeClass
    
    let minItemWidth: CGFloat
    
    init(minItemWidth: CGFloat = 200, @ViewBuilder content: () -> Content) {
        self.minItemWidth = minItemWidth
        self.content = content()
    }
    
    var body: some View {
        let columns = hSizeClass == .regular
            ? [GridItem(.adaptive(minimum: minItemWidth), spacing: 16)]
            : [GridItem(.adaptive(minimum: minItemWidth - 40), spacing: 12)]
        
        LazyVGrid(columns: columns, spacing: hSizeClass == .regular ? 16 : 12) {
            content
        }
    }
}
