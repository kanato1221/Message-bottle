//
//  AuthView.swift
//  short_diary
//

import SwiftUI

struct AuthView: View {
    @ObservedObject var authStore: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 6
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    Text("ひとうた")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundStyle(.secondary)

                    Text(isCreatingAccount ? "アカウントを作る" : "ログイン")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.ink)
                }

                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        TextField("メールアドレス", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button {
                            insertAtMarkIfNeeded()
                        } label: {
                            Text("@")
                                .font(.headline)
                                .foregroundStyle(Color.ink)
                                .frame(width: 38, height: 38)
                                .background(AppTheme.mist.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("@を入力")
                    }
                    .authFieldStyle()

                    SecureField("パスワード", text: $password)
                        .textContentType(isCreatingAccount ? .newPassword : .password)
                        .authFieldStyle()

                    if let errorMessage = authStore.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.cedar)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let successMessage = authStore.successMessage {
                        Text(successMessage)
                            .font(.caption)
                            .foregroundStyle(Color.moss)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button {
                    Task {
                        if isCreatingAccount {
                            await authStore.createAccount(email: email, password: password)
                        } else {
                            await authStore.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    Label(authStore.isWorking ? "処理中" : (isCreatingAccount ? "登録する" : "ログインする"), systemImage: "person.crop.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSubmit || authStore.isWorking)
                .opacity(canSubmit && !authStore.isWorking ? 1 : 0.55)

                Button {
                    switchAuthMode()
                } label: {
                    Text(isCreatingAccount ? "すでにアカウントがある" : "アカウントを作る")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color.ink)

                Spacer()
            }
            .padding(28)
        }
    }

    private func insertAtMarkIfNeeded() {
        guard !email.contains("@") else { return }
        email.append("@")
    }

    private func switchAuthMode() {
        email = ""
        password = ""
        authStore.errorMessage = nil
        authStore.successMessage = nil
        isCreatingAccount.toggle()
    }
}

private extension View {
    func authFieldStyle() -> some View {
        font(.body)
            .padding(14)
            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.line)
            }
    }
}
