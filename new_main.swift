import Foundation

// トークンの種類を表現する列挙型
enum TokenKind {
  case punctuator(String)  // Operators like "+", "-", etc.
  case number(Int)  // Numeric literals
  case eof  // End of file
}

class Token {
  // トークンの種類
  let kind: TokenKind
  // 入力文字列中の位置
  let location: String.Index
  // トークンの長さ
  let length: Int

  init(kind: TokenKind, location: String.Index, length: Int) {
    self.kind = kind
    self.location = location
    self.length = length
  }
}

// エラーメッセージを表示してプログラムを終了
func error(_ message: String) -> Never {
  fatalError(message)
}

// 指定された位置にエラーメッセージを表示してプログラムを終了
func errorAt(_ input: String, location: String.Index, message: String) -> Never {
  let position = input.distance(from: input.startIndex, to: location)
  let spaces = String(repeating: " ", count: position)
  print("\(input)\n\(spaces)^ \(message)")
  fatalError("Compilation Error")
}

// 入力文字列をトークンに分割し、トークンのリストを返す
func tokenize(input: String) -> [Token] {
  var tokens: [Token] = []
  var index = input.startIndex

  // 入力全体を走査し、トークンを分割
  while index < input.endIndex {
    let character = input[index]

    // Skip whitespace
    if character.isWhitespace {
      index = input.index(after: index)
      continue
    }

    // Numeric literals
    if character.isNumber {
      let start = index
      while index < input.endIndex && input[index].isNumber {
        index = input.index(after: index)
      }
      let value = Int(input[start..<index])!
      tokens.append(
        Token(kind: .number(value), location: start, length: input.distance(from: start, to: index))
      )
      continue
    }

    // Punctuators
    if "+-*/()".contains(character) {
      tokens.append(Token(kind: .punctuator(String(character)), location: index, length: 1))
      index = input.index(after: index)
      continue
    }

    // 無効なトークンのエラー処理
    errorAt(input, location: index, message: "Invalid token")
  }

  tokens.append(Token(kind: .eof, location: index, length: 0))
  return tokens
}

// ノードの種類を表現する列挙型
enum NodeKind {
  case add, sub, mul, div
  case number(Int)
}

class Node {
  let kind: NodeKind
  let lhs: Node?
  let rhs: Node?

  init(kind: NodeKind, lhs: Node? = nil, rhs: Node? = nil) {
    self.kind = kind
    self.lhs = lhs
    self.rhs = rhs
  }
}

func parse(tokens: [Token]) -> Node {
  var index = 0

  // 現在のトークンを取得
  func currentToken() -> Token {
    return tokens[index]
  }

  // 次のトークンに進む
  func nextToken() {
    index += 1
  }

  // 現在のトークンが数値であると期待し、その値を返す
  func expectNumber() -> Int {
    if case .number(let value) = currentToken().kind {
      nextToken()
      return value
    } else {
      error("Expected a number")
    }
  }

  // 現在のトークンが指定された記号であると期待する
  func expectPunctuator(_ s: String) {
    if case .punctuator(let op) = currentToken().kind, op == s {
      nextToken()
    } else {
      error("Expected '\(s)'")
    }
  }

  // 数値またはカッコを使った式を解析
  func primary() -> Node {
    if case .punctuator("(") = currentToken().kind {
      nextToken()
      let node = expr()
      expectPunctuator(")")
      return node
    } else if case .number(let value) = currentToken().kind {
      nextToken()
      return Node(kind: .number(value))
    } else {
      error("Expected an expression")
    }
  }

  // 乗算・除算の演算子を扱い、ASTノードを構築
  func mul() -> Node {
    var node = primary()
    while true {
      if case .punctuator(let symbol) = currentToken().kind, symbol == "*" || symbol == "/" {
        nextToken()
        let right = primary()
        node = Node(kind: symbol == "*" ? .mul : .div, lhs: node, rhs: right)
      } else {
        break
      }
    }
    return node
  }

  // 加算・減算の演算子を扱い、ASTノードを構築
  func expr() -> Node {
    var node = mul()
    while true {
      if case .punctuator(let symbol) = currentToken().kind, symbol == "+" || symbol == "-" {
        nextToken()
        let right = mul()
        node = Node(kind: symbol == "+" ? .add : .sub, lhs: node, rhs: right)
      } else {
        break
      }
    }
    return node
  }

  // 構築したASTを返す
  return expr()
}

// Code generator
func generate(node: Node) {
  switch node.kind {
  // 数値リテラルのコード生成
  case .number(let value):
    print("mov $\(value), %rax")
  // 加算演算子のコード生成
  case .add:
    generate(node: node.rhs!)
    print("push %rax")
    generate(node: node.lhs!)
    print("pop %rdi")
    print("add %rdi, %rax")
  // 減算演算子のコード生成
  case .sub:
    generate(node: node.rhs!)
    print("push %rax")
    generate(node: node.lhs!)
    print("pop %rdi")
    print("sub %rdi, %rax")
  // 乗算演算子のコード生成
  case .mul:
    generate(node: node.rhs!)
    print("push %rax")
    generate(node: node.lhs!)
    print("pop %rdi")
    print("imul %rdi, %rax")
  // 除算演算子のコード生成
  case .div:
    generate(node: node.rhs!)
    print("push %rax")
    generate(node: node.lhs!)
    print("pop %rdi")
    print("cqo")
    print("idiv %rdi")
  }
}

func main() {
  let arguments = CommandLine.arguments
  guard arguments.count == 2 else {
    error("Usage: \(arguments[0]) <expression>")
  }

  // 入力文字列をトークン化し、ASTを構築
  let input = arguments[1]
  let tokens = tokenize(input: input)
  let ast = parse(tokens: tokens)

  // アセンブリコードの生成
  print(".globl main")
  print("main:")
  generate(node: ast)
  print("ret")
}

main()
