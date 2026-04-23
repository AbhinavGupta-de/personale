#if os(macOS)
import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum CSVExport {
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    /// Export last 30 days of per-category time as CSV.
    static func exportLast30Days() async {
        let cal = Calendar.current
        let today = ActivityViewModel.effectiveToday(dayStartHour: AppSettings.shared.dayStartHour)
        let from = cal.date(byAdding: .day, value: -29, to: today) ?? today
        let fromStr = dateFmt.string(from: from)
        let toStr = dateFmt.string(from: today)

        guard let range = try? await APIClient.shared.fetchRange(from: fromStr, to: toStr) else {
            showAlert("Export failed", info: "Couldn't fetch range data from the server.")
            return
        }

        var csv = "date,category,seconds,duration\n"
        for day in range.days {
            for cat in day.categories {
                let h = cat.seconds / 3600, m = (cat.seconds % 3600) / 60
                let dur = h > 0 ? "\(h)h \(m)m" : "\(m)m"
                csv += "\(day.date),\(escape(cat.category)),\(cat.seconds),\(dur)\n"
            }
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "personale-\(fromStr)-to-\(toStr).csv"
        panel.message = "Export last 30 days of tracked time"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            showAlert("Write failed", info: error.localizedDescription)
        }
    }

    private static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    private static func showAlert(_ message: String, info: String) {
        let a = NSAlert()
        a.messageText = message
        a.informativeText = info
        a.alertStyle = .warning
        a.runModal()
    }
}
#endif
