//
//  Project.swift
//  Fabricated
//
//  Created by Markus Moenig on 7/4/21.
//

import Foundation

class FABProject           : Codable
{
    var scenes          : [FABScene] = []

    init()
    {
        
    }
    
    private enum CodingKeys: String, CodingKey {
        case scenes
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scenes = try container.decode([FABScene].self, forKey: .scenes)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scenes, forKey: .scenes)
    }
    
}

class FABScene         : Codable, Equatable
{
    /*
    enum AssetType  : Int, Codable {
        case Layer
    }*/
    
    //var type        : AssetType = .Layer
    var id          = UUID()
    
    var name        = ""
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
    
    static func ==(lhs:FABScene, rhs:FABScene) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}
