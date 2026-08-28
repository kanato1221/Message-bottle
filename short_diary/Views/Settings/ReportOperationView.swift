//
//  ReportOperationView.swift
//  short_diary
//

import SwiftUI

struct ReportOperationView: View {
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("通報されたボトルの確認")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.ink)

                    operationCard(
                        title: "1. 管理画面を開く",
                        body: "Firebase Consoleでこのアプリの管理画面を開き、保存されているデータを確認します。"
                    )

                    operationCard(
                        title: "2. 通報の記録を見る",
                        body: "通報の記録には、どのボトルが通報されたか、誰が通報したかが保存されます。"
                    )

                    operationCard(
                        title: "3. ボトルの内容を確認する",
                        body: "通報されたボトルの本文を確認します。通報されたボトルは、確認が終わるまで他のユーザーに届かない状態になります。"
                    )

                    operationCard(
                        title: "4. 対応を決める",
                        body: "問題がないと判断した場合は、配信停止を解除します。不適切または悪質だと判断した場合は配信停止のままにし、必要に応じてアカウントの利用停止を検討します。"
                    )

                    operationCard(
                        title: "5. ブロックの記録を見る",
                        body: "ブロックの記録には、ブロックしたユーザーとブロックされた送信者が保存されます。ブロックされた送信者のボトルは、そのユーザーには今後届かないようになります。"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
        .navigationTitle("通報確認")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func operationCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.ink)

            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.line)
        }
    }
}
