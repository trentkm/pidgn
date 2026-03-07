//
//  SignUpView.swift
//  Pidgn
//

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

            // Header
            VStack(spacing: 8) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Join Pidgn and connect with your family.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Form fields
            VStack(spacing: 16) {
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

            // Error message
            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            // Sign up button
            Button {
                Task {
                    await authService.signUp(
                        email: email,
                        password: password,
                        displayName: displayName
                    )
                }
            } label: {
                if authService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign Up")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(
                displayName.isEmpty || email.isEmpty || password.isEmpty || authService.isLoading
            )

            // Back to sign in
            Button("Already have an account? Sign In") {
                dismiss()
            }
            .font(.subheadline)

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
