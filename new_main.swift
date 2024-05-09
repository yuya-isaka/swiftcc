import Foundation

// Tokenizer
enum TokenKind {
    case punctuator(String)  // Operators like "+", "-", etc.
    case number(Int)         // Numeric literals
    case eof                 // End of file
}

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

func error(_ message: String) -> Never {
    fatalError(message)
}

func errorAt(_ input: String, location: String.Index, message: String) -> Never {
    let position = input.distance(from: input.startIndex, to: location)
    let spaces = String(repeating: " ", count: position)
    print("\(input)\n\(spaces)^ \(message)")
    fatalError("Compilation Error")
}

func tokenize(input: String) -> [Token] {
    var tokens: [Token] = []
    var index = input.startIndex

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
            tokens.append(Token(kind: .number(value), location: start, length: input.distance(from: start, to: index)))
            continue
        }

        // Punctuators
        if "+-*/()".contains(character) {
            tokens.append(Token(kind: .punctuator(String(character)), location: index, length: 1))
            index = input.index(after: index)
            continue
        }

        errorAt(input, location: index, message: "Invalid token")
    }

    tokens.append(Token(kind: .eof, location: index, length: 0))
    return tokens
}

// Parser
enum NodeKind {
    case add, sub, mul, div, number(Int)
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
    func currentToken() -> Token {
        return tokens[index]
    }

    func nextToken() {
        index += 1
    }

    func expectNumber() -> Int {
        if case .number(let value) = currentToken().kind {
            nextToken()
            return value
        } else {
            error("Expected a number")
        }
    }

    func expectPunctuator(_ s: String) {
        if case .punctuator(let op) = currentToken().kind, op == s {
            nextToken()
        } else {
            error("Expected '\(s)'")
        }
    }

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


    return expr()
}

// Code generator
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
    let tokens = tokenize(input: input)
    let ast = parse(tokens: tokens)

    print(".globl main")
    print("main:")
    generate(node: ast)
    print("ret")
}

main()
