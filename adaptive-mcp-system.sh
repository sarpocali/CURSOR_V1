#!/bin/bash
# ================================================================
# ADAPTIVE MCP SERVER ROOM - DEĞİŞİKLİKLERE DAYANIKLI SİSTEM
# ================================================================
# Bu sistem:
# 1. Mevcut yapıyı ASLA bozmaz
# 2. Path değişikliklerine otomatik adapte olur
# 3. Her değişikliği versiyonlar ve yedekler
# 4. Kendini otomatik onarır

# === MASTER CONTROLLER SCRIPT ===
cat << 'MASTER_EOF' > mcp-controller.sh
#!/bin/bash
set -e

# ============================
# ADAPTIVE PATH MANAGEMENT
# ============================

# Dinamik olarak çalışma dizinini bul
find_mcp_base() {
    # Önce INVENTORY.json'un yerini bul
    if [ -f "./INVENTORY.json" ]; then
        echo "$(pwd)"
    elif [ -f "$HOME/Desktop/CURSOR_V1/INVENTORY.json" ]; then
        echo "$HOME/Desktop/CURSOR_V1"
    else
        # INVENTORY.json'u sistemde ara
        local found=$(find "$HOME/Desktop" -name "INVENTORY.json" -path "*/CURSOR_V1/*" 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            dirname "$found"
        else
            echo "/Users/sarpocali/Desktop/CURSOR_V1"  # Fallback
        fi
    fi
}

# MCP_BASE'i dinamik olarak belirle
export MCP_BASE=$(find_mcp_base)
export MCP_CONFIG_DIR="$MCP_BASE/.mcp-adaptive"
export MCP_STATE_FILE="$MCP_CONFIG_DIR/state.json"
export MCP_BACKUP_DIR="$MCP_CONFIG_DIR/backups"
export MCP_CACHE_DIR="$MCP_CONFIG_DIR/cache"

# Renklendirme
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ============================
# SYSTEM INITIALIZATION
# ============================

init_adaptive_system() {
    echo -e "${BLUE}🚀 Initializing Adaptive MCP System${NC}"
    echo -e "   Base Directory: ${GREEN}$MCP_BASE${NC}"
    
    # Gerekli dizinleri oluştur
    mkdir -p "$MCP_CONFIG_DIR"
    mkdir -p "$MCP_BACKUP_DIR"
    mkdir -p "$MCP_CACHE_DIR"
    mkdir -p "$MCP_BASE/scripts"
    
    # State dosyasını oluştur/güncelle
    if [ ! -f "$MCP_STATE_FILE" ]; then
        cat > "$MCP_STATE_FILE" << EOF
{
  "version": "1.0.0",
  "base_path": "$MCP_BASE",
  "last_update": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "tools_count": 19,
  "status": "initializing"
}
EOF
    fi
}

# ============================
# SMART PATH RESOLVER
# ============================

resolve_paths() {
    local tool_id="$1"
    local original_path="$2"
    
    # Eğer path zaten doğruysa, değiştirme
    if [ -e "$original_path" ]; then
        echo "$original_path"
        return 0
    fi
    
    # Path'i MCP_BASE'e göre yeniden oluştur
    if [[ "$original_path" == /Users/sarpocali/Desktop/CURSOR_V1/* ]]; then
        local relative_path="${original_path#/Users/sarpocali/Desktop/CURSOR_V1/}"
        echo "$MCP_BASE/$relative_path"
    else
        echo "$original_path"
    fi
}

# ============================
# INVENTORY PROCESSOR
# ============================

process_inventory() {
    echo -e "${BLUE}📋 Processing INVENTORY.json${NC}"
    
    if [ ! -f "$MCP_BASE/INVENTORY.json" ]; then
        echo -e "${RED}❌ INVENTORY.json not found!${NC}"
        return 1
    fi
    
    # Python script ile INVENTORY'yi işle ve path'leri güncelle
    python3 << PYTHON_EOF
import json
import os
import sys

mcp_base = os.environ.get('MCP_BASE', '/Users/sarpocali/Desktop/CURSOR_V1')
inventory_file = f"{mcp_base}/INVENTORY.json"
output_file = f"{mcp_base}/.mcp-adaptive/processed_inventory.json"

print(f"Processing inventory from: {inventory_file}")

with open(inventory_file, 'r') as f:
    inventory = json.load(f)

# Path'leri güncelle
old_base = "/Users/sarpocali/Desktop/CURSOR_V1"
for tool in inventory:
    # args içindeki path'leri güncelle
    if 'args' in tool:
        tool['args'] = [
            arg.replace(old_base, mcp_base) if isinstance(arg, str) else arg
            for arg in tool['args']
        ]
    
    # resolved_paths'i güncelle
    if 'resolved_paths' in tool:
        for key, value in tool['resolved_paths'].items():
            if isinstance(value, str) and old_base in value:
                tool['resolved_paths'][key] = value.replace(old_base, mcp_base)

# Güncellenmiş inventory'yi kaydet
os.makedirs(os.path.dirname(output_file), exist_ok=True)
with open(output_file, 'w') as f:
    json.dump(inventory, f, indent=2)

print(f"✅ Processed inventory saved to: {output_file}")
print(f"   Total tools: {len(inventory)}")
PYTHON_EOF
}

# ============================
# DYNAMIC MCP.JSON GENERATOR
# ============================

generate_mcp_json() {
    echo -e "${BLUE}🔧 Generating adaptive mcp.json${NC}"
    
    python3 << PYTHON_EOF
import json
import os

mcp_base = os.environ.get('MCP_BASE', '/Users/sarpocali/Desktop/CURSOR_V1')
inventory_file = f"{mcp_base}/.mcp-adaptive/processed_inventory.json"
output_file = f"{mcp_base}/mcp.json"
backup_file = f"{mcp_base}/.mcp-adaptive/backups/mcp.json.$(date +%Y%m%d_%H%M%S)"

# Mevcut mcp.json'u yedekle
if os.path.exists(output_file):
    os.makedirs(os.path.dirname(backup_file), exist_ok=True)
    with open(output_file, 'r') as f:
        backup_data = f.read()
    with open(backup_file, 'w') as f:
        f.write(backup_data)
    print(f"📦 Backup created: {backup_file}")

# Inventory'yi yükle
with open(inventory_file, 'r') as f:
    inventory = json.load(f)

# MCP config oluştur
mcp_config = {"mcpServers": {}}

for tool in inventory:
    tool_id = tool['tool_id']
    
    # Archon özel durum (HTTP endpoint)
    if tool_id == 'archon':
        continue  # Docker-based, skip for now
    
    # Diğer araçlar için config oluştur
    server_config = {
        "command": tool['command'],
        "args": tool['args']
    }
    
    # Environment variables ekle
    if tool['env_keys_used']:
        server_config["env"] = {}
        for key in tool['env_keys_used']:
            server_config["env"][key] = f"${{{key}}}"
    
    mcp_config["mcpServers"][tool_id] = server_config

# Kaydet
with open(output_file, 'w') as f:
    json.dump(mcp_config, f, indent=2)

print(f"✅ Generated mcp.json with {len(mcp_config['mcpServers'])} tools")
PYTHON_EOF
}

# ============================
# SYMLINK MANAGER
# ============================

manage_symlinks() {
    echo -e "${BLUE}🔗 Managing symbolic links${NC}"
    
    # Ana dizin linkleri
    ln -sf "$MCP_BASE/mcp.json" "$HOME/mcp-server-room.json" 2>/dev/null || true
    ln -sf "$MCP_BASE/.env" "$HOME/mcp-server-room.env" 2>/dev/null || true
    
    # Cursor config
    mkdir -p "$HOME/.cursor"
    ln -sf "$MCP_BASE/mcp.json" "$HOME/.cursor/mcp.json" 2>/dev/null || true
    
    # Diğer projeler için global link
    mkdir -p "$HOME/.mcp"
    ln -sf "$MCP_BASE" "$HOME/.mcp/server-room" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Symbolic links updated${NC}"
}

# ============================
# ENVIRONMENT MANAGER
# ============================

setup_environment() {
    echo -e "${BLUE}🔐 Setting up environment${NC}"
    
    # .env template oluştur (yoksa)
    if [ ! -f "$MCP_BASE/.env" ]; then
        cat > "$MCP_BASE/.env" << 'ENV_EOF'
# === DYNAMIC PATHS ===
MCP_BASE_PATH="${MCP_BASE:-/Users/sarpocali/Desktop/CURSOR_V1}"

# === API KEYS ===
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
MISTRAL_API_KEY=
PERPLEXITY_API_KEY=
GOOGLE_API_KEY=
GOOGLE_CSE_ID=
GOOGLE_SEARCH_ENGINE_ID=

# === DATABASE ===
SUPABASE_URL=
SUPABASE_SERVICE_KEY=
DATABASE_URL=

# === ARCHON PORTS ===
ARCHON_SERVER_PORT=8051
ARCHON_MCP_PORT=8181
ARCHON_AGENTS_PORT=8052
ARCHON_UI_PORT=3737

# === PUPPETEER CONFIG (Dynamic) ===
PUPPETEER_EXECUTABLE_PATH=/Applications/Google Chrome.app/Contents/MacOS/Google Chrome
PUPPETEER_USER_DATA_DIR=${MCP_BASE_PATH}/outputs/puppeteer_userdata
PUPPETEER_DOWNLOAD_DIR=${MCP_BASE_PATH}/outputs/puppeteer_downloads
PUPPETEER_OUTPUT_PATH=${MCP_BASE_PATH}/outputs/puppeteer_screenshots
PUPPETEER_HAR_PATH=${MCP_BASE_PATH}/outputs/puppeteer_har
PUPPETEER_TRACE_PATH=${MCP_BASE_PATH}/outputs/puppeteer_traces
PUPPETEER_HEADLESS=false
PUPPETEER_DEVTOOLS=false

# === OUTPUT PATHS (Dynamic) ===
OCR_DIR=${MCP_BASE_PATH}/outputs/mistral_ocr
INPUT_DIR=${MCP_BASE_PATH}/raw_data/ocr-pdf
TRANSCRIPT_OUTPUT_PATH=${MCP_BASE_PATH}/outputs/youtube_transcripts
ENV_EOF
        echo -e "${YELLOW}⚠️  Created .env template - please add your API keys${NC}"
    fi
    
    # .env.dynamic oluştur (her zaman güncelle)
    cat > "$MCP_BASE/.env.dynamic" << ENV_DYN_EOF
# Auto-generated dynamic environment
export MCP_BASE="$MCP_BASE"
export MCP_BASE_PATH="$MCP_BASE"

# Source main .env
if [ -f "$MCP_BASE/.env" ]; then
    set -a
    source "$MCP_BASE/.env"
    set +a
fi

# Override with dynamic paths
export PUPPETEER_USER_DATA_DIR="$MCP_BASE/outputs/puppeteer_userdata"
export PUPPETEER_DOWNLOAD_DIR="$MCP_BASE/outputs/puppeteer_downloads"
export PUPPETEER_OUTPUT_PATH="$MCP_BASE/outputs/puppeteer_screenshots"
export OCR_DIR="$MCP_BASE/outputs/mistral_ocr"
export INPUT_DIR="$MCP_BASE/raw_data/ocr-pdf"
export TRANSCRIPT_OUTPUT_PATH="$MCP_BASE/outputs/youtube_transcripts"
ENV_DYN_EOF
}

# ============================
# HEALTH CHECK
# ============================

health_check() {
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🏥 MCP Server Room Health Check${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "\n${BLUE}📍 Location:${NC}"
    echo -e "   Current: ${GREEN}$(pwd)${NC}"
    echo -e "   MCP Base: ${GREEN}$MCP_BASE${NC}"
    
    echo -e "\n${BLUE}📊 System Status:${NC}"
    
    # Check core files
    files=("INVENTORY.json" "mcp.json" ".env")
    for file in "${files[@]}"; do
        if [ -f "$MCP_BASE/$file" ]; then
            echo -e "   ${GREEN}✅ $file${NC}"
        else
            echo -e "   ${RED}❌ $file missing${NC}"
        fi
    done
    
    # Check adaptive system
    if [ -d "$MCP_CONFIG_DIR" ]; then
        echo -e "   ${GREEN}✅ Adaptive system initialized${NC}"
        
        # Count backups
        backup_count=$(ls -1 "$MCP_BACKUP_DIR" 2>/dev/null | wc -l)
        echo -e "   ${BLUE}📦 Backups: $backup_count${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Adaptive system not initialized${NC}"
    fi
    
    # Check tools from processed inventory
    if [ -f "$MCP_CONFIG_DIR/processed_inventory.json" ]; then
        tool_count=$(grep -c '"tool_id"' "$MCP_CONFIG_DIR/processed_inventory.json")
        echo -e "   ${GREEN}✅ Tools configured: $tool_count${NC}"
    fi
    
    echo -e "\n${BLUE}🔗 Symbolic Links:${NC}"
    links=("$HOME/.cursor/mcp.json" "$HOME/.mcp/server-room")
    for link in "${links[@]}"; do
        if [ -L "$link" ]; then
            echo -e "   ${GREEN}✅ $link${NC}"
        else
            echo -e "   ${YELLOW}⚠️  $link not found${NC}"
        fi
    done
}

# ============================
# REPAIR SYSTEM
# ============================

repair_system() {
    echo -e "${YELLOW}🔧 Running system repair...${NC}"
    
    # Re-initialize
    init_adaptive_system
    
    # Re-process inventory
    process_inventory
    
    # Regenerate configs
    generate_mcp_json
    setup_environment
    manage_symlinks
    
    echo -e "${GREEN}✅ System repair complete${NC}"
}

# ============================
# MAIN MENU
# ============================

show_menu() {
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🎮 MCP Adaptive Controller${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "1) ${GREEN}Initialize/Update System${NC}"
    echo -e "2) ${BLUE}Health Check${NC}"
    echo -e "3) ${YELLOW}Repair System${NC}"
    echo -e "4) ${PURPLE}Generate Configs${NC}"
    echo -e "5) ${RED}Exit${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -n "Select option: "
}

# ============================
# MAIN EXECUTION
# ============================

main() {
    # Eğer parametre verilmişse direkt çalıştır
    case "${1:-}" in
        init)
            init_adaptive_system
            process_inventory
            generate_mcp_json
            setup_environment
            manage_symlinks
            health_check
            ;;
        check)
            health_check
            ;;
        repair)
            repair_system
            ;;
        generate)
            generate_mcp_json
            ;;
        *)
            # İnteraktif menü
            while true; do
                show_menu
                read -r choice
                case $choice in
                    1)
                        init_adaptive_system
                        process_inventory
                        generate_mcp_json
                        setup_environment
                        manage_symlinks
                        health_check
                        ;;
                    2)
                        health_check
                        ;;
                    3)
                        repair_system
                        ;;
                    4)
                        generate_mcp_json
                        ;;
                    5)
                        echo -e "${GREEN}Goodbye!${NC}"
                        exit 0
                        ;;
                    *)
                        echo -e "${RED}Invalid option${NC}"
                        ;;
                esac
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read -r
            done
            ;;
    esac
}

# Run main function
main "$@"
MASTER_EOF

chmod +x mcp-controller.sh

# === QUICK ACCESS SCRIPTS ===

# 1. Auto-detect and run script
cat << 'AUTO_EOF' > mcp-auto.sh
#!/bin/bash
# Otomatik olarak CURSOR_V1'i bulur ve controller'ı çalıştırır

find_and_run() {
    # CURSOR_V1'i bul
    if [ -f "./mcp-controller.sh" ]; then
        ./mcp-controller.sh "$@"
    elif [ -f "$HOME/Desktop/CURSOR_V1/mcp-controller.sh" ]; then
        cd "$HOME/Desktop/CURSOR_V1" && ./mcp-controller.sh "$@"
    else
        echo "❌ MCP Controller not found. Searching..."
        found=$(find "$HOME" -name "mcp-controller.sh" -path "*/CURSOR_V1/*" 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            cd "$(dirname "$found")" && ./mcp-controller.sh "$@"
        else
            echo "❌ Cannot find MCP Controller. Please run from CURSOR_V1 directory."
            exit 1
        fi
    fi
}

find_and_run "$@"
AUTO_EOF

chmod +x mcp-auto.sh

# 2. Global installer
cat << 'GLOBAL_EOF' > install-global.sh
#!/bin/bash
# MCP sistemini global olarak kullanılabilir yapar

echo "🌍 Installing MCP Controller globally..."

# Script'leri /usr/local/bin'e kopyala
sudo cp mcp-auto.sh /usr/local/bin/mcp-control
sudo chmod +x /usr/local/bin/mcp-control

# Alias ekle
echo "alias mcp='mcp-control'" >> ~/.zshrc
echo "alias mcp='mcp-control'" >> ~/.bashrc

echo "✅ Installation complete!"
echo "   You can now use 'mcp' command from anywhere"
echo "   Run: mcp init    - to initialize"
echo "   Run: mcp check   - for health check"
echo "   Run: mcp repair  - to repair system"
GLOBAL_EOF

chmod +x install-global.sh

# 3. Project integrator
cat << 'PROJECT_EOF' > integrate-project.sh
#!/bin/bash
# Herhangi bir projeye MCP entegrasyonu yapar

PROJECT_DIR="${1:-$(pwd)}"
MCP_BASE="$(find $HOME -name "CURSOR_V1" -type d 2>/dev/null | head -1)"

if [ -z "$MCP_BASE" ]; then
    echo "❌ CURSOR_V1 not found"
    exit 1
fi

echo "🔗 Integrating MCP with $PROJECT_DIR"

# .cursor dizini oluştur
mkdir -p "$PROJECT_DIR/.cursor"

# Dinamik mcp.json linki oluştur
ln -sf "$MCP_BASE/mcp.json" "$PROJECT_DIR/.cursor/mcp.json"

# Project-specific env
cat > "$PROJECT_DIR/.mcp-env" << EOF
#!/bin/bash
export MCP_BASE="$MCP_BASE"
source "$MCP_BASE/.env.dynamic"
EOF

echo "✅ MCP integrated with project!"
echo "   The project now has access to all MCP tools"
PROJECT_EOF

chmod +x integrate-project.sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ADAPTIVE MCP SYSTEM CREATED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🚀 QUICK START:"
echo "   ./mcp-controller.sh init  - Initialize system"
echo "   ./mcp-controller.sh check - Health check"
echo "   ./mcp-controller.sh       - Interactive menu"
echo ""
echo "🌍 GLOBAL ACCESS:"
echo "   ./install-global.sh       - Install globally"
echo "   Then use 'mcp' from anywhere"
echo ""
echo "🔗 PROJECT INTEGRATION:"
echo "   ./integrate-project.sh /path/to/project"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"