import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @AppStorage("dashboardLightMode") private var prefersLightMode = false
    @State private var minimumSplashElapsed = false

    private var shouldShowSplash: Bool {
        !minimumSplashElapsed || appViewModel.route == .loading
    }

    var body: some View {
        ZStack {
            Group {
                switch appViewModel.route {
                case .loading:
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.background)
                case .login:
                    LoginView()
                        .transition(.opacity)
                case .dashboard:
                    DashboardTabView()
                        .transition(.opacity)
                }
            }

            if shouldShowSplash {
                SplashLaunchView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            guard !minimumSplashElapsed else { return }
            try? await Task.sleep(for: .seconds(2.75))
            withAnimation(.easeInOut(duration: 0.6)) {
                minimumSplashElapsed = true
            }
        }
        .preferredColorScheme(prefersLightMode ? .light : .dark)
    }
}

private struct SplashLaunchView: View {
    @State private var animateBackground = false
    @State private var animateChart = false
    @State private var animateBars = false
    @State private var revealText = false
    @State private var floatCard = false
    @State private var pulseHalo = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.015, green: 0.05, blue: 0.10),
                    Color(red: 0.035, green: 0.11, blue: 0.19),
                    Color(red: 0.02, green: 0.06, blue: 0.12),
                    Color(red: 0.01, green: 0.03, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [AppTheme.accentCyan.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 260
            )
            .scaleEffect(animateBackground ? 1.25 : 0.92)
            .offset(x: animateBackground ? -30 : -90, y: animateBackground ? -80 : -140)
            .blur(radius: 10)

            RadialGradient(
                colors: [AppTheme.accentPurple.opacity(0.18), .clear],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 280
            )
            .scaleEffect(animateBackground ? 1.18 : 0.9)
            .offset(x: animateBackground ? 40 : 110, y: animateBackground ? 110 : 170)
            .blur(radius: 14)

            Circle()
                .stroke(.white.opacity(0.07), lineWidth: 1)
                .frame(width: 320, height: 320)
                .scaleEffect(pulseHalo ? 1.06 : 0.94)
                .blur(radius: 1)

            Circle()
                .stroke(AppTheme.accentBlue.opacity(0.16), lineWidth: 1)
                .frame(width: 250, height: 250)
                .scaleEffect(pulseHalo ? 1.12 : 0.96)
                .blur(radius: 0.5)

            VStack(spacing: 28) {
                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.09), .white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .stroke(.white.opacity(0.14), lineWidth: 1)
                        )
                        .frame(width: 270, height: 196)
                        .shadow(color: .black.opacity(0.30), radius: 28, y: 18)

                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(AppTheme.accentBlue.opacity(0.08))
                        .frame(width: 232, height: 160)
                        .blur(radius: 20)

                    GeometryReader { proxy in
                        let size = proxy.size
                        ZStack(alignment: .bottomLeading) {
                            HStack(alignment: .bottom, spacing: 12) {
                                ForEach(Array([0.28, 0.42, 0.58, 0.46, 0.76, 0.62, 0.84].enumerated()), id: \.offset) { index, ratio in
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    AppTheme.accentBlue.opacity(0.92),
                                                    AppTheme.accentCyan.opacity(0.74)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 24, height: animateBars ? size.height * ratio * 0.52 : 10)
                                        .shadow(color: AppTheme.accentBlue.opacity(0.20), radius: 10, y: 4)
                                        .animation(.spring(response: 0.85, dampingFraction: 0.78).delay(Double(index) * 0.08), value: animateBars)
                                }
                            }
                            .padding(.leading, 20)
                            .padding(.bottom, 20)

                            SplashLineShape(progress: animateChart ? 1 : 0)
                                .trim(from: 0, to: animateChart ? 1 : 0.01)
                                .stroke(
                                    LinearGradient(
                                        colors: [AppTheme.accentOrange, AppTheme.positive],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                                )
                                .shadow(color: AppTheme.accentOrange.opacity(0.42), radius: 14, y: 4)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 24)
                        }
                    }
                    .frame(width: 270, height: 196)
                }
                .scaleEffect(revealText ? 1 : 0.94)
                .opacity(revealText ? 1 : 0.56)
                .offset(y: floatCard ? -6 : 6)

                VStack(spacing: 11) {
                    Text("Denis Martín Barroso")
                        .font(.caption.weight(.semibold))
                        .tracking(2.2)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.72))
                        .opacity(revealText ? 1 : 0)

                    Text("DMB Capital")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(revealText ? 1 : 0)
                        .offset(y: revealText ? 0 : 10)

                    Text("Patrimonio, estrategia y crecimiento a largo plazo")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.84))
                        .opacity(revealText ? 1 : 0)
                        .offset(y: revealText ? 0 : 12)
                }
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                animateBackground = true
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                floatCard = true
            }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                pulseHalo = true
            }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.82).delay(0.14)) {
                revealText = true
            }
            withAnimation(.easeOut(duration: 1.15).delay(0.24)) {
                animateChart = true
            }
            withAnimation(.easeOut(duration: 0.95).delay(0.08)) {
                animateBars = true
            }
        }
    }
}

private struct SplashLineShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let points = [
            CGPoint(x: rect.minX + rect.width * 0.02, y: rect.maxY - rect.height * 0.18),
            CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY - rect.height * 0.46),
            CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.32),
            CGPoint(x: rect.minX + rect.width * 0.62, y: rect.maxY - rect.height * 0.64),
            CGPoint(x: rect.minX + rect.width * 0.98, y: rect.maxY - rect.height * 0.84)
        ]

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}
