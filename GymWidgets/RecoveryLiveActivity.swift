import ActivityKit
import SwiftUI
import WidgetKit

struct RecoveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecoveryActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Recupero", systemImage: "timer").font(.headline.bold())
                    Spacer()
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .font(.system(.headline, design: .monospaced).bold())
                        .monospacedDigit()
                }
                Text(context.state.exerciseName).font(.caption).lineLimit(1)
                ProgressView(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .tint(.accentColor)
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.92))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "timer") }
                DynamicIslandExpandedRegion(.center) { Text("RECUPERO").font(.caption.bold()) }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .font(.system(.caption, design: .monospaced).bold()).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: Date()...context.state.endDate, countsDown: true).tint(.accentColor)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .font(.system(size: 12, design: .monospaced).bold()).monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}
