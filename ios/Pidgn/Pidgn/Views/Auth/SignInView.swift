//
//  SignInView.swift
//  Pidgn
//

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

                // App branding
                VStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    Text("Pidgn")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Family mail, delivered to your fridge.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Form fields
                VStack(spacing: 16) {
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

                // Error message
                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                // Sign in button
                Button {
                    Task {
                        await authService.signIn(email: email, password: password)
                    }
                } label: {
                    if authService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(email.isEmpty || password.isEmpty || authService.isLoading)

                // Sign up link
                Button("Don't have an account? Sign Up") {
                    showSignUp = true
                }
                .font(.subheadline)

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
