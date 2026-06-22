package main

import (
	"crypto/subtle"
	"encoding/json"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

// Implements: HHT-OPS-portal-resolver/A+B+C — resolve a linking-code prefix to
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
		// Write JSON directly — http.NotFound would clobber the Content-Type to
		// text/plain, breaking JSON-decoding callers.
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(`{"error":"not_found"}`))
		return
	}
	if !r.limiter.allow(clientIP(req)) {
		// Write JSON directly — http.Error would clobber the Content-Type to
		// text/plain even though the body is JSON.
		w.WriteHeader(http.StatusTooManyRequests)
		_, _ = w.Write([]byte(`{"error":"rate_limited"}`))
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
	key, ok := r.keys[code[:2]]
	if !ok {
		key = "\x00" // constant fallback: unknown prefix still costs one HMAC (uniform timing)
	}
	want := checkCharsFor(code[:8], key)
	match := subtle.ConstantTimeCompare([]byte(want), []byte(code[8:])) == 1
	return ok && match
}

func clientIP(req *http.Request) string {
	if xff := req.Header.Get("X-Forwarded-For"); xff != "" {
		return strings.TrimSpace(strings.Split(xff, ",")[0])
	}
	// net.SplitHostPort handles both "host:port" and bracketed IPv6
	// "[2001:db8::1]:1234"; a bare strings split would truncate IPv6 to "[2001"
	// and collapse many clients into one rate-limit bucket.
	host, _, err := net.SplitHostPort(req.RemoteAddr)
	if err != nil {
		return req.RemoteAddr
	}
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
	if raw := os.Getenv("RESOLVER_MAP"); raw != "" {
		if err := json.Unmarshal([]byte(raw), &hosts); err != nil {
			log.Fatalf("RESOLVER_MAP invalid JSON: %v", err)
		}
	}
	keys := map[string]string{}
	for prefix := range hosts {
		k := os.Getenv("RESOLVER_KEY_" + prefix)
		if k == "" {
			log.Fatalf("missing RESOLVER_KEY_%s", prefix)
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
	log.Printf("diary-portal-resolver listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, loadResolver()))
}
