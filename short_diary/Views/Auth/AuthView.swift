//
//  AuthView.swift
//  short_diary
//

import SwiftUI

struct AuthView: View {
    @ObservedObject var authStore: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isCreatingAccount = false
    @State private var hasAcceptedTerms = false
    @State private var isShowingTerms = false

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 6 && hasAcceptedTerms
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    Text("ながれびん")
                        .font(.system(.headline, design: .serif, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(isCreatingAccount ? "アカウントを作る" : "ログイン")
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.ink)
                }

                VStack(spacing: 14) {
                    TextField("メールアドレス", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .authFieldStyle()

                    HStack(spacing: 10) {
                        Group {
                            if isPasswordVisible {
                                TextField("パスワード", text: $password)
                            } else {
                                SecureField("パスワード", text: $password)
                            }
                        }
                        .textContentType(isCreatingAccount ? .newPassword : .password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        Button {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                isPasswordVisible.toggle()
                            }
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .contentTransition(.identity)
                                .foregroundStyle(Color.moss)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isPasswordVisible ? "パスワードを隠す" : "パスワードを表示")
                    }
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

                    TermsAgreementRow(
                        isAccepted: $hasAcceptedTerms,
                        onShowTerms: {
                            isShowingTerms = true
                        }
                    )
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
        .sheet(isPresented: $isShowingTerms) {
            NavigationStack {
                TermsTextView(document: .terms)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("閉じる") {
                                isShowingTerms = false
                            }
                        }
                    }
            }
        }
    }

    private func switchAuthMode() {
        email = ""
        password = ""
        isPasswordVisible = false
        hasAcceptedTerms = false
        authStore.errorMessage = nil
        authStore.successMessage = nil
        isCreatingAccount.toggle()
    }
}

private struct TermsAgreementRow: View {
    @Binding var isAccepted: Bool
    let onShowTerms: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                isAccepted.toggle()
            } label: {
                Image(systemName: isAccepted ? "checkmark.square.fill" : "square")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isAccepted ? Color.moss : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isAccepted ? "利用規約に同意済み" : "利用規約に同意する")

            VStack(alignment: .leading, spacing: 4) {
                Text("利用規約に同意します。不適切な投稿や悪質な利用は許可されません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onShowTerms) {
                    Text("利用規約を読む")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.moss)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func authFieldStyle() -> some View {
        font(.body)
            .padding(14)
            .background(Color.paper.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.line)
            }
    }
}
