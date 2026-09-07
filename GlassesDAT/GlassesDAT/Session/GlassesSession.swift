import Foundation
import MWDATCamera
import MWDATCore
import Observation
import UIKit

@Observable
@MainActor
final class GlassesSession {
    private(set) var session: Session = .idle
    private(set) var stream: Stream = .stopped
    private(set) var frame: PreviewFrame?
    private(set) var status: String = "Sin conectar"

    private var deviceSource: DeviceSource?
    private var deviceSession: DeviceSession?
    private var camera: MWDATCamera.Camera?
    private let sessionTokens = ListenerTokenBag()
    private let streamTokens = ListenerTokenBag()
    private var registrationTask: Task<Void, Never>?

    init() {
        registrationTask = Task { [weak self] in
            for await state in Wearables.shared.registrationStateStream() {
                await self?.applyRegistration(state)
            }
        }
    }

    deinit {
        registrationTask?.cancel()
    }

    func handleOpenURL(_ url: URL) {
        Task {
            _ = try? await Wearables.shared.handleUrl(url)
        }
    }

    func registerWithMetaAI() {
        guard !session.showsLive else { return }
        session = .registering
        status = "Abriendo Meta AI…"
        deviceSource = .metaAI
        Task {
            do {
                try await Wearables.shared.startRegistration()
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    func connectMock() {
        guard !session.showsLive else { return }
        session = .registering
        status = "Mock Device Kit…"
        deviceSource = .mock
        do {
            let feedURL = Bundle.main.url(forResource: "mock-feed", withExtension: "mp4")
            try MockPath.enableAndPair(feedURL: feedURL)
            session = .ready(.mock)
            status = "Mock listo. MEDIUM@24."
        } catch {
            MockPath.disable()
            fail(error.localizedDescription)
        }
    }

    func startStream() {
        guard stream == .stopped else { return }
        switch session {
        case .ready, .live:
            break
        default:
            return
        }
        session = .connecting
        stream = .starting
        status = "Iniciando sesión…"
        Task {
            await startDeviceAndCamera()
        }
    }

    func stopStream() {
        guard stream.isActive else { return }
        stream = .stopping
        status = "Deteniendo…"
        camera?.stop()
    }

    func disconnect() {
        camera?.stop()
        deviceSession?.stop()
        clearStream()
        clearSession()
        if deviceSource == .mock {
            MockPath.disable()
        }
        deviceSource = nil
        session = .idle
        status = "Sin conectar"
    }

    private func startDeviceAndCamera() async {
        do {
            if deviceSource == .metaAI {
                let permission = try await Wearables.shared.checkPermissionStatus(.camera)
                if permission != .granted {
                    let granted = try await Wearables.shared.requestPermission(.camera)
                    guard granted == .granted else {
                        fail("Cámara denegada en Meta AI")
                        return
                    }
                }
            }

            let activeSession: DeviceSession
            if let existing = deviceSession, existing.state == .started {
                activeSession = existing
            } else {
                let wearables = Wearables.shared
                let selector = AutoDeviceSelector(wearables: wearables)
                let newSession = try wearables.createSession(deviceSelector: selector)
                deviceSession = newSession
                observeSession(newSession)
                try newSession.start()
                if newSession.state != .started {
                    for await state in newSession.stateStream() {
                        if state == .started { break }
                        if state == .stopped || state == .idle {
                            fail("La sesión no llegó a started")
                            return
                        }
                    }
                }
                activeSession = newSession
            }

            let config = StreamConfiguration(
                videoCodec: .raw,
                resolution: .medium,
                frameRate: 24
            )
            guard let newCamera = try activeSession.addCamera(config: config) else {
                fail("addCamera devolvió nil. La sesión debe estar started.")
                return
            }
            camera = newCamera
            observeStream(newCamera.stream)
            newCamera.stream.start()
            session = .live
            status = "MEDIUM@24"
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func observeSession(_ deviceSession: DeviceSession) {
        sessionTokens.clear()
        deviceSession.statePublisher.listen { [weak self] state in
            Task { @MainActor in
                self?.applyDeviceSession(state)
            }
        }.store(in: sessionTokens)
    }

    private func observeStream(_ cameraStream: MWDATCamera.Stream) {
        streamTokens.clear()
        cameraStream.statePublisher.listen { [weak self] state in
            Task { @MainActor in
                self?.applyStream(state)
            }
        }.store(in: streamTokens)

        cameraStream.videoFramePublisher.listen { [weak self] videoFrame in
            let receivedAt = CACurrentMediaTime()
            let latencyMs = Latency.milliseconds(
                sampleBuffer: videoFrame.sampleBuffer,
                receivedAt: receivedAt
            )
            let image = videoFrame.makeUIImage()
            Task { @MainActor in
                guard let self else { return }
                if let image {
                    self.frame = PreviewFrame(image: image, latencyMs: latencyMs)
                } else if let current = self.frame {
                    self.frame = PreviewFrame(image: current.image, latencyMs: latencyMs)
                }
            }
        }.store(in: streamTokens)

        cameraStream.errorPublisher.listen { [weak self] error in
            Task { @MainActor in
                self?.fail(error.localizedDescription)
            }
        }.store(in: streamTokens)
    }

    private func applyRegistration(_ state: RegistrationState) {
        switch state {
        case .registered:
            guard deviceSource == .metaAI || deviceSource == nil else { return }
            deviceSource = .metaAI
            if !session.showsLive || session == .registering {
                session = .ready(.metaAI)
                status = "Registrada. MEDIUM@24."
            }
        case .registering:
            if session == .idle || session == .registering {
                session = .registering
                status = "Registrando…"
            }
        case .available, .unavailable:
            if session == .registering, deviceSource == .metaAI {
                status = "Registro pendiente en Meta AI"
            }
        @unknown default:
            break
        }
    }

    private func applyDeviceSession(_ state: DeviceSessionState) {
        switch state {
        case .starting:
            session = .connecting
        case .started:
            if stream == .stopped {
                session = .ready(deviceSource ?? .metaAI)
            } else {
                session = .live
            }
        case .stopping, .paused:
            break
        case .stopped, .idle:
            clearSession()
            if stream != .stopped {
                applyStream(.stopped)
            } else if session.showsLive {
                session = .ready(deviceSource ?? .metaAI)
                status = "Sesión detenida"
            }
        @unknown default:
            break
        }
    }

    private func applyStream(_ state: StreamState) {
        switch state {
        case .starting:
            stream = .starting
            status = "Arrancando stream…"
        case .waitingForDevice:
            stream = .waitingForDevice
            status = "Esperando gafas…"
        case .streaming:
            stream = .streaming
            session = .live
            status = "MEDIUM@24"
        case .paused:
            stream = .paused
            status = "Pausa"
        case .stopping:
            stream = .stopping
        case .stopped:
            clearStream()
            if session == .live || session == .connecting {
                session = .ready(deviceSource ?? .metaAI)
            }
            status = "Stream detenido"
        @unknown default:
            break
        }
    }

    private func clearStream() {
        streamTokens.clear()
        camera?.stop()
        camera = nil
        stream = .stopped
        frame = nil
    }

    private func clearSession() {
        sessionTokens.clear()
        deviceSession = nil
    }

    private func fail(_ message: String) {
        clearStream()
        clearSession()
        session = .failed(message)
        status = message
    }
}
