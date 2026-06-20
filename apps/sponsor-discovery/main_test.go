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
