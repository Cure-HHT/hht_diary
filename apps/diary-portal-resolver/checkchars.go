package main

import (
	"crypto/hmac"
	"crypto/sha256"
)

// Implements: DIARY-DEV-linking-code-lifecycle/E — byte-for-byte mirror of the
// Dart issuer (apps/common-dart/portal_actions/.../linking_code_generator.dart),
// pinned by contract/linking-code-mac-vectors.json.
const charset = "ABCDEFGHJKLMNPQRTUVWXY346789" // 28 symbols

func checkCharsFor(input, sponsorKey string) string {
	h := hmac.New(sha256.New, []byte(sponsorKey))
	h.Write([]byte(input))
	sum := h.Sum(nil)
	return string([]byte{charset[sum[0]%28], charset[sum[1]%28]})
}
