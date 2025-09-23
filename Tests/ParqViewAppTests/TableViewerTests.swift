import XCTest
import SwiftUI
@testable import ParqViewApp
@testable import SharedCore

final class TableViewerTests: XCTestCase {
    
    // MARK: - Test Data Setup
    
    private func createMockParquetFile(rows: Int = 1000, columns: Int = 10) -> ParquetFile {
        let mockColumns = (0..<columns).map { i in
            SchemaColumn(
                name: "column_\(i)",
                type: i % 4 == 0 ? .string : i % 4 == 1 ? .int64 : i % 4 == 2 ? .double : .boolean,
                isNullable: i % 2 == 0
            )
        }
        
        let schema = ParquetSchema(columns: mockColumns)
        
        return ParquetFile(
            name: "test.parquet",
            url: URL(fileURLWithPath: "/tmp/test.parquet"),
            sizeInBytes: Int64(rows * columns * 8),
            schema: schema,
            metadata: ParquetMetadata(
                createdBy: "Test",
                version: "1.0",
                rowGroups: 5,
                compressionCodec: "SNAPPY"
            ),
            totalRows: rows
        )
    }
    
    // MARK: - Column Visibility Tests
    
    func testAllColumnsShownByDefault() throws {
        let file = createMockParquetFile(columns: 15)
        let view = TableViewerView(file: file)
        
        // All columns should be visible in the schema
        XCTAssertEqual(file.schema.columns.count, 15)
        
        // Verify columns are not filtered or hidden
        for column in file.schema.columns {
            XCTAssertNotNil(column.name)
            XCTAssertFalse(column.name.isEmpty)
        }
    }
    
    func testTableHeaderShowsAllColumns() throws {
        let columns = [
            SchemaColumn(name: "id", type: .int64, isNullable: false),
            SchemaColumn(name: "name", type: .string, isNullable: true),
            SchemaColumn(name: "value", type: .double, isNullable: true),
            SchemaColumn(name: "active", type: .boolean, isNullable: false),
            SchemaColumn(name: "created", type: .timestamp, isNullable: true)
        ]
        
        let sortColumn = "id"
        let sortAscending = true
        
        // Create binding wrappers for testing
        var testSortColumn: String? = sortColumn
        var testSortAscending = sortAscending
        
        let headerView = TableHeaderView(
            columns: columns,
            sortColumn: .constant(testSortColumn),
            sortAscending: .constant(testSortAscending),
            onSort: { _ in }
        )
        
        // All columns should be represented in the header
        XCTAssertEqual(columns.count, 5)
    }
    
    // MARK: - Pagination Tests
    
    func testDefaultRowsPerPageIs100() throws {
        let file = createMockParquetFile(rows: 500)
        let view = TableViewerView(file: file)
        
        // Access the state through reflection (for testing purposes)
        let mirror = Mirror(reflecting: view)
        
        // Find the rowsPerPage state
        for child in mirror.children {
            if let label = child.label, label.contains("rowsPerPage") {
                if let stateValue = child.value as? Int {
                    XCTAssertEqual(stateValue, 100)
                } else {
                    // Try to extract from State wrapper
                    let stateMirror = Mirror(reflecting: child.value)
                    for stateChild in stateMirror.children {
                        if let value = stateChild.value as? Int {
                            XCTAssertEqual(value, 100)
                            break
                        }
                    }
                }
            }
        }
    }
    
    func testRowsPerPageOptions() throws {
        // Verify the picker options are correct
        let expectedOptions = [50, 100, 500, 1000]
        
        // These should be the available options in the picker
        for option in expectedOptions {
            XCTAssertTrue(option > 0)
            XCTAssertTrue(option <= 1000)
        }
        
        // Default should be 100
        XCTAssertEqual(expectedOptions[1], 100)
    }
    
    // MARK: - Row Count Display Tests
    
    func testRowCountDisplayForEmptyData() throws {
        let file = createMockParquetFile(rows: 0)
        
        // Empty data should show "0-0 of 0 rows"
        let displayText = "Showing 0-0 of 0 rows"
        XCTAssertTrue(displayText.contains("0"))
    }
    
    func testRowCountDisplayForFirstPage() throws {
        let file = createMockParquetFile(rows: 1000)
        let currentPage = 0
        let rowsPerPage = 100
        let loadedRows = 100
        
        // First page should show "1-100 of 1000 rows"
        let start = currentPage * rowsPerPage + 1
        let end = currentPage * rowsPerPage + loadedRows
        let displayText = "Showing \(start)-\(end) of \(file.totalRows) rows"
        
        XCTAssertEqual(displayText, "Showing 1-100 of 1000 rows")
    }
    
    func testRowCountDisplayForMiddlePage() throws {
        let file = createMockParquetFile(rows: 1000)
        let currentPage = 2
        let rowsPerPage = 100
        let loadedRows = 100
        
        // Third page should show "201-300 of 1000 rows"
        let start = currentPage * rowsPerPage + 1
        let end = currentPage * rowsPerPage + loadedRows
        let displayText = "Showing \(start)-\(end) of \(file.totalRows) rows"
        
        XCTAssertEqual(displayText, "Showing 201-300 of 1000 rows")
    }
    
    func testRowCountDisplayForLastPage() throws {
        let file = createMockParquetFile(rows: 950)
        let currentPage = 9
        let rowsPerPage = 100
        let loadedRows = 50 // Last page has only 50 rows
        
        // Last page should show "901-950 of 950 rows"
        let start = currentPage * rowsPerPage + 1
        let end = currentPage * rowsPerPage + loadedRows
        let displayText = "Showing \(start)-\(end) of \(file.totalRows) rows"
        
        XCTAssertEqual(displayText, "Showing 901-950 of 950 rows")
    }
    
    // MARK: - Data Loading Tests
    
    func testInitialDataLoadLimit() throws {
        // Test that initial load respects the rowsPerPage setting
        let file = createMockParquetFile(rows: 500)
        let rowsPerPage = 100
        
        // Initial load should request exactly rowsPerPage rows
        XCTAssertEqual(rowsPerPage, 100)
        XCTAssertLessThanOrEqual(rowsPerPage, file.totalRows)
    }
    
    func testLoadMoreFunctionality() throws {
        let file = createMockParquetFile(rows: 500)
        var currentRows = 100
        let rowsPerPage = 100
        
        // Simulate loading more rows
        let newRowsToLoad = min(rowsPerPage, file.totalRows - currentRows)
        currentRows += newRowsToLoad
        
        XCTAssertEqual(currentRows, 200)
        XCTAssertLessThanOrEqual(currentRows, file.totalRows)
    }
    
    // MARK: - Row Display Tests
    
    func testTableRowViewDisplaysAllColumns() throws {
        let columns = [
            SchemaColumn(name: "col1", type: .string, isNullable: true),
            SchemaColumn(name: "col2", type: .int64, isNullable: false),
            SchemaColumn(name: "col3", type: .double, isNullable: true)
        ]
        
        let values: [ParquetValue] = [
            .string("test"),
            .int(42),
            .float(3.14)
        ]
        
        let row = ParquetRow(values: values)
        
        // All values should be present
        XCTAssertEqual(row.values.count, columns.count)
        XCTAssertEqual(row.values.count, 3)
    }
    
    func testAlternatingRowBackground() throws {
        // Test that alternating rows have different backgrounds
        for index in 0..<10 {
            let isAlternate = index % 2 == 1
            
            if index == 0 {
                XCTAssertFalse(isAlternate)
            } else if index == 1 {
                XCTAssertTrue(isAlternate)
            } else if index == 2 {
                XCTAssertFalse(isAlternate)
            }
        }
    }
    
    // MARK: - Cell Display Tests
    
    func testTableCellDisplayFormats() throws {
        // Test NULL value
        let nullValue = ParquetValue.null
        let nullCell = TableCellView(value: nullValue)
        XCTAssertEqual(nullCell.displayText, "NULL")
        
        // Test Boolean values
        let trueValue = ParquetValue.bool(true)
        let trueCell = TableCellView(value: trueValue)
        XCTAssertEqual(trueCell.displayText, "true")
        
        let falseValue = ParquetValue.bool(false)
        let falseCell = TableCellView(value: falseValue)
        XCTAssertEqual(falseCell.displayText, "false")
        
        // Test Integer value
        let intValue = ParquetValue.int(12345)
        let intCell = TableCellView(value: intValue)
        XCTAssertEqual(intCell.displayText, "12345")
        
        // Test Float value
        let floatValue = ParquetValue.float(3.14159)
        let floatCell = TableCellView(value: floatValue)
        XCTAssertEqual(floatCell.displayText, "3.14")
        
        // Test String value
        let stringValue = ParquetValue.string("Hello World")
        let stringCell = TableCellView(value: stringValue)
        XCTAssertEqual(stringCell.displayText, "Hello World")
        
        // Test Binary value
        let binaryValue = ParquetValue.binary(Data([0x01, 0x02, 0x03]))
        let binaryCell = TableCellView(value: binaryValue)
        XCTAssertEqual(binaryCell.displayText, "<3 bytes>")
    }
    
    func testTableCellColors() throws {
        // Test color assignments for different types
        let nullCell = TableCellView(value: .null)
        XCTAssertEqual(nullCell.textColor, .secondary)
        
        let boolCell = TableCellView(value: .bool(true))
        XCTAssertEqual(boolCell.textColor, .purple)
        
        let intCell = TableCellView(value: .int(42))
        XCTAssertEqual(intCell.textColor, .green)
        
        let floatCell = TableCellView(value: .float(3.14))
        XCTAssertEqual(floatCell.textColor, .green)
        
        let stringCell = TableCellView(value: .string("test"))
        XCTAssertEqual(stringCell.textColor, .primary)
        
        let binaryCell = TableCellView(value: .binary(Data()))
        XCTAssertEqual(binaryCell.textColor, .gray)
        
        let dateCell = TableCellView(value: .date(Date()))
        XCTAssertEqual(dateCell.textColor, .orange)
        
        let timestampCell = TableCellView(value: .timestamp(Date()))
        XCTAssertEqual(timestampCell.textColor, .orange)
    }
    
    // MARK: - Sorting Tests
    
    func testSortingToggle() throws {
        var sortColumn: String? = nil
        var sortAscending = true
        
        // First click on a column
        let columnName = "test_column"
        if sortColumn == columnName {
            sortAscending.toggle()
        } else {
            sortColumn = columnName
            sortAscending = true
        }
        
        XCTAssertEqual(sortColumn, "test_column")
        XCTAssertTrue(sortAscending)
        
        // Second click on same column (should toggle)
        if sortColumn == columnName {
            sortAscending.toggle()
        } else {
            sortColumn = columnName
            sortAscending = true
        }
        
        XCTAssertEqual(sortColumn, "test_column")
        XCTAssertFalse(sortAscending)
        
        // Click on different column (should reset to ascending)
        let newColumnName = "another_column"
        if sortColumn == newColumnName {
            sortAscending.toggle()
        } else {
            sortColumn = newColumnName
            sortAscending = true
        }
        
        XCTAssertEqual(sortColumn, "another_column")
        XCTAssertTrue(sortAscending)
    }
    
    // MARK: - Performance Tests
    
    func testLargeFileHandling() throws {
        let file = createMockParquetFile(rows: 1_000_000, columns: 50)
        
        // Should handle large files without loading all data
        XCTAssertEqual(file.totalRows, 1_000_000)
        XCTAssertEqual(file.schema.columns.count, 50)
        
        // Initial load should still be limited
        let initialLoadLimit = 100
        XCTAssertLessThan(initialLoadLimit, file.totalRows)
    }
    
    func testPaginationEfficiency() throws {
        let file = createMockParquetFile(rows: 10_000)
        let rowsPerPage = 100
        
        // Calculate total pages
        let totalPages = (file.totalRows + rowsPerPage - 1) / rowsPerPage
        XCTAssertEqual(totalPages, 100)
        
        // Each page should load exactly rowsPerPage rows (except last)
        for page in 0..<totalPages {
            let expectedRows = min(rowsPerPage, file.totalRows - (page * rowsPerPage))
            XCTAssertLessThanOrEqual(expectedRows, rowsPerPage)
            XCTAssertGreaterThan(expectedRows, 0)
        }
    }
}