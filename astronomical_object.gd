@tool
extends Node3D
class_name AstronomicalObject
## Procedurally generates a sphere mesh from a subdivided cube.
##
## This script creates a sphere by:
##   1. Generating a cube made of 6 planes (one per face)
##   2. Subdividing each plane into a grid of quads (controlled by base_resolution)
##   3. Normalizing all vertices to project the cube onto a sphere
##
## The mesh is built using vertex arrays with indexed triangles, and duplicate
## vertices at shared corners are eliminated using a lookup dictionary.
##
## As an @tool script, the mesh regenerates live in the editor when properties change.

@export var base_resolution := 3:
	set(value):
		base_resolution = value
		regenerate_mesh()

@onready var mesh_instance_3d : MeshInstance3D = $MeshInstance3D

var vertex_lookup : Dictionary[Vector3, int] = {}

func _ready() -> void:
	regenerate_mesh()
	
func regenerate_mesh() -> void:
	var mesh_arrays := generate_mesh_arrays()
	# call_deferred delays apply_mesh_arrays until the end of the current frame.
	# This avoids issues when regenerate_mesh is called from a setter (like base_resolution),
	# where modifying the scene tree immediately could cause errors or unexpected behavior.
	# Especially important for @tool scripts running in the editor.
	call_deferred("apply_mesh_arrays", mesh_arrays)
	
func generate_mesh_arrays() -> Array:
	var mesh_arrays := []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	mesh_arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	mesh_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	vertex_lookup = {}
	
	generate_sphere(mesh_arrays)
	
	return mesh_arrays

func generate_sphere(mesh_arrays : Array) -> void:
	# Create a sphere by normalizing a cube's vertices:
	#
	#       CUBE                           SPHERE
	#
	#        ┌───────┐                      ╭───╮
	#       ╱       ╱│                    ╱       ╲
	#      ┌───────┐ │   normalize()    ╱           ╲
	#      │       │ │  ───────────→   (             )
	#      │       │╱                   ╲           ╱
	#      └───────┘                      ╲       ╱
	#                                       ╰───╯
	#
	#   Each vertex is projected onto a unit sphere, then scaled to radius 0.5:
	#
	#      vertex.normalized() / 2.0
	#             │             │
	#             │             └─ Scale to radius 0.5
	#             └─ Project onto unit sphere (length = 1)
	#
	#   Corner vertices move inward, edge/face centers stay roughly in place.
	#   Normals point outward from center (same direction as normalized vertex).
	#
	generate_cube(mesh_arrays)
	var vertex_array := mesh_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normal_array := mesh_arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	for i in vertex_array.size():
		var vertex := vertex_array[i] as Vector3
		vertex_array[i] = vertex.normalized() / 2.0
		normal_array[i] = vertex.normalized()
	mesh_arrays[Mesh.ARRAY_VERTEX] = vertex_array
	mesh_arrays[Mesh.ARRAY_NORMAL] = normal_array
	
	
func generate_cube(mesh_arrays : Array) -> void:
	# Generate 6 faces of a cube, one plane per face:
	#
	#                       +Y (UP)
	#                         │
	#                         │       ╱ +Z (BACK)
	#                         │      ╱
	#                  ┌──────┼─────╱───┐
	#                 ╱│      │    ╱   ╱│
	#                ╱ │      │   ╱   ╱ │
	#               ┌──┼──────┼──╱───┐  │
	#               │  │      │ ╱    │  │
	#               │  │      │╱     │  │
	#   -X (LEFT) ──┼──┼──────●──────┼──┼── +X (RIGHT)
	#               │  │     ╱│      │  │
	#               │  └────╱─┼──────┼──┘
	#               │      ╱  │      │ ╱
	#               │     ╱   │      │╱
	#               └────╱────┼──────┘
	#                   ╱     │
	#             -Z   ╱      │
	#          (FORWARD)      │
	#                        -Y (DOWN)
	#
	#   Face        Normal Direction
	#   ─────       ────────────────
	#   UP          +Y  ( 0,  1,  0)
	#   DOWN        -Y  ( 0, -1,  0)
	#   LEFT        -X  (-1,  0,  0)
	#   RIGHT       +X  ( 1,  0,  0)
	#   FORWARD     -Z  ( 0,  0, -1)
	#   BACK        +Z  ( 0,  0,  1)
	#
	var sides := PackedVector3Array([
		Vector3.UP,
		Vector3.DOWN,
		Vector3.LEFT,
		Vector3.RIGHT,
		Vector3.FORWARD,
		Vector3.BACK
	])
	for normal in sides:
		generate_plane(normal, mesh_arrays)
	
func generate_plane(
	normal := Vector3.ZERO,
	mesh_arrays := []
) -> void:
	# These three vectors form an orthonormal basis (local coordinate system) for each face:
	#   - Normal:   Points outward from the face (perpendicular to surface)
	#   - Binormal: Lies on the face, acts as the local "X" axis
	#   - Tangent:  Lies on the face, acts as the local "Y" axis (perpendicular to binormal)
	#
	#                     NORMAL (N)
	#                        ↑
	#                        │
	#                        │
	#                        ●───────────→ BINORMAL (B)
	#                       ╱
	#                      ╱
	#                     ↓
	#                TANGENT (T)
	#
	# Together, binormal and tangent allow mapping 2D grid coordinates into 3D space
	# using: subdivision_offset = binormal * x + tangent * y
	# The plane_offset = (-normal + binormal + tangent) / 2 centers the plane around
	# the origin by shifting it back along the normal and centering on the B/T axes.
	var binormal := Vector3(normal.z, normal.x, normal.y)
	var tangent := binormal.rotated(normal, PI / 2.0)
	
	# size is the width/height of each quad in the subdivision grid.
	# The full plane spans 1 unit, so each quad is 1/base_resolution units.
	var size : float = 1.0 / base_resolution
	var vertex_array := mesh_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normal_array := mesh_arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var index_array := mesh_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var index_offset := vertex_array.size()
	# plane_offset centers the plane around the origin:
	#
	#   Before centering:              After centering:
	#   (plane starts at origin)       (plane centered on origin)
	#
	#        tangent                        tangent
	#           ↑                              ↑
	#     ┌─────┬─────┐                  ┌─────┬─────┐
	#     │     │     │                  │     │     │
	#     ├─────┼─────┤                ──┼─────●─────┼──
	#     │     │     │                  │     │     │
	#     ●─────┴─────┘→ binormal        └─────┴─────┘→ binormal
	#     ↑ origin                             ↑ origin
	#     ↓ normal (into page)                 ↓ normal (into page)
	#
	#   -normal/2:    shifts plane backward (away from normal direction)
	#   +binormal/2:  shifts plane left along binormal axis
	#   +tangent/2:   shifts plane down along tangent axis
	#
	var plane_offset := (-normal + binormal + tangent) / 2
	
	for x in base_resolution:
		for y in base_resolution:
			# subdivision_offset positions each quad within the grid:
			#
			#        tangent                 Example with base_resolution = 3:
			#           ↑
			#     ┌─────┬─────┬─────┐        subdivision_offset = binormal * x + tangent * y
			#     │(0,2)│(1,2)│(2,2)│
			#   2 ├─────┼─────┼─────┤        (0,0): 0 steps  →  origin of grid
			#     │(0,1)│(1,1)│(2,1)│        (1,0): 1 binormal step  →  1 right
			#   1 ├─────┼─────┼─────┤        (0,1): 1 tangent step   →  1 up
			#     │(0,0)│(1,0)│(2,0)│        (2,2): 2 binormal + 2 tangent  →  top-right
			#   0 └─────┴─────┴─────┘
			#     0     1     2     → binormal
			#      (x,y) = grid position
			#
			var subdivision_offset := binormal * x + tangent * y
			# Each subdivision is a quad made of 4 vertices and 2 triangles:
			#
			#        tangent
			#           ↑
			#     v1 ───────── v2        Vertex positions:
			#      │ ╲       │             v0 = bottom-left  (origin of quad)
			#      │   ╲   2 │             v1 = top-left     (+tangent)
			#      │ 1   ╲   │             v2 = top-right    (+tangent +binormal)
			#      │       ╲ │             v3 = bottom-right (+binormal)
			#     v0 ───────── v3
			#                   → binormal
			#
			#        Triangle 1: v0 → v1 → v2
			#        Triangle 2: v0 → v2 → v3
			#
			var needed_verticies := PackedVector3Array([
				(subdivision_offset) * size - plane_offset,
				(tangent + subdivision_offset) * size - plane_offset,
				(tangent + binormal + subdivision_offset) * size - plane_offset,
				(binormal + subdivision_offset) * size - plane_offset
			])
			
			for vertex in needed_verticies:
				# vertex_lookup prevents duplicate vertices at shared corners:
				#
				#   Without deduplication:           With deduplication (vertex_lookup):
				#
				#     A───B C───D                      A───B───C
				#     │ 1 │ │ 2 │                      │ 1 │ 2 │
				#     E───F G───H      each quad       D───E───F    shared vertices
				#     I───J K───L      has 4 verts     │ 3 │ 4 │    are reused
				#     │ 3 │ │ 4 │                      G───H───I
				#     M───N O───P
				#
				#     16 vertices total                9 vertices total
				#     (many duplicates!)               (no duplicates)
				#
				#   Example: vertex E above is shared by quads 1, 2, 3, and 4.
				#   Without lookup, we'd create it 4 times. With lookup, just once.
				#
				#   For a 3×3 grid: 36 verts → 16 verts (56% reduction)
				#   For a 10×10 grid: 400 verts → 121 verts (70% reduction)
				#
				if vertex_lookup.has(vertex):
					continue
				
				vertex_lookup[vertex] = index_offset
				index_offset += 1
				vertex_array.append(vertex)
				normal_array.append(normal)

			index_array.append_array(PackedInt32Array([
				# First triangle
				vertex_lookup[needed_verticies[0]],
				vertex_lookup[needed_verticies[1]],
				vertex_lookup[needed_verticies[2]],
				
				# Second triangle
				vertex_lookup[needed_verticies[0]],
				vertex_lookup[needed_verticies[2]],
				vertex_lookup[needed_verticies[3]]
			]))
	
	mesh_arrays[Mesh.ARRAY_VERTEX] = vertex_array
	mesh_arrays[Mesh.ARRAY_NORMAL] = normal_array
	mesh_arrays[Mesh.ARRAY_INDEX] = index_array
	
func apply_mesh_arrays(mesh_arrays: Array) -> void:
	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	mesh_instance_3d.set_mesh(new_mesh)
