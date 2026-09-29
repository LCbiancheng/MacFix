import SwiftUI
import Foundation

/// 供应商预设：切换时自动填入默认 API 地址与模型
private struct ProviderPreset: Identifiable {
    let id: String
    let label: String
    let baseURL: String
    let model: String
}

private let presets: [ProviderPreset] = [
    .init(id: "deepseek", label: "DeepSeek", baseURL: "https://api.deepseek.com/v1", model: "deepseek-chat"),
    .init(id: "qwen", label: "通义千问", baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", model: "qwen-plus"),
    .init(id: "kimi", label: "Kimi (Moonshot)", baseURL: "https://api.moonshot.cn/v1", model: "moonshot-v1-8k"),
    .init(id: "openai", label: "OpenAI", baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini"),
]

/// Agent 设置：配置模型供应商、API Key 与模型，写入本地 config.json
struct AgentSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var providerKey = "deepseek"
    @State private var baseURL = ""
    @State private var model = ""
    @State private var apiKey = ""
    @State private var allProviders: [String: [String: Any]] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Agent 设置")
                .font(.title2)
                .bold()

            Picker("模型供应商", selection: $providerKey) {
                ForEach(presets) { p in
                    Text(p.label).tag(p.id)
                }
            }
            .onChange(of: providerKey) { _ in
                loadFields(for: providerKey)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API 地址").font(.caption).foregroundColor(.secondary)
                TextField("https://api.deepseek.com/v1", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("模型").font(.caption).foregroundColor(.secondary)
                TextField("deepseek-chat", text: $model)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API Key").font(.caption).foregroundColor(.secondary)
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear(perform: load)
    }

    private func configURL() -> URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacFix/agent")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: configURL()),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        providerKey = root["provider"] as? String ?? "deepseek"
        allProviders = root["providers"] as? [String: [String: Any]] ?? [:]
        loadFields(for: providerKey)
    }

    private func loadFields(for key: String) {
        if let p = allProviders[key], !p.isEmpty {
            baseURL = p["base_url"] as? String ?? ""
            model = p["model"] as? String ?? ""
            apiKey = p["api_key"] as? String ?? ""
        } else if let preset = presets.first(where: { $0.id == key }) {
            baseURL = preset.baseURL
            model = preset.model
            apiKey = ""
        }
    }

    private func save() {
        let url = configURL()
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = obj
        }

        root["provider"] = providerKey
        var providers = root["providers"] as? [String: [String: Any]] ?? [:]
        providers[providerKey] = [
            "base_url": baseURL,
            "model": model,
            "api_key": apiKey,
        ]
        root["providers"] = providers

        if let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted]) {
            try? data.write(to: url)
        }
        dismiss()
    }
}