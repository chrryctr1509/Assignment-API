---
name: vue-conventions
description: >
  Standar dan konvensi penulisan kode Vue 3 + Composition API untuk tim.
  Gunakan setiap kali fe-developer menulis atau memodifikasi
  kode frontend — components, composables, stores, dan views.
  Wajib diikuti agar codebase konsisten dan type-safe.
---

# Vue 3 + Composition API Conventions

## Convention Adoption Gate

**Jalankan ini PERTAMA sebelum apply konvensi apapun.**

### Step 1 — Deteksi Project Type
```bash
find src -name "*.vue" -o -name "*.ts" 2>/dev/null | wc -l
```
Jika output `0` → **GREENFIELD**. Skip gate, apply konvensi penuh langsung.
Jika output > 0 → **EXISTING PROJECT**. Lanjut ke Step 2.

### Step 2 — Migration Risk Assessment
```bash
# Cek Vue + Vite version
cat package.json 2>/dev/null | grep -E '"vue"|"vite"|"nuxt"' | head -5
# Cek TypeScript
ls tsconfig.json 2>/dev/null && echo "HAS_TS" || echo "NO_TS"
# Cek apakah masih Options API
grep -rl "export default {" src --include="*.vue" 2>/dev/null | wc -l
# Cek Pinia
cat package.json 2>/dev/null | grep '"pinia"'
# Cek test suite
cat package.json 2>/dev/null | grep '"vitest"'
```

### Step 3 — Hitung Risk Score
```
+40  Masih Options API dan butuh migrasi ke Composition API / <script setup>
+30  Tidak ada test suite
+20  > 20 component files yang harus diubah
+20  Tidak ada TypeScript
+10  Masih pakai Vuex (disarankan migrasi ke Pinia)
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
- Gunakan `<script setup lang="ts">` — bukan Options API
- TypeScript wajib — tidak boleh ada implicit `any`
- Pinia untuk state management — bukan Vuex
- Composables untuk logic reusable — satu composable satu tanggung jawab
- Pisahkan UI dari logic: komponen tipis, logic di composables/stores

---

## Struktur Folder

```
src/
├── assets/                     <- gambar, font, style global
├── components/                 <- komponen reusable
│   ├── ui/                     <- Button, Input, Modal, dll
│   └── layout/                 <- Navbar, Sidebar, Footer
├── composables/                <- composable functions (useXxx)
│   ├── useUsers.ts
│   └── useAuth.ts
├── layouts/                    <- layout templates
│   └── DefaultLayout.vue
├── pages/ (atau views/)        <- route-level components
│   ├── users/
│   │   ├── UserListPage.vue
│   │   └── UserDetailPage.vue
│   └── auth/
│       └── LoginPage.vue
├── router/
│   └── index.ts
├── services/                   <- API calls
│   └── user.service.ts
├── stores/                     <- Pinia stores
│   └── auth.store.ts
├── types/                      <- TypeScript interfaces
│   └── user.types.ts
└── utils/                      <- helper functions
    └── format.ts
```

---

## Naming Convention

```
Component file     : PascalCase             -> UserCard.vue, LoginForm.vue
Page / View file   : PascalCase + Page      -> UserListPage.vue
Composable file    : camelCase + use prefix -> useUsers.ts, useAuth.ts
Store file         : camelCase + .store     -> auth.store.ts, user.store.ts
Service file       : camelCase + .service   -> user.service.ts
Types file         : camelCase + .types     -> user.types.ts
Interface          : PascalCase + I prefix  -> IUser, ICreateUserDto
```

---

## Component Pattern

```vue
<!-- components/users/UserCard.vue -->
<script setup lang="ts">
import type { IUser } from '@/types/user.types'

// defineProps dengan TypeScript generics
const props = defineProps<{
  user: IUser
  compact?: boolean
}>()

// defineEmits dengan TypeScript
const emit = defineEmits<{
  delete: [id: number]
  edit: [user: IUser]
}>()

function handleDelete() {
  emit('delete', props.user.id)
}
</script>

<template>
  <div class="rounded-lg border p-4">
    <h3 class="font-semibold">{{ user.name }}</h3>
    <p v-if="!compact" class="text-sm text-gray-500">{{ user.email }}</p>
    <button @click="handleDelete">Hapus</button>
  </div>
</template>
```

---

## Composable Pattern

```typescript
// composables/useUsers.ts
import { ref, computed } from 'vue'
import type { IUser, ICreateUserDto } from '@/types/user.types'
import { userService } from '@/services/user.service'

export function useUsers() {
  const users = ref<IUser[]>([])
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  const activeUsers = computed(() =>
    users.value.filter(u => u.isActive)
  )

  async function fetchAll() {
    isLoading.value = true
    error.value = null
    try {
      users.value = await userService.getAll()
    } catch (e) {
      error.value = (e as Error).message
    } finally {
      isLoading.value = false
    }
  }

  async function create(dto: ICreateUserDto) {
    const newUser = await userService.create(dto)
    users.value.push(newUser)
    return newUser
  }

  async function remove(id: number) {
    await userService.delete(id)
    users.value = users.value.filter(u => u.id !== id)
  }

  return {
    users: readonly(users),
    activeUsers,
    isLoading: readonly(isLoading),
    error: readonly(error),
    fetchAll,
    create,
    remove,
  }
}
```

---

## Pinia Store

```typescript
// stores/auth.store.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { IUser } from '@/types/user.types'

// Gunakan Composition API style (bukan Options style)
export const useAuthStore = defineStore('auth', () => {
  const user = ref<IUser | null>(null)
  const token = ref<string | null>(localStorage.getItem('token'))

  const isAuthenticated = computed(() => !!token.value)

  function setUser(newUser: IUser, newToken: string) {
    user.value = newUser
    token.value = newToken
    localStorage.setItem('token', newToken)
  }

  function logout() {
    user.value = null
    token.value = null
    localStorage.removeItem('token')
  }

  return { user, token, isAuthenticated, setUser, logout }
})
```

---

## Reactivity Rules

```typescript
// BENAR — destructure dengan toRefs untuk menjaga reaktivitas
const { user, isLoading, fetchAll } = toRefs(useAuthStore())

// SALAH — langsung destructure store hilangkan reaktivitas
const { user } = useAuthStore()    // user tidak reaktif lagi!

// BENAR — reactive dengan ref
const count = ref(0)
count.value++                      // akses via .value

// BENAR — computed untuk nilai turunan
const fullName = computed(() => `${firstName.value} ${lastName.value}`)

// SALAH — mutasi prop langsung
props.user.name = 'Baru'          // gunakan emit 'update:user' atau event
```

---

## Service (API Calls)

```typescript
// services/user.service.ts
import { api } from '@/lib/axios'
import type { IUser, ICreateUserDto } from '@/types/user.types'

export const userService = {
  async getAll(): Promise<IUser[]> {
    const { data } = await api.get('/users')
    return data
  },

  async getById(id: number): Promise<IUser> {
    const { data } = await api.get(`/users/${id}`)
    return data
  },

  async create(payload: ICreateUserDto): Promise<IUser> {
    const { data } = await api.post('/users', payload)
    return data
  },

  async delete(id: number): Promise<void> {
    await api.delete(`/users/${id}`)
  },
}
```

---

## Testing (Vitest + Vue Test Utils)

```typescript
// tests/components/UserCard.test.ts
import { describe, it, expect, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import UserCard from '@/components/users/UserCard.vue'
import type { IUser } from '@/types/user.types'

const mockUser: IUser = {
  id: 1, name: 'Budi', email: 'budi@mail.com', isActive: true, createdAt: ''
}

describe('UserCard', () => {
  it('menampilkan nama dan email', () => {
    const wrapper = mount(UserCard, { props: { user: mockUser } })
    expect(wrapper.text()).toContain('Budi')
    expect(wrapper.text()).toContain('budi@mail.com')
  })

  it('emit delete saat tombol ditekan', async () => {
    const wrapper = mount(UserCard, { props: { user: mockUser } })
    await wrapper.find('button').trigger('click')
    expect(wrapper.emitted('delete')?.[0]).toEqual([1])
  })
})
```

---

## Checklist Sebelum Commit

- [ ] Semua component pakai `<script setup lang="ts">`
- [ ] Tidak ada `any` type yang tidak perlu
- [ ] `defineProps` dan `defineEmits` pakai TypeScript generics
- [ ] Tidak ada mutasi prop langsung — gunakan emit
- [ ] Store destructure pakai `storeToRefs()` agar tetap reaktif
- [ ] List selalu punya `:key` yang unik dan stabil
- [ ] Semua async composable handle loading + error state
- [ ] Tidak ada API call langsung di template atau component setup
- [ ] Vitest test ditulis untuk semua component dan composable baru
- [ ] Jalankan: `pnpm lint` dan `pnpm test`


---

## Modal Pattern — Teleport (SIM-11: L41)

<!-- Added by SIM-11: prevent z-index/overflow clipping issues -->

Selalu gunakan `<Teleport to="body">` untuk modal dan overlay.
Render inline bisa terpotong oleh ancestor `overflow: hidden`, `transform`,
atau z-index stacking context.

```vue
<template>
  <button @click="showModal = true">Open</button>

  <!-- Teleport ke body agar tidak terpotong -->
  <Teleport to="body">
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal-content">
        <slot />
        <button @click="showModal = false">Tutup</button>
      </div>
    </div>
  </Teleport>
</template>
```

Scoped CSS (`<style scoped>`) tetap bekerja pada elemen yang di-teleport
karena Vue menambahkan `data-v-*` attribute sebelum teleport.

---

## Error Handling Pattern (SIM-11: L16, L28)

<!-- Added by SIM-11: every API call must have try/catch with user-visible error -->

### Single API Call

```vue
<script setup lang="ts">
const data = ref<Task[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

onMounted(async () => {
  try {
    data.value = await taskService.getAll()
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div v-if="loading" class="animate-pulse"><!-- skeleton --></div>
  <div v-else-if="error" class="text-red-500">{{ error }}</div>
  <div v-else><!-- render data --></div>
</template>
```

### Parallel API Calls

```typescript
// ❌ SALAH — sequential, no error handling
const tasks = await taskService.getAll()
const users = await userService.getAll()

// ✅ BENAR — parallel + error handling
try {
  const [tasks, users] = await Promise.all([
    taskService.getAll(),
    userService.getAll(),
  ])
} catch (e) {
  error.value = (e as Error).message
}
```

---

## Loading States — Skeleton (SIM-11: L27)

<!-- Added by SIM-11: skeleton loading, not spinners -->

Dashboard dan halaman data-heavy HARUS punya skeleton loading dari hari pertama.
Gunakan pulse animation skeleton, BUKAN spinner.

```vue
<template>
  <!-- Skeleton state -->
  <div v-if="loading" class="space-y-4">
    <div class="h-8 bg-gray-200 rounded animate-pulse w-1/3" />
    <div class="h-4 bg-gray-200 rounded animate-pulse w-2/3" />
    <div class="h-4 bg-gray-200 rounded animate-pulse w-1/2" />
  </div>

  <!-- Data state -->
  <div v-else>
    <!-- real content -->
  </div>
</template>
```
