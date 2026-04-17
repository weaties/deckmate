---
name: api-client
description: Generate a Swift client method + Codable model from a HelmLog FastAPI route
---

# /api-client

Scaffold the client side of a new server endpoint: the `Codable` model
in `DeckMateModels`, the method on `APIClient`, a fixture file, and a
decoding test.

## Invocation

```
/api-client <server-route-path>
```

Example: `/api-client routes/polar.py::get_polar`.

## Steps

1. **Inspect the server route** in `../helmlog/src/helmlog/routes/<file>.py`.
   Note:
   - HTTP method + path
   - path and query parameters
   - response shape (look at the `JSONResponse` / return model)
   - authorisation requirements (which `require_auth` / role)
2. **Add / update a Codable model** in
   `packages/DeckMateKit/Sources/DeckMateModels/`:
   - One `struct` per response type, `Codable, Hashable, Sendable`.
   - Snake-case field names in JSON; Swift properties stay camelCase —
     `DeckMateJSON.decoder.keyDecodingStrategy = .convertFromSnakeCase`
     handles the mapping.
   - Dates are `Date` typed; the shared decoder handles ISO-8601 with
     fractional seconds.
   - If a field may be missing, use `Optional`, not a sentinel value.
3. **Add a fixture** under
   `packages/DeckMateKit/Tests/DeckMateModelsTests/Fixtures/<name>.json`
   by calling the server locally and pasting the real response.
4. **Write a decoding test** that asserts a known field on the decoded
   struct — this is the honest regression net.
5. **Add a method to `APIClient`** (`DeckMateAPI/APIClient.swift`) following
   the existing `sessions()` pattern: `get`, `post`, or
   `postNoReturn` + typed return.
6. **Add an `APIClientTests` stub** that returns the fixture JSON via
   `StubURLProtocol` and asserts the client call succeeds.
7. **Update `docs/api-endpoints.md`** — add a row for the new route.

## Gotchas

- The server may return different shapes on the same route depending on
  role (e.g. admin vs crew). Handle either case in the model or split
  into two endpoints on the client side.
- `null` vs missing: `JSONDecoder` treats a present-with-null value and
  a missing key equivalently for `Optional` properties — you can rely
  on that.
- If the server returns a wrapped envelope (`{"data": [...]}`), add an
  internal `Envelope<T>` type — don't leak the envelope to callers.
