import Foundation

// トークンの種類を表現する列挙型
enum TokenKind {
  case punctuator(String)
  case number(Int)
  case eof
}

// トークンの定義
class Token {
  let kind: TokenKind
  let location: String.Index
  let length: Int

  init(kind: TokenKind, location: String.Index, length: Int) {
    self.kind = kind
    self.location = location
    self.length = length
  }
}

// トークナイザークラス
class Tokenizer {
  private let input: String
  private var index: String.Index

  init(input: String) {
    self.input = input
    self.index = input.startIndex
  }

  private func advanceIndex() {
    index = input.index(after: index)
  }

  func tokenize() -> [Token] {
    var tokens: [Token] = []

    while index < input.endIndex {
      let character = input[index]

      // 空白をスキップ
      if character.isWhitespace {
        advanceIndex()
        continue
      }

      // 数値リテラル
      if character.isNumber {
        let start = index
        while index < input.endIndex && input[index].isNumber {
          advanceIndex()
        }
        let value = Int(input[start..<index])!
        tokens.append(
          Token(
            kind: .number(value), location: start, length: input.distance(from: start, to: index)))
        continue
      }

      // 演算子
      if "+-*/()".contains(character) {
        tokens.append(Token(kind: .punctuator(String(character)), location: index, length: 1))
        advanceIndex()
        continue
      }

      // 無効なトークンのエラー処理
      errorAt(input, location: index, message: "Invalid token")
    }

    tokens.append(Token(kind: .eof, location: index, length: 0))
    return tokens
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

// 構文解析のノードタイプ
enum NodeKind {
  case add, sub, mul, div
  case number(Int)
}

// 構文解析のノード
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

// 構文解析器クラス
class Parser {
  private var tokens: [Token]
  private var index: Int

  init(tokens: [Token]) {
    self.tokens = tokens
    self.index = 0
  }

  private func currentToken() -> Token {
    return tokens[index]
  }

  private func nextToken() {
    index += 1
  }

  private func expectPunctuator(_ s: String) {
    if case .punctuator(let op) = currentToken().kind, op == s {
      nextToken()
    } else {
      error("Expected '\(s)'")
    }
  }

  private func primary() -> Node {
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

  private func mul() -> Node {
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
}

// コード生成器
func generate(node: Node) {
  switch node.kind {
  case .number(let value):
    print("mov $\(value), %rax")
  case .add:
    generate(node: node.rhs!)
    print("push %rax")
    generate(node: node.lhs!)
    print("pop %rdi")
    print("add %rdi, %rax")
  case .sub:
    generate(node: node.rhs!)
    print("push %rax")
    generate(node: node.lhs!)
    print("pop %rdi")
    print("sub %rdi, %rax")
  case .mul:
    generate(node: node.rhs!)
    print("push %rax")
    generate(node: node.lhs!)
    print("pop %rdi")
    print("imul %rdi, %rax")
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

  let input = arguments[1]
  let tokenizer = Tokenizer(input: input)
  let tokens = tokenizer.tokenize()
  let parser = Parser(tokens: tokens)
  let ast = parser.expr()

  print(".globl main")
  print("main:")
  generate(node: ast)
  print("ret")
}

main()
