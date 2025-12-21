@tool
extends Resource
class_name AstronomicalObjectData

## Chunk resolution controls how the overall mesh is chunked.
## The where ve 6 * 4^n chunks where n is the chunk resolution.
## This value cannot be less than 0 since the sphere algorithm
## Will always make 6 planes as a minimum. And it can not go higher
## than the base_resolution, as it controls the maximum size of
## a sbdivided plane.
@export var chunk_resolution := 3 :
	set(value):
		chunk_resolution = clamp(value, 0, base_resolution)
		emit_changed()

## Base resolution controls the maximum size of
## a subdivided plane. Higher values mean more subdivisions, resulting in
## a more vetecies and primitives, or put another way, a more detailed object.
## it can not be less than the chunk resolution since it controlls the maximum
## size of a subdivided plane. And it can not go beyond the max resolution for
## obvious reasons.
@export var base_resolution := 3 :
	set(value):
		base_resolution = clamp(value, chunk_resolution, max_resolution)
		emit_changed()

## Max resolution controlls the maximum depth a plane can be subdivided into.
## This will be used to make the part of the object closest to the focus point
## as detailed as possible. It can not be set below the base resolution for
## obvious reasons.
@export var max_resolution := 6 :
	set(value):
		max_resolution = max(value, base_resolution)
		emit_changed()

## The focus point is the location on the object that we want to render at the
## highest resolution. In the future, this will be where the player is located.
## Right now, the value is normalized so it is always on the surface, for
## testing purposes.
@export var focus_point := Vector3.ZERO :
	set(value):
		focus_point = value.normalized()
		emit_changed()
