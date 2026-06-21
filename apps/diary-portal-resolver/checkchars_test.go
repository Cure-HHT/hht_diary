package main

import (
	"encoding/json"
	"os"
	"testing"
)

// Verifies: DIARY-DEV-linking-code-lifecycle/E (cross-language contract)
func TestCheckCharsGoldenVectors(t *testing.T) {
	data, err := os.ReadFile("../../contract/linking-code-mac-vectors.json")
	if err != nil {
		t.Fatalf("read vectors: %v", err)
	}
	var vectors []struct {
		Input   string `json:"input"`
		KeyUTF8 string `json:"keyUtf8"`
		Check   string `json:"check"`
	}
	if err := json.Unmarshal(data, &vectors); err != nil {
		t.Fatal(err)
	}
	if len(vectors) == 0 {
		t.Fatal("no vectors")
	}
	for _, v := range vectors {
		if got := checkCharsFor(v.Input, v.KeyUTF8); got != v.Check {
			t.Errorf("input %q: got %q want %q", v.Input, got, v.Check)
		}
	}
}
