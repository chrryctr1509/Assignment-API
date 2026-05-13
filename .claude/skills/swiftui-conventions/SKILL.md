---
name: swiftui-conventions
description: >
  Standar dan konvensi penulisan kode SwiftUI (iOS/macOS) untuk tim.
  Gunakan setiap kali fe-developer menulis atau memodifikasi
  kode SwiftUI — views, view models, models, dan services.
  Wajib diikuti agar UI konsisten dan maintainable.
---

# SwiftUI Conventions (iOS / macOS)

## Convention Adoption Gate

**Jalankan ini PERTAMA sebelum apply konvensi apapun.**

### Step 1 — Deteksi Project Type
```bash
find . -name "*.swift" 2>/dev/null | wc -l
```
Jika output `0` → **GREENFIELD**. Skip gate, apply konvensi penuh langsung.
Jika output > 0 → **EXISTING PROJECT**. Lanjut ke Step 2.

### Step 2 — Migration Risk Assessment
```bash
# Cek minimum deployment target
grep -E 'IPHONEOS_DEPLOYMENT_TARGET|MACOSX_DEPLOYMENT_TARGET' *.xcodeproj/project.pbxproj 2>/dev/null | head -3
# Cek apakah masih pakai ObservableObject lama
grep -rl "ObservableObject" . --include="*.swift" 2>/dev/null | wc -l
# Cek test suite
find . -name "*Tests.swift" 2>/dev/null | wc -l
# Jumlah view files
find . -name "*View.swift" -o -name "*Screen.swift" 2>/dev/null | wc -l
```

### Step 3 — Hitung Risk Score
```
+40  Deployment target < iOS 17 dan butuh pakai @Observable baru
+30  Tidak ada test suite
+20  > 20 view files yang harus diubah
+20  Banyak pakai UIKit patterns di SwiftUI views
+10  ViewModel masih pakai ObservableObject + @Published
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
- MVVM pattern: Views hanya render, logic di ViewModel / Service
- Gunakan `@Observable` (iOS 17+), bukan `ObservableObject` + `@Published`
- Prefer small, composable views — satu view satu tanggung jawab
- NavigationStack (bukan NavigationView yang deprecated)
- Semua string UI pakai `LocalizedStringKey` / `String(localized:)`

---

## Struktur Folder

```
ProjectName/
├── App/
│   ├── ProjectNameApp.swift    <- @main entry point
│   └── AppDependencies.swift   <- DI setup
├── Features/
│   └── Users/
│       ├── Models/
│       │   └── User.swift
│       ├── Services/
│       │   └── UserService.swift
│       ├── ViewModels/
│       │   └── UserListViewModel.swift
│       └── Views/
│           ├── UserListView.swift
│           ├── UserDetailView.swift
│           └── Components/
│               └── UserRowView.swift
├── Shared/
│   ├── Components/             <- reusable views
│   ├── Extensions/             <- Swift extensions
│   ├── Modifiers/              <- custom ViewModifiers
│   └── Theme/                  <- Color, Font constants
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings
ProjectNameTests/
ProjectNameUITests/
```

---

## Naming Convention

```
Tipe / Struct / Class : PascalCase           -> User, UserListViewModel
View                  : PascalCase + View    -> UserListView, UserRowView
ViewModel             : PascalCase + ViewModel -> UserListViewModel
Service               : PascalCase + Service -> UserService, AuthService
Protocol              : PascalCase + able/ing -> UserServiceable
Property / method     : camelCase            -> userName, fetchUsers()
Private property      : camelCase (no prefix, use private keyword)
Konstanta             : camelCase            -> primaryColor, cornerRadius
File                  : sama dengan type di dalamnya
```

---

## View Pattern

```swift
// Views/UserListView.swift
import SwiftUI

struct UserListView: View {
  @State private var viewModel = UserListViewModel()

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Users")
        .task { await viewModel.load() }
    }
  }

  // Pecah body menjadi computed properties — jaga body tetap ringkas
  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .loading:
      ProgressView()
    case .error(let message):
      ErrorView(message: message)
    case .loaded(let users):
      userList(users)
    }
  }

  private func userList(_ users: [User]) -> some View {
    List(users) { user in
      NavigationLink(value: user) {
        UserRowView(user: user)
      }
    }
    .navigationDestination(for: User.self) { user in
      UserDetailView(user: user)
    }
  }
}
```

---

## ViewModel Pattern (@Observable — iOS 17+)

```swift
// ViewModels/UserListViewModel.swift
import SwiftUI

enum ViewState<T> {
  case loading
  case loaded(T)
  case error(String)
}

@Observable
final class UserListViewModel {
  private(set) var state: ViewState<[User]> = .loading

  private let service: UserServiceable

  init(service: UserServiceable = UserService()) {
    self.service = service
  }

  @MainActor
  func load() async {
    state = .loading
    do {
      let users = try await service.fetchAll()
      state = .loaded(users)
    } catch {
      state = .error(error.localizedDescription)
    }
  }

  @MainActor
  func delete(_ user: User) async {
    do {
      try await service.delete(id: user.id)
      await load()
    } catch {
      state = .error(error.localizedDescription)
    }
  }
}
```

---

## Data Flow

```swift
// @State    — local mutable state milik view ini
// @Binding  — dua arah ke parent view
// @Environment — injected dependency (navigation, theme, dll)
// @Observable ViewModel — shared mutable state untuk fitur

// BENAR — pass binding ke child
struct ParentView: View {
  @State private var isPresented = false

  var body: some View {
    ChildView(isPresented: $isPresented)
  }
}

struct ChildView: View {
  @Binding var isPresented: Bool     // terima dari parent

  var body: some View {
    Button("Close") { isPresented = false }
  }
}
```

---

## Custom ViewModifier

```swift
// Shared/Modifiers/CardModifier.swift
struct CardModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding()
      .background(Color(.systemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
  }
}

extension View {
  func cardStyle() -> some View {
    modifier(CardModifier())
  }
}

// Penggunaan:
UserCard()
  .cardStyle()
```

---

## Service (API Layer)

```swift
// Services/UserService.swift
protocol UserServiceable {
  func fetchAll() async throws -> [User]
  func fetchById(_ id: Int) async throws -> User
  func create(_ dto: CreateUserDto) async throws -> User
  func delete(id: Int) async throws
}

final class UserService: UserServiceable {
  private let apiClient: APIClient

  init(apiClient: APIClient = .shared) {
    self.apiClient = apiClient
  }

  func fetchAll() async throws -> [User] {
    try await apiClient.get("/users")
  }

  func delete(id: Int) async throws {
    try await apiClient.delete("/users/\(id)")
  }
}
```

---

## Testing (XCTest)

```swift
// ProjectNameTests/Features/Users/UserListViewModelTests.swift
import XCTest
@testable import ProjectName

final class UserListViewModelTests: XCTestCase {
  func test_load_setsLoadedState_onSuccess() async {
    let mockService = MockUserService(users: [.stub()])
    let sut = UserListViewModel(service: mockService)

    await sut.load()

    if case .loaded(let users) = sut.state {
      XCTAssertEqual(users.count, 1)
    } else {
      XCTFail("Expected .loaded, got \(sut.state)")
    }
  }

  func test_load_setsErrorState_onFailure() async {
    let mockService = MockUserService(error: URLError(.badServerResponse))
    let sut = UserListViewModel(service: mockService)

    await sut.load()

    if case .error = sut.state { /* pass */ }
    else { XCTFail("Expected .error") }
  }
}
```

---

## Checklist Sebelum Commit

- [ ] View body tidak lebih dari ~30 baris — pecah ke computed properties / sub-views
- [ ] Gunakan `@Observable` bukan `ObservableObject` (jika iOS 17+)
- [ ] Semua async operasi pakai `async/await`, bukan completion handlers
- [ ] `@MainActor` dipakai di fungsi yang update UI state
- [ ] Tidak ada business logic di dalam `body`
- [ ] Protocol dipakai untuk service agar bisa di-mock di test
- [ ] Semua view punya Preview provider
- [ ] NavigationStack dipakai, bukan NavigationView
- [ ] Jalankan: Cmd+U untuk run tests
- [ ] Jalankan: Product > Analyze untuk static analysis
