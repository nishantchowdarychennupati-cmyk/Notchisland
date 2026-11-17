import EventKit
import SwiftUI

/// Upcoming events and today's reminders side by side.
struct AgendaView: View {
    @ObservedObject var calendar: CalendarService
    @ObservedObject var prefs: Preferences

    var body: some View {
        HStack(spacing: 10) {
            events
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
                .islandCard()
            if prefs.showReminders {
                reminders
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
                    .islandCard()
            }
        }
    }

    private var events: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Up Next", systemImage: "calendar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.red)
            if !calendar.hasAccess {
                accessButton(denied: calendar.isDenied, anchor: "Privacy_Calendars") { calendar.requestAccess() }
            } else if calendar.upcoming.isEmpty {
                Text("Nothing else today 🎉")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(calendar.upcoming, id: \.calendarItemIdentifier) { event in
                            EventRow(event: event)
                        }
                    }
                }
            }
        }
    }

    private var reminders: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Reminders", systemImage: "checklist")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
            if !calendar.hasReminderAccess {
                accessButton(denied: calendar.reminderDenied, anchor: "Privacy_Reminders") { calendar.requestReminderAccess() }
            } else if calendar.reminders.isEmpty {
                Text("All done ✓")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(calendar.reminders, id: \.calendarItemIdentifier) { reminder in
                            ReminderRow(reminder: reminder) {
                                withAnimation(islandSpring) { calendar.complete(reminder) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func accessButton(denied: Bool, anchor: String, request: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(denied ? "Access was denied." : "NotchIsland needs access.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
            Button(denied ? "Open Settings" : "Allow Access") {
                denied ? SystemSettingsLink.open(anchor) : request()
            }
            .buttonStyle(PillButtonStyle())
        }
    }
}

struct ReminderRow: View {
    let reminder: EKReminder
    let onComplete: () -> Void
    @State private var checked = false

    var body: some View {
        Button {
            checked = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: onComplete)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(checked ? Color.orange : Color(nsColor: reminder.calendar?.color ?? .systemOrange))
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 0) {
                    Text(reminder.title ?? "Reminder")
                        .font(.system(size: 12, weight: .medium))
                        .strikethrough(checked)
                        .lineLimit(1)
                    if let due = reminder.dueDateComponents?.date {
                        Text(due.formatted(date: Calendar.current.isDateInToday(due) ? .omitted : .abbreviated, time: .shortened))
                            .font(.system(size: 9))
                            .foregroundStyle(due < Date() ? Color.red : Color.white.opacity(0.5))
                    }
                }
            }
        }
        .buttonStyle(RowButtonStyle())
    }
}
