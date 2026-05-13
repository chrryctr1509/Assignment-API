# API Design Conventions — Stack-Agnostic REST API Standards

Skill ini berlaku untuk SEMUA backend API development, terlepas dari stack (Laravel, FastAPI, Express, Go, Kotlin).
Setiap rule di sini HARUS diikuti kecuali ada dokumentasi eksplisit di `docs/conventions.md` yang meng-override.

Rules ini didasarkan pada temuan nyata dari simulation testing (SIM-01, SIM-05, SIM-06, SIM-09, SIM-10).

---

## 1. REST Endpoint Naming

### Rules
- **Plural nouns** untuk resource: `/api/tasks`, `/api/users`, `/api/invoices`
- **Kebab-case** untuk multi-word: `/api/stock-movements`, `/api/user-profiles`
- **JANGAN gunakan verbs** di URL: ~~`/api/getUsers`~~, ~~`/api/createTask`~~
- **Nested resources** max 2 level: `/api/users/{id}/tasks` — OK. `/api/users/{id}/tasks/{id}/comments/{id}/replies` — TIDAK
- **Action endpoints** gunakan verb prefix jika terpaksa: `POST /api/tasks/{id}/archive`

### Versioning
```
/api/v1/tasks        ← prefix versioning (recommended)
Accept: application/vnd.api.v1+json  ← header versioning (alternative)
```

Pilih SATU strategi dan konsisten. Default: prefix versioning `/api/v1/`.

---

## 2. Response Envelope

### Standard Success Response
```json
{
  "data": { ... },
  "meta": {
    "timestamp": "2026-04-02T10:30:00Z"
  }
}
```

### Standard Collection Response (with Pagination)
```json
{
  "data": [ ... ],
  "meta": {
    "current_page": 1,
    "per_page": 25,
    "total": 142,
    "last_page": 6
  },
  "links": {
    "first": "/api/v1/tasks?page=1",
    "last": "/api/v1/tasks?page=6",
    "prev": null,
    "next": "/api/v1/tasks?page=2"
  }
}
```

### Standard Error Response
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The given data was invalid.",
    "details": [
      {
        "field": "email",
        "message": "The email field must be a valid email address."
      }
    ]
  }
}
```

**JANGAN** campur format — semua endpoint harus pakai envelope yang sama.
**JANGAN** return bare array `[{...}, {...}]` — selalu wrap dalam `"data"`.

---

## 3. Pagination (WAJIB untuk semua list endpoints)

> **L40/SIM-10:** Unbounded pagination = DoS vector.
> **L4/SIM-01:** Missing eager-load sebelum paginate = N+1 queries.
> **SIM-05:** Endpoint tanpa pagination mengembalikan semua records.

### Rules

1. **SEMUA list/collection endpoints WAJIB punya pagination.** Tidak ada exception.

2. **Cap `per_page` dengan maximum:**
   ```
   # Stack-agnostic pseudocode
   per_page = clamp(request.per_page, min=1, max=100)
   default  = 25
   ```

   Contoh per stack:
   ```php
   // Laravel
   $perPage = max(1, min(100, (int) $request->input('per_page', 25)));
   $items = Model::query()->paginate($perPage);
   ```
   ```python
   # FastAPI
   @app.get("/items")
   def list_items(page: int = 1, per_page: int = Query(default=25, ge=1, le=100)):
       offset = (page - 1) * per_page
       ...
   ```
   ```go
   // Go
   perPage := clamp(r.URL.Query().Get("per_page"), 1, 100, 25)
   ```

3. **Eager-load relasi SEBELUM paginate:**
   ```php
   // ✅ BENAR — eager load dulu
   Task::with(['assignee', 'labels'])->paginate($perPage);

   // ❌ SALAH — N+1 query explosion
   Task::paginate($perPage); // lalu akses $task->assignee di serializer
   ```

4. **Return pagination metadata** di response envelope (lihat section 2).

5. **Cursor-based pagination** untuk dataset besar (>100K rows):
   ```
   GET /api/v1/events?cursor=eyJpZCI6MTAwfQ&per_page=50
   ```
   Return `next_cursor` di meta, BUKAN page numbers.

---

## 4. Sorting & Filtering (WAJIB whitelist)

> **L39/SIM-10:** Raw user input di `orderBy()` = SQL injection / column enumeration.

### Sorting Rules

1. **SELALU whitelist kolom yang boleh di-sort:**
   ```
   allowed_sort = ["name", "created_at", "updated_at", "status"]
   sort_by = request.sort_by if request.sort_by in allowed_sort else "created_at"
   sort_dir = "desc" if request.sort_dir == "desc" else "asc"
   ```

2. **JANGAN pernah pass raw user input ke ORDER BY:**
   ```php
   // ❌ SQL INJECTION
   $query->orderBy($request->sort_by, $request->sort_dir);

   // ✅ AMAN
   $allowed = ['name', 'created_at', 'updated_at'];
   $sort = in_array($request->sort_by, $allowed) ? $request->sort_by : 'created_at';
   $dir = $request->sort_dir === 'desc' ? 'desc' : 'asc';
   $query->orderBy($sort, $dir);
   ```

3. **Default sort** harus selalu ada — jangan return unsorted results.

### Filtering Rules

1. **Whitelist filter fields** — jangan allow arbitrary column filtering.
2. **Sanitize filter values** — especially for LIKE queries (escape `%` and `_`).
3. **Document available filters** di API docs atau response headers.

---

## 5. HTTP Status Codes

> **SIM-01:** Endpoint return 200 untuk semua response termasuk error.
> **SIM-05:** Wrong status codes (201 untuk GET, 200 untuk create).
> **SIM-06:** InsufficientStockError return 400 instead of 409.

### Mandatory Status Code Map

| Action | Success | Error Examples |
|--------|---------|----------------|
| GET /resources | `200 OK` | `404 Not Found` |
| GET /resources/:id | `200 OK` | `404 Not Found` |
| POST /resources | `201 Created` | `422 Unprocessable Entity` (validation) |
| PUT/PATCH /resources/:id | `200 OK` | `404`, `422` |
| DELETE /resources/:id | `204 No Content` | `404`, `409 Conflict` |

### Error Status Codes — Pilih yang TEPAT

| Code | When to Use | JANGAN Gunakan Untuk |
|------|-------------|---------------------|
| `400 Bad Request` | Malformed request (unparseable JSON, missing content-type) | Validation errors — gunakan 422 |
| `401 Unauthorized` | Missing or invalid auth token | Known user tanpa permission — gunakan 403 |
| `403 Forbidden` | Authenticated tapi tidak punya akses | Invalid token — gunakan 401 |
| `404 Not Found` | Resource tidak ada | Resource yang di-soft-delete (gunakan 410 Gone jika permanent) |
| `409 Conflict` | Business logic conflict (duplicate, insufficient stock, stale update) | Validation errors — gunakan 422 |
| `422 Unprocessable Entity` | Validation errors (parseable tapi invalid data) | Business logic — gunakan 409 |
| `429 Too Many Requests` | Rate limit exceeded | — |
| `500 Internal Server Error` | Unexpected server error | Errors yang bisa di-handle client-side |

### Anti-Pattern: Jangan Return 200 untuk Error
```json
// ❌ SALAH — status 200 tapi isinya error
{ "success": false, "error": "User not found" }

// ✅ BENAR — status 404
HTTP 404
{ "error": { "code": "NOT_FOUND", "message": "User not found" } }
```

---

## 6. Authentication & Authorization Headers

> **L21/SIM-04:** Protected endpoints tidak check auth header.
> **L19/SIM-04:** Missing `authorize()` di mutation endpoints.
> **L20/SIM-04:** Dashboard query tidak di-scope ke authenticated user.
> **L33/SIM-09:** Auth endpoint leak via `firstOrFail()` error message.

### Auth Header Pattern
```
Authorization: Bearer <token>
```

### Rules

1. **SEMUA mutation endpoints (POST, PUT, PATCH, DELETE) WAJIB cek authorization.**
   Jangan asumsikan authenticated = authorized.

2. **Scope queries ke authenticated user:**
   ```php
   // ✅ WAJIB — scope ke user
   $userId = auth()->id();
   Task::where('user_id', $userId)->paginate();

   // ❌ DATA LEAK — return semua user punya data
   Task::paginate();
   ```

3. **Auth error responses harus IDENTIK** untuk user-not-found dan wrong-password:
   ```json
   // ✅ BENAR — same message regardless of cause
   HTTP 401
   { "error": { "code": "AUTH_FAILED", "message": "Invalid credentials" } }

   // ❌ USER ENUMERATION
   HTTP 404 { "error": "User not found" }        ← attacker knows email doesn't exist
   HTTP 401 { "error": "Wrong password" }         ← attacker knows email exists
   ```

4. **Gunakan `first()` + null check**, BUKAN `firstOrFail()` di auth flow:
   ```php
   // ✅ AMAN
   $user = User::where('email', $email)->first();
   if (!$user || !Hash::check($password, $user->password)) {
       return response()->json(['error' => ['message' => 'Invalid credentials']], 401);
   }

   // ❌ ENUMERATION via 404 ModelNotFoundException
   $user = User::where('email', $email)->firstOrFail();
   ```

---

## 7. Rate Limiting

> **L3/SIM-01:** Auth endpoints tanpa rate limiting.

### Rules

1. **Auth endpoints WAJIB di-rate-limit:**
   ```
   POST /api/auth/login       → max 5 requests per minute per IP
   POST /api/auth/register    → max 3 requests per minute per IP
   POST /api/auth/forgot      → max 3 requests per minute per IP
   ```

2. **API endpoints** — gunakan tiered rate limiting:
   ```
   Authenticated users  : 60 requests per minute
   Unauthenticated      : 20 requests per minute
   Admin/service        : 300 requests per minute
   ```

3. **Return rate limit headers:**
   ```
   X-RateLimit-Limit: 60
   X-RateLimit-Remaining: 42
   X-RateLimit-Reset: 1680000000
   ```

4. **Return `429 Too Many Requests`** saat limit tercapai:
   ```json
   HTTP 429
   {
     "error": {
       "code": "RATE_LIMITED",
       "message": "Too many requests. Try again in 45 seconds.",
       "retry_after": 45
     }
   }
   ```

---

## 8. Input Validation

> **L1/SIM-01:** Validator di controller, bukan FormRequest.
> **L12/SIM-02:** `Carbon::parse()` pada raw user input tanpa validasi.
> **L13/SIM-02:** `passedValidation()` vs `prepareForValidation()` ordering bug.

### Rules

1. **Validasi di boundary layer** (FormRequest, Pydantic model, validator middleware) — BUKAN di controller/handler:
   ```php
   // ✅ Laravel: FormRequest
   class StoreTaskRequest extends FormRequest {
       public function rules() { return ['title' => 'required|string|max:255']; }
   }

   // ❌ Controller-level validation
   $validator = Validator::make($request->all(), [...]);
   ```

2. **JANGAN parse dates dari raw input** — validasi tipe dulu:
   ```php
   // ✅ BENAR
   public function rules() {
       return ['due_date' => 'required|date|after:today'];
   }
   public function prepareForValidation() {
       $this->merge(['due_date' => Carbon::parse($this->due_date)->toDateString()]);
   }

   // ❌ SALAH — crash pada invalid input
   $dueDate = Carbon::parse($request->due_date);
   ```

3. **Normalize input di pre-validation hook**, bukan post:
   - Laravel: `prepareForValidation()` (BUKAN `passedValidation()`)
   - FastAPI: Pydantic `@validator` with `pre=True`
   - Express: middleware sebelum validation chain

---

## 9. Idempotency & Safety

### Safe Methods (tidak mengubah state)
- `GET`, `HEAD`, `OPTIONS` — WAJIB idempotent dan safe
- JANGAN pernah trigger side effects di GET handler

### Idempotent Methods
- `PUT`, `DELETE` — harus idempotent (call 2x = same result)
- `PUT` replace seluruh resource — gunakan `PATCH` untuk partial update

### Non-Idempotent
- `POST` — boleh non-idempotent, tapi pertimbangkan idempotency key:
  ```
  Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
  ```
  Untuk financial/payment endpoints, idempotency key WAJIB.

---

## 10. Checklist — Review Sebelum Merge

Setiap API endpoint HARUS lolos checklist ini:

- [ ] Endpoint menggunakan correct HTTP method (GET/POST/PUT/PATCH/DELETE)
- [ ] URL menggunakan plural nouns, kebab-case
- [ ] Response menggunakan standard envelope (`data`, `meta`, `error`)
- [ ] List endpoint punya pagination dengan `per_page` cap (max 100)
- [ ] Sort/filter columns di-whitelist
- [ ] Status code sesuai tabel di section 5
- [ ] Auth endpoints di-rate-limit
- [ ] Mutation endpoints cek authorization (bukan hanya authentication)
- [ ] Queries di-scope ke authenticated user jika applicable
- [ ] Input divalidasi di boundary layer (FormRequest / Pydantic / middleware)
- [ ] Error response tidak leak informasi sensitif (stack trace, SQL, user enumeration)
- [ ] Dates dan numeric input divalidasi sebelum di-parse
