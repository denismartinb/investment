import SwiftUI

struct TypeFilterSheetView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.adaptive(minimum: 98, maximum: 138), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Button {
                            appViewModel.selectAllTypes()
                        } label: {
                            Text("Todos")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.18))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.accentOrange, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button("Ninguno") { appViewModel.clearAllTypes() }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .tint(AppTheme.textPrimary)
                    }

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(appViewModel.availableTypes, id: \.self) { type in
                            Button {
                                appViewModel.toggleType(type)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(AppTheme.color(for: type))
                                            .frame(width: 8, height: 8)
                                        Spacer(minLength: 4)
                                        Image(systemName: appViewModel.isTypeSelected(type) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(appViewModel.isTypeSelected(type) ? AppTheme.positive : AppTheme.textMuted)
                                    }
                                    Text(type)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                        .minimumScaleFactor(0.72)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(AppTheme.panelBackground(highlight: appViewModel.isTypeSelected(type) ? AppTheme.color(for: type) : AppTheme.accentBlue))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke((appViewModel.isTypeSelected(type) ? AppTheme.color(for: type) : AppTheme.panelBorder).opacity(0.34), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Seleccionar activos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
