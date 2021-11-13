//
//  ContentView.swift
//  LiveThreadExample
//
//  Created by monsoir on 11/13/21.
//

import SwiftUI

struct ContentView: View {

    @ObservedObject
    private var viewModel = ContentViewModel()

    var body: some View {
        VStack {
            HStack {
                Text("Log")
                    .font(.title)
            }
            .frame(maxWidth: .infinity)
            .background(.bar)
            ScrollView {
                VStack {
                    Text(viewModel.logs)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxWidth: .infinity)
            }
            HStack {
                Button("Start living", action: { viewModel.startLiving() })
                    .padding()
                Button("Stop living", action: { viewModel.stopLiving() })
                    .padding()
            }
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 13 Pro")
    }
}

class ContentViewModel: NSObject, ObservableObject {

    @Published
    private(set) var logs: String = ""

    private var shouldStop = true
    private var status: Status = .stopped

    private var thread: Thread?

    private var taskTimer: Timer?

    func startLiving() {
        guard status != .running else { return }
        defer { status = .running }

        shouldStop = false
        if !logs.isEmpty {
            appendLog("----------------")
        }

        if let thread = self.thread, !thread.isCancelled {
            thread.cancel()
        }

        appendLog("starting thread...")

        // keep a living thread
        let aThread = newThread
        self.thread = aThread
        aThread.start()

        appendLog("thread started living")

        // dispatch some tasks on the living thread periodically
        dispatchTasksPeriodically()
    }

    func stopLiving() {
        guard status != .stopped else { return }
        defer { status = .stopped }

        shouldStop = true
    }

    private func dispatchTasksPeriodically() {
        let aTimer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            guard let self = self, let thread = self.thread else { return }
            self.perform(#selector(self.handleTask), on: thread, with: nil, waitUntilDone: false)
        }
        self.taskTimer = aTimer

        RunLoop.current.add(aTimer, forMode: .common)
    }

    @objc
    private func handleTask() {
        let currentThread = Thread.current
        appendLog("thread(\(currentThread.name ?? "---")) is running.")
    }

    private var newThread: Thread {
        let result = Thread { [weak self] in
            guard let self = self else { return }

            let runLoop = RunLoop.current
            runLoop.add(NSMachPort(), forMode: .default)
            while !self.shouldStop && runLoop.run(mode: .default, before: .distantFuture) {}

            DispatchQueue.main.sync { [weak self] in
                guard let self = self else { return }
                if let timer = self.taskTimer, timer.isValid {
                    timer.invalidate()
                    self.taskTimer = nil
                }
            }

            self.appendLog("thread living ended.")

            return
        }
        result.name = randomString(length: 5)

        return result
    }

    private func appendLog(_ content: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.logs += "\(content)\n"
        }
    }

    private enum Status {
        case running
        case stopped
    }
}

func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map{ _ in letters.randomElement()! })
}
