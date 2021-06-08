//
//  TileGridView.swift
//  Fabricated
//
//  Created by Markus Moenig on 13/4/21.
//

import SwiftUI

struct TileDropViewDelegate: DropDelegate {
    
    var grid: Tile
    var gridData: TileSet
    
    func performDrop(info: DropInfo) -> Bool {
        ///To never disappear drag item when dropped outside
        //gridData.currentGrid = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {

        let fromIndex = gridData.tiles.firstIndex { (grid) -> Bool in
            return grid.id == gridData.currentTile?.id
        } ?? 0
        
        let toIndex = gridData.tiles.firstIndex { (grid) -> Bool in
            return grid.id == self.grid.id
        } ?? 0
        
        if fromIndex != toIndex{
            withAnimation(.default){
                let fromGrid = gridData.tiles[fromIndex]
                gridData.tiles[fromIndex] = gridData.tiles[toIndex]
                gridData.tiles[toIndex] = fromGrid
            }
        }
    }
    
    // setting Action as Move...
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

struct TileGridView: View {
    @State      var document                    : FabricatedDocument
    @Binding    var updateView                  : Bool
    
    @State     var currentTileSet               : TileSet? = nil
    @State     var currentTile                  : Tile? = nil
    
    @State     var showRenameTilePopover        : Bool = false
    @State     var tileName                     : String = ""
    @State     var contextTile                  : Tile? = nil

    var body: some View {
        ScrollView {
            
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
                        document.core.updateTileAndNodesPreviews()
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
                        ZStack(alignment: .bottom) {
                        
                            if let image = tile.cgiImage {
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
                                    .frame(width: 87, height: 87)
                                    .onTapGesture(perform: {
                                        currentTile = tile
                                        currentTileSet.currentTile = tile
                                    })
                                    .padding(3)
                            }
                            
                            if tile === currentTile {
                                Rectangle()
                                    .stroke(Color.primary, lineWidth: 2)
                                    .frame(width: 90, height: 90)
                            }
                            
                            Rectangle()
                                .fill(Color.secondary)
                                .opacity(0.5)
                                .frame(width: 80, height: 20)
                                .padding(4)
                            
                            Text(tile.name)
                                .padding(6)
                        }
                        
                        /*
                        .onDrag({
                            currentTile = tile
                            currentTileSet.currentTile = tile
                           return NSItemProvider(object: String(tile.name) as NSString)
                        })
                        
                        .onDrop(of: [.text], delegate: TileDropViewDelegate(grid: tile, gridData: currentTileSet))
                        */
                        
                        .contextMenu {
                            Button("Duplicate", action: {
                                func copyTile(_ tile: Tile) -> Tile {
                                    if let data = try? JSONEncoder().encode(tile) {
                                        if let copiedTile = try? JSONDecoder().decode(Tile.self, from: data) {
                                            return copiedTile
                                        }
                                    }
                                    return tile
                                }
                                
                                let copy = copyTile(tile)
                                copy.id = UUID()
                                currentTileSet.tiles.append(copy)
                                updateView.toggle()
                                document.core.updateTileAndNodesPreviews(currentTileSet)
                            })
                            
                            Button("Rename ...", action: {
                                tileName = tile.name
                                contextTile = tile
                                showRenameTilePopover = true
                            })
                            
                            Divider()
                            
                            Button("Remove", action: {
                                if let index = currentTileSet.tiles.firstIndex(of: tile) {
                                    currentTileSet.tiles.remove(at: index)
                                    updateView.toggle()
                                }
                            })
                        }
                    }
                }
            }
            .padding(4)
            
            Spacer()
        }
        
        .popover(isPresented: $showRenameTilePopover,
                 arrowEdge: .top
        ) {
            VStack(alignment: .leading) {
                Text("Tile Name:")
                TextField("Name", text: $tileName, onEditingChanged: { (changed) in
                    if let currentTile = contextTile {
                        currentTile.name = tileName
                        updateView.toggle()
                    }
                })
                .frame(minWidth: 200)
            }.padding()
        }
        
        .onAppear(perform: {
            currentTileSet = document.core.project.currentTileSet
            if let currentTileSet = currentTileSet {
                currentTile = currentTileSet.currentTile
                document.core.updateTileAndNodesPreviews()
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
