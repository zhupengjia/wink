# Wink Project Instructions

## Project Overview
Wink (微客) is a global social app to meet AI companions and make meaningful connections. The project consists of:
- **Flutter App** (`flutter_app/`) - Cross-platform mobile/web client (iOS, Android, Web)
- **Go Backend** (`backend/`) - API server with Gin framework
- **Supabase** (`supabase/`) - Database and authentication

## Agent Usage

### Flutter Development
**ALWAYS use `flutter-engineer` agent** for any Flutter/Dart tasks:
- UI components and widgets
- State management (flutter_bloc)
- Platform-specific configurations (iOS/Android/Web)
- Navigation and routing
- Supabase Flutter integration
- Media handling (image_picker, video_player, record, just_audio)

### Backend Development
**ALWAYS use `golang-engineer` agent** for any Go backend tasks:
- API endpoints and handlers
- Middleware (auth, CORS, rate limiting)
- Repository pattern with Supabase
- Redis session management
- LLM/AI persona integration
- Database queries and migrations

## Architecture

### Flutter App Structure
```
flutter_app/lib/
├── core/           # Theme, constants, utilities
├── features/       # Feature modules (chat, discovery, profile, square)
│   └── <feature>/
│       ├── data/           # Repositories, data sources
│       ├── domain/         # Entities, use cases
│       └── presentation/   # Pages, widgets, BLoC
└── main.dart
```

### Backend Structure
```
backend/
├── cmd/server/     # Application entry point
├── internal/
│   ├── handler/    # HTTP handlers
│   ├── middleware/ # Auth, CORS, rate limiting
│   ├── persona/    # AI persona service
│   ├── repository/ # Data access layer
│   └── session/    # Redis session management
└── pkg/
    └── supabase/   # Supabase client wrapper
```

## Tech Stack

### Flutter
- State Management: `flutter_bloc`
- Networking: `dio`, `supabase_flutter`
- Storage: `hive`, `shared_preferences`
- Media: `image_picker`, `video_player`, `record`, `just_audio`
- Localization: `flutter_localizations`, `intl`

### Backend
- Framework: `gin-gonic/gin`
- Database: `supabase-community/supabase-go`
- Cache: `redis/go-redis/v9`
- LLM: `nlpodyssey/openai-agents-go`
- Auth: Supabase JWT with HMAC validation

## Development Commands

### Root Level
```bash
make dev            # Start all services
make supabase       # Start Supabase locally
make backend        # Run backend server
make flutter        # Run Flutter web
```

### Backend
```bash
cd backend
make build          # Build binary
make run            # Run server
make dev            # Hot reload with air
make test           # Run tests
make docker-build   # Build Docker image
```

### Flutter
```bash
cd flutter_app
make deps           # Install dependencies
make run-android    # Run on Android
make run-ios        # Run on iOS
make run-web        # Run on web
make build-android  # Build Android APK
make build-ios      # Build iOS app
make build-web      # Build web app
```

## Code Conventions

### Flutter/Dart
- Use BLoC pattern for state management
- Follow feature-first folder structure
- Use `equatable` for state/event classes
- Prefer `const` constructors
- Use named parameters for widgets with 3+ parameters

### Go
- Follow standard Go project layout
- Use dependency injection via constructors
- Handle all errors explicitly
- Use context for cancellation and timeouts
- Prefix interfaces with their primary method (e.g., `Reader`, `Writer`)

## Environment Variables

### Backend (.env)
```
PORT=8080
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_KEY=xxx
REDIS_ADDR=localhost:6379
LLM_ENDPOINT=https://api.x.ai/v1
LLM_API_KEY=xxx
LLM_MODEL=grok-beta
JWT_SECRET=xxx
```

### Flutter (.env)
```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=xxx
API_BASE_URL=http://localhost:8080
```

## API Endpoints

### Chat
- `POST /api/chat/send` - Send message
- `POST /api/chat/send/stream` - Send message with streaming response

### Personas
- `GET /api/personas` - List all personas
- `GET /api/personas/:id` - Get persona details

### Conversations
- `POST /api/conversations` - Create conversation
- `GET /api/conversations/:id/messages` - Get messages

### Intimacy
- `GET /api/intimacy/:personaId` - Get intimacy level

## Important Notes

1. **No Mock Data** - Never use mock/placeholder data as fallbacks. Show proper error states with retry options.

2. **Error Handling** - All pages must have proper error states with:
   - Error icon
   - User-friendly error message
   - Retry button

3. **Authentication** - All API routes under `/api` require Supabase JWT authentication.

4. **Deep Linking** - App supports `wink://` URL scheme on all platforms.

5. **Permissions** - Mobile apps request camera, microphone, and photo library permissions.
