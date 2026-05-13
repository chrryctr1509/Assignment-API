---
name: flutter-conventions
description: >
  Standar dan konvensi penulisan kode Flutter/Dart untuk tim.
  Gunakan setiap kali fe-developer menulis atau memodifikasi
  kode Flutter — widgets, state management, services, dan tests.
  Wajib diikuti agar codebase konsisten dan performant.
---

# Flutter / Dart Conventions

## Convention Adoption Gate

**Jalankan ini PERTAMA sebelum apply konvensi apapun.**

### Step 1 — Deteksi Project Type
```bash
find lib -name "*.dart" 2>/dev/null | wc -l
```
Jika output `0` → **GREENFIELD**. Skip gate, apply konvensi penuh langsung.
Jika output > 0 → **EXISTING PROJECT**. Lanjut ke Step 2.

### Step 2 — Migration Risk Assessment
```bash
# Cek Flutter SDK version
cat pubspec.yaml 2>/dev/null | grep -E 'flutter:|sdk:' | head -5
# Cek state management yang dipakai
cat pubspec.yaml 2>/dev/null | grep -E 'riverpod|bloc|provider|getx' | head -5
# Cek test suite
find test -name "*_test.dart" 2>/dev/null | wc -l
# Jumlah widget files
find lib -name "*.dart" 2>/dev/null | wc -l
```

### Step 3 — Hitung Risk Score
```
+40  State management lama (Provider/GetX) dan butuh migrasi ke Riverpod
+30  Tidak ada test suite
+20  > 20 widget files yang harus diubah
+20  Tidak ada const constructors di widget yang ada
+10  StatefulWidget berlebihan yang bisa diganti Riverpod
```

### Step 4 — Decision
```
< 40%  → Apply konvensi penuh.
40-79% → STOP. Tampilkan ke programmer:
         "Convention migration risk: [N]%
          Impact: [N] files | Reason: [alasan]
          APPROVE → proceed | SKIP → keep existing + catat tech debt"
>= 80% → KEEP AS IS. Otomatis tanpa tanya.
         Catat ke .claude/memory/tech-debt.md:
         "[YYYY-MM-DD] Flutter convention migration skipped — risk [N]% ([alasan])"
```

---

## Prinsip Utama
- Gunakan `const` constructors di mana pun memungkinkan
- Composition over inheritance — prefer small, focused widgets
- State management dengan Riverpod (versi 2.x+)
- Pisahkan UI dari logic: widgets tipis, logic di providers/services
- Semua string UI di-localize (l10n), tidak hardcode

---

## Struktur Folder

```
lib/
├── main.dart                   <- entry point
├── app.dart                    <- MaterialApp / routing setup
├── core/
│   ├── constants/              <- warna, dimensi, string keys
│   ├── errors/                 <- exception classes
│   ├── extensions/             <- extension methods
│   ├── theme/                  <- ThemeData, ColorScheme
│   └── utils/                  <- helper functions
├── features/
│   └── users/
│       ├── data/
│       │   ├── models/         <- data classes + fromJson/toJson
│       │   └── repositories/   <- implementasi repository
│       ├── domain/
│       │   └── providers/      <- Riverpod providers
│       └── presentation/
│           ├── screens/        <- screen-level widgets
│           └── widgets/        <- widget kecil reusable
├── shared/
│   ├── widgets/                <- komponen UI generik
│   └── services/               <- HTTP client, storage
test/
├── features/
│   └── users/                  <- mirror dari lib/features/
└── shared/
assets/
├── images/
├── icons/
└── fonts/
```

---

## Naming Convention

```
File widget    : snake_case           -> user_card.dart, login_screen.dart
File model     : snake_case + _model  -> user_model.dart
File provider  : snake_case + _provider -> user_provider.dart
File repo      : snake_case + _repository -> user_repository.dart
Kelas          : PascalCase           -> UserCard, LoginScreen
Variable/func  : camelCase            -> userName, fetchUser()
Konstanta      : camelCase (local) / kCamelCase (global) -> kPrimaryColor
Private        : _camelCase           -> _isLoading
```

---

## Widget Patterns

```dart
// BENAR — StatelessWidget dengan const constructor
class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.user,
    this.onTap,
  });

  final User user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(user.name),
        subtitle: Text(user.email),
        onTap: onTap,
      ),
    );
  }
}

// SALAH — tidak ada const, tidak ada key
class UserCard extends StatelessWidget {
  UserCard({this.user});   // missing const, missing required, missing key
  ...
}
```

---

## State Management (Riverpod)

```dart
// lib/features/users/domain/providers/user_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_provider.g.dart';

// AsyncNotifier untuk operasi async
@riverpod
class UserList extends _$UserList {
  @override
  Future<List<User>> build() async {
    return ref.read(userRepositoryProvider).getAll();
  }

  Future<void> create(CreateUserDto dto) async {
    await ref.read(userRepositoryProvider).create(dto);
    ref.invalidateSelf(); // refresh list
  }

  Future<void> delete(int id) async {
    await ref.read(userRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

// Gunakan di widget dengan ConsumerWidget
class UserListScreen extends ConsumerWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(userListProvider);

    return usersAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => ErrorWidget(e.toString()),
      data: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, i) => UserCard(user: users[i]),
      ),
    );
  }
}
```

---

## Data Model

```dart
// lib/features/users/data/models/user_model.dart
// Gunakan freezed atau plain Dart — konsisten per project
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.isActive,
  });

  final int id;
  final String name;
  final String email;
  final bool isActive;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        isActive: json['is_active'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'is_active': isActive,
      };
}
```

---

## Material 3 Theming

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,           // WAJIB aktifkan M3
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
        ),
        typography: Typography.material2021(),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        typography: Typography.material2021(),
      );
}
```

---

## Performance Rules

```dart
// Gunakan const di mana pun bisa
const SizedBox(height: 16)          // BENAR
SizedBox(height: 16)                // SALAH — tidak perlu create baru tiap rebuild

// RepaintBoundary untuk animasi berat
RepaintBoundary(
  child: ComplexAnimatedWidget(),
)

// ListView.builder untuk list panjang — JANGAN ListView biasa
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(item: items[index]),
)

// JANGAN setState di dalam build()
// JANGAN logic berat di build() — pindah ke provider
```

---

## Testing

```dart
// test/features/users/presentation/user_card_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  group('UserCard', () {
    testWidgets('menampilkan nama dan email user', (tester) async {
      const user = User(id: 1, name: 'Budi', email: 'budi@mail.com', isActive: true);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: UserCard(user: user))),
      );

      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('budi@mail.com'), findsOneWidget);
    });

    testWidgets('memanggil onTap saat di-tap', (tester) async {
      var tapped = false;
      const user = User(id: 1, name: 'Budi', email: 'budi@mail.com', isActive: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserCard(user: user, onTap: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.byType(UserCard));
      expect(tapped, isTrue);
    });
  });
}
```

---

## Checklist Sebelum Commit

- [ ] Semua widget punya `const` constructor dan `super.key`
- [ ] Tidak ada `setState` di dalam `build()`
- [ ] Semua list panjang pakai `ListView.builder`, bukan `ListView`
- [ ] State management via Riverpod, bukan raw `setState` untuk shared state
- [ ] Semua model punya `fromJson` / `toJson`
- [ ] Tidak ada hardcoded color — gunakan `Theme.of(context).colorScheme`
- [ ] `useMaterial3: true` ada di ThemeData
- [ ] Widget test ditulis untuk semua widget baru
- [ ] Jalankan: `flutter analyze`
- [ ] Jalankan: `flutter test`
