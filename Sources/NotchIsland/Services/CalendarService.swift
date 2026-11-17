import EventKit
import Foundation

/// Upcoming events and reminders. Refreshes on EventKit change notifications plus a relaxed minute timer.
final class CalendarService: ObservableObject {
    @Published private(set) var upcoming: [EKEvent] = []
    @Published private(set) var reminders: [EKReminder] = []
    @Published private(set) var eventStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var reminderStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)

    /// (title, minutes until start)
    var onEventSoon: ((String, Int) -> Void)?

    private let prefs: Preferences
    private let store = EKEventStore()
    private var notified = Set<String>()
    private var timer: Timer?

    var hasAccess: Bool { eventStatus == .fullAccess }
    var needsPermission: Bool { eventStatus == .notDetermined }
    var isDenied: Bool { eventStatus == .denied || eventStatus == .restricted || eventStatus == .writeOnly }
    var hasReminderAccess: Bool { reminderStatus == .fullAccess }
    var reminderDenied: Bool { reminderStatus == .denied || reminderStatus == .restricted || reminderStatus == .writeOnly }

    init(prefs: Preferences) {
        self.prefs = prefs
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            self?.reload()
        }
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.reload() }
        t.tolerance = 15
        RunLoop.main.add(t, forMode: .common)
        timer = t
        reload()
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] _, _ in
            DispatchQueue.main.async { self?.reload() }
        }
    }

    func requestReminderAccess() {
        store.requestFullAccessToReminders { [weak self] _, _ in
            DispatchQueue.main.async { self?.reload() }
        }
    }

    func reload() {
        let newEvent = EKEventStore.authorizationStatus(for: .event)
        if newEvent != eventStatus { eventStatus = newEvent }
        let newReminder = EKEventStore.authorizationStatus(for: .reminder)
        if newReminder != reminderStatus { reminderStatus = newReminder }

        let now = Date()
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        let end = cal.date(byAdding: .day, value: 2, to: startOfToday) ?? now.addingTimeInterval(86_400)

        if hasAccess {
            let predicate = store.predicateForEvents(withStart: startOfToday, end: end, calendars: nil)
            upcoming = Array(
                store.events(matching: predicate)
                    .filter { !$0.isAllDay && $0.endDate > now }
                    .sorted { $0.startDate < $1.startDate }
                    .prefix(6)
            )
            checkAlerts()
        } else if !upcoming.isEmpty {
            upcoming = []
        }

        if hasReminderAccess && prefs.showReminders {
            let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: nil)
            store.fetchReminders(matching: predicate) { [weak self] result in
                let items = (result ?? [])
                    .sorted { ($0.dueDateComponents?.date ?? .distantFuture) < ($1.dueDateComponents?.date ?? .distantFuture) }
                DispatchQueue.main.async { self?.reminders = Array(items.prefix(8)) }
            }
        } else if !reminders.isEmpty {
            reminders = []
        }
    }

    func complete(_ reminder: EKReminder) {
        reminder.isCompleted = true
        do {
            try store.save(reminder, commit: true)
        } catch {
            NSLog("NotchIsland: could not complete reminder: \(error)")
        }
        reminders.removeAll { $0.calendarItemIdentifier == reminder.calendarItemIdentifier }
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
