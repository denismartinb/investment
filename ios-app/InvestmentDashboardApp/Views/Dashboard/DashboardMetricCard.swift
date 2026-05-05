import SwiftUI

struct DashboardMetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let accent: Color
    var isHidden: Bool = false
    var compact: Bool = false

    init(title: String, value: String, subtitle: String? = nil, accent: Color, isHidden: Bool = false, compact: Bool = false) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.accent = accent
        self.isHidden = isHidden
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(spacing: 7) {
                Circle().fill(accent).frame(width: compact ? 7 : 9, height: compact ? 7 : 9)
                Text(title)
                    .font((compact ? Font.caption2 : Font.caption2).weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.0)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(isHidden ? "••••••" : value)
                .font(.system(size: compact ? 17 : 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.46)

            Text(subtitle ?? "")
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .frame(height: compact ? 22 : 26, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 82 : 102, alignment: .leading)
        .padding(compact ? 10 : 12)
        .background(RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous).fill(AppTheme.panelBackground(highlight: accent)))
        .overlay(RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous).stroke(accent.opacity(0.22), lineWidth: 1))
    }
}
