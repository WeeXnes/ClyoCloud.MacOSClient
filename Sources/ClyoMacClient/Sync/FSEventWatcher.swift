import Foundation
import CoreServices

public final class FSEventWatcher {
    private var streamRef: FSEventStreamRef?
    private let pathsToWatch: [String]
    private let latency: TimeInterval
    private let callback: () -> Void

    public init(paths: [String], latency: TimeInterval = 1.0, callback: @escaping () -> Void) {
        self.pathsToWatch = paths
        self.latency = latency
        self.callback = callback
    }

    public func start() {
        stop()

        guard !pathsToWatch.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let paths = pathsToWatch as CFArray
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)

        let eventCallback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let clientInfo = clientCallBackInfo else { return }
            let watcher = Unmanaged<FSEventWatcher>.fromOpaque(clientInfo).takeUnretainedValue()
            DispatchQueue.main.async {
                watcher.callback()
            }
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            eventCallback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else {
            print("Failed to create FSEventStream")
            return
        }

        self.streamRef = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    public func stop() {
        if let stream = streamRef {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.streamRef = nil
        }
    }

    deinit {
        stop()
    }
}
