# System Design Features Java

Welcome! This is my personal repository to learn and practice system design concepts and prepare for job interviews. Hope you find something useful!

## 🎵 Spotify Top K Songs Project

A modular Spring Boot application demonstrating real-time top K songs ranking using Kafka, Redis, and Cassandra.

### 🚀 Quick Start

#### First Time Setup
```bash
# Make executable and setup
chmod +x setup.sh
./setup.sh

# Start EVERYTHING
./scripts/start-all.sh
```

#### Daily Development
```bash
# Quick status check
./scripts/status.sh

# Test API endpoints
./scripts/test-api.sh

# Stop everything
./scripts/stop-all.sh

# Start just infrastructure
./scripts/start-infra.sh

# Start just applications
./scripts/start-apps.sh

# View logs
./scripts/logs.sh kafka
./scripts/logs.sh api
```

### 📁 Project Structure

```
spotify-top-k-songs/
├── setup.sh                    # 🔧 Initial setup
├── scripts/
│   ├── start-infra.sh         # 🐳 Docker infrastructure
│   ├── start-apps.sh          # 📱 Spring apps  
│   ├── start-all.sh           # 🎵 Everything together
│   ├── stop-all.sh            # 🛑 Stop everything
│   ├── test-api.sh            # 🧪 Automatic testing
│   ├── status.sh              # 📊 Service status
│   ├── logs.sh                # 🔍 View logs
│   └── init-cassandra.cql     # 📊 Database setup
├── api/                        # REST API module
├── consumer/                   # Kafka consumer module
└── pom.xml                    # Maven parent POM
```

### 🛠️ Scripts Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| `setup.sh` | Initial project setup | `./setup.sh` |
| `start-infra.sh` | Start Docker infrastructure | `./scripts/start-infra.sh` |
| `start-apps.sh` | Start Spring applications | `./scripts/start-apps.sh` |
| `start-all.sh` | Start everything | `./scripts/start-all.sh` |
| `stop-all.sh` | Stop all services | `./scripts/stop-all.sh` |
| `status.sh` | Service status check | `./scripts/status.sh` |
| `logs.sh` | View service logs | `./scripts/logs.sh [service]` |

### 🌐 Service URLs

- **API**: http://localhost:8083
- **Consumer**: http://localhost:8084
- **Kafka UI**: http://localhost:8080
- **PostgreSQL**: localhost:5432

### 📋 Prerequisites

- Docker & Docker Compose
- Java 21+
- Maven 3.6+
- Bash shell

### 🎯 Architecture

- **API Module**: REST endpoints for recording plays and retrieving top songs
- **Consumer Module**: Processes Kafka events and updates rankings
- **Kafka**: Message broker for event streaming
- **Redis**: Caching layer for top K songs
- **Cassandra**: Persistent storage for song events
- **PostgreSQL**: Relational data (optional)

### 🔧 Development Workflow

1. **Start infrastructure**: `./scripts/start-infra.sh`
2. **Develop applications**: Code in `api/` and `consumer/` modules
3. **Run applications**: `./scripts/start-apps.sh`
4. **Test**: `./scripts/test-api.sh`
5. **Monitor**: Use `./scripts/status.sh` and `./scripts/logs.sh`

### 🐳 Docker Services

- **Zookeeper**: Kafka coordination
- **Kafka**: Event streaming platform
- **Redis**: In-memory data store
- **Cassandra**: NoSQL database
- **PostgreSQL**: SQL database
- **Kafka UI**: Web interface for Kafka monitoring

### 📊 Features

- Real-time song play tracking
- Top K songs ranking
- Event-driven architecture
- Modular Spring Boot application
- Automated testing scripts
- Comprehensive monitoring

### 🚀 Next Steps

After running `./setup.sh`, the system will be ready for development. Use the provided scripts to manage the entire stack efficiently.

---