import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

/// Reorder whole draft values so media identity, transfer state and photo pins travel together.
enum UFitPhotoOrdering {
    static let firstPosition = 0
    static let step = 1
    static let minimumReorderCount = 2
    static let payloadCount = 1

    @discardableResult
    static func move<Photo: Identifiable>(_ photoID: UUID, to destinationID: UUID, in photos: inout [Photo]) -> Bool where Photo.ID == UUID {
        guard photoID != destinationID, let source = photos.firstIndex(where: { $0.id == photoID }),
              let destination = photos.firstIndex(where: { $0.id == destinationID }) else { return false }
        let photo = photos.remove(at: source)
        photos.insert(photo, at: destination)
        return true
    }

    @discardableResult
    static func move<Photo: Identifiable>(_ photoID: UUID, by step: Int, in photos: inout [Photo]) -> Bool where Photo.ID == UUID {
        guard let source = photos.firstIndex(where: { $0.id == photoID }), photos.indices.contains(source + step) else { return false }
        let destinationID = photos[source + step].id
        return move(photoID, to: destinationID, in: &photos)
    }
}

struct UFitPhotoOrderControls: View {
    let photoLabel: String
    let position: Int
    let count: Int
    let onMove: (Int) -> Void
    private enum Copy {
        static let earlier = String(localized: "Déplacer la photo avant")
        static let later = String(localized: "Déplacer la photo après")
        static let separator = " · "
    }
    private enum Icon { static let earlier = "arrow.up"; static let later = "arrow.down" }
    var body: some View {
        if count >= UFitPhotoOrdering.minimumReorderCount {
            VStack(spacing: .zero) {
                UFitButton { onMove(-UFitPhotoOrdering.step) } label: {
                    UFitIcon(systemName: Icon.earlier).font(UFitTypography.icon)
                        .frame(width: UFitControlSize.touch, height: UFitControlSize.touch)
                }.accessibilityLabel(Copy.earlier + Copy.separator + photoLabel).disabled(position == UFitPhotoOrdering.firstPosition)
                UFitButton { onMove(UFitPhotoOrdering.step) } label: {
                    UFitIcon(systemName: Icon.later).font(UFitTypography.icon)
                        .frame(width: UFitControlSize.touch, height: UFitControlSize.touch)
                }.accessibilityLabel(Copy.later + Copy.separator + photoLabel).disabled(position == count - UFitPhotoOrdering.step)
            }.foregroundStyle(Color.ufitSecondaryText).accessibilityElement(children: .contain)
        }
    }
}

private struct UFitPhotoOrderPayload: Codable, Transferable {
    let collectionID: UUID
    let photoID: UUID
    let canReorder: Bool
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json).exportingCondition { $0.canReorder }.visibility(.ownProcess)
    }
}

struct UFitPhotoReorderSource: ViewModifier {
    let photoID: UUID
    let collectionID: UUID
    let count: Int
    @Environment(\.isEnabled) private var isEnabled
    private var canReorder: Bool { isEnabled && count >= UFitPhotoOrdering.minimumReorderCount }
    func body(content: Content) -> some View {
        content.draggable(UFitPhotoOrderPayload(collectionID: collectionID, photoID: photoID, canReorder: canReorder))
    }
}

struct UFitPhotoReorderDestination<Photo: Identifiable>: ViewModifier where Photo.ID == UUID {
    let photoID: UUID
    let collectionID: UUID
    @Binding var photos: [Photo]
    @State private var isTargeted = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var canReorder: Bool { isEnabled && photos.count >= UFitPhotoOrdering.minimumReorderCount }
    func body(content: Content) -> some View {
        content.dropDestination(for: UFitPhotoOrderPayload.self) { payloads, _ in
            isTargeted = false
            guard canReorder, payloads.count == UFitPhotoOrdering.payloadCount,
                  let payload = payloads.first, payload.canReorder, payload.collectionID == collectionID else { return false }
            if reduceMotion { return UFitPhotoOrdering.move(payload.photoID, to: photoID, in: &photos) }
            return withAnimation(.easeInOut(duration: UFitMotion.feedback)) {
                UFitPhotoOrdering.move(payload.photoID, to: photoID, in: &photos)
            }
        } isTargeted: { isTargeted = canReorder && $0 }
        .overlay {
            if isTargeted, canReorder {
                RoundedRectangle(cornerRadius: UFitRadius.field)
                    .strokeBorder(Color.ufitInk, lineWidth: UFitStroke.selected)
                    .allowsHitTesting(false)
            }
        }
    }
}
