extends GutTest
## Tests for QuadtreeChunk.get_neighbor_location_code()
##
## Quadrant Layout:
##   +-----+-----+
##   |  2  |  3  |  (TOP_LEFT, TOP_RIGHT)
##   +-----+-----+
##   |  0  |  1  |  (BOTTOM_LEFT, BOTTOM_RIGHT)
##   +-----+-----+

const Direction = AstronomicalObject.QuadtreeChunk.Direction


func create_chunk(location_code: String) -> AstronomicalObject.QuadtreeChunk:
	## Helper to create a QuadtreeChunk with minimal required parameters.
	return AstronomicalObject.QuadtreeChunk.new(
		Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, # normal, binormal, tangent
		AABB(Vector3.ZERO, Vector3.ONE),            # bounds
		0,                                          # depth
		0, 10,                                      # min/max depth
		location_code
	)


# =============================================================================
# LEFT direction tests
# =============================================================================
func test_left_from_bottom_left_at_root_returns_empty() -> void:
	# Arrange
	var chunk := create_chunk("0")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.LEFT)
	
	# Assert
	assert_eq(result, "", "LEFT from quadrant 0 at root should return empty (needs different face)")

func test_left_from_bottom_right_returns_bottom_left_sibling() -> void:
	# Arrange
	var chunk := create_chunk("1")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.LEFT)
	
	# Assert
	assert_eq(result, "0", "LEFT from quadrant 1 should go to sibling quadrant 0")

func test_left_from_top_left_returns_bottom_right_sibling() -> void:
	# Arrange
	var chunk := create_chunk("2")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.LEFT)
	
	# Assert
	assert_eq(result, "", "LEFT from quadrant 2 should return empty (needs different face)")

func test_left_from_top_right_returns_top_left_sibling() -> void:
	# Arrange
	var chunk := create_chunk("3")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.LEFT)
	
	# Assert
	assert_eq(result, "2", "LEFT from quadrant 3 should go to sibling quadrant 2")


func test_left_from_deep_top_right_returns_sibling() -> void:
	# Arrange
	var chunk := create_chunk("323")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.LEFT)
	
	# Assert
	assert_eq(result, "322", "LEFT from 323 should go to 322 (sibling at same level)")


func test_left_crosses_parent_boundary() -> void:
	# Arrange
	var chunk := create_chunk("30")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.LEFT)
	
	# Assert
	assert_eq(result, "21", "LEFT from 30 should cross to parent's neighbor: 21")

func test_left_crosses_parent_boundary_to_different_face() -> void:
	# Arrange
	var chunk := create_chunk("020")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.LEFT)
	
	# Assert
	assert_eq(result, "", "LEFT from 020 should return empty (needs different face)")


# =============================================================================
# UP direction tests
# =============================================================================
func test_up_from_bottom_left_returns_top_left_sibling() -> void:
	# Arrange
	var chunk := create_chunk("0")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.UP)
	
	# Assert
	assert_eq(result, "2", "UP from quadrant 0 should go to sibling quadrant 2")

func test_up_from_bottom_right_returns_top_right_sibling() -> void:
	# Arrange
	var chunk := create_chunk("1")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.UP)
	
	# Assert
	assert_eq(result, "3", "UP from quadrant 1 should go to sibling quadrant 3")

func test_up_from_top_left_at_root_returns_empty() -> void:
	# Arrange
	var chunk := create_chunk("2")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.UP)
	
	# Assert
	assert_eq(result, "", "UP from quadrant 2 at root should return empty (needs different face)")

func test_up_from_top_right_at_root_returns_empty() -> void:
	# Arrange
	var chunk := create_chunk("3")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.UP)
	
	# Assert
	assert_eq(result, "", "UP from quadrant 3 at root should return empty (needs different face)")

func test_up_from_deep_bottom_right_returns_sibling() -> void:
	# Arrange
	var chunk := create_chunk("321")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.UP)
	
	# Assert
	assert_eq(result, "323", "UP from 321 should go to 323 (sibling at same level)")

func test_up_crosses_parent_boundary() -> void:
	# Arrange
	var chunk := create_chunk("12")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.UP)
	
	# Assert
	assert_eq(result, "30", "UP from 12 should cross to parent's neighbor: 30")

func test_up_crosses_parent_boundary_to_different_face() -> void:
	# Arrange
	var chunk := create_chunk("232")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.UP)
	
	# Assert
	assert_eq(result, "", "UP from 232 should return empty (needs different face)")


# =============================================================================
# RIGHT direction tests
# =============================================================================
func test_right_from_bottom_left_returns_bottom_right_sibling() -> void:
	# Arrange
	var chunk := create_chunk("0")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.RIGHT)
	
	# Assert
	assert_eq(result, "1", "RIGHT from quadrant 0 should go to sibling quadrant 1")

func test_right_from_bottom_right_at_root_returns_empty() -> void:
	# Arrange
	var chunk := create_chunk("1")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.RIGHT)
	
	# Assert
	assert_eq(result, "", "RIGHT from quadrant 1 at root should return empty (needs different face)")

func test_right_from_top_left_returns_top_right_sibling() -> void:
	# Arrange
	var chunk := create_chunk("2")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.RIGHT)
	
	# Assert
	assert_eq(result, "3", "RIGHT from quadrant 2 should go to sibling quadrant 3")

func test_right_from_top_right_at_root_returns_empty() -> void:
	# Arrange
	var chunk := create_chunk("3")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.RIGHT)
	
	# Assert
	assert_eq(result, "", "RIGHT from quadrant 3 at root should return empty (needs different face)")

func test_right_from_deep_bottom_left_returns_sibling() -> void:
	# Arrange
	var chunk := create_chunk("320")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.RIGHT)
	
	# Assert
	assert_eq(result, "321", "RIGHT from 320 should go to 321 (sibling at same level)")

func test_right_crosses_parent_boundary() -> void:
	# Arrange
	var chunk := create_chunk("01")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.RIGHT)
	
	# Assert
	assert_eq(result, "10", "RIGHT from 01 should cross to parent's neighbor: 10")

func test_right_crosses_parent_boundary_to_different_face() -> void:
	# Arrange
	var chunk := create_chunk("131")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.RIGHT)
	
	# Assert
	assert_eq(result, "", "RIGHT from 131 should return empty (needs different face)")


# =============================================================================
# DOWN direction tests
# =============================================================================
func test_down_from_bottom_left_at_root_returns_empty() -> void:
	# Arrange
	var chunk := create_chunk("0")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.DOWN)
	
	# Assert
	assert_eq(result, "", "DOWN from quadrant 0 at root should return empty (needs different face)")

func test_down_from_bottom_right_at_root_returns_empty() -> void:
	# Arrange
	var chunk := create_chunk("1")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.DOWN)
	
	# Assert
	assert_eq(result, "", "DOWN from quadrant 1 at root should return empty (needs different face)")

func test_down_from_top_left_returns_bottom_left_sibling() -> void:
	# Arrange
	var chunk := create_chunk("2")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.DOWN)
	
	# Assert
	assert_eq(result, "0", "DOWN from quadrant 2 should go to sibling quadrant 0")

func test_down_from_top_right_returns_bottom_right_sibling() -> void:
	# Arrange
	var chunk := create_chunk("3")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.DOWN)
	
	# Assert
	assert_eq(result, "1", "DOWN from quadrant 3 should go to sibling quadrant 1")

func test_down_from_deep_top_right_returns_sibling() -> void:
	# Arrange
	var chunk := create_chunk("323")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.DOWN)
	
	# Assert
	assert_eq(result, "321", "DOWN from 323 should go to 321 (sibling at same level)")

func test_down_crosses_parent_boundary() -> void:
	# Arrange
	var chunk := create_chunk("21")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.DOWN)
	
	# Assert
	assert_eq(result, "03", "DOWN from 21 should cross to parent's neighbor: 03")

func test_down_crosses_parent_boundary_to_different_face() -> void:
	# Arrange
	var chunk := create_chunk("010")
	
	# Act
	var result := chunk.get_neighbor_location_code(Direction.DOWN)
	
	# Assert
	assert_eq(result, "", "DOWN from 010 should return empty (needs different face)")
