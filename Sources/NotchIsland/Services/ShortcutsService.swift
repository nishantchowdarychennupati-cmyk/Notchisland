import Foundation

/// Lists and runs Apple Shortcuts through the built-in `shortcuts` command-line tool.
final class ShortcutsService: ObservableObject {
    @Published private(set) var all: [String] = []
    @Published private(set) var running: String?
    @Published private(set) var isLoading = false

    /// (name, succeeded)
    var onFinish: ((String, Bool) -> Void)?

    private let tool = "/usr/bin/shortcuts"
    private var loaded = false

    func loadIfNeeded() {
        guard !loaded else { return }
        reload()
    }

    func reload() {
        isLoading = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let output = self.runTool(["list"]).output
            let names = output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }.sorted()
            DispatchQueue.main.async {
                self.all = names
                self.loaded = true
                self.isLoading = false
            }
        }
    }

    func run(_ name: String) {
        guard running == nil else { return }
        running = name
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.runTool(["run", name])
            DispatchQueue.main.async {
                self.running = nil
                self.onFinish?(name, result.status == 0)
            }
        }
    }

    func openApp() {
        let url = URL(fileURLWithPath: "/System/Applications/Shortcuts.app")
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/open"), arguments: [url.path])
    }

    private func runTool(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return (-1, "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}
