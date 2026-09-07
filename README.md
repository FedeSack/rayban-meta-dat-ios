# rayban-meta-dat-ios

App nativa mínima en SwiftUI que abre la cámara de Ray-Ban Meta / Meta AI glasses con el [Device Access Toolkit oficial para iOS](https://github.com/facebook/meta-wearables-dat-ios) (SPM 0.9.0). El overlay muestra la latencia gafas a pantalla en milisegundos.

Este README es para Federico Sack. El proyecto vive en `GlassesDAT/GlassesDAT.xcodeproj`.

Safari y una PWA no pueden ver esta cámara. Las Web Apps on Display de las gafas con pantalla tampoco exponen cámara. Hace falta esta app nativa.

## Qué hace

Dos pantallas, fondo negro.

1. Conectar. Registro con Meta AI, o Mock Device Kit si no hay hardware.
2. Preview. Start/Stop, HUD de latencia en ms, stream `MEDIUM` a 24 fps si el SDK lo acepta.

El dominio es una máquina de estados. `Session` cubre idle, registering, ready, connecting, live, failed. `Stream` cubre stopped, starting, waitingForDevice, streaming, paused, stopping. `GlassesSession` es el único dueño de los objetos DAT.

## Límites de Developer Preview

Lee esto antes de soñar con App Store.

- DAT está en developer preview. Meta lo dice en el [README del SDK](https://github.com/facebook/meta-wearables-dat-ios) y en el [Wearables Developer Center](https://wearables.developer.meta.com/docs/develop/).
- No publiques en App Store. Meta aún no soporta distribución pública. Lo confirmaron en las discusiones [#102](https://github.com/facebook/meta-wearables-dat-ios/discussions/102), [#103](https://github.com/facebook/meta-wearables-dat-ios/discussions/103) y en el [issue 149](https://github.com/facebook/meta-wearables-dat-ios/issues/149). El plan de Meta es abrir publicación en v1.0 y quitar el requisito MFi.
- Apple rechaza el binario por `ExternalAccessory` y `UISupportedExternalAccessoryProtocols` = `com.meta.ar.wearable`. Pide autorización MFi / PPID. Meta no mete apps de terceros en su Product Plan ahora. La [guía de integración](https://wearables.developer.meta.com/docs/develop/dat/build-integration-ios/) avisa lo mismo.
- Para testers reales, crea organización y [release channel](https://wearables.developer.meta.com/docs/develop/dat/set-up-release-channels/) en el Wearables Developer Center. En el iPhone, activa Developer Mode en Meta AI, Settings, Your glasses. `MetaAppID` = `0` solo vale en Developer Mode.
- Sin gafas, usa Mock Device Kit (`MWDATMockDevice`). El botón Mock empareja Ray-Ban Meta simuladas y alimenta `Resources/mock-feed.mp4` (HEVC / hvc1, 504x896, 24 fps).
- FAQ de Meta: [developers.meta.com/wearables/faq](https://developers.meta.com/wearables/faq/). Docs DAT: [wearables.developer.meta.com/docs/develop/dat](https://wearables.developer.meta.com/docs/develop/dat).

## Cómo abrir el proyecto

1. Instala Xcode 15 o posterior. El target es iOS 17.
2. Instala Meta AI en un iPhone. Empareja las gafas, o usa Mock en el simulador.
3. Abre `GlassesDAT/GlassesDAT.xcodeproj`.
4. El proyecto ya firma con el Apple Team `FKR9U47TSF` (Federico Sack / marca **Bobi Labs**, namespace `com.bobilabs`). Bundle IDs: `com.bobilabs.glassesdat` y `com.bobilabs.glassesdat.tests`. `Info.plist` pone `TeamID` = `$(DEVELOPMENT_TEAM)`. Si queda vacío, `startRegistration()` puede fallar con configuración inválida.
5. Deja `MetaAppID` = `0` y `ClientToken` = `developer-mode-placeholder` mientras uses Developer Mode. Para un release channel, reemplázalos con los valores del Wearables Developer Center.
6. El scheme `glassesdat` debe coincidir con `AppLinkURLScheme` = `glassesdat://` y con `CFBundleURLSchemes`.
7. Resuelve el paquete SPM `https://github.com/facebook/meta-wearables-dat-ios` en 0.9.0. Productos: `MWDATCore`, `MWDATCamera`, `MWDATMockDevice`.
8. Corre en iPhone para Meta AI. El simulador sirve para Mock.

## Device / IPA

El simulador ya compile en el Mac (Xcode 26.5). El device y el IPA fallan hasta que haya una identidad de firma Apple.

Esto no es distribución App Store. DAT sigue en developer preview.

1. En el Mac: Xcode → Settings → Accounts → inicia sesión con el Apple ID del team `FKR9U47TSF` (Bobi Labs). Deja que Xcode gestione el certificado Apple Development. No inventes certificados a mano.
2. Abre `GlassesDAT/GlassesDAT.xcodeproj` → Signing & Capabilities → Automatic signing, team `FKR9U47TSF`, bundle `com.bobilabs.glassesdat`. El App ID `com.bobilabs.glassesdat` debe existir en el Apple Developer portal, o Xcode lo crea con Automatic signing.
3. Archive + IPA de development (o ad-hoc):

```bash
./scripts/macos-archive-ipa.sh
```

El IPA queda en `build/ipa/`. El script usa `scripts/exportOptions-development.plist` (`method` = `development`, team `FKR9U47TSF`). Para ad-hoc: `EXPORT_METHOD=ad-hoc ./scripts/macos-archive-ipa.sh`. Pasa `-allowProvisioningUpdates` para que Xcode refresque el perfil. Si no hay identidad de firma, falla con instrucciones y no sigue.

## Flujo DAT que usa la app

Sigue el sample [CameraAccess](https://github.com/facebook/meta-wearables-dat-ios/tree/main/samples/CameraAccess) y las skills oficiales de getting-started, camera-streaming, permissions-registration y mockdevice-testing.

1. `Wearables.configure()` al lanzar.
2. `onOpenURL` llama `Wearables.shared.handleUrl`.
3. Meta AI: `startRegistration()`. Mock: `MockDeviceKit.enable`, `pairGlasses(.rayBanMeta)`, powerOn, unfold, don, `setCameraFeed`.
4. `createSession(deviceSelector: AutoDeviceSelector)`, `start()`, esperar `.started`.
5. Permiso `.camera` en el camino Meta AI.
6. `addCamera` con `StreamConfiguration(videoCodec: .raw, resolution: .medium, frameRate: 24)`.
7. `stream.start()`. Frames por `videoFramePublisher`. Preview con `makeUIImage()` sobre un `UIImageView` (`FrameSurface`).

## HUD de latencia

`VideoFrame` en iOS 0.9 no tiene un timestamp de captura documentado. Solo expone `sampleBuffer`. El HUD hace esto:

- Si el PTS del `CMSampleBuffer` parece reloj de host (más de 100 s), muestra `ahora - PTS` en ms. Eso es lo más cerca de gafas a pantalla que da el SDK.
- Si el PTS es timeline de media (cerca de 0), muestra `ahora - llegada del frame`. Eso es decode más paint, no captura en cristal.

Android sí publica `presentationTimeUs`. iOS no. El número del HUD es honesto con esa diferencia.

## Archivos

- `GlassesDAT/GlassesDAT/Domain` define `Session`, `Stream`, `PreviewFrame`, `Latency`.
- `GlassesDAT/GlassesDAT/Session/GlassesSession.swift` habla con DAT.
- `GlassesDAT/GlassesDAT/Session/MockPath.swift` aísla Mock Device Kit.
- `GlassesDAT/GlassesDAT/UI` son las dos pantallas SwiftUI más el HUD.
- `GlassesDAT/GlassesDAT/Info.plist` tiene los placeholders `MetaAppID`, `ClientToken`, `TeamID`, `AppLinkURLScheme`.
- `GlassesDAT/GlassesDATTests/LatencyTests.swift` cubre la aritmética del HUD.

## Qué no está

No hay SDK web de cámara. No hay scrape de Meta AI. No hay UIKit fuera de `FrameSurface`. No hay App Store. No hay foto ni grabación. El sample oficial de Meta sí las tiene si las necesitas después.
