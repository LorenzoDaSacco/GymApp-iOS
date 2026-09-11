import ActivityKit
import SwiftUI
import WidgetKit

struct RecoveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecoveryActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Recupero", systemImage: "timer")
                        .font(.headline.bold())
                    Spacer()
                    Text(timerInterval: Date()...context.attributes.endDate, countsDown: true)
                        .font(.system(.headline, design: .monospaced).bold())
                }

                Text(context.attributes.exerciseName)
                    .font(.caption)
                    .lineLimit(1)

                ProgressView(timerInterval: Date()...context.attributes.endDate, countsDown: true)
                    .tint(.accentColor)

                Text("Puoi ripartire quando il timer arriva a 0:00")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.9))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Recupero", systemImage: "timer")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.attributes.endDate, countsDown: true)
                        .font(.system(.title3, design: .monospaced).bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.attributes.exerciseName)
                            .font(.caption)
                            .lineLimit(1)
                        ProgressView(timerInterval: Date()...context.attributes.endDate, countsDown: true)
                            .tint(.accentColor)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(timerInterval: Date()...context.attributes.endDate, countsDown: true)
                    .font(.system(.caption, design: .monospaced).bold())
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}
