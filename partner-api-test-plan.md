# Plan de pruebas — Partner API (swagger-partner.json)

API base: `https://raas-partner-cv.nomas.cash/v1`  
Autenticación: header `api_key` con scopes `partner`, `partner_send`, `partner_full`.

---

## 1. Puntos Críticos

| # | Riesgo | Endpoint / contexto | Mitigación a verificar |
|---|--------|----------------------|-------------------------|
| 1 | **IDOR** | `GET /user/operations/detail/{id}` — el path solo lleva `id`, no `userToken`. Un partner podría probar UUIDs de operaciones de otros usuarios. | Backend debe validar que la operación pertenezca al tenant/partner del `api_key` (o al usuario asociado). Si no hay esa validación, es crítico. |
| 2 | **Fuga de información en 5xx** | Todos los endpoints devuelven `reason` (y a veces `code`) en 400/500. | Asegurar que en 500 no se devuelvan mensajes crudos de DB, stack traces ni rutas internas. |
| 3 | **Doble gasto / race en request-money** | `POST /user/operations/request-money-v2/{userToken}` crea una operación de solicitud de dinero. | Sin idempotency key o transacciones, reintentos o peticiones concurrentes podrían crear operaciones duplicadas. |
| 4 | **Consistencia al añadir método de pago** | `POST /user/funding/source/ubn-account/add/{userToken}`. | Múltiples escrituras (cuenta + vinculación a usuario) deben ir en transacción; fallo a mitad no debe dejar estado inconsistente. |

---

## 2. Debilidades de Lógica

| # | Debilidad | Endpoint / dato | Qué probar |
|---|-----------|------------------|------------|
| 1 | **`limit` como number en path** | `GET /user/operations/frequent/{userToken}/{limit}` — schema `format: "double"`. | Valores `0`, negativo, `NaN`, decimales, números muy grandes (DoS o error no controlado). |
| 2 | **Montos sin validación explícita en spec** | `RequestMoneyPartnerParams.amount`, `AddUBNParams` y esquemas con `amount` / `currency`. | Enviar `0`, negativos, `NaN`, `Infinity`, números con muchos decimales; la API debe rechazar o normalizar de forma segura. |
| 3 | **Alias/contacto sin límite de longitud** | `GetUserTokenParams` (phone/email), `createContactRequestParamsPartner`, `phoneOrEmail` en path. | Strings muy largos, caracteres especiales (UTF-8, emojis, `%00`); no debe crashear ni guardar basura. |
| 4 | **Query `id` opcional** | `GET /user/funding/source/get-payment-method-v2/{userToken}?id=`. | Comportamiento con `id` vacío, otro userToken, o ID de otro usuario (IDOR por query). |
| 5 | **Listados sin paginación documentada** | `GET /user/operations/{userToken}`, `GET /user/contacts/{userToken}`. | Respuestas muy grandes; timeouts o DoS si no hay límite/paginación. |
| 6 | **Flujo request-money** | Crear request-money sin método de financiamiento válido o sin estado previo correcto. | Verificar que no se pueda “confirmar” o avanzar un request en estado inválido. |

---

## 3. Plan de Pruebas (Test Cases)

Organizado por recurso. Incluir siempre header `api_key` válido con el scope indicado en el Swagger.

### 3.1 Auth

| ID | Caso | Método | Endpoint / body | Resultado esperado |
|----|------|--------|------------------|--------------------|
| A1 | Happy path: get token por teléfono | POST | `/auth/get-user-token-v2` — `{ "phoneNumber": "+52...", "countryCode": "MX" }` | 200 + `userId` |
| A2 | Happy path: get token por email | POST | `/auth/get-user-token-v2` — `{ "email": "user@example.com" }` | 200 + `userId` |
| A3 | Sin phone ni email | POST | `/auth/get-user-token-v2` — `{}` | 400 |
| A4 | Payload con inyección en string | POST | Body con `"email": "{ '$gt': '' }"` o similar | 400 / sin ejecución de operador |
| A5 | String masivo en email/phone | POST | Campo de 1M caracteres | 400 o 413, no 500 |
| A6 | Register user happy path | POST | `/auth/register-user-v2` según `RegisterUserParams` | 200 + `userId` |
| A7 | Rate limiting (opcional) | POST | Muchas peticiones seguidas a get-user-token / register | 429 o throttling |

### 3.2 Contacts

| ID | Caso | Método | Endpoint / body | Resultado esperado |
|----|------|--------|------------------|--------------------|
| C1 | Listar contactos | GET | `/user/contacts/{userToken}` | 200 + array |
| C2 | IDOR: listar con userToken de otro usuario | GET | `/user/contacts/{userTokenB}` con api_key de usuario A | 403 o 404, no datos de B |
| C3 | Crear contacto válido | POST | `/user/contacts/{userToken}` — body según schema | 201 |
| C4 | Crear contacto con teléfono duplicado | POST | Mismo phone que contacto existente | 400/422 según spec |
| C5 | Actualizar contacto | PUT | `/user/contacts/{userToken}` — body update | 200 |
| C6 | IDOR: update con userToken ajeno | PUT | `/user/contacts/{userTokenB}` modificando contacto de B | 403 o 404 |
| C7 | Get contact user detail | GET | `/user/contacts/user/{userToken}/{phoneOrEmail}` | 200 + userExists, hasOperations, etc. |
| C8 | phoneOrEmail con caracteres especiales / muy largo | GET | Path con emoji o string largo | 400/404, no 500 |
| C9 | Contact body: strings masivos / emojis en alias | POST | Campos con longitud extrema o UTF-8 especial | 400/422 |

### 3.3 Funding

| ID | Caso | Método | Endpoint / body | Resultado esperado |
|----|------|--------|------------------|--------------------|
| F1 | Available methods | GET | `/user/corridors/available-methods/{userToken}` | 200 + array |
| F2 | Available methods con query | GET | `?destinationCountry=US&operationType=SendFunds` | 200 |
| F3 | List funding sources (request money) | GET | `/user/funding/source/request-money/{userToken}` | 200 + array |
| F4 | Get payment method V2 sin id | GET | `/user/funding/source/get-payment-method-v2/{userToken}` | Comportamiento definido (default o 400) |
| F5 | Get payment method V2 con id de otro usuario | GET | `.../{userTokenA}?id=paymentMethodOfUserB` | 403/404, no datos de B |
| F6 | Add UBN account válido | POST | `/user/funding/source/ubn-account/add/{userToken}` — AddUBNParams | 200 |
| F7 | Add UBN: amount/currency inválidos | POST | amount negativo, NaN, currency vacío | 400 |
| F8 | Add UBN: número de cuenta con caracteres raros | POST | number con inyección o muy largo | 400 |

### 3.4 Operations

| ID | Caso | Método | Endpoint / body | Resultado esperado |
|----|------|--------|------------------|--------------------|
| O1 | Request money happy path | POST | `/user/operations/request-money-v2/{userToken}` — RequestMoneyPartnerParams | 200 + operación |
| O2 | Request money con amount 0 o negativo | POST | amount: 0, -1 | 400 |
| O3 | Request money con amount NaN / Infinity | POST | amount: NaN o Infinity (JSON) | 400 |
| O4 | Idempotencia: mismo request dos veces | POST | Mismo body (y si existe idempotency key, mismo key) dos veces | Segundo intento no crea otra operación o devuelve la misma |
| O5 | Race: N requests iguales concurrentes | POST | Varias peticiones idénticas en paralelo | Una operación creada o regla de negocio clara (ej. una por beneficiario/ventana) |
| O6 | Get operation status | GET | `/user/operations/status/{userToken}/{operationId}` | 200 + status |
| O7 | IDOR status: operationId de otro usuario | GET | `/user/operations/status/{userTokenA}/{operationIdOfB}` | 403/404 |
| O8 | Get operation detail por id | GET | `/user/operations/detail/{id}` | 200 si pertenece al contexto del api_key |
| O9 | IDOR detail: id de operación de otro partner/usuario | GET | `/user/operations/detail/{idOtherUserOperation}` | 403/404, nunca detalle de la operación ajena |
| O10 | List operations | GET | `/user/operations/{userToken}` | 200 + array |
| O11 | List operations con toPhoneNumber | GET | `?toPhoneNumber=+52...` | 200 filtrado |
| O12 | Get frequent contacts | GET | `/user/operations/frequent/{userToken}/10` | 200 + array |
| O13 | Frequent: limit 0, negativo, decimal, enorme | GET | `.../0`, `.../-1`, `.../1.5`, `.../999999` | 400 para inválidos; para 999999 no DoS |

### 3.5 Errores y resiliencia

| ID | Caso | Objetivo | Resultado esperado |
|----|------|----------|--------------------|
| E1 | 500 genérico | Provocar error interno (ej. ID mal formado, FK inexistente) | 500 con mensaje genérico; sin stack trace ni mensaje de DB en body |
| E2 | Timeout (si hay mocks) | Simular DB o dependencia lenta | Timeout o 503; no colgar el request |
| E3 | Body no JSON / Content-Type erróneo | POST con body plano o XML | 400/415 |

---

## 4. Refactor Recomendado

1. **GET /user/operations/detail/{id}**  
   - Añadir en spec (y en implementación) que el backend valida que `id` corresponde a una operación permitida para el tenant/usuario del `api_key`.  
   - Opcional: incluir `userToken` en path o query para alineación con el resto de operaciones y documentar que se valida la relación usuario-operación.

2. **Request-money (idempotencia)**  
   - Definir header de idempotency (ej. `Idempotency-Key`) y documentarlo en el Swagger.  
   - En servidor: mismo key → misma respuesta y a lo sumo una operación creada.

3. **Montos y límites**  
   - En esquemas OpenAPI: `minimum: 0` (o el mínimo de negocio) para `amount`; rechazar explícitamente NaN/Infinity en validación.  
   - Para `limit` en `/user/operations/frequent/{userToken}/{limit}`: definir `minimum: 1`, `maximum` (ej. 100) y tipo integer.

4. **Respuestas de error**  
   - Middleware global: en catch no enviar `reason` con contenido de DB o stack; usar códigos internos y mensajes genéricos al cliente.

5. **Paginación**  
   - Para `getOperations` y `listContacts`, documentar (y aplicar) límite de página y cursor/offset para evitar respuestas desproporcionadas y DoS.

6. **Transacciones**  
   - En `addUBNAccount` y en flujos que crean operación + actualizaciones: usar transacciones para que un fallo no deje datos a medias.

---

## Resumen de cobertura

- **Auth:** 7 casos (happy path, validación, inyección, tamaño, rate limit).
- **Contacts:** 9 casos (CRUD, IDOR, duplicados, edge en path/body).
- **Funding:** 8 casos (listados, IDOR por id, validación UBN y amounts).
- **Operations:** 13 casos (request-money con montos e idempotencia, status/detail/list/frequent, IDOR, limit edge).
- **Errores/resiliencia:** 3 casos.

Total: **40 test cases** listos para implementar en Jest/Vitest + Supertest (o similar), priorizando primero los marcados como críticos (IDOR detail, idempotencia request-money, validación de montos y errores 500).
