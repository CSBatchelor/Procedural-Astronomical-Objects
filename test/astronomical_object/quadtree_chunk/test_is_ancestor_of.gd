extends GutTest
## Tests for QuadtreeChunk.is_ancestor_of()
##
## Quadtree Structure Used in Tests:
##
##   Quadrant layout per node:
##     +-----+-----+
##     |  2  |  3  |  (TOP_LEFT, TOP_RIGHT)
##     +-----+-----+
##     |  0  |  1  |  (BOTTOM_LEFT, BOTTOM_RIGHT)
##     +-----+-----+
##
##   Tree hierarchy:
##                           root (depth 0)
##                    /      |      |      \
##               child0  child1  child2  child3   (depth 1)
##             /  |  |  \
##          gc0 gc1 gc2 gc3                       (depth 2, grandchildren of root via child0)
##


func create_chunk(location_code: String, depth: int = 0) -> AstronomicalObject.QuadtreeChunk:
	## Helper to create a QuadtreeChunk with minimal required parameters.
	return AstronomicalObject.QuadtreeChunk.new(
		Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, # normal, binormal, tangent
		AABB(Vector3.ZERO, Vector3.ONE),            # bounds
		depth,                                       # depth
		0, 10,                                       # min/max depth
		location_code
	)


func create_quadtree_with_depth_2() -> Dictionary:
	## Helper to create a quadtree with 2 levels of depth.
	## Returns a dictionary with all nodes for easy access in tests.
	## Root has 4 children, and child0 has 4 grandchildren.
	var root := create_chunk("0", 0)
	
	# 4 children at depth 1 (quadrants 0, 1, 2, 3)
	var child0 := create_chunk("00", 1)
	var child1 := create_chunk("01", 1)
	var child2 := create_chunk("02", 1)
	var child3 := create_chunk("03", 1)
	
	# 4 grandchildren at depth 2 (under child0)
	var grandchild0 := create_chunk("000", 2)
	var grandchild1 := create_chunk("001", 2)
	var grandchild2 := create_chunk("002", 2)
	var grandchild3 := create_chunk("003", 2)
	
	# Build hierarchy - root has 4 children
	root.children.append(child0)
	root.children.append(child1)
	root.children.append(child2)
	root.children.append(child3)
	
	# child0 has 4 grandchildren
	child0.children.append(grandchild0)
	child0.children.append(grandchild1)
	child0.children.append(grandchild2)
	child0.children.append(grandchild3)
	
	return {
		"root": root,
		"child0": child0,
		"child1": child1,
		"child2": child2,
		"child3": child3,
		"grandchild0": grandchild0,
		"grandchild1": grandchild1,
		"grandchild2": grandchild2,
		"grandchild3": grandchild3,
	}


# =============================================================================
# Self-ancestry tests
# =============================================================================
func test_chunk_is_ancestor_of_itself() -> void:
	# Arrange
	var chunk := create_chunk("0")
	
	# Act
	var result := chunk.is_ancestor_of(chunk)
	
	# Assert
	assert_true(result, "A chunk should be considered an ancestor of itself")


func test_leaf_chunk_is_ancestor_of_itself() -> void:
	# Arrange
	var tree := create_quadtree_with_depth_2()
	var grandchild := tree["grandchild0"] as AstronomicalObject.QuadtreeChunk
	
	# Act
	var result := grandchild.is_ancestor_of(grandchild)
	
	# Assert
	assert_true(result, "A leaf chunk should be considered an ancestor of itself")


# =============================================================================
# Direct parent-child relationship tests
# =============================================================================
func test_parent_is_ancestor_of_direct_child() -> void:
	# Arrange
	var tree := create_quadtree_with_depth_2()
	var root := tree["root"] as AstronomicalObject.QuadtreeChunk
	var child0 := tree["child0"] as AstronomicalObject.QuadtreeChunk
	
	# Act
	var result := root.is_ancestor_of(child0)
	
	# Assert
	assert_true(result, "Parent should be an ancestor of its direct child")


func test_parent_is_ancestor_of_all_four_children() -> void:
	# Arrange
	var tree := create_quadtree_with_depth_2()
	var root := tree["root"] as AstronomicalObject.QuadtreeChunk
	var child0 := tree["child0"] as AstronomicalObject.QuadtreeChunk
	var child1 := tree["child1"] as AstronomicalObject.QuadtreeChunk
	var child2 := tree["child2"] as AstronomicalObject.QuadtreeChunk
	var child3 := tree["child3"] as AstronomicalObject.QuadtreeChunk
	
	# Act
	var result0 := root.is_ancestor_of(child0)
	var result1 := root.is_ancestor_of(child1)
	var result2 := root.is_ancestor_of(child2)
	var result3 := root.is_ancestor_of(child3)
	
	# Assert
	assert_true(result0, "Parent should be an ancestor of child in quadrant 0 (bottom-left)")
	assert_true(result1, "Parent should be an ancestor of child in quadrant 1 (bottom-right)")
	assert_true(result2, "Parent should be an ancestor of child in quadrant 2 (top-left)")
	assert_true(result3, "Parent should be an ancestor of child in quadrant 3 (top-right)")


# =============================================================================
# Grandparent-grandchild relationship tests
# =============================================================================
func test_root_is_ancestor_of_grandchild() -> void:
	# Arrange
	var tree := create_quadtree_with_depth_2()
	var root := tree["root"] as AstronomicalObject.QuadtreeChunk
	var grandchild0 := tree["grandchild0"] as AstronomicalObject.QuadtreeChunk
	
	# Act
	var result := root.is_ancestor_of(grandchild0)
	
	# Assert
	assert_true(result, "Root should be an ancestor of its grandchild")


func test_root_is_ancestor_of_all_four_grandchildren() -> void:
	# Arrange
	var tree := create_quadtree_with_depth_2()
	var root := tree["root"] as AstronomicalObject.QuadtreeChunk
	var grandchild0 := tree["grandchild0"] as AstronomicalObject.QuadtreeChunk
	var grandchild1 := tree["grandchild1"] as AstronomicalObject.QuadtreeChunk
	var grandchild2 := tree["grandchild2"] as AstronomicalObject.QuadtreeChunk
	var grandchild3 := tree["grandchild3"] as AstronomicalObject.QuadtreeChunk
	
	# Act
	var result0 := root.is_ancestor_of(grandchild0)
	var result1 := root.is_ancestor_of(grandchild1)
	var result2 := root.is_ancestor_of(grandchild2)
	var result3 := root.is_ancestor_of(grandchild3)
	
	# Assert
	assert_true(result0, "Root should be an ancestor of grandchild in quadrant 0")
	assert_true(result1, "Root should be an ancestor of grandchild in quadrant 1")
	assert_true(result2, "Root should be an ancestor of grandchild in quadrant 2")
	assert_true(result3, "Root should be an ancestor of grandchild in quadrant 3")


func test_intermediate_node_is_ancestor_of_all_four_children() -> void:
	# Arrange
	var tree := create_quadtree_with_depth_2()
	var child0 := tree["child0"] as AstronomicalObject.QuadtreeChunk
	var grandchild0 := tree["grandchild0"] as AstronomicalObject.QuadtreeChunk
	var grandchild1 := tree["grandchild1"] as AstronomicalObject.QuadtreeChunk
	var grandchild2 := tree["grandchild2"] as AstronomicalObject.QuadtreeChunk
	var grandchild3 := tree["grandchild3"] as AstronomicalObject.QuadtreeChunk
	
	# Act
	var result0 := child0.is_ancestor_of(grandchild0)
	var result1 := child0.is_ancestor_of(grandchild1)
	var result2 := child0.is_ancestor_of(grandchild2)
	var result3 := child0.is_ancestor_of(grandchild3)
	
	# Assert
	assert_true(result0, "Intermediate node should be ancestor of child in quadrant 0")
	assert_true(result1, "Intermediate node should be ancestor of child in quadrant 1")
	assert_true(result2, "Intermediate node should be ancestor of child in quadrant 2")
	assert_true(result3, "Intermediate node should be ancestor of child in quadrant 3")


# =============================================================================
# Non-ancestry tests (negative cases)
# =============================================================================
func test_child_is_not_ancestor_of_parent() -> void:
	# Arrange
	var tree := create_quadtree_with_depth_2()
	var root := tree["root"] as AstronomicalObject.QuadtreeChunk
	var child0 := tree["child0"] as AstronomicalObject.QuadtreeChunk
	
	# Act
	var result := child0.is_ancestor_of(root)
	
	# Assert
	assert_false(result, "Child should NOT be an ancestor of its parent")


func test_grandchild_is_not_ancestor_of_grandparent() -> void:
	# Arrange
	var tree := create_quadtree_with_depth_2()
	var root := tree["root"] as AstronomicalObject.QuadtreeChunk
	var grandchild0 := tree["grandchild0"] as AstronomicalObject.QuadtreeChunk
	
	# Act
	var result := grandchild0.is_ancestor_of(root)
	
	# Assert
	assert_false(result, "Grandchild should NOT be an ancestor of its grandparent")


func test_sibling_is_not_ancestor_of_sibling() -> void:
	# Arrange
	var tree := create_quadtree_with_depth_2()
	var child0 := tree["child0"] as AstronomicalObject.QuadtreeChunk
	var child1 := tree["child1"] as AstronomicalObject.QuadtreeChunk
	var child2 := tree["child2"] as AstronomicalObject.QuadtreeChunk
	var child3 := tree["child3"] as AstronomicalObject.QuadtreeChunk
	
	# Act & Assert - test multiple sibling pairs
	assert_false(child0.is_ancestor_of(child1), "Sibling 0 should NOT be ancestor of sibling 1")
	assert_false(child0.is_ancestor_of(child2), "Sibling 0 should NOT be ancestor of sibling 2")
	assert_false(child0.is_ancestor_of(child3), "Sibling 0 should NOT be ancestor of sibling 3")
	assert_false(child2.is_ancestor_of(child3), "Sibling 2 should NOT be ancestor of sibling 3")


func test_cousin_is_not_ancestor_of_cousin() -> void:
	# Arrange
	# Create a tree where child1 also has 4 grandchildren (cousins to grandchild0)
	var tree := create_quadtree_with_depth_2()
	var child1 := tree["child1"] as AstronomicalObject.QuadtreeChunk
	var grandchild0 := tree["grandchild0"] as AstronomicalObject.QuadtreeChunk
	var cousin0 := create_chunk("010", 2)
	var cousin1 := create_chunk("011", 2)
	var cousin2 := create_chunk("012", 2)
	var cousin3 := create_chunk("013", 2)
	child1.children.append(cousin0)
	child1.children.append(cousin1)
	child1.children.append(cousin2)
	child1.children.append(cousin3)
	
	# Act & Assert
	assert_false(grandchild0.is_ancestor_of(cousin0), "Cousin should NOT be ancestor of another cousin")
	assert_false(grandchild0.is_ancestor_of(cousin3), "Cousin should NOT be ancestor of cousin in different quadrant")


func test_unrelated_chunk_is_not_ancestor() -> void:
	# Arrange
	var tree := create_quadtree_with_depth_2()
	var root := tree["root"] as AstronomicalObject.QuadtreeChunk
	var unrelated := create_chunk("1", 0)  # Different root entirely
	
	# Act
	var result := root.is_ancestor_of(unrelated)
	
	# Assert
	assert_false(result, "Chunk should NOT be an ancestor of an unrelated chunk")


# =============================================================================
# Edge cases
# =============================================================================
func test_leaf_with_no_children_is_not_ancestor_of_other_chunk() -> void:
	# Arrange
	var chunk1 := create_chunk("0")
	var chunk2 := create_chunk("1")
	
	# Act
	var result := chunk1.is_ancestor_of(chunk2)
	
	# Assert
	assert_false(result, "Leaf chunk with no children should not be ancestor of unrelated chunk")


func test_node_with_children_but_different_subtree() -> void:
	# Arrange
	# child1, child2, child3 have no children, so grandchild0 is not in their subtrees
	var tree := create_quadtree_with_depth_2()
	var child1 := tree["child1"] as AstronomicalObject.QuadtreeChunk
	var child2 := tree["child2"] as AstronomicalObject.QuadtreeChunk
	var child3 := tree["child3"] as AstronomicalObject.QuadtreeChunk
	var grandchild0 := tree["grandchild0"] as AstronomicalObject.QuadtreeChunk
	
	# Act & Assert
	assert_false(child1.is_ancestor_of(grandchild0), "Node should NOT be ancestor of chunk in different subtree (child1)")
	assert_false(child2.is_ancestor_of(grandchild0), "Node should NOT be ancestor of chunk in different subtree (child2)")
	assert_false(child3.is_ancestor_of(grandchild0), "Node should NOT be ancestor of chunk in different subtree (child3)")

