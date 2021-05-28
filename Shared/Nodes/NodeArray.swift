//
//  NodeArray.swift
//  Fabricated
//
//  Created by Markus Moenig on 10/4/21.
//

import Foundation

// --- Helper for heterogeneous node arrays
// --- Taken from https://medium.com/@kewindannerfjordremeczki/swift-4-0-decodable-heterogeneous-collections-ecc0e6b468cf

protocol NodeClassFamily: Decodable {
    static var discriminator: NodeDiscriminator { get }
    
    func getType() -> AnyObject.Type
}

enum NodeDiscriminator: String, CodingKey {
    case type = "type"
}

/// The NodeFamily enum describes the node types
enum NodeFamily: String, NodeClassFamily {
    case tiledNode = "TiledNode"
    case isoTiledNode = "IsoTiledNode"

    case shapeBox = "ShapeBox"
    case shapeDisk = "ShapeDisk"
    case shapeGround = "ShapeGround"

    case modifierNoise = "ModifierNoise"
    case modifierTiledNoise = "ModifierTiledNoise"

    case decoratorColor = "DecoratorColor"
    case decoratorGradient = "DecoratorGradient"
    case decoratorTilesAndBricks = "DecoratorTilesAndBricks"
    
    static var discriminator: NodeDiscriminator = .type
    
    func getType() -> AnyObject.Type
    {
        switch self
        {
            case .tiledNode:
                return TiledNode.self
            case .isoTiledNode:
                return IsoTiledNode.self
                
            case .shapeBox:
                return ShapeBox.self
            case .shapeDisk:
                return ShapeDisk.self
            case .shapeGround:
                return ShapeGround.self
                
            case .modifierNoise:
                return ModifierNoise.self
            case .modifierTiledNoise:
                return ModifierTiledNoise.self
                
            case .decoratorColor:
                return DecoratorColor.self
            case .decoratorGradient:
                return DecoratorGradient.self
            case .decoratorTilesAndBricks:
                return DecoratorTilesAndBricks.self
        }
    }
}

extension KeyedDecodingContainer {
    
    /// Decode a heterogeneous list of objects for a given family.
    /// - Parameters:
    ///     - heterogeneousType: The decodable type of the list.
    ///     - family: The ClassFamily enum for the type family.
    ///     - key: The CodingKey to look up the list in the current container.
    /// - Returns: The resulting list of heterogeneousType elements.
    func decode<T : Decodable, U : NodeClassFamily>(_ heterogeneousType: [T].Type, ofFamily family: U.Type, forKey key: K) throws -> [T] {
        var container = try self.nestedUnkeyedContainer(forKey: key)
        var list = [T]()
        var tmpContainer = container
        while !container.isAtEnd {
            let typeContainer = try container.nestedContainer(keyedBy: NodeDiscriminator.self)
            let family: U = try typeContainer.decode(U.self, forKey: U.discriminator)
            if let type = family.getType() as? T.Type {
                list.append(try tmpContainer.decode(type))
            }
        }
        return list
    }
}
