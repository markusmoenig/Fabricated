//
//  TileGridView.swift
//  Fabricated
//
//  Created by Markus Moenig on 13/4/21.
//

import SwiftUI

struct TileGridView: View {
    @State      var document                    : FabricatedDocument
    @Binding    var updateView                  : Bool
    
    @State     var currentTileSet               : TileSet? = nil
    @State     var currentTile                  : Tile? = nil

    var body: some View {
        VStack {
            
            HStack {
                Button(action: {
                    if let currentTileSet = document.core.project.currentTileSet {
                        currentTileSet.currentTile = currentTile
                        currentTileSet.openTile = currentTile
                        document.core.tileSetChanged.send(currentTileSet)
                    }
                })
                {
                    Label("Edit Tile", systemImage: "rectangle.3.offgrid")
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.leading, 10)
                .disabled(currentTile === nil)
                
                Spacer()
            }
            
            let columns = [
                GridItem(.adaptive(minimum: 60))
            ]
            
            LazyVGrid(columns: columns, spacing: 10) {
                if let currentTileSet = currentTileSet {
                    ForEach(currentTileSet.tiles, id: \.id) { tile in
                        ZStack {
                        //Text(tile.name)
                        
                            Rectangle()
                                .fill(Color(.blue))
                                .frame(width: 50, height: 50)
                                .onTapGesture(perform: {
                                    currentTile = tile
                                    currentTileSet.currentTile = tile
                                })
                                .padding(10)
                        
                            
                            if tile === currentTile {
                                Rectangle()
                                    .stroke(Color(.white), lineWidth: 5)
                                    .frame(width: 60, height: 60)
                            }
                        }
                    }
                }
            }
            .padding(10)
            
            Spacer()
        }
        
        .onAppear(perform: {
            currentTileSet = document.core.project.currentTileSet
            if let currentTileSet = currentTileSet {
                currentTile = currentTileSet.currentTile
            }
        })
        
        .onReceive(self.document.core.tileSetChanged) { tileSet in
            currentTileSet = nil
            currentTileSet = tileSet
            if let tileSet = tileSet {
                currentTile = tileSet.currentTile
            }
        }
    }
}
