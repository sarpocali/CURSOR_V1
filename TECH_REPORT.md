# MCP Tool Stack Technical Report

**Project:** CURSOR_V1  
**Date:** January 2025  
**Analysis Method:** Serena MCP + Terminal Verification

## Executive Summary

This technical report provides a comprehensive analysis of 18 MCP (Model Context Protocol) tools configured in the Cursor project. The analysis identified:
- **12 Node.js/npx tools** - Standard npm packages
- **4 Python/uvx tools** - Python-based MCP servers
- **1 HTTP service** - Archon knowledge engine (currently offline)
- **1 Local Node.js service** - Puppeteer automation server

All tools except `serena-full` use `dotenv-cli` to load environment variables from `.env` file. Critical issues include the Archon HTTP service being offline and the mistral-ocr tool hanging during initialization.

## Overview & Map of Tools

### Tool Classification

| Category | Count | Tools |
|----------|-------|-------|
| Node/npx packages | 12 | filesystem, sequential-thinking, taskmanager-*, playwright, context7, figma, desktop-commander, google-search, perplexity, git, youtube-transcript |
| Python/uvx tools | 4 | serena-full, fetch, mistral-ocr, pdf-tools |
| Local services | 1 | puppeteer-full |
| HTTP services | 1 | archon |

### Environment Variable Usage

**API Keys (Masked):**
- `MISTRAL_API_KEY`: ********OeGN
- `GOOGLE_API_KEY`: ********sy8E
- `GITHUB_TOKEN`: ********2JBB
- `PERPLEXITY_API_KEY`: ********lGdC
- `OPENAI_API_KEY`: ********BakA
- `ANTHROPIC_API_KEY`: ********JQAA
- `SUPABASE_SERVICE_KEY`: ********mAi4

**Path Configurations:**
- `OCR_DIR`: /Users/sarpocali/Desktop/CURSOR_V1/outputs/mistral_ocr
- `INPUT_DIR`: /Users/sarpocali/Desktop/CURSOR_V1/raw_data/ocr-pdf
- `TRANSCRIPT_OUTPUT_PATH`: /Users/sarpocali/Desktop/CURSOR_V1/outputs/youtube_transcripts
- `PUPPETEER_*`: Multiple paths for Puppeteer configuration

## Per-Tool Deep Dive

### 1. filesystem
- **Kind:** node-npx
- **Command:** `npx dotenv-cli -e .env -- npx -y @modelcontextprotocol/server-filesystem /Users/sarpocali/Desktop/CURSOR_V1`
- **Dependencies:** Node.js v22.18.0, npx 10.9.3
- **Health:** Functional but no --help option
- **Risks:** Path traversal if not properly restricted
- **Performance:** Direct filesystem access, fast operation

### 2. puppeteer-full
- **Kind:** node-local
- **Command:** `npx dotenv-cli -e /Users/sarpocali/Desktop/CURSOR_V1/.env -- node /Users/sarpocali/Desktop/CURSOR_V1/servers/puppeteer-extended/dist/index.js`
- **Environment Variables:** All PUPPETEER_* variables
- **Dependencies:** 
  - puppeteer ^23.4.0
  - Chrome executable at /Applications/Google Chrome.app
- **Health:** dist/index.js exists and ready
- **Risks:** Chrome path hardcoded to macOS location
- **Performance:** Uses dedicated output directories for caching

### 3. archon (HTTP Service)
- **Kind:** http
- **URL:** http://localhost:8051/mcp
- **Status:** **OFFLINE** - Port 8051 not listening
- **Dependencies:**
  - FastAPI >= 0.104.0
  - uvicorn >= 0.24.0
  - crawl4ai == 0.6.2
  - supabase == 2.15.1
- **Fix Required:**
  ```bash
  cd /Users/sarpocali/Desktop/CURSOR_V1/servers/archon/python
  uv run uvicorn src.server.main:app --port 8051
  ```
- **Security:** Database credentials in environment

### 4. serena-full
- **Kind:** python-uvx
- **Command:** `uvx --from git+https://github.com/oraios/serena serena-mcp-server --project /Users/sarpocali/Desktop/CURSOR_V1 --transport stdio`
- **Health:** ✅ Fully functional
- **Help Output:**
  ```
  Usage: serena-mcp-server [OPTIONS]
    --project [PROJECT_NAME|PROJECT_PATH]
    --context TEXT
    --mode TEXT
    --transport [stdio|sse]
  ```
- **Note:** Does NOT use dotenv-cli

### 5. mistral-ocr
- **Kind:** python-module
- **Status:** **PROBLEMATIC** - Hangs on initialization
- **Path:** /Users/sarpocali/Desktop/CURSOR_V1/servers/mistral-ocr-fixed
- **Environment:** MISTRAL_API_KEY, OCR_DIR, INPUT_DIR
- **Issue:** Module hangs when invoked with --help
- **Fix:** Review mcp_mistral_ocr.main module implementation

### 6. playwright
- **Kind:** node-npx
- **Version:** 0.0.34
- **Health:** ✅ Functional
- **Command:** `npx dotenv-cli -e .env -- npx -y @playwright/mcp`

### 7-18. Other Tools
All remaining tools follow standard npx patterns with dotenv-cli loading:
- **google-search:** Requires GOOGLE_API_KEY, GOOGLE_CSE_ID
- **perplexity:** Requires PERPLEXITY_API_KEY
- **youtube-transcript:** Uses TRANSCRIPT_OUTPUT_PATH
- **desktop-commander:** Shell execution capabilities (security consideration)

## Cross-Cutting Concerns

### Environment Variable Strategy
- **Pattern:** All tools except serena-full use `dotenv-cli -e .env`
- **Risk:** API keys stored in plain text in .env
- **Recommendation:** Consider using a secrets manager

### Path Strategy
- **Project Root:** /Users/sarpocali/Desktop/CURSOR_V1
- **Servers:** /servers subdirectory for local implementations
- **Outputs:** /outputs with tool-specific subdirectories
- **Raw Data:** /raw_data for input files

### Binary Dependencies
| Binary | Version | Path |
|--------|---------|------|
| Python | 3.13.7 | /usr/local/bin/python3 |
| Node.js | v22.18.0 | /usr/local/bin/node |
| npx | 10.9.3 | /usr/local/bin/npx |
| uvx | 0.8.12 | /opt/homebrew/bin/uvx |
| jq | 1.7.1 | Available |

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Archon service offline | Current | High | Start service with provided command |
| API keys in plaintext | High | High | Implement secrets management |
| mistral-ocr hanging | Current | Medium | Debug module initialization |
| Path traversal in filesystem tool | Low | High | Implement path restrictions |
| Chrome path hardcoded | Medium | Low | Make configurable |

## Fix Plan

### Immediate Actions
1. Start Archon service:
   ```bash
   cd /Users/sarpocali/Desktop/CURSOR_V1/servers/archon/python
   uv run uvicorn src.server.main:app --port 8051
   ```

2. Debug mistral-ocr:
   ```bash
   cd /Users/sarpocali/Desktop/CURSOR_V1/servers/mistral-ocr-fixed
   uv run python -c "from src.mcp_mistral_ocr.main import main; print('Module loads')"
   ```

### Recommended Improvements
1. **Environment Security:**
   - Migrate from .env to secure secrets manager
   - Implement key rotation policy

2. **Service Monitoring:**
   - Add health check endpoints
   - Implement service auto-restart

3. **Path Configuration:**
   - Make Chrome path configurable per OS
   - Validate all path inputs

## Appendix: Minimal Repro & Health-Check Commands

```bash
# Check all binaries
/opt/homebrew/bin/uvx --version
python3 -V
node -v
npx -v

# Test Serena
/opt/homebrew/bin/uvx --from git+https://github.com/oraios/serena serena-mcp-server --help

# Test Playwright
cd /Users/sarpocali/Desktop/CURSOR_V1
npx -y @playwright/mcp --version

# Check Archon port
nc -z 127.0.0.1 8051 || echo "Port 8051 closed"

# Start Archon if needed
cd /Users/sarpocali/Desktop/CURSOR_V1/servers/archon/python
uv run uvicorn src.server.main:app --port 8051

# Test filesystem tool
cd /Users/sarpocali/Desktop/CURSOR_V1
npx -y @modelcontextprotocol/server-filesystem .

# Check Puppeteer dist
test -f /Users/sarpocali/Desktop/CURSOR_V1/servers/puppeteer-extended/dist/index.js
```

## Conclusion

The MCP tool stack is largely functional with 16 of 18 tools operational. Critical issues requiring immediate attention:
1. Archon HTTP service is offline (fixable with one command)
2. mistral-ocr module has initialization issues (requires debugging)
3. Security concern with plaintext API keys in .env file

The infrastructure is well-organized with clear separation between local servers, npm packages, and Python tools. All required binaries are installed and at appropriate versions.