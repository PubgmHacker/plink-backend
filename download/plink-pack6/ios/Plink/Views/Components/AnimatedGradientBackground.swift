import SwiftUI
import AVFoundation

// MARK: - AnimatedGradientBackground (Pack 6: быстрее + multi-color)
/// Анимированный градиентный фон с 3-цветной палитрой (Purple → Pink → Orange).
/// Pack 6: ускорена анимация в 3x, добавлены 3 цвета.

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    // Pack 6: в 3 раза быстрее (было 8 сек, стало 3 сек)
    private let animationDuration: Double = 3.0
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.067, green: 0.051, blue: 0.157),    // тёмный пурпур
                Color(red: 0.157, green: 0.051, blue: 0.118),    // тёмный розовый
                Color(red: 0.118, green: 0.051, blue: 0.078),    // тёмный оранжевый
                Color(red: 0.051, green: 0.078, blue: 0.118),    // тёмный cyan
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .animation(
            .easeInOut(duration: animationDuration)
                .repeatForever(autoreverses: true),
            value: animateGradient
        )
        .onAppear {
            animateGradient = true
        }
    }
}

// MARK: - BioluminescentBackground (Pack 6: быстрее + multi-color)

struct BioluminescentBackground: View {
    @State private var phase1 = false
    @State private var phase2 = false
    @State private var phase3 = false
    
    // Pack 6: ускорено в 2.5x
    private let duration1: Double = 4.0   // было 10
    private let duration2: Double = 3.0   // было 7
    private let duration3: Double = 5.0   // было 12
    
    var body: some View {
        ZStack {
            // Base dark
            Color.plinkBgPrimary
            
            // Blob 1 — Purple (top-left)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.plinkPrimary.opacity(0.4), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(
                    x: phase1 ? 100 : -100,
                    y: phase1 ? 50 : -50
                )
                .animation(
                    .easeInOut(duration: duration1).repeatForever(autoreverses: true),
                    value: phase1
                )
            
            // Blob 2 — Pink (bottom-right)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.plinkSecondary.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 280
                    )
                )
                .frame(width: 450, height: 450)
                .blur(radius: 70)
                .offset(
                    x: phase2 ? -120 : 120,
                    y: phase2 ? -80 : 80
                )
                .animation(
                    .easeInOut(duration: duration2).repeatForever(autoreverses: true),
                    value: phase2
                )
            
            // Blob 3 — Orange (center)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.plinkAccent.opacity(0.25), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 350, height: 350)
                .blur(radius: 50)
                .offset(
                    x: phase3 ? 80 : -80,
                    y: phase3 ? -100 : 100
                )
                .animation(
                    .easeInOut(duration: duration3).repeatForever(autoreverses: true),
                    value: phase3
                )
        }
        .ignoresSafeArea()
        .onAppear {
            phase1 = true
            phase2 = true
            phase3 = true
        }
    }
}

// MARK: - Preview

#Preview("Animated Gradient") {
    AnimatedGradientBackground()
        .overlay {
            VStack {
                Text("Plink")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Multi-color background")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
}

#Preview("Bioluminescent") {
    BioluminescentBackground()
        .overlay {
            VStack {
                Text("Plink")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("3-color blobs")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
}
