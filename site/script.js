// Espera o conteúdo da página carregar
document.addEventListener('DOMContentLoaded', () => {

    // Efeito de "Scroll" no Menu (Navbar)
    const navbar = document.getElementById('navbar');

    if (navbar) {
        window.addEventListener('scroll', () => {
            if (window.scrollY > 50) {
                // Adiciona a classe 'scrolled' quando o usuário rola a página
                navbar.classList.add('scrolled');
            } else {
                // Remove a classe 'scrolled' quando o usuário está no topo
                navbar.classList.remove('scrolled');
            }
        });
    }

    // Rolagem Suave para links internos (âncoras)
    const linksInternos = document.querySelectorAll('a[href^="#"]');

    linksInternos.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault(); // Impede o salto padrão

            const targetId = this.getAttribute('href');
            
            // Tratamento especial para o link do logo
            if (targetId === '#') {
                window.scrollTo({
                    top: 0,
                    behavior: 'smooth'
                });
                return;
            }

            const targetElement = document.querySelector(targetId);

            if (targetElement) {
                targetElement.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });


    // ===============================================
    // --- NOVA LÓGICA: Controle do Modal de Apresentações ---
    // ===============================================
    const openBtn = document.getElementById('open-modal-btn');
    const closeBtn = document.getElementById('close-modal-btn');
    const modal = document.getElementById('apresentacao-modal');

    if (openBtn && closeBtn && modal) {
        
        // Abrir o modal
        openBtn.addEventListener('click', () => {
            modal.classList.add('show');
        });

        // Fechar o modal (pelo botão 'x')
        closeBtn.addEventListener('click', () => {
            modal.classList.remove('show');
        });

        // Fechar clicando fora (no overlay cinza)
        modal.addEventListener('click', (e) => {
            // Verifica se o clique foi exatamente no overlay (fundo)
            if (e.target === modal) { 
                modal.classList.remove('show');
            }
        });
    }

});