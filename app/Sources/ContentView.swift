import SwiftUI

struct ContentView: View {
    @StateObject private var manager = WeChatManager()
    @State private var showDeleteConfirm = false
    @State private var instanceToDelete: WeChatInstance?

    var body: some View {
        VStack(spacing: 0) {
            // Instance list
            if manager.instances.isEmpty && !manager.isLoading {
                emptyState
            } else {
                instanceList
            }

            Divider()

            // Bottom bar
            bottomBar
        }
        .frame(minWidth: 520, minHeight: 380)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: { manager.scan() }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(manager.isLoading)
                .keyboardShortcut("r", modifiers: .command)

                Button(action: {
                    Task { await manager.createCopy() }
                }) {
                    Label("新增副本", systemImage: "plus")
                }
                .disabled(manager.isLoading)
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .overlay {
            if manager.isLoading {
                loadingOverlay
            }
        }
        .alert("错误", isPresented: $manager.showError, actions: {
            Button("确定", role: .cancel) {}
        }, message: {
            Text(manager.errorMessage ?? "未知错误")
        })
        .alert("确认删除", isPresented: $showDeleteConfirm, actions: {
            Button("取消", role: .cancel) {
                instanceToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let instance = instanceToDelete {
                    Task { await manager.deleteCopy(instance) }
                    instanceToDelete = nil
                }
            }
        }, message: {
            if let instance = instanceToDelete {
                Text("确定要删除 \(instance.name) 吗？\n此操作不可恢复。")
            }
        })
        .onAppear {
            manager.scan()
        }
    }

    // MARK: - Instance List

    private var instanceList: some View {
        List {
            ForEach(manager.instances) { instance in
                instanceRow(instance)
                    .listRowSeparator(.visible)
            }
        }
        .listStyle(.inset)
    }

    private func instanceRow(_ instance: WeChatInstance) -> some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor(for: instance))
                .frame(width: 10, height: 10)

            // App icon
            appIcon(for: instance)
                .frame(width: 32, height: 32)

            // Name & version
            VStack(alignment: .leading, spacing: 2) {
                Text(instance.name)
                    .font(.system(size: 13, weight: .medium))
                Text("v\(instance.version)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // Status tag
            Text(instance.statusText)
                .font(.system(size: 11))
                .foregroundColor(instance.needsUpdate ? .orange : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(instance.needsUpdate ? Color.orange.opacity(0.12) : Color.clear)
                )

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                if instance.isRunning {
                    Button("停止") { manager.stopInstance(instance) }
                        .controlSize(.small)
                } else {
                    Button("启动") { manager.launchInstance(instance) }
                        .controlSize(.small)
                }

                if !instance.isOriginal {
                    Button("删除") {
                        instanceToDelete = instance
                        showDeleteConfirm = true
                    }
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(for instance: WeChatInstance) -> Color {
        if instance.isRunning { return .green }
        if instance.needsUpdate { return .orange }
        return .gray.opacity(0.4)
    }

    private func appIcon(for instance: WeChatInstance) -> some View {
        Group {
            let iconPath = "\(instance.path)/Contents/Resources/AppIcon.icns"
            if let image = NSImage(contentsOfFile: iconPath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.green)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("未检测到微信应用")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("请确认 /Applications/WeChat.app 已安装")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            let copyCount = manager.instances.filter { !$0.isOriginal }.count
            let total = manager.instances.count
            Text("共 \(total) 个实例（1 个原版 + \(copyCount) 个副本）")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            let hasUpdates = manager.instances.contains { $0.needsUpdate }
            Button("更新所有副本") {
                Task { await manager.updateAllCopies() }
            }
            .disabled(!hasUpdates || manager.isLoading)
            .controlSize(.regular)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.15)
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.9)
                Text(manager.progressMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
