//
//  SignInView.swift
//  Pidgn

import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) var authService
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Branding
                VStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(PidgnTheme.accent)

                    Text("Pidgn")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Letters carried with care.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Fields
                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                }

                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await authService.signIn(email: email, password: password) }
                } label: {
                    if authService.isLoading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(PidgnTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                .disabled(email.isEmpty || password.isEmpty || authService.isLoading)
                .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1.0)

                Button("Don't have an account? Sign Up") {
                    showSignUp = true
                }
                .font(.subheadline)
                .foregroundStyle(PidgnTheme.accent)

                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }
}

#Preview {
    SignInView()
        .environment(AuthService())
}
