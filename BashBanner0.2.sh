#!/usr/bin/env bash
set -euo pipefail

# install_bashbanner.sh - Menu interativo colorido
# Reversible installer for BashBanner (user-mode).

# Cores para o menu
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

# Cores para status
SUCCESS="${GREEN}✓${NC}"
INFO="${CYAN}ℹ${NC}"
WARNING="${YELLOW}⚠${NC}"
ERROR="${RED}✗${NC}"

# Configuração
PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
CONF_DIR="$HOME/.config/bashbanner"
BACKUP_DIR="$CONF_DIR/backups"
MANIFEST="$CONF_DIR/manifest.txt"
SYSTEMD_UNIT_DIR="$HOME/.config/systemd/user"
SYSTEMD_UNIT="$SYSTEMD_UNIT_DIR/bashbanner.service"
HOOK_SH="$CONF_DIR/hook.sh"
BASHBANNER_BIN="$BIN_DIR/bashbanner"

# Lista de pastas de banners
BANNER_DIRS=(
    "bannerstartup"      # Banners de inicialização
    "bannerdesktop"      # Banners para Desktop
    "bannerdownloads"    # Banners para Downloads
    "bannerdocuments"    # Banners para Documents
    "bannerpictures"     # Banners para Pictures
    "bannermusic"        # Banners para Music
    "bannervideos"       # Banners para Videos
    "bannerpublico"      # Banners para Public
    "bannertemplates"    # Banners para Templates
)

# Descrições das pastas
declare -A BANNER_DESCRIPTIONS=(
    ["bannerstartup"]="Exibido no login/inicialização"
    ["bannerdesktop"]="Ao entrar na pasta Desktop"
    ["bannerdownloads"]="Ao entrar na pasta Downloads"
    ["bannerdocuments"]="Ao entrar na pasta Documents"
    ["bannerpictures"]="Ao entrar na pasta Pictures"
    ["bannermusic"]="Ao entrar na pasta Music"
    ["bannervideos"]="Ao entrar na pasta Videos"
    ["bannerpublico"]="Ao entrar na pasta Public"
    ["bannertemplates"]="Ao entrar na pasta Templates"
)

# Mapeamento de diretórios para pastas de banners
declare -A DIR_BANNER_MAP=(
    ["$HOME/Desktop"]="bannerdesktop"
    ["$HOME/Desktop/"]="bannerdesktop"
    ["$HOME/Downloads"]="bannerdownloads"
    ["$HOME/Downloads/"]="bannerdownloads"
    ["$HOME/Documents"]="bannerdocuments"
    ["$HOME/Documents/"]="bannerdocuments"
    ["$HOME/Pictures"]="bannerpictures"
    ["$HOME/Pictures/"]="bannerpictures"
    ["$HOME/Music"]="bannermusic"
    ["$HOME/Music/"]="bannermusic"
    ["$HOME/Videos"]="bannervideos"
    ["$HOME/Videos/"]="bannervideos"
    ["$HOME/Public"]="bannerpublico"
    ["$HOME/Public/"]="bannerpublico"
    ["$HOME/Templates"]="bannertemplates"
    ["$HOME/Templates/"]="bannertemplates"
)

# Variáveis do menu
ENABLE_SYSTEMD=false
ENABLE_HOOK=false
MODIFY_RC=true
SELECTED_ACTION=""

# Banner do menu colorido alternativo
show_banner() {
  clear
  echo -e "${MAGENTA}${BOLD}"
  echo -e "╔══════════════════════════════════════════════════════════════════╗"
  echo -e "║${CYAN}                                                                    ${MAGENTA}║"
  echo -e "║${YELLOW} 8                    8      8                                      ${MAGENTA}║"
  echo -e "║${GREEN} 8                    8      8                                      ${MAGENTA}║"
  echo -e "║${BLUE} 8oPYo. .oPYo. .oPYo. 8oPYo. 8oPYo. .oPYo. odYo. odYo. .oPYo. oPYo. ${MAGENTA}║"
  echo -e "║${CYAN} 8    8 .oooo8 Yb..   8    8 8    8 .oooo8 8' \`8 8' \`8 8oooo8 8  \`' ${MAGENTA}║"
  echo -e "║${RED} 8    8 8    8   'Yb. 8    8 8    8 8    8 8   8 8   8 8.     8     ${MAGENTA}║"
  echo -e "║${GREEN} \`YooP' \`YooP8 \`YooP' 8    8 \`YooP' \`YooP8 8   8 8   8 \`Yooo' 8     ${MAGENTA}║"
  echo -e "║${YELLOW} :.....::.....::.....:..:::..:.....::.....:..::....::..:.....:..:::: ${MAGENTA}║"
  echo -e "║${BLUE} ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: ${MAGENTA}║"
  echo -e "║${CYAN} ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: ${MAGENTA}║"
  echo -e "║                                                                    ${MAGENTA}║"
  echo -e "║${WHITE}              INSTALADOR REVERSÍVEL - MENU INTERATIVO               ${MAGENTA}║"
  echo -e "╚══════════════════════════════════════════════════════════════════╝${NC}"
  echo
}

# Linha divisória
show_separator() {
  echo -e "${DIM}────────────────────────────────────────────────────────────${NC}"
}

# Mostra mensagem de status
show_status() {
  echo -e "\n${SUCCESS} $1"
}

show_error() {
  echo -e "\n${ERROR} $1"
}

show_info() {
  echo -e "\n${INFO} $1"
}

# Função para listar pastas de banners
list_banner_dirs() {
    echo -e "${BOLD}${WHITE}Pastas de banners disponíveis:${NC}\n"
    
    for i in "${!BANNER_DIRS[@]}"; do
        local dir="${BANNER_DIRS[$i]}"
        local full_path="$CONF_DIR/$dir"
        local banner_count=0
        
        if [ -d "$full_path" ]; then
            banner_count=$(find "$full_path" -name "*.txt" -type f 2>/dev/null | wc -l)
            local count_color="${GREEN}"
            if [ "$banner_count" -eq 0 ]; then
                count_color="${RED}"
            fi
            echo -e "  ${BOLD}$((i+1)))${NC} ${CYAN}$dir${NC}"
            echo -e "     ${DIM}${BANNER_DESCRIPTIONS[$dir]}${NC}"
            echo -e "     ${DIM}Banners: ${count_color}${banner_count} arquivo(s)${NC}"
        else
            echo -e "  ${BOLD}$((i+1)))${NC} ${DIM}$dir${NC} (${RED}não criada${NC})"
        fi
        echo
    done
}

# Função para selecionar pasta de banner
select_banner_dir() {
    local selected_index
    
    while true; do
        clear
        show_banner
        echo -e "\n${BOLD}${WHITE}Selecionar pasta de banner:${NC}\n"
        
        list_banner_dirs
        echo -e "  ${BOLD}0)${NC} ${BLUE}Voltar ao menu anterior${NC}"
        
        show_separator
        read -p "$(echo -e "${BOLD}${WHITE}Escolha uma pasta [0-${#BANNER_DIRS[@]}]: ${NC}")" selected_index
        
        if [[ "$selected_index" == "0" ]]; then
            return 1
        fi
        
        if [[ "$selected_index" =~ ^[0-9]+$ ]] && [ "$selected_index" -ge 1 ] && [ "$selected_index" -le "${#BANNER_DIRS[@]}" ]; then
            local dir_index=$((selected_index-1))
            SELECTED_BANNER_DIR="${BANNER_DIRS[$dir_index]}"
            SELECTED_BANNER_PATH="$CONF_DIR/$SELECTED_BANNER_DIR"
            
            # Criar diretório se não existir
            if [ ! -d "$SELECTED_BANNER_PATH" ]; then
                mkdir -p "$SELECTED_BANNER_PATH"
                echo -e "\n${SUCCESS} Pasta ${CYAN}$SELECTED_BANNER_DIR${NC} criada."
                sleep 1
            fi
            
            return 0
        else
            echo -e "\n${ERROR} Opção inválida! Tente novamente."
            sleep 1
        fi
    done
}

# Função para adicionar banner
add_banner() {
    if ! select_banner_dir; then
        return
    fi
    
    clear
    show_banner
    echo -e "\n${BOLD}${WHITE}Adicionar banner à pasta: ${CYAN}$SELECTED_BANNER_DIR${NC}\n"
    
    echo -e "${DIM}Digite o nome do arquivo (sem extensão .txt):${NC}"
    read -p "Nome: " banner_name
    
    # Remover espaços e caracteres especiais
    banner_name=$(echo "$banner_name" | tr -s ' ' | tr ' ' '_' | tr -cd '[:alnum:]._-')
    
    if [ -z "$banner_name" ]; then
        banner_name="banner_$(date +%s)"
    fi
    
    local banner_file="$SELECTED_BANNER_PATH/${banner_name}.txt"
    
    if [ -f "$banner_file" ]; then
        echo -e "\n${WARNING} O arquivo ${banner_name}.txt já existe."
        read -p "Deseja sobrescrever? (s/N): " overwrite
        if [[ ! "$overwrite" =~ ^[SsYy]$ ]]; then
            return
        fi
    fi
    
    echo -e "\n${DIM}Digite o conteúdo do banner (pressione Ctrl+D quando terminar):${NC}"
    echo -e "${GREEN}(Você pode usar caracteres ASCII, caixas, etc.)${NC}\n"
    echo -e "${YELLOW}--- Comece a digitar abaixo ---${NC}"
    
    # Usar cat para permitir múltiplas linhas
    cat > "$banner_file"
    
    if [ -s "$banner_file" ]; then
        echo -e "\n${SUCCESS} Banner salvo em: ${CYAN}$banner_file${NC}"
        
        # Mostrar preview
        echo -e "\n${DIM}Preview:${NC}"
        echo -e "${BLUE}════════════════════════════════${NC}"
        cat "$banner_file"
        echo -e "${BLUE}════════════════════════════════${NC}"
    else
        rm -f "$banner_file"
        echo -e "\n${ERROR} Banner vazio. Nada foi salvo."
    fi
    
    pause_screen
}

# Função para ver banners
view_banners() {
    if ! select_banner_dir; then
        return
    fi
    
    clear
    show_banner
    echo -e "\n${BOLD}${WHITE}Banners na pasta: ${CYAN}$SELECTED_BANNER_DIR${NC}\n"
    
    local banners=()
    if [ -d "$SELECTED_BANNER_PATH" ]; then
        mapfile -t banners < <(find "$SELECTED_BANNER_PATH" -name "*.txt" -type f 2>/dev/null | sort)
    fi
    
    if [ ${#banners[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nenhum banner encontrado nesta pasta.${NC}"
        pause_screen
        return
    fi
    
    while true; do
        clear
        show_banner
        echo -e "\n${BOLD}${WHITE}Selecionar banner para visualizar:${NC}\n"
        
        for i in "${!banners[@]}"; do
            local banner="${banners[$i]}"
            local banner_name=$(basename "$banner")
            local line_count=$(wc -l < "$banner" 2>/dev/null || echo 0)
            local size=$(stat -c%s "$banner" 2>/dev/null || echo 0)
            
            echo -e "  ${BOLD}$((i+1)))${NC} ${CYAN}$banner_name${NC}"
            echo -e "     ${DIM}Linhas: $line_count | Tamanho: ${size}B${NC}"
        done
        
        echo -e "\n  ${BOLD}0)${NC} ${BLUE}Voltar ao menu anterior${NC}"
        
        show_separator
        read -p "$(echo -e "${BOLD}${WHITE}Escolha um banner [0-${#banners[@]}]: ${NC}")" choice
        
        if [[ "$choice" == "0" ]]; then
            return
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#banners[@]}" ]; then
            local banner_index=$((choice-1))
            local selected_banner="${banners[$banner_index]}"
            
            clear
            show_banner
            echo -e "\n${BOLD}${WHITE}Banner: ${CYAN}$(basename "$selected_banner")${NC}\n"
            echo -e "${DIM}Caminho: $selected_banner${NC}"
            echo -e "${DIM}Pasta: $SELECTED_BANNER_DIR${NC}"
            echo -e "\n${GREEN}Conteúdo:${NC}"
            echo -e "${BLUE}════════════════════════════════════════${NC}"
            cat "$selected_banner"
            echo -e "${BLUE}════════════════════════════════════════${NC}"
            
            echo -e "\n${DIM}Pressione Enter para continuar...${NC}"
            read -r
        else
            echo -e "\n${ERROR} Opção inválida!"
            sleep 1
        fi
    done
}

# Função para remover banner
remove_banner() {
    if ! select_banner_dir; then
        return
    fi
    
    clear
    show_banner
    echo -e "\n${BOLD}${WHITE}Remover banner da pasta: ${CYAN}$SELECTED_BANNER_DIR${NC}\n"
    
    local banners=()
    if [ -d "$SELECTED_BANNER_PATH" ]; then
        mapfile -t banners < <(find "$SELECTED_BANNER_PATH" -name "*.txt" -type f 2>/dev/null | sort)
    fi
    
    if [ ${#banners[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nenhum banner encontrado nesta pasta.${NC}"
        pause_screen
        return
    fi
    
    while true; do
        clear
        show_banner
        echo -e "\n${BOLD}${WHITE}Selecionar banner para remover:${NC}\n"
        
        for i in "${!banners[@]}"; do
            local banner="${banners[$i]}"
            local banner_name=$(basename "$banner")
            echo -e "  ${BOLD}$((i+1)))${NC} ${CYAN}$banner_name${NC}"
        done
        
        echo -e "\n  ${BOLD}A)${NC} ${RED}Remover TODOS os banners desta pasta${NC}"
        echo -e "  ${BOLD}0)${NC} ${BLUE}Voltar ao menu anterior${NC}"
        
        show_separator
        read -p "$(echo -e "${BOLD}${WHITE}Escolha uma opção [0-${#banners[@]}, A]: ${NC}")" choice
        
        if [[ "$choice" == "0" ]]; then
            return
        fi
        
        if [[ "$choice" == "A" || "$choice" == "a" ]]; then
            echo -e "\n${RED}⚠ ATENÇÃO! ⚠${NC}"
            echo -e "Você está prestes a remover TODOS os ${#banners[@]} banners da pasta ${CYAN}$SELECTED_BANNER_DIR${NC}."
            read -p "$(echo -e "${BOLD}Tem certeza? (s/N): ${NC}")" confirm
            if [[ "$confirm" =~ ^[SsYy]$ ]]; then
                rm -f "${SELECTED_BANNER_PATH}"/*.txt 2>/dev/null
                echo -e "\n${SUCCESS} Todos os banners foram removidos."
                pause_screen
                return
            fi
            continue
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#banners[@]}" ]; then
            local banner_index=$((choice-1))
            local selected_banner="${banners[$banner_index]}"
            
            echo -e "\n${YELLOW}Preview do banner a ser removido:${NC}"
            echo -e "${DIM}────────────────────────────────${NC}"
            head -10 "$selected_banner"
            echo -e "${DIM}────────────────────────────────${NC}"
            
            read -p "$(echo -e "${BOLD}Remover este banner? (s/N): ${NC}")" confirm
            if [[ "$confirm" =~ ^[SsYy]$ ]]; then
                rm -f "$selected_banner"
                echo -e "\n${SUCCESS} Banner removido com sucesso."
                
                # Atualizar lista
                mapfile -t banners < <(find "$SELECTED_BANNER_PATH" -name "*.txt" -type f 2>/dev/null | sort)
                if [ ${#banners[@]} -eq 0 ]; then
                    echo -e "${YELLOW}A pasta agora está vazia.${NC}"
                    pause_screen
                    return
                fi
            fi
            pause_screen
        else
            echo -e "\n${ERROR} Opção inválida!"
            sleep 1
        fi
    done
}

# Função para testar banner
test_banner() {
    if ! select_banner_dir; then
        return
    fi
    
    clear
    show_banner
    echo -e "\n${BOLD}${WHITE}Testar banner da pasta: ${CYAN}$SELECTED_BANNER_DIR${NC}\n"
    
    if [ -d "$SELECTED_BANNER_PATH" ] && [ -x "$BASHBANNER_BIN" ]; then
        echo -e "${DIM}Executando teste...${NC}\n"
        
        if [ "$SELECTED_BANNER_DIR" == "bannerstartup" ]; then
            "$BASHBANNER_BIN" --startup
        else
            # Determinar diretório para teste baseado no nome da pasta
            local test_dir=""
            case "$SELECTED_BANNER_DIR" in
                bannerdesktop) test_dir="$HOME/Desktop" ;;
                bannerdownloads) test_dir="$HOME/Downloads" ;;
                bannerdocuments) test_dir="$HOME/Documents" ;;
                bannerpictures) test_dir="$HOME/Pictures" ;;
                bannermusic) test_dir="$HOME/Music" ;;
                bannervideos) test_dir="$HOME/Videos" ;;
                bannerpublico) test_dir="$HOME/Public" ;;
                bannertemplates) test_dir="$HOME/Templates" ;;
                *) test_dir="$HOME" ;;
            esac
            
            if [ -d "$test_dir" ]; then
                echo -e "${DIM}Testando para diretório: $test_dir${NC}\n"
                "$BASHBANNER_BIN" --dir "$test_dir"
            else
                echo -e "${YELLOW}Diretório $test_dir não existe.${NC}"
                echo -e "${DIM}Testando com diretório atual...${NC}\n"
                "$BASHBANNER_BIN" --dir "$PWD"
            fi
        fi
        
        echo -e "\n${GREEN}✓ Teste concluído.${NC}"
    else
        echo -e "${ERROR} Não foi possível executar o teste."
        echo -e "${DIM}Verifique se o BashBanner está instalado corretamente.${NC}"
    fi
    
    pause_screen
}

# Menu de gerenciamento de banners
manage_banners() {
    while true; do
        clear
        show_banner
        echo -e "\n${BOLD}${WHITE}Gerenciamento de Banners${NC}\n"
        
        # Contar banners totais
        local total_banners=0
        for dir in "${BANNER_DIRS[@]}"; do
            if [ -d "$CONF_DIR/$dir" ]; then
                local count=$(find "$CONF_DIR/$dir" -name "*.txt" -type f 2>/dev/null | wc -l)
                total_banners=$((total_banners + count))
            fi
        done
        
        echo -e "${DIM}Banners totais no sistema: ${CYAN}$total_banners${NC}\n"
        
        echo -e "   ${BOLD}1)${NC} ${GREEN}Adicionar novo banner${NC}"
        echo -e "   ${BOLD}2)${NC} ${CYAN}Visualizar banners existentes${NC}"
        echo -e "   ${BOLD}3)${NC} ${RED}Remover banner${NC}"
        echo -e "   ${BOLD}4)${NC} ${YELLOW}Testar banner${NC}"
        echo -e "   ${BOLD}5)${NC} ${MAGENTA}Listar todas as pastas${NC}"
        echo -e "\n   ${BOLD}0)${NC} ${BLUE}Voltar ao menu principal${NC}"
        
        show_separator
        read -p "$(echo -e "${BOLD}${WHITE}Escolha uma opção [0-5]: ${NC}")" choice
        
        case $choice in
            1) add_banner ;;
            2) view_banners ;;
            3) remove_banner ;;
            4) test_banner ;;
            5)
                clear
                show_banner
                echo -e "\n${BOLD}${WHITE}Pastas de banners:${NC}\n"
                list_banner_dirs
                pause_screen
                ;;
            0) return 0 ;;
            *)
                echo -e "\n${ERROR} Opção inválida!"
                sleep 1
                ;;
        esac
    done
}

# Menu principal interativo
show_menu() {
  while true; do
    show_banner
    
    echo -e "\n${BOLD}${WHITE}Selecione uma ação:${NC}\n"
    
    # Mostra status atual das opções
    local systemd_status
    local hook_status
    local rc_status
    
    if [ "$ENABLE_SYSTEMD" = true ]; then
      systemd_status="${GREEN}● ATIVADO${NC}"
    else
      systemd_status="${DIM}○ DESATIVADO${NC}"
    fi
    
    if [ "$ENABLE_HOOK" = true ]; then
      hook_status="${GREEN}● ATIVADO${NC}"
    else
      hook_status="${DIM}○ DESATIVADO${NC}"
    fi
    
    if [ "$MODIFY_RC" = true ]; then
      rc_status="${GREEN}● ATIVADO${NC}"
    else
      rc_status="${DIM}○ DESATIVADO${NC}"
    fi
    
    echo -e "   ${BOLD}1)${NC} ${CYAN}Instalar BashBanner${NC}"
    echo -e "      ${DIM}Opções:${NC}"
    echo -e "        a) Systemd User Unit: ${systemd_status}"
    echo -e "        b) Hook Shell: ${hook_status}"
    echo -e "        c) Modificar RC files: ${rc_status}"
    
    echo -e "\n   ${BOLD}2)${NC} ${YELLOW}Configurar opções${NC}"
    echo -e "\n   ${BOLD}3)${NC} ${MAGENTA}Gerenciar banners${NC}"
    echo -e "      ${DIM}Adicionar/visualizar/remover banners${NC}"
    
    echo -e "\n   ${BOLD}4)${NC} ${RED}Desinstalar${NC}"
    echo -e "\n   ${BOLD}5)${NC} ${GREEN}Mostrar informações${NC}"
    echo -e "\n   ${BOLD}6)${NC} ${BLUE}Sair${NC}"
    
    show_separator
    
    read -p "$(echo -e "${BOLD}${WHITE}Escolha [1-6]: ${NC}")" choice
    
    case $choice in
      1)
        SELECTED_ACTION="install"
        if confirm_action "Instalar BashBanner com as opções atuais?"; then
          execute_installation
          pause_screen
        fi
        ;;
      2)
        configure_options
        ;;
      3)
        manage_banners
        ;;
      4)
        SELECTED_ACTION="uninstall"
        if confirm_action "Tem certeza que deseja desinstalar o BashBanner?"; then
          execute_uninstallation
          pause_screen
        fi
        ;;
      5)
        show_information
        pause_screen
        ;;
      6)
        echo -e "\n${SUCCESS} Saindo... Até logo!${NC}"
        exit 0
        ;;
      *)
        echo -e "\n${ERROR} Opção inválida! Tente novamente.${NC}"
        sleep 1
        ;;
    esac
  done
}

# Confirmar ação
confirm_action() {
  local message="$1"
  echo -e "\n${YELLOW}${message}${NC}"
  read -p "$(echo -e "${BOLD}(s/N): ${NC}")" confirm
  [[ "$confirm" =~ ^[SsYy]$ ]]
}

# Pausar tela
pause_screen() {
  echo -e "\n${DIM}Pressione Enter para continuar...${NC}"
  read -r
}

# Configurar opções (mantida igual)
configure_options() {
  while true; do
    show_banner
    echo -e "\n${BOLD}${WHITE}Configurar Opções:${NC}\n"
    
    # Systemd
    if [ "$ENABLE_SYSTEMD" = true ]; then
      echo -e "   ${BOLD}1)${NC} Systemd User Unit: ${GREEN}[X] ATIVADO${NC}"
    else
      echo -e "   ${BOLD}1)${NC} Systemd User Unit: [ ] DESATIVADO"
    fi
    echo -e "   ${DIM}   Executa banner no login via systemd${NC}"
    
    # Hook
    if [ "$ENABLE_HOOK" = true ]; then
      echo -e "\n   ${BOLD}2)${NC} Hook Shell: ${GREEN}[X] ATIVADO${NC}"
    else
      echo -e "\n   ${BOLD}2)${NC} Hook Shell: [ ] DESATIVADO"
    fi
    echo -e "   ${DIM}   Mostra banner ao mudar de diretório${NC}"
    
    # Modificar RC (só aparece se hook ativado)
    if [ "$ENABLE_HOOK" = true ]; then
      if [ "$MODIFY_RC" = true ]; then
        echo -e "\n   ${BOLD}3)${NC} Modificar RC files: ${GREEN}[X] ATIVADO${NC}"
      else
        echo -e "\n   ${BOLD}3)${NC} Modificar RC files: [ ] DESATIVADO"
      fi
      echo -e "   ${DIM}   Adiciona source ao .bashrc/.zshrc${NC}"
    fi
    
    echo -e "\n   ${BOLD}4)${NC} ${GREEN}Voltar ao menu principal${NC}"
    
    show_separator
    
    read -p "$(echo -e "${BOLD}${WHITE}Escolha [1-4]: ${NC}")" opt_choice
    
    case $opt_choice in
      1)
        if [ "$ENABLE_SYSTEMD" = true ]; then
          ENABLE_SYSTEMD=false
          show_status "Systemd User Unit desativado"
        else
          ENABLE_SYSTEMD=true
          show_status "Systemd User Unit ativado"
        fi
        sleep 1
        ;;
      2)
        if [ "$ENABLE_HOOK" = true ]; then
          ENABLE_HOOK=false
          MODIFY_RC=false
          show_status "Hook Shell desativado"
        else
          ENABLE_HOOK=true
          show_status "Hook Shell ativado"
        fi
        sleep 1
        ;;
      3)
        if [ "$ENABLE_HOOK" = true ]; then
          if [ "$MODIFY_RC" = true ]; then
            MODIFY_RC=false
            show_status "Modificar RC files desativado"
          else
            MODIFY_RC=true
            show_status "Modificar RC files ativado"
          fi
          sleep 1
        else
          echo -e "\n${ERROR} Ative o Hook Shell primeiro!${NC}"
          sleep 1
        fi
        ;;
      4)
        return 0
        ;;
      *)
        echo -e "\n${ERROR} Opção inválida!${NC}"
        sleep 1
        ;;
    esac
  done
}

# Mostrar informações
show_information() {
  show_banner
  echo -e "\n${BOLD}${WHITE}Informações do Sistema:${NC}\n"
  
  echo -e "${DIM}Paths configurados:${NC}"
  echo -e "  ${CYAN}Binário:${NC} $BASHBANNER_BIN"
  echo -e "  ${CYAN}Configuração:${NC} $CONF_DIR"
  echo -e "  ${CYAN}Backups:${NC} $BACKUP_DIR"
  echo -e "  ${CYAN}Manifest:${NC} $MANIFEST"
  
  echo -e "\n${DIM}Status das opções:${NC}"
  
  if [ "$ENABLE_SYSTEMD" = true ]; then
    echo -e "  ${CYAN}Systemd:${NC} ${GREEN}Ativado${NC}"
  else
    echo -e "  ${CYAN}Systemd:${NC} ${DIM}Desativado${NC}"
  fi
  
  if [ "$ENABLE_HOOK" = true ]; then
    echo -e "  ${CYAN}Hook:${NC} ${GREEN}Ativado${NC}"
  else
    echo -e "  ${CYAN}Hook:${NC} ${DIM}Desativado${NC}"
  fi
  
  if [ "$MODIFY_RC" = true ]; then
    echo -e "  ${CYAN}Modificar RC:${NC} ${GREEN}Ativado${NC}"
  else
    echo -e "  ${CYAN}Modificar RC:${NC} ${DIM}Desativado${NC}"
  fi
  
  echo -e "\n${DIM}Estatísticas de banners:${NC}"
  
  local total_banners=0
  for dir in "${BANNER_DIRS[@]}"; do
    if [ -d "$CONF_DIR/$dir" ]; then
      local count=$(find "$CONF_DIR/$dir" -name "*.txt" -type f 2>/dev/null | wc -l)
      if [ "$count" -gt 0 ]; then
        echo -e "  ${GREEN}✓ $dir:${NC} $count banner(s)"
        total_banners=$((total_banners + count))
      else
        echo -e "  ${DIM}○ $dir:${NC} 0 banners"
      fi
    else
      echo -e "  ${RED}✗ $dir:${NC} pasta não existe"
    fi
  done
  
  echo -e "\n  ${CYAN}Total:${NC} $total_banners banners"
  
  show_separator
  echo -e "\n${DIM}Pressione Enter para voltar...${NC}"
}

# Executar instalação (usa as funções originais)
execute_installation() {
  echo -e "\n${BLUE}${BOLD}Iniciando instalação...${NC}"
  
  # Chama a função do instalador original
  DO_INSTALL=true
  do_install
  
  show_separator
  echo -e "${GREEN}${BOLD}Instalação concluída com sucesso!${NC}"
}

# Executar desinstalação (usa as funções originais)
execute_uninstallation() {
  echo -e "\n${YELLOW}${BOLD}Iniciando desinstalação...${NC}"
  
  # Chama a função do desinstalador original
  DO_UNINSTALL=true
  do_uninstall
  
  show_separator
  echo -e "${GREEN}${BOLD}Desinstalação concluída com sucesso!${NC}"
}

# ============================================================================
# FUNÇÕES ORIGINAIS DO INSTALADOR (mantidas para compatibilidade)
# ============================================================================

show_help(){
  cat <<EOF
install_bashbanner.sh - reversible installer for BashBanner

Usage:
  $0 --install [--with-systemd] [--with-hook] [--no-rc]
  $0 --uninstall
  $0 --help

Options:
  --with-systemd    Enable a systemd --user unit that runs bashbanner --startup at login
  --with-hook       Install the minimal hook script and add a single source line to shells' rc files
  --no-rc           When used with --with-hook, do not modify ~/.bashrc or ~/.zshrc (manual activation)
  --uninstall       Revert everything recorded in the manifest (safe, reversible)

The installer creates backups and writes a manifest to: $MANIFEST
EOF
}

manifest_add(){
  mkdir -p "$(dirname "$MANIFEST")"
  echo "$1" >> "$MANIFEST"
}

backup_file(){
  local f="$1"
  if [ -f "$f" ]; then
    mkdir -p "$BACKUP_DIR"
    local ts
    ts=$(date +%s)
    local b="$BACKUP_DIR/$(basename "$f").bak.$ts"
    cp -- "$f" "$b"
    manifest_add "BACKUP:$f:$b"
    echo "Backup $f -> $b"
  fi
}

write_file(){
  local path="$1"; shift; local content="$*"
  local tmp
  tmp="$(mktemp)"
  printf "%s" "$content" > "$tmp"
  if [ -f "$path" ]; then
    if cmp -s "$tmp" "$path"; then
      rm -f "$tmp"
      return 0
    else
      backup_file "$path"
    fi
  fi
  mkdir -p "$(dirname "$path")"
  mv "$tmp" "$path"
  chmod 755 "$path" || true
  manifest_add "CREATED:$path"
  echo "Wrote $path"
}

remove_created(){
  local path="$1"
  if [ -e "$path" ]; then
    rm -rf -- "$path"
    echo "Removed $path"
  fi
}

add_source_to_rc(){
  local rc="$1"
  local line='source "$HOME/.config/bashbanner/hook.sh"'
  if [ ! -f "$rc" ]; then
    touch "$rc"
    manifest_add "CREATED:$rc"
  else
    backup_file "$rc"
  fi
  if ! grep -Fxq "source \"\$HOME/.config/bashbanner/hook.sh\"" "$rc"; then
    printf "\n# bashbanner hook\nsource \"\$HOME/.config/bashbanner/hook.sh\"\n" >> "$rc"
    manifest_add "APPENDED_RC:$rc"
    echo "Appended source to $rc"
  else
    echo "RC $rc already contains hook source"
  fi
}

remove_source_from_rc(){
  local rc="$1"
  if [ -f "$rc" ]; then
    sed -i '/# bashbanner hook/d' "$rc" || true
    sed -i '/source "$HOME\/\.config\/bashbanner\/hook.sh"/d' "$rc" || true
    echo "Cleaned hook lines from $rc"
  fi
}

# ATUALIZADO: Script Python corrigido
bashbanner_content(){
  cat <<'PY'
#!/usr/bin/env python3
"""
bashbanner - pequeno utilitário para exibir banners.
"""
import argparse, random, os, sys, pathlib, subprocess, time

HOME = pathlib.Path.home()
CONF_DIR = HOME / ".config" / "bashbanner"

# Cache para evitar exibição repetida na mesma sessão
visited_dirs = set()
startup_shown = False

# Mapeamento de diretórios específicos para pastas de banners
DIR_BANNER_MAP = {
    str(HOME / "Desktop"): "bannerdesktop",
    str(HOME / "Downloads"): "bannerdownloads",
    str(HOME / "Documents"): "bannerdocuments",
    str(HOME / "Pictures"): "bannerpictures",
    str(HOME / "Music"): "bannermusic",
    str(HOME / "Videos"): "bannervideos",
    str(HOME / "Public"): "bannerpublico",
    str(HOME / "Templates"): "bannertemplates",
}

def find_random_banner(dirpath):
    p = pathlib.Path(dirpath)
    if not p.exists() or not p.is_dir():
        return None
    candidates = [f for f in p.iterdir() if f.is_file() and f.suffix == ".txt"]
    if not candidates:
        return None
    return random.choice(candidates).read_text(errors="ignore")

def who_ttys_for_user():
    try:
        out = subprocess.check_output(["who"]).decode(errors="ignore").splitlines()
    except Exception:
        return []
    tt = []
    user = os.getenv("USER") or os.getlogin()
    for line in out:
        parts = line.split()
        if not parts: continue
        u = parts[0]; tty = parts[1]
        if u == user:
            path = "/dev/" + tty
            if os.path.exists(path):
                tt.append(path)
    return list(dict.fromkeys(tt))

def write_to_ttys(text):
    if not text:
        return
    ttys = who_ttys_for_user()
    if not ttys:
        sys.stdout.write(text)
        return
    for tty in ttys:
        try:
            with open(tty, "w") as f:
                f.write(text + "\n")
        except Exception:
            pass

def detect_banner_for_dir(dirpath):
    global visited_dirs
    
    # Evitar exibição repetida na mesma sessão
    dir_str = str(dirpath)
    if dir_str in visited_dirs:
        return None
    
    # Verificar mapeamento direto
    for mapped_dir, banner_folder in DIR_BANNER_MAP.items():
        if dir_str == mapped_dir or dir_str.startswith(mapped_dir + "/"):
            visited_dirs.add(dir_str)
            return find_random_banner(CONF_DIR / banner_folder)
    
    return None

def main():
    global startup_shown
    
    ap = argparse.ArgumentParser()
    ap.add_argument("--startup", action="store_true")
    ap.add_argument("--dir", metavar="DIR")
    ap.add_argument("--list-dirs", action="store_true")
    ap.add_argument("--reset-cache", action="store_true", help="Resetar cache de diretórios visitados")
    args = ap.parse_args()

    if args.reset_cache:
        visited_dirs.clear()
        startup_shown = False
        return

    if args.list_dirs:
        print("Config dir:", CONF_DIR)
        if CONF_DIR.exists():
            for p in sorted([p.name for p in CONF_DIR.iterdir() if p.is_dir()]):
                banner_count = len(list((CONF_DIR / p).glob("*.txt")))
                print(f"- {p}: {banner_count} banner(s)")
        return

    if args.startup:
        if not startup_shown:
            text = find_random_banner(CONF_DIR / "bannerstartup")
            if text:
                write_to_ttys(text)
                startup_shown = True
            else:
                text = find_random_banner(CONF_DIR / "bannerdesktop")
                write_to_ttys(text)
                startup_shown = True
        return

    if args.dir:
        dirpath = pathlib.Path(args.dir).resolve()
        text = detect_banner_for_dir(dirpath)
        if text:
            sys.stdout.write(text)
        return

if __name__ == "__main__":
    main()
PY
}

# ATUALIZADO: Hook corrigido
hook_content(){
  cat <<'SH'
# bashbanner hook (inteligente e não-repetitivo)
BASHBANNER_BIN="${BASHBANNER_BIN:-$HOME/.local/bin/bashbanner}"
CONF_DIR="$HOME/.config/bashbanner"

# Apenas para shells interativos
case "$-" in *i*) : ;; *) return ;; esac

# Variáveis de controle
BASHBANNER_VISITED_DIRS=""
BASHBANNER_STARTUP_SHOWN=0

# Função para exibir banner de startup (apenas uma vez)
__bashbanner_startup() {
    if [ "$BASHBANNER_STARTUP_SHOWN" -eq 0 ] && [ -x "$BASHBANNER_BIN" ]; then
        "$BASHBANNER_BIN" --startup 2>/dev/null && BASHBANNER_STARTUP_SHOWN=1
    fi
}

# Função para verificar se diretório já foi visitado
__bashbanner_is_visited() {
    local dir="$1"
    case ":${BASHBANNER_VISITED_DIRS}:" in
        *":${dir}:"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Função para marcar diretório como visitado
__bashbanner_mark_visited() {
    local dir="$1"
    if ! __bashbanner_is_visited "$dir"; then
        BASHBANNER_VISITED_DIRS="${BASHBANNER_VISITED_DIRS}:${dir}"
    fi
}

# Função principal do hook
__bashbanner_hook() {
    if [ -x "$BASHBANNER_BIN" ]; then
        local current_dir="$PWD"
        
        # Lista de diretórios que devem exibir banners
        local target_dirs="
            $HOME/Desktop
            $HOME/Downloads
            $HOME/Documents
            $HOME/Pictures
            $HOME/Music
            $HOME/Videos
            $HOME/Public
            $HOME/Templates
        "
        
        # Verificar se o diretório atual é um dos alvos
        for target_dir in $target_dirs; do
            if [ -n "$target_dir" ] && [ "$current_dir" = "$target_dir" ]; then
                if ! __bashbanner_is_visited "$current_dir"; then
                    "$BASHBANNER_BIN" --dir "$current_dir" 2>/dev/null && __bashbanner_mark_visited "$current_dir"
                fi
                return
            fi
        done
    fi
}

# Executar startup apenas uma vez quando o shell carregar
__bashbanner_startup

# Configurar hooks para shell
if [ -n "${BASH_VERSION:-}" ]; then
    # Bash: usar PROMPT_COMMAND
    case ":${PROMPT_COMMAND:-}:" in
        *":__bashbanner_hook:"*) : ;;
        *) 
            if [ -z "$PROMPT_COMMAND" ]; then
                PROMPT_COMMAND="__bashbanner_hook"
            else
                PROMPT_COMMAND="__bashbanner_hook;$PROMPT_COMMAND"
            fi
            ;;
    esac
elif [ -n "${ZSH_VERSION:-}" ]; then
    # Zsh: usar chpwd hook
    autoload -U add-zsh-hook 2>/dev/null || true
    add-zsh-hook chpwd __bashbanner_hook 2>/dev/null || true
fi

# Comando para resetar cache (útil para desenvolvimento)
bashbanner-reset-cache() {
    if [ -x "$BASHBANNER_BIN" ]; then
        "$BASHBANNER_BIN" --reset-cache
        BASHBANNER_VISITED_DIRS=""
        BASHBANNER_STARTUP_SHOWN=0
        echo "Cache do BashBanner resetado"
    fi
}
SH
}

systemd_unit_content(){
  cat <<'INI'
[Unit]
Description=BashBanner: show startup banner for user session

[Service]
Type=oneshot
ExecStart=%h/.local/bin/bashbanner --startup
Environment=DISPLAY=:0

[Install]
WantedBy=default.target
INI
}

do_install(){
  echo "Starting install..."
  mkdir -p "$BIN_DIR" "$CONF_DIR" "$BACKUP_DIR"
  manifest_add "INSTALL_START:$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  write_file "$BASHBANNER_BIN" "$(bashbanner_content)"

  for sub in bannerstartup bannerdesktop bannerdownloads bannerdocuments bannerpictures bannermusic bannervideos bannerpublico bannertemplates; do
    d="$CONF_DIR/$sub"
    if [ ! -d "$d" ]; then
      mkdir -p "$d"
      manifest_add "CREATED:$d"
      if [ -z "$(ls -A "$d" 2>/dev/null || true)" ]; then
        printf "=== %s ===\n\nEste é um banner de exemplo para %s.\nVocê pode editar ou substituir este arquivo.\n" "$sub" "$sub" > "$d/example.txt"
        manifest_add "CREATED:$d/example.txt"
      fi
    fi
  done

  if [ "$ENABLE_HOOK" = true ]; then
    write_file "$HOOK_SH" "$(hook_content)"
    if [ "$MODIFY_RC" = true ]; then
      add_source_to_rc "$HOME/.bashrc"
      add_source_to_rc "$HOME/.zshrc"
      echo "Hook instalado e ativado nos arquivos de configuração do shell."
      echo "Recarregue o shell com 'source ~/.bashrc' ou abra um novo terminal."
    else
      echo "Hook instalado em $HOOK_SH mas não ativado nos rc files (--no-rc)."
      echo "Ative manualmente adicionando: source \"$HOOK_SH\" ao seu .bashrc/.zshrc"
    fi
  fi

  if [ "$ENABLE_SYSTEMD" = true ]; then
    mkdir -p "$SYSTEMD_UNIT_DIR"
    write_file "$SYSTEMD_UNIT" "$(systemd_unit_content)"
    if command -v systemctl >/dev/null 2>&1; then
      systemctl --user daemon-reload || true
      systemctl --user enable --now bashbanner.service 2>/dev/null || true
      manifest_add "ENABLED_SYSTEMD:bashbanner.service"
      echo "Systemd user unit ativada. O banner de startup será exibido no login."
    else
      echo "systemctl não encontrado: não foi possível ativar a unit systemd" >&2
    fi
  fi

  manifest_add "INSTALL_END:$(date -u +%Y-%m-dT%H:%M:%SZ)"
  echo "Install complete. Manifest: $MANIFEST"
  echo "Para testar:"
  echo "  - Banner de startup: $BASHBANNER_BIN --startup"
  echo "  - Listar pastas: $BASHBANNER_BIN --list-dirs"
  echo "  - Testar diretório: $BASHBANNER_BIN --dir ~/Downloads"
  echo "  - Resetar cache: $BASHBANNER_BIN --reset-cache"
}

do_uninstall(){
  if [ ! -f "$MANIFEST" ]; then
    echo "No manifest found at $MANIFEST. Nothing to uninstall."
    exit 1
  fi
  echo "Starting uninstall..."

  tac "$MANIFEST" | while IFS= read -r line; do
    case "$line" in
      BACKUP:*)
        IFS=':' read -r _ orig backup <<< "$line"
        if [ -f "$backup" ]; then
          cp -- "$backup" "$orig"
          echo "Restored $orig from $backup"
        fi
        ;;
      ENABLED_SYSTEMD:*)
        if command -v systemctl >/dev/null 2>&1; then
          systemctl --user disable --now bashbanner.service 2>/dev/null || true
          systemctl --user daemon-reload 2>/dev/null || true
          echo "Disabled systemd unit"
        fi
        ;;
      CREATED:*)
        path="${line#CREATED:}"
        if [[ "$path" == "$CONF_DIR"* ]] || [[ "$path" == "$BASHBANNER_BIN" ]] || [[ "$path" == "$SYSTEMD_UNIT" ]]; then
          rm -rf -- "$path" 2>/dev/null || true
          echo "Removed $path"
        else
          echo "Skipping removal of $path (not managed)"
        fi
        ;;
      APPENDED_RC:*)
        rc="${line#APPENDED_RC:}"
        bkp=$(ls -1 "$BACKUP_DIR"/"$(basename "$rc")".bak.* 2>/dev/null | tail -n1 || true)
        if [ -n "$bkp" ] && [ -f "$bkp" ]; then
          cp -- "$bkp" "$rc" && echo "Restored $rc from $bkp"
        else
          remove_source_from_rc "$rc"
        fi
        ;;
      *)
        ;;
    esac
  done

  rm -rf -- "$BACKUP_DIR" 2>/dev/null || true
  rm -f -- "$MANIFEST" 2>/dev/null || true
  echo "Uninstall complete. Backups and manifest removed."
}

# ============================================================================
# PONTO DE ENTRADA PRINCIPAL
# ============================================================================

# Verificar se há argumentos de linha de comando
if [ "$#" -eq 0 ]; then
  # Modo interativo
  show_menu
else
  # Modo CLI original
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --install) DO_INSTALL=true; shift ;;
      --uninstall) DO_UNINSTALL=true; shift ;;
      --with-systemd) ENABLE_SYSTEMD=true; shift ;;
      --with-hook) ENABLE_HOOK=true; shift ;;
      --no-rc) MODIFY_RC=false; shift ;;
      --help) show_help; exit 0 ;;
      --menu) show_menu; exit 0 ;;
      *) echo "Unknown argument: $1"; show_help; exit 1 ;;
    esac
  done

  if [ "$DO_INSTALL" = true ] && [ "$DO_UNINSTALL" = true ]; then
    echo "Can't --install and --uninstall at the same time"; exit 1
  fi

  if [ "$DO_INSTALL" = true ]; then
    do_install
    exit 0
  fi

  if [ "$DO_UNINSTALL" = true ]; then
    do_uninstall
    exit 0
  fi

  show_help
fi
