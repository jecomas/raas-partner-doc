# Partner API – OpenAPI error coverage audit

Generated as part of the partner controllers documentation initiative. Re-run after `yarn build:partner` by comparing `partner/build/swagger.json` to controller implementations.

## Method

- Sample **high-traffic** `operationId`s from auth, operations, funding, and contacts.
- For each: list `responses.*` keys present in OpenAPI vs obvious branches in code (`badRequest`, `notFound`, `errorResponse`, etc.).

## Findings (snapshot)

| operationId | OpenAPI responses | Notes |
|---------------|-------------------|-------|
| getUserTokenV2 | 200, 400, 404, 500 | Matches `@Res()` branches. Global `api_key` failures may appear as 401 from middleware (not listed on this operation). |
| registerUserV2 | 200, 400, 500 | Matches implementation. |
| requestMoneyV2 | 200, 400, 500 | Matches typical pattern. |
| createContact | 200, 201, 400, 422, 500 | Implementation returns **200** with body on success; `@SuccessResponse(CREATED)` adds **201** without JSON body in spec—curated examples use `responses["200"]` for success payload. |
| listContacts | 200 only | Controller only exposes success `TsoaResponse`; always returns 200 (empty list if user resolution fails silently). Optional improvement: add explicit 404/400 if product wants stricter semantics. |
| sendFundsV2 | 200, 400, 500 | Matches. |
| operationQuoteV2 | 200, **400**, 500 | Invalid quotation payload (empty recipient, non-positive amount, empty currency) now returns **400** via `badRequestResponse`; other failures remain **500**. |

## Recommendations

1. Prefer **`@Res()` for every HTTP status** the handler returns so TSOA emits the response in `partner/build/swagger.json`.
2. Use **`mintlify-docs/openapi-examples.json`** → `responses` for non-200 examples **only** when that status already has `content` in the spec (see `mergeOpenApiExamples` in `scripts/reorder-swagger.js`).
3. Keep **JSDoc `@throws`** aligned with emitted statuses (not with middleware-only 401 unless documented globally).
4. Periodically re-audit **funding** and **cip** controllers (large surface area) using the same table format.

## Commands

```bash
yarn build:partner
node -e "const s=require('./partner/build/swagger.json'); /* inspect paths */"
yarn docs:update-openapi
```
