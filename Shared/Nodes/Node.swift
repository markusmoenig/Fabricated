//
//  Node.swift
//  Fabricated
//
//  Created by Markus Moenig on 8/4/21.
//

import MetalKit

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

class TileNodeOptionExclusion
{
    var name                = ""
    var value               = Float(0)
        
    init(_ name: String,_ value: Float)
    {
        self.name = name
        self.value = value
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
    
    var range               : float2
    
    var exclusion           : TileNodeOptionExclusion? = nil
    var exclusionTrigger    : Bool = false
    
    var defaultFloat        : Float

    init(_ node: TileNode,_ name: String,_ type: OptionType, menuEntries: [String]? = nil, range: float2 = float2(0,1), exclusion: TileNodeOptionExclusion? = nil, exclusionTrigger: Bool = false, defaultFloat: Float = 1, defaultFloat4: float4 = float4(0.5, 0.5, 0.5, 1))
    {
        self.node = node
        self.name = name
        self.type = type
        self.menuEntries = menuEntries
        self.range = range
        self.exclusion = exclusion
        self.exclusionTrigger = exclusionTrigger
        self.defaultFloat = defaultFloat
        
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
        case Tile, Shape, Modifier, Decorator, Pattern, IsoTile
    }
    
    enum TileNodeTool {
        case None, Offset, QuadraticSpline, Range
    }
    
    var id                  = UUID()
    var name                = "" // User defined
    
    var type                : String = "" // To identify the node when loading via JSON
    
    var role                : TileNodeRole = .Tile
    var tool                : TileNodeTool = .None

    /// Set by pattern nodes to identify the id
    var hash                : Float = 0
    
    var nodeRect            = MMRect()
    var nodePreviewRect     = MMRect()

    var optionGroups        : [TileNodeOptionsGroup] = []
    
    // For node preview, always fixed size of 80
    var texture             : MTLTexture? = nil
    
    // --- The terminals, nodes can have multiple outputs but only one input
    var terminalsOut        : [Int: [UUID]] = [:]
    var terminalIn          : [UUID] = []

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
        terminalsOut = try container.decode([Int:[UUID]].self, forKey: .terminalsOut)
        terminalIn = try container.decode([UUID].self, forKey: .terminalIn)
        setup()
    }
    
    deinit {
        if let texture = texture {
            texture.setPurgeableState(.empty)
        }
        texture = nil
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

    /// Pixelizes the UV coordinate based on the pixelSize
    func getPixelUV(pixelCtx: TilePixelContext, tileCtx: TileContext, uv: float2) -> float2
    {
        let pixelSize = pixelCtx.width / tileCtx.pixelSize
        
        var rc = floor(uv * pixelSize) / pixelSize
        rc += 1.0 / (pixelSize * 2.0)
        return rc
    }
    
    /// Transforms the UV
    func transformUV(pixelCtx: TilePixelContext, tileCtx: TileContext, pixelise: Bool = true, centered: Bool = true, areaAdjust: Bool = false) -> float2
    {
        var uv = pixelCtx.uv
        
        if areaAdjust {
            if tileCtx.areaSize.x > 1 {
                uv.x += tileCtx.areaSize.x - (tileCtx.areaSize.x - tileCtx.areaOffset.x)
            }

            if tileCtx.areaSize.y > 1 {
                uv.y += tileCtx.areaSize.y - (tileCtx.areaSize.y - tileCtx.areaOffset.y)
            }
        }
        
        if centered {
            uv -= 0.5
        }
        
        let offset = readFloat2FromInstanceAreaIfExists(tileCtx.tileArea, self, "_offset", float2(0.5, 0.5))
        uv -= offset - float2(0.5, 0.5)
        
        func rotateCW(_ pos : SIMD2<Float>, angle: Float, pivot: float2) -> SIMD2<Float>
        {
            let ca : Float = cos(angle), sa = sin(angle)
            return pivot + (pos - pivot) * float2x2(float2(ca, sa), float2(-sa, ca))
        }
        
        let rotation = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Rotation", 0)
        if rotation != 0.0 {
            var pivot = offset
            if tileCtx.areaSize.x * tileCtx.areaSize.y == 1 {
                pivot = float2(0,0)
            }
            uv = rotateCW(uv, angle: rotation.degreesToRadians, pivot: pivot)
        }

        let tUV = pixelise == true ? getPixelUV(pixelCtx: pixelCtx, tileCtx: tileCtx, uv: uv) : uv
        
        return tUV
    }
    
    /// Gets  the next optional id in the chain
    func getChainedNodeIdsForRole(_ connectedRole: TileNodeRole) -> [UUID]
    {
        if role == .Tile {
            if connectedRole == .Shape {
                if let id = terminalsOut[0] {
                    return id
                }
            }
        } else
        if role == .IsoTile {
            if connectedRole == .Shape {
                if let isoNode = self as? IsoTiledNode {
                    if let id = terminalsOut[isoNode.isoFace.rawValue] {
                        return id
                    }
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
        if role == .Decorator || role == .Pattern {
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
        return []
    }
    
    /// Creates the shape  options
    func createShapeOptionsGroup() -> TileNodeOptionsGroup {
        return TileNodeOptionsGroup("Shape Options", [
            TileNodeOption(self, "Shape", .Menu, menuEntries: ["Standalone", "Merge"], defaultFloat: 1)
        ])
    }
    
    /// Creates  the decorator mask options
    func createDefaultDecoratorOptionsGroup() -> TileNodeOptionsGroup {
        return TileNodeOptionsGroup("Default Options", [
            TileNodeOption(self, "Shape", .Menu, menuEntries: ["Inside", "Outside"], defaultFloat: 0),
            TileNodeOption(self, "Modifier", .Menu, menuEntries: ["Add", "Mix"], defaultFloat: 0),
            TileNodeOption(self, "Depth Range", .Switch, exclusionTrigger: true, defaultFloat: 0),
            TileNodeOption(self, "Depth Start", .Float, exclusion: TileNodeOptionExclusion("Depth Range", 0), defaultFloat: 0),
            TileNodeOption(self, "Depth End", .Float, exclusion: TileNodeOptionExclusion("Depth Range", 0), defaultFloat: 1)
        ])
    }
        
    static func ==(lhs:TileNode, rhs:TileNode) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}

/// For JSON storage we need a derived version of TileNode
class TiledNode : TileNode {
    
    var cgiImage        : CGImage? = nil
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Tile, "Tile")
    }
    
    deinit {
        cgiImage = nil
        if let texture = texture {
            texture.setPurgeableState(.empty)
        }
        texture = nil
    }
    
    override func setup()
    {
        type = "TiledNode"
        tool = .Offset
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
