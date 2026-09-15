import SwiftUI
import AppKit
import Combine

// MARK: - 脚本执行器

final class ScriptRunner: ObservableObject {
    @Published var output: String = ""
    @Published var isRunning: Bool = false

    private var process: Process?
    private var outPipe: Pipe?
    private var errPipe: Pipe?

    func run(scriptName: String, arguments: [String] = [], environment: [String: String] = [:]) {
        guard !isRunning else { return }
        isRunning = true
        output = ""

        guard let scriptURL = ScriptPaths.url(for: scriptName) else {
            output = "未找到脚本：\(scriptName)"
            isRunning = false
            return
        }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        var args = [scriptURL.path]
        args.append(contentsOf: arguments)
        p.arguments = args
        p.standardInput = FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        p.environment = env

        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err
        outPipe = out
        errPipe = err

        out.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.append(s) }
        }
        err.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.append(s) }
        }

        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.append("\n[进程结束，退出码 \(proc.terminationStatus)]")
                self?.isRunning = false
                self?.process = nil
            }
        }

        process = p
        do {
            try p.run()
        } catch {
            append("启动失败：\(error.localizedDescription)")
            isRunning = false
        }
    }

    func cancel() {
        if let p = process, p.isRunning {
            p.terminate()
        }
    }

    private func append(_ s: String) {
        output += ScriptRunner.stripANSI(s)
    }

    private static func stripANSI(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\x1B\\[[0-9;]*[a-zA-Z]", options: []) else {
            return s
        }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return regex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "")
    }
}

enum ScriptPaths {
    static func url(for name: String) -> URL? {
        if let res = Bundle.main.resourceURL {
            let u = res.appendingPathComponent("Scripts").appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: u.path) {
                return u
            }
        }
        if let exeDir = Bundle.main.executableURL?.deletingLastPathComponent() {
            let u = exeDir.appendingPathComponent("Scripts").appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: u.path) {
                return u
            }
        }
        return nil
    }
}

// MARK: - 模块定义

enum Module: String, Identifiable, CaseIterable {
    case cache = "缓存清理"
    case quicklook = "快速预览"
    case brew = "Homebrew"
    case npm = "npm 代理"
    case newTxt = "新建txt在桌面"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .cache: return "trash"
        case .quicklook: return "eye"
        case .brew: return "terminal"
        case .npm: return "shippingbox"
        case .newTxt: return "doc.badge.plus"
        }
    }

    var detail: String {
        switch self {
        case .cache: return "清理用户缓存与日志，释放磁盘空间"
        case .quicklook: return "重置快速预览服务并重启访达"
        case .brew: return "通过代理测试连接并安装软件包"
        case .npm: return "通过代理管理全局 npm 包"
        case .newTxt: return "在指定位置快速新建 txt 文档"
        }
    }
}

// MARK: - 主界面

struct HomeView: View {
    @State private var selected: Module?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mac 工具箱")
                    .font(.largeTitle)
                    .bold()
                Text("选择要处理的问题模块")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 22)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Module.allCases) { module in
                    Button {
                        selected = module
                    } label: {
                        ModuleCard(module: module)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .sheet(item: $selected) { module in
            switch module {
            case .cache: CacheView()
            case .quicklook: QuickLookView()
            case .brew: BrewView()
            case .npm: NpmView()
            case .newTxt: NewTxtView()
            }
        }
    }
}

// MARK: - 模块卡片

struct ModuleCard: View {
    let module: Module
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: module.symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.33, green: 0.56, blue: 0.93),
                                    Color(red: 0.15, green: 0.35, blue: 0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(module.rawValue)
                    .font(.headline)
                Text(module.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(hovering ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(hovering ? Color.accentColor : Color.gray.opacity(0.25), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering = $0 }
    }
}

// MARK: - 通用组件

struct SheetHeader: View {
    let title: String
    let symbol: String
    let desc: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.accentColor.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2)
                    .bold()
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

struct LogView: View {
    @ObservedObject var runner: ScriptRunner

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(runner.output.isEmpty ? "运行输出将显示在这里" : runner.output)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(runner.output.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .textSelection(.enabled)
                    .id("log-bottom")
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .onChange(of: runner.output) { _ in
                withAnimation {
                    proxy.scrollTo("log-bottom", anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - 模块一：缓存清理

struct CacheView: View {
    @StateObject private var runner = ScriptRunner()
    @Environment(\.dismiss) private var dismiss

    @State private var cacheSize = "计算中…"
    @State private var logSize = "计算中…"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: "缓存清理", symbol: "trash", desc: "清理 ~/Library/Caches 与 ~/Library/Logs 下的内容")

            GroupBox("待清理内容") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("~/Library/Caches")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 180, alignment: .leading)
                        Text(cacheSize).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("~/Library/Logs")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 180, alignment: .leading)
                        Text(logSize).foregroundColor(.secondary)
                    }
                    Text("不会处理系统目录、开发者数据或系统快照。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            LogView(runner: runner)
                .frame(minHeight: 150)

            HStack {
                Button("清理") {
                    runner.run(scriptName: "clean_user_caches_logs.sh", arguments: ["--yes"])
                }
                .keyboardShortcut(.defaultAction)
                .disabled(runner.isRunning)

                if runner.isRunning {
                    Button("取消") { runner.cancel() }
                }

                Spacer()

                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 440)
        .onAppear(perform: loadSizes)
    }

    private func loadSizes() {
        DispatchQueue.global(qos: .userInitiated).async {
            let c = Self.dirSize(NSString(string: "~/Library/Caches").expandingTildeInPath)
            let l = Self.dirSize(NSString(string: "~/Library/Logs").expandingTildeInPath)
            DispatchQueue.main.async {
                cacheSize = c
                logSize = l
            }
        }
    }

    private static func dirSize(_ path: String) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        p.arguments = ["-sh", path]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            return "—"
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        if let s = String(data: data, encoding: .utf8) {
            return s.components(separatedBy: .whitespacesAndNewlines).first ?? "—"
        }
        return "—"
    }
}

// MARK: - 模块二：快速预览

struct QuickLookView: View {
    @StateObject private var runner = ScriptRunner()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: "快速预览修复", symbol: "eye", desc: "重置 Quick Look 缓存并重启访达")

            Text("适用于选中文件后按空格无法预览、预览内容错乱等情况。")
                .font(.callout)
                .foregroundColor(.secondary)

            LogView(runner: runner)
                .frame(minHeight: 150)

            HStack {
                Button("立即修复") {
                    runner.run(scriptName: "fix_quicklook.sh")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(runner.isRunning)

                if runner.isRunning {
                    Button("取消") { runner.cancel() }
                }

                Spacer()

                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 380)
    }
}

// MARK: - 模块三：Homebrew

struct BrewView: View {
    @StateObject private var runner = ScriptRunner()
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @AppStorage("brewProxyPort") private var port = "7892"

    private var portValue: String {
        let t = port.trimmed
        return t.isEmpty ? "7892" : t
    }

    private var proxyEnv: [String: String] {
        ["HTTP_PORT": portValue, "SOCKS_PORT": portValue]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: "Homebrew 代理", symbol: "terminal", desc: "通过代理测试连接并安装 Homebrew 软件包")

            GroupBox("代理端口") {
                HStack(spacing: 8) {
                    Text("HTTP / SOCKS 端口")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("7892", text: $port)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                .padding(8)
            }

            GroupBox("安装目标") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("输入包名或前缀（多个包名用空格分隔，留空则仅测试连接）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("例如：poppler 或 p", text: $input)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(8)
            }

            LogView(runner: runner)
                .frame(minHeight: 150)

            HStack {
                Button("测试连接") {
                    runner.run(scriptName: "brew_proxy_manager.sh", arguments: ["test"], environment: proxyEnv)
                }
                .disabled(runner.isRunning)

                Button("安装指定包") {
                    let packages = input.split(separator: " ").map(String.init)
                    runner.run(scriptName: "brew_proxy_manager.sh", arguments: ["install"] + packages, environment: proxyEnv)
                }
                .disabled(runner.isRunning || input.trimmed.isEmpty)

                Button("按前缀安装") {
                    runner.run(scriptName: "brew_proxy_manager.sh", arguments: ["install-prefix", input.trimmed], environment: proxyEnv)
                }
                .disabled(runner.isRunning || input.trimmed.isEmpty)

                if runner.isRunning {
                    Button("取消") { runner.cancel() }
                }

                Spacer()

                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 520)
    }
}

// MARK: - 模块四：npm 代理

struct NpmView: View {
    @StateObject private var runner = ScriptRunner()
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @AppStorage("npmProxyPort") private var port = "7892"

    private var portValue: String {
        let t = port.trimmed
        return t.isEmpty ? "7892" : t
    }

    private var proxyEnv: [String: String] {
        ["HTTP_PORT": portValue, "SOCKS_PORT": portValue]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: "npm 代理管理", symbol: "shippingbox", desc: "通过代理管理全局 npm 包")

            GroupBox("代理端口") {
                HStack(spacing: 8) {
                    Text("HTTP / SOCKS 端口")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("7892", text: $port)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                .padding(8)
            }

            GroupBox("包名") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("留空则使用默认包 @openai/codex")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("包名（可选）", text: $input)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(8)
            }

            LogView(runner: runner)
                .frame(minHeight: 150)

            HStack(spacing: 8) {
                Button("测试") { run("test") }
                Button("安装") { run("install") }
                Button("更新") { run("update") }
                Button("重装") { run("reinstall") }
                Button("检查") { run("check") }
                Button("版本") { run("version") }
            }
            .disabled(runner.isRunning)

            HStack {
                if runner.isRunning {
                    Button("取消") { runner.cancel() }
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 540, minHeight: 530)
    }

    private func run(_ action: String) {
        var args = [action]
        let trimmed = input.trimmed
        if !trimmed.isEmpty {
            args.append(trimmed)
        }
        runner.run(scriptName: "npm_proxy_manager.sh", arguments: args, environment: proxyEnv)
    }
}

// MARK: - 模块五：新建文本文件

struct NewTxtView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
    @State private var fileName = ""
    @State private var message = ""
    @State private var success = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: "新建文本文件", symbol: "doc.badge.plus", desc: "在指定位置快速新建 txt 文档")

            GroupBox("保存位置") {
                HStack(spacing: 8) {
                    TextField("选择或输入保存目录", text: $directory)
                        .textFieldStyle(.roundedBorder)
                    Button("选择…") { chooseDirectory() }
                }
                .padding(8)
            }

            GroupBox("文档名称") {
                HStack(spacing: 8) {
                    TextField("文档名称（可省略 .txt 后缀）", text: $fileName)
                        .textFieldStyle(.roundedBorder)
                    Text(".txt")
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            if !message.isEmpty {
                Text(message)
                    .foregroundColor(success ? .green : .red)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            HStack {
                Button("创建") { createFile() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(directory.trimmed.isEmpty || fileName.trimmed.isEmpty)
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 340)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "选择"
        if panel.runModal() == .OK {
            directory = panel.url?.path ?? ""
        }
    }

    private func createFile() {
        var name = fileName.trimmed
        if !name.lowercased().hasSuffix(".txt") {
            name += ".txt"
        }
        let dir = directory.trimmed
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else {
            message = "保存目录不存在：\(dir)"
            success = false
            return
        }
        let url = URL(fileURLWithPath: dir).appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) {
            message = "已存在同名文件，未覆盖：\(url.path)"
            success = false
            return
        }

        // 先尝试直接创建
        do {
            try Data().write(to: url)
            message = "已创建：\(url.path)"
            success = true
            return
        } catch {
            // 权限不足时，尝试以管理员权限创建
        }

        if createWithAdminPrivileges(at: url.path) {
            message = "已创建：\(url.path)"
            success = true
        } else {
            message = "创建失败：未获得管理员权限（可能已取消授权）"
            success = false
        }
    }

    private func createWithAdminPrivileges(at path: String) -> Bool {
        let command = "touch \(Self.shellEscaped(path))"
        let script = "do shell script \"\(command)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func shellEscaped(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

// MARK: - 扩展

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
