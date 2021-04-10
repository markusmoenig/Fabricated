//
//  Views.swift
//  Fabricated
//
//  Created by Markus Moenig on 8/4/21.
//

import SwiftUI

/// ParameterListView
struct ProjectView: View {
    @State var document                     : FabricatedDocument
    @Binding var updateView                 : Bool

    var body: some View {
        VStack {
            List() {
                Button(action: {
                })
                {
                    Label("Settings", systemImage: "camera")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .listRowBackground(Group {
                    //if selection == cameraNode.id {
//                        Color.gray.mask(RoundedRectangle(cornerRadius: 4))
//                    } else { Color.clear }
                    
                    Color.clear
                })
            }
        }
    }
}
