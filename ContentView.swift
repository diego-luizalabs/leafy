import SwiftUI
import Combine
import Foundation
import SafariServices
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import WebKit // Importado para o Minigame

// MARK: - Configurações e Modelos

extension Color {
    static let corFolhaClara = Color(red: 0.3, green: 0.65, blue: 0.25)
    static let corDestaque = Color(red: 0.95, green: 0.7, blue: 0.3)
    static let fundoFormularioClaro = Color(.systemGray6)
    static let fundoFormularioEscuro = Color(.systemGray5)
    static let verdeClaroCard = Color(red: 0.85, green: 0.95, blue: 0.8)
    static let azulClaroCard = Color(red: 0.8, green: 0.9, blue: 0.98)
    static let amareloClaroCard = Color(red: 0.98, green: 0.95, blue: 0.8)
}

struct ConteudoEducacional: Identifiable, Hashable {
    let id = UUID()
    let titulo: String, subtitulo: String, descricaoCurta: String, icone: String
    let cor: Color, categoria: String, nivel: String
    var isMandatory: Bool = false
    var link: String? = nil
    var autor: String? = nil
    var duracao: String? = nil
    var textoCompleto: String? = nil
}

struct Plano: Identifiable {
    let id = UUID()
    let nome: String, preco: String
    let features: [String], cor: Color
    let isRecommended: Bool
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let text: String
    let user: String
    let isCurrentUser: Bool
    let timestamp: Date
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let size: CGFloat, speed: CGFloat, color: Color, opacity: Double

    static func createRandom(in size: CGSize) -> Particle {
        let color = [Color.corFolhaClara.opacity(0.8), Color.corDestaque.opacity(0.7), .white.opacity(0.9)].randomElement()!
        return Particle(
            position: CGPoint(x: .random(in: 0...size.width), y: .random(in: size.height...size.height + 100)),
            size: .random(in: 4...12),
            speed: .random(in: 50...100),
            color: color,
            opacity: .random(in: 0.5...1.0)
        )
    }

    static func createRandomMovingUp(in size: CGSize) -> Particle {
        let color = [Color.corFolhaClara.opacity(0.6), Color.corDestaque.opacity(0.5), .white.opacity(0.7)].randomElement()!
        return Particle(
            position: CGPoint(x: .random(in: 0...size.width), y: .random(in: size.height...size.height + 50)),
            size: .random(in: 3...8),
            speed: .random(in: 30...80),
            color: color,
            opacity: .random(in: 0.3...0.8)
        )
    }
}

struct UserProfile: Codable, Identifiable {
    var id: String?
    var name: String
    var profileImageURL: String?
    var bio: String?
    var points: Int
}

// MARK: - AppDataStore (Firebase)

class AppDataStore: ObservableObject {
    @Published var conteudos: [ConteudoEducacional]
    @Published var conteudosCompletos: Set<UUID> = []

    @Published var userProfile: UserProfile? = nil
    @Published var userName: String = "Visitante"
    var userBio: String { userProfile?.bio ?? "" }

    @Published var userProfileImage: Image? = nil
    @Published var chatMessages: [ChatMessage] = []

    private var db = Firestore.firestore()
    private var storage = Storage.storage()

    private var chatListenerRegistration: ListenerRegistration?
    private var userProfileListenerRegistration: ListenerRegistration?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        self.conteudos = [
            ConteudoEducacional(titulo: "Missões e Valores", subtitulo: "Módulo Obrigatório", descricaoCurta: "Conheça os pilares da plataforma Leafy.", icone: "heart.fill", cor: .pink, categoria: "Institucional", nivel: "Todos", isMandatory: true),
            ConteudoEducacional(titulo: "Compreender o Mercado Sustentável", subtitulo: "Módulo Obrigatório", descricaoCurta: "Sustentabilidade e o futuro profissional.", icone: "briefcase.fill", cor: .indigo, categoria: "Carreira", nivel: "Iniciante", isMandatory: true),
            
            // Minigame não está mais nesta lista, agora é uma Aba principal
            
            ConteudoEducacional(titulo: "Hortas Urbanas e Permacultura", subtitulo: "Curso Prático", descricaoCurta: "Guia completo de plantio em pequenos espaços.", icone: "leaf.fill", cor: .corFolhaClara, categoria: "Curso", nivel: "Iniciante"),
            ConteudoEducacional(titulo: "Reciclagem e Economia Circular", subtitulo: "Curso Completo", descricaoCurta: "Técnicas e a economia circular.", icone: "arrow.triangle.2.circlepath", cor: .blue, categoria: "Curso", nivel: "Avançado"),
            ConteudoEducacional(titulo: "Energias Renováveis do Futuro", subtitulo: "Curso Técnico", descricaoCurta: "Explore a energia solar, eólica e outras fontes limpas.", icone: "wind", cor: .cyan, categoria: "Curso", nivel: "Avançado"),
            ConteudoEducacional(titulo: "O Saneamento Básico", subtitulo: "Saúde e Meio Ambiente", descricaoCurta: "Entenda a importância do saneamento para a saúde pública.", icone: "drop.fill", cor: .cyan, categoria: "Curso", nivel: "Intermediário"),
            ConteudoEducacional(titulo: "Descarte de Lixo Eletrônico", subtitulo: "Lixo Eletrônico", descricaoCurta: "O que fazer com celulares, pilhas e computadores antigos.", icone: "iphone.gen1.slash", cor: .blue, categoria: "Curso", nivel: "Intermediário"),
            ConteudoEducacional(titulo: "A Ameaça dos Oceanos", subtitulo: "Ecossistemas Marinhos", descricaoCurta: "Como o lixo plástico impacta a vida marinha.", icone: "trash.circle.fill", cor: .teal, categoria: "Curso", nivel: "Avançado"),
            ConteudoEducacional(titulo: "A Revolução da Energia Solar", subtitulo: "Energias Renováveis", descricaoCurta: "Como a energia solar está moldando o futuro.", icone: "sun.max.trianglebadge.exclamationmark.fill", cor: .orange, categoria: "Curso", nivel: "Iniciante"),
            ConteudoEducacional(titulo: "O Problema do Isopor", subtitulo: "Descarte Correto", descricaoCurta: "Aprenda a descartar e reciclar o isopor corretamente.", icone: "archivebox.fill", cor: .gray, categoria: "Curso", nivel: "Iniciante"),
            ConteudoEducacional(titulo: "Guia de Compostagem Caseira", subtitulo: "E-book Gratuito", descricaoCurta: "Transforme resíduos orgânicos em adubo.", icone: "book.closed.fill", cor: Color(red: 0.2, green: 0.15, blue: 0.05), categoria: "Ebook", nivel: "Iniciante", link: "https://www.infoteca.cnptia.embrapa.br/infoteca/bitstream/doc/1019253/1/cartilhacompostagem.pdf"),
            ConteudoEducacional(titulo: "Manual Completo do Lixo Zero", subtitulo: "E-book Completo", descricaoCurta: "Princípios para reduzir sua geração de lixo.", icone: "trash.slash.fill", cor: .gray, categoria: "Ebook", nivel: "Avançado"),
            ConteudoEducacional(titulo: "5 Atitudes para um Planeta Mais Saudável", subtitulo: "Artigo da Comunidade", descricaoCurta: "Pequenas mudanças que fazem a diferença.", icone: "newspaper.fill", cor: .purple, categoria: "Artigo", nivel: "Todos", autor: "Equipe Leafy", textoCompleto: "Pequenas mudanças de hábito podem ter um impacto global..."),
            ConteudoEducacional(titulo: "A Importância Vital das Abelhas", subtitulo: "Artigo Científico", descricaoCurta: "O papel vital dos polinizadores.", icone: "ant.fill", cor: .red, categoria: "Artigo", nivel: "Intermediário", autor: "Dr. Silva", textoCompleto: "As abelhas são responsáveis por mais de 70% da polinização..."),
            ConteudoEducacional(titulo: "Como Montar sua Horta Vertical", subtitulo: "Vídeo Tutorial", descricaoCurta: "Horta em apartamentos.", icone: "video.fill", cor: .teal, categoria: "Video", nivel: "Iniciante", duracao: "12 min"),
            ConteudoEducacional(titulo: "Documentário: Oceanos de Plástico", subtitulo: "Documentário Impactante", descricaoCurta: "A poluição marinha.", icone: "film.fill", cor: .blue, categoria: "Video", nivel: "Todos", duracao: "45 min")
        ]

        setupAuthListener()
        listenToChatMessages()
    }

    private func setupAuthListener() {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            guard let self = self else { return }
            if let user = user {
                self.listenToUserProfile(userID: user.uid)
            } else {
                self.stopListening()
                DispatchQueue.main.async {
                    self.userProfile = nil
                    self.userName = "Visitante"
                    self.userProfileImage = nil
                    self.chatMessages = []
                    self.conteudosCompletos = []
                }
            }
        }
    }

    func listenToUserProfile(userID: String) {
        userProfileListenerRegistration?.remove()
        userProfileListenerRegistration = db.collection("users").document(userID)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("🔴 ERRO no listener do perfil: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.userProfile = nil
                        self.userName = "Erro ao Carregar"
                    }
                    return
                }

                guard let document = documentSnapshot, document.exists else {
                    print("⚠️ AVISO: Documento do perfil NÃO encontrado para o usuário \(userID).")
                    DispatchQueue.main.async {
                        self.userProfile = nil
                        self.userName = "Perfil Não Encontrado"
                    }
                    return
                }

                let data = document.data()
                let name = data?["name"] as? String ?? "Nome Padrão"
                let profileImageURL = data?["profileImageURL"] as? String
                let bio = data?["bio"] as? String ?? ""
                let points = data?["points"] as? Int ?? 0

                let profile = UserProfile(id: document.documentID, name: name, profileImageURL: profileImageURL, bio: bio, points: points)

                DispatchQueue.main.async {
                    self.userProfile = profile
                    self.userName = profile.name
                    print("✅✅ Perfil CARREGADO/ATUALIZADO: \(profile.name), Pontos: \(profile.points)")

                    if profile.profileImageURL == nil {
                        self.userProfileImage = nil
                    }
                }
            }
    }

    func listenToChatMessages() {
        chatListenerRegistration?.remove()
        chatListenerRegistration = db.collection("chatMessages")
            .order(by: "timestamp", descending: false)
            .limit(toLast: 50)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                guard let documents = querySnapshot?.documents else {
                    print("Erro ao buscar mensagens: \(error?.localizedDescription ?? "Erro desconhecido")")
                    return
                }

                let newMessages = documents.compactMap { document -> ChatMessage? in
                    let data = document.data()
                    let id = document.documentID
                    let text = data["text"] as? String ?? ""
                    let userName = data["userName"] as? String ?? "Anônimo"
                    let userID = data["userID"] as? String ?? ""
                    let timestamp = data["timestamp"] as? Timestamp

                    guard let date = timestamp?.dateValue() else { return nil }
                    let isCurrentUser = (userID == Auth.auth().currentUser?.uid)

                    return ChatMessage(id: id, text: text, user: userName, isCurrentUser: isCurrentUser, timestamp: date)
                }
                DispatchQueue.main.async {
                    self.chatMessages = newMessages
                }
            }
    }

    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let userID = Auth.auth().currentUser?.uid,
              let currentUserName = self.userProfile?.name else {
            return
        }

        let messageData: [String: Any] = [
            "text": text,
            "userName": currentUserName,
            "userID": userID,
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("chatMessages").addDocument(data: messageData) { error in
            if let error = error { print("Erro ao enviar mensagem: \(error.localizedDescription)") }
        }
    }

    func createUserProfile(userID: String, name: String) {
        let profileData: [String: Any] = [
            "name": name,
            "profileImageURL": NSNull(),
            "bio": "",
            "points": 0
        ]

        db.collection("users").document(userID).setData(profileData) { error in
            if let error = error { print("Erro ao criar perfil inicial: \(error)") }
            else { print("Perfil inicial criado para o usuário \(userID)") }
        }
    }

    func addPoints(_ amount: Int) {
        guard let userID = Auth.auth().currentUser?.uid, var currentProfile = self.userProfile else { return }
        let newPoints = currentProfile.points + amount

        db.collection("users").document(userID).updateData(["points": newPoints]) { error in
            if let error = error {
                print("Erro ao atualizar pontos: \(error.localizedDescription)")
            } else {
                print("Pontos atualizados no Firestore.")
                DispatchQueue.main.async {
                    self.userProfile?.points = newPoints
                }
            }
        }
    }

    func updateUserName(newName: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        guard self.userProfile != nil else { return }
        db.collection("users").document(userID).updateData(["name": newName]) { error in
            if let error = error { print("Erro ao atualizar nome no Firestore: \(error)") }
            else {
                print("Nome atualizado com sucesso no Firestore")
                DispatchQueue.main.async {
                    self.userProfile?.name = newName
                    self.userName = newName
                }
            }
        }
        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
        changeRequest?.displayName = newName
        changeRequest?.commitChanges { error in
            if let error = error { print("Erro ao atualizar DisplayName no Auth: \(error)") }
            else { print("DisplayName atualizado com sucesso no Auth") }
        }
    }

    func updateUserBio(newBio: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        guard self.userProfile != nil else { return }
        db.collection("users").document(userID).updateData(["bio": newBio]) { error in
              if let error = error {
                  print("Erro ao atualizar bio no Firestore: \(error)")
              } else {
                  print("Bio atualizada com sucesso no Firestore")
                  DispatchQueue.main.async {
                      self.userProfile?.bio = newBio
                  }
              }
          }
    }

    func sendPasswordReset(email: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@") else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Por favor, insira um e-mail válido."])
        }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
            print("E-mail de redefinição enviado para \(trimmedEmail)")
        } catch {
            print("Erro ao enviar e-mail de redefinição: \(error.localizedDescription)")
            throw error
        }
    }

    func updateProfileImage(imageData: Data) {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let storageRef = storage.reference().child("profileImages/\(userID).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        storageRef.putData(imageData, metadata: metadata) { [weak self] metadata, error in
            guard let self = self else { return }
            guard metadata != nil else {
                print("Erro ao fazer upload da imagem: \(error?.localizedDescription ?? "Erro")")
                return
            }

            storageRef.downloadURL { url, error in
                guard let downloadURL = url else {
                    print("Erro ao obter URL de download: \(error?.localizedDescription ?? "Erro")")
                    return
                }

                self.db.collection("users").document(userID).updateData(["profileImageURL": downloadURL.absoluteString]) { error in
                    if let error = error {
                        print("Erro ao salvar URL da imagem no Firestore: \(error)")
                    } else {
                        print("URL da imagem atualizada com sucesso no Firestore")
                        DispatchQueue.main.async {
                            self.userProfile?.profileImageURL = downloadURL.absoluteString
                            self.userProfileImage = nil
                        }
                    }
                }
            }
        }
    }

    func stopListening() {
        chatListenerRegistration?.remove()
        chatListenerRegistration = nil
        userProfileListenerRegistration?.remove()
        userProfileListenerRegistration = nil
    }

    func toggleCompletion(for item: ConteudoEducacional) {
        DispatchQueue.main.async {
            if self.conteudosCompletos.contains(item.id) {
                self.conteudosCompletos.remove(item.id)
            } else {
                self.conteudosCompletos.insert(item.id)
            }
        }
    }

     deinit {
         print("AppDataStore deinit: Removing listeners.")
         stopListening()
         if let handle = authStateHandle {
             Auth.auth().removeStateDidChangeListener(handle)
             print("AppDataStore Auth Listener removed.")
         }
     }
}

// MARK: - Views Utilitárias e de Tema
enum AuthScreen { case login, cadastro }
struct AppTheme {
    var colorScheme: ColorScheme
    var fundo: Color { colorScheme == .light ? Color(.systemGray6) : Color(red: 0.1, green: 0.1, blue: 0.1) }
    var fundoCard: Color { colorScheme == .light ? .white : Color(red: 0.2, green: 0.2, blue: 0.2) }
    var corTerra: Color { colorScheme == .light ? Color(red: 0.2, green: 0.15, blue: 0.05) : Color(red: 0.9, green: 0.9, blue: 0.8) }
    var fundoCampoInput: Color { colorScheme == .light ? Color(.systemGray5) : Color(.systemGray4) }
}
struct TagModifier: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content.font(.caption.weight(.bold)).padding(.horizontal, 10).padding(.vertical, 5).background(color.opacity(0.1)).foregroundColor(color).clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
extension View {
    func tagStyle(color: Color) -> some View { self.modifier(TagModifier(color: color)) }
}

// MARK: - Views de Chat
struct ChatBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.isCurrentUser {
                Spacer()
                VStack(alignment: .trailing) {
                    Text(message.text).padding(10).background(Color.corFolhaClara).foregroundColor(.white).cornerRadius(15, corners: [.topLeft, .bottomLeft, .bottomRight])
                    Text(message.timestamp, style: .time).font(.caption2).foregroundColor(.gray)
                }
            } else {
                VStack(alignment: .leading) {
                    Text(message.user).font(.caption).foregroundColor(.gray)
                    Text(message.text).padding(10).background(Color(.systemGray5)).foregroundColor(.primary).cornerRadius(15, corners: [.topRight, .bottomLeft, .bottomRight])
                    Text(message.timestamp, style: .time).font(.caption2).foregroundColor(.gray)
                }
                Spacer()
            }
        }
    }
}
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity, corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path { Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)).cgPath) }
}
struct ComunidadeChatView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @State private var newMessageText: String = ""

    var body: some View {
        VStack {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(appDataStore.chatMessages) { message in
                            ChatBubble(message: message).id(message.id)
                        }
                    }.padding()
                }
                .onChange(of: appDataStore.chatMessages) { _, newValue in
                    if let lastMessage = newValue.last {
                        withAnimation { scrollViewProxy.scrollTo(lastMessage.id, anchor: .bottom) }
                    }
                }
                .onAppear {
                    if let lastMessage = appDataStore.chatMessages.last {
                        scrollViewProxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }

            HStack {
                TextField("Digite sua mensagem...", text: $newMessageText).padding(10).background(Color(.systemGray6)).cornerRadius(10)
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill").font(.largeTitle).foregroundColor(.corFolhaClara)
                }.disabled(newMessageText.isEmpty)
            }.padding()
        }
        .navigationTitle("Comunidade")
    }

    func sendMessage() {
        guard !newMessageText.isEmpty else { return }
        appDataStore.sendMessage(newMessageText)
        newMessageText = ""
    }
}

// MARK: - Views Principais (Tabs)
struct MainView: View {
    let logoutAction: () -> Void
    var body: some View {
        TabView {
            NavigationView { MinigameView(logoutAction: logoutAction) }
                .tabItem { Label("Jogar", systemImage: "gamecontroller.fill") }
            
            NavigationView { CursosView(logoutAction: logoutAction) }
                .tabItem { Label("Cursos", systemImage: "book.fill") }

            NavigationView { ExplorarView() }
                .tabItem { Label("Explorar", systemImage: "sparkles") }

            NavigationView { ComunidadeChatView() }
                .tabItem { Label("Comunidade", systemImage: "person.3.fill") }

        }.accentColor(.corFolhaClara)
    }
}

// MARK: - Views de Conteúdo (Planos, Módulos, Detalhes)
struct PlanosView: View {
    @Environment(\.colorScheme) var colorScheme
    let planos: [Plano] = [
        Plano(nome: "Básico", preco: "Grátis", features: ["Acesso a e-books simples", "Módulos introdutórios"], cor: .gray, isRecommended: false),
        Plano(nome: "Pro", preco: "R$ 29,90/mês", features: ["Todos os e-books", "Módulos detalhados", "Aulas em vídeo"], cor: .corFolhaClara, isRecommended: true),
        Plano(nome: "Super", preco: "Sob consulta", features: ["Todos os benefícios do Pro", "Assistência em escolas", "Visitas a parques"], cor: .corDestaque, isRecommended: false)
    ]

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ScrollView {
            VStack(spacing: 20) {
                ForEach(planos) { plano in
                    PlanoCardView(plano: plano)
                }
            }.padding()
        }
        .background(theme.fundo.ignoresSafeArea()).navigationTitle("Nossos Planos")
    }
}
struct PlanoCardView: View {
    let plano: Plano
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        VStack(alignment: .leading, spacing: 15) {
            if plano.isRecommended {
                Text("RECOMENDADO").font(.caption.weight(.bold)).padding(.horizontal, 8).padding(.vertical, 4).background(Color.yellow).foregroundColor(.black).cornerRadius(5)
            }
            Text(plano.nome).font(.title.weight(.bold)).foregroundColor(plano.cor)
            Text(plano.preco).font(.title3.weight(.semibold))
            Divider()
            ForEach(plano.features, id: \.self) { feature in
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.corFolhaClara)
                    Text(feature)
                }
            }
        }.padding(20).background(theme.fundoCard).cornerRadius(15).shadow(radius: 5)
    }
}
struct ModuleView: View {
    let item: ConteudoEducacional
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        let isCompleto = appDataStore.conteudosCompletos.contains(item.id)
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Aula 1: Introdução").font(.title2.weight(.bold))
                    RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.2)).aspectRatio(16/9, contentMode: .fit).overlay(Image(systemName: "play.circle.fill").font(.largeTitle).foregroundColor(.gray))
                    Text("Este módulo introdutório explora os conceitos fundamentais de \(item.titulo.lowercased()). Abordaremos os principais desafios e as soluções mais eficazes que você pode aplicar no seu dia a dia para promover um impacto positivo e duradouro no meio ambiente. O conteúdo foi desenhado para ser prático e de fácil comprehension.").lineSpacing(5)
                    Divider()
                    Button(action: {
                        appDataStore.toggleCompletion(for: item)
                        dismiss()
                    }) {
                        Label(isCompleto ? "Desmarcar Conclusão" : "Marcar como Concluído", systemImage: isCompleto ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.headline.weight(.bold)).frame(maxWidth: .infinity).padding().background(isCompleto ? Color.gray : Color.corFolhaClara).foregroundColor(.white).cornerRadius(12)
                    }
                }.padding()
            }
            .background(theme.fundo.ignoresSafeArea())
            .navigationTitle(item.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}
struct DetailView: View {
    let item: ConteudoEducacional
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.colorScheme) var colorScheme
    @State private var showModulo = false

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 15) {
                    Image(systemName: item.icone).resizable().scaledToFit().frame(width: 50, height: 50).foregroundColor(item.cor)
                        .padding(15)
                        .background(item.cor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 15))

                    VStack(alignment: .leading) {
                        Text(item.titulo).font(.largeTitle.weight(.heavy)).foregroundColor(theme.corTerra)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(item.subtitulo).font(.title3).foregroundColor(.gray)
                    }
                }.padding(.bottom)

                HStack(spacing: 10) {
                    Text(item.categoria).tagStyle(color: item.cor)
                    Text(item.nivel).tagStyle(color: .corDestaque)
                }

                Divider()

                Text("Sobre este Módulo").font(.title2.weight(.bold)).foregroundColor(theme.corTerra)
                Text("Este conteúdo foi cuidadosamente desenhado para aprofundar seu conhecimento sobre \(item.titulo.lowercased()). Ao longo das aulas, você terá acesso a vídeos explicativos, materiais de leitura, quizzes interativos e projetos práticos que conectam a teoria com o mundo real. Nosso objetivo é fornecer as ferramentas necessárias para que você não apenas aprenda, mas também aplique esses conceitos sustentáveis em sua comunidade.").lineSpacing(5).foregroundColor(.primary)

                Button("Iniciar Módulo") { showModulo = true }.buttonStyle(.borderedProminent).tint(.corFolhaClara).controlSize(.large).frame(maxWidth: .infinity).padding(.top, 10)

            }.padding()
        }
        .background(theme.fundo.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(item.titulo)
        .sheet(isPresented: $showModulo) {
            ModuleView(item: item)
        }
    }
}
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
struct EbookReaderView: View {
    let ebook: ConteudoEducacional
    @Environment(\.colorScheme) var colorScheme
    @State private var showSafari = false

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ScrollView {
            VStack(spacing: 25) {
                Image(systemName: ebook.icone)
                    .font(.system(size: 80))
                    .foregroundColor(ebook.cor)
                    .padding(30)
                    .background(theme.fundoCard.opacity(0.8))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    .padding(.top, 20)

                Text(ebook.titulo).font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
                Text(ebook.descricaoCurta).font(.title3).foregroundColor(.secondary).multilineTextAlignment(.center)

                if let link = ebook.link, let url = URL(string: link) {
                    Button { showSafari = true } label: {
                        Label("Ler E-book Agora", systemImage: "safari.fill")
                            .font(.headline.weight(.bold))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.corFolhaClara)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .corFolhaClara.opacity(0.4), radius: 5, y: 3)
                    }
                    .sheet(isPresented: $showSafari) {
                        SafariView(url: url)
                            .ignoresSafeArea()
                    }
                } else {
                    Text("Conteúdo em breve")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            }
            .padding(40)
        }
        .background(theme.fundo.ignoresSafeArea())
        .navigationTitle(ebook.categoria)
        .navigationBarTitleDisplayMode(.inline)
    }
}
struct ArtigoView: View {
    let artigo: ConteudoEducacional
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                VStack {
                    Image(systemName: artigo.icone)
                        .font(.largeTitle)
                        .foregroundColor(artigo.cor)
                        .padding(.bottom, 5)

                    Text(artigo.titulo)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text(artigo.subtitulo)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if let autor = artigo.autor {
                        Text("Por \(autor)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)

                Divider()

                Text(artigo.textoCompleto ?? "Este artigo está sendo escrito e estará disponível em breve.")
                    .font(.body)
                    .lineSpacing(6)
                    .padding(.top, 10)

            }
            .padding()
        }
        .background(theme.fundo.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(artigo.categoria)
    }
}
struct VideoView: View {
    let video: ConteudoEducacional
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.8))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.7))
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 10) {
                    Text(video.titulo)
                        .font(.largeTitle.weight(.bold))

                    Text(video.subtitulo)
                        .font(.title3)
                        .foregroundColor(.secondary)

                    if let duracao = video.duracao {
                        Label(duracao, systemImage: "clock.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 10) {
                        Text(video.categoria).tagStyle(color: video.cor)
                        Text(video.nivel).tagStyle(color: .corDestaque)
                    }
                }

                Divider()

                Text("Sobre este Vídeo")
                    .font(.title2.weight(.bold))
                    .foregroundColor(theme.corTerra)

                Text(video.descricaoCurta)
                    .font(.body)
                    .lineSpacing(5)
            }
            .padding()
        }
        .background(theme.fundo.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(video.categoria)
    }
}
struct ViewRouter: View {
    let item: ConteudoEducacional

    @ViewBuilder
    var body: some View {
        switch item.categoria {
        case "Curso":
            DetailView(item: item)
        case "Ebook":
            EbookReaderView(ebook: item)
        case "Artigo":
            ArtigoView(artigo: item)
        case "Video":
            VideoView(video: item)
        default:
            DetailView(item: item)
        }
    }
}
struct CategoriaListView: View {
    let categoriaTitulo: String
    let corCategoria: Color
    let todosConteudos: [ConteudoEducacional]
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.colorScheme) var colorScheme

    private var conteudosFiltrados: [ConteudoEducacional] {
        let categoriaKey: String
        switch categoriaTitulo {
            case "E-books": categoriaKey = "Ebook"
            case "Artigos": categoriaKey = "Artigo"
            case "Vídeos": categoriaKey = "Video"
            default: categoriaKey = categoriaTitulo
        }
        return todosConteudos.filter { $0.categoria == categoriaKey && $0.categoria != "Minigame" }
    }

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ScrollView {
            LazyVStack(spacing: 15) {
                if conteudosFiltrados.isEmpty {
                    Text("Nenhum conteúdo encontrado para \"\(categoriaTitulo)\" ainda.")
                        .foregroundColor(.secondary)
                        .padding(.top, 50)
                        .multilineTextAlignment(.center)
                } else {
                    ForEach(conteudosFiltrados) { item in
                        NavigationLink(destination: ViewRouter(item: item)) {
                            ItemRowView(item: item)
                        }
                    }
                }
            }
            .padding()
        }
        .background(theme.fundo.ignoresSafeArea())
        .navigationTitle(categoriaTitulo)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Views de Componentes (Cards e Rows)
struct ItemRowView: View {
    let item: ConteudoEducacional
    var passoNumero: Int? = nil
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let isCompleto = appDataStore.conteudosCompletos.contains(item.id)
        let theme = AppTheme(colorScheme: colorScheme)

        HStack(spacing: 15) {
            if let passo = passoNumero {
                ZStack {
                    Circle()
                        .fill(isCompleto ? Color.corFolhaClara : Color.gray.opacity(0.3))
                        .frame(width: 35, height: 35)
                    Text("\(passo)")
                        .font(.headline.weight(.bold))
                        .foregroundColor(isCompleto ? .white : .primary.opacity(0.7))
                }
            }

            Image(systemName: item.icone)
                .font(.title2.weight(.medium))
                .foregroundColor(item.cor)
                .frame(width: 45, height: 45)
                .background(item.cor.opacity(0.12))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.titulo)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(item.descricaoCurta)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isCompleto {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.corFolhaClara)
                    .font(.title)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(15)
        .background(theme.fundoCard)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
    }
}
struct CursoCardView: View {
    let curso: ConteudoEducacional
    @State private var progress: Double
    @Environment(\.colorScheme) var colorScheme

    init(curso: ConteudoEducacional) {
        self.curso = curso
        _progress = State(initialValue: [0.2, 0.5, 0.8, 0.95].randomElement()!)
    }

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        HStack(spacing: 15) {
            Image(systemName: curso.icone)
                .font(.system(size: 28))
                .foregroundColor(curso.cor)
                .frame(width: 60, height: 60)
                .background(curso.cor.opacity(0.15))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 8) {
                Text(curso.nivel.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.secondary)
                Text(curso.titulo)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                ProgressView(value: progress, total: 1.0)
                    .tint(curso.cor)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding(15)
        .background(theme.fundoCard)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
    }
}
struct CursosView: View {
    let logoutAction: () -> Void
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.colorScheme) var colorScheme
    @State private var showProfile = false

    private var todosOsCursos: [ConteudoEducacional] {
        appDataStore.conteudos.filter { $0.categoria == "Curso" && !$0.isMandatory }
    }

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                
                if !todosOsCursos.isEmpty {
                    Text("Trilhas de Aprendizagem")
                        .font(.title2.weight(.bold))
                        .foregroundColor(theme.corTerra)
                        .padding(.horizontal)

                    LazyVStack(spacing: 15) {
                        ForEach(todosOsCursos) { curso in
                            NavigationLink(destination: DetailView(item: curso)) {
                                CursoCardView(curso: curso)
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    Text("Novos cursos em breve!")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 50)
                }

            }.padding(.top)
        }
        .buttonStyle(.plain)
        .background(theme.fundo.ignoresSafeArea())
        .navigationTitle("Cursos")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                HStack {
                    Text("\(appDataStore.userProfile?.points ?? 0)")
                        .font(.subheadline.weight(.bold))
                    Image(systemName: "star.fill")
                        .font(.caption.weight(.bold))
                }
                .foregroundColor(.corDestaque)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.corDestaque.opacity(0.15))
                .clipShape(Capsule())
                
                Button(action: { showProfile = true }) {
                    Image(systemName: "person.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showProfile) { ProfileView(logoutAction: logoutAction) }
    }
}
struct ExplorarView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""

    private var destaques: [ConteudoEducacional] {
        Array(appDataStore.conteudos.filter {
            ($0.categoria == "Artigo" || $0.categoria == "Video" || $0.categoria == "Ebook")
        }.shuffled().prefix(4))
    }

    private let coresCategorias: [String: Color] = ["E-books": .orange, "Artigos": .purple, "Vídeos": .teal]

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)

        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {

                    SearchBar(text: $searchText)
                        .padding(.horizontal)

                    VStack(alignment: .leading) {
                        Text("Destaques da Semana").font(.title2.weight(.bold)).padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(destaques) { item in
                                    NavigationLink(destination: ViewRouter(item: item)) {
                                        DestaquePrincipalCard(item: item).frame(width: 300)
                                    }
                                }
                            }.padding(.horizontal)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Explore por Categoria").font(.title2.weight(.bold)).padding(.horizontal)
                        HStack(spacing: 15) {
                            Spacer()
                            NavigationLink(destination: CategoriaListView(categoriaTitulo: "E-books", corCategoria: .orange, todosConteudos: appDataStore.conteudos)) {
                                CategoriaCard(title: "E-books", icon: "book.closed.fill", color: .orange)
                            }
                            NavigationLink(destination: CategoriaListView(categoriaTitulo: "Artigos", corCategoria: .purple, todosConteudos: appDataStore.conteudos)) {
                                CategoriaCard(title: "Artigos", icon: "newspaper.fill", color: .purple)
                            }
                            NavigationLink(destination: CategoriaListView(categoriaTitulo: "Vídeos", corCategoria: .teal, todosConteudos: appDataStore.conteudos)) {
                                CategoriaCard(title: "Vídeos", icon: "video.fill", color: .teal)
                            }
                            Spacer()
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dicas Rápidas para o Dia a Dia").font(.title2.weight(.bold)).padding(.horizontal)
                        DicaCard(text: "Reutilize a água do cozimento de vegetais (fria) para regar suas plantas.").padding(.horizontal)
                        DicaCard(text: "Separe o lixo orgânico para compostagem. Seu jardim agradece.").padding(.horizontal)
                    }
                    VStack(alignment: .leading) {
                        Text("O que a Comunidade Diz").font(.title2.weight(.bold)).padding(.horizontal)
                        FeedbackCard(text: "\"O curso de Hortas Urbanas mudou minha relação com a comida!\"", user: "Ana L.").padding(.horizontal)
                    }
                }.padding(.top)
            }
            .background(theme.fundo.ignoresSafeArea())
            .navigationTitle("Explorar")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Minigame (com WebView)

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

struct MinigameView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.colorScheme) var colorScheme
    let logoutAction: () -> Void
    
    @State private var showProfile = false
    
    private let gameURL = URL(string: "https://trex-runner.com/")!
    
    @State private var showPointsFeedback = false

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        
        NavigationView {
            ZStack {
                theme.fundo.ignoresSafeArea()

                VStack(spacing: 20) {
                    
                    Text("Toque na tela do jogo para começar!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)

                    WebView(url: gameURL)
                        .frame(height: 150)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    
                    Spacer()

                    Button(action: {
                        appDataStore.addPoints(10)
                        withAnimation {
                            showPointsFeedback = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showPointsFeedback = false
                            }
                        }
                    }) {
                        Label("Resgatar 10 Pontos", systemImage: "plus.circle.fill")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.corDestaque)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .corDestaque.opacity(0.5), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer().frame(height: 20)
                }
                
                if showPointsFeedback {
                    Text("+10 Pontos!")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.white)
                        .padding(20)
                        .background(Color.corFolhaClara.opacity(0.8))
                        .clipShape(Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        .zIndex(1)
                }
            }
            .navigationTitle("Jogar")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    HStack {
                        Text("\(appDataStore.userProfile?.points ?? 0)")
                            .font(.subheadline.weight(.bold))
                        Image(systemName: "star.fill")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundColor(.corDestaque)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.corDestaque.opacity(0.15))
                    .clipShape(Capsule())

                    Button(action: { showProfile = true }) {
                        Image(systemName: "person.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView(logoutAction: logoutAction)
            }
        }
    }
}


// MARK: - Views de Perfil e Configurações
struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appDataStore: AppDataStore
    let logoutAction: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    @State private var editingName: String = ""
    @State private var editingBio: String = ""
    @State private var isEditing: Bool = false

    @State private var showPrivacy = false

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)

        NavigationView {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 20) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                            VStack {
                                Group {
                                    if let profileImage = appDataStore.userProfileImage {
                                        profileImage.resizable().scaledToFill()
                                    } else if let profileURLString = appDataStore.userProfile?.profileImageURL, let url = URL(string: profileURLString) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image { image.resizable().scaledToFill() }
                                            else if phase.error != nil { Image(systemName: "person.circle.fill").resizable().scaledToFit().foregroundColor(.gray) }
                                            else { ProgressView() }
                                        }
                                    } else {
                                        Image(systemName: "person.circle.fill").resizable().scaledToFit().frame(width: 80, height: 80).foregroundColor(.gray)
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))

                                Text("Alterar Foto").font(.caption).foregroundColor(.accentColor)
                            }
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                guard let newItem = newItem, let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                                if let uiImage = UIImage(data: data) {
                                    appDataStore.userProfileImage = Image(uiImage: uiImage)
                                }
                                appDataStore.updateProfileImage(imageData: data)
                            }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                if isEditing {
                                    TextField("Nome", text: $editingName)
                                        .font(.title2.weight(.bold))
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    Text(appDataStore.userName).font(.title2.weight(.bold))
                                }
                                Spacer()
                                Button { saveChanges() } label: { Text(isEditing ? "Salvar" : "Editar") }.buttonStyle(.bordered)
                            }
                            
                            if isEditing {
                                VStack(alignment: .leading) {
                                    Text("Sobre mim:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    TextEditor(text: $editingBio)
                                        .frame(height: 80)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                                        .font(.body)
                                }
                                .padding(.top, 10)
                            } else {
                                Text(appDataStore.userBio.isEmpty ? "Sem bio ainda." : appDataStore.userBio)
                                    .font(.body)
                                    .foregroundColor(appDataStore.userBio.isEmpty ? .secondary : .primary)
                                    .lineLimit(3)
                                    .padding(.top, 10)
                            }
                        }
                    }
                    .padding(.vertical)
                }

                Section(header: Text("Conta")) {
                    NavigationLink(destination: PlanosView()) { Label("Ver Planos", systemImage: "creditcard.fill") }
                    Toggle(isOn: .constant(true)) { Label("Receber Notificações", systemImage: "bell.badge.fill") }

                    HStack {
                         Label("Meus Pontos", systemImage: "star.fill")
                         Spacer()
                         Text("\(appDataStore.userProfile?.points ?? 0) PTS")
                            .foregroundColor(.corDestaque)
                            .fontWeight(.bold)
                     }
                }

                Section(header: Text("Sobre")) {
                    Button { showPrivacy = true } label: { Label("Política de Privacidade", systemImage: "lock.shield.fill") }
                    HStack {
                         Label("Versão do App", systemImage: "info.circle.fill")
                         Spacer()
                         Text("1.0.3").foregroundColor(.secondary)
                     }
                }

                Section {
                    Button(role: .destructive) {
                        dismiss()
                        logoutAction()
                    } label: {
                        Label("Sair", systemImage: "rectangle.portrait.and.arrow.right.fill")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") {
                         saveChanges(andDismiss: true)
                    }
                }
            }
            .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
            .onAppear(perform: loadInitialEditingValues)
        }
    }

    private func loadInitialEditingValues() {
         isEditing = false
         editingName = appDataStore.userName
         editingBio = appDataStore.userBio
    }

    private func saveChanges(andDismiss: Bool = false) {
        if isEditing {
            let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBio = editingBio.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedName != appDataStore.userName && !trimmedName.isEmpty {
                appDataStore.updateUserName(newName: trimmedName)
            }

            if trimmedBio != appDataStore.userBio {
                appDataStore.updateUserBio(newBio: trimmedBio)
            }

            if andDismiss {
                isEditing = false
                dismiss()
            } else {
                 isEditing = false
            }
        } else {
            loadInitialEditingValues()
            isEditing = true
        }

        if !isEditing && andDismiss {
             dismiss()
         }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Política de Privacidade").font(.title.weight(.bold)).padding(.bottom)
                    Text("Última atualização: 23 de Outubro de 2025").font(.caption).foregroundColor(.secondary)

                    Text("Coleta de Dados").font(.title3.weight(.semibold))
                    Text("Coletamos informações que você nos fornece diretamente, como nome, e-mail e senha ao criar sua conta. Também coletamos dados de uso do aplicativo, como progresso nos cursos e interações na comunidade, para melhorar sua experiência.")

                    Text("Uso dos Dados").font(.title3.weight(.semibold))
                    Text("Usamos seus dados para operar e melhorar o aplicativo Leafy, personalizar seu conteúdo, responder às suas solicitações e enviar notificações relevantes (se permitido). Não compartilhamos seus dados pessoais com terceiros para fins de marketing sem seu consentimento explícito.")
                    Text("Armazenamento de Dados").font(.title3.weight(.semibold))
                    Text("Seus dados são armazenados de forma segura nos servidores do Firebase (Google Cloud). Tomamos medidas razoáveis para proteger suas informações contra acesso não autorizado.")
                    Text("Seus Direitos").font(.title3.weight(.semibold))
                    Text("Você tem o direito de acessar, corrigir ou solicitar a exclusão dos seus dados pessoais. Entre em contato conosco para exercer esses direitos.")
                    Text("Alterações na Política").font(.title3.weight(.semibold))
                    Text("Podemos atualizar esta política periodicamente. Notificaremos você sobre alterações significativas através do aplicativo ou por e-mail.")
                }.padding()
            }
            .navigationTitle("Política de Privacidade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("OK") { dismiss() } } }
        }
    }
}

// MARK: - Views de Autenticação e Onboarding

struct SplashScreenView: View {
    @State private var dropPosition: CGFloat = -UIScreen.main.bounds.midY
    @State private var dropScale: CGFloat = 1.0
    @State private var rippleScale: CGFloat = 0.0
    @State private var rippleOpacity: Double = 1.0
    @State private var backgroundScale: CGFloat = 0.0

    @State private var exitLeafScale: CGFloat = 0.01
    @State private var exitLeafOpacity: Double = 0.0
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)

            Circle().fill(Color.corFolhaClara).frame(width: 100, height: 100).scaleEffect(backgroundScale)

            ZStack {
                Circle().stroke(Color.corFolhaClara, lineWidth: 2).scaleEffect(rippleScale).opacity(rippleOpacity)
                Circle().stroke(Color.corFolhaClara, lineWidth: 1).scaleEffect(rippleScale * 1.5).opacity(rippleOpacity * 0.7)
            }
            Circle().fill(Color.corFolhaClara).frame(width: 30, height: 30).scaleEffect(dropScale).offset(y: dropPosition)

            Image(systemName: "leaf.fill").font(.system(size: 100)).foregroundColor(.white).scaleEffect(exitLeafScale).opacity(exitLeafOpacity)
        }
        .onAppear(perform: startAnimationSequence)
    }

    private func startAnimationSequence() {
        withAnimation(.easeIn(duration: 0.6)) { dropPosition = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { dropScale = 0.0 }
            withAnimation(.easeOut(duration: 1.0)) { rippleScale = 2.0; rippleOpacity = 0.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation(.easeIn(duration: 0.8)) { backgroundScale = 50 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.8)) { backgroundScale = 0.0; exitLeafScale = 1.0; exitLeafOpacity = 1.0 }
            withAnimation(.easeOut(duration: 0.2).delay(0.8)) { exitLeafOpacity = 0.0 }
        }
    }
}

struct MandatoryModulesView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.colorScheme) var colorScheme
    @Binding var showNextStep: Bool
    @State private var itemParaAceite: ConteudoEducacional?

    private var mandatoryModules: [ConteudoEducacional] {
        appDataStore.conteudos.filter { $0.isMandatory }
    }
    
    private var allMandatoryCompleted: Bool {
        let mandatoryIDs = Set(mandatoryModules.map { $0.id })
        return mandatoryIDs.isSubset(of: appDataStore.conteudosCompletos)
    }

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ScrollView {
            VStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Seja Bem-vindo(a) à Leafy!")
                        .font(.largeTitle.weight(.bold)).foregroundColor(theme.corTerra)
                    Text("Para começar sua jornada sustentável, precisamos que você complete alguns módulos introdutórios. Isso garante que todos na plataforma compartilhem nossos valores e objetivos.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(5)
                }.padding(.horizontal)

                VStack(spacing: 15) {
                    ForEach(Array(mandatoryModules.enumerated()), id: \.element.id) { index, item in
                        Button(action: { itemParaAceite = item }) {
                            ItemRowView(item: item, passoNumero: index + 1)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal)

                Spacer(minLength: 30)

                Button(action: {
                    if allMandatoryCompleted {
                        withAnimation { showNextStep = true }
                    }
                }) {
                    Label("Acessar a Plataforma", systemImage: "arrow.right.circle.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(allMandatoryCompleted ? Color.corFolhaClara : Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: allMandatoryCompleted ? .corFolhaClara.opacity(0.4) : .clear, radius: 5, y: 3)
                }
                .disabled(!allMandatoryCompleted)
                .padding(.horizontal)
                .padding(.bottom, 20)

            }
            .padding(.top, 40)
        }
        .background(theme.fundo.ignoresSafeArea())
        .sheet(item: $itemParaAceite) { item in
            ModuleView(item: item)
        }
    }
}
struct LoginView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @Binding var currentAuthScreen: AuthScreen
    @Binding var showTerms: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var email = ""
    @State private var senha = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    @State private var showForgotPassword = false

    @State private var viewOpacity = 0.0

    private func attemptLogin() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = senha.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            self.alertMessage = "Por favor, preencha o e-mail e a senha."; self.showAlert = true; return
        }
        Auth.auth().signIn(withEmail: trimmedEmail, password: trimmedPassword) { authResult, error in
            if let error = error {
                self.alertMessage = "Falha no login: \(error.localizedDescription)"
                self.showAlert = true
                print("ERRO LOGIN: \(error.localizedDescription)")
            } else {
                print("Login OK para UID: \(authResult?.user.uid ?? "N/A"). Listener do AppDataStore vai carregar o perfil.")
                if !UserDefaults.standard.bool(forKey: "hasAcceptedMainTerms") {
                    print("Termos não aceitos, mostrando termos.")
                    showTerms = true
                } else {
                    print("Termos já aceitos. AppDataStore listener prosseguirá.")
                }
            }
        }
    }

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ZStack(alignment: .topLeading) {
            theme.fundo.ignoresSafeArea()
            VStack {
                Spacer()
                Image(systemName: "leaf.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.corFolhaClara)
                    .padding(.bottom, 30)

                VStack(spacing: 30) {
                    Text("Bem-vindo(a)!").font(.largeTitle.weight(.bold)).foregroundColor(theme.corTerra)
                    VStack(spacing: 20) {
                        TextField("E-mail", text: $email).padding().background(theme.fundoCampoInput).cornerRadius(12).autocapitalization(.none).keyboardType(.emailAddress)
                        SecureField("Senha", text: $senha).padding().background(theme.fundoCampoInput).cornerRadius(12)

                        HStack {
                            Spacer()
                            Button("Esqueceu a senha?") {
                                showForgotPassword = true
                            }
                            .font(.caption.weight(.bold))
                            .foregroundColor(.corFolhaClara)
                        }
                        .padding(.top, -10)

                        Button(action: attemptLogin) { Text("Entrar").font(.body.weight(.bold)).frame(maxWidth: .infinity).padding().background(Color.corFolhaClara).foregroundColor(.white).cornerRadius(12).shadow(color: .corFolhaClara.opacity(0.5), radius: 10, x: 0, y: 5) }.padding(.top, 10)
                    }
                    Divider().padding(.vertical, 20)
                    Button { withAnimation { currentAuthScreen = .cadastro } } label: { VStack { Text("Não tem conta?").foregroundColor(.gray).font(.caption); Text("Crie uma agora!").font(.caption.weight(.bold)).foregroundColor(.corFolhaClara) } }
                }.padding(.horizontal, 40)
                Spacer()
            }
        }
        .sheet(isPresented: $showForgotPassword, onDismiss: {
            senha = ""
        }) {
            ForgotPasswordView()
                .environmentObject(appDataStore)
        }
        .alert(isPresented: $showAlert) { Alert(title: Text("Aviso de Login"), message: Text(alertMessage), dismissButton: .default(Text("OK"))) }
        .opacity(viewOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.5).delay(0.2)) {
                viewOpacity = 1.0
            }
        }
    }
}
struct TermsAndConditionsView: View {
    @Binding var showTerms: Bool
    @Binding var showMandatoryModules: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var accepted: Bool = false

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ZStack {
            Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                .onTapGesture { withAnimation { showTerms = false } }

            VStack(spacing: 20) {
                Text("Termos de Serviço").font(.title2.weight(.bold)).foregroundColor(theme.corTerra).padding(.top, 10)
                ScrollView {
                    Text("Bem-vindo à Leafy! Ao usar nosso aplicativo, você concorda com estes termos. Comprometemo-nos a fornecer conteúdo educacional sobre sustentabilidade. Seus dados serão tratados conforme nossa Política de Privacidade. O uso indevido da plataforma, incluindo discurso de ódio ou spam na comunidade, resultará na suspensão da conta. O conteúdo fornecido é para fins educacionais e não substitui aconselhamento profissional. Reservamo-nos o direito de atualizar estes termos a qualquer momento.")
                        .font(.body)
                        .lineSpacing(5)
                        .padding()
                }
                .frame(maxHeight: 350)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.5), lineWidth: 1))

                VStack(spacing: 15) {
                    Toggle(isOn: $accepted) { Text("Eu li e aceito os Termos.").foregroundColor(theme.corTerra) }.toggleStyle(.switch).tint(.corFolhaClara)
                    Button(action: {
                        if accepted {
                            UserDefaults.standard.set(true, forKey: "hasAcceptedMainTerms")
                            withAnimation {
                                showTerms = false
                            }
                        }
                    }) {
                        Text("Aceitar e Continuar")
                            .font(.body.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(accepted ? Color.corFolhaClara : Color.gray.opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }.disabled(!accepted)
                }.padding(.horizontal)

                Button("Voltar") { withAnimation { showTerms = false } }.foregroundColor(.gray).font(.footnote)

            }.padding(30).background(theme.fundo).cornerRadius(20).shadow(radius: 10).padding(20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}
struct CadastroView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @Binding var currentAuthScreen: AuthScreen
    @Environment(\.colorScheme) var colorScheme
    @State private var nome = ""
    @State private var email = ""
    @State private var senha = ""
    @State private var viewOpacity = 0.0

    @State private var showAlert = false
    @State private var alertTitle = "Cadastro"
    @State private var alertMessage = ""

    private func attemptCadastro() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = senha.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = nome.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
             self.alertTitle = "Campo Obrigatório"; self.alertMessage = "Por favor, preencha seu nome."; self.showAlert = true; return
         }
        guard !trimmedEmail.isEmpty, email.contains("@") else {
             self.alertTitle = "E-mail Inválido"; self.alertMessage = "Por favor, insira um e-mail válido."; self.showAlert = true; return
         }
        guard trimmedPassword.count >= 6 else {
            self.alertTitle = "Senha Curta"; self.alertMessage = "A senha deve ter no mínimo 6 caracteres."; self.showAlert = true; return
        }

        Auth.auth().createUser(withEmail: trimmedEmail, password: trimmedPassword) { authResult, error in
            if let error = error {
                self.alertTitle = "Erro no Cadastro"
                self.alertMessage = "Não foi possível criar a conta: \(error.localizedDescription)"
                self.showAlert = true
            } else if let user = authResult?.user {
                print("Usuário Auth criado: \(user.uid)")

                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = trimmedName
                changeRequest.commitChanges { err in
                    if let e = err { print("Erro ao definir DisplayName no Auth: \(e)") }
                    else { print("DisplayName definido no Auth com sucesso.") }
                }
                
                appDataStore.createUserProfile(userID: user.uid, name: trimmedName)

                do {
                    try Auth.auth().signOut()
                    print("Logout automático após cadastro realizado.")
                } catch {
                    print("Erro ao fazer signOut automático pós cadastro: \(error.localizedDescription)")
                }

                self.alertTitle = "Cadastro Realizado"
                self.alertMessage = "Conta criada com sucesso! Por favor, faça o login para continuar."
                self.showAlert = true
            }
        }
    }

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ZStack(alignment: .topLeading) {
            theme.fundo.ignoresSafeArea()
            VStack {
                Spacer()
                VStack(spacing: 25) {
                    Text("Criar Conta").font(.largeTitle.weight(.bold)).foregroundColor(theme.corTerra).padding(.bottom, 20)
                    VStack(spacing: 15) {
                        TextField("Nome Completo", text: $nome).padding().background(theme.fundoCampoInput).cornerRadius(12)
                        TextField("E-mail", text: $email).padding().background(theme.fundoCampoInput).cornerRadius(12).autocapitalization(.none).keyboardType(.emailAddress)
                        SecureField("Senha (mín. 6 caracteres)", text: $senha).padding().background(theme.fundoCampoInput).cornerRadius(12)
                        Button(action: attemptCadastro) { Text("Cadastrar").font(.body.weight(.bold)).frame(maxWidth: .infinity).padding().background(Color.corFolhaClara).foregroundColor(.white).cornerRadius(12).shadow(color: .corFolhaClara.opacity(0.5), radius: 10, x: 0, y: 5) }.padding(.top, 10)
                    }
                    Divider().padding(.vertical, 15)
                    Button { withAnimation { currentAuthScreen = .login } } label: { HStack { Text("Já tem uma conta?").foregroundColor(.gray); Text("Fazer Login").font(.body.weight(.bold)).foregroundColor(.corFolhaClara) } }
                }.padding(.horizontal, 40)
                Spacer()
            }
            Button(action: { withAnimation { currentAuthScreen = .login } }) { Image(systemName: "arrow.left.circle.fill").font(.title).foregroundColor(.gray.opacity(0.5)) }.padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertTitle == "Cadastro Realizado" {
                        withAnimation { currentAuthScreen = .login }
                    }
                }
            )
        }
        .opacity(viewOpacity)
        .onAppear { withAnimation(.easeIn(duration: 0.5)) { viewOpacity = 1.0 } }
    }
}


struct ForgotPasswordView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)

        NavigationView {
            ZStack {
                theme.fundo.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Redefinir Senha")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(theme.corTerra)
                        .padding(.bottom, 10)

                    Text("Digite seu e-mail cadastrado. Enviaremos um link para você redefinir sua senha.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 20)

                    TextField("E-mail", text: $email)
                        .padding()
                        .background(theme.fundoCampoInput)
                        .cornerRadius(12)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)

                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        Button(action: attemptPasswordReset) {
                            Text("Enviar E-mail")
                                .font(.body.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.corFolhaClara)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: .corFolhaClara.opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                        .padding(.top, 10)
                        .disabled(email.isEmpty)
                    }

                    Spacer()
                }
                .padding(40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if alertTitle == "Sucesso" {
                            dismiss()
                        }
                    }
                )
            }
        }
    }

    private func attemptPasswordReset() {
        isLoading = true
        Task {
            do {
                try await appDataStore.sendPasswordReset(email: email)
                self.alertTitle = "Sucesso"
                self.alertMessage = "E-mail enviado para \(email). Verifique sua caixa de entrada (e spam) para criar uma *nova* senha. Após redefinir, volte aqui e faça o login com ela."
            } catch {
                self.alertTitle = "Erro"
                self.alertMessage = error.localizedDescription
            }
            self.isLoading = false
            self.showAlert = true
        }
    }
}


// MARK: - View Principal (ContentView)

struct ContentView: View {
    @EnvironmentObject var appDataStore: AppDataStore

    @State private var showSplash: Bool = true
    @State private var currentAuthScreen: AuthScreen = .login
    @State private var showTerms: Bool = false

    @State private var mandatoryModulesPresentedThisSession: Bool = false
    
    @State private var authOpacity: Double = 0.0

    var body: some View {
        ZStack {
            if let userProfile = appDataStore.userProfile {
                let needsMandatory = !mandatoryModulesPresentedThisSession && !allMandatoryCompleted

                if needsMandatory {
                    MandatoryModulesView(showNextStep: $mandatoryModulesPresentedThisSession)
                        .transition(.opacity)
                        .zIndex(2)
                } else {
                    MainView(logoutAction: logout)
                        .transition(.opacity)
                }
            } else {
                ZStack {
                    if showSplash {
                        SplashScreenView()
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        showSplash = false
                                    }
                                    withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
                                        authOpacity = 1.0
                                    }
                                }
                            }
                    } else {
                        switch currentAuthScreen {
                        case .login:
                            LoginView(currentAuthScreen: $currentAuthScreen, showTerms: $showTerms)
                        case .cadastro:
                            CadastroView(currentAuthScreen: $currentAuthScreen)
                        }
                    }
                }
                .opacity(showSplash ? 1.0 : authOpacity)
                .transition(.opacity)

                if showTerms {
                    TermsAndConditionsView(showTerms: $showTerms, showMandatoryModules: .constant(false))
                        .zIndex(1)
                }
            }
        }
    }

    private var allMandatoryCompleted: Bool {
        let mandatoryIDs = Set(appDataStore.conteudos.filter { $0.isMandatory }.map { $0.id })
        return mandatoryIDs.isSubset(of: appDataStore.conteudosCompletos)
    }

    private func logout() {
        do {
            try Auth.auth().signOut()
            print("Logout action initiated.")
            mandatoryModulesPresentedThisSession = false
            showTerms = false
            currentAuthScreen = .login
            authOpacity = 1.0
        } catch let signOutError as NSError {
            print("Erro ao fazer logout: %@", signOutError)
        }
    }
}

// MARK: - Componentes de Exploração (Cards)
struct SearchBar: View {
    @Binding var text: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray).padding(.leading, 8)
            TextField("Pesquisar conteúdo...", text: $text).padding(.vertical, 10).padding(.horizontal, 5).background(.clear)
        }
        .padding(.horizontal, 8)
        .background(theme.fundoCampoInput.opacity(0.8))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}
struct DestaquePrincipalCard: View {
    let item: ConteudoEducacional

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                gradient: Gradient(colors: [item.cor.opacity(0.9), item.cor]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .shadow(color: item.cor.opacity(0.4), radius: 8, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: item.icone)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.25))
                    .cornerRadius(12)
                Spacer()
                Text(item.titulo)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(item.subtitulo)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .padding(20)
        }
        .frame(height: 220)
        .cornerRadius(20)
    }
}
struct CategoriaCard: View {
    let title: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title.weight(.semibold)).foregroundColor(color)
            Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
        }
        .frame(width: 90, height: 90)
        .background(theme.fundoCard)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
    }
}
struct DicaCard: View {
    let text: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill").foregroundColor(.corDestaque).font(.title2).padding(.top, 4)
            Text(text).font(.body).foregroundColor(.primary)
            Spacer()
        }.padding(15).background(theme.fundoCard).cornerRadius(15).shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
    }
}
struct FeedbackCard: View {
    let text: String
    let user: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "quote.opening").font(.headline).foregroundColor(.corFolhaClara.opacity(0.7))
            Text(text).font(.body.italic()).foregroundColor(.primary)
            Text("- \(user)").font(.caption.weight(.bold)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
        }.padding(15).background(theme.fundoCard).cornerRadius(15).shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
    }
}


// MARK: - Previews

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppDataStore())

        NavigationView {
             CategoriaListView(categoriaTitulo: "Artigo", corCategoria: .purple, todosConteudos: AppDataStore().conteudos)
                 .environmentObject(AppDataStore())
         }
        .previewDisplayName("Lista Categoria Artigo")

        MandatoryModulesView(showNextStep: .constant(false))
            .environmentObject(AppDataStore())
            .previewDisplayName("Primeiros Passos")

        NavigationView{
            MinigameView(logoutAction: {})
                .environmentObject(AppDataStore())
        }
        .previewDisplayName("Minigame View")
    }
}
