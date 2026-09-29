import Foundation

/// Python Agent 服务生命周期管理（本地 FastAPI，127.0.0.1:8765）
@MainActor
final class AgentServer: ObservableObject {
    enum State {
        case stopped
        case starting
        case running
        case failed(String)
    }

    @Published private(set) var state: State = .stopped

    private var process: Process?
    private let baseURL = URL(string: "http://127.0.0.1:8765")!

    /// 确保服务已启动；已运行则直接返回
    func ensureRunning() async {
        if await isHealthy() {
            state = .running
            return
        }
        start()
    }

    func stop() {
        process?.terminate()
        process = nil
        state = .stopped
    }

    private func start() {
        guard process == nil else { return }
        guard let dir = backendDirectory else {
            state = .failed("未找到 Agent 后端目录，请设置 MACFIX_AGENT_DIR")
            return
        }
        state = .starting

        let task = Process()
        // GUI 启动的应用 PATH 很精简，优先直接使用 .venv 里的 python，避免找不到 uv
        let venvPython = dir.appendingPathComponent(".venv/bin/python")
        if FileManager.default.isExecutableFile(atPath: venvPython.path) {
            task.executableURL = venvPython
            task.arguments = ["-m", "macfix_agent"]
        } else {
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["uv", "run", "python", "-m", "macfix_agent"]
        }
        task.currentDirectoryURL = dir
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            process = task
            state = .running
        } catch {
            state = .failed("无法启动 Agent 服务：\(error.localizedDescription)")
        }
    }

    private func isHealthy() async -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("health"))
        request.timeoutInterval = 1.5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// 定位后端目录：环境变量 > 打包资源 > 开发期从 .app 位置逐级向上查找
    private var backendDirectory: URL? {
        if let dir = ProcessInfo.processInfo.environment["MACFIX_AGENT_DIR"], !dir.isEmpty {
            return URL(fileURLWithPath: dir)
        }
        if let res = Bundle.main.resourceURL?.appendingPathComponent("agent"),
           FileManager.default.fileExists(atPath: res.appendingPathComponent("macfix_agent").path) {
            return res
        }
        // 开发期：从 .app 位置逐级向上，查找包含 macfix_agent 包的 agent 目录
        var dir = Bundle.main.bundleURL
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("agent")
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("macfix_agent").path) {
                return candidate
            }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }
}