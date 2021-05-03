//
//  Undo.swift
//  Fabricated
//
//  Created by Markus Moenig on 3/5/21.
//

import Foundation

class LayerUndoComponent
{
    let core            : Core

    var name            : String
    var layer           : Layer
    
    var originalData    : String = ""
    var processedData   : String = ""
            
    init(_ layer : Layer,_ core: Core)
    {
        self.name = "Layer Changed"
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
                                self.core.renderer.render()
                            }
                        }
                    }
                }
                layerChangedCB(newState, oldState)
            }
            core.undoManager!.setActionName("Layer")
        }
        
        layerChangedCB(originalData, processedData)
    }
}
