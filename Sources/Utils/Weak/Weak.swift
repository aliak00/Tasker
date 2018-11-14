/**
 A generic wrapper that can be used on a reference type and store it inside
 as a weak reference

 ## Motivation

 A weak wrapper comes in useful in a number of situations:
    * When you want a protocol to ensure the existence of a weak reference. While you can declare a var
      weak in the protocol, there's no way to enforce it in an implementing class.
    * If you want the values in a container to contain weak references so that they can be deallocated
      regardless of being inserted in to a container
 */
public struct Weak<T: AnyObject> {
    /**
     The value of the object this was initialized with
     */
    public weak var value: T?

    /**
     - parameter value: the value to store weakly
     */
    public init(_ value: T?) {
        self.value = value
    }
}
