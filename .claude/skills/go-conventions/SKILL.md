---
name: go-conventions
description: >
  Standar dan konvensi penulisan kode Go backend untuk tim.
  Gunakan setiap kali be-developer menulis atau memodifikasi
  kode Go — handlers, services, repositories, models, dan tests.
  Wajib diikuti agar kode idiomatic, testable, dan bebas goroutine leak.
---

# Go Backend Conventions

## Convention Adoption Gate

**Jalankan ini PERTAMA sebelum apply konvensi apapun.**

### Step 1 — Deteksi Project Type
```bash
find . -name "*.go" 2>/dev/null | wc -l
```
Jika output `0` → **GREENFIELD**. Skip gate, apply konvensi penuh langsung.
Jika output > 0 → **EXISTING PROJECT**. Lanjut ke Step 2.

### Step 2 — Migration Risk Assessment
```bash
# Cek Go version
cat go.mod 2>/dev/null | grep '^go ' | head -1
# Cek HTTP framework yang dipakai
cat go.mod 2>/dev/null | grep -E 'gin|chi|echo|fiber|gorilla/mux' | head -5
# Cek test coverage
go test ./... -coverprofile=coverage.out 2>/dev/null | tail -3
# Jumlah Go files
find . -name "*.go" ! -name "*_test.go" 2>/dev/null | wc -l
```

### Step 3 — Hitung Risk Score
```
+40  Tidak ada interface — semua concrete types, sulit di-test
+30  Tidak ada unit test
+20  > 20 Go files yang harus diubah
+20  Error handling pakai panic alih-alih return error
+10  Global state atau singleton pattern berlebihan
```

### Step 4 — Decision
```
< 40%  → Apply konvensi penuh.
40-79% → STOP. Tampilkan ke programmer:
         "Convention migration risk: [N]%
          Impact: [N] files | Reason: [alasan]
          APPROVE → proceed | SKIP → keep existing + catat tech debt"
>= 80% → KEEP AS IS. Catat ke .claude/memory/tech-debt.md.
```

---

## Prinsip Utama
- Interface-driven design — depend on interfaces, not concrete types
- Selalu return error — tidak boleh `panic` di production code kecuali init
- `context.Context` sebagai parameter pertama setiap fungsi yang async / IO
- Short variable names untuk scope kecil, deskriptif untuk scope besar
- Table-driven tests untuk semua logika yang bisa divariasikan input/output-nya

---

## Struktur Folder

```
.
├── cmd/
│   └── api/
│       └── main.go             <- entry point
├── internal/                   <- kode internal, tidak boleh diimport luar
│   ├── config/
│   │   └── config.go           <- load env, struct Config
│   ├── domain/
│   │   ├── user.go             <- struct + business logic
│   │   └── errors.go           <- sentinel errors domain
│   ├── handler/
│   │   ├── user_handler.go     <- HTTP handler functions
│   │   └── middleware/
│   │       └── auth.go
│   ├── repository/
│   │   ├── user_repository.go  <- interface
│   │   └── postgres/
│   │       └── user_repo.go    <- implementasi
│   └── service/
│       ├── user_service.go     <- interface
│       └── user_service_impl.go
├── pkg/                        <- library yang aman di-reuse
│   ├── httputil/
│   │   └── response.go         <- JSON response helpers
│   └── logger/
│       └── logger.go
├── api/
│   └── openapi.yaml            <- API spec
├── migrations/                 <- SQL migration files
├── go.mod
└── go.sum
```

---

## Naming Convention

```
Package        : lowercase, satu kata         -> handler, service, repository
File           : snake_case                   -> user_handler.go, user_service.go
Struct / type  : PascalCase                   -> User, CreateUserDto
Interface      : PascalCase (deskriptif)      -> UserRepository, UserService
Method / func  : PascalCase (export) / camelCase (private)
Variabel lokal : camelCase, nama pendek       -> u, usr, ctx, err
Konstanta      : PascalCase (export) / camelCase (private)
Error sentinel : ErrXxx                       -> ErrNotFound, ErrUnauthorized
```

---

## Interface-Driven Design

```go
// internal/repository/user_repository.go
package repository

import (
  "context"
  "github.com/company/app/internal/domain"
)

type UserRepository interface {
  GetAll(ctx context.Context) ([]domain.User, error)
  GetByID(ctx context.Context, id int) (domain.User, error)
  Create(ctx context.Context, dto domain.CreateUserDto) (domain.User, error)
  Delete(ctx context.Context, id int) error
}
```

```go
// internal/repository/postgres/user_repo.go
package postgres

import (
  "context"
  "database/sql"
  "errors"
  "github.com/company/app/internal/domain"
)

type userRepo struct {
  db *sql.DB
}

// Pastikan implementasi memenuhi interface di compile time
var _ repository.UserRepository = (*userRepo)(nil)

func NewUserRepository(db *sql.DB) repository.UserRepository {
  return &userRepo{db: db}
}

func (r *userRepo) GetByID(ctx context.Context, id int) (domain.User, error) {
  var u domain.User
  err := r.db.QueryRowContext(ctx,
    `SELECT id, name, email, is_active FROM users WHERE id = $1`, id,
  ).Scan(&u.ID, &u.Name, &u.Email, &u.IsActive)

  if errors.Is(err, sql.ErrNoRows) {
    return domain.User{}, domain.ErrNotFound
  }
  return u, err
}
```

---

## Error Handling

```go
// internal/domain/errors.go
package domain

import "errors"

// Sentinel errors — gunakan errors.Is() untuk cek
var (
  ErrNotFound     = errors.New("not found")
  ErrUnauthorized = errors.New("unauthorized")
  ErrConflict     = errors.New("conflict")
)

// Wrap dengan context
func (s *userService) GetByID(ctx context.Context, id int) (User, error) {
  u, err := s.repo.GetByID(ctx, id)
  if err != nil {
    return User{}, fmt.Errorf("userService.GetByID id=%d: %w", id, err)
  }
  return u, nil
}

// Handler — map domain errors ke HTTP status
func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) {
  id, _ := strconv.Atoi(chi.URLParam(r, "id"))

  user, err := h.service.GetByID(r.Context(), id)
  if err != nil {
    switch {
    case errors.Is(err, domain.ErrNotFound):
      httputil.Error(w, http.StatusNotFound, "user tidak ditemukan")
    default:
      httputil.Error(w, http.StatusInternalServerError, "internal error")
    }
    return
  }

  httputil.JSON(w, http.StatusOK, user)
}
```

---

## Context Usage

```go
// BENAR — context sebagai parameter PERTAMA
func (s *userService) Create(ctx context.Context, dto CreateUserDto) (User, error) {
  return s.repo.Create(ctx, dto)
}

// BENAR — pass context ke semua downstream calls
func (h *handler) handleCreate(w http.ResponseWriter, r *http.Request) {
  ctx := r.Context()                         // ambil context dari request
  user, err := h.service.Create(ctx, dto)   // teruskan ke service
  ...
}

// SALAH — context.Background() di dalam handler (hilangkan deadline/cancel)
user, err := h.service.Create(context.Background(), dto)   // JANGAN

// SALAH — store context di struct
type MyService struct {
  ctx context.Context   // JANGAN — context harus per-call, bukan per-struct
}
```

---

## Concurrency Rules

```go
// BENAR — goroutine dengan WaitGroup + error channel
func fetchParallel(ctx context.Context, ids []int) ([]User, error) {
  results := make([]User, len(ids))
  errs := make(chan error, len(ids))
  var wg sync.WaitGroup

  for i, id := range ids {
    wg.Add(1)
    go func(idx, userID int) {
      defer wg.Done()
      u, err := repo.GetByID(ctx, userID)
      if err != nil {
        errs <- err
        return
      }
      results[idx] = u
    }(i, id)
  }

  wg.Wait()
  close(errs)

  if err := <-errs; err != nil {
    return nil, err
  }
  return results, nil
}

// SALAH — goroutine tanpa cleanup (goroutine leak)
go func() {
  for {
    process()          // jalan selamanya, tidak ada exit condition
  }
}()
```

---

## Testing (Table-Driven)

```go
// internal/service/user_service_test.go
package service_test

import (
  "context"
  "errors"
  "testing"

  "github.com/stretchr/testify/assert"
  "github.com/stretchr/testify/mock"
)

func TestUserService_GetByID(t *testing.T) {
  tests := []struct {
    name    string
    id      int
    mockFn  func(*MockUserRepository)
    want    domain.User
    wantErr error
  }{
    {
      name: "berhasil mengembalikan user",
      id:   1,
      mockFn: func(m *MockUserRepository) {
        m.On("GetByID", mock.Anything, 1).
          Return(domain.User{ID: 1, Name: "Budi"}, nil)
      },
      want: domain.User{ID: 1, Name: "Budi"},
    },
    {
      name: "return ErrNotFound jika user tidak ada",
      id:   99,
      mockFn: func(m *MockUserRepository) {
        m.On("GetByID", mock.Anything, 99).
          Return(domain.User{}, domain.ErrNotFound)
      },
      wantErr: domain.ErrNotFound,
    },
  }

  for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
      repo := new(MockUserRepository)
      tt.mockFn(repo)
      svc := service.NewUserService(repo)

      got, err := svc.GetByID(context.Background(), tt.id)

      if tt.wantErr != nil {
        assert.True(t, errors.Is(err, tt.wantErr))
      } else {
        assert.NoError(t, err)
        assert.Equal(t, tt.want, got)
      }
      repo.AssertExpectations(t)
    })
  }
}
```

---

## Checklist Sebelum Commit

- [ ] Semua fungsi yang bisa gagal return `error` sebagai nilai terakhir
- [ ] Tidak ada `panic` di luar `main()` / init
- [ ] `context.Context` sebagai parameter pertama semua fungsi IO
- [ ] Semua interface didefinisikan di sisi konsumer (bukan implementor)
- [ ] Tidak ada goroutine tanpa exit condition atau cancel mechanism
- [ ] Error di-wrap dengan `fmt.Errorf("...: %w", err)` untuk traceability
- [ ] Tidak ada `errors.New()` inline — gunakan sentinel errors di domain
- [ ] Table-driven test untuk semua service logic
- [ ] Tidak ada hardcoded credential — gunakan config struct dari env
- [ ] Jalankan: `go vet ./...`
- [ ] Jalankan: `go test ./... -race` (deteksi data race)
- [ ] Jalankan: `golangci-lint run`
