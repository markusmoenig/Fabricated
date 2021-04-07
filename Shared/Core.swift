//
//  Core.swift
//  Fabricated
//
//  Created by Markus Moenig on 7/4/21.
//

import MetalKit
import Combine
import AVFoundation

class Core
{
    var view            : FABView!
    var device          : MTLDevice!

    var nodesView       : FABView!
    
    var metalStates     : MetalStates!

    var project         : FABProject
    
    init()
    {
        project = FABProject()
    }
    
    /// Sets a loaded project
    func setProject(project: FABProject)
    {
        self.project = project
    }
    
    /// Setup the preview view
    public func setupView(_ view: FABView)
    {
        self.view = view
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            device = metalDevice
        } else {
            print("Cannot initialize Metal!")
        }
        view.core = self
        
        metalStates = MetalStates(self)
        
        view.platformInit()
    }
    
    public func setupNodesView(_ view: FABView)
    {
        view.platformInit()

        nodesView = view
        view.core = self
        //nodesWidget = NodesWidget(self)
    }
    
    public func draw()
    {
        
    }
}
