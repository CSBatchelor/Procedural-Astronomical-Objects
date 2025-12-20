shader_type spatial;

void vertex() {
    // Create a sphere by normalizing a cube's vertices:
	//
	//        CUBE                           SPHERE
	//
	//        ┌───────┐                      ╭───╮
	//       ╱       ╱│                    ╱       ╲
	//      ┌───────┐ │   normalize()    ╱           ╲
	//      │       │ │  ───────────→   (             )
	//      │       │╱                   ╲           ╱
	//      └───────┘                      ╲       ╱
	//                                       ╰───╯
	//
	//   Each vertex is projected onto a unit sphere, then scaled to radius 0.5:
	//
	//      normalize(VERTX) * 0.5
	//             │             │
	//             │             └─ Scale to radius 0.5
	//             └─ Project onto unit sphere (length = 1)
	//
	//   Corner vertices move inward, edge/face centers stay roughly in place.
	//   Normals point outward from center (same direction as normalized vertex).
	//
	VERTEX = normalize(VERTEX) * 0.5;
}
