//
//  Undo.swift
//  Fabricated
//
//  Created by Markus Moenig on 3/5/21.
//

import Foundation

/// Handles undo for a layer
class LayerUndoComponent
{
    let core            : Core

    var name            : String
    var layer           : Layer
    
    var originalData    : String = ""
    var processedData   : String = ""
            
    init(_ layer : Layer,_ core: Core,_ name: String)
    {
        self.name = name
        self.layer = layer
        self.core = core
    }
    
    func start()
    {
        let encodedData = try? JSONEncoder().encode(layer)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
        {
            originalData = encodedObjectJsonString
        }
    }
    
    func end() {
            
        let encodedData = try? JSONEncoder().encode(layer)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
            processedData = encodedObjectJsonString
        }
        
        func layerChangedCB(_ oldState: String, _ newState: String)
        {
            core.undoManager!.registerUndo(withTarget: self) { target in
                if let jsonData = oldState.data(using: .utf8) {
                    if let layer =  try? JSONDecoder().decode(Layer.self, from: jsonData) {
                        if let screen = self.core.project.getScreenForLayer(layer.id) {
                            var index : Int? = nil
                            for (i,l) in screen.layers.enumerated() {
                                if l.id == layer.id {
                                    index = i
                                }
                            }
                            if index != nil {
                                screen.layers[index!] = layer
                                self.core.project.currentLayer = layer
                                self.core.layerChanged.send(layer)
                                self.core.project.setHasChanged(true)
                                self.core.renderer.render()
                            }
                        }
                    }
                }
                layerChangedCB(newState, oldState)
            }
            core.undoManager!.setActionName(name)
        }
        
        layerChangedCB(originalData, processedData)
    }
}

/// Handles Undo for a given tile
class TileUndoComponent
{
    let core            : Core

    var name            : String
    var tile            : Tile
    
    var originalData    : String = ""
    var processedData   : String = ""
            
    init(_ tile : Tile,_ core: Core,_ name: String)
    {
        self.name = name
        self.tile = tile
        self.core = core
    }
    
    func start()
    {
        let encodedData = try? JSONEncoder().encode(tile)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
        {
            originalData = encodedObjectJsonString
        }
    }
    
    func end() {
                    
        let encodedData = try? JSONEncoder().encode(tile)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
            processedData = encodedObjectJsonString
        }
        
        func tileChangedCB(_ oldState: String, _ newState: String)
        {
            core.undoManager!.registerUndo(withTarget: self) { target in
                if let jsonData = oldState.data(using: .utf8) {
                    if let tile = try? JSONDecoder().decode(Tile.self, from: jsonData) {
                        if let tileSet = self.core.project.getTileSetForTile(tile.id) {
                            var index : Int? = nil
                            for (i,l) in tileSet.tiles.enumerated() {
                                if l.id == tile.id {
                                    index = i
                                }
                            }
                            if index != nil {
                                tileSet.tiles[index!] = tile
                                if let currentNode = self.core.nodeView.currentNode {
                                    let id = currentNode.id
                                    self.core.nodeView.currentNode = nil

                                    for n in tile.nodes {
                                        if n.id == id {
                                            self.core.nodeView.currentNode = n
                                            break
                                        }
                                    }
                                }
                                tileSet.currentTile = tile
                                tileSet.openTile = tile

                                tile.setHasChanged(true)
                                
                                self.core.tileNodeChanged.send(self.core.nodeView.currentNode)
                                
                                self.core.nodeView.update()
                                self.core.updateTilePreviews(tile)
                                self.core.renderer.render()
                            }
                        }
                    }
                }
                tileChangedCB(newState, oldState)
            }
            core.undoManager!.setActionName(name)
        }
        
        tileChangedCB(originalData, processedData)
    }
}
