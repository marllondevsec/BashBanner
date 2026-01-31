# BashBanner

<p align="center">
  <img src="assets/banner1.png" alt="Banner 1" width="300" />
  <img src="assets/banner2.png" alt="Banner 2" width="300" />
</p>
<p align="center">
  <img src="assets/banner3.png" alt="Banner 3" width="300" />
  <img src="assets/banner4.png" alt="Banner 4" width="300" />
</p>

**BashBanner** é um sistema completo de gerenciamento dinâmico de banners para terminais Linux com interface interativa colorida. Ele oferece instalação reversível, múltiplos métodos de ativação e gerenciamento integrado de banners através de um menu amigável.

Um programa para quem busca personalizar a experiência no terminal com banners ASCII dinâmicos, permitindo exibi-los na inicialização e ao navegar entre diretórios principais.

---

## ✨ Características Principais

* 🎨 **Menu interativo colorido**: Interface amigável com cores e formatação visual.
* 🔄 **Instalação 100% reversível**: Sistema de backup e manifest para desinstalação completa.
* ⚙️ **Múltiplos métodos de ativação**:

  * Hook no shell (exibe banners ao mudar de diretório)
  * Systemd user unit (exibe banner no login)
  * Modificação automática de `.bashrc` / `.zshrc`
* 🗂️ **Gerenciamento integrado de banners**: Adicione, visualize, remova e teste banners diretamente pelo menu.
* 🔀 **Compatibilidade dual**: Funciona tanto em Bash quanto Zsh sem configuração manual.
* 🔐 **Segurança**: Não requer permissões root, todas as modificações são locais ao usuário.

---

## 🧠 Como Funciona

BashBanner é um sistema modular que pode ser configurado de três formas combináveis:

* **Binário principal**: Script Python instalado em `~/.local/bin/bashbanner`
* **Hook no shell**: Script injetado nos arquivos RC que monitora mudanças de diretório
* **Systemd user unit**: Serviço que executa o banner de inicialização no login

### 🔁 Fluxo de Funcionamento

```
Terminal aberto → Hook carregado → Banner startup exibido (uma vez por sessão)
      ↓
Usuário navega → Hook detecta diretório → Busca banner correspondente
      ↓
Diretório XDG → Mapeamento para pasta → Exibe banner aleatório (*.txt)
```

---

## 📁 Estrutura do Sistema

Após instalação, o seguinte diretório é criado:

```
~/.config/bashbanner/
├── backups/               # Backups dos arquivos modificados
├── manifest.txt          # Registro de todas as alterações
├── hook.sh               # Script de integração com shell
├── bannerstartup/        # Banners exibidos na inicialização
├── bannerdesktop/        # Banners para ~/Desktop
├── bannerdownloads/      # Banners para ~/Downloads
├── bannerdocuments/      # Banners para ~/Documents
├── bannerpictures/       # Banners para ~/Pictures
├── bannermusic/          # Banners para ~/Music
├── bannervideos/         # Banners para ~/Videos
├── bannerpublico/        # Banners para ~/Public
└── bannertemplates/      # Banners para ~/Templates
```

---

## 🚀 Instalação

### Método Interativo (Recomendado)

```bash
git clone https://github.com/marllondevsec/BashBanner
cd BashBanner
./BashBanner1.3.sh
```

O menu interativo guiará você através de:

* Configuração das opções (systemd, hook, RC files)
* Instalação do sistema
* Gerenciamento inicial de banners

---

### Método por Linha de Comando

```bash
# Instalação completa
./BashBanner1.3.sh --install --with-systemd --with-hook

# Instalação mínima (apenas binário)
./BashBanner1.3.sh --install

# Instalação sem modificar RC files
./BashBanner1.3.sh --install --with-hook --no-rc
```

---

## 🧭 Uso

### Menu Principal

Execute:

```bash
./BashBanner1.3.sh
```

Opções disponíveis:

* Instalar BashBanner
* Configurar opções
* Gerenciar banners
* Desinstalar
* Mostrar informações
* Sair

---

### Gerenciamento de Banners

No menu **Gerenciar banners** você pode:

* ➕ **Adicionar**: Cria novos banners com editor integrado
* 👁️ **Visualizar**: Navega e pré-visualiza banners existentes
* 🗑️ **Remover**: Exclui banners individuais ou limpa pastas inteiras
* 🧪 **Testar**: Testa a exibição de banners em tempo real
* 📊 **Listar pastas**: Mostra todas as pastas com contagem de banners

---

### Comandos no Shell

Após instalação, novos comandos ficam disponíveis:

```bash
bashbanner-test     # Testa todos os banners configurados
bashbanner-list     # Lista pastas e quantidades de banners
```

---

## ⚙️ Configuração

### Opções Disponíveis

* **Systemd User Unit** (Padrão: desativado)

  * Executa `bashbanner --startup` no login via systemd
  * Requer systemd e sessão de usuário ativa

* **Hook Shell** (Padrão: ativado)

  * Adiciona monitoramento de mudança de diretórios
  * Funciona tanto para Bash (`PROMPT_COMMAND`) quanto Zsh (`chpwd`)

* **Modificar RC files** (Padrão: ativado)

  * Adiciona automaticamente `source ~/.config/bashbanner/hook.sh` aos arquivos RC
  * Quando desativado, requer ativação manual

---

### 🎨 Personalização

Banners são arquivos de texto simples (`.txt`) com arte ASCII. Coloque-os nas pastas correspondentes:

* `bannerstartup/`: Exibido uma vez por sessão ao abrir terminal
* `bannerdesktop/`: Exibido ao entrar em `~/Desktop`
* `bannerdownloads/`: Exibido ao entrar em `~/Downloads`
* etc.

---

## 🧹 Desinstalação

### Método Interativo

Selecione **Desinstalar** no menu principal.

### Método por Linha de Comando

```bash
./BashBanner1.3.sh --uninstall
```

O processo de desinstalação:

* Usa o manifest para reverter todas as alterações
* Restaura backups dos arquivos modificados
* Remove arquivos criados pelo instalador
* Limpa unidades systemd se aplicável

---

## 🛠️ Solução de Problemas

### ❌ Banner não aparece

```bash
grep bashbanner ~/.bashrc ~/.zshrc 2>/dev/null
~/.local/bin/bashbanner --startup
ls -la ~/.config/bashbanner/
```

---

### ⚠️ Erro no systemd

```bash
systemctl --user daemon-reload
systemctl --user status bashbanner.service
journalctl --user-unit bashbanner.service
```

---

### 🔄 Recarregar configurações

```bash
# Bash
source ~/.bashrc

# Zsh
source ~/.zshrc
```

---

## 🧩 Compatibilidade

* **Shells**: Bash 4.0+, Zsh 5.0+
* **Sistemas**: Linux com suporte a cores ANSI no terminal
* **Arquiteturas**: x86_64, arm64
* **Dependências**: Python 3, systemd (opcional), coreutils

---

## 🔐 Segurança

* ✅ Sem elevação de privilégios (não requer sudo)
* ✅ Modificações apenas no diretório do usuário
* ✅ Backup automático de arquivos modificados
* ✅ Código auditável (open source)
* ✅ Desinstalação completa e reversível

---

## 🧑‍💻 Desenvolvimento

### Estrutura do Código

```
BashBanner1.3.sh
├── Interface interativa (linhas 1–736)
│   ├── Menu principal
│   ├── Gerenciador de banners
│   └── Configurador de opções
├── Instalador original (linhas 738–1201)
│   ├── Funções de instalação/desinstalação
│   ├── Gerenciamento de manifest
│   └── Criação de arquivos
└── Conteúdos embutidos
    ├── Script Python (bashbanner)
    ├── Hook shell
    └── Unidade systemd
```

### Para Desenvolvedores

O script mantém compatibilidade com:

* Modo interativo (sem argumentos)
* Modo CLI (argumentos tradicionais)
* Sistema de manifest para desinstalação reversível

---

## 📜 Licença

MIT License — veja o arquivo `LICENSE` para detalhes.

---

## 🤝 Contribuições

Contribuições são bem-vindas!

1. Faça fork do repositório
2. Crie uma branch para sua feature
3. Teste suas alterações
4. Envie um pull request
