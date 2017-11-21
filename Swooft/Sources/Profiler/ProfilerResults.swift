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

public struct ProfilerResults: CustomStringConvertible {
    let label: String
    let configuration: ProfilerConfiguration
    let results: [String: Double]

    public subscript(label: String) -> Double? {
        return self.results[label]
    }

    public func descending() -> [(label: String, duration: Double)] {
        return self.results.sorted {
            $0.1 > $1.1
        }.map { (label: $0.0, duration: $0.1) }
    }

    public func ascending() -> [(label: String, duration: Double)] {
        return self.results.sorted {
            $0.1 < $1.1
        }.map { (label: $0.0, duration: $0.1) }
    }

    public var description: String {

        let header = "[profiler:\(self.label)] threads: \(self.configuration.threadCount), samples: \(self.configuration.sampleCount)"

        if self.results.count == 1, let duration = self.results[self.label] {
            return header + ", time: \(duration) ms"
        }

        let sortedResults = self.descending()

        guard sortedResults.count > 0 else {
            return "You haven't profiled anything numbnuts"
        }

        var lines: [String] = []
        var previousDuration: Double?
        for result in sortedResults {
            var percentString: String?
            if let p = previousDuration {
                let percent = p == result.duration ? 0 : Int((p - result.duration) / p * 100)
                percentString = " (\(percent) % faster)"
            }
            lines.append("  " + result.label + ": \(result.duration) ms" + (percentString ?? ""))
            previousDuration = result.duration
        }
        return header + "\n" + lines.reversed().joined(separator: "\n")
    }
}
