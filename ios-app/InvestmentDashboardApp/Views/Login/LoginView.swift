import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.08, blue: 0.13), Color(red: 0.05, green: 0.14, blue: 0.21)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("DMB Capital")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .tracking(1.8)
                    .foregroundStyle(Color.white.opacity(0.78))

                Text("Dashboard protegido")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Accede a tu visualizador privado de inversión y patrimonio.")
                    .foregroundStyle(Color.white.opacity(0.92))

                VStack(spacing: 14) {
                    TextField("", text: $username, prompt: Text("Usuario").foregroundStyle(Color.white.opacity(0.60)))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .foregroundStyle(.white)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    SecureField("", text: $password, prompt: Text("Contraseña").foregroundStyle(Color.white.opacity(0.60)))
                        .padding()
                        .foregroundStyle(.white)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let errorMessage = appViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.red.opacity(0.9))
                }

                Button {
                    Task { await appViewModel.login(username: username, password: password) }
                } label: {
                    HStack {
                        Spacer()
                        if appViewModel.isBusy {
                            ProgressView().tint(.black)
                        } else {
                            Text("Entrar").fontWeight(.bold)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(LinearGradient(colors: [Color.green.opacity(0.95), Color.blue.opacity(0.9)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(.black)
                }
                .disabled(appViewModel.isBusy)
            }
            .padding(28)
            .background(.ultraThinMaterial.opacity(0.26), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
            .padding(24)
        }
    }
}
