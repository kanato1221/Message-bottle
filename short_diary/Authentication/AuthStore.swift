//
//  AuthStore.swift
//  short_diary
//

import Combine
import FirebaseAuth
import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var user: User?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isWorking = false

    private var listenerHandle: AuthStateDidChangeListenerHandle?
    private let deleteAccountDataURL = URL(string: "https://asia-northeast1-shortdiary-66f95.cloudfunctions.net/deleteAccountData")!

    var isSignedIn: Bool {
        user != nil
    }

    var email: String {
        user?.email ?? ""
    }

    var userID: String {
        user?.uid ?? email
    }

    init() {
        user = Auth.auth().currentUser
        listenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
            }
        }
    }

    deinit {
        if let listenerHandle {
            Auth.auth().removeStateDidChangeListener(listenerHandle)
        }
    }

    func signIn(email: String, password: String) async {
        await performAuthAction {
            _ = try await Auth.auth().signIn(withEmail: email.trimmed, password: password)
        }
    }

    func createAccount(email: String, password: String) async {
        guard !isWorking else { return }

        isWorking = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await Auth.auth().createUser(withEmail: email.trimmed, password: password)
            successMessage = "アカウントを作成しました。"
        } catch {
            errorMessage = authMessage(for: error)
        }

        isWorking = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            errorMessage = nil
            successMessage = nil
        } catch {
            errorMessage = "ログアウトできませんでした。"
        }
    }

    func deleteAccount() async -> Bool {
        guard !isWorking, let user else { return false }

        isWorking = true
        errorMessage = nil
        successMessage = nil

        do {
            try await deleteServerData(for: user)
            try await user.delete()
            isWorking = false
            return true
        } catch {
            errorMessage = authMessage(for: error)
            isWorking = false
            return false
        }
    }

    private func deleteServerData(for user: User) async throws {
        let idToken = try await user.getIDToken()
        var request = URLRequest(url: deleteAccountDataURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data("{}".utf8)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func performAuthAction(_ action: @escaping () async throws -> Void) async {
        guard !isWorking else { return }

        isWorking = true
        errorMessage = nil
        successMessage = nil

        do {
            try await action()
        } catch {
            errorMessage = authMessage(for: error)
        }

        isWorking = false
    }

    private func authMessage(for error: Error) -> String {
        guard let code = AuthErrorCode(_bridgedNSError: error as NSError)?.code else {
            return "ログインに失敗しました。"
        }

        switch code {
        case .invalidEmail:
            return "メールアドレスの形式を確認してください。"
        case .emailAlreadyInUse:
            return "このメールアドレスはすでに使われています。"
        case .userNotFound:
            return "このメールアドレスのアカウントが見つかりません。"
        case .wrongPassword, .invalidCredential:
            return "メールアドレスかパスワードが違います。"
        case .weakPassword:
            return "パスワードは6文字以上にしてください。"
        case .networkError:
            return "通信に失敗しました。時間をおいて試してください。"
        case .requiresRecentLogin:
            return "安全のため、もう一度ログインしてからアカウント削除を行ってください。"
        default:
            return "ログインに失敗しました。"
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
