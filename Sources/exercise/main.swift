// Define the Petri net's incidence matrix.
let c = Matrix(rows: [
  [-1,  1,  0,  0],
  [ 1, -1,  0,  0],
  [ 0,  0, -1,  1],
  [ 0,  0,  1, -1],
  [-1,  1, -1,  1],
  [ 1,  0, -1,  0],
  [-1,  0,  1,  0],
])

// Define the initial matrix as 1 column vector.
let m0 = Matrix(columns: [[1, 0, 1, 0, 1, 0, 3]])

// Create a random sequence of transitions.
let s = Matrix(columns: [
  (0 ..< 4).map({ _ in Int.random(in: 0 ..< 200) })
])

// Compute the marking obtained after firing a random sequence of transitions.
let m1 = m0 + c * s
print(m1)
