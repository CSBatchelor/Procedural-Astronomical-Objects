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

@export var base_resolution := 3 :
	set(value):
		base_resolution = value
		regenerate_mesh()
@export var max_resolution := 6 :
	set(value):
		max_resolution = value
		regenerate_mesh()
@export var focus_point := Vector3.ZERO :
	set(value):
		focus_point = value
		regenerate_mesh()

var material : Material = load("res://astronomical_object_shader_material.tres")
var vertex_lookup : Dictionary[Vector3, int] = {}
var mesh_rid : RID
var instance_rid : RID
var chunks_lookup : Dictionary[String, MeshInstance3D] = {}
var current_chunks_lookup : Dictionary[String, bool] = {}

func _ready() -> void:
	regenerate_mesh()
	
func regenerate_mesh() -> void:
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
		generate_quadtree_plane(normal)

func generate_quadtree_plane(normal := Vector3.ZERO) -> void:
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
	var binormal := Vector3(normal.z, normal.x, normal.y)
	var tangent := binormal.rotated(normal, PI / 2.0)
	# Position is bottom-left corner of the plane
	# Dividing by 2 ensures the cube will be centered
	var pos := normal/2 - binormal/2 - tangent/2
	var size := normal/2 + binormal + tangent
	var bounds := AABB(pos, size)
	var starting_depth := -(abs(base_resolution) as int)
	var max_depth := max_resolution - starting_depth 
	var quadtree_chunk := QuadtreeChunk.new(normal, binormal, tangent, bounds, starting_depth, max_depth)
	
	quadtree_chunk.subdivide(focus_point)
	
	visualize_quadtree(quadtree_chunk)

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
	var max_chunk_depth : int
	var identifier : String
	
	func _init(
		_normal : Vector3,
		_binormal : Vector3,
		_tangent : Vector3,
		_bounds : AABB,
		_depth : int,
		_max_chunk_depth : int
	) -> void:
		normal = _normal
		binormal = _binormal
		tangent = _tangent
		bounds = _bounds
		depth = _depth
		max_chunk_depth = _max_chunk_depth
		identifier = generate_identifier()
		
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
		
		for child_position in child_positions:
			var child_center_3d := child_position + binormal * quarter_size + tangent * quarter_size
			var distance := child_center_3d.normalized().distance_to(focus_point.normalized())
			var child_bounds := AABB(child_position, half_extents)
			var new_child := QuadtreeChunk.new(normal, binormal, tangent, child_bounds, depth+1, max_chunk_depth)
			
			# Threshold needs to be in chord-distance units on unit sphere
			# We multiply by local_size.x to ensure that
			# larger chunks have a larger threshold, otherwise
			# chunks that are further away will not be subdivided
			# to the same degree.
			var threshold := local_size.x * 2.0
			children.append(new_child)
			if depth < 0 or (depth < max_chunk_depth and distance < threshold):
				new_child.subdivide(focus_point)
	
func visualize_quadtree(quadtree_chunk : QuadtreeChunk) -> void:
	# If this chunk has children, we only want to render the children
	# as they make up the geometry of the parent chunk.
	if quadtree_chunk.children:
		for child in quadtree_chunk.children:
			visualize_quadtree(child)
		return
		
	# Here we mark this chunk as rendered this frame
	current_chunks_lookup[quadtree_chunk.identifier] = true
	
	# If we already have a mesh instance of this chunk,
	# then don't need to re-create it.
	if chunks_lookup.has(quadtree_chunk.identifier):
		return
	
	# At this point, the chunk has no children and we do not have a
	# mesh instance for it yet, so we create one.
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
	var verts := PackedVector3Array([
		pos,
		pos + size_y,
		pos + size_x + size_y,
		pos + size_x,
	])
	
	var indicies := PackedInt32Array([
		0,1,2, # First triangle
		0,2,3, # Second triangle
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indicies
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# We are creating a single mesh instance for each plane.
	# This is very ineficient as it results in many draw calls.
	# We will use MultiMeshInstance3D in the near future.
	var mi := MeshInstance3D.new()
	mi.set_mesh(mesh)
	mi.material_override = material
	add_child(mi)
	chunks_lookup[quadtree_chunk.identifier] = mi
