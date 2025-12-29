package middleware

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// SupabaseAuthMiddleware validates Supabase JWT tokens
func SupabaseAuthMiddleware() gin.HandlerFunc {
	jwtSecret := os.Getenv("SUPABASE_JWT_SECRET")
	if jwtSecret == "" {
		// Fallback to service key for development
		jwtSecret = os.Getenv("JWT_SECRET")
	}

	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			c.Abort()
			return
		}

		// Extract token from "Bearer <token>"
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization format"})
			c.Abort()
			return
		}

		tokenString := parts[1]

		// Parse and validate the token
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			// Validate signing method
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return []byte(jwtSecret), nil
		})

		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token: " + err.Error()})
			c.Abort()
			return
		}

		if !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Token is not valid"})
			c.Abort()
			return
		}

		// Extract claims
		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
			c.Abort()
			return
		}

		// Extract user ID from sub claim
		userID, ok := claims["sub"].(string)
		if !ok || userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User ID not found in token"})
			c.Abort()
			return
		}

		// Store user info in context
		c.Set("user_id", userID)

		// Extract email if available
		if email, ok := claims["email"].(string); ok {
			c.Set("user_email", email)
		}

		// Extract role if available
		if role, ok := claims["role"].(string); ok {
			c.Set("user_role", role)
		}

		c.Next()
	}
}

// DevAuthMiddleware is a development-only middleware that accepts any request
func DevAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// In development, accept X-User-ID header or use default
		userID := c.GetHeader("X-User-ID")
		if userID == "" {
			userID = "dev-user-123"
		}

		c.Set("user_id", userID)
		c.Next()
	}
}

// RequireAuth returns the appropriate middleware based on environment
func RequireAuth() gin.HandlerFunc {
	env := os.Getenv("GIN_MODE")
	if env == "release" {
		return SupabaseAuthMiddleware()
	}
	return DevAuthMiddleware()
}

// GetUserID extracts the user ID from the Gin context
func GetUserID(c *gin.Context) string {
	userID, exists := c.Get("user_id")
	if !exists {
		return ""
	}
	return userID.(string)
}

// GetUserEmail extracts the user email from the Gin context
func GetUserEmail(c *gin.Context) string {
	email, exists := c.Get("user_email")
	if !exists {
		return ""
	}
	return email.(string)
}

// CORSMiddleware handles CORS headers
func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if origin == "" {
			origin = "*"
		}

		c.Header("Access-Control-Allow-Origin", origin)
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization, X-User-ID")
		c.Header("Access-Control-Allow-Credentials", "true")
		c.Header("Access-Control-Max-Age", "86400")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

// RateLimitMiddleware implements Redis-based rate limiting
func RateLimitMiddleware(redisSession RateLimiter, requestsPerMinute int) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := GetUserID(c)
		if userID == "" {
			// Use IP as fallback for unauthenticated requests
			userID = "ip:" + c.ClientIP()
		}

		ctx := c.Request.Context()
		allowed, remaining, resetTime, err := redisSession.CheckRateLimit(ctx, userID, requestsPerMinute, 60)
		if err != nil {
			// On error, allow request but log
			c.Next()
			return
		}

		// Set rate limit headers
		c.Header("X-RateLimit-Limit", fmt.Sprintf("%d", requestsPerMinute))
		c.Header("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
		c.Header("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))

		if !allowed {
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error":       "Rate limit exceeded",
				"retry_after": resetTime.Unix() - time.Now().Unix(),
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// RateLimiter interface for rate limiting operations
type RateLimiter interface {
	CheckRateLimit(ctx context.Context, userID string, limit int, windowSeconds int) (bool, int, time.Time, error)
}
