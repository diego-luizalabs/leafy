import SwiftUI
import FirebaseCore // Importe o Firebase
import GoogleSignIn // Importe o Google Sign-In

// 1. Crie esta classe (se ainda não o fez)
// Ela gerencia a inicialização do app
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // 2. Configure o Firebase PRIMEIRO
        FirebaseApp.configure()

        // 3. Configure o Google Sign-In
        // Esta é a parte que está faltando e causando o crash
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            // Se crachar aqui, seu GoogleService-Info.plist está errado ou faltando
            fatalError("Erro: CLIENT_ID do Firebase não encontrado. Verifique seu GoogleService-Info.plist.")
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        return true
    }
    
    // 4. Adicione o handler de URL (necessário para o Google)
    // Isso permite que o app receba a resposta do pop-up de login
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
      
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// 5. Esta é a sua estrutura @main principal
@main
struct LeafyApp: App {
    
    // 6. Registre o AppDelegate AQUI
    // Esta linha "conecta" a classe de configuração acima ao seu app
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Você já deve ter esta linha
    @StateObject private var appDataStore = AppDataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDataStore)
                // 7. (Opcional, mas bom ter) Fallback para o URL handler
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
