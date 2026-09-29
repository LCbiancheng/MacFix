import SwiftUI

/// Agent 聊天面板：向本地服务流式请求并渲染
@MainActor
final class AgentChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String?

    private let server = AgentServer()
    private let sessionID = UUID().uuidString
    private let endpoint = URL(string: "http://127.0.0.1:8765/chat")!

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        input = ""
        messages.append(ChatMessage(role: .user, content: text))
        let assistantIndex = messages.count
        messages.append(ChatMessage(role: .assistant, content: ""))
        isStreaming = true
        errorMessage = nil

        Task {
            await server.ensureRunning()
            if case .failed(let msg) = server.state {
                errorMessage = msg
                messages[assistantIndex].content = "（无法连接到 Agent 服务：\(msg)）"
                isStreaming = false
                return
            }
            await stream(assistantIndex: assistantIndex, text: text)
        }
    }

    private func stream(assistantIndex: Int, text: String) async {
        defer { isStreaming = false }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "session_id": sessionID,
            "message": text,
        ])

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                await consumeError(from: bytes)
                return
            }

            var currentEvent = ""
            for try await line in bytes.lines {
                if line.hasPrefix("event: ") {
                    currentEvent = String(line.dropFirst("event: ".count))
                } else if line.hasPrefix("data: ") {
                    let payload = String(line.dropFirst("data: ".count))
                    handle(event: currentEvent, payload: payload, index: assistantIndex)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handle(event: String, payload: String, index: Int) {
        guard let data = payload.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        switch event {
        case "token":
            if let t = obj["text"] as? String {
                messages[index].content += t
            }
        case "error":
            if let m = obj["message"] as? String {
                errorMessage = m
                if messages[index].content.isEmpty { messages[index].content = m }
            }
        default:
            break
        }
    }

    /// 非 200 响应时读取 FastAPI 的 {"detail": "..."}
    private func consumeError(from bytes: URLSession.AsyncBytes) async {
        var body = ""
        do {
            for try await line in bytes.lines { body += line }
        } catch {}
        if let data = body.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = obj["detail"] as? String {
            errorMessage = detail
            if let last = messages.indices.last {
                messages[last].content = detail
            }
        }
    }
}

struct AgentChatView: View {
    @StateObject private var viewModel = AgentChatViewModel()
    @State private var showSettings = false
    @Binding var isExpanded: Bool
    var inputFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text("智能助手")
                        .font(.headline)
                    Text(isExpanded ? "对话记录" : "点击此处开始对话")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 8)

                if viewModel.isStreaming {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.42)) {
                        isExpanded.toggle()
                    }
                    if !isExpanded {
                        inputFocused.wrappedValue = false
                    }
                } label: {
                    Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "收起对话框" : "展开对话框")

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Agent 设置")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.messages.isEmpty {
                        EmptyChatState()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { expandIfNeeded() }
                    } else {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.messages) { msg in
                                MessageBubble(message: msg)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: viewModel.messages.last?.content ?? "") { _ in
                    guard let last = viewModel.messages.last else { return }
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("输入问题，例如：帮我释放磁盘空间", text: $viewModel.input)
                    .textFieldStyle(.roundedBorder)
                    .focused(inputFocused)
                    .onSubmit { viewModel.send() }
                Button("发送") { viewModel.send() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(viewModel.isStreaming ||
                              viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isExpanded ? 0.95 : 0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { expandIfNeeded() }
        .environment(\.colorScheme, .light)
        .sheet(isPresented: $showSettings) {
            AgentSettingsView()
        }
    }

    private func expandIfNeeded() {
        guard !isExpanded else { return }
        withAnimation(.easeInOut(duration: 0.42)) {
            isExpanded = true
        }
    }
}

private struct EmptyChatState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.accentColor.opacity(0.78))
            Text("有什么可以帮你处理？")
                .font(.callout.weight(.medium))
            Text("输入问题，智能助手会协助完成诊断")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            Text(message.content.isEmpty ? " " : message.content)
                .font(.callout)
                .foregroundColor(message.role == .user ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(message.role == .user ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                )
                .textSelection(.enabled)

            if message.role != .user { Spacer(minLength: 40) }
        }
    }
}
