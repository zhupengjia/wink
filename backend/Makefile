.PHONY: all build run test clean docker docker-build docker-run lint fmt deps tidy help dev

BINARY_NAME=wink-server
DOCKER_IMAGE=wink-backend
DOCKER_TAG=latest
GO=go

all: build

help:
	@echo "Wink Backend Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make build        Build the server binary"
	@echo "  make run          Run the server locally"
	@echo "  make dev          Run with hot reload (requires air)"
	@echo "  make test         Run tests"
	@echo "  make test-cover   Run tests with coverage"
	@echo "  make lint         Run linter (requires golangci-lint)"
	@echo "  make fmt          Format code"
	@echo "  make deps         Download dependencies"
	@echo "  make tidy         Tidy go modules"
	@echo "  make clean        Remove build artifacts"
	@echo "  make docker-build Build Docker image"
	@echo "  make docker-run   Run Docker container"
	@echo "  make docker       Build and run Docker"

build:
	@echo "Building $(BINARY_NAME)..."
	$(GO) build -o bin/$(BINARY_NAME) ./cmd/server

run: build
	@echo "Running $(BINARY_NAME)..."
	./bin/$(BINARY_NAME)

dev:
	@echo "Starting development server with hot reload..."
	@if command -v air > /dev/null; then \
		air; \
	else \
		echo "air not installed. Install with: go install github.com/cosmtrek/air@latest"; \
		echo "Falling back to regular run..."; \
		$(MAKE) run; \
	fi

test:
	@echo "Running tests..."
	$(GO) test -v ./...

test-cover:
	@echo "Running tests with coverage..."
	$(GO) test -v -coverprofile=coverage.out ./...
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

lint:
	@echo "Running linter..."
	@if command -v golangci-lint > /dev/null; then \
		golangci-lint run ./...; \
	else \
		echo "golangci-lint not installed. Install from https://golangci-lint.run/"; \
		exit 1; \
	fi

fmt:
	@echo "Formatting code..."
	$(GO) fmt ./...
	@if command -v goimports > /dev/null; then \
		goimports -w .; \
	fi

deps:
	@echo "Downloading dependencies..."
	$(GO) mod download

tidy:
	@echo "Tidying modules..."
	$(GO) mod tidy

clean:
	@echo "Cleaning..."
	rm -rf bin/
	rm -f coverage.out coverage.html

docker-build:
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

docker-run:
	@echo "Running Docker container..."
	docker run --rm -p 8080:8080 --env-file .env $(DOCKER_IMAGE):$(DOCKER_TAG)

docker: docker-build docker-run

docker-push:
	@echo "Pushing Docker image..."
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)
