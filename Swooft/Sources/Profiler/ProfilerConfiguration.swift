/*
 Copyright 2017 Ali Akhtarzada

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

public struct ProfilerConfiguration {

    /// Number of threads you want the profiler to use
    public let threadCount: Int

    /// Number of samples to take per thread
    public let sampleCount: Int

    /// This is the default configuration for a single measurement with a single Profiler
    public static let single = ProfilerConfiguration(
        threadCount: 1,
        sampleCount: 1000
    )

    /// This is the default configuration for performing multiple measurements with the same Profiler
    public static let multiple = ProfilerConfiguration(
        threadCount: 4,
        sampleCount: 1000
    )
}
