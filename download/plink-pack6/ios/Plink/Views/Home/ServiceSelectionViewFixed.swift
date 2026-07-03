import SwiftUI

// MARK: - ServiceSelectionView (Pack 6: выбор сервиса → сразу создание комнаты)
// Баг: при выборе YouTube открывался сам плеер YouTube
// Фикс: выбор сервиса сразу переводит к созданию комнаты (без открытия плеера)

struct ServiceSelectionViewFixed: View {
    @Binding var selectedService: VideoService?
    @Binding var isPresented: Bool
    var onContinue: ((VideoService) -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Direct streaming
                    serviceGroup(title: "Прямые потоки", services: [.youtube, .vk, .rutube])
                    
                    // Cinemas (WebView)
                    serviceGroup(title: "Кинотеатры", 
                                 services: [.kinopoisk, .ivi, .okko, .wink, .start, .premier, .smotrim, .kion])
                    
                    // Universal
                    serviceGroup(title: "Универсальные", services: [.browser, .customURL, .plex, .jellyfin, .local])
                }
                .padding()
            }
            .background(Color.plinkBgGradient)
            .navigationTitle("Выберите сервис")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { isPresented = false }
                }
            }
        }
    }
    
    @ViewBuilder
    private func serviceGroup(title: String, services: [VideoService]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.plinkTextSecondary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                ForEach(services) { service in
                    Button {
                        selectService(service)
                    } label: {
                        ServiceCard(service: service, 
                                    isSelected: selectedService == service)
                    }
                    .accessibleButton(service.displayName, hint: "Выбрать \(service.displayName)")
                }
            }
        }
    }
    
    private func selectService(_ service: VideoService) {
        HapticManager.shared.tap()
        selectedService = service
        
        // Pack 6: НЕ открывать плеер сервиса!
        // Сразу продолжить к созданию комнаты
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
            onContinue?(service)
        }
    }
}

private struct ServiceCard: View {
    let service: VideoService
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: service.iconName)
                .font(.title2)
                .foregroundStyle(service.brandColor)
                .frame(width: 44, height: 44)
                .background(service.brandColor.opacity(0.15), in: Circle())
            
            Text(service.displayName)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? service.brandColor.opacity(0.2) : Color.plinkBgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? service.brandColor : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    ServiceSelectionViewFixed(
        selectedService: .constant(nil),
        isPresented: .constant(true)
    ) { _ in
        print("Continue with service")
    }
}
