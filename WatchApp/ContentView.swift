import SwiftUI
import PacingCore
private let gold = Color(red: 0.91, green: 0.80, blue: 0.55)
private func clock(_ value: Double?) -> String {
    guard let value, value.isFinite, value >= 0 else { return "—" }
    let s = Int(value.rounded())
    return s >= 3600 ? String(format:"%d:%02d:%02d",s/3600,(s/60)%60,s%60) : String(format:"%d:%02d",s/60,s%60)
}
struct ContentView: View {
    @EnvironmentObject var workout: WorkoutManager
    @Environment(\.isLuminanceReduced) var dimmed
    @State private var distance = 5.0
    @State private var minutes = 30.0
    @State private var miles = false
    @State private var race = true
    @State private var endConfirmation = false
    @AppStorage("appearance") private var appearance = "Signature"
    private var unit: Double { miles ? 1609.344 : 1000 }
    private var foreground: Color { appearance == "Daylight" && !dimmed ? .black : appearance == "Night" ? Color(red:0.9,green:0.87,blue:0.82) : .white }
    private var background: Color { appearance == "Daylight" && !dimmed ? Color(red:0.97,green:0.96,blue:0.93) : .black }
    private var accent: Color { appearance == "Daylight" && !dimmed ? Color(red:0.46,green:0.34,blue:0.05) : gold }
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("STRIDE").font(.caption).tracking(3).foregroundStyle(accent)
                if workout.running { live }
                else if workout.saving { ProgressView("Preparing / saving…") }
                else { setup; if let summary = workout.summary { summaryView(summary) } }
                if let error = workout.errorMessage { Text(error).font(.footnote).foregroundStyle(accent) }
                if let message = workout.saveMessage { Text(message).font(.footnote) }
            }.padding(.horizontal, 8)
        }.foregroundStyle(foreground).background(background)
         .confirmationDialog("End this run?",isPresented:$endConfirmation,titleVisibility:.visible) { Button("End and save",role:.destructive) { workout.end() } }
    }
    private var setup: some View {
        VStack(spacing:10) {
            Stepper(value:$distance,in:0.5...100,step:0.5) { Text(String(format:"%.1f %@",distance,miles ? "mi" : "km")) }
            Toggle("Miles",isOn:$miles)
            Stepper(value:$minutes,in:1...720,step:1) { Text("Goal \(Int(minutes)) min") }
            Toggle("Race clock",isOn:$race)
            Text(race ? "Stops count toward goal time." : "Pauses excluded from goal time.").font(.footnote)
            Picker("Appearance",selection:$appearance) { ForEach(["Signature","Night","Daylight"],id:\.self) { Text($0) } }
            Toggle("Vibration",isOn:Binding(get:{workout.haptics},set:{workout.haptics=$0}))
            Button("Start outdoor run") { workout.start(meters:distance*unit,seconds:minutes*60,race:race) }.tint(accent)
        }
    }
    private var instruction: String {
        if workout.paused { return "PAUSED" }
        switch workout.guidance {
        case .faster: return "SPEED UP GRADUALLY"
        case .ease: return "YOU CAN EASE"
        case .hold: return "HOLD THIS PACE"
        case .waiting: return "CHECKING PACE"
        case .expired: return "GOAL TIME PASSED"
        case .complete: return "DISTANCE COMPLETE"
        }
    }
    private var live: some View {
        VStack(spacing:8) {
            Text(instruction).font(.headline).multilineTextAlignment(.center)
            Text(clock(workout.required.map{$0*unit/1000})).font(.system(size:44,weight:.semibold,design:.rounded)).minimumScaleFactor(0.7).foregroundStyle(accent).monospacedDigit()
            Text("/\(miles ? "mi" : "km") needed").font(.caption)
            ProgressView(value:min(1,workout.distance/workout.goalMeters)).tint(accent)
            HStack { metric("LEFT",String(format:"%.2f %@",max(0,workout.goalMeters-workout.distance)/unit,miles ? "mi":"km")); Spacer(); metric("TIME LEFT",clock(max(0,workout.goalSeconds-workout.elapsed))) }
            if !dimmed {
                HStack { metric("EST. FINISH",clock(workout.projected)); Spacer(); metric("HEART RATE",workout.heartRate > 0 ? "\(Int(workout.heartRate))" : "—") }
                Text("Estimate assumes recent pace continues.").font(.system(size:10))
                Button(workout.paused ? "Resume" : "Pause") { workout.togglePause() }
                Button("End run",role:.destructive) { endConfirmation = true }
            }
        }
    }
    private func metric(_ label: String,_ value: String) -> some View { VStack(alignment:.leading) { Text(label).font(.system(size:9)); Text(value).font(.headline).monospacedDigit() } }
    private func summaryView(_ summary: RunSummary) -> some View {
        VStack(alignment:.leading,spacing:10) {
            Divider(); Text("LAST RUN").foregroundStyle(accent)
            Text(summary.date,style:.date).font(.caption)
            Text(String(format:"%.2f %@ · %@",summary.distance/unit,miles ? "mi":"km",clock(summary.elapsed))).font(.headline)
            Text(summary.distance >= summary.goalMeters ? "Distance completed" : "Ended before distance goal")
            Text("Goal: \(clock(summary.goalSeconds)) · \(summary.raceClock ? "race clock" : "training clock")").font(.caption)
            Text("TERRAIN SUMMARY").font(.caption).foregroundStyle(accent)
            let terrain = terrainTotals(summary.points)
            if terrain.count >= 2 {
                Text("Ascent ~\(Int(terrain.gain)) m · Descent ~\(Int(terrain.loss)) m")
                Text("Based on filtered altitude samples. Elevation is approximate.").font(.footnote)
            } else { Text("Not enough reliable elevation data.").font(.footnote) }
        }
    }
    private func terrainTotals(_ points:[RunPoint]) -> (gain:Double,loss:Double,count:Int) {
        var gain=0.0,loss=0.0,count=0
        var anchor:RunPoint?
        for p in points {
            guard let a=p.altitude else { anchor=nil;continue }
            guard let previous=anchor,let old=previous.altitude else {anchor=p;count+=1;continue}
            if p.distance-previous.distance >= 30 {
                let delta=a-old
                if abs(delta)>=2 {if delta>0 {gain+=delta}else{loss-=delta}}
                anchor=p;count+=1
            }
        }
        return (gain,loss,count)
    }
}
