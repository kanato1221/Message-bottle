//
//  TermsTextView.swift
//  short_diary
//

import SwiftUI

struct TermsTextView: View {
    let document: LegalDocument

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(document.title)
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.ink)

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(Color.ink)

                            Text(section.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("最終更新日: 2026年8月21日")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum LegalDocument {
    case terms
    case privacy

    var title: String {
        switch self {
        case .terms: "利用規約"
        case .privacy: "プライバシーポリシー"
        }
    }

    var sections: [LegalSection] {
        switch self {
        case .terms:
            return [
                LegalSection(title: "このアプリについて", body: "このアプリは、短い言葉をボトルとして海へ流し、匿名の誰かのボトルを受け取るためのサービスです。ユーザー同士のプロフィール、コメント、個別メッセージ機能はありません。"),
                LegalSection(title: "禁止事項", body: "他人を傷つける内容、個人情報、連絡先、住所、URL、犯罪や危険行為を助長する内容、不適切な表現を投稿することは禁止します。"),
                LegalSection(title: "通報と制限", body: "通報されたボトルは、他のユーザーに届かないよう制限されます。悪質な利用が確認された場合、アカウントの利用を停止することがあります。通報された本人へ通知は行いません。"),
                LegalSection(title: "投稿内容", body: "ユーザーが流したボトルは、匿名のボトルとして他のユーザーへ届くことがあります。自分自身や第三者を特定できる情報は書かないでください。"),
                LegalSection(title: "アカウント削除", body: "設定画面からアカウント削除を行えます。削除するとログイン情報と、この端末に保存されたボトル棚、サーバーに保存された自分のボトルが削除されます。")
            ]
        case .privacy:
            return [
                LegalSection(title: "取得する情報", body: "ログインのためのメールアドレス、Firebase AuthのユーザーID、ユーザーが流したボトル本文、ボトルの色、通報情報を扱います。"),
                LegalSection(title: "利用目的", body: "ログイン、ボトル交換、通報対応、不正利用の防止、サービス改善のために利用します。"),
                LegalSection(title: "匿名性について", body: "他のユーザーにメールアドレス、ユーザー名、プロフィールは表示されません。ただし、安全運用のため、運営側ではFirebase上のユーザーIDと投稿データを確認できる場合があります。"),
                LegalSection(title: "第三者サービス", body: "このアプリはFirebaseを利用しています。認証、Cloud Functions、Firestoreなどの機能によりデータを保存、処理します。"),
                LegalSection(title: "データ削除", body: "アカウント削除を行うと、ログイン情報とサーバー上の自分のボトルが削除されます。通報対応や不正防止に必要な最小限の記録は一定期間残る場合があります。")
            ]
        }
    }
}

struct LegalSection: Identifiable {
    let id = UUID()
    var title: String
    var body: String
}

