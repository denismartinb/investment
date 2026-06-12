import SwiftUI
import UIKit

enum AppTheme {
    private static func dynamic(_ dark: UIColor, _ light: UIColor) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let background = dynamic(UIColor(red: 0.03, green: 0.07, blue: 0.12, alpha: 1), UIColor(red: 0.95, green: 0.97, blue: 0.99, alpha: 1))
    static let backgroundSecondary = dynamic(UIColor(red: 0.05, green: 0.11, blue: 0.17, alpha: 1), UIColor(red: 0.90, green: 0.94, blue: 0.98, alpha: 1))
    static let surface = dynamic(UIColor(red: 0.08, green: 0.14, blue: 0.20, alpha: 1), UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1))
    static let surfaceElevated = dynamic(UIColor(red: 0.10, green: 0.17, blue: 0.24, alpha: 1), UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1))
    static let panelBorder = dynamic(UIColor(white: 1.0, alpha: 0.08), UIColor(red: 0.83, green: 0.88, blue: 0.94, alpha: 1))
    static let textPrimary = dynamic(.white, UIColor(red: 0.08, green: 0.12, blue: 0.18, alpha: 1))
    static let textSecondary = dynamic(UIColor(white: 1.0, alpha: 0.74), UIColor(red: 0.28, green: 0.34, blue: 0.42, alpha: 1))
    static let textMuted = dynamic(UIColor(white: 1.0, alpha: 0.52), UIColor(red: 0.47, green: 0.54, blue: 0.63, alpha: 1))
    static let axis = dynamic(UIColor(white: 1.0, alpha: 0.18), UIColor(red: 0.77, green: 0.83, blue: 0.90, alpha: 1))
    static let positive = Color(red: 0.20, green: 0.88, blue: 0.63)
    static let negative = Color(red: 1.0, green: 0.43, blue: 0.47)
    static let accentBlue = Color(red: 0.39, green: 0.78, blue: 1.0)
    static let accentCyan = Color(red: 0.38, green: 0.90, blue: 0.90)
    static let accentOrange = Color(red: 0.98, green: 0.73, blue: 0.33)
    static let accentPurple = Color(red: 0.70, green: 0.58, blue: 1.0)
    static let accentPink = Color(red: 0.99, green: 0.46, blue: 0.72)

    static let heroGradient = LinearGradient(
        colors: [
            dynamic(UIColor(red: 0.08, green: 0.18, blue: 0.26, alpha: 1), UIColor(red: 0.73, green: 0.86, blue: 0.95, alpha: 1)),
            dynamic(UIColor(red: 0.03, green: 0.09, blue: 0.16, alpha: 1), UIColor(red: 0.89, green: 0.94, blue: 0.99, alpha: 1)),
            dynamic(UIColor(red: 0.02, green: 0.05, blue: 0.10, alpha: 1), UIColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func panelBackground(highlight: Color? = nil) -> some ShapeStyle {
        LinearGradient(
            colors: [
                (highlight ?? accentBlue).opacity(0.14),
                surfaceElevated.opacity(0.96),
                surface.opacity(0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func color(for type: String) -> Color {
        switch type.lowercased() {
        case let value where value.contains("inmobili"):
            return accentOrange
        case let value where value.contains("cuenta"):
            return accentBlue
        case let value where value.contains("accion"):
            return accentPink
        case let value where value.contains("cripto"):
            return accentPurple
        case let value where value.contains("pension"):
            return Color(red: 0.53, green: 0.80, blue: 1.0)
        case let value where value.contains("renta fija"):
            return Color(red: 0.99, green: 0.82, blue: 0.47)
        default:
            let palette: [Color] = [positive, accentBlue, accentOrange, accentPurple, accentPink, accentCyan]
            let index = abs(type.hashValue) % palette.count
            return palette[index]
        }
    }
}

struct PremiumPanel<Content: View>: View {
    var highlight: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(AppTheme.panelBackground(highlight: highlight)))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(AppTheme.panelBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    var trailing: AnyView? = nil

    init(title: String, subtitle: String? = nil, trailing: AnyView? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
    }
}

struct GlassTag: View {
    let text: String
    let accent: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(accent.opacity(0.16), in: Capsule())
            .overlay(Capsule().stroke(accent.opacity(0.28), lineWidth: 1))
    }
}

struct ChartLegendRow: View {
    let items: [(String, Color)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 8) {
                        Circle().fill(item.1).frame(width: 10, height: 10)
                        Text(item.0)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(AppTheme.surface.opacity(0.55), in: Capsule())
                }
            }
        }
    }
}


enum DashboardTooltipDismissal {
    static let notification = Notification.Name("dashboardDismissTooltips")

    static func post() {
        NotificationCenter.default.post(name: notification, object: nil)
    }
}
