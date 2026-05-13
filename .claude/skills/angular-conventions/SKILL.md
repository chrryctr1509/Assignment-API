---
name: angular-conventions
description: >
  Standar dan konvensi penulisan kode Angular 17+ untuk tim.
  Gunakan setiap kali fe-developer menulis atau memodifikasi
  kode Angular — standalone components, signals, services, dan tests.
  Wajib diikuti agar arsitektur konsisten dan bebas memory leak.
---

# Angular 17+ Conventions (Standalone + Signals)

## Convention Adoption Gate

**Jalankan ini PERTAMA sebelum apply konvensi apapun.**

### Step 1 — Deteksi Project Type
```bash
find src -name "*.ts" -o -name "*.html" 2>/dev/null | wc -l
```
Jika output `0` → **GREENFIELD**. Skip gate, apply konvensi penuh langsung.
Jika output > 0 → **EXISTING PROJECT**. Lanjut ke Step 2.

### Step 2 — Migration Risk Assessment
```bash
# Cek Angular version
cat package.json 2>/dev/null | grep '"@angular/core"' | head -1
# Cek apakah masih NgModule based
grep -rl "NgModule" src --include="*.ts" 2>/dev/null | wc -l
# Cek apakah masih pakai class-based services tanpa providedIn
grep -rl "providers:" src --include="*.ts" 2>/dev/null | wc -l
# Cek test suite
find src -name "*.spec.ts" 2>/dev/null | wc -l
```

### Step 3 — Hitung Risk Score
```
+40  Masih NgModule dan butuh migrasi ke standalone
+30  Tidak ada test suite
+20  > 20 component files yang harus diubah
+20  Tidak ada TypeScript strict mode
+10  Masih pakai EventEmitter + ngZone secara eksplisit
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
- Standalone components — tidak ada NgModules untuk kode baru
- Signals untuk state lokal dan reaktivitas — bukan `BehaviorSubject` + `async pipe` untuk simple cases
- `inject()` function di constructor area — bukan constructor parameter injection untuk kode baru
- `takeUntilDestroyed()` untuk unsubscribe — tidak ada manual `ngOnDestroy` + Subject
- Defer blocks untuk lazy loading — bukan `*ngIf` dengan lazy routes

---

## Struktur Folder

```
src/
├── app/
│   ├── app.config.ts           <- provideRouter, provideHttpClient, dll
│   ├── app.routes.ts           <- route definitions
│   ├── app.component.ts
│   └── features/
│       └── users/
│           ├── users.routes.ts
│           ├── components/
│           │   ├── user-list/
│           │   │   ├── user-list.component.ts
│           │   │   └── user-list.component.html
│           │   └── user-card/
│           │       └── user-card.component.ts
│           ├── services/
│           │   └── user.service.ts
│           └── models/
│               └── user.model.ts
├── shared/
│   ├── components/             <- reusable standalone components
│   ├── directives/
│   ├── pipes/
│   └── services/
└── environments/
    ├── environment.ts
    └── environment.prod.ts
```

---

## Naming Convention

```
File component     : kebab-case + .component  -> user-list.component.ts
File service       : kebab-case + .service    -> user.service.ts
File model         : kebab-case + .model      -> user.model.ts
File pipe          : kebab-case + .pipe       -> format-date.pipe.ts
File directive     : kebab-case + .directive  -> click-outside.directive.ts
Kelas component    : PascalCase + Component   -> UserListComponent
Kelas service      : PascalCase + Service     -> UserService
Interface          : PascalCase               -> User, CreateUserDto
Selector           : kebab-case dengan prefix -> app-user-list, app-user-card
Member / method    : camelCase               -> userName, fetchUsers()
```

---

## Standalone Component Pattern

```typescript
// features/users/components/user-card/user-card.component.ts
import { Component, input, output, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import type { User } from '../../models/user.model';

@Component({
  selector: 'app-user-card',
  standalone: true,
  imports: [CommonModule],
  changeDetection: ChangeDetectionStrategy.OnPush,   // WAJIB untuk performa
  template: `
    <div class="card">
      <h3>{{ user().name }}</h3>
      <p>{{ user().email }}</p>
      <button (click)="onDelete()">Hapus</button>
    </div>
  `,
})
export class UserCardComponent {
  // Signal-based inputs (Angular 17+)
  user = input.required<User>();

  // Signal-based outputs
  delete = output<number>();

  onDelete() {
    this.delete.emit(this.user().id);
  }
}
```

---

## Signals untuk State

```typescript
// features/users/components/user-list/user-list.component.ts
import {
  Component, inject, signal, computed, OnInit, ChangeDetectionStrategy,
} from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { UserService } from '../../services/user.service';
import type { User } from '../../models/user.model';

@Component({
  selector: 'app-user-list',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (isLoading()) {
      <app-loading />
    } @else if (error()) {
      <app-error [message]="error()!" (retry)="loadUsers()" />
    } @else {
      @for (user of users(); track user.id) {
        <app-user-card [user]="user" (delete)="deleteUser($event)" />
      } @empty {
        <p>Tidak ada user.</p>
      }
    }
  `,
})
export class UserListComponent implements OnInit {
  private readonly userService = inject(UserService);

  // Signals untuk UI state
  users = signal<User[]>([]);
  isLoading = signal(false);
  error = signal<string | null>(null);

  // Computed signal
  activeUsers = computed(() => this.users().filter(u => u.isActive));

  ngOnInit() {
    this.loadUsers();
  }

  loadUsers() {
    this.isLoading.set(true);
    this.error.set(null);

    this.userService.getAll()
      .pipe(takeUntilDestroyed())        // auto-unsubscribe saat destroy
      .subscribe({
        next: (users) => {
          this.users.set(users);
          this.isLoading.set(false);
        },
        error: (e) => {
          this.error.set(e.message);
          this.isLoading.set(false);
        },
      });
  }

  deleteUser(id: number) {
    this.userService.delete(id).subscribe(() => {
      this.users.update(users => users.filter(u => u.id !== id));
    });
  }
}
```

---

## Service Pattern

```typescript
// features/users/services/user.service.ts
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '@env/environment';
import type { User, CreateUserDto } from '../models/user.model';

@Injectable({ providedIn: 'root' })     // WAJIB providedIn root atau feature
export class UserService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${environment.apiUrl}/users`;

  getAll(): Observable<User[]> {
    return this.http.get<User[]>(this.baseUrl);
  }

  getById(id: number): Observable<User> {
    return this.http.get<User>(`${this.baseUrl}/${id}`);
  }

  create(dto: CreateUserDto): Observable<User> {
    return this.http.post<User>(this.baseUrl, dto);
  }

  delete(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}`);
  }
}
```

---

## RxJS Rules

```typescript
// BENAR — takeUntilDestroyed (Angular 16+)
this.service.getUsers()
  .pipe(takeUntilDestroyed())
  .subscribe(...);

// BENAR — async pipe di template (auto-unsubscribe)
// template: <div *ngIf="users$ | async as users">

// SALAH — subscribe tanpa unsubscribe (memory leak)
ngOnInit() {
  this.service.getUsers().subscribe(...);  // LEAK!
}

// SALAH — nested subscribe (callback hell)
this.service.getUsers().subscribe(users => {
  this.service.getDetails(users[0].id).subscribe(...);  // pakai switchMap
});
```

---

## Testing (Jest + Angular Testing Library)

```typescript
// features/users/components/user-card/user-card.component.spec.ts
import { render, screen, fireEvent } from '@testing-library/angular';
import { UserCardComponent } from './user-card.component';
import { signal } from '@angular/core';

const mockUser = { id: 1, name: 'Budi', email: 'budi@mail.com', isActive: true };

describe('UserCardComponent', () => {
  it('menampilkan nama dan email user', async () => {
    await render(UserCardComponent, {
      componentInputs: { user: mockUser },
    });

    expect(screen.getByText('Budi')).toBeInTheDocument();
    expect(screen.getByText('budi@mail.com')).toBeInTheDocument();
  });

  it('emit delete saat tombol ditekan', async () => {
    const deleteHandler = jest.fn();

    await render(UserCardComponent, {
      componentInputs: { user: mockUser },
      on: { delete: deleteHandler },
    });

    fireEvent.click(screen.getByRole('button', { name: /hapus/i }));
    expect(deleteHandler).toHaveBeenCalledWith(1);
  });
});
```

---

## Checklist Sebelum Commit

- [ ] Semua component adalah `standalone: true`
- [ ] Semua component pakai `ChangeDetectionStrategy.OnPush`
- [ ] Gunakan signal-based `input()` dan `output()` untuk Angular 17+
- [ ] Semua subscription menggunakan `takeUntilDestroyed()` atau `async pipe`
- [ ] Service pakai `providedIn: 'root'` atau lazy feature provider
- [ ] Tidak ada manual `ngOnDestroy` hanya untuk unsubscribe
- [ ] Template pakai `@if`, `@for`, `@defer` (bukan `*ngIf`, `*ngFor`)
- [ ] Tidak ada hardcoded API URL — gunakan `environment.apiUrl`
- [ ] Test ditulis untuk semua component dan service baru
- [ ] Jalankan: `ng lint` dan `ng test`
