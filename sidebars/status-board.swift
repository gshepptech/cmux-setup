let attention = workspaces.filter { $0.unread > 0 }
let working = workspaces.filter { $0.unread == 0 && $0.progress != nil }
let dirty = workspaces.filter { $0.unread == 0 && $0.progress == nil && $0.dirty == true }
let quiet = workspaces.filter { $0.unread == 0 && $0.progress == nil && $0.dirty != true }

func lane(_ title: String, _ tint: String, _ items: [Any]) -> some View {
    return VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 11))
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundColor("#8A96A4")
            Spacer()
            Text("\(items.count)")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundColor("#5E6B7A")
        }
        .padding(6)

        ForEach(items.prefix(8)) { w in
            Button(action: { cmux("workspace.select", workspace_id: w.id) }) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tint)
                        .frame(width: 3, height: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.title)
                            .font(.system(size: 13))
                            .fontWeight(w.selected ? .semibold : .regular)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundColor(w.selected ? "#F5F1EA" : "#C2CBD5")
                        if let b = w.branch {
                            Text(b)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundColor("#7A8695")
                        }
                    }
                    Spacer()
                    if w.unread > 0 {
                        Text("\(w.unread)")
                            .font(.system(size: 11))
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundColor("#0E1319")
                            .padding(3)
                            .background("#E4572E")
                            .clipShape(Capsule())
                    }
                }
                .padding(7)
                .background(w.selected ? "#1B2531" : "#131A22")
                .cornerRadius(6)
            }
            .padding(3)
        }
    }
}

VStack(alignment: .leading, spacing: 0) {
    HStack(spacing: 6) {
        Image(systemName: "chart.bar.doc.horizontal.fill")
            .font(.system(size: 13))
            .foregroundColor("#E4572E")
        Text("Status Board")
            .font(.system(size: 12))
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .foregroundColor("#A7B2BF")
        Spacer()
        Text(clock.time)
            .font(.system(size: 12))
            .monospacedDigit()
            .foregroundColor("#7A8695")
    }
    .padding(10)

    Divider()

    ScrollView {
        VStack(alignment: .leading, spacing: 10) {
            if attention.count > 0 { lane("Needs Attention", "#E4572E", attention) }
            if working.count > 0 { lane("Working", "#E8B04B", working) }
            if dirty.count > 0 { lane("Uncommitted", "#6BA4E4", dirty) }
            if quiet.count > 0 { lane("Quiet", "#4B9E78", quiet) }
        }
        .padding(6)
    }

    Spacer()
    Divider()

    HStack(spacing: 6) {
        Text("\(workspaceCount)")
            .font(.system(size: 13))
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundColor("#A7B2BF")
        Text("workspaces")
            .font(.system(size: 12))
            .foregroundColor("#7A8695")
        Spacer()
    }
    .padding(10)
}
