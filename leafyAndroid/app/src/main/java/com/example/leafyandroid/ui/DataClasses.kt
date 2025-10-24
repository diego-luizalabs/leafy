package com.example.leafyandroid.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.Timestamp
import com.google.firebase.storage.FirebaseStorage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.util.Date
import java.util.UUID

// 1. O ViewModel substitui o ObservableObject do SwiftUI
class AppDataStoreViewModel : ViewModel() {

    // Instâncias do Firebase (equivalente ao init no Swift)
    private val auth = FirebaseAuth.getInstance()
    private val db = FirebaseFirestore.getInstance()
    private val storage = FirebaseStorage.getInstance()

    // Listeners do Firebase (equivalente aos ListenerRegistration do Swift)
    private var chatListenerRegistration: ListenerRegistration? = null
    private var userProfileListenerRegistration: ListenerRegistration? = null

    // =========================================================================
    // 2. Variáveis de Estado (Substituindo @Published)
    // Usamos StateFlow para emitir mudanças para o Compose
    // =========================================================================

    // O equivalente a @Published var userProfile: UserProfile?
    private val _userProfile = MutableStateFlow<UserProfile?>(null)
    val userProfile: StateFlow<UserProfile?> = _userProfile

    // O equivalente a @Published var userRole: UserRole?
    private val _userRole = MutableStateFlow<UserRole?>(null)
    val userRole: StateFlow<UserRole?> = _userRole

    // O equivalente a @Published var userName: String
    private val _userName = MutableStateFlow("Visitante")
    val userName: StateFlow<String> = _userName

    // O equivalente a @Published var chatMessages: [ChatMessage]
    private val _chatMessages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val chatMessages: StateFlow<List<ChatMessage>> = _chatMessages

    // O equivalente a @Published var conteudos: [ConteudoEducacional] (Estaticamente carregado)
    private val _conteudos = MutableStateFlow(carregarConteudosIniciais())
    val conteudos: StateFlow<List<ConteudoEducacional>> = _conteudos

    // O equivalente a @Published var conteudosCompletos: Set<UUID>
    private val _conteudosCompletos = MutableStateFlow<Set<String>>(emptySet())
    val conteudosCompletos: StateFlow<Set<String>> = _conteudosCompletos

    // =========================================================================
    // 3. Inicialização e Listeners
    // =========================================================================

    init {
        // A CoroutineScope do ViewModel é usada para rodar tarefas assíncronas
        // O setupAuthListener do Swift é a forma do Android:
        auth.addAuthStateListener { firebaseAuth ->
            val user = firebaseAuth.currentUser
            if (user != null) {
                println("Auth state changed: User logged in (${user.uid}). Starting profile listener.")
                listenToUserProfile(userID = user.uid)
                listenToChatMessages()
            } else {
                println("Auth state changed: User logged out. Stopping listeners.")
                stopListening()
                _userProfile.value = null
                _userRole.value = null
                _userName.value = "Visitante"
                _chatMessages.value = emptyList()
                // A imagem do perfil será tratada na UI com Coil
            }
        }
    }

    // Leitura do perfil (Substituindo listenToUserProfile(userID: String))
    fun listenToUserProfile(userID: String) {
        userProfileListenerRegistration?.remove()

        userProfileListenerRegistration = db.collection("users").document(userID)
            .addSnapshotListener { documentSnapshot, error ->
                if (error != null) {
                    println("Erro ao buscar perfil: ${error.localizedMessage}")
                    return@addSnapshotListener
                }

                if (documentSnapshot != null && documentSnapshot.exists()) {
                    val data = documentSnapshot.data
                    val name = data?.get("name") as? String ?: "Usuário Desconhecido"
                    val roleString = data?.get("role") as? String ?: UserRole.ESTUDANTE.roleName
                    val profileImageURL = data?.get("profileImageURL") as? String

                    val role = UserRole.fromString(roleString)
                    val profile = UserProfile(
                        id = documentSnapshot.id,
                        name = name,
                        role = roleString,
                        profileImageURL = profileImageURL
                    )

                    _userProfile.value = profile
                    _userName.value = profile.name
                    _userRole.value = role
                    println("Perfil carregado/atualizado manualmente: ${profile.name}")
                }
            }
    }

    // Leitura do chat (Substituindo listenToChatMessages())
    fun listenToChatMessages() {
        chatListenerRegistration?.remove()

        chatListenerRegistration = db.collection("chatMessages")
            .orderBy("timestamp", Query.Direction.ASCENDING)
            .limitToLast(50)
            .addSnapshotListener { querySnapshot, error ->
                if (error != null) {
                    println("Erro ao buscar mensagens: ${error.localizedMessage}")
                    return@addSnapshotListener
                }

                val messages = querySnapshot?.documents?.mapNotNull { document ->
                    val data = document.data
                    val text = data["text"] as? String ?: ""
                    val userName = data["userName"] as? String ?: "Anônimo"
                    val userID = data["userID"] as? String ?: ""
                    val timestamp = data["timestamp"] as? Timestamp ?: Timestamp.now()

                    val isCurrentUser = (userID == auth.currentUser?.uid)

                    // Cria o objeto ChatMessage e injeta a propriedade isCurrentUser
                    document.toObject(ChatMessage::class.java)?.apply {
                        this.isCurrentUser = isCurrentUser
                        this.id = document.id // Usa o ID real do documento
                    }
                } ?: emptyList()

                _chatMessages.value = messages
            }
    }

    // Função de limpeza
    fun stopListening() {
        chatListenerRegistration?.remove()
        userProfileListenerRegistration?.remove()
    }

    // =========================================================================
    // 4. Funções de Ação (Substituindo sendMessage, createUserProfile, etc.)
    // =========================================================================

    // Envio manual do chat (Substituindo sendMessage(_ text: String))
    fun sendMessage(text: String) {
        if (text.trim().isEmpty()) return

        val userID = auth.currentUser?.uid ?: return
        val currentUserName = _userProfile.value?.name ?: return

        val messageData = hashMapOf(
            "text" to text,
            "userName" to currentUserName,
            "userID" to userID,
            "timestamp" to Timestamp(Date())
        )

        db.collection("chatMessages").add(messageData)
            .addOnFailureListener { e -> println("Erro ao enviar mensagem: ${e.localizedMessage}") }
    }

    // Criação manual do perfil (Substituindo createUserProfile)
    fun createUserProfile(userID: String, name: String, role: UserRole) {
        val profileData = hashMapOf(
            "name" to name,
            "role" to role.roleName,
            "profileImageURL" to null // O Firebase trata nulls corretamente
        )

        db.collection("users").document(userID).set(profileData)
            .addOnSuccessListener { println("Perfil inicial criado para o usuário $userID") }
            .addOnFailureListener { e -> println("Erro ao criar perfil inicial: $e") }
    }

    // Atualiza nome (Substituindo updateUserName)
    fun updateUserName(newName: String) {
        val userID = auth.currentUser?.uid ?: return
        if (_userProfile.value == null) return

        // 1. Atualizar no Firestore
        db.collection("users").document(userID).update("name", newName)
            .addOnFailureListener { e -> println("Erro ao atualizar nome no Firestore: $e") }

        // 2. Atualizar no Firebase Auth
        val user = auth.currentUser
        if (user != null) {
            val profileUpdates = com.google.firebase.auth.UserProfileChangeRequest.Builder()
                .setDisplayName(newName)
                .build()
            user.updateProfile(profileUpdates)
                .addOnFailureListener { e -> println("Erro ao atualizar DisplayName no Auth: $e") }
        }
    }

    // Atualiza imagem do perfil (Substituindo updateProfileImage(imageData: Data))
    // Nota: Requer que a UI envie o 'ByteArray' (o Data no Swift)
    fun updateProfileImage(imageData: ByteArray) {
        val userID = auth.currentUser?.uid ?: return

        val storageRef = storage.reference.child("profileImages/${userID}.jpg")

        storageRef.putBytes(imageData)
            .addOnSuccessListener {
                storageRef.downloadUrl.addOnSuccessListener { uri ->
                    val downloadURL = uri.toString()
                    // 1. Atualizar a URL no Firestore
                    db.collection("users").document(userID).update("profileImageURL", downloadURL)
                        .addOnFailureListener { e -> println("Erro ao salvar URL no Firestore: $e") }
                }
            }
            .addOnFailureListener { e -> println("Erro ao fazer upload da imagem: ${e.localizedMessage}") }
    }

    // Alternar status de conclusão
    fun toggleCompletion(item: ConteudoEducacional) {
        val currentSet = _conteudosCompletos.value.toMutableSet()
        if (currentSet.contains(item.id)) {
            currentSet.remove(item.id)
        } else {
            currentSet.add(item.id)
        }
        _conteudosCompletos.value = currentSet
        // NOTA: Para persistir isso entre sessões, você precisará salvar o 'Set<String>' no SharedPreferences (equivalente ao UserDefaults) ou no próprio Firestore.
    }

    // =========================================================================
    // 5. Dados Estáticos e Cores (Mapeamento do Conteúdo Inicial)
    // =========================================================================

    private fun carregarConteudosIniciais(): List<ConteudoEducacional> {
        // Cores em Android Studio: 0xFF seguido pelo código RGB em Hex (o seu Color.corFolhaClara é 4ca640)
        val corFolhaClaraHex = 0xFF4CA640
        val corDestaqueHex = 0xFFF2B24C
        val corTerraHex = 0xFF33260D
        val verdeClaroCardHex = 0xFFD7F2CC
        val azulClaroCardHex = 0xFFCCE5FB
        val amareloClaroCardHex = 0xFFF7F2CC

        return listOf(
            // Missões e Valores (Cor .pink)
            ConteudoEducacional(
                titulo = "Missões e Valores", subtitulo = "Módulo Obrigatório",
                descricaoCurta = "Conheça os pilares da plataforma Leafy.", icone = "heart_fill",
                corHex = 0xFFEE82EE, // Violeta/Rosa - apenas um exemplo
                categoria = "Institucional", nivel = "Todos",
                isMandatoryFor = listOf(UserRole.ESTUDANTE, UserRole.EDUCADOR)
            ),
            // Compreender o Mercado Sustentável (Cor .indigo)
            ConteudoEducacional(
                titulo = "Compreender o Mercado Sustentável", subtitulo = "Módulo Obrigatório",
                descricaoCurta = "Sustentabilidade e o futuro profissional.", icone = "briefcase_fill",
                corHex = 0xFF4B0082, // Indigo
                categoria = "Carreira", nivel = "Iniciante",
                isMandatoryFor = listOf(UserRole.ESTUDANTE)
            ),
            // ... (Continue mapeando o restante dos 12 itens do seu array)
            // Exemplo de Hortas Urbanas (usando sua cor principal)
            ConteudoEducacional(
                titulo = "Hortas Urbanas e Permacultura", subtitulo = "Curso Prático",
                descricaoCurta = "Guia completo de plantio em pequenos espaços.", icone = "leaf_fill",
                corHex = corFolhaClaraHex, categoria = "Curso", nivel = "Iniciante"
            ),
            // ... adicione todos os outros 9 itens ...
            // Guia de Compostagem Caseira (usando corTerra)
            ConteudoEducacional(
                titulo = "Guia de Compostagem Caseira", subtitulo = "E-book Gratuito",
                descricaoCurta = "Transforme resíduos orgânicos em adubo de alta qualidade.", icone = "book_closed_fill",
                corHex = corTerraHex, categoria = "Ebook", nivel = "Iniciante", link = "https://www.infoteca.cnptia.embrapa.br/infoteca/bitstream/doc/1019253/1/cartilhacompostagem.pdf"
            ),
            // ...
        )
    }

    // Não precisamos de deinit, pois o ViewModel tem seu próprio ciclo de vida
    override fun onCleared() {
        super.onCleared()
        stopListening()
        println("ViewModel limpo e listeners removidos.")
    }
}