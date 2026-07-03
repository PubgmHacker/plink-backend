import SwiftUI

// MARK: - ReferralView (Pack 5: Referral program UI)

struct ReferralView: View {
    @State private var referralCode: String = ""
    @State private var shareUrl: String = ""
    @State private var stats: ReferralStats?
    @State private var isLoading = false
    @State private var showShareSheet = false
    @State private var copiedCode = false
    
    private let api = APIClient.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    heroSection
                    codeSection
                    if let stats = stats {
                        statsSection(stats)
                        referralsList(stats.referrals)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Invite Friends")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareUrl])
        }
    }
    
    // MARK: - Hero
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "gift.fill")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(
                    colors: [.purple, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text("Get 7 Days Free")
                .font(.title2.bold())
            
            Text("For every friend who joins Plink using your code, both of you get 7 days of Premium free!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    // MARK: - Code Section
    
    private var codeSection: some View {
        VStack(spacing: 16) {
            // Code card
            VStack(spacing: 8) {
                Text("Your Referral Code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(referralCode)
                    .font(.system(.title2, design: .monospaced).bold())
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                Button {
                    UIPasteboard.general.string = referralCode
                    HapticManager.shared.success()
                    withAnimation { copiedCode = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copiedCode = false }
                    }
                } label: {
                    Label(copiedCode ? "Copied!" : "Copy Code", 
                          systemImage: copiedCode ? "checkmark" : "doc.on.doc")
                        .font(.headline)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            // Share button
            Button {
                showShareSheet = true
                HapticManager.shared.tap()
            } label: {
                Label("Share with Friends", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Stats Section
    
    private func statsSection(_ stats: ReferralStats) -> some View {
        VStack(spacing: 16) {
            HStack {
                statCard(title: "Friends Invited", value: "\(stats.totalReferrals)", color: .purple)
                statCard(title: "Days Earned", value: "\(stats.totalDaysEarned)", color: .green)
                statCard(title: "Available", value: "\(stats.remaining)/\(stats.maxReferrals)", color: .orange)
            }
        }
    }
    
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Referrals List
    
    private func referralsList(_ referrals: [ReferralEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Friends")
                .font(.headline)
            
            ForEach(referrals) { referral in
                HStack(spacing: 12) {
                    Circle()
                        .fill(.purple.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(referral.username.prefix(1).uppercased())
                                .font(.headline)
                        )
                    
                    VStack(alignment: .leading) {
                        Text(referral.username)
                            .font(.subheadline.bold())
                        Text(referral.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("+\(referral.rewardDays)d")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.2), in: Capsule())
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let codeResponse = try await api.get("/referral/code")
            referralCode = codeResponse["code"] as? String ?? ""
            shareUrl = codeResponse["shareUrl"] as? String ?? ""
            
            let statsResponse = try await api.get("/referral/stats")
            stats = ReferralStats(
                totalReferrals: statsResponse["totalReferrals"] as? Int ?? 0,
                totalDaysEarned: statsResponse["totalDaysEarned"] as? Int ?? 0,
                maxReferrals: statsResponse["maxReferrals"] as? Int ?? 50,
                remaining: statsResponse["remaining"] as? Int ?? 50,
                referrals: (statsResponse["referrals"] as? [[String: Any]] ?? []).map { dict in
                    ReferralEntry(
                        id: dict["id"] as? String ?? UUID().uuidString,
                        username: dict["username"] as? String ?? "",
                        rewardDays: dict["rewardDays"] as? Int ?? 0,
                        date: ISO8601DateFormatter().date(from: dict["date"] as? String ?? "") ?? Date()
                    )
                }
            )
        } catch {
            print("Referral load error: \(error)")
        }
    }
}

// MARK: - Models

struct ReferralStats {
    let totalReferrals: Int
    let totalDaysEarned: Int
    let maxReferrals: Int
    let remaining: Int
    let referrals: [ReferralEntry]
}

struct ReferralEntry: Identifiable {
    let id: String
    let username: String
    let rewardDays: Int
    let date: Date
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
