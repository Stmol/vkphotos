//
// Created by Yury Smidovich on 25/07/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Foundation

class AsyncOperation: Operation {
    enum State: String {
        case isReady, isExecuting, isFinished
    }

    override var isAsynchronous: Bool {
        return true
    }

    override var isExecuting: Bool {
        return state == .isExecuting
    }

    override var isFinished: Bool {
        return state == .isFinished
    }

    var state = State.isReady {
        willSet {
            willChangeValue(forKey: state.rawValue)
            willChangeValue(forKey: newValue.rawValue)
        }
        didSet {
            didChangeValue(forKey: oldValue.rawValue)
            didChangeValue(forKey: state.rawValue)
        }
    }

    override func start() {
        guard !self.isCancelled else {
            state = .isFinished
            return
        }

        state = .isExecuting
        main()
    }
}
