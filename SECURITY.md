# Security Implementation & Validation Report

**Scope:** `CheapSeek` macOS client (menu bar app).
**Architecture:** 100% on-device. No network calls, no telemetry, no accounts, no shared container.
**Date:** 2026-09-15 · **Last re-verified:** 2026-09-15 (46 unit tests pass; 1 UI launch test passes) · **Validated by:** `PeakCalculatorTests`, `AppSettingsTests`, `AppModelTests`, `LocalizationTests` (run per build via `test/test.sh`).

## OWASP Top 10 (2021) — Desktop Client Applicability

| # | Category | Status | Evidence / Control |
| :-- | :--- | :--- | :--- |
| A01 | Broken Access Control | **N/A** | Single-user local app. No accounts, roles, or multi-tenant data. |
| A02 | Cryptographic Failures | **N/A** | The app stores no passwords, tokens, or keys. Only preference values are persisted. |
| A03 | Injection | **N/A** | No SQL, shell, or network input. The only external value is a timezone identifier, validated through `TimeZone(identifier:)` with a safe `.current` fallback (`AppSettings.timeZone`). |
| A04 | Insecure Design | **Pass** | Peak pricing is computed locally from the system clock (`PeakCalculator`, UTC). No remote trust boundary exists. |
| A05 | Security Misconfiguration | **Pass** | `LSUIElement = true` (no Dock icon/menu), no entitlements, no debug backdoors in the app logic. |
| A06 | Vulnerable Components | **Pass** | A single dependency, Localize-Swift, is **vendored locally** at 3.2.0 — no SPM/network resolution and no third-party runtime SDKs. |
| A07 | Identification & Auth Failures | **N/A** | No authentication or identity surface. |
| A08 | Software/Data Integrity | **Pass** | `UserDefaults` values are type-checked on load; invalid/absent timezones fall back to `.current`; intervals are clamped to `30...300`. |
| A09 | Logging & Monitoring Failures | **Pass** | No sensitive data is logged. No crash reporters or analytics are present. |
| A10 | SSRF | **N/A** | The app performs **zero outbound requests**. |

## OWASP MASVS (v2) Coverage

| MASVS Domain | Level | Notes |
| :--- | :--- | :--- |
| MASVS-STORAGE | **L1** | Only preferences are stored, in the app's `UserDefaults` (`settings.timeZone`, `settings.notificationsEnabled`, `settings.updateInterval`, and Localize's language key). No secrets. |
| MASVS-CRYPTO | L1 | No custom cryptography; none required. |
| MASVS-NETWORK | **L1+** | No networking at all — strictly stronger than the baseline requirement. |
| MASVS-PRIVACY | **L1** | Zero analytics, zero crash reporters, zero third-party SDKs. No data leaves the machine. |
| MASVS-PLATFORM | **L1** | Menu-bar-only (`LSUIElement`); launch-at-login via Apple's `SMAppService`; no entitlements required. |

## Threat Model (Core Journeys)

1. **Local preference tampering**
   - **Asset:** User preferences (timezone, interval, language, notifications).
   - **Adversary:** A local process/user editing `UserDefaults`.
   - **Control:** Low impact — values are non-sensitive and validated on load (unknown timezone → system default; interval clamped).

2. **Launch-at-login abuse**
   - **Asset:** Persistence at login.
   - **Adversary:** Enabling the app to launch without consent.
   - **Control:** Managed exclusively through `SMAppService.mainApp`, which is user-visible and revocable in **System Settings → General → Login Items**. The app never installs helper executables or agents.

3. **Supply-chain risk**
   - **Asset:** Build integrity.
   - **Adversary:** Malicious upstream dependency.
   - **Control:** The only dependency is vendored in-repo and pinned at 3.2.0; no code is fetched at build time.

## Risk Assessment Matrix (known, unresolved)

| # | Risk | Severity | Likelihood | Status | Rationale / Accepted because |
| :-- | :--- | :--- | :--- | :--- | :--- |
| R1 | `SMAppService.register()` may fail for ad-hoc signed builds | Low | Medium | Accepted | Ad-hoc signing is dev-only; distributed builds should be properly signed/notarized. Failures are caught and surfaced in Settings. |
| R2 | Menu bar label may render monochrome, hiding red/green | Low | High | Accepted | A macOS rendering behavior, not a security issue. Status text remains present in the popup. |
| R3 | Incorrect status if the system clock is wrong | Low | Low | Accepted | Peak logic trusts UTC from the OS; there is no independent time source by design. |

## Incident Response (condensed playbook)

- **Reset all preferences:** `defaults delete com.mahirfatih.CheapSeek` (then relaunch).
- **Disable launch at login:** toggle it off in **Settings**, or remove it in **System Settings → General → Login Items**.
- **Wrong peak status:** verify the system date/time and the selected timezone in Settings (peak windows are always computed in UTC).

## Verification Commands

```bash
# Unit tests + coverage summary
./test/test.sh --coverage

# Unit tests only, directly
xcodebuild -project CheapSeek.xcodeproj -scheme CheapSeek \
  -destination 'platform=macOS' \
  -only-testing:CheapSeekTests test
```

**Version:** `CFBundleShortVersionString 1.0.0` (`CFBundleVersion 1`), set via `project.yml` (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`).
