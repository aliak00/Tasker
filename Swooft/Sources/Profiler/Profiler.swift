//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

public class Profiler {
    private static let kNanosPerUSec: Double = 1000
    private static let kNanosPerMSec: Double = kNanosPerUSec * 1000

    private static let kAbsMultiplier: Double = {
        let info = mach_timebase_info_t.allocate(capacity: 1)
        info.initialize(to: mach_timebase_info(numer: 0, denom: 0))
        defer {
            info.deinitialize()
            info.deallocate(capacity: 1)
        }
        mach_timebase_info(info)
        return Double(info.pointee.numer) / Double(info.pointee.denom)
    }()

    private static func absoluteTimeToMS(_ abs: Double) -> Double {
        return Double(abs) * self.kAbsMultiplier / self.kNanosPerMSec
    }

    private typealias Duration = (start: UInt64, end: UInt64)

    private static func averageDurations(_ durations: [Duration]) -> Double {
        let sum: UInt64 = durations.reduce(0) { (memo, data) -> UInt64 in
            return memo + (data.end - data.start)
        }
        let averageTime = Double(sum) / Double(durations.count)
        return self.absoluteTimeToMS(averageTime)
    }

    private let queue = DispatchQueue(label: "Swooft.Profiler")
    private let configuration: ProfilerConfiguration
    private let label: String
    private var data: [String: Double] = [:]

    public init(label: String, configuration: ProfilerConfiguration = .multiple) {
        self.label = label
        self.configuration = configuration
    }

    @discardableResult
    public static func profile(label: String, configuration: ProfilerConfiguration = .single, block: @escaping () -> Void) -> ProfilerResults {
        let profiler = Profiler(label: label, configuration: configuration)
        profiler.profile(tag: label, block: block)
        return profiler.results
    }

    private func process(block: @escaping () -> Void) -> [Duration] {
        var durations: [Duration] = []
        DispatchQueue.concurrentPerform(iterations: self.configuration.threadCount) { _ in
            var durationsPerThread = [Duration](
                repeating: (0, 0),
                count: self.configuration.sampleCount
            )
            for i in 0..<self.configuration.sampleCount {
                durationsPerThread[i].start = mach_absolute_time()
                block()
                durationsPerThread[i].end = mach_absolute_time()
            }
            self.queue.sync {
                durations.append(contentsOf: durationsPerThread)
            }
        }
        return durations
    }

    @discardableResult
    public func profile(tag: String, block: @escaping () -> Void) -> Double {
        let durations = self.process(block: block)
        let averageDuration = Profiler.averageDurations(durations)
        self.queue.sync {
            self.data[tag] = averageDuration
        }
        return averageDuration
    }

    public var results: ProfilerResults {
        let results = self.queue.sync {
            return self.data
        }
        return ProfilerResults(
            label: self.label,
            configuration: self.configuration,
            results: results
        )
    }
}
