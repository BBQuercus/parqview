import Foundation

public enum ParquetError: Error, LocalizedError {
    case failedToReadSchema
    case failedToReadData
    case dataReadError
    case fileNotFound
    case invalidFormat
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
        case .fileNotFound:
            return "Parquet file not found"
        case .invalidFormat:
            return "Invalid Parquet file format"
        case .pythonNotFound:
            return "Python interpreter not found. Please ensure Python 3 is installed."
        case .pythonScriptError(let message):
            return "Python script error: \(message)"
        case .invalidResponse:
            return "Invalid response from Python script"
        case .invalidSchema:
            return "Invalid schema data returned"
        case .invalidMetadata:
            return "Invalid metadata returned"
        }
    }
}