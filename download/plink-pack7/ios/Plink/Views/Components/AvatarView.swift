import SwiftUI

// MARK: - AvatarView (Pack 7.1: обводка только у Premium и Admin)
// Баг: у всех юзеров была обводка аватара
// Фикс: обводка только у Premium (Gold) и Admin (Red)

struct AvatarView: View {
    let imageURL: String?
    let username: String
    let size: CGFloat
    let isPremium: Bool
    let role: UserRole
    
    var body: some View {
        ZStack {
            // Pack 7.1: обводка ТОЛЬКО для Premium и Admin
            if shouldShowRing {
                Circle()
                    .stroke(borderGradient, lineWidth: 3)
                    .frame(width: size + 6, height: size + 6)
            }
            
            // Сама аватарка
            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholderAvatar
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                placeholderAvatar
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
            
            // Pack 7.1: иконка Premium/Admin внизу справа
            if shouldShowBadge {
                badge
            }
        }
    }
    
    // MARK: - Helpers
    
    private var shouldShowRing: Bool {
        isPremium || role == .admin || role == .founder
    }
    
    private var shouldShowBadge: Bool {
        isPremium || role == .admin || role == .founder
    }
    
    private var borderGradient: LinearGradient {
        if isPremium {
            // Premium — Gold gradient
            return Color.plinkPremiumGradient
        } else if role == .admin || role == .founder {
            // Admin — Red gradient
            return LinearGradient(
                colors: [.plinkNotifications, .plinkError],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return Color.plinkGradient
    }
    
    private var badge: some View {
        Group {
            if isPremium {
                // Premium — коронка
                Image(systemName: "crown.fill")
                    .font(.system(size: size * 0.20))
                    .foregroundStyle(.white)
                    .padding(size * 0.08)
                    .background(Color.plinkPremiumGradient, in: Circle())
            } else if role == .admin || role == .founder {
                // Admin — щит
                Image(systemName: "shield.fill")
                    .font(.system(size: size * 0.20))
                    .foregroundStyle(.white)
                    .padding(size * 0.08)
                    .background(Color.plinkError, in: Circle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .offset(x: -2, y: 2)
    }
    
    private var placeholderAvatar: some View {
        ZStack {
            Circle().fill(Color.plinkGradient)
            Text(String(username.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - UserRole (если ещё не определён в проекте)

enum UserRole: String, Codable, Sendable {
    case user = "USER"
    case moderator = "MODERATOR"
    case admin = "ADMIN"
    case founder = "FOUNDER"
}

// MARK: - Preview

#Preview("Default User (no ring)") {
    AvatarView(
        imageURL: nil,
        username: "Alexander",
        size: 96,
        isPremium: false,
        role: .user
    )
    .padding()
    .background(Color.plinkBgPrimary)
}

#Preview("Premium User (Gold ring + crown)") {
    AvatarView(
        imageURL: nil,
        username: "Premium",
        size: 96,
        isPremium: true,
        role: .user
    )
    .padding()
    .background(Color.plinkBgPrimary)
}

#Preview("Admin (Red ring + shield)") {
    AvatarView(
        imageURL: nil,
        username: "Admin",
        size: 96,
        isPremium: false,
        role: .admin
    )
    .padding()
    .background(Color.plinkBgPrimary)
}
