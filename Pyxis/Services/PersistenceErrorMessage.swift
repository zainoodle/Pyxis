import Foundation

public enum PersistenceErrorMessage {
    public static func saveFailed(_ error: Error) -> String {
        "Changes could not be saved. Please try again."
    }
}
