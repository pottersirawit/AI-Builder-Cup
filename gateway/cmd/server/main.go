package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/saransirichote/weather-resilience-gateway/internal/api"
	"github.com/saransirichote/weather-resilience-gateway/internal/config"
	"github.com/saransirichote/weather-resilience-gateway/internal/dispatcher"
)

func main() {
	cfg := config.LoadConfig()

	log.Println("==================================================")
	log.Println("Bangkok Weather Resilience - Go API Gateway & Dispatcher")
	log.Println("==================================================")

	// Initialize Goroutine Worker Pool
	pool := dispatcher.NewWorkerPool(cfg, 5000)
	pool.Start()

	// Initialize API Server
	server := api.NewServer(cfg, pool)
	mux := http.NewServeMux()
	server.RegisterRoutes(mux)

	httpServer := &http.Server{
		Addr:    ":" + cfg.Port,
		Handler: mux,
	}

	// Handle graceful shutdown
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("[Main] Gateway HTTP server listening on port %s", cfg.Port)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[Main] Server error: %v", err)
		}
	}()

	<-stop
	log.Println("[Main] Shutting down gracefully...")

	// 1. Shutdown HTTP server first to stop accepting new requests and drain in-flight requests
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		log.Printf("[Main] HTTP server shutdown error: %v", err)
	} else {
		log.Println("[Main] HTTP server stopped successfully")
	}

	// 2. Stop worker pool after HTTP server has completely stopped
	pool.Stop()
	log.Println("[Main] Worker pool stopped cleanly")
}
