---
name: auto-build
description: >
  Sıfırdan proje planlama ve otonom çoklu-ajan geliştirme. Üç fazda çalışır:
  (A) İnteraktif keşif ile proje dökümanları oluşturur (SPECIFICATION, IMPLEMENTATION, TASKS),
  (B) GNAP orkestratörünü yapılandırır,
  (C) 5 ajan ile otonom olarak projeyi kodlar.
  Tetikleyiciler: "projeyi planla", "sıfırdan başla", "otonom geliştir", "auto build",
  "build this project", "bu projeyi otonom geliştir", "plan ve build"
user-invocable: true
---

# Auto-Build: Plan → Build → Deliver

Sıfırdan tam otonom proje geliştirme sistemi. Üç faz:

```
/auto-build
  │
  ├── FAZ A: Keşif ve Planlama (interaktif, sen ve kullanıcı)
  │   → Proje tanımı, tech stack, mimari kararlar
  │   → SPECIFICATION.md, IMPLEMENTATION.md, TASKS.md üretilir
  │
  ├── FAZ B: GNAP Kurulum (otomatik)
  │   → TASKS.md → .gnap/tasks.json dönüştürülür
  │   → CLAUDE.md proje kurallarıyla yazılır
  │
  └── FAZ C: Otonom Build (daemon, insan gereksiz)
      → 5 ajan: Claude Code (builder) + Sonnet/Opus/Codex/Gemini (reviewers)
      → Her görev: build → test → review → commit
      → Her faz: phase gate review
      → Hata: escalation → retry
```

## Ajan Hiyerarşisi

```
İnsan (orkestra şefi, stratejik kararlar)
  └── Claude Opus 4.6 1M (sen — mimar, bu oturum)
      ├── Claude Opus 4.6 200K (senior reviewer)
      ├── Claude Sonnet 4.6 200K (senior reviewer, hızlı)
      ├── Codex GPT-5.4 xhigh (reviewer, session memory)
      └── Gemini 3.1 flash-lite (reviewer, farklı perspektif)
```

---

## FAZ A: Keşif ve Planlama

Bu faz interaktiftir. Kullanıcıyla konuşarak projeyi anla.

### Adım 1: Proje Kimliği

Read `${SKILL_DIR}/references/elicitation-guide.md` for the full question framework.

Kullanıcıya sor (AskUserQuestion kullan):
1. "Bu proje ne yapıyor?" (elevator pitch)
2. "Kimin için?" (hedef kitle)
3. Proje tipi: Web App / CLI / API / Mobile / Desktop
4. Kapsam: MVP / Full Product / Enterprise
5. Tech stack tercihi: "Biliyorum" / "Yardım et" / "Sen seç"

**Tech stack yardımı gerekiyorsa:** Read `${SKILL_DIR}/references/tech-stacks.md`

### Adım 2: SPECIFICATION.md Üret

Read `${SKILL_DIR}/references/specification-guide.md` before generating.

Projenin **ne** olduğunu tanımla. `./docs/SPECIFICATION.md` olarak kaydet.
Kullanıcıya göster, onay al.

### Adım 3: IMPLEMENTATION.md Üret

Read `${SKILL_DIR}/references/implementation-guide.md` AND `${SKILL_DIR}/references/design-patterns.md`

Projenin **nasıl** yapılacağını tanımla. Tech stack, dizin yapısı, modüller, API'ler.
`./docs/IMPLEMENTATION.md` olarak kaydet. Kullanıcıya göster, onay al.

### Adım 4: TASKS.md Üret

Read `${SKILL_DIR}/references/tasks-guide.md` before generating.

IMPLEMENTATION.md'yi görevlere böl. Her görev:
- Tek oturumda tamamlanabilir
- Bağımlılık sırası belirli
- Acceptance criteria machine-testable
- Dosya listesi explicit

**Görev formatı (GNAP uyumlu):**
```markdown
### Task N: Görev Başlığı

**Description:** Ne yapılacak
**Files to create:** dosya1.py, dosya2.py
**Files to modify:** mevcut_dosya.py
**Acceptance Criteria:**
- [ ] `python -m pytest tests/ -v`
- [ ] `ruff check src/`
- [ ] Spesifik kontrol
**Dependencies:** Task 1, Task 3
**Phase:** 1
```

`./docs/TASKS.md` olarak kaydet. Kullanıcıya göster, onay al.

### Adım 5: CLAUDE.md Üret

Proje kök dizinine `CLAUDE.md` yaz. İçerik:
- Kod standartları (dil spesifik)
- Güvenlik kuralları (tehlikeli komutlar listesi)
- Test kuralları
- Git kuralları
- Mimari kurallar (IMPLEMENTATION.md'den)

---

## FAZ B: GNAP Kurulum

Kullanıcı onayı aldıktan sonra otomatik çalışır.

### Adım 6: GNAP Ortamını Hazırla

```bash
# TASKS.md'den GNAP görevleri yükle
gnap load-tasks --tasks-file docs/TASKS.md

# Durumu kontrol et
gnap status
```

Eğer `gnap` komutu bulunamazsa:
```bash
pip3 install -e /Users/serkanozdogan/Desktop/AI_Automation
```

### Adım 7: Git Hazırlığı

```bash
git init  # Eğer repo değilse
git add -A
git commit -m "Initial project setup with specs and task plan"
```

---

## FAZ C: Otonom Geliştirme

### Adım 8: Architect Loop Başlat

Kullanıcıya son onay sor: "Otonom geliştirmeyi başlatayım mı?"

Onay alındığında `/architect-loop` skill'ini tetikle. Bu, Opus 1M'in kendisinin
orkestratör olarak çalışmasını sağlar:
- SEN (Opus 1M) her görevi dış modellere gönderirsin
- Sonuçları KENDİN kontrol edersin (1M context ile)
- Build + test + Chrome kontrolü KENDİN yaparsın
- Hata varsa KENDİN düzeltirsin

Bu, `gnap daemon`'dan çok daha güçlüdür çünkü gerçek mimar (1M context) her kodu görür.
- Her faz sonrası phase gate review (Opus)
- Hata durumunda escalation (Codex GPT-5.4 risk analizi)
- Tüm görevler bitince durur

### İzleme

```bash
gnap status          # Görev durumu
tail -f logs/*.log   # Canlı loglar
touch .kill_switch   # Acil durdurma
```

---

## Kurallar

1. **Faz sırası zorunlu.** A → B → C. Asla atlama.
2. **Her doküman için onay al.** SPEC, IMPL, TASKS ayrı ayrı onaylanmalı.
3. **AskUserQuestion kullan.** Tech stack, veritabanı, auth gibi kararlar için seçenek sun.
4. **Ölçeğe uyarla.** Hafta sonu projesi = 15-20 görev. Kurumsal = 100+ görev.
5. **Dokümanlar `./docs/` dizinine.** SPECIFICATION.md, IMPLEMENTATION.md, TASKS.md
6. **GNAP uyumlu görev formatı.** Task N: başlık, description, files, criteria, deps, phase
7. **Her satır bu projeye özel.** Generic boilerplate yasak.

## Plugin Entegrasyonu

Kullanıcının başka skill'leri varsa:
- **frontend-design** → UI bileşen kararlarında kullan
- **typescript-mastery** → TS projelerde kod standartlarını entegre et
- **react-app-planner** → React projelerinde derin mimari
