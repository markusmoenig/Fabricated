//
//  FabricatedApp.swift
//  Shared
//
//  Created by Markus Moenig on 7/4/21.
//

import SwiftUI

@main
struct FabricatedApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: FabricatedDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
