import SwiftUI
import Combine
import Foundation
import SafariServices
import FirebaseAuth
import FirebaseFirestore // Base Firestore
// FirebaseFirestoreSwift REMOVIDO
import FirebaseStorage
import PhotosUI

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
    var isMandatoryFor: [UserRole]? = nil
    var link: String? = nil
    var autor: String? = nil
    var duracao: String? = nil
}

struct Plano: Identifiable {
    let id = UUID()
    let nome: String, preco: String
    let features: [String], cor: Color
    let isRecommended: Bool
}

// REMOVIDA: struct ChatMessageFirebase (não necessária sem FirestoreSwift)

// Struct principal do Chat (Date)
struct ChatMessage: Identifiable, Equatable {
    let id: String // ID do Documento Firestore
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
}

enum UserRole: String, CaseIterable, Codable {
    case estudante = "Estudante"
    case educador = "Educador"
}

// Struct para dados do usuário no Firestore (Codable para AppDataStore)
struct UserProfile: Codable, Identifiable {
    // Não precisa de @DocumentID se não usar FirestoreSwift
    var id: String? // Mapeia o UID do Auth
    var name: String
    var role: UserRole
    var profileImageURL: String?
}


class AppDataStore: ObservableObject {
    @Published var conteudos: [ConteudoEducacional]
    @Published var conteudosCompletos: Set<UUID> = []
    
    @Published var userProfile: UserProfile? = nil
    @Published var userRole: UserRole? = nil
    @Published var userName: String = "Visitante"
    @Published var userProfileImage: Image? = nil

    @Published var chatMessages: [ChatMessage] = []
    
    private var db = Firestore.firestore()
    private var storage = Storage.storage()
    
    private var chatListenerRegistration: ListenerRegistration?
    private var userProfileListenerRegistration: ListenerRegistration?

    init() {
        self.conteudos = [
             ConteudoEducacional(titulo: "Missões e Valores", subtitulo: "Módulo Obrigatório", descricaoCurta: "Conheça os pilares da plataforma Leafy.", icone: "heart.fill", cor: .pink, categoria: "Institucional", nivel: "Todos", isMandatoryFor: [.estudante, .educador]),
            ConteudoEducacional(titulo: "Compreender o Mercado Sustentável", subtitulo: "Módulo Obrigatório", descricaoCurta: "Sustentabilidade e o futuro profissional.", icone: "briefcase.fill", cor: .indigo, categoria: "Carreira", nivel: "Iniciante", isMandatoryFor: [.estudante]),
            ConteudoEducacional(titulo: "Clima e Sustentabilidade", subtitulo: "Trilha Essencial", descricaoCurta: "Entenda as mudanças climáticas e ações locais.", icone: "cloud.sun.rain.fill", cor: .orange, categoria: "Curso", nivel: "Iniciante"),
            ConteudoEducacional(titulo: "Hortas Urbanas e Permacultura", subtitulo: "Curso Prático", descricaoCurta: "Guia completo de plantio em pequenos espaços.", icone: "leaf.fill", cor: .corFolhaClara, categoria: "Curso", nivel: "Iniciante"),
            ConteudoEducacional(titulo: "Reciclagem e Economia Circular", subtitulo: "Curso Completo", descricaoCurta: "Técnicas e a economia circular.", icone: "arrow.triangle.2.circlepath", cor: .blue, categoria: "Curso", nivel: "Avançado"),
            ConteudoEducacional(titulo: "Energias Renováveis do Futuro", subtitulo: "Curso Técnico", descricaoCurta: "Explore a energia solar, eólica e outras fontes limpas.", icone: "wind", cor: .cyan, categoria: "Curso", nivel: "Avançado"),
            ConteudoEducacional(titulo: "Guia de Compostagem Caseira", subtitulo: "E-book Gratuito", descricaoCurta: "Transforme resíduos orgânicos em adubo de alta qualidade.", icone: "book.closed.fill", cor: Color(red: 0.2, green: 0.15, blue: 0.05), categoria: "Ebook", nivel: "Iniciante", link: "https://www.infoteca.cnptia.embrapa.br/infoteca/bitstream/doc/1019253/1/cartilhacompostagem.pdf"),
            ConteudoEducacional(titulo: "Manual Completo do Lixo Zero", subtitulo: "E-book Completo", descricaoCurta: "Um guia com os princípios para reduzir sua geração de lixo.", icone: "trash.slash.fill", cor: .gray, categoria: "Ebook", nivel: "Avançado"),
            ConteudoEducacional(titulo: "5 Atitudes para um Planeta Mais Saudável", subtitulo: "Artigo da Comunidade", descricaoCurta: "Pequenas mudanças de hábito que fazem a diferença.", icone: "newspaper.fill", cor: .purple, categoria: "Artigo", nivel: "Todos", autor: "Equipe Leafy"),
            ConteudoEducacional(titulo: "A Importância Vital das Abelhas", subtitulo: "Artigo Científico", descricaoCurta: "Entenda o papel vital dos polinizadores no nosso ecossistema.", icone: "ladybug.fill", cor: .red, categoria: "Artigo", nivel: "Intermediário", autor: "Dr. Silva"),
            ConteudoEducacional(titulo: "Como Montar sua Horta Vertical", subtitulo: "Vídeo Tutorial", descricaoCurta: "Passo a passo para criar uma horta em apartamentos.", icone: "video.fill", cor: .teal, categoria: "Video", nivel: "Iniciante", duracao: "12 min"),
            ConteudoEducacional(titulo: "Documentário: Oceanos de Plástico", subtitulo: "Documentário Impactante", descricaoCurta: "Uma visão aprofundada sobre a poluição marinha.", icone: "film.fill", cor: .blue, categoria: "Video", nivel: "Todos", duracao: "45 min")
        ]
        
        setupAuthListener()
        listenToChatMessages()
    }

    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            guard let self = self else { return }
            if let user = user {
                print("Auth state changed: User logged in (\(user.uid)). Starting profile listener.")
                self.listenToUserProfile(userID: user.uid)
            } else {
                print("Auth state changed: User logged out. Stopping listeners.")
                self.stopListening()
                self.userProfile = nil
                self.userRole = nil
                self.userName = "Visitante"
                self.userProfileImage = nil
                self.chatMessages = []
            }
        }
    }

    // Leitura manual do perfil (sem FirestoreSwift)
    func listenToUserProfile(userID: String) {
        userProfileListenerRegistration?.remove()

        userProfileListenerRegistration = db.collection("users").document(userID)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot, document.exists else {
                    print("Erro ao buscar perfil ou perfil não existe: \(error?.localizedDescription ?? "No data")")
                    return
                }
                
                let data = document.data()
                let name = data?["name"] as? String ?? "Usuário Desconhecido"
                let roleString = data?["role"] as? String ?? UserRole.estudante.rawValue
                let profileImageURL = data?["profileImageURL"] as? String
                let role = UserRole(rawValue: roleString) ?? .estudante
                let profile = UserProfile(id: document.documentID, name: name, role: role, profileImageURL: profileImageURL)
                
                self.userProfile = profile
                self.userName = profile.name
                self.userRole = profile.role
                print("Perfil carregado/atualizado manualmente: \(profile.name)")

                if let imageURLString = profile.profileImageURL, let _ = URL(string: imageURLString) {
                    // Lógica para baixar a imagem pode ser feita na ProfileView com AsyncImage
                } else {
                    self.userProfileImage = nil
                }
            }
    }
    
    // Leitura manual do chat (sem FirestoreSwift)
    func listenToChatMessages() {
        chatListenerRegistration?.remove()
        
        chatListenerRegistration = db.collection("chatMessages")
            .order(by: "timestamp", descending: false)
            .limit(toLast: 50)
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Erro ao buscar mensagens: \(error?.localizedDescription ?? "Erro desconhecido")")
                    return
                }
                
                self.chatMessages = documents.compactMap { document -> ChatMessage? in
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
            }
    }

    // Envio manual do chat (sem FirestoreSwift)
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let userID = Auth.auth().currentUser?.uid,
              let currentUserName = self.userProfile?.name else {
            print("Usuário não logado, perfil não carregado ou mensagem vazia.")
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
    
    // Criação manual do perfil (sem FirestoreSwift)
    func createUserProfile(userID: String, name: String, role: UserRole) {
        let profileData: [String: Any] = [
            "name": name,
            "role": role.rawValue,
            "profileImageURL": NSNull()
        ]
        
        db.collection("users").document(userID).setData(profileData) { error in
            if let error = error { print("Erro ao criar perfil inicial: \(error)") }
            else { print("Perfil inicial criado para o usuário \(userID)") }
        }
    }

    // Funções de updateUserName e updateProfileImage já funcionam manualmente
    func updateUserName(newName: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        guard self.userProfile != nil else { return }

        db.collection("users").document(userID).updateData(["name": newName]) { error in
            if let error = error { print("Erro ao atualizar nome no Firestore: \(error)") }
            else { print("Nome atualizado com sucesso no Firestore") }
        }

        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
        changeRequest?.displayName = newName
        changeRequest?.commitChanges { error in
            if let error = error { print("Erro ao atualizar DisplayName no Auth: \(error)") }
            else { print("DisplayName atualizado com sucesso no Auth") }
        }
    }

    func updateProfileImage(imageData: Data) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let storageRef = storage.reference().child("profileImages/\(userID).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        storageRef.putData(imageData, metadata: metadata) { metadata, error in
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
                    if let error = error { print("Erro ao salvar URL da imagem no Firestore: \(error)") }
                    else { print("URL da imagem atualizada com sucesso no Firestore") }
                }
            }
        }
    }

    func stopListening() {
        chatListenerRegistration?.remove()
        userProfileListenerRegistration?.remove()
    }

    func toggleCompletion(for item: ConteudoEducacional) {
        if conteudosCompletos.contains(item.id) { conteudosCompletos.remove(item.id) }
        else { conteudosCompletos.insert(item.id) }
    }
    
     deinit {
         stopListening()
     }
}

// (Restante das Views - AuthScreen, AppTheme, TagModifier, etc. - continuam aqui, sem alterações até ContentView)
enum AuthScreen { case welcome, login, cadastro }

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

struct EscolasView: View {
    let logoutAction: () -> Void
    @State private var showProfile = false
    var body: some View { NavigationView { Text("Área de Gestão de Escolas").font(.largeTitle).navigationTitle("Escolas")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showProfile = true }) { Image(systemName: "person.circle.fill") }
        } }
        .sheet(isPresented: $showProfile) { ProfileView(logoutAction: logoutAction) }
    } }
}
struct ChatsProducaoView: View {
    var body: some View { NavigationView { Text("Chats de Produção e Suporte").navigationTitle("Produção") } }
}

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
                .onChange(of: appDataStore.chatMessages) {
                    if let lastMessage = appDataStore.chatMessages.last {
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

struct EducadorMainView: View {
    let logoutAction: () -> Void
    var body: some View {
        TabView {
            NavigationView { EscolasView(logoutAction: logoutAction) }.tabItem { Label("Escolas", systemImage: "building.2.fill") }
            NavigationView { ChatsProducaoView() }.tabItem { Label("Produção", systemImage: "bubble.left.and.bubble.right.fill") }
            NavigationView { CursosView(logoutAction: logoutAction) }.tabItem { Label("Cursos", systemImage: "books.vertical.fill") }
        }.accentColor(.corFolhaClara)
    }
}

struct EstudanteMainView: View {
    let logoutAction: () -> Void
    var body: some View {
        TabView {
            NavigationView { CursosView(logoutAction: logoutAction) }.tabItem { Label("Cursos", systemImage: "book.fill") }
            NavigationView { ExplorarView() }.tabItem { Label("Explorar", systemImage: "sparkles") }
            NavigationView { ComunidadeChatView() }.tabItem { Label("Comunidade", systemImage: "person.3.fill") }
        }.accentColor(.corFolhaClara)
    }
}

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
                    Text("Este módulo introdutório explora os conceitos fundamentais de \(item.titulo.lowercased()). Abordaremos os principais desafios e as soluções mais eficazes que você pode aplicar no seu dia a dia para promover um impacto positivo e duradouro no meio ambiente. O conteúdo foi desenhado para ser prático e de fácil compreensão.").lineSpacing(5)
                    Divider()
                    Button(action: {
                        appDataStore.toggleCompletion(for: item)
                        dismiss()
                    }) {
                        Label(isCompleto ? "Desmarcar" : "Marcar como Concluído", systemImage: isCompleto ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.headline.weight(.bold)).frame(maxWidth: .infinity).padding().background(isCompleto ? Color.gray : Color.corFolhaClara).foregroundColor(.white).cornerRadius(12)
                    }
                }.padding()
            }.background(theme.fundo.ignoresSafeArea()).navigationTitle(item.titulo).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Fechar") { dismiss() } } }
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
                HStack {
                    Image(systemName: item.icone).resizable().aspectRatio(contentMode: .fit).frame(width: 50, height: 50).foregroundColor(item.cor)
                    VStack(alignment: .leading) {
                        Text(item.titulo).font(.largeTitle.weight(.heavy)).foregroundColor(theme.corTerra)
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
                Button("Iniciar Módulo") { showModulo = true }.buttonStyle(.borderedProminent).tint(.corFolhaClara).controlSize(.large).padding(.top, 10)
            }.padding()
        }.background(theme.fundo.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline).navigationTitle(item.titulo)
        .sheet(isPresented: $showModulo) { ModuleView(item: item).environmentObject(appDataStore) }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {}
}

struct EbookReaderView: View {
    let ebook: ConteudoEducacional
    @State private var showSafari = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: ebook.icone)
                .font(.system(size: 80))
                .foregroundColor(ebook.cor)
            
            Text(ebook.titulo).font(.largeTitle.weight(.bold))
            Text(ebook.descricaoCurta).font(.title3).foregroundColor(.secondary).multilineTextAlignment(.center)
            
            if let link = ebook.link, let _ = URL(string: link) {
                Button("Ler E-book Agora") {
                    showSafari = true
                }
                .font(.headline.weight(.bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.corFolhaClara)
                .foregroundColor(.white)
                .cornerRadius(12)
            } else {
                Text("Conteúdo em breve")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
        }
        .padding(40)
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: ebook.link!) {
                SafariView(url: url)
            }
        }
    }
}

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
                        .frame(width: 30, height: 30)
                    Text("\(passo)")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                }
            }
            
            Image(systemName: item.icone)
                .font(.title2)
                .foregroundColor(item.cor)
                .frame(width: 40, height: 40)
                .background(item.cor.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
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
                    .font(.title2)
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

    init(curso: ConteudoEducacional) {
        self.curso = curso
        _progress = State(initialValue: [0.2, 0.5, 0.8, 0.95].randomElement()!)
    }
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: curso.icone)
                .font(.system(size: 28))
                .foregroundColor(curso.cor)
                .frame(width: 60, height: 60)
                .background(curso.cor.opacity(0.15))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 5) {
                Text(curso.nivel.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.secondary)
                Text(curso.titulo)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                ProgressView(value: progress, total: 1.0)
                    .tint(curso.cor)
                    .scaleEffect(x: 1, y: 0.8, anchor: .center)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}


struct CursosView: View {
    let logoutAction: () -> Void
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.colorScheme) var colorScheme
    @State private var showProfile = false
    
    private var cursosEmDestaque: [ConteudoEducacional] { Array(appDataStore.conteudos.filter { $0.categoria == "Curso" }.prefix(1)) }
    private var todasAsTrilhas: [ConteudoEducacional] { appDataStore.conteudos.filter { !($0.isMandatoryFor != nil) && $0.categoria == "Curso" } }
    
    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if let destaque = cursosEmDestaque.first {
                    VStack(alignment: .leading) {
                        Text("Continue sua Jornada").font(.title2.weight(.bold)).foregroundColor(theme.corTerra).padding(.horizontal)
                        NavigationLink(destination: DetailView(item: destaque)) {
                            DestaquePrincipalCard(item: destaque)
                        }
                        .padding(.horizontal)
                    }
                }
                
                Text("Trilhas de Aprendizagem").font(.title2.weight(.bold)).foregroundColor(theme.corTerra).padding(.horizontal)
                
                LazyVStack(spacing: 15) {
                    ForEach(todasAsTrilhas) { curso in
                        NavigationLink(destination: DetailView(item: curso)) {
                            CursoCardView(curso: curso)
                        }
                    }
                }
                .padding(.horizontal)
                
            }.padding(.top)
        }
        .buttonStyle(.plain)
        .background(theme.fundo.ignoresSafeArea())
        .navigationTitle("Cursos")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showProfile = true }) { Image(systemName: "person.circle.fill") }
            }
        }
        .sheet(isPresented: $showProfile) { ProfileView(logoutAction: logoutAction) }
    }
}


struct ExplorarView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedItem: ConteudoEducacional?
    @State private var searchText = ""
    
    private var ebooks: [ConteudoEducacional] { appDataStore.conteudos.filter { $0.categoria == "Ebook" } }
    private var articles: [ConteudoEducacional] { appDataStore.conteudos.filter { $0.categoria == "Artigo" } }
    private var videos: [ConteudoEducacional] { appDataStore.conteudos.filter { $0.categoria == "Video" } }
    private var destaques: [ConteudoEducacional] { Array(appDataStore.conteudos.shuffled().prefix(3)) }

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
                                    NavigationLink(destination: DetailView(item: item)) {
                                        DestaquePrincipalCard(item: item).frame(width: 300)
                                    }
                                }
                            }.padding(.horizontal)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Explore por Categoria").font(.title2.weight(.bold)).padding(.horizontal)
                        HStack(spacing: 20) {
                            Spacer()
                            CategoriaCard(title: "E-books", icon: "book.closed.fill", color: .orange)
                            CategoriaCard(title: "Artigos", icon: "newspaper.fill", color: .purple)
                            CategoriaCard(title: "Vídeos", icon: "video.fill", color: .teal)
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
            .sheet(item: $selectedItem) { item in
                if item.categoria == "Ebook" { EbookReaderView(ebook: item) }
                else { DetailView(item: item) }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appDataStore: AppDataStore
    let logoutAction: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    
    @State private var editingName: String = ""
    @State private var isEditing: Bool = false

    @State private var showPrivacy = false

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 20) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                            VStack {
                                if let profileImage = appDataStore.userProfileImage {
                                    profileImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else if let profileURLString = appDataStore.userProfile?.profileImageURL, let url = URL(string: profileURLString) {
                                      AsyncImage(url: url) { phase in
                                          if let image = phase.image { image.resizable().scaledToFill() }
                                          else if phase.error != nil { Image(systemName: "person.circle.fill").resizable().scaledToFit().foregroundColor(.gray) }
                                          else { ProgressView() }
                                      }
                                      .frame(width: 80, height: 80)
                                      .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable().scaledToFit().frame(width: 80, height: 80).foregroundColor(.gray)
                                }
                                Text("Alterar Foto").font(.caption).foregroundColor(.accentColor)
                            }
                        }
                        .onChange(of: selectedPhotoItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                    if let uiImage = UIImage(data: data) {
                                        appDataStore.userProfileImage = Image(uiImage: uiImage)
                                        appDataStore.updateProfileImage(imageData: data)
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            if isEditing {
                                TextField("Nome", text: $editingName)
                                    .font(.title2.weight(.bold))
                                    .textFieldStyle(.roundedBorder)
                                    .onAppear { editingName = appDataStore.userName }
                            } else {
                                Text(appDataStore.userName).font(.title2.weight(.bold))
                            }
                            Text(appDataStore.userRole?.rawValue ?? "Usuário").font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Button {
                            if isEditing {
                                if editingName != appDataStore.userName {
                                    appDataStore.updateUserName(newName: editingName)
                                }
                            }
                            isEditing.toggle()
                        } label: { Text(isEditing ? "Salvar" : "Editar") }.buttonStyle(.bordered)
                        
                    }
                    .padding(.vertical)
                }
                
                Section(header: Text("Conta")) {
                    if appDataStore.userRole == .estudante {
                        NavigationLink(destination: PlanosView()) { Label("Ver Planos", systemImage: "creditcard.fill") }
                    }
                    Toggle(isOn: .constant(true)) { Label("Receber Notificações", systemImage: "bell.badge.fill") }
                }
                
                Section(header: Text("Sobre")) {
                    Button { showPrivacy = true } label: { Label("Política de Privacidade", systemImage: "lock.shield.fill") }
                    HStack {
                         Label("Versão do App", systemImage: "info.circle.fill")
                         Spacer()
                         Text("1.0.0").foregroundColor(.secondary)
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
                         if isEditing {
                             if editingName != appDataStore.userName { appDataStore.updateUserName(newName: editingName) }
                             isEditing = false
                         }
                         dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
            .onAppear {
                 isEditing = false
                 editingName = appDataStore.userName
            }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("OK") { dismiss() } } }
        }
    }
}

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


struct WelcomeView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @Binding var currentAuthScreen: AuthScreen
    @State private var leafRotation: Angle = .degrees(-180)
    @State private var leafOffset: CGFloat = -200
    @State private var leafOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var buttonOffset: CGFloat = 200
    
    @State private var defaultRole: UserRole = .estudante
    
    private func selectRole(_ role: UserRole) {
        appDataStore.userRole = role
        defaultRole = role
        withAnimation { currentAuthScreen = .login }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "leaf.fill").font(.system(size: 100)).foregroundColor(.corFolhaClara).rotationEffect(leafRotation).offset(y: leafOffset).opacity(leafOpacity)
            VStack {
                Text("LEAFY").font(.system(size: 60, weight: .black, design: .rounded)).foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.05))
                Text("Sua jornada para um futuro mais verde começa aqui.").font(.title3).foregroundColor(.secondary).multilineTextAlignment(.center)
            }.opacity(textOpacity).padding(.horizontal)
            Spacer(); Spacer()
            VStack(spacing: 20) {
                Button(action: { selectRole(.estudante) }) { Label("Sou Estudante", systemImage: "person.fill").font(.headline.weight(.bold)).frame(maxWidth: .infinity).padding().background(Color.corFolhaClara).foregroundColor(.white).cornerRadius(12) }.offset(y: buttonOffset)
                Button(action: { selectRole(.educador) }) { Label("Sou Educador", systemImage: "graduationcap.fill").font(.headline.weight(.bold)).frame(maxWidth: .infinity).padding().background(Color.corDestaque).foregroundColor(.white).cornerRadius(12) }.offset(y: buttonOffset)
            }
        }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity).background(LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.1), .white]), startPoint: .top, endPoint: .bottom).ignoresSafeArea()).onAppear(perform: startAnimation)
    }
    
    private func startAnimation() {
        withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2)) { leafRotation = .degrees(0); leafOffset = 0; leafOpacity = 1.0 }
        withAnimation(.easeIn(duration: 0.8).delay(0.8)) { textOpacity = 1.0 }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.2)) { buttonOffset = 0 }
    }
}

struct MissionAndValuesView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.dismiss) var dismiss
    let item: ConteudoEducacional

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Nossa Missão").font(.title2.weight(.bold))
                        Text("Acreditamos que a educação é a semente para um futuro sustentável...") // Conteúdo omitido para brevidade
                        Text("Nossos Valores").font(.title2.weight(.bold))
                        Text("**Ação Local, Impacto Global:** ...")
                        Text("**Conhecimento Acessível:** ...")
                    }.padding()
                }
                Button(action: {
                    if !appDataStore.conteudosCompletos.contains(item.id) { appDataStore.toggleCompletion(for: item) }
                    dismiss()
                }) { Text("Compreendo e aceito estes valores").font(.headline.weight(.bold)).frame(maxWidth: .infinity).padding().background(Color.corFolhaClara).foregroundColor(.white).cornerRadius(12) }.padding()
            }.navigationTitle("Missão e Valores").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Fechar") { dismiss() } } }
        }
    }
}

struct MandatoryModulesView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.colorScheme) var colorScheme
    @Binding var isAuthenticated: Bool
    @State private var itemParaAceite: ConteudoEducacional?

    private var mandatoryModules: [ConteudoEducacional] {
        guard let role = appDataStore.userRole else { return [] }
        return appDataStore.conteudos.filter { $0.isMandatoryFor?.contains(role) ?? false }
    }
    
    private var allMandatoryCompleted: Bool {
        let mandatoryIDs = Set(mandatoryModules.map { $0.id })
        return mandatoryIDs.isSubset(of: appDataStore.conteudosCompletos)
    }

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 30)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Seja Bem-vindo à Leafy!").font(.largeTitle.weight(.bold)).foregroundColor(theme.corTerra)
                    Text("Para começar sua jornada sustentável...").font(.body).foregroundColor(.secondary) // Conteúdo omitido
                }.padding(.horizontal)
                VStack(spacing: 15) {
                    ForEach(Array(mandatoryModules.enumerated()), id: \.element.id) { index, item in
                        Button(action: { itemParaAceite = item }) { ItemRowView(item: item, passoNumero: index + 1) }.buttonStyle(.plain)
                    }
                }.padding(.horizontal)
                Spacer()
                Button(action: { withAnimation { isAuthenticated = true } }) { Label("Acessar a Plataforma", systemImage: "arrow.right.circle.fill").font(.headline.weight(.bold)).frame(maxWidth: .infinity).padding().background(allMandatoryCompleted ? Color.corFolhaClara : Color.gray).foregroundColor(.white).cornerRadius(12) }.disabled(!allMandatoryCompleted).padding(.horizontal).padding(.bottom, 30)
            }
        }.background(theme.fundo.ignoresSafeArea()).sheet(item: $itemParaAceite) { item in
            if item.titulo == "Missões e Valores" { MissionAndValuesView(item: item) } else { ModuleView(item: item) }
        }
    }
}


struct LoginView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @Binding var currentAuthScreen: AuthScreen
    @Binding var showTerms: Bool
    @Binding var showMandatoryModules: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var email = ""
    @State private var senha = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var viewOpacity = 0.0
    
    private func attemptLogin() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = senha.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            self.alertMessage = "Por favor, preencha o e-mail e a senha."; self.showAlert = true; return
        }
        Auth.auth().signIn(withEmail: trimmedEmail, password: trimmedPassword) { authResult, error in
            if let error = error {
                self.alertMessage = "Credenciais inválidas."; self.showAlert = true; print("ERRO LOGIN: \(error.localizedDescription)")
            } else {
                print("Login OK: \(authResult?.user.uid ?? "")")
                if UserDefaults.standard.bool(forKey: "hasAcceptedMainTerms") { showMandatoryModules = true } else { showTerms = true }
            }
        }
    }
    
    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ZStack(alignment: .topLeading) {
            VStack {
                Spacer()
                VStack {
                    Text("Bem-vindo!").font(.largeTitle.weight(.bold)).foregroundColor(theme.corTerra).padding(.bottom, 40)
                    VStack(spacing: 25) {
                        TextField("E-mail", text: $email).padding().background(theme.fundoCampoInput).cornerRadius(12).autocapitalization(.none).keyboardType(.emailAddress)
                        SecureField("Senha", text: $senha).padding().background(theme.fundoCampoInput).cornerRadius(12)
                        Button(action: attemptLogin) { Text("Entrar").font(.body.weight(.bold)).frame(maxWidth: .infinity).padding().background(Color.corFolhaClara).foregroundColor(.white).cornerRadius(12).shadow(color: .corFolhaClara.opacity(0.5), radius: 10, x: 0, y: 5) }.padding(.top, 20)
                    }
                    Divider().padding(.vertical, 40)
                    Button { withAnimation { currentAuthScreen = .cadastro } } label: { VStack { Text("Não tem conta?").foregroundColor(.gray).font(.caption); Text("Crie uma agora!").font(.caption.weight(.bold)).foregroundColor(.corFolhaClara) } }
                }.padding(.horizontal, 40)
                Spacer()
            }.padding(.horizontal, 30).background(theme.fundo.ignoresSafeArea())
            Button(action: { withAnimation { currentAuthScreen = .welcome } }) { Image(systemName: "arrow.left.circle.fill").font(.title).foregroundColor(.gray.opacity(0.5)) }.padding()
        }.alert(isPresented: $showAlert) { Alert(title: Text("Aviso de Login"), message: Text(alertMessage), dismissButton: .default(Text("OK"))) }.opacity(viewOpacity).onAppear { withAnimation(.easeIn(duration: 0.5)) { viewOpacity = 1.0 } }
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
            Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
            VStack(spacing: 20) {
                Text("Termos de Serviço").font(.title2.weight(.bold)).foregroundColor(theme.corTerra).padding(.top, 10)
                ScrollView { Text("Bem-vindo à Leafy...").font(.body).padding() }.frame(maxHeight: 350).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                VStack(spacing: 15) {
                    Toggle(isOn: $accepted) { Text("Eu li e aceito os Termos.").foregroundColor(theme.corTerra) }.toggleStyle(.switch).tint(.corFolhaClara)
                    Button(action: { if accepted { UserDefaults.standard.set(true, forKey: "hasAcceptedMainTerms"); withAnimation { showTerms = false; showMandatoryModules = true } } }) { Text("Aceitar").font(.body.weight(.bold)).frame(maxWidth: .infinity).padding().background(accepted ? Color.corFolhaClara : Color.gray).foregroundColor(.white).cornerRadius(12) }.disabled(!accepted)
                }.padding(.horizontal)
                Button("Voltar") { withAnimation { showTerms = false } }.foregroundColor(.gray)
            }.padding(30).background(theme.fundo).cornerRadius(20).shadow(radius: 10).padding(20)
        }
    }
}

struct CadastroView: View {
    @EnvironmentObject var appDataStore: AppDataStore
    @Binding var currentAuthScreen: AuthScreen
    @Binding var showTerms: Bool
    @Binding var showMandatoryModules: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var nome = ""
    @State private var email = ""
    @State private var senha = ""
    @State private var viewOpacity = 0.0
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private func attemptCadastro() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = senha.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty, !trimmedName.isEmpty else {
            self.alertMessage = "Por favor, preencha todos os campos."; self.showAlert = true; return
        }
        guard trimmedPassword.count >= 6 else {
            self.alertMessage = "A senha deve ter no mínimo 6 caracteres."; self.showAlert = true; return
        }
        Auth.auth().createUser(withEmail: trimmedEmail, password: trimmedPassword) { authResult, error in
            if let error = error {
                self.alertMessage = "Não foi possível criar a conta: \(error.localizedDescription)"; self.showAlert = true
            } else if let user = authResult?.user {
                print("Usuário Auth criado: \(user.uid)")
                let roleSelecionado = appDataStore.userRole ?? .estudante
                appDataStore.createUserProfile(userID: user.uid, name: trimmedName, role: roleSelecionado)
                let changeRequest = user.createProfileChangeRequest(); changeRequest.displayName = trimmedName
                changeRequest.commitChanges { err in if let e = err { print("Erro DisplayName Auth: \(e)") } else { print("DisplayName Auth OK") } }
                do { try Auth.auth().signOut() } catch { print("Erro signOut pós cadastro: \(error.localizedDescription)") }
                self.alertMessage = "Conta criada com sucesso! Faça o login."; self.showAlert = true
            }
        }
    }
    
    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ZStack(alignment: .topLeading) {
            VStack {
                Spacer()
                VStack(spacing: 20) {
                    Text("Criar Conta").font(.largeTitle.weight(.bold)).foregroundColor(theme.corTerra).padding(.bottom, 30)
                    VStack(spacing: 20) {
                        TextField("Nome Completo", text: $nome).padding().background(theme.fundoCampoInput).cornerRadius(12)
                        TextField("E-mail", text: $email).padding().background(theme.fundoCampoInput).cornerRadius(12).autocapitalization(.none).keyboardType(.emailAddress)
                        SecureField("Senha (mín. 6 caracteres)", text: $senha).padding().background(theme.fundoCampoInput).cornerRadius(12)
                        Button(action: attemptCadastro) { Text("Cadastrar").font(.body.weight(.bold)).frame(maxWidth: .infinity).padding().background(Color.corFolhaClara).foregroundColor(.white).cornerRadius(12).shadow(color: .corFolhaClara.opacity(0.5), radius: 10, x: 0, y: 5) }.padding(.top, 10)
                    }
                    Divider().padding(.vertical, 20)
                    Button { withAnimation { currentAuthScreen = .login } } label: { HStack { Text("Já tem uma conta?").foregroundColor(.gray); Text("Fazer Login").font(.body.weight(.bold)).foregroundColor(.corFolhaClara) } }
                }.padding(.horizontal, 10)
                Spacer()
            }.padding(.horizontal, 30).background(theme.fundo.ignoresSafeArea())
            Button(action: { withAnimation { currentAuthScreen = .welcome } }) { Image(systemName: "arrow.left.circle.fill").font(.title).foregroundColor(.gray.opacity(0.5)) }.padding()
        }.alert(isPresented: $showAlert) {
            if alertMessage.contains("sucesso") {
                return Alert(title: Text("Cadastro"), message: Text(alertMessage), dismissButton: .default(Text("OK")) { withAnimation { currentAuthScreen = .login } })
            } else {
                return Alert(title: Text("Cadastro"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }.opacity(viewOpacity).onAppear { withAnimation(.easeIn(duration: 0.5)) { viewOpacity = 1.0 } }
    }
}


struct ContentView: View {
    @StateObject private var appDataStore = AppDataStore()
    @State private var isAuthenticated: Bool = false
    @State private var showSplash: Bool = true
    @State private var currentAuthScreen: AuthScreen = .welcome
    @State private var showTerms: Bool = false
    @State private var showMandatoryModules: Bool = false
    
    @State private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    var body: some View {
        ZStack {
            if isAuthenticated {
                // Se autenticado, mostra view principal
                // O role vem do listener do AppDataStore
                if appDataStore.userRole == .educador {
                    EducadorMainView(logoutAction: logout).environmentObject(appDataStore)
                } else {
                    EstudanteMainView(logoutAction: logout).environmentObject(appDataStore)
                }
            } else {
                // Se não autenticado, mostra fluxo de login/cadastro
                Group {
                    if showSplash { SplashScreenView() }
                    else if currentAuthScreen == .welcome { WelcomeView(currentAuthScreen: $currentAuthScreen).environmentObject(appDataStore) }
                    else if currentAuthScreen == .login { LoginView(currentAuthScreen: $currentAuthScreen, showTerms: $showTerms, showMandatoryModules: $showMandatoryModules).environmentObject(appDataStore) }
                    else { CadastroView(currentAuthScreen: $currentAuthScreen, showTerms: $showTerms, showMandatoryModules: $showMandatoryModules).environmentObject(appDataStore) }
                }
                
                if showTerms { TermsAndConditionsView(showTerms: $showTerms, showMandatoryModules: $showMandatoryModules).transition(.opacity).zIndex(1) }
                if showMandatoryModules { MandatoryModulesView(isAuthenticated: $isAuthenticated).environmentObject(appDataStore).transition(.opacity).zIndex(2) }
            }
        }
        .onAppear(perform: setupApp) // Chama função setup no appear
        .onDisappear(perform: removeAuthListener) // Limpa listener ao sair
    }

    // Configuração inicial e listener do Auth
    private func setupApp() {
        // Esconde splash
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut) { showSplash = false }
        }
        
        // Configura listener do Auth
        removeAuthListener() // Garante limpeza
        authStateHandle = Auth.auth().addStateDidChangeListener { (auth, user) in
            // Atualiza isAuthenticated baseado no estado real do Firebase Auth
            let wasAuthenticated = self.isAuthenticated
            self.isAuthenticated = (user != nil)
            print("ContentView Auth Listener: isAuthenticated = \(self.isAuthenticated)")
            
            // Se o estado mudou de logado para deslogado, reseta a tela
            if wasAuthenticated && !self.isAuthenticated {
                print("User logged out, resetting to login screen.")
                self.currentAuthScreen = .login
                self.showTerms = false
                self.showMandatoryModules = false
            }
            // Se acabou de logar, o AppDataStore vai carregar o perfil
        }
    }

    // Função para remover o listener do Auth
    private func removeAuthListener() {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
            print("ContentView Auth Listener removed.")
        }
    }

    // Função de logout
    private func logout() {
        do {
            try Auth.auth().signOut()
            // O listener do Auth vai detectar a mudança e setar isAuthenticated = false
            print("Logout successful.")
        } catch let signOutError as NSError {
            print("Erro ao fazer logout: %@", signOutError)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray).padding(.leading, 8)
            TextField("Pesquisar conteúdo...", text: $text).padding(.vertical, 10).background(theme.fundoCampoInput.opacity(0.7)).cornerRadius(8)
        }.padding(.horizontal, 8).background(theme.fundoCampoInput).cornerRadius(10).shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

struct DestaquePrincipalCard: View {
    let item: ConteudoEducacional
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20).fill(item.cor.opacity(0.8)).shadow(color: item.cor.opacity(0.3), radius: 8, x: 0, y: 5)
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: item.icone).font(.largeTitle).foregroundColor(.white).padding(10).background(Color.white.opacity(0.2)).cornerRadius(10)
                Spacer()
                Text(item.titulo).font(.title2.weight(.bold)).foregroundColor(.white).lineLimit(2)
                Text(item.subtitulo).font(.subheadline).foregroundColor(.white.opacity(0.9)).lineLimit(1)
            }.padding()
        }.frame(height: 220).cornerRadius(20)
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
        }.frame(width: 90, height: 90).background(theme.fundoCard).cornerRadius(15).shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            // .preferredColorScheme(.dark) // Para testar modo escuro
    }
}
