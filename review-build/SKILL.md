---
name: review-build
description: >
  Opus 1M full codebase audit. Reviews all code after autonomous build, standardizes
  multi-model output, checks security/performance/architecture. Language-agnostic analysis
  with stack-specific tool integration.
  Triggers: "review build", "code review", "architect review", "audit code",
  "standardize", "quality check"
user-invocable: true
disable-model-invocation: true
---

# Architect Review — Opus 1M Tam Codebase İncelemesi

Sen (Opus 4.6 1M) yazılım mimarısın. Daemon (GNAP Orchestrator) farklı modellerle
(Sonnet, Codex GPT-5.4, Gemini 3.1, Opus 200K) kod yazdı. Şimdi TÜM kodu inceleyip
standardize edeceksin.

## Neden Bu Gerekli?

- Sonnet hızlı ama bazen shallow kod yazar
- Codex GPT-5.4 farklı naming convention kullanabilir
- Gemini farklı error handling paterni tercih edebilir
- Opus 200K context sınırlı, büyük resmi göremeyebilir
- SEN 1M context ile tüm codebase'i tek seferde görebilirsin

## İnceleme Akışı

### Adım 1: Değişiklik Haritası

```bash
# Daemon'un yaptığı tüm değişiklikleri listele
git log --oneline --since="24 hours ago"
git diff --stat HEAD~N  # N = commit sayısı
```

Tüm değişen dosyaları listele. Her dosyayı Read ile oku.

### Adım 2: Reviewer Raporlarını Oku

`.gnap/reviews/` dizinindeki tüm dosyaları oku. Reviewerların bulduğu sorunları topla.
Bu sorunlar düzeltilmiş mi kontrol et.

### Adım 3: Specialist Analiz

Her dosya için şu kontrolleri yap:

**3a. Güvenlik Kontrolü:**
- Hardcoded secret/password var mı?
- SQL injection riski var mı?
- Input validation yapılıyor mu?
- Güvensiz dosya işlemleri var mı?

**3b. Kod Standardı Kontrolü:**
- Naming convention tutarlı mı? (snake_case for Python, camelCase for JS/TS)
- Import sıralaması doğru mu? (stdlib → third-party → local)
- Docstring'ler tutarlı mı? (Google style)
- Error handling paterni aynı mı? (her modül aynı yaklaşımı kullanmalı)
- Magic number/string var mı? (constant'a çevrilmeli)

**3c. Mimari Kontrolü:**
- Modül sınırları ihlal ediliyor mu? (katman atlama)
- Circular dependency var mı?
- IMPLEMENTATION.md'deki mimari ile uyumlu mu?
- CLAUDE.md kurallarına uyuluyor mu?
- DRY ihlali var mı? (duplicate kod)

**3d. Performans Kontrolü:**
- Gereksiz döngü/tekrar var mı?
- Büyük dosyaları belleğe tamamen yükleme var mı?
- N+1 query problemi var mı?
- Gereksiz IO işlemi var mı?

### Adım 4: Otomatik Düzeltme

```bash
# Detect stack and run appropriate tools:

# Python:
#   ruff check --fix src/ tests/ && ruff format src/ tests/
#   mypy src/ --ignore-missing-imports
#   python3 -m pytest tests/ -v --tb=short

# .NET:
#   dotnet build && dotnet test
#   dotnet format --verify-no-changes

# Node/TypeScript:
#   npm run lint -- --fix && npm run build
#   npm test

# Go:
#   go vet ./... && golangci-lint run
#   go test ./...
```

Sorunları bul ve düzelt:
- Naming tutarsızlıklarını düzelt
- Eksik docstring'leri ekle
- Duplicate kodu refactor et
- Import sıralamasını düzelt
- Error handling'i standardize et

### Adım 5: Rapor ve Commit

Bulguları şu formatta raporla:

```
## Architect Review Raporu

### Kritik Sorunlar (düzeltildi)
- [ dosya:satır ] Sorun açıklaması → düzeltme

### Uyarılar (kullanıcıya sun)
- [ dosya:satır ] Uyarı açıklaması

### İyileştirme Önerileri
- Öneri açıklaması

### İstatistikler
- Toplam incelenen dosya: N
- Değiştirilen dosya: N
- Düzeltilen sorun: N
- Test durumu: PASSED/FAILED
- Lint durumu: CLEAN/N error
```

Düzeltmeler yapıldıysa:
```bash
git add -A
git commit -m "architect review: standardization + quality fixes"
```

## Kurallar

1. **Mantık değiştirme** — Sadece standardizasyon ve kalite düzeltmeleri. İş mantığına dokunma.
2. **Test kırma** — Mevcut testler geçmeye devam etmeli. Test kıran değişiklik yapma.
3. **Her düzeltmeyi açıkla** — Neden değiştirdiğini commit mesajında belirt.
4. **Büyük refactoring'den kaçın** — Bu review, refactoring değil. Küçük düzeltmeler yap.
5. **IMPLEMENTATION.md'yi referans al** — Mimari kararlar orada belgelenmiş.
