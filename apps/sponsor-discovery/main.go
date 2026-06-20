package main

import (
	"crypto/subtle"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

// Implements: HHT-OPS-sponsor-discovery/A+B+C — resolve a linking-code prefix to
// a portal hostname, verifying the 2 check chars offline; uniform negative;
// rate-limited; reads its map+keys from the environment (Doppler in cloud,
// compose locally), never the sponsor VPC.

type resolver struct {
	hosts   map[string]string // prefix -> portal url
	keys    map[string]string // prefix -> hmac key
	limiter *rateLimiter
}

const negativeBody = `{"error":"invalid"}`

func (r *resolver) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")
	if req.URL.Path != "/v1/resolve" {
		http.NotFound(w, req)
		return
	}
	if !r.limiter.allow(clientIP(req)) {
		http.Error(w, `{"error":"rate_limited"}`, http.StatusTooManyRequests)
		return
	}
	code := strings.ToUpper(strings.TrimSpace(req.URL.Query().Get("code")))
	if !r.verify(code) {
		// uniform negative for unknown prefix AND bad check
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(negativeBody))
		return
	}
	host := r.hosts[code[:2]]
	_ = json.NewEncoder(w).Encode(map[string]string{"portal": host})
}

func (r *resolver) verify(code string) bool {
	if len(code) != 10 {
		return false
	}
	prefix := code[:2]
	key, ok := r.keys[prefix]
	if !ok {
		return false
	}
	want := checkCharsFor(code[:8], key)
	return subtle.ConstantTimeCompare([]byte(want), []byte(code[8:])) == 1
}

func clientIP(req *http.Request) string {
	if xff := req.Header.Get("X-Forwarded-For"); xff != "" {
		return strings.TrimSpace(strings.Split(xff, ",")[0])
	}
	host, _, _ := strings.Cut(req.RemoteAddr, ":")
	return host
}

// rateLimiter: simple fixed-window per-IP counter (the ~784 speed-bump).
type rateLimiter struct {
	mu     sync.Mutex
	perMin int
	counts map[string]int
	window time.Time
}

func newRateLimiter(perMin int) *rateLimiter {
	return &rateLimiter{perMin: perMin, counts: map[string]int{}}
}

func (l *rateLimiter) allow(ip string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := time.Now().Truncate(time.Minute)
	if now.After(l.window) {
		l.window = now
		l.counts = map[string]int{}
	}
	l.counts[ip]++
	return l.counts[ip] <= l.perMin
}

func loadResolver() *resolver {
	hosts := map[string]string{}
	if raw := os.Getenv("DISCOVERY_MAP"); raw != "" {
		if err := json.Unmarshal([]byte(raw), &hosts); err != nil {
			log.Fatalf("DISCOVERY_MAP invalid JSON: %v", err)
		}
	}
	keys := map[string]string{}
	for prefix := range hosts {
		k := os.Getenv("DISCOVERY_KEY_" + prefix)
		if k == "" {
			log.Fatalf("missing DISCOVERY_KEY_%s", prefix)
		}
		keys[prefix] = k
	}
	return &resolver{hosts: hosts, keys: keys, limiter: newRateLimiter(30)}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8086"
	}
	log.Printf("sponsor-discovery listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, loadResolver()))
}
