import XCTest
@testable import AriaDomain
@testable import AriaApplication

final class FileSystemToolDefinitionsTests: XCTestCase {
    
    func testOpenFileDefinition() {
        let definition = FileSystemToolDefinitions.openFile
        
        XCTAssertEqual(definition.identifier, .openFile)
        XCTAssertEqual(definition.description, "Open an existing file with its associated macOS application")
        XCTAssertEqual(definition.riskLevel, .safe)
        XCTAssertEqual(definition.category, .file)
        XCTAssertFalse(definition.requiresConfirmation)
        
        XCTAssertEqual(definition.parameters.count, 1)
        let parameter = definition.parameters[0]
        XCTAssertEqual(parameter.name, "path")
        XCTAssertEqual(parameter.type, .string)
        XCTAssertTrue(parameter.isRequired)
    }
    
    func testOpenFolderDefinition() {
        let definition = FileSystemToolDefinitions.openFolder
        
        XCTAssertEqual(definition.identifier, .openFolder)
        XCTAssertEqual(definition.description, "Open an existing folder in Finder")
        XCTAssertEqual(definition.riskLevel, .safe)
        XCTAssertEqual(definition.category, .file)
        XCTAssertFalse(definition.requiresConfirmation)
        
        XCTAssertEqual(definition.parameters.count, 1)
        let parameter = definition.parameters[0]
        XCTAssertEqual(parameter.name, "path")
        XCTAssertEqual(parameter.type, .string)
        XCTAssertTrue(parameter.isRequired)
    }
    
    func testFindFileDefinition() {
        let definition = FileSystemToolDefinitions.findFile
        
        XCTAssertEqual(definition.identifier, .findFile)
        XCTAssertEqual(definition.description, "Find files matching a search query within the user's home directory")
        XCTAssertEqual(definition.riskLevel, .sensitive)
        XCTAssertEqual(definition.category, .file)
        XCTAssertFalse(definition.requiresConfirmation)
        
        XCTAssertEqual(definition.parameters.count, 2)
        
        let queryParameter = definition.parameters[0]
        XCTAssertEqual(queryParameter.name, "query")
        XCTAssertEqual(queryParameter.type, .string)
        XCTAssertTrue(queryParameter.isRequired)
        
        let scopeParameter = definition.parameters[1]
        XCTAssertEqual(scopeParameter.name, "searchScope")
        XCTAssertEqual(scopeParameter.type, .string)
        XCTAssertFalse(scopeParameter.isRequired)
    }
    
    func testAllFileSystemTools() {
        let allTools = FileSystemToolDefinitions.all
        
        XCTAssertEqual(allTools.count, 3)
        
        let identifiers = allTools.map { $0.identifier }
        XCTAssertTrue(identifiers.contains(.openFile))
        XCTAssertTrue(identifiers.contains(.openFolder))
        XCTAssertTrue(identifiers.contains(.findFile))
    }
    
    func testToolRiskLevels() {
        XCTAssertEqual(FileSystemToolDefinitions.openFile.riskLevel, .safe)
        XCTAssertEqual(FileSystemToolDefinitions.openFolder.riskLevel, .safe)
        XCTAssertEqual(FileSystemToolDefinitions.findFile.riskLevel, .sensitive)
    }
    
    func testToolCategories() {
        XCTAssertEqual(FileSystemToolDefinitions.openFile.category, .file)
        XCTAssertEqual(FileSystemToolDefinitions.openFolder.category, .file)
        XCTAssertEqual(FileSystemToolDefinitions.findFile.category, .file)
    }
}