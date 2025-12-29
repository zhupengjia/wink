# Wink (微客)

A global social app to meet AI companions and make meaningful connections.

> Every wink sparks a connection | 每一次眨眼，都是新的邂逅

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter App                          │
│                   (iOS / Android / Web)                     │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                      Supabase (Kong)                        │
│                       API Gateway                           │
└────────────────────────────┬────────────────────────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────────┐
│  Go Backend     │ │   Supabase      │ │  Supabase Services  │
│  (Chat/AI)      │ │   Auth          │ │  (Storage/Realtime) │
└────────┬────────┘ └────────┬────────┘ └──────────┬──────────┘
         │                   │                     │
         └───────────────────┴─────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   PostgreSQL    │
                    └─────────────────┘
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Frontend | Flutter (Dart) |
| Backend | Go 1.22+ |
| Database | PostgreSQL (Supabase) |
| Auth | Supabase Auth |
| Storage | Supabase Storage |
| Realtime | Supabase Realtime |
| State Management | flutter_bloc |
| API Gateway | Kong |

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) & Docker Compose
- [Flutter](https://flutter.dev/docs/get-started/install) 3.2+
- [Go](https://golang.org/dl/) 1.22+
- Make

## Quick Start

### 1. Clone and Setup Environment

```bash
git clone <repository-url>
cd wink

# Copy environment files
cp .env.example .env
cp backend/.env.example backend/.env
cp supabase/.env.example supabase/.env
```

### 2. Start Supabase (Local Development)

```bash
cd supabase
docker compose up -d
```

Supabase services will be available at:
- **Studio**: http://localhost:3000 (Dashboard)
- **API**: http://localhost:8000 (Kong Gateway)
- **Database**: localhost:5432

### 3. Start Backend

```bash
cd backend
make dev  # Hot-reload with Air
```

Backend API will be available at http://localhost:8080

### 4. Run Flutter App

```bash
cd flutter_app

# Web
make run-web

# iOS (requires macOS)
make run-ios

# Android
make run-android
```

## Project Structure

```
wink/
├── backend/                 # Go backend service
│   ├── cmd/                 # Application entrypoints
│   ├── internal/            # Private application code
│   │   ├── api/             # HTTP handlers
│   │   ├── models/          # Data models
│   │   └── services/        # Business logic
│   ├── pkg/                 # Public libraries
│   ├── Dockerfile
│   └── Makefile
│
├── flutter_app/             # Flutter mobile/web app
│   ├── lib/
│   │   ├── l10n/            # Localization (en/zh)
│   │   ├── models/          # Data models
│   │   ├── screens/         # UI screens
│   │   ├── widgets/         # Reusable widgets
│   │   └── blocs/           # BLoC state management
│   ├── android/
│   ├── ios/
│   ├── web/
│   └── Makefile
│
├── supabase/                # Supabase self-hosted config
│   ├── docker-compose.yml   # Local Supabase stack
│   ├── migrations/          # Database migrations
│   ├── seed.sql             # Seed data
│   └── volumes/             # Service configs
│       ├── api/kong.yml     # API Gateway routes
│       ├── db/*.sql         # Init scripts
│       └── logs/vector.yml  # Log aggregation
│
├── Makefile                 # Root project commands
├── CLAUDE.md                # AI assistant instructions
└── README.md
```

## Makefile Commands

### Root Level

```bash
make dev          # Start all services (supabase + backend + flutter web)
make supabase     # Start Supabase stack
make supabase-down # Stop Supabase stack
make backend      # Start backend with hot-reload
make flutter      # Run Flutter web app
make clean        # Stop all services
```

### Backend

```bash
cd backend
make build        # Build binary
make run          # Run directly
make dev          # Hot-reload with Air
make test         # Run tests
make lint         # Run linter
make docker-build # Build Docker image
make docker-run   # Run in Docker
```

### Flutter App

```bash
cd flutter_app
make run-web      # Run on Chrome
make run-ios      # Run on iOS simulator
make run-android  # Run on Android emulator
make build-apk    # Build Android APK
make build-ios    # Build iOS app
make build-web    # Build for web deployment
make test         # Run tests
make lint         # Analyze code
make clean        # Clean build artifacts
```

## Environment Variables

### Root `.env`

```env
SUPABASE_URL=http://localhost:8000
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### Backend `.env`

```env
PORT=8080
SUPABASE_URL=http://localhost:8000
SUPABASE_KEY=your-service-role-key
DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres
OPENAI_API_KEY=your-openai-key
```

### Supabase `.env`

See `supabase/.env.example` for complete list of required variables including:
- JWT secrets
- Database credentials
- API keys for all services
- SMTP configuration (optional)

## Features

- AI Companion Chat with intimacy system
- Real-time messaging
- Multi-language support (English / 中文)
- Cross-platform (iOS, Android, Web)
- OAuth authentication (Google, Apple, Email)
- Media sharing (Photos, Videos, Voice)

## Development

### Adding a New Localization String

1. Add to `flutter_app/lib/l10n/app_en.arb`:
   ```json
   "newKey": "English text",
   "@newKey": { "description": "Description" }
   ```

2. Add to `flutter_app/lib/l10n/app_zh.arb`:
   ```json
   "newKey": "中文文本"
   ```

3. Run `flutter gen-l10n` or rebuild the app

### Database Migrations

Place SQL files in `supabase/migrations/` with timestamp prefix:
```
supabase/migrations/20241229000000_create_users.sql
```

## License

Private - All rights reserved.
