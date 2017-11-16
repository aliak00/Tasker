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

private extension Int32 {
    var pthreadError: String {
        switch self {
        case 0:
            return "success"
        case EINVAL:
            return "the mutex has not been properly initialized"
        case EDEADLK:
            return "the mutex is already locked by the calling thread"
        case EOWNERDEAD:
            return "the robust mutex is now locked by the calling thread after the previous owner terminated without unlocking it"
        case ENOTRECOVERABLE:
            return "the robust mutex is not locked and is no longer usable after the previous owner unlocked it without calling pthread_mutex_consistent"
        case EBUSY:
            return "the mutex could not be acquired because it was currently locked"
        case ETIMEDOUT:
            return "the mutex could not be acquired before the abs_timeout time arrived"
        case EPERM:
            return "the calling thread does not own the mutex"
        default:
            return "unknown error"
        }
    }
}

public final class PosixLock: NSLocking {

    public enum Kind {
        case `default`
        case normal
        case recursive
        case errorChecking
    }

    private var mutex = pthread_mutex_t()

    public init(kind: Kind) {
        var attr = pthread_mutexattr_t()
        let type: Int32
        switch kind {
        case .default:
            type = Int32(PTHREAD_MUTEX_DEFAULT)
        case .normal:
            type = Int32(PTHREAD_MUTEX_NORMAL)
        case .recursive:
            type = Int32(PTHREAD_MUTEX_RECURSIVE)
        case .errorChecking:
            type = Int32(PTHREAD_MUTEX_ERRORCHECK)
        }
        pthread_mutexattr_init(&attr)
        var result = pthread_mutexattr_settype(&attr, type)
        if result != 0 {
            preconditionFailure("failed to set \(kind) mutex attribtue - \(result.pthreadError)")
        }
        result = pthread_mutex_init(&self.mutex, &attr)
        if result != 0 {
            preconditionFailure("failed to init mutex - \(result.pthreadError)")
        }
        pthread_mutexattr_destroy(&attr)
    }

    deinit {
        let result = pthread_mutex_destroy(&self.mutex)
        if result != 0 {
            preconditionFailure("failed to destroy mutex - \(result.pthreadError)")
        }
    }

    public func lock() {
        let result = pthread_mutex_lock(&self.mutex)
        if result != 0 {
            preconditionFailure("failed to lock mutex - \(result.pthreadError)")
        }
    }

    public func unlock() {
        let result = pthread_mutex_unlock(&self.mutex)
        if result != 0 {
            preconditionFailure("failed to unlock mutex - \(result.pthreadError)")
        }
    }

    public func tryLock() -> Bool {
        let result = pthread_mutex_trylock(&mutex)
        if result != 0 && result != EBUSY {
            preconditionFailure("failed to trylock mutex - \(result.pthreadError)")
        }
        return result != EBUSY
    }
}
