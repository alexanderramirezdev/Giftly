//
//  ContactImport.swift
//  Giftly
//
//  Import people from Contacts with the SYSTEM contact picker. The picker
//  runs out of process and needs no Contacts permission: Giftly only ever
//  receives the people the parent taps. That keeps the privacy story clean.
//
//  What we take from each card (only if present): name, photo, birthday
//  (becomes a repeating Birthday occasion), anniversary dates (Anniversary
//  occasion), job title. If the birthday includes a year we derive an age
//  group (child / teen / adult) and never store the year itself.
//

import SwiftUI
import SwiftData
import Contacts
import ContactsUI
import UIKit

// MARK: - Picker presenter

/// Present with `.background(ContactPickerPresenter(isPresented: $flag) { contacts in ... })`.
/// CNContactPickerViewController misbehaves when embedded in a SwiftUI sheet,
/// so this hosts an invisible view controller and presents the picker from it.
struct ContactPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: ([CNContact]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, !context.coordinator.isShowing else { return }
        context.coordinator.isShowing = true
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        DispatchQueue.main.async {
            host.present(picker, animated: true)
        }
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerPresenter
        var isShowing = false

        init(_ parent: ContactPickerPresenter) { self.parent = parent }

        // Implementing the plural form turns on multi-select in the picker.
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            isShowing = false
            parent.isPresented = false
            parent.onPick(contacts)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            isShowing = false
            parent.isPresented = false
        }
    }
}

// MARK: - Mapping contacts to people

enum ContactImporter {

    struct Result {
        var added = 0
        var updated = 0
        var occasions = 0
    }

    private static let palette = ["#4C8BF5", "#E4572E", "#2F7D4F", "#B565C9", "#E3B04B", "#17BEBB", "#C0392B"]

    /// Adds new people or fills blanks on people already imported. Never
    /// overwrites something the parent typed.
    @discardableResult
    static func importContacts(_ contacts: [CNContact], into context: ModelContext, existing: [Person]) -> Result {
        var result = Result()
        var known = existing

        for contact in contacts {
            let name = displayName(for: contact)
            guard !name.isEmpty else { continue }

            let person: Person
            if let match = known.first(where: { $0.contactIdentifier == contact.identifier })
                ?? known.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                person = match
                result.updated += 1
            } else {
                person = Person(name: name, colorHex: palette.randomElement() ?? "#4C8BF5")
                context.insert(person)
                known.append(person)
                result.added += 1
            }

            if person.contactIdentifier.isEmpty { person.contactIdentifier = contact.identifier }

            if person.photoData == nil,
               contact.isKeyAvailable(CNContactThumbnailImageDataKey),
               let photo = contact.thumbnailImageData {
                person.photoData = photo
            }

            if person.jobTitle.isEmpty, contact.isKeyAvailable(CNContactJobTitleKey) {
                person.jobTitle = contact.jobTitle
            }

            // Birthday -> repeating Birthday occasion (+ age group if a year is present).
            if contact.isKeyAvailable(CNContactBirthdayKey), let birthday = contact.birthday,
               let date = nextDate(month: birthday.month, day: birthday.day) {
                if let year = birthday.year, year != NSDateComponentUndefined, person.ageBand.isEmpty {
                    person.ageBand = ageBand(birthYear: year)
                }
                let hasBirthday = (person.occasions ?? []).contains { $0.kind == .birthday }
                if !hasBirthday {
                    let o = Occasion(title: "\(person.firstName)'s Birthday", kind: .birthday,
                                     date: date, repeatsAnnually: true, person: person)
                    context.insert(o)
                    result.occasions += 1
                }
            }

            // Anniversary dates -> repeating Anniversary occasion.
            if contact.isKeyAvailable(CNContactDatesKey) {
                for labeled in contact.dates where labeled.label == CNLabelDateAnniversary {
                    let comps = labeled.value as DateComponents
                    guard let date = nextDate(month: comps.month, day: comps.day) else { continue }
                    let hasAnniversary = (person.occasions ?? []).contains { $0.kind == .anniversary }
                    if !hasAnniversary {
                        let o = Occasion(title: "\(person.firstName)'s Anniversary", kind: .anniversary,
                                         date: date, repeatsAnnually: true, person: person)
                        context.insert(o)
                        result.occasions += 1
                    }
                }
            }
        }
        return result
    }

    static func displayName(for contact: CNContact) -> String {
        var parts: [String] = []
        if contact.isKeyAvailable(CNContactGivenNameKey), !contact.givenName.isEmpty { parts.append(contact.givenName) }
        if contact.isKeyAvailable(CNContactFamilyNameKey), !contact.familyName.isEmpty { parts.append(contact.familyName) }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        if contact.isKeyAvailable(CNContactNicknameKey), !contact.nickname.isEmpty { return contact.nickname }
        if contact.isKeyAvailable(CNContactOrganizationNameKey) { return contact.organizationName }
        return ""
    }

    /// The next upcoming month/day, so the stored date is sensible.
    static func nextDate(month: Int?, day: Int?) -> Date? {
        guard let month, let day, month != NSDateComponentUndefined, day != NSDateComponentUndefined else { return nil }
        let cal = Calendar.current
        return cal.nextDate(after: cal.startOfDay(for: .now).addingTimeInterval(-1),
                            matching: DateComponents(month: month, day: day),
                            matchingPolicy: .nextTimePreservingSmallerComponents)
    }

    static func ageBand(birthYear: Int) -> String {
        let age = Calendar.current.component(.year, from: .now) - birthYear
        if age < 13 { return "child" }
        if age < 18 { return "teen" }
        return "adult"
    }
}
