//
//  BackgroundEventsFlush.swift
//  FlagsmithClient
//

#if canImport(UIKit) && !os(watchOS)
    import UIKit

    /// Begins and ends background tasks, which `UIApplication` does in an application.
    @MainActor
    protocol BackgroundTasks: AnyObject {
        /// Begins a background task, calling `expiration` on the main thread if it runs out of time.
        func begin(expiration: @escaping @MainActor () -> Void) -> UIBackgroundTaskIdentifier
        func end(_ task: UIBackgroundTaskIdentifier)
    }

    /// The background tasks of the running application.
    @MainActor
    final class ApplicationBackgroundTasks: BackgroundTasks {
        private let application: UIApplication

        /// The background tasks of the running application, or `nil` in an application extension, which cannot
        /// begin them.
        static func current() -> ApplicationBackgroundTasks? {
            // `UIApplication.shared` is unavailable to application extensions, which may link this SDK too.
            guard !Bundle.main.bundlePath.hasSuffix(".appex"),
                  let application = UIApplication.perform(NSSelectorFromString("sharedApplication"))?
                  .takeUnretainedValue() as? UIApplication
            else {
                return nil
            }
            return ApplicationBackgroundTasks(application: application)
        }

        private init(application: UIApplication) {
            self.application = application
        }

        func begin(expiration: @escaping @MainActor () -> Void) -> UIBackgroundTaskIdentifier {
            application.beginBackgroundTask(withName: "Flagsmith events") { expiration() }
        }

        func end(_ task: UIBackgroundTaskIdentifier) {
            application.endBackgroundTask(task)
        }
    }

    /// Sends the buffered events when the application enters the background, inside a background task so that iOS
    /// lets the request finish before suspending the application.
    ///
    /// The task ends once the events have been sent, retries included, or kept or dropped after failing to send, or
    /// when it runs out of time.
    @MainActor
    final class BackgroundEventsFlush: NSObject {
        private weak var events: FlagsmithEvents?
        private let notificationCenter: NotificationCenter
        private let backgroundTasks: @MainActor @Sendable () -> (any BackgroundTasks)?

        nonisolated init(events: FlagsmithEvents, notificationCenter: NotificationCenter = .default,
                         backgroundTasks: @escaping @MainActor @Sendable () -> (any BackgroundTasks)? = {
                             ApplicationBackgroundTasks.current()
                         })
        {
            self.events = events
            self.notificationCenter = notificationCenter
            self.backgroundTasks = backgroundTasks
            super.init()
            notificationCenter.addObserver(self, selector: #selector(didEnterBackground),
                                           name: UIApplication.didEnterBackgroundNotification, object: nil)
        }

        deinit {
            notificationCenter.removeObserver(self)
        }

        @objc private func didEnterBackground() {
            guard let events = events else { return }
            let task = backgroundTasks().map(BackgroundTask.init)
            task?.begin()
            let flushing = events.flushForBackground {
                DispatchQueue.main.async { task?.end() }
            }
            if !flushing {
                task?.end()
            }
        }
    }

    /// A background task that ends once, when told to or when it runs out of time.
    @MainActor
    private final class BackgroundTask {
        private let tasks: any BackgroundTasks
        private var task = UIBackgroundTaskIdentifier.invalid

        init(_ tasks: any BackgroundTasks) {
            self.tasks = tasks
        }

        func begin() {
            task = tasks.begin { [weak self] in self?.end() }
        }

        func end() {
            guard task != .invalid else { return }
            tasks.end(task)
            task = .invalid
        }
    }
#endif
