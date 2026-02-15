import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let rotation: Double
    let scale: CGFloat
}

struct ConfettiView: View {
    @State private var pieces: [ConfettiPiece] = []
    @State private var animate = false

    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: 8, height: 12)
                        .scaleEffect(piece.scale)
                        .rotationEffect(.degrees(piece.rotation + (animate ? 360 : 0)))
                        .position(x: piece.x, y: animate ? geometry.size.height + 50 : piece.y)
                        .animation(
                            .easeIn(duration: Double.random(in: 2...3))
                            .delay(Double.random(in: 0...0.5)),
                            value: animate
                        )
                }
            }
            .onAppear {
                createPieces(in: geometry.size)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animate = true
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func createPieces(in size: CGSize) {
        pieces = (0..<50).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -100...0),
                color: colors.randomElement() ?? .yellow,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.5)
            )
        }
    }
}

// MARK: - Celebration Overlay

struct CelebrationOverlay: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var isShowing: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isShowing = false
                    }
                }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 80, height: 80)
                        .shadow(color: color.opacity(0.5), radius: 20)

                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))

                Button("Awesome!") {
                    withAnimation {
                        isShowing = false
                    }
                }
                .font(.headline)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(.white)
                .foregroundStyle(color)
                .clipShape(Capsule())
                .padding(.top, 8)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))

            ConfettiView()
        }
    }
}

#Preview {
    CelebrationOverlay(
        title: "Achievement Unlocked!",
        subtitle: "First Steps - Track your first game",
        icon: "trophy.fill",
        color: .yellow,
        isShowing: .constant(true)
    )
}
