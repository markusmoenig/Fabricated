//
//  PaletteView.swift
//  Fabricated
//
//  Created by Markus Moenig on 2/6/21.
//

import SwiftUI

/// The palette editor, if option is passed it also serves as a widget for the color picker
struct PaletteView: View {
    @State var core                        : Core
    @Binding var updateView                : Bool
    
    @State var option                      : TileNodeOption? = nil

    @State var editor                      : Bool = true
        
    @State var currentTileSet              : TileSet? = nil
    @State var currentColor                : TileSetColor? = nil
    
    @State var colorPickerValue            : Color = Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1)

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
                                        
                                        if let option = option {
                                            
                                            if let tile = core.project.currentTileSet?.openTile {
                                                                                            
                                                // Called from ParamColor, set the new index
                                                if let index = currentPalette.colors.firstIndex(of: color) {
                                                    core.startTileUndo(tile, "Color Changed")

                                                    option.node.writeOptionalFloatInstanceArea(core, option.node, option.name, value: Float(index))
                                                    core.colorChanged.send()
                                                 
                                                    core.currentTileUndo?.end()

                                                    core.renderer.render()
                                                    core.updateTilePreviews(tile)
                                                }
                                            }
                                        } else {
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

            if option === nil {
                ColorPicker("", selection: $colorPickerValue, supportsOpacity: true)
                    .onChange(of: colorPickerValue) { color in
                        if let currentColor = currentColor {
                            currentColor.fromColor(color)
                            core.colorChanged.send()
                            updateView.toggle()
                            if let tileSet = currentTileSet {
                                tileSet.invalidateColorIndex()
                            }
                            core.renderer.render()
                        }
                    }
            }

            Spacer()
        }
        
        .onAppear(perform: {
            currentTileSet = core.project.currentTileSet
            currentColor = getColor()
            if let color = currentColor?.toColor(), option == nil {
                colorPickerValue = color
            }
        })
        
        .onReceive(core.colorChanged) { _ in
            currentTileSet = core.project.currentTileSet
            currentColor = getColor()
        }
    }
    
    /// Get the current palette color
    func getColor() -> TileSetColor {
        if let tileSet = currentTileSet {
            if let option = option {
                let palette = tileSet.getPalette()
                let index = Int(option.node.readOptionalFloatInstanceArea(core, option.node, option.name, 0))
                        
                return palette.getColorAtIndex(index)
            } else {
                if let color = currentTileSet?.getColor() {
                    return color
                }
            }
        }
        
        return TileSetColor()
    }
}
