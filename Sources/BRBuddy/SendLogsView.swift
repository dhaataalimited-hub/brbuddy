import AppKit
import BRBuddyCore
import SwiftUI

/// **Send Logs…**: shows the whole report first (a short header about the Mac, then BRBuddy's log), then lets the
/// user email it to BRBuddy, save it for a GitHub issue, or copy it. Nothing is sent without one of those clicks.
/// Opened by `AppWindows` from the menu bar item and Settings → General.
struct SendLogsView: View {
    let state: AppState
    @State private var report = ""
    @State private var savedFile: URL?
    @State private var note: String?

    static let size = CGSize(width: 620, height: 520)
    static let address = "hello@dhaataa.com"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send logs to BRBuddy")
                .font(.title2.weight(.semibold))
            Text("This is everything that will be sent: your BRBuddy version, macOS, the Mac model and screens, and what BRBuddy did recently. It never includes passwords, what you type, terminal or mirror text, your notes, or project names.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                Text(report)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))

            if let note {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Button("Clear Log") { clear() }
                    .help("Deletes BRBuddy's log on this Mac")
                Spacer()
                Button("Copy") { copy() }
                Button("Save for GitHub…") { saveAndReveal() }
                    .help("Saves the report and shows it in Finder, to attach to a GitHub issue")
                Button("Email to BRBuddy…") { email() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: Self.size.width, height: Self.size.height)
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in refresh() }
    }

    private func refresh() {
        report = DiagnosticReport.make(header: AppLog.header(state: state), log: DiagnosticLog.shared.contents())
    }

    /// Writes the report next to the log, as a .txt file to attach.
    private func save() -> URL? {
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)
            .timeSeparator(.omitted).dateTimeSeparator(.space))
        let url = DiagnosticLog.shared.folder.appending(path: "BRBuddy report \(stamp).txt")
        do {
            try FileManager.default.createDirectory(at: DiagnosticLog.shared.folder, withIntermediateDirectories: true)
            try report.write(to: url, atomically: true, encoding: .utf8)
            savedFile = url
            return url
        } catch {
            note = "Couldn't save the report: \(error.localizedDescription)"
            return nil
        }
    }

    private func email() {
        AppLog.info(.app, "Send Logs: email")
        refresh()
        guard let file = save() else { return }
        let subject = "BRBuddy logs (\(AppVersion.label()))"
        let message = "Hi BRBuddy,\n\nWhat happened:\n\n\nThe report is attached.\n"
        if let service = NSSharingService(named: .composeEmail), service.canPerform(withItems: [message, file]) {
            service.recipients = [Self.address]
            service.subject = subject
            service.perform(withItems: [message, file])
            note = "Your mail app has the report attached. Add what happened, then send it."
        } else {
            // No mail app set up: open a blank email and show the file to attach by hand.
            var parts = URLComponents()
            parts.scheme = "mailto"
            parts.path = Self.address
            parts.queryItems = [URLQueryItem(name: "subject", value: subject)]
            if let url = parts.url { NSWorkspace.shared.open(url) }
            NSWorkspace.shared.activateFileViewerSelecting([file])
            note = "Attach the report shown in Finder to the email, or send it to \(Self.address)."
        }
    }

    private func saveAndReveal() {
        AppLog.info(.app, "Send Logs: saved for GitHub")
        refresh()
        guard let file = save() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([file])
        note = "Saved. Attach it to an issue at github.com/dhaataalimited-hub/brbuddy/issues."
    }

    private func copy() {
        refresh()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        note = "Copied."
    }

    private func clear() {
        DiagnosticLog.shared.clear()
        AppLog.info(.app, "Log cleared")
        refresh()
        note = "The log on this Mac was cleared."
    }
}
