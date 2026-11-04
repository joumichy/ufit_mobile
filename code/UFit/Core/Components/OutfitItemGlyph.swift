import SwiftUI

/// Ufit-owned vector artwork on a shared grid. Adding a type requires its drawing.
struct UFitOutfitItemGlyph: Shape {
    let type: UFitOutfitItemType
    private enum Grid { static let side: CGFloat = 24 }
    private typealias Point = (CGFloat, CGFloat)
    private enum Stroke { case open([Point]), closed([Point]), oval(CGRect), rounded(CGRect, CGFloat) }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for stroke in strokes {
            switch stroke {
            case .open(let points): append(points, closed: false, to: &path)
            case .closed(let points): append(points, closed: true, to: &path)
            case .oval(let bounds): path.addEllipse(in: bounds)
            case .rounded(let bounds, let radius): path.addRoundedRect(in: bounds, cornerSize: .init(width: radius, height: radius))
            }
        }
        return path.applying(.init(scaleX: rect.width / Grid.side, y: rect.height / Grid.side)
            .concatenating(.init(translationX: rect.minX, y: rect.minY)))
    }
    private func append(_ points: [Point], closed: Bool, to path: inout Path) {
        guard let first = points.first else { return }
        path.move(to: .init(x: first.0, y: first.1))
        for point in points.dropFirst() { path.addLine(to: .init(x: point.0, y: point.1)) }
        if closed { path.closeSubpath() }
    }
    private var strokes: [Stroke] {
        switch type {
        case .top: Drawing.top
        case .shirt: Drawing.shirt
        case .knitwear: Drawing.knitwear
        case .hoodie: Drawing.hoodie
        case .vest: Drawing.vest
        case .outerwear: Drawing.outerwear
        case .bottom: Drawing.bottom
        case .skirt: Drawing.skirt
        case .shorts: Drawing.shorts
        case .dress: Drawing.dress
        case .jumpsuit: Drawing.jumpsuit
        case .swimwear: Drawing.swimwear
        case .underwear: Drawing.underwear
        case .shoes: Drawing.shoes
        case .sneakers: Drawing.sneakers
        case .boots: Drawing.boots
        case .sandals: Drawing.sandals
        case .heels: Drawing.heels
        case .socks: Drawing.socks
        case .tights: Drawing.tights
        case .bag: Drawing.bag
        case .backpack: Drawing.backpack
        case .clutch: Drawing.clutch
        case .eyewear: Drawing.eyewear
        case .headwear: Drawing.headwear
        case .hat: Drawing.hat
        case .beanie: Drawing.beanie
        case .scarf: Drawing.scarf
        case .belt: Drawing.belt
        case .gloves: Drawing.gloves
        case .watch: Drawing.watch
        case .necklace: Drawing.necklace
        case .earrings: Drawing.earrings
        case .bracelet: Drawing.bracelet
        case .ring: Drawing.ring
        case .tie: Drawing.tie
        case .bowtie: Drawing.bowtie
        case .hairclip: Drawing.hairclip
        case .brooch: Drawing.brooch
        case .umbrella: Drawing.umbrella
        case .accessory: Drawing.accessory
        }
    }
    private enum Drawing {
        static let top: [Stroke] = [
            .closed([(8,4),(4,6),(1,10),(5,13),(7,10),(7,21),(17,21),(17,10),(19,13),(23,10),(20,6),(16,4),(15,7),(9,7)]),
        ]
        static let shirt: [Stroke] = [
            .closed([(8,3),(3,6),(1,18),(5,19),(8,10),(8,22),(18,22),(18,10),(21,19),(23,18),(21,6),(16,3)]),
            .open([(8,3),(12,7),(16,3)]), .open([(12,7),(12,22)]),
            .open([(8,3),(9,8),(12,7),(15,8),(16,3)]),
        ]
        static let knitwear: [Stroke] = [
            .closed([(8,4),(4,6),(1,18),(5,20),(8,11),(8,21),(17,21),(17,11),(20,20),(23,18),(20,6),(16,4)]),
            .open([(8,4),(9,7),(12,8),(15,7),(16,4)]), .open([(8,18),(17,18)]),
        ]
        static let hoodie: [Stroke] = [
            .closed([(8,6),(7,4),(9,2),(15,2),(17,4),(16,6),(20,8),(23,19),(19,21),(17,13),(17,22),(7,22),(7,13),(5,21),(1,19),(4,8)]),
            .open([(8,6),(12,9),(16,6)]), .open([(10,8),(10,12)]), .open([(14,8),(14,12)]),
            .closed([(9,16),(15,16),(16,19),(8,19)]),
        ]
        static let vest: [Stroke] = [
            .closed([(8,3),(4,5),(5,10),(7,12),(6,22),(18,22),(17,12),(19,10),(20,5),(16,3),(12,9)]),
            .open([(12,9),(12,22)]),
        ]
        static let outerwear: [Stroke] = [
            .closed([(8,3),(4,5),(1,17),(5,19),(7,12),(6,22),(18,22),(17,12),(19,19),(23,17),(20,5),(16,3)]),
            .open([(8,3),(12,8),(10,11),(12,13),(12,22)]), .open([(16,3),(12,8),(14,11),(12,13)]),
            .open([(8,16),(10,16)]), .open([(15,16),(17,16)]),
        ]
        static let bottom: [Stroke] = [
            .closed([(7,2),(17,2),(20,22),(14,22),(12,10),(10,22),(4,22)]),
            .open([(7,5),(17,5)]), .open([(12,5),(12,10)]),
        ]
        static let skirt: [Stroke] = [
            .closed([(8,3),(16,3),(21,21),(3,21)]), .open([(8,6),(16,6)]),
            .open([(10,8),(8,19)]), .open([(14,8),(16,19)]),
        ]
        static let shorts: [Stroke] = [
            .closed([(6,4),(18,4),(21,19),(14,19),(12,12),(10,19),(3,19)]),
            .open([(6,7),(18,7)]), .open([(12,7),(12,12)]),
        ]
        static let dress: [Stroke] = [
            .closed([(8,2),(6,3),(8,9),(8,11),(3,22),(21,22),(16,11),(16,9),(18,3),(16,2),(14,6),(10,6)]),
            .open([(8,11),(16,11)]),
        ]
        static let jumpsuit: [Stroke] = [
            .closed([(8,2),(5,4),(8,10),(6,22),(11,22),(12,14),(13,22),(18,22),(16,10),(19,4),(16,2),(12,6)]),
            .open([(8,10),(16,10)]),
        ]
        static let swimwear: [Stroke] = [
            .closed([(8,2),(5,3),(7,9),(5,17),(9,22),(12,16),(15,22),(19,17),(17,9),(19,3),(16,2),(15,7),(12,9),(9,7)]),
        ]
        static let underwear: [Stroke] = [
            .closed([(3,6),(21,6),(19,13),(14,20),(10,20),(5,13)]),
            .open([(3,9),(21,9)]), .open([(5,13),(10,13),(12,16),(14,13),(19,13)]),
        ]
        static let shoes: [Stroke] = [
            .closed([(3,8),(7,11),(12,10),(17,14),(21,15),(22,18),(20,20),(3,20),(2,17)]),
            .open([(3,17),(10,17),(14,18),(22,18)]), .open([(12,10),(11,14),(16,15)]),
        ]
        static let sneakers: [Stroke] = [
            .closed([(3,5),(8,8),(10,11),(15,10),(18,14),(22,15),(23,19),(21,21),(3,21),(1,18)]),
            .open([(2,17),(9,17),(13,18),(23,18)]), .open([(11,12),(15,13)]), .open([(13,10),(17,11)]),
        ]
        static let boots: [Stroke] = [
            .closed([(5,2),(15,2),(14,12),(18,15),(22,16),(22,20),(19,22),(10,22),(10,20),(4,20),(4,15)]),
            .open([(5,5),(15,5)]), .open([(4,18),(22,18)]),
        ]
        static let sandals: [Stroke] = [
            .rounded(.init(x: 5,y: 2,width: 13,height: 20),5),
            .open([(6,7),(16,15)]), .open([(17,7),(7,15)]), .open([(6,18),(17,18)]),
        ]
        static let heels: [Stroke] = [
            .closed([(3,7),(7,7),(9,13),(16,17),(21,17),(22,20),(12,20),(7,15),(6,22),(3,22)]),
            .open([(3,10),(7,10)]),
        ]
        static let socks: [Stroke] = [
            .closed([(10,2),(18,2),(18,14),(16,19),(8,23),(4,21),(3,17),(10,12)]),
            .open([(10,6),(18,6)]), .open([(10,12),(14,16)]),
        ]
        static let tights: [Stroke] = [
            .closed([(7,2),(17,2),(18,10),(18,19),(21,21),(19,23),(14,21),(12,11),(10,21),(5,23),(3,21),(6,19),(6,10)]),
            .open([(7,5),(17,5)]),
        ]
        static let bag: [Stroke] = [
            .rounded(.init(x: 3,y: 9,width: 18,height: 13),2),
            .open([(8,11),(8,6),(9,3),(15,3),(16,6),(16,11)]),
        ]
        static let backpack: [Stroke] = [
            .rounded(.init(x: 5,y: 5,width: 14,height: 17),4),
            .open([(9,5),(9,2),(15,2),(15,5)]),
            .rounded(.init(x: 8,y: 13,width: 8,height: 6),1), .open([(8,15),(16,15)]),
            .open([(5,10),(2,10),(2,19),(5,19)]), .open([(19,10),(22,10),(22,19),(19,19)]),
        ]
        static let clutch: [Stroke] = [
            .rounded(.init(x: 2,y: 6,width: 20,height: 13),2),
            .open([(3,7),(12,14),(21,7)]), .rounded(.init(x: 10,y: 12,width: 4,height: 4),1),
        ]
        static let eyewear: [Stroke] = [
            .rounded(.init(x: 2,y: 9,width: 8,height: 7),2), .rounded(.init(x: 14,y: 9,width: 8,height: 7),2),
            .open([(10,11),(12,10),(14,11)]), .open([(2,10),(1,6)]), .open([(22,10),(23,6)]),
        ]
        static let headwear: [Stroke] = [
            .open([(3,15),(3,11),(5,6),(9,4),(14,5),(17,8),(18,13)]),
            .closed([(2,15),(12,13),(18,13),(23,16),(19,18),(12,17),(2,17)]),
            .open([(11,5),(12,13)]),
        ]
        static let hat: [Stroke] = [
            .closed([(7,4),(10,3),(14,3),(17,4),(18,15),(6,15)]),
            .oval(.init(x: 1,y: 14,width: 22,height: 6)), .open([(7,12),(17,12)]),
        ]
        static let beanie: [Stroke] = [
            .open([(5,16),(5,9),(7,5),(10,3),(14,3),(17,5),(19,9),(19,16)]),
            .rounded(.init(x: 3,y: 15,width: 18,height: 6),1),
            .open([(9,5),(8,14)]), .open([(15,5),(16,14)]),
        ]
        static let scarf: [Stroke] = [
            .rounded(.init(x: 5,y: 2,width: 14,height: 7),2),
            .closed([(7,9),(12,9),(10,22),(5,21)]), .closed([(12,9),(17,9),(20,19),(15,21)]),
            .open([(6,18),(10,19)]), .open([(15,18),(19,16)]),
        ]
        static let belt: [Stroke] = [
            .rounded(.init(x: 2,y: 8,width: 20,height: 8),2),
            .rounded(.init(x: 8,y: 6,width: 7,height: 12),1), .open([(12,12),(17,12)]),
        ]
        static let gloves: [Stroke] = [
            .closed([(7,22),(6,17),(2,12),(2,10),(4,9),(7,12),(6,5),(7,4),(9,5),(9,10),(9,2),(11,2),(12,10),(13,3),(15,3),(15,11),(17,5),(19,6),(18,16),(16,22)]),
            .open([(7,19),(17,19)]),
        ]
        static let watch: [Stroke] = [
            .rounded(.init(x: 6,y: 7,width: 12,height: 10),3),
            .open([(9,7),(9,2),(15,2),(15,7)]), .open([(9,17),(9,22),(15,22),(15,17)]),
            .open([(12,10),(12,12),(15,13)]), .open([(18,11),(20,11),(20,13),(18,13)]),
        ]
        static let necklace: [Stroke] = [
            .open([(4,3),(3,8),(5,14),(9,18),(12,19),(15,18),(19,14),(21,8),(20,3)]),
            .closed([(12,18),(15,21),(12,23),(9,21)]),
        ]
        static let earrings: [Stroke] = [
            .oval(.init(x: 4,y: 2,width: 3,height: 3)), .oval(.init(x: 17,y: 2,width: 3,height: 3)),
            .oval(.init(x: 1,y: 6,width: 9,height: 15)), .oval(.init(x: 14,y: 6,width: 9,height: 15)),
        ]
        static let bracelet: [Stroke] = [
            .oval(.init(x: 3,y: 3,width: 18,height: 18)), .oval(.init(x: 6,y: 6,width: 12,height: 12)),
            .closed([(16,3),(20,2),(23,6),(19,8)]),
        ]
        static let ring: [Stroke] = [
            .oval(.init(x: 5,y: 8,width: 14,height: 14)),
            .closed([(8,2),(16,2),(18,5),(12,10),(6,5)]), .open([(6,5),(18,5)]),
        ]
        static let tie: [Stroke] = [
            .closed([(9,2),(15,2),(16,5),(13,8),(16,19),(12,23),(8,19),(11,8),(8,5)]),
            .open([(11,8),(13,8)]),
        ]
        static let bowtie: [Stroke] = [
            .closed([(2,5),(10,10),(14,10),(22,5),(22,19),(14,14),(10,14),(2,19)]),
            .rounded(.init(x: 10,y: 9,width: 4,height: 6),1),
        ]
        static let hairclip: [Stroke] = [
            .rounded(.init(x: 2,y: 7,width: 20,height: 10),5),
            .open([(7,10),(18,10),(18,14),(7,14)]), .open([(5,9),(5,15)]),
        ]
        static let brooch: [Stroke] = [
            .closed([(12,2),(15,7),(21,8),(17,13),(18,20),(12,17),(6,20),(7,13),(3,8),(9,7)]),
            .oval(.init(x: 10,y: 9,width: 4,height: 4)),
        ]
        static let umbrella: [Stroke] = [
            .closed([(2,12),(4,6),(8,3),(16,3),(20,6),(22,12)]),
            .open([(12,2),(12,19),(14,22),(17,22),(19,20)]),
            .open([(12,3),(9,6),(8,12)]), .open([(12,3),(15,6),(16,12)]),
        ]
        static let accessory: [Stroke] = [
            .closed([(3,3),(12,3),(22,13),(13,22),(3,12)]), .oval(.init(x: 6,y: 6,width: 3,height: 3)),
        ]
    }
}
