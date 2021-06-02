//
//  PaletteView.swift
//  Fabricated
//
//  Created by Markus Moenig on 2/6/21.
//

import SwiftUI

/// The palette editor
struct PaletteView: View {
    @State      var core                        : Core
    @Binding    var updateView                  : Bool
    
    @State      var editor                      : Bool = true
        
    @State      var currentTileSet              : TileSet? = nil
    @State      var currentColor                : TileSetColor? = nil
    
    @State      var colorPickerValue            : Color = Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1)

    var body: some View {
        VStack {
            
            let columns = [
                GridItem(.adaptive(minimum: 20))
            ]
            
            LazyVGrid(columns: columns, spacing: 0) {
                if let tileSet = currentTileSet {
                    if let currentPalette = tileSet.getPalette() {
                        ForEach(currentPalette.colors, id: \.id) { color in
                            ZStack {
                            
                                Rectangle()
                                    .fill(color.toColor())
                                    .frame(width: 15, height: 15)
                                    .onTapGesture(perform: {
                                        
                                        if editor {
                                            if let index = currentPalette.colors.firstIndex(of: color) {
                                                tileSet.currentColorIndex = index
                                                currentColor = currentTileSet?.getColor()
                                                if let color = currentColor {
                                                    colorPickerValue = color.toColor()
                                                }
                                            }
                                        }
                                    })
                                    .padding(5)
                                
                                
                                if color === currentColor {
                                    Rectangle()
                                        .stroke(Color.primary, lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                }
                            }
                        }
                    }
                }
            }
            .padding(4)

            if editor {
                ColorPicker("", selection: $colorPickerValue, supportsOpacity: true)
                    .onChange(of: colorPickerValue) { color in
                        if let currentColor = currentColor {
                            currentColor.fromColor(color)
                            updateView.toggle()
                        }
                    }
            }

            Spacer()
        }
        
        .onAppear(perform: {
            currentTileSet = core.project.currentTileSet
            currentColor = currentTileSet?.getColor()
        })
        
        /*
        .onReceive(self.document.core.tileSetChanged) { tileSet in
            currentTileSet = nil
            currentTileSet = tileSet
            if let tileSet = tileSet {
                currentTile = tileSet.currentTile
            }
            document.core.updateTilePreviews()
        }*/
    }
}
