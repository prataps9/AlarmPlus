# Adding the iOS home screen widget

The Android home screen widget (streak + next alarm) already ships —
`android/app/src/main/kotlin/com/alarmplus/app/AlarmWidgetProvider.kt` — and
the Dart-side sync layer (`lib/core/services/widget_sync_service.dart`, using
the `home_widget` package) already works cross-platform. What's missing is
the iOS half: a WidgetKit extension target, which **must be created in
Xcode on a Mac** — it can't be done by hand-editing `project.pbxproj`
reliably, and there was no Xcode available to build/verify one when this was
written.

`WidgetSyncService` already calls `HomeWidget.setAppGroupId('group.com.alarmplus.app')`
and writes two keys — `streak_days` (int) and `next_alarm` (String) — every
time the streak or next scheduled alarm changes. Once the extension below
exists, no further Dart changes should be needed.

## Steps

1. **Add an App Group capability to the main `Runner` target.**
   In Xcode, select the `Runner` target → Signing & Capabilities → "+
   Capability" → App Groups → add `group.com.alarmplus.app` (must match the
   id `WidgetSyncService._iosAppGroupId` uses exactly). This generates
   `ios/Runner/Runner.entitlements` — there isn't one in this repo yet.

2. **Create the widget extension target.**
   File → New → Target → Widget Extension. Name it something like
   `AlarmPlusWidget`. When prompted, do **not** include Live Activity unless
   you want one later — a plain widget is enough for streak + next alarm.

3. **Add the same App Group to the new extension target.**
   Same Signing & Capabilities step as #1, but on the `AlarmPlusWidget`
   target — both targets need the identical group id so they can read/write
   the same shared `UserDefaults` suite.

4. **Add the `home_widget` Swift package dependency to the extension target**
   (Xcode should offer this automatically since `home_widget` is already a
   Flutter plugin in the project; if not, link it manually the same way the
   plugin's own example does — see the package's `example/ios/HomeWidgetExampleExtension` target for reference).

5. **Write the widget view**, reading the same two keys `WidgetSyncService`
   writes. Following the same pattern the `home_widget` package's own
   example uses (`HomeWidgetExample.swift`):

   ```swift
   import SwiftUI
   import WidgetKit

   private let appGroupId = "group.com.alarmplus.app"

   struct AlarmWidgetEntry: TimelineEntry {
     let date: Date
     let streak: Int
     let nextAlarm: String
   }

   struct AlarmWidgetProvider: TimelineProvider {
     func placeholder(in context: Context) -> AlarmWidgetEntry {
       AlarmWidgetEntry(date: Date(), streak: 0, nextAlarm: "No alarm set")
     }

     func getSnapshot(in context: Context, completion: @escaping (AlarmWidgetEntry) -> Void) {
       completion(loadEntry())
     }

     func getTimeline(in context: Context, completion: @escaping (Timeline<AlarmWidgetEntry>) -> Void) {
       let timeline = Timeline(entries: [loadEntry()], policy: .atEnd)
       completion(timeline)
     }

     private func loadEntry() -> AlarmWidgetEntry {
       let data = UserDefaults(suiteName: appGroupId)
       return AlarmWidgetEntry(
         date: Date(),
         streak: data?.integer(forKey: "streak_days") ?? 0,
         nextAlarm: data?.string(forKey: "next_alarm") ?? "No alarm set"
       )
     }
   }

   struct AlarmWidgetView: View {
     var entry: AlarmWidgetEntry

     var flame: String {
       switch entry.streak {
       case 30...: return "🔥🔥🔥"
       case 7..<30: return "🔥🔥"
       case 3..<7: return "🔥"
       default: return "⭐"
       }
     }

     var body: some View {
       VStack(alignment: .leading, spacing: 4) {
         Text("\(flame) \(entry.streak)").font(.title2).bold()
         Text("day streak").font(.caption).foregroundColor(.secondary)
         Spacer(minLength: 8)
         Text(entry.nextAlarm).font(.subheadline).bold().foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37)) // #22C55E
       }
       .padding()
     }
   }

   @main
   struct AlarmWidget: Widget {
     let kind: String = "AlarmWidget"

     var body: some WidgetConfiguration {
       StaticConfiguration(kind: kind, provider: AlarmWidgetProvider()) { entry in
         AlarmWidgetView(entry: entry)
       }
       .configurationDisplayName("Alarm+ Streak")
       .description("Your current streak and next alarm.")
     }
   }
   ```

6. **Refreshing already works.** `WidgetSyncService.refresh()` already calls
   `HomeWidget.updateWidget(androidName: 'AlarmWidgetProvider', iOSName: 'AlarmWidget')`
   — the `iOSName` matches the `kind: String = "AlarmWidget"` used above, so
   as long as the extension's `kind` matches, no Dart changes are needed.
   `home_widget` handles the reload internally via `WidgetCenter.shared.reloadTimelines`.

7. **Build, run on a device/simulator, and add the widget** via the iOS
   widget gallery (long-press home screen → "+"). Confirm the streak and
   next-alarm text update after dismissing an alarm or scheduling one in the
   app.

## Reference

The `home_widget` package's own example app (in its pub cache / GitHub repo)
has a complete, working iOS widget extension — `HomeWidgetExample.swift`,
`Runner.entitlements`, and a matching extension `.entitlements` file — that
this doc's Swift snippet above is adapted from. If anything here is unclear,
that example is the most reliable reference.
