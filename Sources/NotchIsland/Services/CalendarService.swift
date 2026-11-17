import EventKit
import Foundation

final class CalendarService: ObservableObject {
    @Published private(set) var upcoming: [EKEvent] = []
    @Published private(set) var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    /// (title, minutes until start)
    var onEventSoon: ((String, Int) -> Void)?

    private let prefs: Preferences
    private let store = EKEventStore()
    private var notified = Set<String>()
    private var timer: Timer?

    var hasAccess: Bool { status == .fullAccess }
    var needsPermission: Bool { status == .notDetermined }
    var isDenied: Bool { status == .denied || status == .restricted || status == .writeOnly }

    init(prefs: Preferences) {
        self.prefs = prefs
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in self?.reload() }

        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.reload()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        reload()
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] _, _ in
            DispatchQueue.main.async { self?.reload() }
        }
    }

    func reload() {
        let newStatus = EKEventStore.authorizationStatus(for: .event)
        if newStatus != status { status = newStatus }
        guard hasAccess else {
            if !upcoming.isEmpty { upcoming = [] }
            return
        }

        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: 2, to: startOfToday) ?? now.addingTimeInterval(86_400)
        let predicate = store.predicateForEvents(withStart: startOfToday, end: end, calendars: nil)
        upcoming = Array(
            store.events(matching: predicate)
                .filter { !$0.isAllDay && $0.endDate > now }
                .sorted { $0.startDate < $1.startDate }
                .prefix(5)
        )
        checkAlerts()
    }

    private func checkAlerts() {
        let window = Double(prefs.calendarAlertMinutes) * 60
        for event in upcoming {
            let seconds = event.startDate.timeIntervalSinceNow
            let id = (event.eventIdentifier ?? "") + "\(event.startDate.timeIntervalSince1970)"
            guard seconds > 0, seconds <= window, !notified.contains(id) else { continue }
            notified.insert(id)
            onEventSoon?(event.title ?? "Event", Int((seconds / 60).rounded(.up)))
        }
    }
}
