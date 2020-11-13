/// A matrix of elements.
public struct Matrix<Element> {

  /// Creates a new matrix containing the specified number of a single, repeated value.
  ///
  /// - Parameters:
  ///   - repeatedValue: The element to repeat.
  ///   - rowCount: The number of rows in the matrix. `rowCount` must be zero or greater.
  ///   - columnCount: The number of columns in the matrix. `columnCount` must be zero or greater.
  public init(repeating repeatedValue: Element, rowCount: Int, columnCount: Int) {
    guard rowCount > 0 && columnCount > 0 else {
      storage = Storage(rowCount: 0, columnCount: 0)
      return
    }

    storage = Storage(rowCount: rowCount, columnCount: columnCount)
    for i in 0 ..< rowCount * columnCount {
      storage.elements.advanced(by: i).initialize(to: repeatedValue)
    }
  }

  /// Creates a new matrix from a collection of rows.
  ///
  /// - Parameter rows: A sequence of rows, where each row is a sequence of elements.
  public init<C>(rows: C)
    where C: Collection, C.Element: Collection, C.Element.Element == Element
  {
    guard let first = rows.first, !first.isEmpty else {
      storage = Storage(rowCount: 0, columnCount: 0)
      return
    }

    precondition(rows.allSatisfy({ $0.count == first.count }))
    storage = Storage(rowCount: rows.count, columnCount: first.count)
    for (i, row) in rows.enumerated() {
      for (j, value) in row.enumerated() {
        let offset = i * storage.columnCount + j
        storage.elements.advanced(by: offset).initialize(to: value)
      }
    }
  }

  /// Creates a new matrix from a collection of columns.
  public init<C>(columns: C)
    where C: Collection, C.Element: Collection, C.Element.Element == Element
  {
    guard let first = columns.first, !first.isEmpty else {
      storage = Storage(rowCount: 0, columnCount: 0)
      return
    }

    precondition(columns.allSatisfy({ $0.count == first.count }))
    storage = Storage(rowCount: first.count, columnCount: columns.count)
    for (j, column) in columns.enumerated() {
      for (i, value) in column.enumerated() {
        let offset = i * storage.columnCount + j
        storage.elements.advanced(by: offset).initialize(to: value)
      }
    }
  }

  /// Creates an matrix with the specified number of rows and columns, then calls the given
  /// closure with a buffer covering the matrix’s uninitialized memory.
  ///
  /// The matrix's memory is a contiguous buffer large enough to fit `rowCount * columnCount`
  /// instances of `Element`, laid out in row-major order.
  ///
  /// - Parameters:
  ///   - rowCount: The number of rows in the matrix. `rowCount` must be zero or greater.
  ///   - columnCount: The number of columns in the matrix. `columnCount` must be zero or greater.
  ///   - initializer: A closure that accepts a pointer to the matrix's memory and initializes it
  ///     in the range `[0 ..< rowCount * columnCount]`.
  public init(
    rowCount: Int,
    columnCount: Int,
    initializingWith initializer: (UnsafeMutablePointer<Element>) throws -> Void
  ) rethrows {
    guard rowCount > 0 && columnCount > 0 else {
      storage = Storage(rowCount: 0, columnCount: 0)
      return
    }

    storage = Storage(rowCount: rowCount, columnCount: columnCount)
    try initializer(storage.elements)
  }

  /// The internal storage of the matrix.
  internal var storage: Storage

  internal class Storage {

    init(rowCount: Int, columnCount: Int) {
      self.rowCount = rowCount
      self.columnCount = columnCount
      self.elements = .allocate(capacity: rowCount * columnCount)
    }

    deinit {
      elements.deallocate()
    }

    /// The number of rows in the matrix.
    let rowCount: Int

    /// The number of columns in the matrix.
    let columnCount: Int

    /// The elements of the matrix, stored in a contiguous array in row-major order.
    let elements: UnsafeMutablePointer<Element>

    func copy() -> Storage {
      let newStorage = Storage(rowCount: rowCount, columnCount: columnCount)
      newStorage.elements.assign(from: elements, count: rowCount * columnCount)
      return newStorage
    }

  }

  /// The number of rows in the matrix.
  public var rowCount: Int { storage.rowCount }

  /// The number of columns in the matrix.
  public var columnCount: Int { storage.columnCount }

  /// The indices that are valid for accessing rows.
  public var rowIndices: Range<Int> { 0 ..< storage.rowCount }

  /// The indices that are valid for accessing columns.
  public var columnIndices: Range<Int> { 0 ..< storage.columnCount }

  /// Returns this matrix transposed.
  public var transposed: Matrix {
    return Matrix(rows: columns)
  }

  /// Calls the gien closure with a pointer to the matrix's memory.
  ///
  /// - Parameter body: A closure that accepts a pointer to the matrix's memory.
  public func withContiguousStorage<R>(
    _ body: (UnsafeBufferPointer<Element>) throws -> R
  ) rethrows -> R {
    return try body(UnsafeBufferPointer(start: storage.elements, count: rowCount * columnCount))
  }

  /// Accesses the element at the specified row and column.
  ///
  /// - Parameters:
  ///   - rowIndex: The row index of the element to access.
  ///   - columnIndex: The column index of the element to access.
  public subscript(rowIndex: Int, columnIndex: Int) -> Element {
    get {
      precondition(rowIndex < storage.rowCount && columnIndex < storage.columnCount)
      return storage.elements[rowIndex * storage.columnCount + columnIndex]
    }
    set {
      precondition(rowIndex < storage.rowCount && columnIndex < storage.columnCount)
      if !isKnownUniquelyReferenced(&storage) {
        storage = storage.copy()
      }
      storage.elements[rowIndex * storage.columnCount + columnIndex] = newValue
    }
  }

  /// Returns a view on the row at the specified index.
  ///
  /// - Parameter position: A row index.
  public subscript(rowIndex position: Int) -> Row {
    precondition(position < storage.rowCount)
    return Row(storage: storage, rowIndex: position, columnIndices: 0 ..< columnCount)
  }

  /// Returns a view on the column at the specified index.
  ///
  /// - Parameter position: A column index.
  public subscript(columnIndex position: Int) -> Column {
    precondition(position < storage.columnCount)
    return Column(storage: storage, columnIndex: position, rowIndices: 0 ..< rowCount)
  }

  /// A collection with the rows of the matrix.
  public var rows: [Row] { (0 ..< rowCount).map({ self[rowIndex: $0] }) }

  /// A collection with the columns of the matrix.
  public var columns: [Column] { (0 ..< columnCount).map({ self[columnIndex: $0] }) }

  /// A view on a specific row of a matrix.
  public struct Row: Collection, CustomStringConvertible {

    /// A reference to the entire storage of the original matrix.
    internal let storage: Storage

    /// The index of this row in the matrix.
    public let rowIndex: Int

    /// The range of column indices of the row.
    public let columnIndices: Range<Int>

    public var startIndex: Int { columnIndices.lowerBound }

    public var endIndex: Int { columnIndices.upperBound }

    public func index(after i: Int) -> Int {
      return i + 1
    }

    /// Accesses the element at the specified column position in the row.
    public subscript(position: Int) -> Element {
      precondition(columnIndices ~= position)
      return storage.elements[rowIndex * storage.columnCount + position]
    }

    public var description: String {
      return String(describing: Array(self))
    }

  }

  /// A view on a specific column of a matrix.
  public struct Column: Collection, CustomStringConvertible {

    /// A reference to the entire storage of the original matrix.
    internal let storage: Storage

    /// The index of this column in the matrix.
    public let columnIndex: Int

    /// The range of row indices of the column.
    public let rowIndices: Range<Int>

    public var startIndex: Int { rowIndices.lowerBound }

    public var endIndex: Int { rowIndices.upperBound }

    public func index(after i: Int) -> Int {
      return i + 1
    }

    /// Accesses the element at the specified row position in the column.
    public subscript(position: Int) -> Element {
      precondition(rowIndices ~= position)
      return storage.elements[position * storage.columnCount + columnIndex]
    }

    public var description: String {
      return String(describing: Array(self))
    }

  }

  /// Returns a matrix containing the results of mapping the given closure over each element.
  ///
  /// - Parameter transform: A mapping closure. `transform` accepts an element of this sequence as
  ///   its parameter and returns a transformed value of the same or of a different type.
  public func map<R>(_ transform: (Element) throws -> R) rethrows -> Matrix<R> {
    return try Matrix<R>(
      rowCount: rowCount,
      columnCount: columnCount,
      initializingWith: { elements in
        for i in 0 ..< rowCount * columnCount {
          elements.advanced(by: i).initialize(to: try transform(storage.elements[i]))
        }
      })
  }

}

extension Matrix: Equatable where Element: Equatable {

  public static func == (lhs: Matrix, rhs: Matrix) -> Bool {
    guard (lhs.rowCount == rhs.rowCount) && (lhs.columnCount == rhs.columnCount)
      else { return false }

    for i in 0 ..< lhs.rowCount * lhs.columnCount {
      guard lhs.storage.elements[i] == rhs.storage.elements[i]
        else { return false }
    }

    return true
  }
}

extension Matrix: Hashable where Element: Hashable {

  public func hash(into hasher: inout Hasher) {
    hasher.combine(rowCount)
    hasher.combine(columnCount)
    for i in 0 ..< rowCount * columnCount {
      hasher.combine(storage.elements[i])
    }
  }

}

extension Matrix where Element: AdditiveArithmetic {

  /// Returns whether the matrix is filled with zeros.
  public var isZero: Bool {
    for i in 0 ..< rowCount * columnCount where storage.elements[i] != .zero {
      return false
    }
    return true
  }

  /// Computes the component-wise sum of two matrices.
  ///
  /// - Parameters:
  ///   - lhs: The first matrix to add.
  ///   - rhs: The second matrix to add.
  public static func + (lhs: Matrix, rhs: Matrix) -> Matrix {
    precondition(lhs.rowCount == rhs.rowCount && lhs.columnCount == rhs.columnCount)
    return Matrix(
      rowCount: lhs.rowCount,
      columnCount: lhs.columnCount,
      initializingWith: { elements in
        for i in 0 ..< lhs.rowCount * lhs.columnCount {
          elements.advanced(by: i)
            .initialize(to: lhs.storage.elements[i] + rhs.storage.elements[i])
        }
      })
  }

  /// Computes the component-wise sum of two matrices and stores the result in the left-hand-side
  /// variable.
  ///
  /// - Parameters:
  ///   - lhs: The first matrix to add.
  ///   - rhs: The second matrix to add.
  public static func += (lhs: inout Matrix, rhs: Matrix) {
    precondition(lhs.rowCount == rhs.rowCount && lhs.columnCount == rhs.columnCount)
    for i in 0 ..< lhs.rowCount * lhs.columnCount {
      lhs.storage.elements[i] += rhs.storage.elements[i]
    }
  }

  /// Computes the component-wise subtraction of a matrice by another.
  ///
  /// - Parameters:
  ///   - lhs: A matrix.
  ///   - rhs: The matrix to subtract from `lhs`.
  public static func - (lhs: Matrix, rhs: Matrix) -> Matrix {
    precondition(lhs.rowCount == rhs.rowCount && lhs.columnCount == rhs.columnCount)
    return Matrix(
      rowCount: lhs.rowCount,
      columnCount: lhs.columnCount,
      initializingWith: { elements in
        for i in 0 ..< lhs.rowCount * lhs.columnCount {
          elements.advanced(by: i)
            .initialize(to: lhs.storage.elements[i] - rhs.storage.elements[i])
        }
      })
  }

  /// Computes the component-wise subtraction of a matrice by another and stores the result in the
  /// left-hand-side variable.
  ///
  /// - Parameters:
  ///   - lhs: A matrix.
  ///   - rhs: The matrix to subtract from `lhs`.
  public static func -= (lhs: inout Matrix, rhs: Matrix) {
    precondition(lhs.rowCount == rhs.rowCount && lhs.columnCount == rhs.columnCount)
    for i in 0 ..< lhs.rowCount * lhs.columnCount {
      lhs.storage.elements[i] -= rhs.storage.elements[i]
    }
  }

}

extension Matrix where Element: Numeric {

  /// Computes the multiplication of two matrices.
  ///
  /// - Parameters:
  ///   - lhs: The first matrix to multiply.
  ///   - rhs: The second matrix to multiply.
  public static func * (lhs: Matrix, rhs: Matrix) -> Matrix {
    precondition(lhs.columnCount == rhs.rowCount)
    let mat = Matrix(
      repeating: Element.zero,
      rowCount: lhs.rowCount,
      columnCount: rhs.columnCount)

    for i in 0 ..< lhs.rowCount {
      for j in 0 ..< rhs.columnCount {
        let c = mat.storage.elements.advanced(by: i * rhs.columnCount + j)
        for k in 0 ..< lhs.columnCount {
          c.pointee = c.pointee + lhs[i, k] * rhs[k, j]
        }
      }
    }

    return mat
  }

}

extension Matrix: CustomStringConvertible {

  public var description: String {
    guard (rowCount > 0) && (columnCount > 0)
      else { return "()" }

    guard rowCount > 1 else {
      return "( " + self[rowIndex: rowIndices.lowerBound]
        .map(String.init(describing:))
        .joined(separator: "  ") + " )"
    }

    let strings = map(String.init(describing:))
    let lengths = (0 ..< columnCount).map({ j in
      strings[columnIndex: j].reduce(0, { n, string in max(n, string.count) })
    })

    var rv = ""
    for i in 0 ..< rowCount {
      let line = strings[rowIndex: i]
        .enumerated()
        .map({ j, string in
          String(repeating: " ", count: lengths[j] - string.count) + string
        })
        .joined(separator: "  ")

      switch i {
      case 0           : rv += "⎛ " + line + " ⎞\n"
      case rowCount - 1: rv += "⎝ " + line + " ⎠"
      default          : rv += "⎜ " + line + " ⎟\n"
      }
    }

    return rv
  }

}

extension Matrix: CustomDebugStringConvertible {

  public var debugDescription: String {
    return String(reflecting: rowIndices.map({ self[rowIndex: $0] }))
  }

}
