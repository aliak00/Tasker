import Foundation

/**
 Curry a function. This is very useful when using async/await on functions that take
 more than one parameter and end in a callback

 - parameter f: the function that takes two parameters
 - returns: A function object that takes the 1st parameter and returns a function object that takes the 2nd parameter
 */
public func curry<A, B, C>(_ f: @escaping (A, B) -> C) -> (A) -> ((B) -> C) {
    return { (a: A) in
        { (b: B) in
            f(a, b)
        }
    }
}

/**
 Curry a function. This is very useful when using async/await on functions that take
 more than one parameter and end in a callback

 - parameter f: the function that takes three parameters
 - returns: A function object that takes the 1st and 2nd parameters and returns a function object that takes the 3rd parameter
 */
public func curry<A, B, C, D>(_ f: @escaping (A, B, C) -> D) -> (A, B) -> ((C) -> D) {
    return { (a: A, b: B) in
        { (c: C) in
            f(a, b, c)
        }
    }
}
