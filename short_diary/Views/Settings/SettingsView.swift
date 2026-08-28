//
//  SettingsView.swift
//  short_diary
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var authStore: AuthStore
    @ObservedObject var bottleStore: BottleStore
    @AppStorage(AppSettings.bottleTextSizeKey) private var bottleTextSize = BottleTextSize.standard.rawValue
    @AppStorage(AppSettings.bottleColorModeKey) private var bottleColorMode = BottleColorMode.chooseEachTime.rawValue
    @AppStorage(AppSettings.defaultBottleColorKey) private var defaultBottleColor = BottleColor.seaGreen.rawValue
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("設定")
                            .font(.system(size: 34, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.ink)

                        appearanceSection

                        settingsLinksSection

                        accountSection

                        if let message = authStore.errorMessage {
                            Text(message)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.cedar)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let message = authStore.successMessage {
                            Text(message)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.moss)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert("アカウントを削除しますか？", isPresented: $isShowingDeleteConfirmation) {
                Button("削除する", role: .destructive) {
                    Task {
                        let didDelete = await authStore.deleteAccount()
                        if didDelete {
                            bottleStore.disconnectAccount()
                            bottleStore.clearLocalData()
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("ログイン情報、この端末とクラウドに保存されたボトル棚、投稿・通報・ブロックに関するデータを削除します。この操作は取り消せません。")
            }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("文字サイズ")
                        .font(.headline)
                        .foregroundStyle(Color.ink)

                    Text("ボトルや中の紙に表示する文字の大きさを変えます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("文字サイズ", selection: $bottleTextSize) {
                    ForEach(BottleTextSize.allCases) { size in
                        Text(size.title).tag(size.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ボトルの色")
                        .font(.headline)
                        .foregroundStyle(Color.ink)

                    Text("流すたびに選ぶか、いつも同じ色を使うかを選びます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("ボトルの色", selection: $bottleColorMode) {
                    ForEach(BottleColorMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                if BottleColorMode.value(for: bottleColorMode) == .useDefault {
                    DefaultBottleColorPicker(selectedColor: $defaultBottleColor)
                        .padding(.top, 4)
                }
            }
        }
        .settingsCard()
    }

    private var settingsLinksSection: some View {
        VStack(spacing: 0) {
            Link(destination: DeveloperContactCard.reportEmailURL) {
                SettingsRow(title: "不適切な活動を報告・お問い合わせ", systemImage: "exclamationmark.bubble")
            }

            Divider()
                .padding(.leading, 42)

            NavigationLink {
                LegalAndSafetyView()
            } label: {
                SettingsRow(title: "利用規約と安全について", systemImage: "shield")
            }
        }
        .settingsCard()
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("アカウント")
                    .font(.headline)
                    .foregroundStyle(Color.ink)

                Text(authStore.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                            }

            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                HStack {
                    Label("アカウントを削除", systemImage: "person.crop.circle.badge.xmark")
                    Spacer()
                    if authStore.isWorking {
                        ProgressView()
                    }
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.cedar)
            .disabled(authStore.isWorking)
        }
        .settingsCard()
    }
}

private struct LegalAndSafetyView: View {
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("利用規約と安全について")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.ink)

                    Text("利用規約、プライバシーポリシー、通報やブロック、開発者への連絡方法をまとめています。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    DeveloperContactCard()

                    VStack(spacing: 0) {
                        NavigationLink {
                            TermsTextView(document: .terms)
                        } label: {
                            SettingsRow(title: "利用規約", systemImage: "doc.text")
                        }

                        Divider()
                            .padding(.leading, 42)

                        NavigationLink {
                            TermsTextView(document: .privacy)
                        } label: {
                            SettingsRow(title: "プライバシーポリシー", systemImage: "hand.raised")
                        }

                    }
                    .settingsCard()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
        .navigationTitle("利用規約と安全")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DeveloperContactCard: View {
    private static let supportEmail = "jouersapp@gmail.com"
    static let reportEmailURL: URL = {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "ながれびん・不適切な活動の報告")
        ]
        return components.url ?? URL(string: "mailto:jouersapp@gmail.com")!
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("開発者への連絡", systemImage: "envelope")
                .font(.headline)
                .foregroundStyle(Color.ink)

            Text("不適切な活動、通報に関する相談、不具合、アカウントについての問い合わせは、以下のメールアドレスへ連絡できます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: Self.reportEmailURL) {
                Label("開発者にメールで報告", systemImage: "paperplane")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.moss)
            }

            Text(Self.supportEmail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsCard()
    }
}

private struct SettingsRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.moss)
                .frame(width: 26)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ink)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

private extension View {
    func settingsCard() -> some View {
        padding(16)
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.line)
        }
    }
}

private struct DefaultBottleColorPicker: View {
    @Binding var selectedColor: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(BottleColor.allCases) { color in
                Button {
                    selectedColor = color.rawValue
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(color.gradient)
                            .frame(width: 34, height: 34)
                            .overlay {
                                Circle()
                                    .stroke(isSelected(color) ? Color.ink : AppTheme.line, lineWidth: isSelected(color) ? 2 : 1)
                            }
                            .overlay {
                                if isSelected(color) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.paper)
                                }
                            }

                        Text(color.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isSelected(color) ? Color.ink : .secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isSelected(_ color: BottleColor) -> Bool {
        selectedColor == color.rawValue
    }
}
