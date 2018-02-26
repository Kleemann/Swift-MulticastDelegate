//: Playground - noun: a place where people can play

import UIKit

class MulticastDelegate<T> {
    private var delegates = [WeakObjectWrapper]()
    private let lock = NSRecursiveLock()
    
    func add(_ delegate:T) {
        guard Mirror(reflecting: delegate).subjectType is AnyClass else {
            fatalError("Delegates must be a reference type")
        }
        threadSafe(delegates.append(WeakObjectWrapper(value: delegate as AnyObject)))
    }
    
    func remove(_ delegate:T) {
        guard Mirror(reflecting: delegate).subjectType is AnyClass else {
            //The delegate is not a reference type - it is not added in the first place
            return
        }
        threadSafe(delegates.remove(WeakObjectWrapper(value: delegate as AnyObject)))
    }
    
    func invoke(invocation: (T) -> ()) {
        //Enumerating in reverse order to prevent a race condition when removing objects.
        for (index, item) in delegates.enumerated().reversed() {
            //Since these are weak references, the value/reference may be nil
            //Also we ensure the object is T
            guard let delegateClass = item.value, let delegate = delegateClass as? T else {
                //The object is deinitilized by ARC - remove it
                threadSafe(delegates.remove(at: index))
                continue
            }
            
            threadSafe(invocation(delegate))
        }
    }
    
    fileprivate func threadSafe<T>(_ closure: @autoclosure ()->T) -> T {
        lock.lock()
        defer { lock.unlock() }
        
        return closure()
    }
}
extension MulticastDelegate {
    private class WeakObjectWrapper: Equatable {
        weak var value: AnyObject?
        
        init(value: AnyObject) {
            self.value = value
        }
        
        // MARK: Equatable
        static func ==(lhs: WeakObjectWrapper, rhs: WeakObjectWrapper) -> Bool {
            return lhs.value === rhs.value
        }
    }
}

extension RangeReplaceableCollection where Iterator.Element : Equatable {
    @discardableResult mutating func remove(_ element : Iterator.Element) -> Iterator.Element? {
        if let index = self.index(of: element) {
            return self.remove(at: index)
        }
        return nil
    }
}

protocol SomeDelegate: class {
    func onSomeEvent()
}

class SomeDelegateImplementation: SomeDelegate {
    let value: Int
    
    init(value: Int) {
        self.value = value
    }
    
    deinit {
        print("Delegate \(value) is deallocated")
    }
    
    func onSomeEvent() {
        print("Invoking delegate \(value)")
    }
}

let multicastDelegate = MulticastDelegate<SomeDelegate>()
func testInvoke() {
    multicastDelegate.invoke { (delegate) in
        delegate.onSomeEvent()
    }
}

print("Adding first delegate")
let delegateOne = SomeDelegateImplementation(value: 1)
multicastDelegate.add(delegateOne)
testInvoke()
print("")

print("Adding Second delegate")
let delegateTwo = SomeDelegateImplementation(value: 2)
multicastDelegate.add(delegateTwo)
testInvoke()
print("")

print("Removing first delegate.")
multicastDelegate.remove(delegateOne)
testInvoke()
print("")

print("Added third delegate - which is deallocated immediately after")
({
    let delegateThree = SomeDelegateImplementation(value: 3)
    multicastDelegate.add(delegateThree)
    testInvoke()
})()
print("")

testInvoke()
