# CURSOR_V1 🚀

Advanced multi-agent system featuring Archon and Serena servers for intelligent task automation and code generation.

## 🏗️ Architecture

This project consists of two main components:

### 🔮 Archon Server
- **Location**: `servers/archon/`
- Multi-agent coordination system
- React-based UI with modern components
- Comprehensive agent management and task orchestration

### 🎯 Serena Server  
- **Location**: `servers/serena/`
- Specialized agent for code generation and analysis
- Language server protocol integration
- Advanced prompt engineering capabilities

## 🚀 Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/sarpocali/CURSOR_V1.git
   cd CURSOR_V1
   ```

2. **Environment Setup**
   ```bash
   cp .env.example .env
   # Edit .env with your API keys
   ```

3. **Install Dependencies**
   ```bash
   npm install
   ```

## 🔧 Configuration

The project requires several API keys for full functionality:

- **OpenAI API**: For GPT models and completions
- **Anthropic API**: For Claude model integration  
- **Google APIs**: For search and other services
- **GitHub Token**: For repository operations
- **Additional APIs**: Perplexity, Mistral, Tavily, etc.

## 📁 Project Structure

```
CURSOR_V1/
├── servers/
│   ├── archon/          # Archon multi-agent system
│   └── serena/          # Serena code generation agent
├── .env.example         # Environment variables template
├── package.json         # Node.js dependencies
└── README.md           # This file
```

## 🔐 Security

- All sensitive API keys are stored in `.env` (not tracked by git)
- Use `.env.example` as a template for required environment variables
- Never commit real API keys to the repository

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

This project is available for educational and development purposes.

---

**Built with ❤️ using modern AI technologies**
