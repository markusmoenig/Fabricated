//
//  Node.swift
//  Fabricated
//
//  Created by Markus Moenig on 8/4/21.
//

import Foundation

class TileNodeOptionsGroup
{
    
    var id                  = UUID()
    var name                = ""
        
    var options             : [TileNodeOption]

    init(_ name: String,_ options: [TileNodeOption] = [])
    {
        self.name = name
        self.options = options
    }
}

class TileNodeOption
{
    enum OptionType {
        case Int, Float, Switch, Color, Menu
    }
    
    var id                  = UUID()

    var type                : OptionType = .Float
    var name                = ""
    
    let node                : TileNode
    
    let menuEntries         : [String]?
        
    init(_ node: TileNode,_ name: String,_ type: OptionType, menuEntries: [String]? = nil, defaultFloat: Float = 1, defaultFloat4: float4 = float4(0.5, 0.5, 0.5, 1))
    {
        self.node = node
        self.name = name
        self.type = type
        self.menuEntries = menuEntries
        
        if type == .Color {
            if node.doesFloatExist(name + "_x") == false {
                node.writeFloat4(name, value: defaultFloat4)
            }
        } else {
            // Float based
            if node.doesFloatExist(name) == false {
                node.writeFloat(name, value: defaultFloat)
            }
        }
    }
}

class TileNode : MMValues, Codable, Equatable, Identifiable {

    enum TileNodeRole : Int, Codable {
        case Tile, Shape, Modifier, Decorator
    }
    
    var id                  = UUID()
    var name                = "" // User defined
    
    var type                : String = "" // To identify the node when loading via JSON
    
    var role                : TileNodeRole = .Tile
    
    var nodeRect            = MMRect()
    
    var optionGroups        : [TileNodeOptionsGroup] = []
    
    // --- The terminals, nodes can have multiple outputs but only one input
    var terminalsOut        : [Int: UUID] = [:]
    var terminalIn          : UUID? = nil

    // --- For terminal drawing
    var terminalsOutRect    = [MMRect(), MMRect(),MMRect(),MMRect()]
    var terminalInRect      = MMRect()
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case values
        case terminalsOut
        case terminalIn
    }
    
    init(_ role: TileNodeRole,_ name: String = "Unnamed")
    {
        self.role = role
        self.name = name
        super.init()
        writeFloat2("nodePos", value: float2(0,0))
        setup()
    }
    
    required init(from decoder: Decoder) throws
    {
        super.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(TileNodeRole.self, forKey: .role)
        values = try container.decode([String:Float].self, forKey: .values)
        terminalsOut = try container.decode([Int:UUID].self, forKey: .terminalsOut)
        terminalIn = try container.decode(UUID?.self, forKey: .terminalIn)
        setup()
    }
    
    func setup()
    {
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(values, forKey: .values)
        try container.encode(terminalsOut, forKey: .terminalsOut)
        try container.encode(terminalIn, forKey: .terminalIn)
    }
    
    /// Renders the output color of the node
    func render(pixelCtx: TilePixelContext, tileCtx: TileContext, prevColor: float4) -> float4
    {
        return float4()
    }
    
    /// Renders the output value
    func render(pixelCtx: TilePixelContext, tileCtx: TileContext) -> Float
    {
        return 0
    }
    
    /// Modifies the distance (only available for shape nodes)
    func modifyDistance(pixelCtx: TilePixelContext, tileCtx: TileContext, distance: Float) -> Float {
        var dist = distance
        if role == .Shape {
            if let modifierNode = tileCtx.tile.getNextInChain(self, .Modifier) {
                dist -= modifierNode.render(pixelCtx: pixelCtx, tileCtx: tileCtx)
            }
        }
        return dist
    }

    /// Pixelizes the UV coordinate based on the pixelSize
    func getPixelUV(_ uv: float2,_ pixelSize: Float) -> float2
    {
        var rc = floor(uv * pixelSize) / pixelSize
        rc += 1.0 / (pixelSize * 2.0)
        return rc
    }
    
    /// Transforms the UV
    func transformUV(pixelCtx: TilePixelContext, tileCtx: TileContext, pixelise: Bool = true) -> float2
    {
        var uv = pixelCtx.uv
        
        let positionX = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Position X")
        let positionY = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Position Y")

        if positionX == 1 {
            // Center
            uv.x -= 0.5
        } else
        if positionX == 2 {
            // Right
            uv.x -= 1.0
        }
        
        if positionY == 1 {
            // Center
            uv.y -= 0.5
        } else
        if positionY == 2 {
            // Bottom
            uv.y -= 1.0
        }
        
        var tUV = pixelise == true ? getPixelUV(uv, tileCtx.pixelSize) : uv
        
        func rotateCW(_ pos : SIMD2<Float>, angle: Float) -> SIMD2<Float>
        {
            let ca : Float = cos(angle), sa = sin(angle)
            return pos * float2x2(float2(ca, sa), float2(-sa, ca))
        }
        
        let rotation = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Rotation") * 360.0
        
        tUV = rotateCW(tUV, angle: rotation.degreesToRadians)
        
        return tUV
    }

    /// Renders the chain of Decorators
    func renderDecorators(pixelCtx: TilePixelContext, tileCtx: TileContext, prevColor: float4) -> float4
    {
        var color = prevColor
        
        func appyModifier(_ node: TileNode, prevColor: float4) -> float4 {
            var color = prevColor
            if let modifierNode = tileCtx.tile.getNextInChain(node, .Modifier) {
                let value = modifierNode.render(pixelCtx: pixelCtx, tileCtx: tileCtx)

                color.x += value
                color.y += value
                color.z += value
                
                color.clamp(lowerBound: float4(0,0,0,0), upperBound: float4(1,1,1,1))
            }
            return color
        }
        
        if role == .Shape {
            if var decoNode = tileCtx.tile.getNextInChain(self, .Decorator) {
                color = decoNode.render(pixelCtx: pixelCtx, tileCtx: tileCtx, prevColor: color)
                color = appyModifier(decoNode, prevColor: color)
                
                while let nextDecoNode = tileCtx.tile.getNextInChain(decoNode, .Decorator) {
                    color = nextDecoNode.render(pixelCtx: pixelCtx, tileCtx: tileCtx, prevColor: color)
                    decoNode = nextDecoNode
                }                
            } else {
                let step = simd_smoothstep(0, -1.0 / pixelCtx.width, pixelCtx.localDist)
                color = simd_mix(prevColor, float4(1,1,1,1), float4(step, step, step, step))
            }
        }
        
        return color
    }
    
    /// Computes the decorator mask
    func computeDecoratorMask(pixelCtx: TilePixelContext, tileCtx: TileContext) -> Float
    {
        let maskStart = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Mask Start", 0)
        let maskEnd = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Mask End", 1)
        return simd_smoothstep(-maskEnd, -maskStart, pixelCtx.localDist)
    }
    
    /// Gets  the next optional id in the chain
    func getChainedNodeIdForRole(_ connectedRole: TileNodeRole) -> UUID?
    {
        if role == .Tile {
            if connectedRole == .Shape {
                if let id = terminalsOut[0] {
                    return id
                }
            }
        } else
        if role == .Shape {
            if connectedRole == .Shape {
                if let id = terminalsOut[2] {
                    return id
                }
            } else
            if connectedRole == .Modifier {
                if let id = terminalsOut[0] {
                    return id
                }
            } else
            if connectedRole == .Decorator {
                if let id = terminalsOut[1] {
                    return id
                }
            }
        } else
        if role == .Decorator {
            if connectedRole == .Modifier {
                if let id = terminalsOut[0] {
                    return id
                }
            } else
            if connectedRole == .Decorator {
                if let id = terminalsOut[1] {
                    return id
                }
            }
        }
        return nil
    }
    
    /// Creates the shape transform options
    func createShapeTransformGroup() -> TileNodeOptionsGroup {
        return TileNodeOptionsGroup("Transform Options", [
            TileNodeOption(self, "Position X", .Menu, menuEntries: ["Left", "Center", "Right"], defaultFloat: 1),
            TileNodeOption(self, "Position Y", .Menu, menuEntries: ["Top", "Center", "Bottom"], defaultFloat: 1),
            TileNodeOption(self, "Rotation", .Float, defaultFloat: 0)
        ])
    }
    
    /// Creates  the decorator mask options
    func createDecoratorMaskGroup() -> TileNodeOptionsGroup {
        return TileNodeOptionsGroup("Mask Options", [
            TileNodeOption(self, "Mask Start", .Float, defaultFloat: 0),
            TileNodeOption(self, "Mask End", .Float, defaultFloat: 1)
        ])
    }
        
    static func ==(lhs:TileNode, rhs:TileNode) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}

/// For JSON storage we need a derived version of TileNode
class TiledNode : TileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Tile, "Tile")
    }
    
    override func setup()
    {
        type = "TiledNode"
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
}
