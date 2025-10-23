import SwiftUI
import Combine
import Foundation
import SafariServices
import FirebaseAuth

extension Color {
    static let corFolhaClara = Color(red: 0.3, green: 0.65, blue: 0.25)
    static let corDestaque = Color(red: 0.95, green: 0.7, blue: 0.3)
    static let fundoFormularioClaro = Color(.systemGray6)
    static let fundoFormularioEscuro = Color(.systemGray5)
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

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
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

enum UserRole: String, CaseIterable {
    case estudante = "Estudante"
    case educador = "Educador"
}

class AppDataStore: ObservableObject {
    @Published var conteudos: [ConteudoEducacional]
    @Published var conteudosCompletos: Set<UUID> = []
    @Published var userRole: UserRole? = nil
    @Published var chatMessages: [ChatMessage] = []
    @Published var userName: String = "Visitante"

    init() {
        self.conteudos = [
            ConteudoEducacional(titulo: "Missões e Valores", subtitulo: "Módulo Obrigatório", descricaoCurta: "Conheça os pilares da plataforma Leafy.", icone: "heart.fill", cor: .pink, categoria: "Institucional", nivel: "Todos", isMandatoryFor: [.estudante, .educador]),
            ConteudoEducacional(titulo: "Compreender o Mercado", subtitulo: "Módulo Obrigatório", descricaoCurta: "Sustentabilidade e o futuro profissional.", icone: "briefcase.fill", cor: .indigo, categoria: "Carreira", nivel: "Iniciante", isMandatoryFor: [.estudante]),
            ConteudoEducacional(titulo: "Clima e Sustentabilidade", subtitulo: "Trilha Básica", descricaoCurta: "Entenda as mudanças climáticas e ações locais.", icone: "cloud.sun.rain.fill", cor: .orange, categoria: "Curso", nivel: "Iniciante"),
            ConteudoEducacional(titulo: "Hortas Urbanas", subtitulo: "Curso Prático", descricaoCurta: "Guia completo de plantio em pequenos espaços.", icone: "leaf.fill", cor: .corFolhaClara, categoria: "Curso", nivel: "Iniciante"),
            ConteudoEducacional(titulo: "Reciclagem Avançada", subtitulo: "Curso Completo", descricaoCurta: "Técnicas e a economia circular.", icone: "arrow.triangle.2.circlepath", cor: .blue, categoria: "Curso", nivel: "Avançado"),
            ConteudoEducacional(titulo: "Energias Renováveis", subtitulo: "Curso Técnico", descricaoCurta: "Explore a energia solar, eólica e outras fontes limpas.", icone: "wind", cor: .cyan, categoria: "Curso", nivel: "Avançado"),
            ConteudoEducacional(titulo: "Guia de Compostagem", subtitulo: "E-book Gratuito", descricaoCurta: "Transforme resíduos orgânicos em adubo de alta qualidade.", icone: "book.closed.fill", cor: Color(red: 0.2, green: 0.15, blue: 0.05), categoria: "Ebook", nivel: "Iniciante", link: "https://www.infoteca.cnptia.embrapa.br/infoteca/bitstream/doc/1019253/1/cartilhacompostagem.pdf"),
            ConteudoEducacional(titulo: "Manual do Lixo Zero", subtitulo: "E-book Completo", descricaoCurta: "Um guia com os princípios para reduzir sua geração de lixo.", icone: "trash.slash.fill", cor: .gray, categoria: "Ebook", nivel: "Avançado"),
            ConteudoEducacional(titulo: "5 Atitudes para um Planeta Mais Saudável", subtitulo: "Artigo da Comunidade", descricaoCurta: "Pequenas mudanças de hábito que fazem a diferença.", icone: "newspaper.fill", cor: .purple, categoria: "Artigo", nivel: "Todos", autor: "Equipe Leafy"),
            ConteudoEducacional(titulo: "A Importância das Abelhas", subtitulo: "Artigo Científico", descricaoCurta: "Entenda o papel vital dos polinizadores no nosso ecossistema.", icone: "ladybug.fill", cor: .red, categoria: "Artigo", nivel: "Intermediário", autor: "Dr. Silva"),
            ConteudoEducacional(titulo: "Como Montar sua Horta Vertical", subtitulo: "Vídeo Tutorial", descricaoCurta: "Passo a passo para criar uma horta em apartamentos.", icone: "video.fill", cor: .teal, categoria: "Video", nivel: "Iniciante", duracao: "12 min"),
            ConteudoEducacional(titulo: "Documentário: Oceanos de Plástico", subtitulo: "Documentário", descricaoCurta: "Uma visão aprofundada sobre a poluição marinha.", icone: "film.fill", cor: .blue, categoria: "Video", nivel: "Todos", duracao: "45 min")
        ]
        self.chatMessages = [
            ChatMessage(text: "Olá, pessoal! Bem-vindos à comunidade Leafy.", user: "Bot Leafy", isCurrentUser: false, timestamp: Date().addingTimeInterval(-3600))
        ]
    }
    
    func toggleCompletion(for item: ConteudoEducacional) {
        if conteudosCompletos.contains(item.id) { conteudosCompletos.remove(item.id) }
        else { conteudosCompletos.insert(item.id) }
    }

    func sendMessage(_ text: String) {
        let newMessage = ChatMessage(text: text, user: "Você", isCurrentUser: true, timestamp: Date())
        chatMessages.append(newMessage)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let replyMessage = ChatMessage(text: "Ótima contribuição para a nossa comunidade!", user: "Bot Leafy", isCurrentUser: false, timestamp: Date())
            self.chatMessages.append(replyMessage)
        }
    }
}

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
                .onChange(of: appDataStore.chatMessages) { //
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

struct CursoCardView: View {
    let curso: ConteudoEducacional
    var body: some View {
        NavigationLink(destination: DetailView(item: curso)) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: curso.icone).font(.largeTitle).foregroundColor(curso.cor)
                Text(curso.titulo).font(.headline.weight(.bold)).foregroundColor(.primary).lineLimit(2)
                Text(curso.nivel).font(.caption).foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .frame(width: 160, height: 160)
            .background(Color(.systemGray6))
            .cornerRadius(15)
        }.buttonStyle(.plain)
    }
}

struct ItemRowView: View {
    let item: ConteudoEducacional
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        let isCompleto = appDataStore.conteudosCompletos.contains(item.id)
        
        HStack {
            Image(systemName: item.icone).resizable().aspectRatio(contentMode: .fit).frame(width: 30, height: 30).padding(10).background(item.cor.opacity(0.15)).cornerRadius(10).foregroundColor(item.cor)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.titulo).font(.system(.headline, design: .default).weight(.medium)).foregroundColor(theme.corTerra)
                Text(item.descricaoCurta).font(.subheadline).foregroundColor(.gray).lineLimit(1)
            }
            Spacer()
            if isCompleto { Image(systemName: "checkmark.circle.fill").foregroundColor(.corFolhaClara) }
            else { Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5)) }
        }.opacity(isCompleto ? 0.6 : 1.0)
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
                        Text("Continue de onde parou").font(.title2.weight(.bold)).foregroundColor(theme.corTerra).padding(.horizontal)
                        DestaquePrincipalCard(item: destaque).padding(.horizontal)
                    }
                }
                
                Text("Todas as Trilhas").font(.title2.weight(.bold)).foregroundColor(theme.corTerra).padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))]) {
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
                        Text("Destaques").font(.title2.weight(.bold)).padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(destaques) { item in
                                    DestaquePrincipalCard(item: item).frame(width: 300)
                                }
                            }.padding(.horizontal)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Categorias").font(.title2.weight(.bold)).padding(.horizontal)
                        HStack(spacing: 20) {
                            Spacer()
                            CategoriaCard(title: "E-books", icon: "book.closed.fill", color: .orange)
                            CategoriaCard(title: "Artigos", icon: "newspaper.fill", color: .purple)
                            CategoriaCard(title: "Vídeos", icon: "video.fill", color: .teal)
                            Spacer()
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dicas Rápidas").font(.title2.weight(.bold)).padding(.horizontal)
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
    @State private var showPrivacy = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        Text(appDataStore.userName)
                            .font(.title2.weight(.bold))
                        Text(appDataStore.userRole?.rawValue ?? "Usuário")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Adicionar Foto") {}
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                Section(header: Text("Conta")) {
                    TextField("Nome do Usuário", text: $appDataStore.userName)
                    if appDataStore.userRole == .estudante {
                        NavigationLink(destination: PlanosView()) {
                            Text("Ver Planos de Assinatura")
                        }
                    }
                    Toggle(isOn: .constant(true)) {
                        Text("Receber Notificações")
                    }
                }
                
                Section(header: Text("Sobre")) {
                    Button("Política de Privacidade") {
                        showPrivacy = true
                    }
                    Text("Versão do App: 1.0.0")
                }
                
                Section {
                    Button(action: {
                        dismiss()
                        logoutAction()
                    }) {
                        Text("Sair")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Perfil e Configurações")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") { dismiss() }
                }
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyPolicyView()
            }
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                Text("Nossa Política de Privacidade descreve como coletamos e usamos seus dados. Coletamos informações básicas como nome e e-mail para personalizar sua experiência. Não compartilhamos seus dados com terceiros sem seu consentimento. Você pode solicitar a exclusão dos seus dados a qualquer momento.").padding()
            }
            .navigationTitle("Política de Privacidade")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("OK") { dismiss() } } }
        }
    }
}


// ==========================================
// ===== SPLASHSCREEN VIEW - ATUALIZADA =====
// ==========================================
struct SplashScreenView: View {
    @State private var dropPosition: CGFloat = -UIScreen.main.bounds.midY
    @State private var dropScale: CGFloat = 1.0
    @State private var rippleScale: CGFloat = 0.0
    @State private var rippleOpacity: Double = 1.0
    @State private var backgroundScale: CGFloat = 0.0
    
    // ===== MUDANÇA AQUI (1/3): Novas variáveis para a animação da folha =====
    @State private var exitLeafScale: CGFloat = 0.01
    @State private var exitLeafOpacity: Double = 0.0

    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            // O círculo verde que expande
            Circle()
                .fill(Color.corFolhaClara)
                .frame(width: 100, height: 100)
                .scaleEffect(backgroundScale)
            
            // O efeito de "ripple"
            ZStack {
                Circle().stroke(Color.corFolhaClara, lineWidth: 2).scaleEffect(rippleScale).opacity(rippleOpacity)
                Circle().stroke(Color.corFolhaClara, lineWidth: 1).scaleEffect(rippleScale * 1.5).opacity(rippleOpacity * 0.7)
            }

            // A gota que cai
            Circle()
                .fill(Color.corFolhaClara)
                .frame(width: 30, height: 30)
                .scaleEffect(dropScale)
                .offset(y: dropPosition)
            
            // ===== MUDANÇA AQUI (2/3): A nova folha que aparece no final =====
            // Ela começa invisível
            Image(systemName: "leaf.fill")
                .font(.system(size: 100))
                .foregroundColor(.white) // Cor branca para aparecer sobre o fundo verde
                .scaleEffect(exitLeafScale)
                .opacity(exitLeafOpacity)
        }
        .onAppear(perform: startAnimationSequence)
    }
    
    private func startAnimationSequence() {
        // --- Animação de ENTRADA (Como estava antes) ---
        withAnimation(.easeIn(duration: 0.6)) {
            dropPosition = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                dropScale = 0.0
            }
            withAnimation(.easeOut(duration: 1.0)) {
                rippleScale = 2.0
                rippleOpacity = 0.0
            }
        }
        
        // Tela fica verde (termina em 1.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.8)) {
                backgroundScale = 50
            }
        }
        
        // ===== MUDANÇA AQUI (3/3): Nova animação de SAÍDA =====
        // Vamos começar aos 2.0s (antes dos 3.0s do ContentView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            
            // O fundo verde encolhe e a folha branca aparece
            withAnimation(.easeInOut(duration: 0.8)) {
                backgroundScale = 0.0   // Fundo verde some
                exitLeafScale = 1.0     // Folha branca cresce
                exitLeafOpacity = 1.0   // Folha branca aparece
            }
            
            // E então, a folha branca desaparece
            withAnimation(.easeOut(duration: 0.2).delay(0.8)) { // Começa depois que a animação acima termina
                exitLeafOpacity = 0.0
            }
        }
        // (O timer de 3.0s do ContentView vai esconder esta tela logo após a folha sumir)
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
    
    private func selectRole(_ role: UserRole) {
        appDataStore.userRole = role
        withAnimation { currentAuthScreen = .login }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "leaf.fill")
                .font(.system(size: 100))
                .foregroundColor(.corFolhaClara)
                .rotationEffect(leafRotation)
                .offset(y: leafOffset)
                .opacity(leafOpacity)

            VStack {
                Text("LEAFY")
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.05))
                
                Text("Sua jornada para um futuro mais verde começa aqui.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(textOpacity)
            .padding(.horizontal)
            
            Spacer()
            Spacer()

            VStack(spacing: 20) {
                Button(action: { selectRole(.estudante) }) {
                    Label("Sou Estudante", systemImage: "person.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.corFolhaClara)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .offset(y: buttonOffset)
                
                Button(action: { selectRole(.educador) }) {
                    Label("Sou Educador", systemImage: "graduationcap.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.corDestaque)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .offset(y: buttonOffset)
            }
            
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.1), .white]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .onAppear(perform: startAnimation)
    }
    
    private func startAnimation() {
        withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2)) {
            leafRotation = .degrees(0)
            leafOffset = 0
            leafOpacity = 1.0
        }
        
        withAnimation(.easeIn(duration: 0.8).delay(0.8)) {
            textOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.2)) {
            buttonOffset = 0
        }
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
                        Text("Acreditamos que a educação é a semente para um futuro sustentável. Nossa missão é empoderar estudantes e educadores com conhecimento prático e acessível sobre o meio ambiente, transformando a consciência ecológica em ação cotidiana. Queremos construir uma comunidade global que não apenas compreende os desafios ambientais, mas que ativamente participa da solução.")
                        Text("Nossos Valores").font(.title2.weight(.bold))
                        Text("**Ação Local, Impacto Global:** Incentivamos projetos 'mão na massa' que começam na comunidade escolar e se expandem, mostrando que pequenas ações coletivas geram grandes transformações.")
                        Text("**Conhecimento Acessível:** Removemos barreiras ao aprendizado, oferecendo conteúdos de alta qualidade em diversos formatos, desde e-books gratuitos a planos completos para escolas.")
                    }.padding()
                }
                Button(action: {
                    if !appDataStore.conteudosCompletos.contains(item.id) {
                        appDataStore.toggleCompletion(for: item)
                    }
                    dismiss()
                }) {
                    Text("Compreendo e aceito estes valores").font(.headline.weight(.bold)).frame(maxWidth: .infinity).padding().background(Color.corFolhaClara).foregroundColor(.white).cornerRadius(12)
                }.padding()
            }.navigationTitle("Missão e Valores").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Fechar") { dismiss() } } }
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
        VStack {
            Spacer()
            
            VStack {
                Text("Primeiros Passos").font(.largeTitle.weight(.bold)).foregroundColor(theme.corTerra)
                Text("Complete os módulos abaixo para começar.").foregroundColor(.secondary)
                
                List(mandatoryModules) { item in
                    Button(action: { itemParaAceite = item }) { ItemRowView(item: item) }
                }
                .listStyle(.plain)
                .frame(height: CGFloat(mandatoryModules.count) * 70)
            }
            
            Spacer()
            
            Button("Acessar a Plataforma") { withAnimation { isAuthenticated = true } }
            .font(.headline.weight(.bold)).frame(maxWidth: .infinity).padding().background(allMandatoryCompleted ? Color.corFolhaClara : Color.gray).foregroundColor(.white).cornerRadius(12).disabled(!allMandatoryCompleted)
        }.padding().background(theme.fundo.ignoresSafeArea())
        .sheet(item: $itemParaAceite) { item in
            if item.titulo == "Missões e Valores" { MissionAndValuesView(item: item) }
            else { ModuleView(item: item) }
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
            self.alertMessage = "Por favor, preencha o e-mail e a senha."
            self.showAlert = true
            return
        }

        Auth.auth().signIn(withEmail: trimmedEmail, password: trimmedPassword) { authResult, error in
            
            if let error = error {
                self.alertMessage = "Credenciais inválidas. Verifique seu e-mail e senha."
                self.showAlert = true
                print("ERRO DE LOGIN: \(error.localizedDescription)")
            } else {
                print("Usuário logado com sucesso: \(authResult?.user.uid ?? "")")
                
                appDataStore.userRole = .estudante

                if UserDefaults.standard.bool(forKey: "hasAcceptedMainTerms") {
                    showMandatoryModules = true
                } else {
                    showTerms = true
                }
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
                        TextField("E-mail", text: $email).padding().background(theme.fundoCampoInput).cornerRadius(12).autocapitalization(.none)
                        SecureField("Senha", text: $senha).padding().background(theme.fundoCampoInput).cornerRadius(12)
                        Button(action: attemptLogin) { Text("Entrar").font(.body.weight(.bold)).frame(maxWidth: .infinity).padding().background(Color.corFolhaClara).foregroundColor(.white).cornerRadius(12).shadow(color: .corFolhaClara.opacity(0.5), radius: 10, x: 0, y: 5) }.padding(.top, 20)
                    }
                    Divider().padding(.vertical, 40)
                    Button { withAnimation { currentAuthScreen = .cadastro } } label: {
                        VStack {
                            Text("Não tem conta?").foregroundColor(.gray).font(.caption)
                            Text("Crie uma agora!").font(.caption.weight(.bold)).foregroundColor(.corFolhaClara)
                        }
                    }
                }.padding(.horizontal, 40)
                Spacer()
            }.padding(.horizontal, 30).background(theme.fundo.ignoresSafeArea())
            Button(action: { withAnimation { currentAuthScreen = .welcome } }) {
                Image(systemName: "arrow.left.circle.fill").font(.title).foregroundColor(.gray.opacity(0.5))
            }.padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Aviso de Login"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .opacity(viewOpacity).onAppear { withAnimation(.easeIn(duration: 0.5)) { viewOpacity = 1.0 } }
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
                ScrollView {
                    Text("Bem-vindo à Leafy. Ao usar nosso aplicativo, você concorda com estes termos. O conteúdo é para fins educacionais e não deve ser redistribuído. Respeite a comunidade e use a plataforma de forma lícita. Coletamos dados básicos para o funcionamento do app, conforme nossa Política de Privacidade. Não nos responsabilizamos por interrupções no serviço. Podemos suspender contas que violem estas regras.")
                        .font(.body)
                        .padding()
                }
                .frame(maxHeight: 350).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                VStack(spacing: 15) {
                    Toggle(isOn: $accepted) { Text("Eu li e aceito os Termos.").foregroundColor(theme.corTerra) }.toggleStyle(.switch).tint(.corFolhaClara)
                    Button(action: {
                        if accepted {
                            UserDefaults.standard.set(true, forKey: "hasAcceptedMainTerms")
                            withAnimation { showTerms = false; showMandatoryModules = true }
                        }
                    }) {
                        Text("Aceitar").font(.body.weight(.bold)).frame(maxWidth: .infinity).padding().background(accepted ? Color.corFolhaClara : Color.gray).foregroundColor(.white).cornerRadius(12)
                    }.disabled(!accepted)
                }.padding(.horizontal)
                Button("Voltar") { withAnimation { showTerms = false } }.foregroundColor(.gray)
            }.padding(30).background(theme.fundo).cornerRadius(20).shadow(radius: 10).padding(20)
        }
    }
}


// ===============================================
// ===== CADASTRO VIEW - ATUALIZADA (LÓGICA) =====
// ===============================================
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
    
    // ===== MUDANÇA AQUI (1/1): Lógica de cadastro atualizada =====
    private func attemptCadastro() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = senha.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty, !nome.isEmpty else {
            self.alertMessage = "Por favor, preencha todos os campos."
            self.showAlert = true
            return
        }
        
        guard trimmedPassword.count >= 6 else {
            self.alertMessage = "A senha deve ter no mínimo 6 caracteres."
            self.showAlert = true
            return
        }

        Auth.auth().createUser(withEmail: trimmedEmail, password: trimmedPassword) { authResult, error in
            if let error = error {
                // Erro (ex: e-mail já existe)
                self.alertMessage = "Não foi possível criar a conta: \(error.localizedDescription)"
                self.showAlert = true
            } else {
                // SUCESSO!
                print("Usuário criado com sucesso: \(authResult?.user.uid ?? "")")
                
                // 1. Deslogar o usuário (para forçar o login)
                do {
                    try Auth.auth().signOut()
                } catch {
                    print("Erro ao deslogar após cadastro: \(error.localizedDescription)")
                }
                
                // 2. Avisar que deu certo e pedir para logar
                self.alertMessage = "Conta criada com sucesso! Por favor, faça o login."
                self.showAlert = true
                
                // 3. Mudar a tela de volta para o Login
                withAnimation {
                    self.currentAuthScreen = .login
                }
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
                        TextField("E-mail", text: $email).padding().background(theme.fundoCampoInput).cornerRadius(12).autocapitalization(.none)
                        SecureField("Senha", text: $senha).padding().background(theme.fundoCampoInput).cornerRadius(12)
                        
                        Button(action: attemptCadastro) { // Ação do botão está correta
                            Text("Cadastrar").font(.body.weight(.bold)).frame(maxWidth: .infinity).padding().background(Color.corFolhaClara).foregroundColor(.white).cornerRadius(12).shadow(color: .corFolhaClara.opacity(0.5), radius: 10, x: 0, y: 5)
                        }.padding(.top, 10)
                    }
                    Divider().padding(.vertical, 20)
                    Button { withAnimation { currentAuthScreen = .login } } label: {
                        HStack {
                            Text("Já tem uma conta?").foregroundColor(.gray)
                            Text("Fazer Login").font(.body.weight(.bold)).foregroundColor(.corFolhaClara)
                        }
                    }
                }.padding(.horizontal, 10)
                Spacer()
            }.padding(.horizontal, 30).background(theme.fundo.ignoresSafeArea())
            Button(action: { withAnimation { currentAuthScreen = .welcome } }) {
                Image(systemName: "arrow.left.circle.fill").font(.title).foregroundColor(.gray.opacity(0.5))
            }.padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Aviso de Cadastro"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .opacity(viewOpacity).onAppear { withAnimation(.easeIn(duration: 0.5)) { viewOpacity = 1.0 } }
    }
}


struct ContentView: View {
    @StateObject private var appDataStore = AppDataStore()
    @State private var isAuthenticated: Bool = false
    @State private var showSplash: Bool = true
    @State private var currentAuthScreen: AuthScreen = .welcome
    @State private var showTerms: Bool = false
    @State private var showMandatoryModules: Bool = false
    
    var body: some View {
        ZStack {
            if isAuthenticated {
                if appDataStore.userRole == .educador {
                    EducadorMainView(logoutAction: logout).environmentObject(appDataStore)
                } else {
                    EstudanteMainView(logoutAction: logout).environmentObject(appDataStore)
                }
            } else {
                Group {
                    if showSplash { SplashScreenView() } // Timer de 3s está aqui
                    else if currentAuthScreen == .welcome { WelcomeView(currentAuthScreen: $currentAuthScreen).environmentObject(appDataStore) }
                    else if currentAuthScreen == .login { LoginView(currentAuthScreen: $currentAuthScreen, showTerms: $showTerms, showMandatoryModules: $showMandatoryModules).environmentObject(appDataStore) }
                    else { CadastroView(currentAuthScreen: $currentAuthScreen, showTerms: $showTerms, showMandatoryModules: $showMandatoryModules).environmentObject(appDataStore) }
                }
                
                if showTerms { TermsAndConditionsView(showTerms: $showTerms, showMandatoryModules: $showMandatoryModules).transition(.opacity).zIndex(1) }
                if showMandatoryModules { MandatoryModulesView(isAuthenticated: $isAuthenticated).environmentObject(appDataStore).transition(.opacity).zIndex(2) }
            }
        }
        .onAppear {
            // Este timer de 3.0s controla o splash
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut) { showSplash = false }
            }
        }
    }

    private func logout() {
        do {
            try Auth.auth().signOut()
            withAnimation {
                isAuthenticated = false
                currentAuthScreen = .login
            }
        } catch let signOutError as NSError {
            print("Erro ao fazer logout: %@", signOutError)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var body: some View {
        HStack {
            TextField("Pesquisar conteúdo...", text: $text)
                .padding(10)
                .padding(.horizontal, 25)
                .background(Color(.systemGray5))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                    }
                )
        }
    }
}

struct DestaquePrincipalCard: View {
    let item: ConteudoEducacional
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(item.cor)
            VStack(alignment: .leading) {
                Image(systemName: item.icone)
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                Spacer()
                Text(item.titulo)
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                Text(item.subtitulo)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
        .frame(height: 200)
        .cornerRadius(20)
    }
}

struct CategoriaCard: View {
    let title: String
    let icon: String
    let color: Color
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
        }
        .frame(width: 100, height: 100)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct DicaCard: View {
    let text: String
    var body: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

struct FeedbackCard: View {
    let text: String
    let user: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(text)
                .font(.body.italic())
            Text("- \(user)")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
