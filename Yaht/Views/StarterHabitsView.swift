import SwiftData
import SwiftUI

/// First launch: pick a few starter habits, or create your own. Each picked
/// habit lights up its segment of the ring.
struct StarterHabitsView: View {
    @Environment(HabitStore.self) private var store
    let onCreateOwn: () -> Void

    @State private var picked: Set<String> = ["water", "read"]

    struct Starter: Identifiable {
        let id: String
        let name: LocalizedStringResource
        let emoji: String
        let colorHex: String
        let note: LocalizedStringResource
        var kind: HabitKind = .binary
        var dailyTarget = 1
        var unit: LocalizedStringResource?
        var schedule: ScheduleKind = .daily
        var weeklyTarget = 0
    }

    static let starters: [Starter] = [
        Starter(id: "water", name: "Drink water", emoji: "💧", colorHex: "83A598",
                note: "Count · 8 glasses a day", kind: .count, dailyTarget: 8, unit: "glasses"),
        Starter(id: "read", name: "Read", emoji: "📖", colorHex: "FABD2F",
                note: "Count · 10 pages a day", kind: .count, dailyTarget: 10, unit: "pages"),
        Starter(id: "walk", name: "Walk", emoji: "🚶", colorHex: "B8BB26", note: "Every day"),
        Starter(id: "meds", name: "Take meds", emoji: "💊", colorHex: "D3869B", note: "Every day"),
        Starter(id: "workout", name: "Work out", emoji: "🏋️", colorHex: "FE8019",
                note: "3 times a week", schedule: .timesPerWeek, weeklyTarget: 3),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 18) {
                    ZStack {
                        SegmentedRing(
                            segments: Self.starters.map {
                                SegmentedRing.Segment(
                                    id: $0.id,
                                    color: Color(hex: $0.colorHex) ?? Theme.tint,
                                    isFilled: picked.contains($0.id)
                                )
                            },
                            lineWidth: 14
                        )
                        Text("yaht")
                            .roundedFont(34, weight: .heavy)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .frame(width: 148, height: 148)
                    .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("Start with one small habit")
                            .roundedFont(28, weight: .heavy)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("Pick a few to begin. Each one gets its own color and fills a piece of your daily ring.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: 300)
                    }
                }
                .padding(.top, 24)

                VStack(spacing: 8) {
                    ForEach(Self.starters) { starter in
                        starterRow(starter)
                    }
                }

                VStack(spacing: 8) {
                    Button(action: addPicked) {
                        Text(picked.isEmpty ? "Pick at least one" : "Add \(picked.count) habits")
                            .roundedFont(17)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(picked.isEmpty ? Theme.textTertiary : Theme.background)
                            .background(
                                picked.isEmpty ? Theme.raised : Theme.textPrimary,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(picked.isEmpty)
                    .accessibilityIdentifier("habit-list-empty-add-button")

                    Button("Create my own instead", action: onCreateOwn)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("starter-create-own")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func starterRow(_ starter: Starter) -> some View {
        let isOn = picked.contains(starter.id)
        let color = Color(hex: starter.colorHex) ?? Theme.tint
        return Button {
            if isOn { picked.remove(starter.id) } else { picked.insert(starter.id) }
        } label: {
            HStack(spacing: 12) {
                HabitTile(emoji: starter.emoji, color: color, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(starter.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(starter.note)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .strokeBorder(isOn ? .clear : Theme.textDisabled, lineWidth: 2)
                        .background(Circle().fill(isOn ? color : .clear))
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Theme.onAccent(starter.colorHex))
                    }
                }
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 60)
            .background(isOn ? color.opacity(0.12) : Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isOn ? color.opacity(0.45) : Theme.hairline, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier("starter-\(starter.id)")
    }

    private func addPicked() {
        let chosen = Self.starters.filter { picked.contains($0.id) }
        for (index, starter) in chosen.enumerated() {
            let habit = Habit(
                name: String(localized: starter.name),
                emoji: starter.emoji,
                colorHex: starter.colorHex,
                sortOrder: index,
                kind: starter.kind,
                dailyTarget: starter.dailyTarget,
                unit: starter.unit.map { String(localized: $0) },
                scheduleKind: starter.schedule,
                weeklyTarget: starter.weeklyTarget
            )
            store.create(habit)
        }
    }
}
