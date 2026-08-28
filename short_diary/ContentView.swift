//
//  ContentView.swift
//  short_diary
//
//  Created by 松井奏人 on 2026/07/19.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var bottleStore = BottleStore()
    @StateObject private var authStore = AuthStore()

    var body: some View {
        if authStore.isSignedIn {
            TabView {
                BottleHomeView(store: bottleStore, authStore: authStore)
                    .tabItem {
                        Label("流す", systemImage: "water.waves")
                    }

                BottleShelfView(store: bottleStore)
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
