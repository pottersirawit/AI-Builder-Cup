package config

import (
	"os"
	"strconv"
)

type Config struct {
	Port                string
	LineChannelSecret   string
	LineChannelToken    string
	EngineBaseURL       string
	LIFFEndpointURL     string
	LiffEndpointURL     string // alias for case compatibility
	WorkerPoolSize      int
	DispatchRatePerSec  int
}

func LoadConfig() *Config {
	port := os.Getenv("GATEWAY_PORT")
	if port == "" {
		port = "8080"
	}

	engineURL := os.Getenv("ENGINE_BASE_URL")
	if engineURL == "" {
		engineURL = "http://localhost:8000"
	}

	liffURL := os.Getenv("LIFF_ENDPOINT_URL")
	if liffURL == "" {
		liffURL = "https://liff.line.me/placeholder"
	}

	poolSize := 20
	if val := os.Getenv("WORKER_POOL_SIZE"); val != "" {
		if p, err := strconv.Atoi(val); err == nil {
			poolSize = p
		}
	}

	return &Config{
		Port:               port,
		LineChannelSecret:  os.Getenv("LINE_CHANNEL_SECRET"),
		LineChannelToken:   os.Getenv("LINE_CHANNEL_ACCESS_TOKEN"),
		EngineBaseURL:      engineURL,
		LIFFEndpointURL:    liffURL,
		LiffEndpointURL:    liffURL,
		WorkerPoolSize:     poolSize,
		DispatchRatePerSec: 50,
	}
}
