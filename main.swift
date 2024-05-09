import Foundation

// トークンの種類を表す列挙型
enum TokenKind {
    case punct(String)
    case number(Int)
    case eof
}

// トークンの構造体
struct Token {
    let kind: TokenKind
    let start: String.Index
    let end: String.Index
}

// トークン化エラーのレポートとプログラムの終了
func error(_ message: String) -> Never {
    fputs(message + "\n", stderr)
    exit(1)
}

// トークンが指定された文字列と一致するかを確認
func equal(_ token: Token, to string: String, in input: String) -> Bool {
    return input[token.start..<token.end] == string
}

// 数字のトークンから値を取得
func getNumber(from token: Token) -> Int {
    if case .number(let value) = token.kind {
        return value
    }
    error("Expected a number")
}

// 新しいトークンを生成
func newToken(kind: TokenKind, start: String.Index, end: String.Index) -> Token {
    return Token(kind: kind, start: start, end: end)
}

// 文字列をトークンに分解
func tokenize(_ input: String) -> [Token] {
    var tokens = [Token]()
    var index = input.startIndex

    func skipWhitespace() {
        while index < input.endIndex, input[index].isWhitespace {
            index = input.index(after: index)
        }
    }

    while index < input.endIndex {
        skipWhitespace()
        if index == input.endIndex { break }

        // 数字のトークン
        if input[index].isNumber {
            let start = index
            var value = 0
            while index < input.endIndex, let digit = input[index].wholeNumberValue {
                value = value * 10 + digit
                index = input.index(after: index)
            }
            tokens.append(newToken(kind: .number(value), start: start, end: index))
            continue
        }

        // 演算子のトークン
        if "+-".contains(input[index]) {
            let start = index
            index = input.index(after: index)
            tokens.append(newToken(kind: .punct(String(input[start])), start: start, end: index))
            continue
        }

        error("Invalid token")
    }

    tokens.append(newToken(kind: .eof, start: index, end: index))
    return tokens
}

// コマンドライン引数のチェック
guard CommandLine.arguments.count == 2 else {
    error("\(CommandLine.arguments[0]): invalid number of arguments")
}

// 入力文字列をトークン化
let input = CommandLine.arguments[1]
let tokens = tokenize(input)
var index = 0

func nextToken() -> Token {
    defer { index += 1 }
    return tokens[index]
}

// アセンブリコードの生成
print("  .globl main")
print("main:")

// 最初のトークンは数値である必要があります
var token = nextToken()
print("  mov $\(getNumber(from: token)), %rax")

// + または - の後に続く数値を処理
while index < tokens.count - 1 {
    token = nextToken()
    switch token.kind {
    case .punct("+"):
        let value = getNumber(from: nextToken())
        print("  add $\(value), %rax")
    case .punct("-"):
        let value = getNumber(from: nextToken())
        print("  sub $\(value), %rax")
    case .eof:
        break
    default:
        error("Unexpected token")
    }
}

print("  ret")
