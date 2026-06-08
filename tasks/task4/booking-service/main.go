package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	enableFeatureX := os.Getenv("ENABLE_FEATURE_X") == "true"

	http.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		fmt.Fprint(w, "pong")
	})

	http.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		fmt.Fprint(w, "ready")
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
		fmt.Fprint(w, "Feature X is enabled")
	})

	log.Printf("booking-service starting on :8080; ENABLE_FEATURE_X=%t", enableFeatureX)
	log.Fatal(http.ListenAndServe(":8080", nil))
}
