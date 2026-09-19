# CheapSeek — Genel Bakış

[English](./EN.md) · **Türkçe**

CheapSeek, DeepSeek API'sinin şu an **peak** (pahalı) mi yoksa **off-peak** (ucuz) fiyatlandırmada mı olduğunu söyleyen küçük bir **macOS menü çubuğu uygulamasıdır**. SwiftUI ile yazılmıştır ve fiyat penceresini tamamen **cihaz üstünde**, geçerli UTC saatinden hesaplar. Amacı basittir: ucuzken kod yaz, pahalıyken bekle — canlı menü çubuğu durumu, günün programı, sonraki değişime geri sayım, yerel bildirimler ve 7 günlük geçmiş grafiğiyle.

---

## Temel çalışma prensibi

1. `Clock`, yapılandırılabilir aralıkta (varsayılan **60 sn**) tetiklenir ve geçerli tarihi `AppModel`'e verir.
2. `AppModel`, saf `PeakCalculator`'a bu anın peak olup olmadığını sorar; UTC takvimi ve yarı-açık pencereler kullanılır (`[01:00,04:00)` ve `[06:00,10:00)`).
3. Menü çubuğu etiketi off-peak için `leaf` + `cheap`, peak için `flame.fill` + `peak` gösterir.
4. Popup açıldığında saniyelik `TimelineView` çalışır: durum rozeti, geçerli saat ve saat dilimi, günün tam programı ve sonraki değişime canlı geri sayım.
5. Açılışta ve her bildirim/saat dilimi değişiminde `NotificationManager`, 7 günlük ufuk için yerel bildirimleri yeniden planlar (sessiz saatleri atlar).
6. Her durum değişimi `HistoryStore`'a kaydedilir; uygulama kapalıyken oluşan boşluk **açılışta ve saat dilimi değişiminde backfill edilir**, böylece grafik doğru kalır.

Kritik nokta: **ağ çağrısı ve hesap yok.** Karar, sistem saatinden ve UTC kurallarından cihaz üstünde hesaplanır.

---

## Ekranlar ve işlevleri

### Menü çubuğu

- Kısa metin + simge: off-peak'te `leaf` + `cheap`, peak'te `flame.fill` + `peak`.
- Yalnızca renge değil metne dayandığı için açık, koyu ve monokrom template modunda okunur kalır.

### Popup

- Durum rozeti (**Yoğun Saatler** / **Yoğun Olmayan Saatler**), geçerli saat ve seçili saat dilimi (örn. `Europe/Istanbul · GMT+3`).
- **Bugünün Programı:** seçili saat diliminde günün tüm peak/off-peak dilimleri.
- **Sonraki Değişim:** sonraki geçişe canlı geri sayım (`içinde 3sa 42dk Yoğun saate`).
- Katlanabilir **Geçmiş** grafiği (son 7 gün, yoğun/yoğun olmayan dakikalar).
- Eylemler: **Ayarlar**, **Bilgi** (fiyatlandırma), **Çık**.

### Fiyatlandırma / bilgi

- DeepSeek model ücretleri (1M token başına), **peak** ve **off-peak** fiyatları yan yana.
- UTC peak penceresi ve bunun saat diliminizdeki karşılığı.
- Fiyatlandırma sayfası, API belgeleri ve API kullanımı bağlantıları.

### Saat dilimi seçici

- Bölgeye göre gruplanmış, aranabilir IANA saat dilimi listesi ve güncel UTC ofsetleri.
- Şehir veya kimliğe göre filtreleme; seçili öğe işaretlenir.

### Ayarlar

- **Dil** — 17 dil; seçim anında uygulanır, yeniden başlatma yok.
- **Saat dilimi** — herhangi bir IANA kimliği veya `Sistem Saat Dilimi`.
- **Bildirimler** — bildirimleri etkinleştirme, yoğun olmayan saat başlangıcı, yoğun saat başlangıcı, yoğun saatten önce uyarı ve sessiz saatler.
- **Girişte Başlat** — `SMAppService` ile.
- **Güncelleme aralığı** — 30–300 sn (varsayılan 60 sn).

---

## Peak mantığı

Peak pencereleri **UTC**'dir ve Pazartesi–Cuma uygulanır; hafta sonları her zaman off-peak'tir.

| Pencere (UTC) | Günler | Fiyat |
| :--- | :--- | :--- |
| `01:00–04:00` | Pzt–Cum | Peak (tam ücret) |
| `06:00–10:00` | Pzt–Cum | Peak (tam ücret) |
| Diğer tüm saatler (hafta sonu dahil) | — | Off-peak (%50 indirim) |

- Pencereler **yarı-açıktır**: `01:00` peak, `04:00` off-peak.
- Özel bir `Configuration.plist` pencereleri, hafta içi kuralını, fiyatları ve bağlantıları geçersiz kılabilir; `DeepSeekConfigTests` bunu doğrular ve dosya eksik/bozuksa yerleşik varsayılanlara düşer.

---

## Mimari ve veri katmanı

- **Saf çekirdek:** `PeakCalculator`, `CountdownFormatter`, `NotificationPlanner`, `HistoryAggregator`, `TimeZoneCatalog`, `TimeZoneLabel` — yalnızca Foundation, tamamen birim testli, global durum yok.
- **Durum:** `AppModel` (`@MainActor`, `@Observable`; yenileme tiki, program, geçmiş) + `AppSettings` (`UserDefaults` kalıcılığı, `SMAppService`) + `Clock` (async ticker) + `HistoryStore` + `NotificationManager`.
- **Yapılandırma:** `DeepSeekConfig`, `Configuration.plist`'i (peak pencereleri, fiyatlar, bağlantılar) yerleşik yedekle yükler.
- **View'lar:** `PopupHost`/`PopupView` (`MenuBarExtra` `.window`), `SettingsView`, `PricingInfoView`, `HistoryChartView` (Swift Charts), `TimeZonePicker`, `MenuBarLabel`, `PeakStatus`.
- **Geçmiş:** olay tabanlı — örnek yalnızca durum değişiminde `UserDefaults`'a yazılır; kayıtlar 7 güne budanır ve sınır çapası korunur; `HistoryAggregator` aralıkları yerel güne göre yoğun/yoğun olmayan dakikalara böler (DST'li 23sa/25sa günler dahil).

---

## Gizlilik ve tasarım

- **%100 cihaz üstü:** analitik, telemetri, ağ çağrısı ve üçüncü taraf çalışma-zamanı SDK'sı yok.
- Durum yalnızca `UserDefaults`'ta (saat dilimi, bildirim tercihleri, sessiz saatler, güncelleme aralığı, dil, geçmiş örnekleri); `PrivacyInfo.xcprivacy` UserDefaults gerekçe kodunu (`CA92.1`) bildirir.
- **Entitlement yok**; yalnızca menü çubuğu ajanı olarak çalışır (`LSUIElement`).
- **Tasarım:** semantik sistem renkleri, `.regularMaterial` popup arka planı ve otomatik açık/koyu tema.

---

## Bilinen sınırlamalar

- **Ad-hoc imza:** proje varsayılan olarak ad-hoc imzalanır; bu nedenle `SMAppService` girişte başlat kaydı, bir Development Team ile imzalanana kadar başarısız olabilir.
- **Menü çubuğu görünümü:** macOS durum öğesini monokrom template olarak çizebilir; bu yüzden renk yerine kısa metin ve belirgin SF Symbols kullanılır.
- **Kapalıyken geçmiş:** örnekler yalnızca uygulama çalışırken kaydedilir; boşluk bir sonraki açılışta ve saat dilimi değişiminde backfill edilir.
- **Bildirimler:** yerel uyarılar macOS bildirim iznine bağlıdır ve önümüzdeki 7 gün için cihaz üstünde planlanır.

---

## Kalite, test ve proje yönetimi

- **Test:** **214 birim testi** (saf çekirdek, durum, yöneticiler, yerelleştirme, güvenlik + ViewInspector ve offscreen `ImageRenderer` view testleri) ve **5 UI testi** (açılış, Ayarlar ve saat dilimi seçici assert edilir; menü çubuğu popup'ı best-effort'tur ve macOS durum öğesini açığa çıkarmazsa atlar).
- **Kapsam:** `CheapSeek.app` satır kapsamı **%96,69**, CI kapısı **≥%95**.
- **CI:** GitHub Actions (`.github/workflows/ci.yml`) `main`'e push, pull request ve manuel tetikleme ile — `xcodegen generate`, build, kapsamlı birim testleri ve kapsam kapısı.
- **Proje yönetimi:** `project.yml` (XcodeGen) tek doğruluk kaynağı; doküman/asset `docs/diagrams/` (Archify) ve `docs/screenshots/` altında.
- **Sürüm:** `project.yml`'de `MARKETING_VERSION` artırılır; uygulama arşivlenir, imzalanır, dışa aktarılır, notarize edilir, staple'lanır ve dağıtım için paketlenir.

---

Özetle: CheapSeek, DeepSeek'in peak/off-peak fiyatlandırmasını bir bakışta okunur menü çubuğu sinyaline çevirir — UTC kurallarından cihaz üstünde hesaplanır; canlı program, geri sayım, bildirimler ve geçmişle birlikte.
