//
//  SignUpView.swift
//  Pidgn

import SwiftUI

struct SignUpView: View {
    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Create Account")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Join the flock and start sending letters.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 14) {
                TextField("Display Name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                    .autocorrectionDisabled()

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
            }

            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await authService.signUp(email: email, password: password, displayName: displayName)
                }
            } label: {
                if authService.isLoading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text("Sign Up")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(PidgnTheme.accent, in: RoundedRectangle(cornerRadius: 12))
            .disabled(displayName.isEmpty || email.isEmpty || password.isEmpty || authService.isLoading)
            .opacity(displayName.isEmpty || email.isEmpty || password.isEmpty ? 0.5 : 1.0)

            Button("Already have an account? Sign In") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(PidgnTheme.accent)

            Spacer()
        }
        .padding(.horizontal, 32)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environment(AuthService())
    }
}
