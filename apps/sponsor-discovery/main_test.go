package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

// Verifies: HHT-OPS-sponsor-discovery/A+B
func newTestResolver() *resolver {
	return &resolver{
		hosts:   map[string]string{"CA": "https://callisto.example"},
		keys:    map[string]string{"CA": "k"},
		limiter: newRateLimiter(1000), // effectively unlimited for these tests
	}
}

func validCode() string {
	const input = "CARANDMQ" // 8 chars: prefix CA + 6 body
	return input + checkCharsFor(input, "k")
}

func TestResolveSuccess(t *testing.T) {
	r := newTestResolver()
	code := validCode()
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/v1/resolve?code="+code, nil))
	if rec.Code != 200 {
		t.Fatalf("status %d body %s", rec.Code, rec.Body.String())
	}
	if rec.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Error("missing CORS header")
	}
}

func TestUnknownPrefixAndBadCheckAreIdentical(t *testing.T) {
	r := newTestResolver()
	unknown := httptest.NewRecorder()
	r.ServeHTTP(unknown, httptest.NewRequest(http.MethodGet, "/v1/resolve?code=ZZAAAAAAAA", nil))
	badcheck := httptest.NewRecorder()
	r.ServeHTTP(badcheck, httptest.NewRequest(http.MethodGet, "/v1/resolve?code=CARANDMQAA", nil))
	if unknown.Code != 404 || badcheck.Code != 404 {
		t.Fatalf("want 404/404 got %d/%d", unknown.Code, badcheck.Code)
	}
	if unknown.Body.String() != badcheck.Body.String() {
		t.Errorf("negatives differ: %q vs %q", unknown.Body.String(), badcheck.Body.String())
	}
}

// Verifies: HHT-OPS-sponsor-discovery/C (rate limit)
func TestRateLimitReturns429(t *testing.T) {
	r := &resolver{
		hosts:   map[string]string{"CA": "https://callisto.example"},
		keys:    map[string]string{"CA": "k"},
		limiter: newRateLimiter(1),
	}
	do := func() int {
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/v1/resolve?code=ZZAAAAAAAA", nil))
		return rec.Code
	}
	if c := do(); c != 404 {
		t.Fatalf("first request: want 404 got %d", c)
	}
	if c := do(); c != 429 {
		t.Fatalf("second request (same IP): want 429 got %d", c)
	}
}

// Verifies: HHT-OPS-sponsor-discovery/C — rate-limit keying must not collapse
// IPv6 clients into one bucket (clientIP must parse bracketed IPv6).
func TestClientIPHandlesIPv6AndIPv4(t *testing.T) {
	cases := []struct{ remote, want string }{
		{"192.0.2.1:1234", "192.0.2.1"},
		{"[2001:db8::1]:1234", "2001:db8::1"},
	}
	for _, tc := range cases {
		req := httptest.NewRequest(http.MethodGet, "/v1/resolve", nil)
		req.RemoteAddr = tc.remote
		if got := clientIP(req); got != tc.want {
			t.Errorf("clientIP(%q) = %q, want %q", tc.remote, got, tc.want)
		}
	}
}
