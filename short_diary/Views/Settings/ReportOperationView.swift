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
                        title: "1. Firebase Consoleを開く",
                        body: "Firebase Consoleで shortdiary-66f95 を開き、Firestore Databaseへ進みます。"
                    )

                    operationCard(
                        title: "2. reports を見る",
                        body: "reports コレクションに、通報されたボトルIDと通報したユーザーIDが保存されます。"
                    )

                    operationCard(
                        title: "3. bottles を確認する",
                        body: "reports の bottleID と同じIDの bottles ドキュメントを開き、本文と isReported を確認します。通報されたボトルは isReported: true になり、他の人へ届かなくなります。"
                    )

                    operationCard(
                        title: "4. 解除する場合",
                        body: "問題ないと判断した場合は、Firebase Consoleで該当ボトルの isReported を false に戻します。悪質な場合は、そのまま true にしておきます。"
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

