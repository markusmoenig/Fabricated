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
                        
                        let tile = Tile("Tile")
                        let tiledNode = TiledNode()
                        
                        currentTileSet.tiles.append(tile)
                        tile.nodes.append(tiledNode)
                        
                        currentTileSet.currentTile = tile
                        currentTileSet.openTile = tile
                        document.core.tileSetChanged.send(currentTileSet)
                    }
                })
                {
                    Label("New Tile", systemImage: "plus")
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.leading, 10)
                .disabled(currentTile === nil)
                
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
                GridItem(.adaptive(minimum: 90))
            ]
            
            LazyVGrid(columns: columns, spacing: 0) {
                if let currentTileSet = currentTileSet {
                    ForEach(currentTileSet.tiles, id: \.id) { tile in
                        ZStack {
                        //Text(tile.name)
                            
                            if let tiled = tile.nodes[0] as? TiledNode {
                                if let image = tiled.cgiImage {
                                    Image(image, scale: 1.0, label: Text(tile.name))
                                        .onTapGesture(perform: {
                                            currentTile = tile
                                            currentTileSet.currentTile = tile
                                        })
                                        .frame(width: 80, height: 80)
                                        .padding(10)
                                } else {
                                    Rectangle()
                                        .fill(Color.secondary)
                                        .frame(width: 80, height: 80)
                                        .onTapGesture(perform: {
                                            currentTile = tile
                                            currentTileSet.currentTile = tile
                                        })
                                        .padding(10)
                                }
                            }
                        
                            
                            if tile === currentTile {
                                Rectangle()
                                    .stroke(Color.primary, lineWidth: 2)
                                    .frame(width: 90, height: 90)
                            }
                        }
                    }
                }
            }
            .padding(4)
            
            Spacer()
        }
        
        .onAppear(perform: {
            currentTileSet = document.core.project.currentTileSet
            if let currentTileSet = currentTileSet {
                currentTile = currentTileSet.currentTile
                document.core.updateTilePreviews()
            }
        })
        
        .onReceive(self.document.core.tileSetChanged) { tileSet in
            currentTileSet = nil
            currentTileSet = tileSet
            if let tileSet = tileSet {
                currentTile = tileSet.currentTile
            }
            document.core.updateTilePreviews()
        }
    }
}
