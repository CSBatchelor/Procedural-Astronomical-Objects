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

@export var data : AstronomicalObjectData :
	set(value):
		data = value
		if data != null and not data.is_connected("changed", regenerate_meshes):
			data.connect("changed", regenerate_meshes)

var material : Material = load("res://astronomical_object_shader_material.tres")
var chunks_lookup : Dictionary[String, MeshInstance3D] = {}
var current_chunks_lookup : Dictionary[String, bool] = {}

func _ready() -> void:
	regenerate_meshes()

func regenerate_meshes() -> void:
	if not is_inside_tree():
		return
		
	# This lookup will be repopulated each render
	# If the chunk is drawn, it will be in the lookup.
	current_chunks_lookup = {}
	
	generate_cube() # We use a shader to turn this cube into a sphere
	
	for key in chunks_lookup.keys():
		if not current_chunks_lookup.has(key):
			# If the chunk wasn't drawn this render, then we want to remove it.
			# This happens when a chunk's subdivision status changes.
			var mi := chunks_lookup[key]
			chunks_lookup.erase(key)
			remove_child(mi)
			mi.queue_free()
	
func generate_cube() -> void:
	var quadtree_cube := QuadtreeCube.new(data.base_resolution, data.max_resolution, data.focus_point)
	quadtree_cube.generate()
	for face in QuadtreeCube.faces.values():
		var quadtree_chunk := quadtree_cube.face_quadtrees[face]
		visualize_quadtree(quadtree_chunk)

class QuadtreeCube :
	## A cube with 6 faces, each face represented as a quadtree for LOD subdivision:
	##
	##                       +Y (UP)
	##                         │
	##                         │       ╱ +Z (BACK)
	##                         │      ╱
	##                  ┌──────┼─────╱───┐
	##                 ╱│      │    ╱   ╱│
	##                ╱ │      │   ╱   ╱ │
	##               ┌──┼──────┼──╱───┐  │
	##               │  │      │ ╱    │  │
	##               │  │      │╱     │  │
	##   -X (LEFT) ──┼──┼──────●──────┼──┼── +X (RIGHT)
	##               │  │     ╱│      │  │
	##               │  └────╱─┼──────┼──┘
	##               │      ╱  │      │ ╱
	##               │     ╱   │      │╱
	##               └────╱────┼──────┘
	##                   ╱     │
	##             -Z   ╱      │
	##          (FORWARD)      │
	##                        -Y (DOWN)
	##
	##   Face        Normal Direction
	##   ─────       ────────────────
	##   UP          +Y  ( 0,  1,  0)
	##   DOWN        -Y  ( 0, -1,  0)
	##   LEFT        -X  (-1,  0,  0)
	##   RIGHT       +X  ( 1,  0,  0)
	##   FORWARD     -Z  ( 0,  0, -1)
	##   BACK        +Z  ( 0,  0,  1)
	##
	
	enum faces {
		UP,
		DOWN,
		LEFT,
		RIGHT,
		FRONT,
		BACK
	}

	static var _initialized := false
	
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
	# using: pos_3d = binormal * x + tangent * y
	const face_normals: Dictionary[int, Vector3] = {
		faces.UP: Vector3.UP,
		faces.DOWN: Vector3.DOWN,
		faces.LEFT: Vector3.LEFT,
		faces.RIGHT: Vector3.RIGHT,
		faces.FRONT: Vector3.FORWARD,
		faces.BACK: Vector3.BACK
	}

	# Computed in _static_init() using: Vector3(normal.z, normal.x, normal.y)

	static var face_binormals: Dictionary[int, Vector3] = {}
	
	# Computed in _static_init() using: binormal.rotated(normal, PI / 2.0)
	static var face_tangents: Dictionary[int, Vector3] = {}

	# The bottom-left corner position of each face's plane.
	# Computed in _static_init() using: normal/2 - binormal/2 - tangent/2
	#
	#   Example for UP face (looking down at it from above):
	#
	#                   -Z (tangent direction)
	#                       ↑
	#                  ┌────┼────┐
	#                  │    │    │
	#       -X ────────┼────●────┼──────── +X (binormal)
	#                  │  center │
	#         corner → ●────┼────┘
	#                       ↓
	#                      +Z
	#
	static var face_positions: Dictionary[int, Vector3] = {}

	# The size of each face's bounding box.
	# Computed in _static_init() using: normal/2 + binormal + tangent
	static var face_sizes: Dictionary[int, Vector3] = {}

	# The AABB bounds for each face.
	# Computed in _static_init() using: AABB(face_positions[face], face_sizes[face])
	static var face_bounds: Dictionary[int, AABB] = {}

	static func _static_init() -> void:
		if _initialized:
			return
		_initialized = true
		# Reset dictionaries in case they were made read-only in a previous editor session
		face_binormals = {}
		face_tangents = {}
		face_positions = {}
		face_sizes = {}
		face_bounds = {}
		for face in faces.values():
			var normal := face_normals[face]
			# Cyclic permutation creates a perpendicular vector on the face
			var binormal := Vector3(normal.z, normal.x, normal.y)
			# Rotate 90° around normal to get the other perpendicular axis
			var tangent := binormal.rotated(normal, PI / 2.0)
			
			face_binormals[face] = binormal
			face_tangents[face] = tangent
			face_positions[face] = normal/2 - binormal/2 - tangent/2
			face_sizes[face] = normal/2 + binormal + tangent
			face_bounds[face] = AABB(face_positions[face], face_sizes[face])
		
		face_normals.make_read_only()
		face_binormals.make_read_only()
		face_tangents.make_read_only()
		face_positions.make_read_only()
		face_sizes.make_read_only()
		face_bounds.make_read_only()

	var min_depth : int
	var max_depth : int
	var focus_point : Vector3
	var face_quadtrees : Dictionary[int, QuadtreeChunk] = {}

	func _init(_min_depth : int, _max_depth : int, _focus_point : Vector3) -> void:
		min_depth = _min_depth
		max_depth = _max_depth
		focus_point = _focus_point
	
	func generate() -> void:
		for face in faces.values():
			_generate_face(face)
	
	func _generate_face(face : int) -> void:
		var quadtree_chunk := QuadtreeChunk.new(
			face_normals[face],
			face_binormals[face],
			face_tangents[face],
			face_bounds[face],
			0,
			min_depth,
			max_depth,
			"%s-" % [face]
		)
		quadtree_chunk.subdivide(focus_point)
		face_quadtrees[face] = quadtree_chunk

class QuadtreeChunk :
	## A quadtree is a tree where each node has exactly 0 or 4 children.
	##
	## Structure:
	##
	##                    ┌───────────────────┐
	##                    │       Root        │  depth = 0
	##                    │     (1 chunk)     │
	##                    └─────────┬─────────┘
	##            ┌─────────┬───────┴───────┬─────────┐
	##            ▼         ▼               ▼         ▼
	##        ┌───────┐ ┌───────┐       ┌───────┐ ┌───────┐
	##        │ Child │ │ Child │       │ Child │ │ Child │  depth = 1
	##        └───┬───┘ └───────┘       └───────┘ └───┬───┘
	##     ┌──┬──┬┴─┐                           ┌──┬──┴┬──┐
	##     ▼  ▼  ▼  ▼                           ▼  ▼   ▼  ▼
	##    ┌─┐┌─┐┌─┐┌─┐                         ┌─┐┌─┐┌─┐┌─┐  depth = 2
	##    └─┘└─┘└─┘└─┘                         └─┘└─┘└─┘└─┘
	##
	## We use a quadtree to subdivide the cube into smaller chunks,
	## increasing the detail of the mesh where the focus point is.
	##
	var normal : Vector3
	var binormal : Vector3
	var tangent : Vector3
	var bounds : AABB
	var children : Array[QuadtreeChunk] = []
	var depth : int
	var min_chunk_depth : int
	var max_chunk_depth : int
	var identifier : String
	var location_code : String
	
	func _init(
		_normal : Vector3,
		_binormal : Vector3,
		_tangent : Vector3,
		_bounds : AABB,
		_depth : int,
		_min_chunk_depth : int,
		_max_chunk_depth : int,
		_location_code : String = ""
	) -> void:
		normal = _normal
		binormal = _binormal
		tangent = _tangent
		bounds = _bounds
		depth = _depth
		min_chunk_depth = _min_chunk_depth
		max_chunk_depth = _max_chunk_depth
		identifier = generate_identifier()
		location_code = _location_code
		
	func generate_identifier() -> String:
		return "%s_%s_%s_%d" % [normal, bounds.position, bounds.size, depth]
		
	func subdivide(focus_point : Vector3) -> void:
		# Subdivides this chunk into 4 child quadrants:
		#
		#                   tangent
		#                      ↑
		#        ┌─────────────┼─────────────┐
		#        │             │             │
		#        │   Child 2   │   Child 3   │
		#        │  top-left   │  top-right  │
		#        │      ●      │      ●      │  ● = child center (quarter_size from corner)
		#        │             │             │
		#        ├─────────────┼─────────────┤ ← half_size
		#        │             │             │
		#        │   Child 0   │   Child 1   │
		#        │ bottom-left │bottom-right │
		#        │      ●      │      ●      │
		#        │             │             │
		#        └─────────────┴─────────────┘──→ binormal
		#        ↑             ↑
		#   bounds.position    half_size
		#
		#   Each child's bounds.position starts at its bottom-left corner.
		#   Child centers are used for LOD distance checks against focus_point.
		#
		var local_size := Vector2(bounds.size.dot(binormal), bounds.size.dot(tangent))
		var half_size := local_size.x * 0.5
		var quarter_size := local_size.x * 0.25
		var half_extents := normal/2 + binormal * half_size + tangent * half_size
		var child_positions : Array[Vector3] = [
			bounds.position,                                              # bottom-left
			bounds.position + binormal * half_size,                       # bottom-right
			bounds.position + tangent * half_size + binormal * half_size, # top-left
			bounds.position + tangent * half_size,                        # top-right
		]
		
		for i in child_positions.size():
			var child_position := child_positions[i]
			var child_center_3d := child_position + binormal * quarter_size + tangent * quarter_size
			var distance := child_center_3d.normalized().distance_to(focus_point)
			var child_bounds := AABB(child_position, half_extents)
			var new_child := QuadtreeChunk.new(
				normal,
				binormal,
				tangent,
				child_bounds,
				depth+1,
				min_chunk_depth,
				max_chunk_depth,
				location_code + "%s" % [i]
			)

			# Threshold needs to be in chord-distance units on unit sphere
			# We multiply by local_size.x to ensure that
			# larger chunks have a larger threshold, otherwise
			# chunks that are further away will not be subdivided
			# to the same degree.
			var threshold := local_size.x * 2.0
			children.append(new_child)
			if depth < min_chunk_depth  or (depth < max_chunk_depth and distance < threshold):
				new_child.subdivide(focus_point)
			
			# We want a parent chunk's identifier to include it's children's identifiers
			# so we can  know if we need to discard a mesh becuase it's children changed.
			identifier = identifier + " " + new_child.identifier

func visualize_quadtree(quadtree_chunk : QuadtreeChunk) -> void:
	if quadtree_chunk.depth < data.chunk_resolution:
		# Keep going until we are at the chunk resolution
		for child in quadtree_chunk.children:
			visualize_quadtree(child)
		return

	# Mark this chunk as being drawn this render.
	current_chunks_lookup[quadtree_chunk.identifier] = true
	
	# If we've already have a mesh for this chunk, don't create a new one.
	if chunks_lookup.has(quadtree_chunk.identifier):
		return
	# Create a single mesh instance for this chunk, including all of it's children.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	
	var vertex_lookup : Dictionary[Vector3, int] = {}
	
	construct_chunk_mesh(quadtree_chunk, arrays, vertex_lookup)
	
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	chunks_lookup[quadtree_chunk.identifier] = mesh_instance
	add_child(mesh_instance)

func construct_chunk_mesh(
	quadtree_chunk : QuadtreeChunk,
	arrays: Array,
	vertex_lookup : Dictionary[Vector3, int]
) -> void:
	# If this chunk has children, we only want to render the children
	# as they make up the geometry of the parent chunk.
	if quadtree_chunk.children:
		for child in quadtree_chunk.children:
			construct_chunk_mesh(child, arrays, vertex_lookup)
		return

	var index_offset := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var binormal := quadtree_chunk.binormal
	var tangent := quadtree_chunk.tangent
	var pos := quadtree_chunk.bounds.position
	var size_x := binormal * quadtree_chunk.bounds.size.dot(binormal)
	var size_y := tangent * quadtree_chunk.bounds.size.dot(tangent)
	
	# Each subdivision is a quad made of 4 vertices and 2 triangles:
	#
	#        tangent
	#           ↑
	#     v1 ───────── v2        Vertex positions:
	#      │ ╲       │             v0 = bottom-left  (origin of quad)
	#      │   ╲   2 │             v1 = top-left     (+size_y)
	#      │ 1   ╲   │             v2 = top-right    (+size_x +size_y)
	#      │       ╲ │             v3 = bottom-right (+size_x)
	#     v0 ───────── v3
	#                   → binormal
	#
	#        Triangle 1: v0 → v1 → v2
	#        Triangle 2: v0 → v2 → v3
	#
	# Normalizing the vectors curves the plane so the planes form a sphere,
	# then halfing it so the sphere has a diameter of 1 meter.
	#
	var needed_verts := PackedVector3Array([
		pos.normalized() * 0.5,
		(pos + size_y).normalized() * 0.5,
		(pos + size_x + size_y).normalized() * 0.5,
		(pos + size_x).normalized() * 0.5,
	])
	
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
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for vert in needed_verts:
		if vertex_lookup.has(vert):
			continue
		
		vertex_lookup[vert] = index_offset
		index_offset += 1 
		verts.append(vert)
		norms.append(vert.normalized())
	
	var indicies := PackedInt32Array([
		# First triangle
		vertex_lookup[needed_verts[0]], 
		vertex_lookup[needed_verts[1]],
		vertex_lookup[needed_verts[2]], 
		
		# Second triangle
		vertex_lookup[needed_verts[0]],
		vertex_lookup[needed_verts[2]], 
		vertex_lookup[needed_verts[3]] 
	])

	arrays[Mesh.ARRAY_VERTEX] = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array) + verts
	arrays[Mesh.ARRAY_NORMAL] = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array) + norms
	arrays[Mesh.ARRAY_INDEX] = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array) + indicies
