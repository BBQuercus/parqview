import Foundation

public enum ParquetError: Error, LocalizedError {
    case failedToReadSchema
    case failedToReadData
    case dataReadError
    case fileNotFound(String)
    case invalidFormat(String)
    case pythonNotFound
    case pythonScriptError(String)
    case invalidResponse
    case invalidSchema
    case invalidMetadata

    public var errorDescription: String? {
        switch self {
        case .failedToReadSchema:
            return "Failed to read Parquet file schema"
        case .failedToReadData:
            return "Failed to read Parquet file data"
        case .dataReadError:
            return "Failed to read data from Parquet file"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidFormat(let message):
            return message
        case .pythonNotFound:
            return "Python interpreter not found"
        case .pythonScriptError(let message):
            return "Script error: \(message)"
        case .invalidResponse:
            return "Invalid response from script"
        case .invalidSchema:
            return "Invalid schema data"
        case .invalidMetadata:
            return "Invalid metadata"
        }
    }
}