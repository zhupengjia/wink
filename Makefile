.PHONY: all help dev backend flutter supabase clean

all: help

help:
	@echo "Wink Project Makefile"
	@echo ""
	@echo "Development:"
	@echo "  make dev           Start all services (Supabase, Backend, Flutter web)"
	@echo "  make supabase      Start Supabase local development"
	@echo "  make supabase-down Stop Supabase services"
	@echo "  make backend       Run backend server"
	@echo "  make flutter       Run Flutter web app"
	@echo ""
	@echo "Build:"
	@echo "  make build-backend Build backend Docker image"
	@echo "  make build-flutter Build Flutter for all platforms"
	@echo ""
	@echo "Subproject commands:"
	@echo "  make -C backend <target>     Run backend Makefile target"
	@echo "  make -C flutter_app <target> Run Flutter Makefile target"

# Development
dev: supabase
	@echo "Starting backend and flutter..."
	@$(MAKE) -C backend dev &
	@$(MAKE) -C flutter_app run-web

supabase:
	@echo "Starting Supabase local development..."
	cd supabase && docker-compose up -d

supabase-down:
	@echo "Stopping Supabase services..."
	cd supabase && docker-compose down

supabase-logs:
	@echo "Showing Supabase logs..."
	cd supabase && docker-compose logs -f

backend:
	@echo "Starting backend..."
	$(MAKE) -C backend run

flutter:
	@echo "Starting Flutter web..."
	$(MAKE) -C flutter_app run-web

# Build
build-backend:
	@echo "Building backend Docker image..."
	$(MAKE) -C backend docker-build

build-flutter:
	@echo "Building Flutter for all platforms..."
	$(MAKE) -C flutter_app build-android
	$(MAKE) -C flutter_app build-ios
	$(MAKE) -C flutter_app build-web

# Clean
clean:
	@echo "Cleaning all build artifacts..."
	$(MAKE) -C backend clean
	$(MAKE) -C flutter_app clean

# Install dependencies
deps:
	@echo "Installing all dependencies..."
	$(MAKE) -C backend deps
	$(MAKE) -C flutter_app deps
