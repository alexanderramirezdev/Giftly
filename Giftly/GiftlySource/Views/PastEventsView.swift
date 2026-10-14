//
//  PastEventsView.swift
//  Giftly
//
//  Occasions that already happened, grouped by year, with what was given.
//  Reached from one "Past events" row on home so the main screen stays about
//  what's coming up.
//

import SwiftUI
import SwiftData

struct PastEventsView: View {
    @Query(sort: \Person.name) private var people: [Person]

    private struct Entry: Identifiable {
        let occasion: Occasion
        let when: Date
        var id: PersistentIdentifier { occasion.persistentModelID }
    }

    private var entries: [Entry] {
        var out: [Entry] = []
        for person in people {
            for o in person.occasions ?? [] where o.belongsInPast {
                if let when = o.lastOccurrence { out.append(Entry(occasion: o, when: when)) }
            }
        }
        return out.sorted { $0.when > $1.when }
    }

    private var years: [Int] {
        let cal = Calendar.current
        let all = entries.map { cal.component(.year, from: $0.when) }
        return Array(Set(all)).sorted(by: >)
    }

    var body: some View {
        let list = entries
        Group {
            if list.isEmpty {
                ContentUnavailableView("Nothing here yet",
                                       systemImage: "clock.arrow.circlepath",
                                       description: Text("Once an event goes by, it moves here with what you gave."))
            } else {
                List {
                    ForEach(years, id: \.self) { year in
                        Section(String(year)) {
                            ForEach(list.filter { Calendar.current.component(.year, from: $0.when) == year }) { entry in
                                NavigationLink {
                                    OccasionDetailView(occasion: entry.occasion)
                                } label: {
                                    PastEventRow(occasion: entry.occasion, when: entry.when)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .giftlyBackground()
        .navigationTitle("Past Events")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PastEventRow: View {
    let occasion: Occasion
    let when: Date

    private var detail: String {
        let date = when.formatted(.dateTime.month(.abbreviated).day())
        let bought = occasion.boughtCount
        let total = occasion.wishCount
        var parts: [String] = [date]
        if total > 0 { parts.append("\(bought) of \(total) bought") }
        let spent = occasion.committedTotalCents
        if spent > 0 {
            parts.append((Double(spent) / 100).formatted(.currency(code: "USD").precision(.fractionLength(0))))
        }
        return parts.joined(separator: "  ·  ")
    }

    private var boxColor: Color { Color(hex: occasion.person?.colorHex ?? "#4C8BF5") }

    var body: some View {
        HStack(spacing: 12) {
            GiftBoxMark(color: boxColor, stage: .calm, size: 36, seed: 0, kind: occasion.kind)
                .opacity(0.8)
            VStack(alignment: .leading, spacing: 2) {
                Text(occasion.title).font(.body.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
