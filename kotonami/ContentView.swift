//
//  ContentView.swift
//  kotonami
//
//  Created by 松井奏人 on 2026/07/19.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var bottleStore = BottleStore()
    @StateObject private var authStore = AuthStore()
    @AppStorage(AppSettings.bottleTextSizeKey) private var bottleTextSize = BottleTextSize.standard.rawValue
    @AppStorage("hitouta.hasCompletedOnboarding.v1") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView {
                    withAnimation(.easeOut(duration: 0.25)) {
                        hasCompletedOnboarding = true
                    }
                }
            } else if authStore.isSignedIn {
                TabView {
                    BottleHomeView(store: bottleStore, authStore: authStore)
                        .tabItem {
                            Label("流す", systemImage: "water.waves")
                        }

                    BottleShelfView(store: bottleStore, authStore: authStore)
                        .tabItem {
                            Label("ボトル棚", systemImage: "shippingbox")
                        }

                    SettingsView(authStore: authStore, bottleStore: bottleStore)
                        .tabItem {
                            Label("設定", systemImage: "gearshape")
                        }
                }
                .tint(.ink)
                .task(id: authStore.userID) {
                    await bottleStore.connectAccount(userID: authStore.userID)
                }
            } else {
                AuthView(authStore: authStore)
                    .onAppear {
                        bottleStore.disconnectAccount()
                    }
            }
        }
        .dynamicTypeSize(BottleTextSize.value(for: bottleTextSize).dynamicTypeSize)
        .preferredColorScheme(.light)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
