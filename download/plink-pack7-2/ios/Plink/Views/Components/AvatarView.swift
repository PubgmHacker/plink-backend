import SwiftUI

// MARK: - AvatarView (Pack 7.2: строгая Premium обводка)
// Premium — Deep Gold gradient (дорогой, не "кричащий")
// Admin/Founder — Crimson gradient (властный)

struct AvatarView: View {
    let imageURL: String?
    let username: String
    let size: CGFloat
    let isPremium: Bool
    let role: UserRole
    
    var body: some View {
        ZStack {
            // Pack 7.2: обводка только для Premium и Admin/Founder
            if shouldShowRing {
                Circle()
                    .stroke(borderGradient, lineWidth: ringWidth)
                    .frame(width: size + ringWidth * 2, height: size + ringWidth * 2)
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
            
            // Pack 7.2: тонкий бейдж внизу справа (для Premium/Admin)
            if shouldShowBadge {
                badge
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: -2, y: 2)
            }
        }
    }
    
    private var shouldShowRing: Bool {
        isPremium || role == .admin || role == .founder
    }
    
    private var shouldShowBadge: Bool {
        isPremium || role == .admin || role == .founder
    }
    
    private var ringWidth: CGFloat {
        max(2, size * 0.04)
    }
    
    private var borderGradient: LinearGradient {
        if isPremium {
            // Pack 7.2: строгий Deep Gold gradient
            return LinearGradient(
                colors: [
                    Color(red: 0.831, green: 0.686, blue: 0.216),  // Deep Gold
                    Color(red: 0.620, green: 0.482, blue: 0.137),  // Darker Gold
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Admin/Founder — Crimson
            return LinearGradient(
                colors: [
                    Color(red: 0.863, green: 0.149, blue: 0.149),  // Crimson
                    Color(red: 0.620, green: 0.090, blue: 0.090),  // Dark Crimson
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var badge: some View {
        Group {
            if isPremium {
                // Premium — коронка на Onyx background с gold border
                ZStack {
                    Circle()
                        .fill(Color.plinkOnyx)
                    Circle()
                        .stroke(Color.plinkPremiumGold, lineWidth: 1)
                    Image(systemName: "crown.fill")
                        .font(.system(size: size * 0.18, weight: .semibold))
                        .foregroundStyle(Color.plinkPremiumGold)
                }
                .frame(width: size * 0.35, height: size * 0.35)
            } else if role == .admin || role == .founder {
                // Admin — щит на Onyx с crimson border
                ZStack {
                    Circle()
                        .fill(Color.plinkOnyx)
                    Circle()
                        .stroke(Color.plinkNotifications, lineWidth: 1)
                    Image(systemName: "shield.fill")
                        .font(.system(size: size * 0.18, weight: .semibold))
                        .foregroundStyle(Color.plinkNotifications)
                }
                .frame(width: size * 0.35, height: size * 0.35)
            }
        }
    }
    
    private var placeholderAvatar: some View {
        ZStack {
            // Pack 7.2: тонкий gradient вместо яркого
            Circle().fill(
                LinearGradient(
                    colors: [
                        Color.plinkPrimary.opacity(0.7),
                        Color.plinkRooms.opacity(0.5),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            Text(String(username.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

enum UserRole: String, Codable, Sendable {
    case user = "USER"
    case moderator = "MODERATOR"
    case admin = "ADMIN"
    case founder = "FOUNDER"
}

#Preview("Default User (no ring)") {
    AvatarView(imageURL: nil, username: "Alex", size: 96, isPremium: false, role: .user)
        .padding().background(Color.plinkBgPrimary)
}

#Preview("Premium (Deep Gold)") {
    AvatarView(imageURL: nil, username: "Premium", size: 96, isPremium: true, role: .user)
        .padding().background(Color.plinkBgPrimary)
}

#Preview("Admin (Crimson)") {
    AvatarView(imageURL: nil, username: "Admin", size: 96, isPremium: false, role: .admin)
        .padding().background(Color.plinkBgPrimary)
}
