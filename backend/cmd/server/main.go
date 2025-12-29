package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/wink/backend/internal/handler"
	"github.com/wink/backend/internal/middleware"
	"github.com/wink/backend/internal/persona"
	"github.com/wink/backend/internal/repository"
	"github.com/wink/backend/internal/session"
	"github.com/wink/backend/pkg/supabase"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	// Initialize Redis session manager
	redisSession := session.NewRedisSession(session.RedisConfig{
		Addr:     getEnv("REDIS_ADDR", "localhost:6379"),
		Password: getEnv("REDIS_PASSWORD", ""),
		DB:       0,
		TTL:      24 * time.Hour,
	})

	// Ping Redis to verify connection
	ctx := context.Background()
	if err := redisSession.Ping(ctx); err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}
	log.Println("Connected to Redis")

	// Initialize persona service
	personaConfig := &persona.Config{
		LLMModel:    getEnv("LLM_MODEL", "grok-beta"),
		LLMEndpoint: getEnv("LLM_ENDPOINT", "https://api.x.ai/v1"),
		LLMAPIKey:   getEnv("LLM_API_KEY", ""),
	}

	// Initialize Supabase client
	supabaseClient := supabase.NewClient()
	log.Println("Initialized Supabase client")

	// Initialize repository with Supabase
	repo := repository.NewSupabaseRepository(supabaseClient)

	intimacyService := persona.NewIntimacyService(repo)
	personaService := persona.NewPersonaService(repo, redisSession, intimacyService, personaConfig)

	// Initialize handlers
	chatHandler := handler.NewChatHandler(personaService, redisSession, repo)

	// Setup Gin router
	router := gin.Default()

	// Global middleware
	router.Use(middleware.CORSMiddleware())

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// API routes
	api := router.Group("/api")
	{
		// Auth middleware
		api.Use(middleware.RequireAuth())

		// Chat endpoints
		chat := api.Group("/chat")
		{
			chat.POST("/send", chatHandler.SendMessage)
			chat.POST("/send/stream", chatHandler.SendMessageStream)
		}

		// Persona endpoints
		personas := api.Group("/personas")
		{
			personas.GET("", handler.ListPersonas(repo))
			personas.GET("/:id", handler.GetPersona(repo))
		}

		// Intimacy endpoints
		intimacy := api.Group("/intimacy")
		{
			intimacy.GET("/:personaId", handler.GetIntimacy(intimacyService))
		}

		// Conversation endpoints
		conversations := api.Group("/conversations")
		{
			conversations.POST("", handler.CreateConversation(repo))
			conversations.GET("/:id/messages", handler.GetMessages(repo))
		}
	}

	// Start server
	port := getEnv("PORT", "8080")
	srv := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	// Graceful shutdown
	go func() {
		log.Printf("Starting server on port %s", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	redisSession.Close()
	log.Println("Server exited")
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
