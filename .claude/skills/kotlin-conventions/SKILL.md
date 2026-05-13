---
name: kotlin-conventions
description: >
  Standar dan konvensi penulisan kode Kotlin/Android untuk tim.
  Gunakan setiap kali fe-developer menulis atau memodifikasi
  kode Android — composables, ViewModels, repositories, dan tests.
  Wajib diikuti agar arsitektur konsisten dan bebas memory leak.
---

# Kotlin / Android Conventions (Jetpack Compose)

## Convention Adoption Gate

**Jalankan ini PERTAMA sebelum apply konvensi apapun.**

### Step 1 — Deteksi Project Type
```bash
find app/src/main/java -name "*.kt" 2>/dev/null | wc -l
```
Jika output `0` → **GREENFIELD**. Skip gate, apply konvensi penuh langsung.
Jika output > 0 → **EXISTING PROJECT**. Lanjut ke Step 2.

### Step 2 — Migration Risk Assessment
```bash
# Cek Compose version
grep -E 'compose_bom|compose-bom' app/build.gradle* 2>/dev/null | head -3
# Cek apakah masih ada View-based UI
find app/src/main/res/layout -name "*.xml" 2>/dev/null | wc -l
# Cek Hilt setup
grep -r 'hilt' app/build.gradle* 2>/dev/null | head -3
# Jumlah Composable files
grep -rl "@Composable" app/src/main/java 2>/dev/null | wc -l
```

### Step 3 — Hitung Risk Score
```
+40  Masih ada View-based layout XML yang harus dimigrasi ke Compose
+30  Tidak ada unit test / Compose test
+20  > 20 screen files yang harus diubah
+20  DI manual tanpa Hilt
+10  ViewModel masih pakai LiveData (disarankan migrasi ke StateFlow)
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
- MVVM dengan Repository pattern — ViewModel tidak boleh pegang Context
- Hilt untuk Dependency Injection — tidak boleh ada manual `new Repository()`
- StateFlow + collectAsStateWithLifecycle untuk UI state
- Structured concurrency: semua coroutine via `viewModelScope` atau `lifecycleScope`
- Null safety: hindari `!!`, pakai `?.`, `?:`, atau early return

---

## Struktur Folder

```
app/src/main/java/com/company/app/
├── di/                         <- Hilt modules
│   ├── NetworkModule.kt
│   └── RepositoryModule.kt
├── data/
│   ├── models/                 <- data classes + DTOs
│   ├── remote/
│   │   ├── api/                <- Retrofit interfaces
│   │   └── dto/                <- API response classes
│   ├── local/                  <- Room database, DAOs
│   └── repositories/           <- implementasi Repository
├── domain/
│   └── repositories/           <- Repository interfaces (contracts)
├── presentation/
│   └── users/
│       ├── UserListScreen.kt
│       ├── UserDetailScreen.kt
│       ├── UserListViewModel.kt
│       └── components/
│           └── UserCard.kt
├── shared/
│   ├── components/             <- reusable Composables
│   ├── theme/                  <- Theme, Color, Typography
│   └── utils/                  <- extension functions, helpers
└── MainActivity.kt
app/src/test/                   <- unit tests
app/src/androidTest/            <- UI / Compose tests
```

---

## Naming Convention

```
Kelas / Object    : PascalCase              -> UserRepository, UserListViewModel
Composable        : PascalCase              -> UserCard, UserListScreen
Interface         : PascalCase (tanpa I)    -> UserRepository (bukan IUserRepository)
Fungsi / var      : camelCase               -> fetchUsers(), userName
Konstanta         : SCREAMING_SNAKE_CASE    -> MAX_RETRY_COUNT
Package           : lowercase               -> com.company.app.users
File              : sama dengan kelas utama -> UserListViewModel.kt
```

---

## Composable Patterns

```kotlin
// BENAR — state hoisting, preview friendly
@Composable
fun UserCard(
  user: User,
  onDelete: (Int) -> Unit,
  modifier: Modifier = Modifier,        // selalu sediakan modifier param
) {
  Card(modifier = modifier.fillMaxWidth()) {
    Row(
      modifier = Modifier.padding(16.dp),
      horizontalArrangement = Arrangement.SpaceBetween,
    ) {
      Column {
        Text(text = user.name, style = MaterialTheme.typography.titleMedium)
        Text(text = user.email, style = MaterialTheme.typography.bodySmall)
      }
      IconButton(onClick = { onDelete(user.id) }) {
        Icon(Icons.Default.Delete, contentDescription = "Hapus")
      }
    }
  }
}

@Preview(showBackground = true)
@Composable
private fun UserCardPreview() {
  AppTheme {
    UserCard(
      user = User(id = 1, name = "Budi", email = "budi@mail.com"),
      onDelete = {},
    )
  }
}
```

---

## ViewModel Pattern

```kotlin
// presentation/users/UserListViewModel.kt
@HiltViewModel
class UserListViewModel @Inject constructor(
  private val repository: UserRepository,
) : ViewModel() {

  // Satu sealed UI state — bukan banyak boolean
  sealed class UiState {
    data object Loading : UiState()
    data class Success(val users: List<User>) : UiState()
    data class Error(val message: String) : UiState()
  }

  private val _uiState = MutableStateFlow<UiState>(UiState.Loading)
  val uiState: StateFlow<UiState> = _uiState.asStateFlow()

  init {
    loadUsers()
  }

  fun loadUsers() {
    viewModelScope.launch {
      _uiState.value = UiState.Loading
      repository.getAll()
        .onSuccess { _uiState.value = UiState.Success(it) }
        .onFailure { _uiState.value = UiState.Error(it.message ?: "Unknown error") }
    }
  }

  fun delete(id: Int) {
    viewModelScope.launch {
      repository.delete(id)
        .onSuccess { loadUsers() }
        .onFailure { _uiState.value = UiState.Error(it.message ?: "Delete failed") }
    }
  }
}
```

---

## Screen (Collect State)

```kotlin
@Composable
fun UserListScreen(
  viewModel: UserListViewModel = hiltViewModel(),
) {
  val uiState by viewModel.uiState.collectAsStateWithLifecycle()

  when (val state = uiState) {
    is UiState.Loading -> LoadingIndicator()
    is UiState.Error   -> ErrorMessage(state.message, onRetry = viewModel::loadUsers)
    is UiState.Success -> UserList(
      users    = state.users,
      onDelete = viewModel::delete,
    )
  }
}
```

---

## Repository Pattern

```kotlin
// domain/repositories/UserRepository.kt
interface UserRepository {
  suspend fun getAll(): Result<List<User>>
  suspend fun getById(id: Int): Result<User>
  suspend fun create(dto: CreateUserDto): Result<User>
  suspend fun delete(id: Int): Result<Unit>
}

// data/repositories/UserRepositoryImpl.kt
class UserRepositoryImpl @Inject constructor(
  private val api: UserApi,
) : UserRepository {

  override suspend fun getAll(): Result<List<User>> = runCatching {
    api.getUsers().map { it.toDomain() }
  }

  override suspend fun delete(id: Int): Result<Unit> = runCatching {
    api.deleteUser(id)
  }
}
```

---

## Coroutines Rules

```kotlin
// BENAR — viewModelScope untuk ViewModel
viewModelScope.launch { ... }

// BENAR — lifecycleScope untuk Activity/Fragment
lifecycleScope.launch { ... }

// BENAR — context switching
withContext(Dispatchers.IO) {
  // operasi IO
}

// SALAH — GlobalScope (goroutine leak)
GlobalScope.launch { ... }

// SALAH — blokir main thread
runBlocking { fetchData() }   // hanya boleh di tests
```

---

## Testing

```kotlin
// test/users/UserListViewModelTest.kt
@OptIn(ExperimentalCoroutinesApi::class)
class UserListViewModelTest {

  @get:Rule
  val mainDispatcherRule = MainDispatcherRule()

  private val repository = mockk<UserRepository>()
  private lateinit var sut: UserListViewModel

  @BeforeEach
  fun setup() {
    sut = UserListViewModel(repository)
  }

  @Test
  fun `loadUsers emits Success saat repository berhasil`() = runTest {
    val users = listOf(User(id = 1, name = "Budi", email = "budi@mail.com"))
    coEvery { repository.getAll() } returns Result.success(users)

    sut.loadUsers()
    advanceUntilIdle()

    assertIs<UserListViewModel.UiState.Success>(sut.uiState.value)
    assertEquals(users, (sut.uiState.value as UserListViewModel.UiState.Success).users)
  }
}
```

---

## Checklist Sebelum Commit

- [ ] Semua Composable punya `modifier: Modifier = Modifier` parameter
- [ ] Semua Composable punya `@Preview`
- [ ] ViewModel tidak pegang `Context` — inject string resources via `@StringRes` jika perlu
- [ ] Gunakan `collectAsStateWithLifecycle`, bukan `collectAsState` (untuk lifecycle awareness)
- [ ] Tidak ada `!!` operator kecuali ada alasan kuat dengan komentar
- [ ] Semua coroutine pakai `viewModelScope` atau `lifecycleScope`, bukan `GlobalScope`
- [ ] Repository interface ada di domain layer, implementasi di data layer
- [ ] Hilt `@HiltViewModel` di semua ViewModel
- [ ] Unit test ditulis untuk semua ViewModel
- [ ] Jalankan: `./gradlew test`
- [ ] Jalankan: `./gradlew lint`
