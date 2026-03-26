# Mintlify docs (Partner API)

Sitio de documentación pública del Partner API. La navegación y el tema se definen en [`docs.json`](./docs.json).

## Contenido

| Recurso | Uso |
|--------|-----|
| [`docs.json`](./docs.json) | Navegación (tabs), OpenAPI por pestaña, `api.baseUrl` |
| [`api-reference/introduction.mdx`](./api-reference/introduction.mdx) | Intro, mTLS, happy path; link to QA project context |
| [`api-reference/qa-project-context.mdx`](./api-reference/qa-project-context.mdx) | **QA project context** (Introduction nav); keep in sync with `docs/qa/PROJECT_CONTEXT.md` |
| [`api-reference/partner-api-scopes.mdx`](./api-reference/partner-api-scopes.mdx) | **Partner API scopes**; keep in sync with `docs/qa/PARTNER_API_SCOPES.md` |
| [`api-reference/environment-matrix.mdx`](./api-reference/environment-matrix.mdx) | **Environment matrix**; keep in sync with `docs/qa/ENVIRONMENT_MATRIX.md` |
| [`api-reference/credentials-test-identities-pack.mdx`](./api-reference/credentials-test-identities-pack.mdx) | **Credentials & test identities pack**; keep in sync with `docs/qa/CREDENTIALS_TEST_IDENTITIES_PACK.md` |
| `swagger-partner.json`, `swagger-partner-send.json`, `swagger-partner-full.json`, `swagger-partner-widget-ask.json` | Especificaciones consumidas por Mintlify |
| [`partner-api-test-plan.md`](./partner-api-test-plan.md) | Plan de pruebas / riesgos (referencia QA) |

## Desarrollo local

Desde la raíz del monorepo RaaS:

```bash
cd mintlify-docs && npx mintlify dev
```

(O el comando global `mint dev` si tienes la CLI de Mintlify instalada.)

Abre la URL que imprime la CLI (suele ser `http://localhost:3000`).

## Actualizar el OpenAPI desde el código

En la raíz del monorepo:

```bash
yarn docs:update-openapi
```

Eso (ver `package.json`) copia `partner/build/swagger.json` → `mintlify-docs/swagger.json` y ejecuta `scripts/reorder-swagger.js`, que a partir de ese spec genera los ficheros usados por las pestañas de Mintlify: `swagger-partner.json`, `swagger-partner-send.json`, `swagger-partner-full.json`, `swagger-partner-widget-ask.json`.

Antes conviene tener un build reciente del Partner API:

```bash
yarn build:partner && yarn docs:update-openapi
```

El script `yarn docs:update` hace `build:partner`, `docs:update-openapi`, copia este directorio a un repo hermano `../raas-partner-doc` y arranca `mint dev`; solo úsalo si ese flujo aplica en tu máquina.

## Despliegue

Mintlify suele desplegar desde el repositorio/carpeta conectada al dashboard de Mintlify. Asegura que `docs.json` y los JSON de Swagger estén committed y que la rama configurada en Mintlify reciba los cambios.
