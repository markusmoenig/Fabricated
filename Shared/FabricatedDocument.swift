//
//  FabricatedDocument.swift
//  Shared
//
//  Created by Markus Moenig on 7/4/21.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var fabricatedProject: UTType {
        UTType(exportedAs: "com.Fabricated.project")
    }
}

struct FabricatedDocument: FileDocument {
    
    var core    = Core()
    var updated = false

    init() {
    }

    static var readableContentTypes: [UTType] { [.fabricatedProject] }
    static var writableContentTypes: [UTType] { [.fabricatedProject, .png] }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
                let project = try? JSONDecoder().decode(Project.self, from: data)
        else {
            /*
            do {
                let data = configuration.file.regularFileContents
                let response = try JSONDecoder().decode(Project.self, from: data!)
            } catch {
                print(error) //here.....
            }*/
            
            throw CocoaError(.fileReadCorruptFile)
        }
        if data.isEmpty == false {
            
            core.setProject(project: project)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var data = Data()
        
        let encodedData = try? JSONEncoder().encode(core.project)
        if let json = String(data: encodedData!, encoding: .utf8) {
            data = json.data(using: .utf8)!
        }
        
        return .init(regularFileWithContents: data)
    }
}
