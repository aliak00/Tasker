import Foundation

/**
 Errors that happen internally in the URLIntercetor
 */
public enum URLInterceptorError: Error {
    /**
     This indicates that the URLInterceptor that was supposed to be incharge
     of executing a URLSessionTask has managed to dissapear.
     */
    case keyNotFound
}
