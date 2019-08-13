import Foundation

/**
 Errors that happen internally in the URLTaskManager
 */
public enum URLTaskManagerError: Error {
    /**
     This indicates that the URLTaskManager that was supposed to be incharge
     of executing a URLSessionTask has managed to dissapear.
     */
    case keyNotFound
}
