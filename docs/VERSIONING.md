# Versionado — Bobi Glasses

Reglas para que TestFlight / App Store Connect nunca reutilice un build ni salte números al azar.

App: **Bobi Glasses** · bundle `com.bobilabs.glasses` · team `FKR9U47TSF`.

## MARKETING_VERSION (`CFBundleShortVersionString`)

- Semver `MAJOR.MINOR.PATCH`, visible para el usuario.
- Parte de **1.0.0** (migración desde `1.0`).
- Se sube en un PR cuando el cambio es user-facing. No lo toca el script de archive.

## CURRENT_PROJECT_VERSION (`CFBundleVersion`)

- Entero positivo que **solo aumenta**.
- Cada upload a App Store Connect / TestFlight lleva un número **nuevo y mayor**.
- Nunca reutilizar. Nunca bajar.
- Baseline actual en el repo: `1` (aún no subido). El primer archive del script queda en `2`.

## Quién sube qué

| Campo | Cuándo | Dónde |
| --- | --- | --- |
| Marketing | PR al shippear un cambio visible | `project.pbxproj` (`MARKETING_VERSION`) |
| Build | En el archive / upload | `scripts/macos-archive-ipa.sh` |

No subir el build a mano en commits sueltos.

El script incrementa `CURRENT_PROJECT_VERSION` en **+1** antes del archive y deja el `pbxproj` sucio a propósito. Después de un upload a TestFlight, commiteá ese bump. Si App Store Connect ya tiene un número más alto (upload a mano, otro Mac), no edites al azar: pasá el siguiente entero con `BUILD_NUMBER`.

```bash
./scripts/macos-archive-ipa.sh
# o, si TestFlight ya usó 7:
BUILD_NUMBER=8 ./scripts/macos-archive-ipa.sh
```

`BUILD_NUMBER` tiene que ser un entero positivo **estrictamente mayor** que el valor actual. El script imprime marketing + build usados.

## Tag opcional

Cuando un build entra a TestFlight:

```
vMAJOR.MINOR.PATCH+BUILD
```

Ejemplo: `v1.0.0+2`. El script sugiere el tag; no lo crea solo.

## Qué no hacer

- No reutilizar un `CFBundleVersion` ya subido.
- No bajar el build.
- No mezclar marketing `1.0` (dos componentes) con `1.0.0`.
- No commitear secretos, API keys de App Store Connect, ni certificados.
