# Manual Test Instructions for ParqView

## Test File Opening

1. **Build the app**:
```bash
swift build
```

2. **Run the app**:
```bash
.build/debug/ParqViewApp
```

3. **Test file opening methods**:

### Method 1: Open Dialog
- Press `Cmd+O` or click "Open File..." button
- Navigate to the project directory
- Select `test_data.parquet`
- **Expected**: File should load and display data table

### Method 2: Drag and Drop
- Drag `test_data.parquet` from Finder
- Drop it onto the ParqView window
- **Expected**: File should load and display data table

### Method 3: Open with App
- In Finder, right-click `test_data.parquet`
- Select "Open With" > ParqView (if available)
- **Expected**: App should launch and display the file

## What to Check

1. **Loading State**: 
   - Should show "Loading file..." progress indicator

2. **Success State**:
   - Should display table with data
   - Should show schema in sidebar
   - Should display "Showing 1-100 of 1000 rows"

3. **Debug Log**:
   - Check `~/parqview_debug.log` for entries:
     - "Loading file with ParquetFile.load..."
     - "File loaded successfully: 7 columns, 1000 rows"
     - "currentFile set on MainActor - UI should update now"

## Current Issue

The file loads successfully (confirmed in logs) but the UI remains on the welcome screen instead of showing the data table.

## Test Data File

The `test_data.parquet` file contains:
- 1000 rows
- 7 columns: id, name, age, salary, active, department, join_date