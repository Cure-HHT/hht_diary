# File A — canonical h2 definition

## REQ-d00001: Server-Owned Activation (file A definition)

**Level**: dev | **Status**: Active | **Implements**: -
**Refines**: REQ-p00001

### Assertions

A. POST /activate SHALL accept {code, password} with no bearer auth.

B. The handler SHALL validate code expiry before any external call.

*End* *Server-Owned Activation (file A definition)*
