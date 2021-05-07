//
//  Classes.swift
//  Fabricated
//
//  Created by Markus Moenig on 8/4/21.
//

import Foundation

/// Utility class to handles reading / writing values from a named float map
class MMValues
{
    var values    : [String:Float] = [:]

    func doesFloatExist(_ name: String) -> Bool {
        if values[name] == nil {
            return false
        } else {
            return true
        }
    }
    
    func readFloat(_ name: String,_ defaultValue: Float = 0) -> Float
    {
        var rc = Float(defaultValue)
        if let x = values[name] { rc = x }
        return rc
    }
    
    func writeFloat(_ name: String, value: Float)
    {
        values[name] = value
    }
    
    func readFloat2(_ name: String,_ defaultValue: float2 = float2(0,0)) -> float2
    {
        var rc = defaultValue
        if let x = values[name + "_x"] { rc.x = x }
        if let y = values[name + "_y"] { rc.y = y }
        return rc
    }
    
    func writeFloat2(_ name: String, value: float2)
    {
        values[name + "_x"] = value.x
        values[name + "_y"] = value.y
    }
    
    func readFloat3(_ name: String) -> float3
    {
        var rc = float3(0,0,0)
        if let x = values[name + "_x"] { rc.x = x }
        if let y = values[name + "_y"] { rc.y = y }
        if let z = values[name + "_z"] { rc.z = z }
        return rc
    }
    
    func writeFloat3(_ name: String, value: float3)
    {
        values[name + "_x"] = value.x
        values[name + "_y"] = value.y
        values[name + "_z"] = value.z
    }
    
    func readFloat4(_ name: String) -> float4
    {
        var rc = float4(0,0,0,0)
        if let x = values[name + "_x"] { rc.x = x }
        if let y = values[name + "_y"] { rc.y = y }
        if let z = values[name + "_z"] { rc.z = z }
        if let w = values[name + "_w"] { rc.w = w }
        return rc
    }
    
    func writeFloat4(_ name: String, value: float4)
    {
        values[name + "_x"] = value.x
        values[name + "_y"] = value.y
        values[name + "_z"] = value.z
        values[name + "_w"] = value.w
    }
    
    // These functions read / write to either itself or the currently selected area if .Select tool is active
    
    func readOptionalFloatInstanceArea(_ core: Core,_ node: TileNode,_ name: String,_ defaultValue: Float = 0) -> Float
    {
        if let area = core.screenView.getCurrentArea(), core.currentTool == .Select {
            // Read values from the area
            return readFloatFromInstanceAreaIfExists(area, node, name, defaultValue)
        } else {
            // Write value to self
            return readFloat(name, defaultValue)
        }
    }

    func writeOptionalFloatInstanceArea(_ core: Core,_ node: TileNode,_ name: String, value: Float)
    {
        if let area = core.screenView.getCurrentArea(), core.currentTool == .Select {
            // Write values into the area
            area.writeFloat(node.id.uuidString + "_" + name, value: value)
        } else {
            // Write value to self
            writeFloat(name, value: value)
        }
    }
    
    func readOptionalFloat4InstanceArea(_ core: Core,_ node: TileNode,_ name: String,_ defaultValue: float4 = float4(0,0,0,0)) -> float4
    {
        var value = float4()
        value.x = readOptionalFloatInstanceArea(core, node, name + "_x", defaultValue.x)
        value.y = readOptionalFloatInstanceArea(core, node, name + "_y", defaultValue.y)
        value.z = readOptionalFloatInstanceArea(core, node, name + "_z", defaultValue.z)
        value.w = readOptionalFloatInstanceArea(core, node, name + "_w", defaultValue.w)
        return value
    }
    
    func writeOptionalFloat4InstanceArea(_ core: Core,_ node: TileNode,_ name: String, value: float4)
    {
        writeOptionalFloatInstanceArea(core, node, name + "_x", value: value.x)
        writeOptionalFloatInstanceArea(core, node, name + "_y", value: value.y)
        writeOptionalFloatInstanceArea(core, node, name + "_z", value: value.z)
        writeOptionalFloatInstanceArea(core, node, name + "_w", value: value.w)
    }
    
    func readOptionalFloat2InstanceArea(_ core: Core,_ node: TileNode,_ name: String,_ defaultValue: float2 = float2(0,0)) -> float2
    {
        var value = float2()
        value.x = readOptionalFloatInstanceArea(core, node, name + "_x", defaultValue.x)
        value.y = readOptionalFloatInstanceArea(core, node, name + "_y", defaultValue.y)
        return value
    }
    
    func writeOptionalFloat2InstanceArea(_ core: Core,_ node: TileNode,_ name: String, value: float2)
    {
        writeOptionalFloatInstanceArea(core, node, name + "_x", value: value.x)
        writeOptionalFloatInstanceArea(core, node, name + "_y", value: value.y)
    }
    
    // These functions read / write to either itself or the currently selected instance if .Select tool is active
    func readFloatFromInstanceAreaIfExists(_ instance: TileInstanceArea,_ node: TileNode,_ name: String,_ defaultValue: Float = 0) -> Float
    {
        if let value = instance.values[node.id.uuidString + "_" + name] {
            return value
        } else {
            // Read from self
            return readFloat(name, defaultValue)
        }
    }
    
    func readFloat2FromInstanceAreaIfExists(_ instance: TileInstanceArea,_ node: TileNode,_ name: String,_ defaultValue: float2 = float2(0,0)) -> float2
    {
        var value = float2()
        value.x = readFloatFromInstanceAreaIfExists(instance, node, name + "_x", defaultValue.x)
        value.y = readFloatFromInstanceAreaIfExists(instance, node, name + "_y", defaultValue.y)
        return value
    }
    
    func readFloat4FromInstanceAreaIfExists(_ instance: TileInstanceArea,_ node: TileNode,_ name: String,_ defaultValue: float4 = float4(0,0,0,1)) -> float4
    {
        var value = float4()
        value.x = readFloatFromInstanceAreaIfExists(instance, node, name + "_x", defaultValue.x)
        value.y = readFloatFromInstanceAreaIfExists(instance, node, name + "_y", defaultValue.y)
        value.z = readFloatFromInstanceAreaIfExists(instance, node, name + "_z", defaultValue.z)
        value.w = readFloatFromInstanceAreaIfExists(instance, node, name + "_w", defaultValue.w)
        return value
    }
}

/// MMRect class
class MMRect
{
    var x : Float
    var y: Float
    var width: Float
    var height: Float
    
    init( _ x : Float, _ y : Float, _ width: Float, _ height : Float, scale: Float = 1 )
    {
        self.x = x * scale; self.y = y * scale; self.width = width * scale; self.height = height * scale
    }
    
    init()
    {
        x = 0; y = 0; width = 0; height = 0
    }
    
    init(_ rect : MMRect)
    {
        x = rect.x; y = rect.y
        width = rect.width; height = rect.height
    }
    
    func set( _ x : Float, _ y : Float, _ width: Float, _ height : Float, scale: Float = 1 )
    {
        self.x = x * scale; self.y = y * scale; self.width = width * scale; self.height = height * scale
    }
    
    /// Copy the content of the given rect
    func copy(_ rect : MMRect)
    {
        x = rect.x; y = rect.y
        width = rect.width; height = rect.height
    }
    
    /// Returns true if the given point is inside the rect
    func contains( _ x : Float, _ y : Float ) -> Bool
    {
        if self.x <= x && self.y <= y && self.x + self.width >= x && self.y + self.height >= y {
            return true;
        }
        return false;
    }
    
    /// Returns true if the given point is inside the scaled rect
    func contains( _ x : Float, _ y : Float, _ scale : Float ) -> Bool
    {
        if self.x <= x && self.y <= y && self.x + self.width * scale >= x && self.y + self.height * scale >= y {
            return true;
        }
        return false;
    }
    
    /// Intersect the rects
    func intersect(_ rect: MMRect)
    {
        let left = max(x, rect.x)
        let top = max(y, rect.y)
        let right = min(x + width, rect.x + rect.width )
        let bottom = min(y + height, rect.y + rect.height )
        let width = right - left
        let height = bottom - top
        
        if width > 0 && height > 0 {
            x = left
            y = top
            self.width = width
            self.height = height
        } else {
            copy(rect)
        }
    }
    
    /// Merge the rects
    func merge(_ rect: MMRect)
    {
        width = width > rect.width ? width : rect.width + (rect.x - x)
        height = height > rect.height ? height : rect.height + (rect.y - y)
        x = min(x, rect.x)
        y = min(y, rect.y)
    }
    
    /// Returns the cordinate of the right edge of the rectangle
    func right() -> Float
    {
        return x + width
    }
    
    /// Returns the cordinate of the bottom of the rectangle
    func bottom() -> Float
    {
        return y + height
    }
    
    /// Shrinks the rectangle by the given x and y amounts
    func shrink(_ x : Float,_ y : Float)
    {
        self.x += x
        self.y += y
        self.width -= x * 2
        self.height -= y * 2
    }
    
    /// Clears the rect
    func clear()
    {
        set(0, 0, 0, 0)
    }
    
    /// Returns the position of the rect as float2
    func position() -> float2
    {
        return float2(x, y)
    }
    
    /// Returns the middle of the rect
    func middle() -> float2
    {
        return float2(x, y) + float2(width, height) / 2.0
    }
    
    /// Returns the size of the rect as float2
    func size() -> float2
    {
        return float2(width, height)
    }
}

