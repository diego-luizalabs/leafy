// MARK: - ARQUIVO PRINCIPAL (LeafyApp.swift)
import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    print("Firebase Configurado com Sucesso.")
    return true
  }
}

@main
struct LeafyApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appDataStore = AppDataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDataStore)
        }
    }
}
