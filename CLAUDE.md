# callcenterSalon.Mobil — AI ekibi için yönergeler

Bu dosya hem Claude (Anthropic) hem ChatGPT/Codex (OpenAI) ekibinin okuduğu **paylaşılan** referans. Memory/private notlar değil — herkes buradan baksın.

## Kapsam (DEĞİŞMEZ)

**Bu Flutter uygulaması SADECE müşteri tarafıdır.** Salon kullanıcıları (admin/owner/staff) için **AYRI bir mobil uygulama** yazılacak.

- Bu repo'ya **salon-staff ekran/feature EKLEMEYIN** (IBAN onboarding, sub-merchant config, staff schedule, customer management vb.).
- Yeni özellik isteği geldiğinde önce sor: "Bu *müşteri* için mi *salon staff* için mi?" Salon-staff ise kapsam dışı, ayrı projeye gönder.
- `docs/PRODUCTION.md`'deki salon-admin notları (IBAN, sub-merchant) tarihsel referans; bu repo'da implemente edilmeyecek.

## ClaudeManager — proje takibi

Bu projenin ClaudeManager **project_id = 126**. Tüm planlar, faz, task, journal **manager'dan** takip edilir; memory veya yerel dosyalar **kaynak değil**.

API base: `http://127.0.0.1:41847`

Sık kullanılan uçlar:

```bash
# Faz + task özeti
curl -s http://127.0.0.1:41847/api/projects/126/roadmap/summary

# Tüm faz + task detayı
curl -s http://127.0.0.1:41847/api/projects/126/roadmap

# Yeni faz
curl -X POST http://127.0.0.1:41847/api/projects/126/phases -H "Content-Type: application/json" \
  -d '{"phase_no":"X","title":"...","description":"..."}'

# Faza task ekle (PHASE_ID önce alınır)
curl -X POST http://127.0.0.1:41847/api/phases/PHASE_ID/tasks -H "Content-Type: application/json" \
  -d '{"task_no":"X.Y","title":"...","detail":"..."}'

# Task durumu güncelle
curl -X PUT http://127.0.0.1:41847/api/tasks/TASK_ID -H "Content-Type: application/json" \
  -d '{"status":"completed"}'

# Journal (karar günlüğü)
curl -X POST http://127.0.0.1:41847/api/projects/126/journal -H "Content-Type: application/json" \
  -d '{"title":"...","content":"...","category":"karar"}'

# Notes (api key, kredensiyal vs.)
curl -s http://127.0.0.1:41847/api/projects/126/notes
```

Backend (callcenter) için **project_id = 15**.

## i18n stratejisi

Çeviriler API'den çekilebilir (web Salon `ServerTranslationCache` mantığına paralel). V1 TR-only ama mimaride **hard-coded string yerine dinamik çekim** prensibi kabul edildi. Tam ARB migration acele etmeyin; API endpoint hazır olduğunda `tr('key')` helper'ı ile devreye alınır.

## Akıllı kuralları

- **Memory'ye not düşme** (Claude'a özel kalır, ChatGPT okumaz). Yeni kural / tercih → bu CLAUDE.md'ye veya ClaudeManager journal'ine.
- **Salon translations** sadece `src/CallCenter.Salon/wwwroot/translations-salon.xml` (callcenter projesi). `salon.xml` adında dosya **yoktur**, oluşturma/sync yapma.
- Plan değişikliği → mutlaka journal entry. Memory'ye değil.

## Build ve çalıştırma

Flutter SDK: `C:\Users\Ahmet\flutter_sdk_stable\bin\flutter.bat` (PATH'te değil, doğrudan çağır).

Geliştirme:
```powershell
.\scripts\dev.ps1 -Mode web -ApiUrl https://localhost:7147   # default
.\scripts\dev.ps1 -Mode android -ApiUrl http://10.0.2.2:5041
```

Production build:
```powershell
.\scripts\build.ps1 -Target apk -Env prod -MapTileUrl '...'
```

Detaylı production gates: `docs/PRODUCTION.md`.

## Mevcut faz durumu (özet)

Tam liste için: `curl -s http://127.0.0.1:41847/api/projects/126/roadmap/summary`

- Phase 1-5 ✓ done (profile, reviews, membership, auth/forgot-pwd, payments)
- Phase 6: token register API tamam, FCM kurulumu kullanıcıya bağlı
- Phase 7: kod hazır, store/icon/signing/Mapbox kullanıcıya bağlı
- Phase 8: UX polish (8/8 done — i18n deferred)
- Phase 9: Pay-appointment (backend bekliyor)
- MOBQA-20260510: QA bulguları (in progress)
