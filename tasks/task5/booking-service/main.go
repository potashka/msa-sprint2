package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	version := os.Getenv("SERVICE_VERSION")
	if version == "" {
		version = "v1"
	}
	enableFeatureX := os.Getenv("ENABLE_FEATURE_X") == "true"

	http.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		fmt.Fprintf(w, "pong from %s", version)
	})

	http.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		fmt.Fprintf(w, "ready from %s", version)
	})

	http.HandleFunc("/feature", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if !enableFeatureX {
			http.Error(w, "feature disabled", http.StatusNotFound)
			return
		}
		fmt.Fprintf(w, "Feature X is enabled on %s", version)
	})

	log.Printf("booking-service starting on :8080; SERVICE_VERSION=%s; ENABLE_FEATURE_X=%t", version, enableFeatureX)
	log.Fatal(http.ListenAndServe(":8080", nil))
}
