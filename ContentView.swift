// MARK: - ARQUIVO DE VIEWS (ContentView.swift)
// Este arquivo contém TODAS as suas views e lógica do AppDataStore.

import SwiftUI
import Combine
import Foundation
import SafariServices
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import WebKit // Necessário para a WebView do Ebook/Safari

// NOVO: IMPORTS PARA LOGIN SOCIAL
import GoogleSignIn
import GoogleSignInSwift
// FIM DOS NOVOS IMPORTS

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
    let userID: String
    let userPhotoURL: String?
    let isCurrentUser: Bool
    let timestamp: Date
}

struct UserProfile: Codable, Identifiable {
    var id: String?
    var name: String
    var profileImageURL: String?
    var bio: String?
    var points: Int
    var completedContent: [String]? // Salva os IDs como String
}

// MARK: - AppDataStore (Firebase + Cache Local)

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
    
    private let userProfileCacheKey = "cachedUserProfile_v1"

    init() {
        self.conteudos = [
            // Módulos Obrigatórios (Mais conteúdo)
            ConteudoEducacional(titulo: "Missões e Valores", subtitulo: "Módulo Obrigatório", descricaoCurta: "Conheça os pilares da plataforma Leafy.", icone: "heart.fill", cor: .pink, categoria: "Institucional", nivel: "Todos", isMandatory: true, textoCompleto: "Bem-vindo à Leafy!\n\nNossa missão é democratizar o conhecimento sobre sustentabilidade. Acreditamos que pequenas ações, quando somadas, geram um impacto global massivo. Nosso objetivo não é apenas ensinar sobre o meio ambiente, mas inspirar uma mudança real de hábitos.\n\nNossos valores são baseados em 3 pilares:\n1.  **Educação Acessível:** Conhecimento deve ser livre e fácil de entender.\n2.  **Comunidade:** Ninguém muda o mundo sozinho. Juntos, compartilhamos ideias e nos apoiamos.\n3.  **Ação Prática:** Aprender é o primeiro passo. Agir é o que realmente importa."),
            ConteudoEducacional(titulo: "Compreender o Mercado Sustentável", subtitulo: "Módulo Obrigatório", descricaoCurta: "Sustentabilidade e o futuro profissional.", icone: "briefcase.fill", cor: .indigo, categoria: "Carreira", nivel: "Iniciante", isMandatory: true, textoCompleto: "O Futuro é Verde\n\nO mercado de trabalho está mudando rapidamente. Empresas não são mais avaliadas apenas por seu lucro, mas por seu impacto social e ambiental (ESG).\n\nProfissionais que entendem de sustentabilidade, economia circular e responsabilidade social não são mais um nicho, são uma necessidade. Este módulo irá mostrar como a sustentabilidade está abrindo novas portas de carreira em todas as áreas, da moda à finanças."),
            
            // Cursos (Mais conteúdo)
            ConteudoEducacional(titulo: "Hortas Urbanas e Permacultura", subtitulo: "Curso Prático", descricaoCurta: "Guia completo de plantio em pequenos espaços.", icone: "leaf.fill", cor: .corFolhaClara, categoria: "Curso", nivel: "Iniciante", textoCompleto: "Começando sua Horta\n\nTer uma horta em casa é um ato revolucionário. É reconectar-se com o ciclo do alimento, reduzir o desperdício e garantir comida saudável na sua mesa. Mesmo que você more em um apartamento pequeno, é possível plantar.\n\nNeste curso, vamos cobrir:\n* Vasos autoirrigáveis.\n* Escolhendo o substrato correto.\n* O que plantar: temperos, hortaliças e PANCs (Plantas Alimentícias Não Convencionais).\n* Como combater pragas sem veneno.\n* Princípios básicos de permacultura para aplicar na sua varanda."),
            ConteudoEducacional(titulo: "Reciclagem e Economia Circular", subtitulo: "Curso Completo", descricaoCurta: "Técnicas e a economia circular.", icone: "arrow.triangle.2.circlepath", cor: .blue, categoria: "Curso", nivel: "Avançado", textoCompleto: "Além da Lixeira Colorida\n\nA reciclagem é o último passo, não o primeiro. Antes dela, precisamos Repensar, Reduzir e Reutilizar. Este curso vai a fundo na cadeia de reciclagem, mostrando os desafios do processo no Brasil.\n\nMergulharemos no conceito de Economia Circular, um modelo econômico que propõe o fim do 'lixo'. Em vez de 'extrair, usar e descartar', a economia circular foca em 'reduzir, reutilizar, remanufaturar e reciclar', criando um ciclo fechado onde materiais são reaproveitados ao máximo, gerando valor e não poluição."),
            ConteudoEducacional(titulo: "Energias Renováveis do Futuro", subtitulo: "Curso Técnico", descricaoCurta: "Explore a energia solar, eólica e outras fontes limpas.", icone: "wind", cor: .cyan, categoria: "Curso", nivel: "Avançado", textoCompleto: "A Transição Energética\n\nO mundo precisa desesperadamente sair dos combustíveis fósseis. Neste curso, faremos uma análise técnica das principais fontes de energia limpa: solar (fotovoltaica), eólica (onshore e offshore), hidrelétrica e até fontes emergentes como hidrogênio verde e energia das marés."),
            ConteudoEducacional(titulo: "O Saneamento Básico", subtitulo: "Saúde e Meio Ambiente", descricaoCurta: "Entenda a importância do saneamento para a saúde pública.", icone: "drop.fill", cor: .cyan, categoria: "Curso", nivel: "Intermediário", textoCompleto: "Saneamento é Dignidade\n\nSaneamento básico não é apenas água na torneira. É coleta e tratamento de esgoto, drenagem de águas pluviais e coleta de lixo. A falta de saneamento é a principal causa de muitas doenças em países em desenvolvimento. Vamos explorar o cenário brasileiro e como a universalização do saneamento impacta diretamente a saúde, a educação e o meio ambiente."),
            ConteudoEducacional(titulo: "Descarte de Lixo Eletrônico", subtitulo: "Lixo Eletrônico", descricaoCurta: "O que fazer com celulares, pilhas e computadores antigos.", icone: "iphone.gen1.slash", cor: .blue, categoria: "Curso", nivel: "Intermediário", textoCompleto: "O Perigo Invisível\n\nSeu celular antigo contém metais pesados como chumbo, mercúrio e cádmio. Quando descartado no lixo comum, ele contamina o solo e os lençóis freáticos. O 'e-lixo' é um dos que mais cresce no mundo. Aprenda sobre a logística reversa, seus direitos como consumidor e onde encontrar postos de coleta adequados."),
            ConteudoEducacional(titulo: "A Ameaça dos Oceanos", subtitulo: "Ecossistemas Marinhos", descricaoCurta: "Como o lixo plástico impacta a vida marinha.", icone: "trash.circle.fill", cor: .teal, categoria: "Curso", nivel: "Avançado", textoCompleto: "Um Mar de Plástico\n\nEstima-se que até 2050 haverá mais peso em plástico nos oceanos do que em peixes. Este curso explora o impacto dos giros de lixo oceânicos, o problema dos microplásticos e como a poluição afeta desde o plâncton até as grandes baleias. Também discutiremos soluções, como ONGs de limpeza de praia e tecnologias de captura de plástico em rios."),
            ConteudoEducacional(titulo: "A Revolução da Energia Solar", subtitulo: "Energias Renováveis", descricaoCurta: "Como a energia solar está moldando o futuro.", icone: "sun.max.trianglebadge.exclamationmark.fill", cor: .orange, categoria: "Curso", nivel: "Iniciante", textoCompleto: "O Sol é para Todos\n\nA energia solar é democrática: está disponível em quase todos os lugares. Vamos desmistificar a instalação de painéis solares, explicar a diferença entre geração on-grid e off-grid, e como você pode (em muitos lugares) 'vender' o excesso de energia de volta para a rede elétrica, gerando créditos na sua conta de luz."),
            ConteudoEducacional(titulo: "O Problema do Isopor", subtitulo: "Descarte Correto", descricaoCurta: "Aprenda a descartar e reciclar o isopor corretamente.", icone: "archivebox.fill", cor: .gray, categoria: "Curso", nivel: "Iniciante", textoCompleto: "Isopor é Reciclável? Sim, mas...\n\nTecnicamente, o EPS (Poliestireno Expandido) é 100% reciclável. O problema é que ele é 98% ar, o que torna seu transporte e processamento muito caros. Poucas cooperativas aceitam. Vamos ver alternativas ao isopor e qual a maneira correta de descartá-lo para que ele não acabe em aterros, onde leva centenas de anos para se decompor."),
            
            // E-books
            ConteudoEducacional(titulo: "Guia de Compostagem Caseira", subtitulo: "E-book Interativo", descricaoCurta: "Transforme resíduos orgânicos em adubo.", icone: "book.closed.fill", cor: Color(red: 0.2, green: 0.15, blue: 0.05), categoria: "Ebook", nivel: "Iniciante", textoCompleto: "Capítulo 1: O que é Compostagem?\n\nCompostagem é um processo biológico que transforma lixo orgânico (restos de frutas, vegetais, borra de café) em um adubo rico chamado composto. É a forma mais natural de reciclagem.\n\nCapítulo 2: Minhocário vs. Compostagem Seca\nExistem dois tipos principais de composteiras caseiras: as com minhocas (vermicompostagem) e as secas (que usam apenas microorganismos). Vamos analisar os prós e contras de cada uma para um apartamento."),
            ConteudoEducacional(titulo: "Manual Completo do Lixo Zero", subtitulo: "PDF Externo", descricaoCurta: "Princípios para reduzir sua geração de lixo.", icone: "trash.slash.fill", cor: .gray, categoria: "Ebook", nivel: "Avançado", link: "https://www.infoteca.cnptia.embrapa.br/infoteca/bitstream/doc/1019253/1/cartilhacompostagem.pdf"), // Link de exemplo real
            
            // Artigos
            ConteudoEducacional(titulo: "5 Atitudes para um Planeta Mais Saudável", subtitulo: "Artigo da Comunidade", descricaoCurta: "Pequenas mudanças que fazem a diferença.", icone: "newspaper.fill", cor: .purple, categoria: "Artigo", nivel: "Todos", autor: "Equipe Leafy", textoCompleto: "Muitas vezes pensamos que para ajudar o planeta precisamos de ações grandiosas. Mas a verdade é que o impacto real vem da consistência.\n\n1. Use uma ecobag. Sempre.\n2. Tenha um copo reutilizável na sua mochila ou carro.\n3. Tente a 'Segunda Sem Carne'.\n4. Troque suas lâmpadas por LED.\n5. Desligue aparelhos da tomada em vez de deixá-los em standby."),
            ConteudoEducacional(titulo: "A Importância Vital das Abelhas", subtitulo: "Artigo Científico", descricaoCurta: "O papel vital dos polinizadores.", icone: "ant.fill", cor: .red, categoria: "Artigo", nivel: "Intermediário", autor: "Dr. Silva", textoCompleto: "As abelhas são indiscutivelmente os polinizadores mais importantes do planeta. Cerca de 70% das culturas agrícolas que alimentam o mundo dependem delas. O desaparecimento das abelhas (CCD - Colony Collapse Disorder) é uma ameaça real à nossa segurança alimentar. O uso de agrotóxicos e a perda de habitat são os principais vilões."),
            
            // Vídeos
            ConteudoEducacional(titulo: "Como Montar sua Horta Vertical", subtitulo: "Vídeo Tutorial", descricaoCurta: "Horta em apartamentos.", icone: "video.fill", cor: .teal, categoria: "Video", nivel: "Iniciante", duracao: "12 min", textoCompleto: "Aprenda a transformar aquela parede vazia em uma horta produtiva. Neste vídeo, mostramos como usar garrafas PET, canos de PVC ou pallets para criar uma estrutura vertical que otimiza o espaço e recebe luz solar. Perfeito para quem não tem quintal."),
            ConteudoEducacional(titulo: "Documentário: Oceanos de Plástico", subtitulo: "Documentário Impactante", descricaoCurta: "A poluição marinha.", icone: "film.fill", cor: .blue, categoria: "Video", nivel: "Todos", duracao: "45 min", textoCompleto: "Uma jornada investigativa pelos cinco giros oceânicos do planeta. Veja imagens chocantes de como o plástico afeta a vida selvagem e descubra como cientistas e ativistas estão lutando contra essa maré de poluição. (Link externo para o documentário)."),
            
            // **** NOVO CONTEÚDO ADICIONADO ****
            
            // Cursos Novos
            ConteudoEducacional(titulo: "Moda Sustentável (Slow Fashion)", subtitulo: "Curso Introdutório", descricaoCurta: "O impacto da indústria têxtil e alternativas.", icone: "tshirt.fill", cor: .pink, categoria: "Curso", nivel: "Iniciante", textoCompleto: "O Custo da Moda\n\nA indústria da moda é a segunda mais poluente do mundo, atrás apenas da de petróleo. O 'Fast Fashion' nos ensinou a comprar, usar pouco e descartar. Isso gera um volume absurdo de lixo têxtil, que não é biodegradável, além de consumir trilhões de litros de água.\n\nO 'Slow Fashion' é um movimento contrário. Ele preza por:\n* Peças duráveis e de qualidade.\n* Produção local e justa.\n* Uso de tecidos ecológicos (algodão orgânico, linho, cânhamo).\n* Transparência na cadeia produtiva."),
            ConteudoEducacional(titulo: "Finanças Verdes", subtitulo: "Curso Avançado", descricaoCurta: "Investindo em um futuro sustentável (ESG).", icone: "dollarsign.circle.fill", cor: .green, categoria: "Curso", nivel: "Avançado", textoCompleto: "O que é ESG?\n\nESG (Environmental, Social, and Governance) é uma sigla para Ambiental, Social e Governança. Ela se refere às boas práticas que uma empresa deve ter para ser considerada sustentável e responsável. Investidores do mundo todo estão usando critérios ESG para decidir onde aplicar seu dinheiro. Empresas que poluem, violam leis trabalhistas ou têm casos de corrupção estão perdendo valor de mercado."),
            ConteudoEducacional(titulo: "Consumo Consciente de Água", subtitulo: "Curso Prático", descricaoCurta: "Técnicas para reduzir sua pegada hídrica.", icone: "humidity.fill", cor: .blue, categoria: "Curso", nivel: "Todos", textoCompleto: "Água: O Recurso Finito\n\nEmbora 70% do planeta seja água, apenas uma pequena fração é potável. Neste curso, vamos além do óbvio (fechar a torneira). Você aprenderá sobre a 'água virtual': a quantidade de água usada para produzir tudo o que consumimos, desde uma camiseta de algodão até 1kg de carne.\n\nAprenda técnicas práticas:\n* Instalação de arejadores nas torneiras.\n* Reuso de água da máquina de lavar para lavar o quintal.\n* Cálculo da sua pegada hídrica pessoal."),
            
            // Artigos Novos
            ConteudoEducacional(titulo: "Microplásticos: O Inimigo Invisível", subtitulo: "Artigo de Alerta", descricaoCurta: "Como eles estão entrando na nossa cadeia alimentar.", icone: "testtube.2", cor: .red, categoria: "Artigo", nivel: "Intermediário", autor: "Dra. Ana Pereira", textoCompleto: "Você provavelmente está comendo plástico e não sabe. Microplásticos são partículas minúsculas (menores que 5mm) que vêm da degradação de lixos maiores ou de produtos como cosméticos e roupas sintéticas (poliéster).\n\nEles já foram encontrados no sal marinho, na água engarrafada, nos peixes e até no sangue humano. Os impactos na saúde a longo prazo ainda são incertos, mas alarmantes. Este artigo explora as fontes primárias e o que você pode fazer para reduzir sua exposição, como usar filtros de água e optar por roupas de fibras naturais."),
            ConteudoEducacional(titulo: "O Poder da Energia Eólica", subtitulo: "Artigo Explicativo", descricaoCurta: "Como funcionam as turbinas eólicas.", icone: "wind", cor: .gray, categoria: "Artigo", nivel: "Iniciante", autor: "Equipe Leafy", textoCompleto: "Aquelas 'hélices gigantes' no horizonte são mais do que parecem. Elas são turbinas eólicas, uma das formas mais eficientes de gerar eletricidade limpa. O vento gira as pás, que acionam um gerador interno, produzindo energia sem queimar combustíveis fósseis.\n\nO Brasil tem um potencial eólico gigantesco, especialmente no Nordeste. Embora existam desafios, como o impacto visual e em aves, a tecnologia é fundamental para nossa matriz energética."),
            ConteudoEducacional(titulo: "O que é 'Crédito de Carbono'?", subtitulo: "Artigo Financeiro", descricaoCurta: "Explicando o mercado de carbono de forma simples.", icone: "tree.fill", cor: .green, categoria: "Artigo", nivel: "Avançado", autor: "Carlos Mendes", textoCompleto: "Crédito de carbono é um certificado digital que comprova que uma empresa ou projeto evitou a emissão de 1 tonelada de CO2 (dióxido de carbono) na atmosfera. \n\nFunciona assim: uma empresa que polui muito (ex: uma fábrica) precisa 'zerar' suas emissões. Ela pode investir em tecnologia limpa, ou pode comprar créditos de carbono de um projeto que *remove* carbono da atmosfera (ex: um reflorestamento na Amazônia). É um mercado complexo, mas vital para financiar a preservação ambiental."),
            
            // Vídeos Novos
            ConteudoEducacional(titulo: "Receitas Sem Desperdício (Zero Waste)", subtitulo: "Vídeo Culinário", descricaoCurta: "Aprenda a usar cascas, talos e sementes.", icone: "carrot.fill", cor: .orange, categoria: "Video", nivel: "Iniciante", duracao: "15 min", textoCompleto: "Não jogue fora a casca da banana! Vamos transformá-la em 'carne' desfiada vegana. E o talo da couve? Vira um recheio delicioso! A semente da abóbora? Um snack crocante e nutritivo. Aprenda 3 receitas incríveis para aproveitar 100% dos alimentos."),
            ConteudoEducacional(titulo: "Entrevista: O Futuro das Cidades", subtitulo: "Debate com Especialista", descricaoCurta: "Cidades mais verdes, transporte público e mais.", icone: "bus.fill", cor: .purple, categoria: "Video", nivel: "Intermediário", duracao: "30 min", textoCompleto: "Conversamos com o arquiteto e urbanista João Martins sobre o conceito de 'Cidades de 15 minutos'. Imagine poder resolver sua vida (trabalho, escola, compras, lazer) a 15 minutos de caminhada ou bicicleta da sua casa. Falamos sobre ciclovias, parques lineares e o fim da dependência do carro."),
            ConteudoEducacional(titulo: "DIY: Sabão Ecológico com Óleo Usado", subtitulo: "Vídeo Tutorial", descricaoCurta: "Transforme óleo de cozinha em sabão.", icone: "bubbles.and.sparkles", cor: .yellow, categoria: "Video", nivel: "Iniciante", duracao: "8 min", textoCompleto: "Nunca mais jogue óleo de cozinha no ralo! 1 litro de óleo pode contaminar 25 mil litros de água. Neste tutorial rápido, mostramos a receita segura (usando soda cáustica com proteção!) para transformar esse resíduo em barras de sabão de limpeza de alta qualidade."),
            
            // Ebook Novo
            ConteudoEducacional(titulo: "Guia do Pequeno Ativista", subtitulo: "E-book Interativo", descricaoCurta: "Como fazer a diferença na sua escola ou bairro.", icone: "figure.stand", cor: .blue, categoria: "Ebook", nivel: "Todos", textoCompleto: "Sua Voz Importa\n\nNão é preciso ser adulto para mudar o mundo. Se você está preocupado com o futuro do planeta, este guia é para você.\n\nCapítulo 1: Comece Pequeno.\nComo organizar um dia de limpeza na praça do seu bairro ou uma coleta de lixo eletrônico na sua escola.\n\nCapítulo 2: Use a Internet.\nComo criar uma petição online (abaixo-assinado) para pedir ciclovias na sua cidade ou lixeiras de reciclagem no seu condomínio.")
        ]

        loadProfileFromLocalCache()
        setupAuthListener()
        listenToChatMessages()
    }
    
    // MARK: - Persistência Local (Cache)
    private func saveProfileToLocalCache(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: userProfileCacheKey)
        }
    }

    private func loadProfileFromLocalCache() {
        if let data = UserDefaults.standard.data(forKey: userProfileCacheKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.userProfile = profile
            self.userName = profile.name
            
            // Carrega o progresso salvo localmente
            if let completedIDs = profile.completedContent {
                self.conteudosCompletos = Set(completedIDs.compactMap { UUID(uuidString: $0) })
            }
        }
    }

    private func clearLocalCache() {
        UserDefaults.standard.removeObject(forKey: userProfileCacheKey)
    }

    // MARK: - Firebase Auth & Firestore
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
                self.clearLocalCache()
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
                    return
                }

                // NOVO: CHECK DE SEGURANÇA PARA LOGIN SOCIAL
                guard let document = documentSnapshot, document.exists else {
                    print("⚠️ AVISO: Documento do perfil NÃO encontrado.")
                    // Se o documento não existe (ex: login social novo)
                    // e o usuário auth existe, podemos criar um perfil
                    // Isso é um fallback caso o fluxo de login falhe em criar
                    if let authUser = Auth.auth().currentUser, authUser.uid == userID {
                        print("Documento não encontrado para usuário logado, criando perfil social (fallback)...")
                        self.createProfileForSocialUser(authUser)
                    }
                    return
                }
                // FIM DA ADIÇÃO

                let data = document.data()
                let name = data?["name"] as? String ?? "Nome Padrão"
                let profileImageURL = data?["profileImageURL"] as? String
                let bio = data?["bio"] as? String ?? ""
                let points = data?["points"] as? Int ?? 0
                
                // Carrega o progresso salvo do Firebase
                let completedIDs = data?["completedContent"] as? [String] ?? []

                let profile = UserProfile(id: document.documentID, name: name, profileImageURL: profileImageURL, bio: bio, points: points, completedContent: completedIDs)

                DispatchQueue.main.async {
                    self.userProfile = profile
                    self.userName = profile.name
                    self.saveProfileToLocalCache(profile)
                    
                    // Popula o set local com os dados do Firebase
                    self.conteudosCompletos = Set(completedIDs.compactMap { UUID(uuidString: $0) })

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
                guard let documents = querySnapshot?.documents else { return }

                let newMessages = documents.compactMap { document -> ChatMessage? in
                    let data = document.data()
                    let id = document.documentID
                    let text = data["text"] as? String ?? ""
                    let userName = data["userName"] as? String ?? "Anônimo"
                    let userID = data["userID"] as? String ?? ""
                    let userPhotoURL = data["userPhotoURL"] as? String
                    let timestamp = data["timestamp"] as? Timestamp

                    guard let date = timestamp?.dateValue() else { return nil }
                    let isCurrentUser = (userID == Auth.auth().currentUser?.uid)

                    return ChatMessage(id: id, text: text, user: userName, userID: userID, userPhotoURL: userPhotoURL, isCurrentUser: isCurrentUser, timestamp: date)
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
            "userPhotoURL": self.userProfile?.profileImageURL ?? "",
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("chatMessages").addDocument(data: messageData) { error in
            if let error = error { print("Erro ao enviar mensagem: \(error.localizedDescription)") }
        }
    }

    func createUserProfile(userID: String, name: String) {
        let profile = UserProfile(id: userID, name: name, profileImageURL: nil, bio: "", points: 0, completedContent: [])
        
        let profileData: [String: Any] = [
            "name": name,
            "profileImageURL": NSNull(),
            "bio": "",
            "points": 0,
            "completedContent": [] // <-- Novo campo
        ]

        db.collection("users").document(userID).setData(profileData) { error in
            if let error = error {
                print("Erro ao criar perfil inicial: \(error)")
            } else {
                self.saveProfileToLocalCache(profile)
            }
        }
    }

    func addPoints(_ amount: Int) {
        guard let userID = Auth.auth().currentUser?.uid, var currentProfile = self.userProfile else { return }
        let newPoints = currentProfile.points + amount

        currentProfile.points = newPoints
        self.userProfile = currentProfile
        self.saveProfileToLocalCache(currentProfile)

        db.collection("users").document(userID).updateData(["points": newPoints]) { error in
            if let error = error {
                print("Erro ao atualizar pontos no servidor: \(error.localizedDescription)")
            }
        }
    }

    func updateUserName(newName: String) {
        guard let userID = Auth.auth().currentUser?.uid, var currentProfile = self.userProfile else { return }
        
        currentProfile.name = newName
        self.userProfile = currentProfile
        self.userName = newName
        self.saveProfileToLocalCache(currentProfile)
        
        db.collection("users").document(userID).updateData(["name": newName])
        
        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
        changeRequest?.displayName = newName
        changeRequest?.commitChanges(completion: nil)
    }

    func updateUserBio(newBio: String) {
        guard let userID = Auth.auth().currentUser?.uid, var currentProfile = self.userProfile else { return }
        
        currentProfile.bio = newBio
        self.userProfile = currentProfile
        self.saveProfileToLocalCache(currentProfile)
        
        db.collection("users").document(userID).updateData(["bio": newBio])
    }

    func sendPasswordReset(email: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@") else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Por favor, insira um e-mail válido."])
        }
        try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
    }

    // MARK: - Social Login Helpers (NOVAS FUNÇÕES)
    
    // Helper para pegar a View Controller que está no topo (necessário para os pop-ups de login)
    private func getTopViewController() -> UIViewController? {
        // Pega a cena conectada
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            print("🔴 ERRO: Não foi possível encontrar o rootViewController.")
            return nil
        }
        
        // Itera para encontrar o VC no topo
        var topViewController = rootViewController
        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }
        return topViewController
    }
    
    // Função para criar perfil para usuário de login social (se for novo)
    fileprivate func createProfileForSocialUser(_ user: User) {
        let name = user.displayName ?? "Usuário"
        let photoURL = user.photoURL?.absoluteString
        
        let profile = UserProfile(id: user.uid, name: name, profileImageURL: photoURL, bio: "", points: 0, completedContent: [])
        
        let profileData: [String: Any] = [
            "name": name,
            "profileImageURL": photoURL ?? NSNull(),
            "bio": "",
            "points": 0,
            "completedContent": []
        ]
        
        // Seta os dados no Firestore. O listener 'listenToUserProfile'
        // será acionado automaticamente após isso.
        // Usamos .setData com merge=true para criar ou atualizar sem sobrescrever
        // campos existentes se o usuário já tiver dados parciais.
        db.collection("users").document(user.uid).setData(profileData, merge: true) { error in
            if let error = error {
                print("🔴 ERRO ao criar/mesclar perfil social: \(error)")
            } else {
                print("✅ Perfil social criado/mesclado no Firestore para \(user.uid)")
                self.saveProfileToLocalCache(profile)
            }
        }
    }
    
    // MARK: - Funções de Login Social (Chamadas pela View) (CORRIGIDAS)

    @MainActor
    func signInWithGoogle() async {
        print("Iniciando login com Google...")
        
        // 1. Pega a View Controller do topo
        guard let topVC = getTopViewController() else {
            print("🔴 ERRO: Não foi possível obter topVC para Google Sign-In.")
            return
        }

        do {
            // 2. Inicia o fluxo de login do Google
            let gidUser = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)
            
            guard let idToken = gidUser.user.idToken?.tokenString else {
                print("🔴 ERRO: Token ID do Google não encontrado.")
                return
            }
            
            let accessToken = gidUser.user.accessToken.tokenString
            
            // 3. Cria a credencial do Firebase
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                         accessToken: accessToken)
            
            // 4. Faz login no Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Login com Google (Firebase) OK. User: \(authResult.user.uid)")
            
            // 5. Se for um *novo* usuário, cria o perfil no Firestore
            if authResult.additionalUserInfo?.isNewUser == true {
                print("Detectado novo usuário do Google. Criando perfil...")
                createProfileForSocialUser(authResult.user)
            }
            
        } catch {
            print("🔴 ERRO no signInWithGoogle: \(error.localizedDescription)")
        }
    }
    
    @MainActor
        func signInWithGitHub() async {
            print("Iniciando login com GitHub...")

            let provider = OAuthProvider(providerID: "github.com")
            
            do {
                // 1. Pega a credencial do GitHub (isso abrirá o SFSafariViewController)
                // ---- CORREÇÃO APLICADA AQUI ----
                // O método assíncrono correto é 'credential(with:)'
                let credential = try await provider.credential(with: nil)
                
                // 2. Faz login no Firebase
                // Esta é a linha que estava dando o erro (provavelmente a sua linha 459)
                let authResult = try await Auth.auth().signIn(with: credential)
                print("✅ Login com GitHub (Firebase) OK. User: \(authResult.user.uid)")
                
                // 3. Se for um *novo* usuário, cria o perfil no Firestore
                if authResult.additionalUserInfo?.isNewUser == true {
                    print("Detectado novo usuário do GitHub. Criando perfil...")
                    createProfileForSocialUser(authResult.user)
                }
                
            } catch {
                print("🔴 ERRO no signInWithGitHub: \(error.localizedDescription)")
            }
        }
    
    // (FIM DAS NOVAS FUNÇÕES / CORREÇÕES)

    func updateProfileImage(imageData: Data) {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let storageRef = storage.reference().child("profileImages/\(userID).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        storageRef.putData(imageData, metadata: metadata) { [weak self] metadata, error in
            guard let self = self else { return }
            guard metadata != nil else { return }

            storageRef.downloadURL { url, error in
                guard let downloadURL = url else { return }
                let urlString = downloadURL.absoluteString

                self.db.collection("users").document(userID).updateData(["profileImageURL": urlString])
                
                DispatchQueue.main.async {
                    if var currentProfile = self.userProfile {
                        currentProfile.profileImageURL = urlString
                        self.userProfile = currentProfile
                        self.saveProfileToLocalCache(currentProfile)
                    }
                    self.userProfileImage = nil
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

    // **** FUNÇÃO DE COMPLETAR MODIFICADA (4/4) ****
    func toggleCompletion(for item: ConteudoEducacional) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        // 1. Atualiza o set local (otimista)
        DispatchQueue.main.async {
            if self.conteudosCompletos.contains(item.id) {
                self.conteudosCompletos.remove(item.id)
            } else {
                self.conteudosCompletos.insert(item.id)
            }
            
            // 2. Prepara os dados para o Firebase
            let completedIDsAsString = self.conteudosCompletos.map { $0.uuidString }
            
            // 3. Atualiza o cache local
            if var profile = self.userProfile {
                profile.completedContent = completedIDsAsString
                self.saveProfileToLocalCache(profile)
            }
            
            // 4. Salva no Firebase
            self.db.collection("users").document(userID).updateData(["completedContent": completedIDsAsString]) { error in
                if let error = error {
                    print("Erro ao salvar progresso: \(error.localizedDescription)")
                    // Aqui você poderia reverter a mudança local se falhasse
                } else {
                    print("Progresso salvo no Firebase!")
                }
            }
        }
    }

     deinit {
         stopListening()
         if let handle = authStateHandle {
             Auth.auth().removeStateDidChangeListener(handle)
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
        HStack(alignment: .bottom, spacing: 8) {
            if message.isCurrentUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.corFolhaClara)
                        .foregroundColor(.white)
                        .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft]))
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.trailing, 4)
                }
            } else {
                AvatarView(name: message.user, photoURL: message.userPhotoURL)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(message.user)
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    Text(message.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomRight]))

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                }
                Spacer()
            }
        }
    }
}

struct AvatarView: View {
    let name: String
    let photoURL: String?

    var initial: String {
        String(name.prefix(1)).uppercased()
    }
    var avatarColor: Color {
        let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .teal]
        let hash = name.hashValue
        let index = abs(hash) % colors.count
        return colors[index].opacity(0.7)
    }

    var body: some View {
        if let urlString = photoURL, !urlString.isEmpty, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    fallbackAvatar
                }
            }
            .frame(width: 35, height: 35)
            .clipShape(Circle())
        } else {
            fallbackAvatar
        }
    }
    
    var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(avatarColor)
                .frame(width: 35, height: 35)
            Text(initial)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
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
    @Environment(\.colorScheme) var colorScheme
    @State private var newMessageText: String = ""

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        VStack(spacing: 0) {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(appDataStore.chatMessages) { message in
                            ChatBubble(message: message).id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
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

            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 10) {
                    TextField("Digite sua mensagem...", text: $newMessageText)
                        .padding(12)
                        .background(theme.fundoCampoInput)
                        .cornerRadius(25)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.corFolhaClara)
                            .clipShape(Circle())
                    }
                    .disabled(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(theme.fundoCard)
            }
        }
        .navigationTitle("Comunidade")
        .background(theme.fundo.ignoresSafeArea())
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
                    
                    Text(.init(item.textoCompleto ?? "Conteúdo programático em desenvolvimento."))
                        .font(.body)
                        .lineSpacing(6)
                    
                    Divider()
                    
                    // **** BOTÃO "REFAZER" MODIFICADO ****
                    Button(action: {
                        appDataStore.toggleCompletion(for: item)
                        dismiss()
                    }) {
                        Label(isCompleto ? "Refazer Módulo" : "Marcar como Concluído",
                              systemImage: isCompleto ? "arrow.counterclockwise.circle.fill" : "checkmark.circle.fill")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isCompleto ? Color.corDestaque : Color.corFolhaClara) // <-- Cor modificada
                            .foregroundColor(.white)
                            .cornerRadius(12)
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

struct InternalBookView: View {
    let ebook: ConteudoEducacional
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text(ebook.titulo)
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(theme.corTerra)
                        .padding(.bottom, 5)
                    
                    if let text = ebook.textoCompleto {
                        Text(.init(text))
                            .font(.body)
                            .lineSpacing(6)
                    } else {
                        Text("Conteúdo não disponível.")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
            }
            .background(theme.fundo.ignoresSafeArea())
            .navigationTitle("Leitor Leafy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

struct EbookReaderView: View {
    let ebook: ConteudoEducacional
    @Environment(\.colorScheme) var colorScheme
    @State private var showSafari = false
    @State private var showInternalReader = false

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
                        Label("Ler E-book Externo", systemImage: "safari.fill")
                            .font(.headline.weight(.bold))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.corFolhaClara)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .corFolhaClara.opacity(0.4), radius: 5, y: 3)
                    }
                    .sheet(isPresented: $showSafari) {
                        SafariView(url: url).ignoresSafeArea()
                    }
                } else if ebook.textoCompleto != nil {
                     Button { showInternalReader = true } label: {
                         Label("Ler Agora", systemImage: "book.fill")
                             .font(.headline.weight(.bold))
                             .padding()
                             .frame(maxWidth: .infinity)
                             .background(Color.corFolhaClara)
                             .foregroundColor(.white)
                             .cornerRadius(12)
                             .shadow(color: .corFolhaClara.opacity(0.4), radius: 5, y: 3)
                     }
                     .sheet(isPresented: $showInternalReader) {
                         InternalBookView(ebook: ebook)
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

                Text(.init(artigo.textoCompleto ?? "Este artigo está sendo escrito e estará disponível em breve."))
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

                Text(.init(video.textoCompleto ?? video.descricaoCurta))
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
    
    // **** NOVO: Acessa o AppDataStore ****
    @EnvironmentObject var appDataStore: AppDataStore

    init(curso: ConteudoEducacional) {
        self.curso = curso
        _progress = State(initialValue: [0.2, 0.5, 0.8, 0.95].randomElement()!)
    }

    var body: some View {
        // **** NOVO: Verifica se o curso está completo ****
        let isCompleto = appDataStore.conteudosCompletos.contains(curso.id)
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
        // **** NOVO: Aplica opacidade se estiver completo ****
        .opacity(isCompleto ? 0.6 : 1.0)
    }
}

// MARK: - Novo Minigame (Quiz)

struct QuizQuestion: Identifiable {
    let id = UUID()
    let questionText: String
    let options: [String]
    let correctAnswerIndex: Int
}

struct MinigameQuizView: View {
    @Environment(\.dismiss) var dismiss
    
    // Lista de Perguntas
    let questions: [QuizQuestion] = [
        QuizQuestion(questionText: "Qual destes NÃO é um dos 3 R's clássicos da sustentabilidade?", options: ["Reduzir", "Reutilizar", "Reclamar", "Reciclar"], correctAnswerIndex: 2),
        QuizQuestion(questionText: "Qual gás é o principal contribuinte para o efeito estufa?", options: ["Oxigênio", "Dióxido de Carbono (CO2)", "Nitrogênio", "Hélio"], correctAnswerIndex: 1),
        QuizQuestion(questionText: "O que é 'compostagem'?", options: ["Um tipo de lixo tóxico", "Queimar lixo orgânico", "Processo de decomposição de matéria orgânica para criar adubo", "Um filtro de água"], correctAnswerIndex: 2),
        QuizQuestion(questionText: "Qual a cor da lixeira para descarte de PLÁSTICO?", options: ["Azul", "Amarelo", "Verde", "Vermelho"], correctAnswerIndex: 3)
    ]
    
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswerIndex: Int? = nil
    @State private var score = 0
    @State private var quizFinished = false
    
    // Closure para retornar a pontuação
    var onQuizCompleted: (Int) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                if quizFinished {
                    // --- Tela de Pontuação ---
                    VStack(spacing: 20) {
                        Text("Desafio Concluído!")
                            .font(.largeTitle.weight(.bold))
                        
                        Image(systemName: score > 2 ? "star.fill" : "star.slash.fill")
                            .font(.system(size: 80))
                            .foregroundColor(score > 2 ? .corDestaque : .gray)
                        
                        Text("Você acertou \(score) de \(questions.count)!")
                            .font(.title2)
                        
                        Text("Você ganhou \(score * 10) pontos!")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.corFolhaClara)
                        
                        Button(action: {
                            onQuizCompleted(score * 10) // Retorna os pontos (10 por acerto)
                            dismiss()
                        }) {
                            Label("Coletar Pontos e Sair", systemImage: "arrow.down.circle.fill")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.corFolhaClara)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding()
                    
                } else {
                    // --- Tela da Pergunta ---
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Questão \(currentQuestionIndex + 1) de \(questions.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(questions[currentQuestionIndex].questionText)
                            .font(.title2.weight(.bold))
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                        
                        // Opções
                        ForEach(0..<questions[currentQuestionIndex].options.count, id: \.self) { index in
                            Button(action: {
                                selectedAnswerIndex = index
                            }) {
                                HStack {
                                    Image(systemName: selectedAnswerIndex == index ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedAnswerIndex == index ? .corFolhaClara : .gray)
                                    Text(questions[currentQuestionIndex].options[index])
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                        
                        // Botão de Próximo/Finalizar
                        Button(action: nextQuestion) {
                            Text(currentQuestionIndex == questions.count - 1 ? "Finalizar" : "Próxima Pergunta")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedAnswerIndex == nil ? Color.gray.opacity(0.5) : Color.corDestaque)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(selectedAnswerIndex == nil)
                        .animation(.easeInOut, value: selectedAnswerIndex)
                    }
                    .padding()
                }
                Spacer()
            }
            .navigationTitle("Quiz Sustentável")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sair") { dismiss() }
                }
            }
        }
    }
    
    func nextQuestion() {
        // Checa a resposta
        if selectedAnswerIndex == questions[currentQuestionIndex].correctAnswerIndex {
            score += 1
        }
        
        // Reseta a seleção
        selectedAnswerIndex = nil
        
        // Avança
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
        } else {
            // Terminou o quiz
            withAnimation {
                quizFinished = true
            }
        }
    }
}


struct CursosView: View {
    let logoutAction: () -> Void
    @EnvironmentObject var appDataStore: AppDataStore
    @Environment(\.colorScheme) var colorScheme
    @State private var showProfile = false

    // MARK: - Propriedades do Minigame (Quiz)
    @State private var showMinigameQuiz = false
    @State private var showPointsFeedback = false
    @State private var pontosGanhosSessao = 0

    // **** NOVO: Lógica de Ordenação dos Cursos ****
    private var todosOsCursos: [ConteudoEducacional] {
        let cursos = appDataStore.conteudos.filter { $0.categoria == "Curso" && !$0.isMandatory }
        
        // Ordena: incompletos primeiro, completos por último
        return cursos.sorted { (curso1, curso2) -> Bool in
            let completo1 = appDataStore.conteudosCompletos.contains(curso1.id)
            let completo2 = appDataStore.conteudosCompletos.contains(curso2.id)
            
            if !completo1 && completo2 {
                return true // curso1 (incompleto) vem antes de curso2 (completo)
            } else if completo1 && !completo2 {
                return false // curso1 (completo) vem depois de curso2 (incompleto)
            } else {
                // Se ambos forem completos ou ambos incompletos, usa a ordem original (pela forma como o filtro foi feito)
                // Para manter uma ordem estável, poderíamos comparar títulos, mas não é necessário.
                return false
            }
        }
    }

    var body: some View {
        let theme = AppTheme(colorScheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                
                // MARK: - Minigame (Quiz)
                ZStack {
                    VStack(spacing: 20) {
                        Image(systemName: "leaf.arrow.triangle.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(.corFolhaClara)
                        Text("Desafio: Quiz Verde")
                            .font(.title2.weight(.bold))
                            .foregroundColor(theme.corTerra)
                        Text("Responda \(MinigameQuizView(onQuizCompleted: {_ in}).questions.count) perguntas sobre sustentabilidade e ganhe pontos por seus acertos!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Iniciar Desafio!") {
                            showMinigameQuiz = true
                        }
                        .font(.headline.weight(.bold))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.corDestaque)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity)
                    .background(theme.fundoCard)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // Feedback de pontos (igual ao anterior)
                    if showPointsFeedback {
                        VStack(spacing: 10) {
                            Text("Desafio Concluído!")
                                .font(.title3.weight(.bold))
                            Text("+\(pontosGanhosSessao) Pontos")
                                .font(.largeTitle.weight(.heavy))
                                .foregroundColor(.corDestaque)
                        }
                        .padding(30)
                        .background(theme.fundoCard)
                        .cornerRadius(20)
                        .shadow(radius: 20)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(2)
                    }
                }
                .sheet(isPresented: $showMinigameQuiz) {
                    MinigameQuizView { points in
                        // Esta é a completion handler que é chamada ao fechar o quiz
                        collectQuizPoints(points: points)
                    }
                }

                // MARK: - Lista de Cursos (Agora ordenada)
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
                    .animation(.easeInOut, value: todosOsCursos) // Anima a reordenação
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showProfile = true }) {
                    Image(systemName: "person.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showProfile) { ProfileView(logoutAction: logoutAction) }
    }
    
    // Nova função para coletar pontos do Quiz
    private func collectQuizPoints(points: Int) {
        if points > 0 {
            pontosGanhosSessao = points
            appDataStore.addPoints(points)
            
            withAnimation {
                showPointsFeedback = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    showPointsFeedback = false
                }
            }
        }
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

// MARK: - WebView (Para Ebooks/Safari)

// **** CORREÇÃO MINIGAME TELA BRANCA (1/1) ****
// Habilitamos o JavaScript para a WebView carregar o jogo.
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        // --- CORREÇÃO: Habilitar JavaScript ---
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true // <--- ISSO CORRIGE A TELA BRANCA
        
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        // --- Fim da Correção ---
        
        // Esta webview (Safari) deve permitir scroll
        webView.scrollView.isScrollEnabled = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

// MARK: - Views de Perfil e Configurações

// **** NOVA VIEW (1/2): Tela de Aparência ****
struct AppearanceSettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("appIconName") private var appIconName: String = "Padrão"
    
    var body: some View {
        Form {
            Section(header: Text("Tema"), footer: Text("O modo escuro ajuda a economizar bateria em telas OLED.")) {
                Toggle("Modo Escuro", isOn: $isDarkMode)
            }
            
            Section(header: Text("Ícone do App"), footer: Text("A mudança pode levar alguns segundos para ser aplicada.")) {
                Picker("Ícone do App", selection: $appIconName) {
                    Text("Padrão").tag("Padrão")
                    Text("Claro").tag("iconClaro") // "iconClaro" deve bater com a chave no Info.plist
                    Text("Escuro").tag("iconEscuro") // "iconEscuro" deve bater com a chave no Info.plist
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: appIconName) { _, newIcon in
                    changeAppIcon(to: newIcon)
                }
            }
        }
        .navigationTitle("Aparência")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // **** NOVA VIEW (2/2): Função de troca de ícone ****
    private func changeAppIcon(to iconName: String) {
        let iconToSet: String? = (iconName == "Padrão") ? nil : iconName
        
        guard UIApplication.shared.supportsAlternateIcons else {
            print("App não suporta ícones alternativos.")
            return
        }

        UIApplication.shared.setAlternateIconName(iconToSet) { error in
            if let error = error {
                print("Erro ao trocar o ícone: \(error.localizedDescription)")
            } else {
                print("Ícone do app trocado com sucesso para: \(iconName)")
            }
        }
    }
}


struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appDataStore: AppDataStore
    let logoutAction: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    // As @AppStorage foram movidas para 'AppearanceSettingsView'
    
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
                
                // **** SEÇÃO DE APARÊNCIA MODIFICADA ****
                Section(header: Text("Personalização")) {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label("Aparência", systemImage: "paintbrush.fill")
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
    
    @AppStorage("isDarkMode") private var isDarkMode = false
    
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

            Image(isDarkMode ? "logo_escuro" : "logo_claro")
                .resizable()
                .scaledToFit()
                .frame(width: 100)
                .foregroundColor(.white)
                .scaleEffect(exitLeafScale)
                .opacity(exitLeafOpacity)
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

// MARK: - LOGIN VIEW ATUALIZADA (COM ÍCONES E CORREÇÕES)

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
    
    // NOVO: Estado de carregamento para botões sociais
    @State private var isSocialLoading = false
    
    @AppStorage("isDarkMode") private var isDarkMode = false

    private func attemptLogin() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = senha.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            self.alertMessage = "Por favor, preencha o e-mail e a senha."; self.showAlert = true; return
        }
        
        // Desativa o loading social se estava ativo
        isSocialLoading = false
        
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
            
            // Adicionado ScrollView para telas menores
            ScrollView {
                VStack {
                    Spacer(minLength: 50) // Garante espaço no topo
                    
                    Image(isDarkMode ? "logo_escuro" : "logo_claro")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.corFolhaClara)
                        .padding(.bottom, 30)

                    VStack(spacing: 20) {
                        Text("Bem-vindo(a)!").font(.largeTitle.weight(.bold)).foregroundColor(theme.corTerra)
                        
                        // --- Login com E-mail ---
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
                            .padding(.top, -10) // Ajuste de layout

                            Button(action: attemptLogin) { Text("Entrar").font(.body.weight(.bold)).frame(maxWidth: .infinity).padding().background(Color.corFolhaClara).foregroundColor(.white).cornerRadius(12).shadow(color: .corFolhaClara.opacity(0.5), radius: 10, x: 0, y: 5) }
                                .padding(.top, 10)
                                .disabled(isSocialLoading) // Desativa se o login social estiver em progresso
                        }
                        
                        // --- Divisor "OU" ---
                        HStack(spacing: 15) {
                            VStack { Divider().background(Color.gray.opacity(0.5)) }
                            Text("OU")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.secondary)
                            VStack { Divider().background(Color.gray.opacity(0.5)) }
                        }
                        .padding(.vertical, 15) // Espaçamento do divisor
                        
                        // --- Botões Sociais ---
                        VStack(spacing: 15) {
                            // Botão Google
                            Button(action: {
                                isSocialLoading = true
                                Task {
                                    await appDataStore.signInWithGoogle()
                                    // O listener do Auth cuidará da transição
                                    isSocialLoading = false // Reseta em caso de falha
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image("google_icon") // <-- USA IMAGEM DO ASSETS
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22) // Tamanho do ícone
                                    Text("Continuar com Google")
                                }
                                .font(.headline)
                                .foregroundColor(.primary) // Texto escuro para botão claro
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(theme.fundoCard) // Fundo branco/cinza claro
                                .cornerRadius(12)
                                .overlay( // Borda sutil
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(isSocialLoading)

                            // Botão GitHub
                            Button(action: {
                                isSocialLoading = true
                                Task {
                                    await appDataStore.signInWithGitHub()
                                    // O listener do Auth cuidará da transição
                                    isSocialLoading = false // Reseta em caso de falha
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image("github_icon") // <-- USA IMAGEM DO ASSETS
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .colorInvert() // Inverte a cor da imagem (de preto para branco)
                                    Text("Continuar com GitHub")
                                }
                                .font(.headline)
                                .foregroundColor(.white) // Texto branco para botão escuro
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black) // Fundo preto
                                .cornerRadius(12)
                            }
                            .disabled(isSocialLoading)
                            
                            // Indicador de carregamento social
                            if isSocialLoading {
                                ProgressView()
                                    .padding(.top, 10)
                            }
                        }
                        
                        // --- Link de Cadastro ---
                        Divider().padding(.vertical, 20)
                        Button { withAnimation { currentAuthScreen = .cadastro } } label: { VStack { Text("Não tem conta?").foregroundColor(.gray).font(.caption); Text("Crie uma agora!").font(.caption.weight(.bold)).foregroundColor(.corFolhaClara) } }
                        
                    }.padding(.horizontal, 40)
                    
                    Spacer(minLength: 50) // Garante espaço embaixo
                }
            } // Fim do ScrollView
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
// FIM DA LOGIN VIEW ATUALIZADA


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
    
    @AppStorage("isDarkMode") private var isDarkMode = false

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
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    private var allMandatoryCompleted: Bool {
        let mandatoryIDs = Set(appDataStore.conteudos.filter { $0.isMandatory }.map { $0.id })
        return mandatoryIDs.isSubset(of: appDataStore.conteudosCompletos)
    }

    private func logout() {
        do {
            // NOVO: Adiciona logout do Google Sign In
            GIDSignIn.sharedInstance.signOut()
            print("Google GIDSignIn.sharedInstance.signOut() chamado.")
            // FIM DA ADIÇÃO
            
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
    }
}
