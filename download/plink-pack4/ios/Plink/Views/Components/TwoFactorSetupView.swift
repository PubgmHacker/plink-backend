import SwiftUI

// MARK: - TwoFactorSetupView (Pack 4: 2FA QR code setup)
struct TwoFactorSetupView: View {
    @State private var secret: String?
    @State private var qrCodeUrl: String?
    @State private var otpauthUrl: String?
    @State private var code: String = ""
    @State private var backupCodes: [String]?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showBackupCodes = false
    
    private let api = APIClient.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView("Setting up 2FA...")
                            .padding()
                    } else if let backupCodes {
                        // Backup codes view
                        backupCodesView(backupCodes)
                    } else if let qrCodeUrl {
                        // QR + code input
                        qrSetupView(qrCodeUrl: qrCodeUrl, secret: secret ?? "")
                    } else {
                        // Initial setup
                        introView
                    }
                }
                .padding()
            }
            .navigationTitle("Two-Factor Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .task { await setup() }
        }
    }
    
    private var introView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            Text("Protect Your Account")
                .font(.title2.bold())
            
            Text("2FA adds an extra layer of security. Even if someone gets your password, they can't access your account without your phone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
    
    private func qrSetupView(qrCodeUrl: String, secret: String) -> some View {
        VStack(spacing: 24) {
            // QR Code
            AsyncImage(url: URL(string: qrCodeUrl)) { image in
                image
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
            } placeholder: {
                ProgressView()
                    .frame(width: 220, height: 220)
            }
            
            VStack(spacing: 8) {
                Text("Scan with Google Authenticator")
                    .font(.headline)
                Text("or enter the secret manually:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(secret)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
            }
            
            // Code input
            VStack(spacing: 12) {
                Text("Enter the 6-digit code")
                    .font(.headline)
                
                TextField("000000", text: $code)
                    .font(.system(.title2, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                
                Button {
                    Task { await verify() }
                } label: {
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(code.count != 6)
            }
            
            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
    
    private func backupCodesView(_ codes: [String]) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            Text("2FA Enabled!")
                .font(.title2.bold())
            
            Text("Save these backup codes in a safe place. You'll need them if you lose your device.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                ForEach(codes, id: \.self) { code in
                    Text(code)
                        .font(.system(.headline, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .textSelection(.enabled)
                }
            }
            .padding()
            
            Button {
                UIPasteboard.general.string = codes.joined(separator: "\n")
                HapticManager.shared.success()
            } label: {
                Label("Copy All", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button("Done") {
                backupCodes = nil
            }
            .font(.headline)
        }
    }
    
    private func setup() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await api.post("/2fa/setup", body: [:])
            secret = response["secret"] as? String
            qrCodeUrl = response["qrCodeUrl"] as? String
            otpauthUrl = response["otpauthUrl"] as? String
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func verify() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await api.post("/2fa/verify", body: ["code": code])
            if let codes = response["backupCodes"] as? [String] {
                backupCodes = codes
                HapticManager.shared.success()
            }
        } catch {
            self.error = "Invalid code. Try again."
            HapticManager.shared.error()
        }
    }
}
