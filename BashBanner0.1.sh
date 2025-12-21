#!/usr/bin/env bash
# dynamicbanners_manager.sh
# Gerenciador interativo para instalar/desinstalar DynamicBanners com log e manifest
set -euo pipefail

# --- Configurações básicas ---
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$INSTALL_DIR/dynamicbanners.log"
MANIFEST="$INSTALL_DIR/.dynamicbanners_manifest"
BACKUP_DIR="$INSTALL_DIR/backups"
BANNER_DIRS=( "bannerstartup" "bannerpictures" "bannerdocuments" "bannerdownloads" "bannertemplates" "bannermusic" "bannervideos" "bannerpublico" "bannerdesktop" )
BASHRC_FILE="$HOME/.bashrc"
ZSHRC_FILE="$HOME/.zshrc"
MARKER_BEGIN="# BEGIN DynamicBanners"
MARKER_END="# END DynamicBanners"

# --- Helpers ---
timestamp() { date +"%Y-%m-%d %H:%M:%S"; }
log() {
  local msg="$*"
  printf '%s %s\n' "$(timestamp)" "$msg" | tee -a "$LOG_FILE"
}
ensure_dirs() {
  mkdir -p "$BACKUP_DIR"
  touch "$LOG_FILE"
  touch "$MANIFEST"
}
manifest_add() {
  # grava uma linha no manifest
  echo "$*" >> "$MANIFEST"
}
manifest_read() {
  cat "$MANIFEST"
}
manifest_clear() {
  rm -f "$MANIFEST"
  touch "$MANIFEST"
}

# Segurança: garante que um caminho pertence ao INSTALL_DIR
is_within_install_dir() {
  local p="$1"
  local install_abs
  install_abs="$(cd "$INSTALL_DIR" >/dev/null 2>&1 && pwd)"
  local target_abs
  target_abs="$(cd "$(dirname "$p")" >/dev/null 2>&1 && pwd)/$(basename "$p")"
  case "$target_abs" in
    "$install_abs" | "$install_abs"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Apaga conteúdo entre markers em um arquivo (seguro)
remove_marked_block() {
  local file="$1"
  if [ ! -f "$file" ]; then
    log "remove_marked_block: arquivo não existe: $file"
    return 0
  fi
  # Faz backup antes de remover
  local bkp="$BACKUP_DIR/$(basename "$file").pre_remove.$(date +%s).bak"
  cp -- "$file" "$bkp"
  manifest_add "BACKUP_RC $file $bkp"
  # Remove o bloco entre MARKER_BEGIN e MARKER_END
  awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
    BEGIN {skip=0}
    $0 ~ begin {skip=1; next}
    $0 ~ end {skip=0; next}
    { if (!skip) print }
  ' "$bkp" > "$file.tmp" && mv "$file.tmp" "$file"
  log "Block removido de $file (backup em $bkp)"
}

# Adiciona o bloco zsh ou bash de forma idempotente (com deteção XDG / PT-BR / EN)
append_block_to_rc() {
  local rc_file="$1"
  local shell_type="$2" # "bash" ou "zsh"
  if [ ! -f "$rc_file" ]; then
    touch "$rc_file"
    manifest_add "CREATED_FILE $rc_file"
    log "Criado $rc_file porque não existia."
  fi

  if grep -Fq "$MARKER_BEGIN" "$rc_file" 2>/dev/null; then
    log "Marcador já presente em $rc_file — pulando append."
    return
  fi

  # backup do rc antes de alterar
  local backup="$BACKUP_DIR/$(basename "$rc_file").bak.$(date +%s)"
  cp -- "$rc_file" "$backup"
  manifest_add "BACKUP_RC $rc_file $backup"
  log "Backup de $rc_file criado em $backup"

  if [ "$shell_type" = "zsh" ]; then
    cat >> "$rc_file" <<'ZSH_BLOCK'

# BEGIN DynamicBanners
# DynamicBanners (zsh) - adicionado pelo installer
export DYNAMIC_BANNERS_SHELL="zsh"
export SCRIPT_DIR="__INSTALL_DIR_PLACEHOLDER__"
BANNER_STARTUP_DIR="$SCRIPT_DIR/bannerstartup"
BANNER_PICTURES_DIR="$SCRIPT_DIR/bannerpictures"
BANNER_DOCUMENTS_DIR="$SCRIPT_DIR/bannerdocuments"
BANNER_DOWNLOADS_DIR="$SCRIPT_DIR/bannerdownloads"
BANNER_TEMPLATES_DIR="$SCRIPT_DIR/bannertemplates"
BANNER_MUSIC_DIR="$SCRIPT_DIR/bannermusic"
BANNER_VIDEOS_DIR="$SCRIPT_DIR/bannervideos"
BANNER_PUBLICO_DIR="$SCRIPT_DIR/bannerpublico"
BANNER_DESKTOP_DIR="$SCRIPT_DIR/bannerdesktop"

# Resolve diretórios XDG ou nomes locais (zsh)
resolve_xdg_or_local() {
  local key="$1"
  local -a candidates
  # 1) xdg-user-dir
  if command -v xdg-user-dir >/dev/null 2>&1; then
    local d
    d=$(xdg-user-dir "$key" 2>/dev/null || true)
    [ -n "$d" ] && candidates+=("$d")
  fi
  # 2) ~/.config/user-dirs.dirs
  if [ -f "$HOME/.config/user-dirs.dirs" ]; then
    local line d
    line=$(grep -E "^XDG_${key}_DIR=" "$HOME/.config/user-dirs.dirs" 2>/dev/null || true)
    if [ -n "$line" ]; then
      eval "$line"
      eval "d=\$XDG_${key}_DIR"
      d=${d/#\$HOME/$HOME}
      candidates+=("$d")
    fi
  fi
  # 3) common names (EN + PT-BR)
  case "$key" in
    DESKTOP) candidates+=("$HOME/Desktop" "$HOME/Área de Trabalho" "$HOME/Área_de_Trabalho" "$HOME/Work") ;;
    DOCUMENTS) candidates+=("$HOME/Documents" "$HOME/Documentos") ;;
    DOWNLOAD) candidates+=("$HOME/Downloads" "$HOME/Transferências" "$HOME/Transferencias") ;;
    PICTURES) candidates+=("$HOME/Pictures" "$HOME/Imagens" "$HOME/Images") ;;
    MUSIC) candidates+=("$HOME/Music" "$HOME/Música" "$HOME/Musicas") ;;
    VIDEOS) candidates+=("$HOME/Videos" "$HOME/Vídeos") ;;
    PUBLICSHARE) candidates+=("$HOME/Public" "$HOME/Público" "$HOME/Publico") ;;
    TEMPLATES) candidates+=("$HOME/Templates" "$HOME/Modelos") ;;
  esac

  local c
  for c in "${candidates[@]}"; do
    [ -z "$c" ] && continue
    if [ -d "$c" ]; then
      printf '%s' "$c"
      return 0
    fi
  done
  return 1
}

# Pre-resolve (ao carregar o rc) para velocidade; fallback para SCRIPT_DIR/banner*
BANNER_DESKTOP_DIR="$(resolve_xdg_or_local DESKTOP 2>/dev/null || true)"
BANNER_DOCUMENTS_DIR="$(resolve_xdg_or_local DOCUMENTS 2>/dev/null || true)"
BANNER_DOWNLOADS_DIR="$(resolve_xdg_or_local DOWNLOAD 2>/dev/null || true)"
BANNER_PICTURES_DIR="$(resolve_xdg_or_local PICTURES 2>/dev/null || true)"
BANNER_MUSIC_DIR="$(resolve_xdg_or_local MUSIC 2>/dev/null || true)"
BANNER_VIDEOS_DIR="$(resolve_xdg_or_local VIDEOS 2>/dev/null || true)"
BANNER_PUBLICO_DIR="$(resolve_xdg_or_local PUBLICSHARE 2>/dev/null || true)"
BANNER_TEMPLATES_DIR="$(resolve_xdg_or_local TEMPLATES 2>/dev/null || true)"

# If any are empty, point them to local SCRIPT_DIR/banner*
[ -z "$BANNER_DESKTOP_DIR" ] && BANNER_DESKTOP_DIR="$SCRIPT_DIR/bannerdesktop"
[ -z "$BANNER_DOCUMENTS_DIR" ] && BANNER_DOCUMENTS_DIR="$SCRIPT_DIR/bannerdocuments"
[ -z "$BANNER_DOWNLOADS_DIR" ] && BANNER_DOWNLOADS_DIR="$SCRIPT_DIR/bannerdownloads"
[ -z "$BANNER_PICTURES_DIR" ] && BANNER_PICTURES_DIR="$SCRIPT_DIR/bannerpictures"
[ -z "$BANNER_MUSIC_DIR" ] && BANNER_MUSIC_DIR="$SCRIPT_DIR/bannermusic"
[ -z "$BANNER_VIDEOS_DIR" ] && BANNER_VIDEOS_DIR="$SCRIPT_DIR/bannervideos"
[ -z "$BANNER_PUBLICO_DIR" ] && BANNER_PUBLICO_DIR="$SCRIPT_DIR/bannerpublico"
[ -z "$BANNER_TEMPLATES_DIR" ] && BANNER_TEMPLATES_DIR="$SCRIPT_DIR/bannertemplates"
[ -z "$BANNER_STARTUP_DIR" ] && BANNER_STARTUP_DIR="$SCRIPT_DIR/bannerstartup"

# Ensure receiver directories exist (create under SCRIPT_DIR for local fallbacks)
mkdir -p "$SCRIPT_DIR/bannerstartup" "$SCRIPT_DIR/bannerpictures" "$SCRIPT_DIR/bannerdocuments" \
         "$SCRIPT_DIR/bannerdownloads" "$SCRIPT_DIR/bannertemplates" "$SCRIPT_DIR/bannermusic" \
         "$SCRIPT_DIR/bannervideos" "$SCRIPT_DIR/bannerpublico" "$SCRIPT_DIR/bannerdesktop" 2>/dev/null || true

display_random_banner() {
  local banner_dir=$1
  local files=( "$banner_dir"/*.txt )
  if [ -e "${files[0]}" ]; then
    shuf -n 1 -e "${files[@]}" | xargs -r -I{} cat "{}"
  fi
}

if [ -z "${BANNER_SHOWN:-}" ]; then
  display_random_banner "$BANNER_STARTUP_DIR"
  export BANNER_SHOWN=true
fi

function chpwd() {
  local cwd="$PWD"
  local banner_dir=""

  # If some variables are empty, try resolve on the fly
  [ -z "$BANNER_DESKTOP_DIR" ] && BANNER_DESKTOP_DIR="$(resolve_xdg_or_local DESKTOP 2>/dev/null || true)"
  [ -z "$BANNER_DOCUMENTS_DIR" ] && BANNER_DOCUMENTS_DIR="$(resolve_xdg_or_local DOCUMENTS 2>/dev/null || true)"
  [ -z "$BANNER_DOWNLOADS_DIR" ] && BANNER_DOWNLOADS_DIR="$(resolve_xdg_or_local DOWNLOAD 2>/dev/null || true)"
  [ -z "$BANNER_PICTURES_DIR" ] && BANNER_PICTURES_DIR="$(resolve_xdg_or_local PICTURES 2>/dev/null || true)"
  [ -z "$BANNER_MUSIC_DIR" ] && BANNER_MUSIC_DIR="$(resolve_xdg_or_local MUSIC 2>/dev/null || true)"
  [ -z "$BANNER_VIDEOS_DIR" ] && BANNER_VIDEOS_DIR="$(resolve_xdg_or_local VIDEOS 2>/dev/null || true)"
  [ -z "$BANNER_PUBLICO_DIR" ] && BANNER_PUBLICO_DIR="$(resolve_xdg_or_local PUBLICSHARE 2>/dev/null || true)"
  [ -z "$BANNER_TEMPLATES_DIR" ] && BANNER_TEMPLATES_DIR="$(resolve_xdg_or_local TEMPLATES 2>/dev/null || true)"

  case "$cwd" in
    "$BANNER_PICTURES_DIR" | "$BANNER_PICTURES_DIR"/*) banner_dir="$BANNER_PICTURES_DIR" ;;
    "$BANNER_DOCUMENTS_DIR" | "$BANNER_DOCUMENTS_DIR"/*) banner_dir="$BANNER_DOCUMENTS_DIR" ;;
    "$BANNER_DOWNLOADS_DIR" | "$BANNER_DOWNLOADS_DIR"/*) banner_dir="$BANNER_DOWNLOADS_DIR" ;;
    "$BANNER_TEMPLATES_DIR" | "$BANNER_TEMPLATES_DIR"/*) banner_dir="$BANNER_TEMPLATES_DIR" ;;
    "$BANNER_MUSIC_DIR" | "$BANNER_MUSIC_DIR"/*) banner_dir="$BANNER_MUSIC_DIR" ;;
    "$BANNER_VIDEOS_DIR" | "$BANNER_VIDEOS_DIR"/*) banner_dir="$BANNER_VIDEOS_DIR" ;;
    "$BANNER_PUBLICO_DIR" | "$BANNER_PUBLICO_DIR"/*) banner_dir="$BANNER_PUBLICO_DIR" ;;
    "$BANNER_DESKTOP_DIR" | "$BANNER_DESKTOP_DIR"/*) banner_dir="$BANNER_DESKTOP_DIR" ;;
    *) return ;;
  esac

  if [ -n "$banner_dir" ] && [ "${LAST_DIR:-}" != "$PWD" ]; then
    display_random_banner "$banner_dir"
    LAST_DIR="$PWD"
  fi
}

autoload -U add-zsh-hook 2>/dev/null || true
add-zsh-hook chpwd chpwd 2>/dev/null || true
# END DynamicBanners

ZSH_BLOCK
    # replace placeholder with real INSTALL_DIR (safe)
    sed -i "s|__INSTALL_DIR_PLACEHOLDER__|$INSTALL_DIR|g" "$rc_file"
    manifest_add "APPENDED_RC $rc_file zsh"
    log "Bloco zsh adicionado em $rc_file"
  else
    # bloco para bash (note: this block will expand INSTALL_DIR at write time)
    cat >> "$rc_file" <<'BASH_BLOCK'

# BEGIN DynamicBanners
# DynamicBanners (bash) - adicionado pelo installer
export DYNAMIC_BANNERS_SHELL="bash"
export SCRIPT_DIR="$INSTALL_DIR"
BANNER_STARTUP_DIR="\$SCRIPT_DIR/bannerstartup"
BANNER_PICTURES_DIR="\$SCRIPT_DIR/bannerpictures"
BANNER_DOCUMENTS_DIR="\$SCRIPT_DIR/bannerdocuments"
BANNER_DOWNLOADS_DIR="\$SCRIPT_DIR/bannerdownloads"
BANNER_TEMPLATES_DIR="\$SCRIPT_DIR/bannertemplates"
BANNER_MUSIC_DIR="\$SCRIPT_DIR/bannermusic"
BANNER_VIDEOS_DIR="\$SCRIPT_DIR/bannervideos"
BANNER_PUBLICO_DIR="\$SCRIPT_DIR/bannerpublico"
BANNER_DESKTOP_DIR="\$SCRIPT_DIR/bannerdesktop"

# Resolve diretórios XDG ou nomes locais (bash)
resolve_xdg_or_local() {
  local key="\$1"
  local candidates=()
  if command -v xdg-user-dir >/dev/null 2>&1; then
    local d
    d=\$(xdg-user-dir "\$key" 2>/dev/null || true)
    [ -n "\$d" ] && candidates+=( "\$d" )
  fi
  if [ -f "\$HOME/.config/user-dirs.dirs" ]; then
    local line d
    line=\$(grep -E "^XDG_\${key}_DIR=" "\$HOME/.config/user-dirs.dirs" 2>/dev/null || true)
    if [ -n "\$line" ]; then
      eval "\$line"
      eval "d=\$XDG_${key}_DIR"
      d=\${d/#\$HOME/\$HOME}
      candidates+=( "\$d" )
    fi
  fi
  case "\$key" in
    DESKTOP) candidates+=( "\$HOME/Desktop" "\$HOME/Área de Trabalho" "\$HOME/Área_de_Trabalho" "\$HOME/Work" ) ;;
    DOCUMENTS) candidates+=( "\$HOME/Documents" "\$HOME/Documentos" ) ;;
    DOWNLOAD) candidates+=( "\$HOME/Downloads" "\$HOME/Transferências" "\$HOME/Transferencias" ) ;;
    PICTURES) candidates+=( "\$HOME/Pictures" "\$HOME/Imagens" "\$HOME/Images" ) ;;
    MUSIC) candidates+=( "\$HOME/Music" "\$HOME/Música" "\$HOME/Musicas" ) ;;
    VIDEOS) candidates+=( "\$HOME/Videos" "\$HOME/Vídeos" ) ;;
    PUBLICSHARE) candidates+=( "\$HOME/Public" "\$HOME/Público" "\$HOME/Publico" ) ;;
    TEMPLATES) candidates+=( "\$HOME/Templates" "\$HOME/Modelos" ) ;;
  esac

  local c
  for c in "\${candidates[@]}"; do
    [ -z "\$c" ] && continue
    if [ -d "\$c" ]; then
      printf '%s' "\$c"
      return 0
    fi
  done
  return 1
}

# Pre-resolve (ao carregar o rc)
BANNER_DESKTOP_DIR="\$(resolve_xdg_or_local DESKTOP 2>/dev/null || true)"
BANNER_DOCUMENTS_DIR="\$(resolve_xdg_or_local DOCUMENTS 2>/dev/null || true)"
BANNER_DOWNLOADS_DIR="\$(resolve_xdg_or_local DOWNLOAD 2>/dev/null || true)"
BANNER_PICTURES_DIR="\$(resolve_xdg_or_local PICTURES 2>/dev/null || true)"
BANNER_MUSIC_DIR="\$(resolve_xdg_or_local MUSIC 2>/dev/null || true)"
BANNER_VIDEOS_DIR="\$(resolve_xdg_or_local VIDEOS 2>/dev/null || true)"
BANNER_PUBLICO_DIR="\$(resolve_xdg_or_local PUBLICSHARE 2>/dev/null || true)"
BANNER_TEMPLATES_DIR="\$(resolve_xdg_or_local TEMPLATES 2>/dev/null || true)"

# Fallback to local SCRIPT_DIR/banner* if missing
[ -z "\$BANNER_DESKTOP_DIR" ] && BANNER_DESKTOP_DIR="\$SCRIPT_DIR/bannerdesktop"
[ -z "\$BANNER_DOCUMENTS_DIR" ] && BANNER_DOCUMENTS_DIR="\$SCRIPT_DIR/bannerdocuments"
[ -z "\$BANNER_DOWNLOADS_DIR" ] && BANNER_DOWNLOADS_DIR="\$SCRIPT_DIR/bannerdownloads"
[ -z "\$BANNER_PICTURES_DIR" ] && BANNER_PICTURES_DIR="\$SCRIPT_DIR/bannerpictures"
[ -z "\$BANNER_MUSIC_DIR" ] && BANNER_MUSIC_DIR="\$SCRIPT_DIR/bannermusic"
[ -z "\$BANNER_VIDEOS_DIR" ] && BANNER_VIDEOS_DIR="\$SCRIPT_DIR/bannervideos"
[ -z "\$BANNER_PUBLICO_DIR" ] && BANNER_PUBLICO_DIR="\$SCRIPT_DIR/bannerpublico"
[ -z "\$BANNER_TEMPLATES_DIR" ] && BANNER_TEMPLATES_DIR="\$SCRIPT_DIR/bannertemplates"
[ -z "\$BANNER_STARTUP_DIR" ] && BANNER_STARTUP_DIR="\$SCRIPT_DIR/bannerstartup"

# Ensure receiver directories exist (create under SCRIPT_DIR for local fallbacks)
mkdir -p "\$SCRIPT_DIR/bannerstartup" "\$SCRIPT_DIR/bannerpictures" "\$SCRIPT_DIR/bannerdocuments" \
         "\$SCRIPT_DIR/bannerdownloads" "\$SCRIPT_DIR/bannertemplates" "\$SCRIPT_DIR/bannermusic" \
         "\$SCRIPT_DIR/bannervideos" "\$SCRIPT_DIR/bannerpublico" "\$SCRIPT_DIR/bannerdesktop" 2>/dev/null || true

display_random_banner() {
  local banner_dir="\$1"
  local files=( "\$banner_dir"/*.txt )
  if [ -e "\${files[0]}" ]; then
    shuf -n 1 -e "\${files[@]}" | xargs -r -I{} cat "{}"
  fi
}

if [ -z "\${BANNER_SHOWN:-}" ]; then
  display_random_banner "\$BANNER_STARTUP_DIR"
  export BANNER_SHOWN=true
fi

_DYNAMICB_LAST_DIR="${PWD:-}"
_dynamicb_check_pwd() {
  if [ "${PWD:-}" != "${_DYNAMICB_LAST_DIR:-}" ]; then
    # If pre-resolved missing, resolve on-the-fly
    [ -z "\$BANNER_DESKTOP_DIR" ] && BANNER_DESKTOP_DIR="\$(resolve_xdg_or_local DESKTOP 2>/dev/null || true)"
    [ -z "\$BANNER_DOCUMENTS_DIR" ] && BANNER_DOCUMENTS_DIR="\$(resolve_xdg_or_local DOCUMENTS 2>/dev/null || true)"
    [ -z "\$BANNER_DOWNLOADS_DIR" ] && BANNER_DOWNLOADS_DIR="\$(resolve_xdg_or_local DOWNLOAD 2>/dev/null || true)"
    [ -z "\$BANNER_PICTURES_DIR" ] && BANNER_PICTURES_DIR="\$(resolve_xdg_or_local PICTURES 2>/dev/null || true)"
    [ -z "\$BANNER_MUSIC_DIR" ] && BANNER_MUSIC_DIR="\$(resolve_xdg_or_local MUSIC 2>/dev/null || true)"
    [ -z "\$BANNER_VIDEOS_DIR" ] && BANNER_VIDEOS_DIR="\$(resolve_xdg_or_local VIDEOS 2>/dev/null || true)"
    [ -z "\$BANNER_PUBLICO_DIR" ] && BANNER_PUBLICO_DIR="\$(resolve_xdg_or_local PUBLICSHARE 2>/dev/null || true)"
    [ -z "\$BANNER_TEMPLATES_DIR" ] && BANNER_TEMPLATES_DIR="\$(resolve_xdg_or_local TEMPLATES 2>/dev/null || true)"

    case "$PWD" in
      "$BANNER_PICTURES_DIR" | "$BANNER_PICTURES_DIR"/*) display_random_banner "$BANNER_PICTURES_DIR" ;;
      "$BANNER_DOCUMENTS_DIR" | "$BANNER_DOCUMENTS_DIR"/*) display_random_banner "$BANNER_DOCUMENTS_DIR" ;;
      "$BANNER_DOWNLOADS_DIR" | "$BANNER_DOWNLOADS_DIR"/*) display_random_banner "$BANNER_DOWNLOADS_DIR" ;;
      "$BANNER_TEMPLATES_DIR" | "$BANNER_TEMPLATES_DIR"/*) display_random_banner "$BANNER_TEMPLATES_DIR" ;;
      "$BANNER_MUSIC_DIR" | "$BANNER_MUSIC_DIR"/*) display_random_banner "$BANNER_MUSIC_DIR" ;;
      "$BANNER_VIDEOS_DIR" | "$BANNER_VIDEOS_DIR"/*) display_random_banner "$BANNER_VIDEOS_DIR" ;;
      "$BANNER_PUBLICO_DIR" | "$BANNER_PUBLICO_DIR"/*) display_random_banner "$BANNER_PUBLICO_DIR" ;;
      "$BANNER_DESKTOP_DIR" | "$BANNER_DESKTOP_DIR"/*) display_random_banner "$BANNER_DESKTOP_DIR" ;;
      *) ;;
    esac

    _DYNAMICB_LAST_DIR="$PWD"
  fi
}

if [[ ":${PROMPT_COMMAND}:" != *":_dynamicb_check_pwd:"* ]]; then
  PROMPT_COMMAND="_dynamicb_check_pwd;${PROMPT_COMMAND:-}"
fi
# END DynamicBanners

BASH_BLOCK
    manifest_add "APPENDED_RC $rc_file bash"
    log "Bloco bash adicionado em $rc_file"
  fi
}

# Cria diretórios de banner (idempotente) — também cria local fallbacks
create_banner_dirs() {
  for d in "${BANNER_DIRS[@]}"; do
    local path="$INSTALL_DIR/$d"
    if [ ! -d "$path" ]; then
      mkdir -p "$path"
      manifest_add "CREATED_DIR $path"
      log "Criado diretório: $path"
    else
      log "Diretório já existe: $path"
    fi
  done

  # Também garanta que os diretórios locais under SCRIPT_DIR existam (fallbacks)
  mkdir -p "$INSTALL_DIR/bannerstartup" "$INSTALL_DIR/bannerpictures" "$INSTALL_DIR/bannerdocuments" \
           "$INSTALL_DIR/bannerdownloads" "$INSTALL_DIR/bannertemplates" "$INSTALL_DIR/bannermusic" \
           "$INSTALL_DIR/bannervideos" "$INSTALL_DIR/bannerpublico" "$INSTALL_DIR/bannerdesktop" 2>/dev/null || true
}

# Cria ficheiros placeholder instaladores (apenas se não existirem)
create_placeholder_installers() {
  local b="$INSTALL_DIR/ibash.sh"
  local zb="$INSTALL_DIR/izsh.sh"
  if [ ! -f "$b" ]; then
    cat > "$b" <<'EOF'
#!/usr/bin/env bash
# placeholder ibash.sh
echo "ibash installer placeholder"
EOF
    chmod +x "$b"
    manifest_add "CREATED_FILE $b"
    log "Placeholder criado: $b"
  fi
  if [ ! -f "$zb" ]; then
    cat > "$zb" <<'EOF'
#!/usr/bin/env bash
# placeholder izsh.sh
echo "izsh installer placeholder"
EOF
    chmod +x "$zb"
    manifest_add "CREATED_FILE $zb"
    log "Placeholder criado: $zb"
  fi
}

# --- Instalar ---
perform_install() {
  ensure_dirs
  log "Iniciando instalação do DynamicBanners em $INSTALL_DIR"

  # Detecta shell padrão
  local default_shell="$(basename "${SHELL:-/bin/sh}")"
  log "Shell detectado: $default_shell"

  echo "Escolha onde instalar:"
  PS3="Opção: "
  select opt in "Shell detectado ($default_shell)" "Ambos (bash + zsh)" "Escolher manualmente" "Cancelar"; do
    case "$REPLY" in
      1) targets=("$default_shell"); break ;;
      2) targets=("bash" "zsh"); break ;;
      3)
         echo "Escolha manual: digite 'bash', 'zsh', ou ambos separados por espaço:"
         read -r -a arr
         targets=("${arr[@]}")
         break
         ;;
      4) log "Instalação cancelada pelo usuário."; return ;;
      *) echo "Opção inválida";;
    esac
  done

  # Cria dirs e files
  create_banner_dirs
  create_placeholder_installers

  # Adiciona blocos
  for t in "${targets[@]}"; do
    case "$t" in
      bash)
        append_block_to_rc "$BASHRC_FILE" "bash"
        ;;
      zsh)
        append_block_to_rc "$ZSHRC_FILE" "zsh"
        ;;
      *)
        log "Target desconhecido: $t - pulando"
        ;;
    esac
  done

  log "Instalação concluída. Consultar log em: $LOG_FILE"
  echo
  echo "Para aplicar imediatamente, execute:"
  for t in "${targets[@]}"; do
    if [ "$t" = "bash" ]; then
      echo "  source ~/.bashrc"
    elif [ "$t" = "zsh" ]; then
      echo "  source ~/.zshrc"
    fi
  done
}

# --- Desinstalar (reverte com base no manifest) ---
perform_uninstall() {
  ensure_dirs
  if [ ! -s "$MANIFEST" ]; then
    log "Manifest vazio — nada para desinstalar."
    echo "Manifest vazio. Talvez o programa nunca tenha sido instalado por este script."
    return
  fi

  echo "=== RESUMO DO QUE SERÁ REMOVIDO ==="
  manifest_read | tee -a "$LOG_FILE"
  echo "=================================="
  read -rp "Confirma desinstalar e reverter tudo que aparece acima? (yes/no) " yn
  if [ "$yn" != "yes" ]; then
    log "Desinstalação abortada pelo usuário."
    echo "Abortado."
    return
  fi

  log "Iniciando desinstalação/reversão com base em $MANIFEST"

  # Lê manifest de baixo para cima para desfazer na ordem inversa
  tac "$MANIFEST" | while IFS= read -r line; do
    set -- $line
    cmd="$1"
    case "$cmd" in
      CREATED_DIR)
        path="$2"
        if is_within_install_dir "$path" && [ -d "$path" ]; then
          rm -rf -- "$path"
          log "Removido diretório criado: $path"
        else
          log "Ignorado (fora do install_dir ou não existe): $path"
        fi
        ;;
      CREATED_FILE)
        path="$2"
        if is_within_install_dir "$path" && [ -f "$path" ]; then
          rm -f -- "$path"
          log "Removido ficheiro criado: $path"
        else
          log "Ignorado (fora do install_dir ou não existe): $path"
        fi
        ;;
      APPENDED_RC)
        rc_file="$2"
        shelltype="$3"
        bkp="$(ls -1 "$BACKUP_DIR"/"$(basename "$rc_file")".bak.* 2>/dev/null | tail -n1 || true)"
        if [ -n "$bkp" ] && [ -f "$bkp" ]; then
          cp -- "$bkp" "$rc_file"
          log "Restaurado $rc_file a partir de backup $bkp"
        else
          remove_marked_block "$rc_file"
        fi
        ;;
      BACKUP_RC)
        log "Backup marcado: $line"
        ;;
      *)
        log "Entrada não reconhecida no manifest: $line"
        ;;
    esac
  done

  # Apaga backups e manifest
  if [ -d "$BACKUP_DIR" ]; then
    rm -rf -- "$BACKUP_DIR"
    log "Removido diretório de backups: $BACKUP_DIR"
  fi
  rm -f -- "$MANIFEST"
  log "Removido manifest: $MANIFEST"

  # Opcional: pergunta para limpar log também
  read -rp "Deseja apagar o log ($LOG_FILE)? (yes/no) " yn2
  if [ "$yn2" = "yes" ]; then
    rm -f -- "$LOG_FILE"
    log "Log apagado por solicitação do usuário."
  else
    log "Log mantido em $LOG_FILE"
  fi

  log "Desinstalação concluída."
}

# --- Status e exibição de log ---
show_status() {
  echo "=== STATUS ==="
  echo "Install dir: $INSTALL_DIR"
  echo "Log file:    $LOG_FILE"
  echo "Manifest:    $MANIFEST"
  echo
  echo "Arquivos/dirs criados (segundo manifest):"
  if [ -s "$MANIFEST" ]; then
    manifest_read
  else
    echo "(manifest vazio)"
  fi
  echo "=== FIM STATUS ==="
}

show_log() {
  if [ -f "$LOG_FILE" ]; then
    less "$LOG_FILE"
  else
    echo "Nenhum log encontrado."
  fi
}

# --- Menu interativo ---
while true; do
  cat <<EOF

DynamicBanners Manager
1) Instalar
2) Desinstalar (reverte conforme manifest)
3) Status
4) Mostrar log
5) Sair
EOF

  read -rp "Escolha uma opção [1-5]: " opt
  case "$opt" in
    1) perform_install ;;
    2) perform_uninstall ;;
    3) show_status ;;
    4) show_log ;;
    5) log "Saindo."; exit 0 ;;
    *) echo "Opção inválida." ;;
  esac
done
