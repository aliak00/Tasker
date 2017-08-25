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

public enum Result<T> {
    case success(T)
    case failure(Error)

    var successValue: T? {
        if case let .success(value) = self {
            return value
        }
        return nil
    }

    var failureValue: Error? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }
}
