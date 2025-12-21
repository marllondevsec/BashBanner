#!/usr/bin/env bash
set -euo pipefail

# BashBanner0.2.sh
# Manager interativo para DynamicBanners
# - detecta XDG dirs (PT-BR/EN)
# - mostra banners ao entrar em dirs do usuário OU nas pastas do projeto
# - logging, manifest, backup, uninstall reversível
# - injeção idempotente no ~/.bashrc ou ~/.zshrc

##########################
# Config
##########################
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$INSTALL_DIR/dynamicbanners.log"
MANIFEST="$INSTALL_DIR/.dynamicbanners_manifest"
BACKUP_DIR="$INSTALL_DIR/backups"
MARKER_BEGIN="# BEGIN DynamicBanners"
MARKER_END="# END DynamicBanners"

USER_BANNER_DIRS=( bannerstartup bannerpictures bannerdocuments bannerdownloads bannertemplates bannermusic bannervideos bannerpublico bannerdesktop )

BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"

##########################
# Helpers
##########################
timestamp(){ date +"%Y-%m-%d %H:%M:%S"; }
log(){
  printf '%s %s\n' "$(timestamp)" "$*" | tee -a "$LOG_FILE"
}
ensure_state(){
  mkdir -p "$BACKUP_DIR"
  touch "$LOG_FILE"
  touch "$MANIFEST"
}
manifest_add(){ printf '%s\n' "$*" >> "$MANIFEST"; }
manifest_read(){ [ -f "$MANIFEST" ] && cat "$MANIFEST" || true; }
manifest_clear(){ rm -f "$MANIFEST"; touch "$MANIFEST"; }

# Safe absolute resolution for path check
is_within_install_dir(){
  local p="$1"
  local install_abs target_abs
  install_abs="$(cd "$INSTALL_DIR" >/dev/null 2>&1 && pwd)"
  target_abs="$(cd "$(dirname "$p")" >/dev/null 2>&1 && pwd)/$(basename "$p")"
  case "$target_abs" in
    "$install_abs" | "$install_abs"/*) return 0 ;;
    *) return 1 ;;
  esac
}

##########################
# Create banner folders (installer-side)
##########################
create_banner_dirs(){
  for d in "${USER_BANNER_DIRS[@]}"; do
    local path="$INSTALL_DIR/$d"
    if [ ! -d "$path" ]; then
      mkdir -p "$path"
      manifest_add "CREATED_DIR $path"
      log "Criado diretório: $path"
    else
      log "Diretório já existe: $path"
    fi
  done
}

##########################
# Generate injected shell block (idempotent)
# We'll remove any previous DynamicBanners block before appending.
##########################
generate_injected_block(){
  # This is a POSIX-friendly block that works in both bash and zsh.
  # It sets a safe PATH prefix, resolves XDG dirs once, and defines a robust
  # function to pick a random .txt banner using find + shuf / fallback.
  cat <<'EOF'
# BEGIN DynamicBanners
# DynamicBanners injected by BashBanner0.2
# Ensure minimal PATH so builtin utilities are available even early.
export PATH="/usr/bin:/bin:$PATH"

SCRIPT_DIR="__INSTALL_DIR__"

# Resolve XDG-user-dirs if present, otherwise fallbacks
if [ -f "$HOME/.config/user-dirs.dirs" ]; then
  # shellcheck disable=SC1090
  . "$HOME/.config/user-dirs.dirs"
fi

DESKTOP_DIR="${XDG_DESKTOP_DIR:-$HOME/Desktop}"
DOCUMENTS_DIR="${XDG_DOCUMENTS_DIR:-$HOME/Documents}"
DOWNLOADS_DIR="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
PICTURES_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}"
MUSIC_DIR="${XDG_MUSIC_DIR:-$HOME/Music}"
VIDEOS_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}"
PUBLIC_DIR="${XDG_PUBLICSHARE_DIR:-$HOME/Public}"
TEMPLATES_DIR="${XDG_TEMPLATES_DIR:-$HOME/Templates}"

# Expand $HOME tokens if any
for v in DESKTOP_DIR DOCUMENTS_DIR DOWNLOADS_DIR PICTURES_DIR MUSIC_DIR VIDEOS_DIR PUBLIC_DIR TEMPLATES_DIR; do
  eval "$v=\"\${$v/\$HOME/\$HOME}\""
done

# pick a random .txt file from a directory robustly (works early, avoids fragile arrays)
_display_random_banner() {
  local dir="$1"
  [ -d "$dir" ] || return 1

  # Try find + shuf if available
  local file
  if command -v shuf >/dev/null 2>&1; then
    file="$(find "$dir" -maxdepth 1 -type f -name '*.txt' -print 2>/dev/null | shuf -n1 2>/dev/null || true)"
  else
    # fallback: pick first .txt
    file="$(find "$dir" -maxdepth 1 -type f -name '*.txt' -print 2>/dev/null | awk 'NR==1{print; exit}' || true)"
  fi

  [ -n "$file" ] || return 1
  # Clear only if running in interactive terminal
  if [ -t 1 ]; then clear; fi
  cat "$file"
  return 0
}

# --- STARTUP: exibe bannerstartup uma vez ao carregar o rc (apenas shells interativos) ---
# Checa se shell é interativo: verifica se 'i' está presente em $-
# Usa variável de controle DYNAMICB_STARTUP_SHOWN para exibir apenas uma vez por sessão
case "$-" in
  *i*)
    if [ -z "${DYNAMICB_STARTUP_SHOWN:-}" ]; then
      export DYNAMICB_STARTUP_SHOWN=1
      # tenta exibir, mas não falha se não houver ficheiros/pasta
      _display_random_banner "$SCRIPT_DIR/bannerstartup" || true
    fi
    ;;
  *)
    # não interativo: não faz nada
    ;;
esac
# --- FIM STARTUP ---

# Main checker executed on directory change
_dynamicb_check_dir() {
  local cwd="$PWD"

  # 1) If we are inside user's real XDG dir, show the banner from INSTALL_DIR
  case "$cwd" in
    "$DOWNLOADS_DIR"*) _display_random_banner "$SCRIPT_DIR/bannerdownloads" && return ;;
    "$DOCUMENTS_DIR"*) _display_random_banner "$SCRIPT_DIR/bannerdocuments" && return ;;
    "$PICTURES_DIR"*)  _display_random_banner "$SCRIPT_DIR/bannerpictures" && return ;;
    "$MUSIC_DIR"*)     _display_random_banner "$SCRIPT_DIR/bannermusic" && return ;;
    "$VIDEOS_DIR"*)    _display_random_banner "$SCRIPT_DIR/bannervideos" && return ;;
    "$PUBLIC_DIR"*)    _display_random_banner "$SCRIPT_DIR/bannerpublico" && return ;;
    "$DESKTOP_DIR"*)   _display_random_banner "$SCRIPT_DIR/bannerdesktop" && return ;;
    "$TEMPLATES_DIR"*) _display_random_banner "$SCRIPT_DIR/bannertemplates" && return ;;
  esac

  # 2) If user is inside the INSTALL_DIR banner subfolders (preview mode)
  case "$cwd" in
    "$SCRIPT_DIR"/bannerdownloads* ) _display_random_banner "$SCRIPT_DIR/bannerdownloads" && return ;;
    "$SCRIPT_DIR"/bannerdocuments* ) _display_random_banner "$SCRIPT_DIR/bannerdocuments" && return ;;
    "$SCRIPT_DIR"/bannerpictures* )  _display_random_banner "$SCRIPT_DIR/bannerpictures" && return ;;
    "$SCRIPT_DIR"/bannertemplates* ) _display_random_banner "$SCRIPT_DIR/bannertemplates" && return ;;
    "$SCRIPT_DIR"/bannermusic* )     _display_random_banner "$SCRIPT_DIR/bannermusic" && return ;;
    "$SCRIPT_DIR"/bannervideos* )    _display_random_banner "$SCRIPT_DIR/bannervideos" && return ;;
    "$SCRIPT_DIR"/bannerpublico* )   _display_random_banner "$SCRIPT_DIR/bannerpublico" && return ;;
    "$SCRIPT_DIR"/bannerdesktop* )   _display_random_banner "$SCRIPT_DIR/bannerdesktop" && return ;;
    "$SCRIPT_DIR"/bannerstartup* )   _display_random_banner "$SCRIPT_DIR/bannerstartup" && return ;;
  esac

  return 0
}

# Hook into zsh or bash
if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -U add-zsh-hook 2>/dev/null || true
  add-zsh-hook chpwd _dynamicb_check_dir 2>/dev/null || true
fi
if [ -n "${BASH_VERSION:-}" ]; then
  # Avoid duplicating PROMPT_COMMAND entry
  case ":${PROMPT_COMMAND:-}:" in
    *":_dynamicb_check_dir:"*) : ;;
    *) PROMPT_COMMAND="_dynamicb_check_dir;${PROMPT_COMMAND:-}" ;;
  esac
fi

# END DynamicBanners
EOF
}

##########################
# Installer: append block safely
##########################
append_block_to_rc(){
  local rc_file="$1"
  ensure_state

  # create rc if missing
  if [ ! -f "$rc_file" ]; then
    touch "$rc_file"
    manifest_add "CREATED_FILE $rc_file"
    log "Criado $rc_file porque não existia."
  fi

  # backup rc
  local bkp="$BACKUP_DIR/$(basename "$rc_file").bak.$(date +%s)"
  cp -- "$rc_file" "$bkp"
  manifest_add "BACKUP_RC $rc_file $bkp"
  log "Backup de $rc_file criado em $bkp"

  # remove previous injected block (if any)
  # sed range: from MARKER_BEGIN to MARKER_END inclusive
  sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$rc_file"

  # prepare block with actual INSTALL_DIR substituted
  local block
  block="$(generate_injected_block)"
  block="${block//__INSTALL_DIR__/$INSTALL_DIR}"

  # append
  printf "\n%s\n" "$block" >> "$rc_file"
  manifest_add "APPENDED_RC $rc_file"
  log "Bloco adicionado em $rc_file"
}

##########################
# Installer main
##########################
perform_install(){
  ensure_state
  log "Iniciando instalação em $INSTALL_DIR"

  create_banner_dirs

  # decide which rc(s) to modify
  local default_shell rc_targets=()
  default_shell="$(basename "${SHELL:-/bin/sh}")"
  log "Shell detectado: $default_shell"

  # interactive selection
  echo "Escolha onde instalar:"
  PS3="Opção: "
  select opt in "Shell detectado ($default_shell)" "Ambos (bash + zsh)" "Escolher manualmente" "Cancelar"; do
    case "$REPLY" in
      1) rc_targets=("$default_shell"); break ;;
      2) rc_targets=(bash zsh); break ;;
      3) read -rp "Digite 'bash', 'zsh', ou ambos separados por espaço: " -a arr; rc_targets=("${arr[@]}"); break ;;
      4) log "Instalação cancelada"; return ;;
      *) echo "Opção inválida";;
    esac
  done

  for t in "${rc_targets[@]}"; do
    case "$t" in
      bash) append_block_to_rc "$BASHRC" ;;
      zsh) append_block_to_rc "$ZSHRC" ;;
      *)
        log "Target desconhecido: $t"
        ;;
    esac
  done

  log "Instalação concluída. Log: $LOG_FILE"
  echo "Para aplicar agora: source ~/.bashrc (ou source ~/.zshrc)"
}

##########################
# Uninstall: revert changes per manifest/backups
##########################
perform_uninstall(){
  ensure_state
  if [ ! -s "$MANIFEST" ]; then
    log "Manifest vazio — nada a desinstalar."
    echo "Manifest vazio."
    return
  fi

  echo "=== RESUMO DO QUE SERÁ REMOVIDO ==="
  manifest_read | tee -a "$LOG_FILE"
  echo "=================================="
  read -rp "Confirma desinstalar e reverter tudo que aparece acima? (yes/no) " yn
  if [ "$yn" != "yes" ]; then
    log "Desinstalação abortada"
    return
  fi

  # Restore RC backups if present, else remove markers
  # We stored backup entries as BACKUP_RC <rc_file> <bkp_path>
  # and APPENDED_RC <rc_file>
  tac "$MANIFEST" | while IFS= read -r line; do
    set -- $line
    cmd="$1"
    case "$cmd" in
      CREATED_DIR)
        path="$2"
        if is_within_install_dir "$path" && [ -d "$path" ]; then
          rm -rf -- "$path"
          log "Removido diretório: $path"
        fi
        ;;
      CREATED_FILE)
        path="$2"
        if is_within_install_dir "$path" && [ -f "$path" ]; then
          rm -f -- "$path"
          log "Removido ficheiro: $path"
        fi
        ;;
      BACKUP_RC)
        # nothing to do here (handled by APPENDED_RC)
        ;;
      APPENDED_RC)
        rc_file="$2"
        # find latest backup for this rc
        bkp="$(ls -1 "$BACKUP_DIR"/"$(basename "$rc_file")".bak.* 2>/dev/null | tail -n1 || true)"
        if [ -n "$bkp" ] && [ -f "$bkp" ]; then
          cp -- "$bkp" "$rc_file"
          log "Restaurado $rc_file a partir do backup $bkp"
        else
          # simply delete the block markers if no backup found
          sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$rc_file" || true
          log "Removido bloco DynamicBanners de $rc_file (sem backup)"
        fi
        ;;
      *)
        log "Linha de manifest não reconhecida: $line"
        ;;
    esac
  done

  # remove backups and manifest
  rm -rf -- "$BACKUP_DIR"
  rm -f -- "$MANIFEST"
  log "Removidos backups e manifest"

  read -rp "Deseja apagar o log ($LOG_FILE)? (yes/no) " yn2
  if [ "$yn2" = "yes" ]; then rm -f -- "$LOG_FILE"; log "Log apagado."; else log "Log mantido em $LOG_FILE"; fi

  log "Desinstalação concluída"
}

##########################
# Status & Log display
##########################
show_status(){
  echo "Install dir: $INSTALL_DIR"
  echo "Log file:    $LOG_FILE"
  echo "Manifest:    $MANIFEST"
  echo
  echo "Conteúdo do manifest (se existente):"
  if [ -s "$MANIFEST" ]; then manifest_read; else echo "(manifest vazio)"; fi
}

show_log(){
  if [ -f "$LOG_FILE" ]; then less "$LOG_FILE"; else echo "Nenhum log."; fi
}

##########################
# CLI menu
##########################
while true; do
  cat <<EOF

DynamicBanners Manager
1) Instalar
2) Desinstalar (reverte conforme manifest)
3) Status
4) Mostrar log
5) Sair
EOF

  read -rp "Escolha [1-5]: " opt
  case "$opt" in
    1) perform_install ;;
    2) perform_uninstall ;;
    3) show_status ;;
    4) show_log ;;
    5) log "Saindo."; exit 0 ;;
    *) echo "Opção inválida." ;;
  esac
done
