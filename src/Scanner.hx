package;

class Scanner {
	final source:String;
	final tokens:Array<Token> = [];

	var start = 0;
	var current = 0;
	var line = 1;

	static var keywords = [
		'class' => TokenType.Class,
		'else' => TokenType.Else,
		'false' => TokenType.False,
		'for' => TokenType.For,
		'fn' => TokenType.Fn,
		'in' => TokenType.In,
		'continue' => TokenType.Continue,
		'break' => TokenType.Break,
		'if' => TokenType.If,
		'null' => TokenType.Null,
		'print' => TokenType.Print,
		'return' => TokenType.Return,
		'super' => TokenType.Super,
		'this' => TokenType.This,
		'true' => TokenType.True,
		'let' => TokenType.Let,
		'while' => TokenType.While,
		'immut' => TokenType.Immut
	];

	public function new(source:String) {
		this.source = source;
	}

	public function scanTokens() {
		while (!isAtEnd()){
			start = current;
			scanToken();
		}
		tokens.push(new Token(Eof, '', null, line));
		return tokens;
	}

	function scanToken() {
		var c = advance();
		switch (c){
			case "(": addToken(LeftParen);
			case ")": addToken(RightParen);
			case "{": addToken(LeftBrace);
			case "}": addToken(RightBrace);
			case ",": addToken(Comma);
			case "-": addToken(match("=") ? MinusEqual : Minus);
			case "+": addToken(match("=") ? PlusEqual : Plus);
			case ";": addToken(Semicolon);
			case ":": addToken(Colon);
			case "*": addToken(match("=") ? StarEqual : Star);
			case "!": addToken(match('=') ? BangEqual : Bang);
			case "=": addToken(match('=') ? EqualEqual : Equal);
			case "<": addToken(match('=') ? LessEqual : Less);
			case ">": addToken(match('=') ? GreaterEqual : Greater);
			case ".": addToken(match(".") ? DotDot : Dot);
			case "&": addToken(match("&") ? And : BinaryAnd);
			case "|": addToken(match("|") ? Or : BinaryOr);
			case "/":
				if(match("/")){
					while (peek() != "\n" && !isAtEnd()) advance();
				}else{
					addToken(match("=") ? SlashEqual : Slash);
				}
			case ' ':
			case '\r':
			case '\t':
			case '\n': line++;
			case '"': string();
			case _:
				if (isDigit(c)) {
					number();
				} else if (isAlpha(c)) {
					identifier();
				} else {
					Lox.error(line, "Unexpected character.");
				}
		}
	}

	function identifier() {
		while(isAlphaNumeric(peek())) advance();

		var text = source.substring(start, current);
		var type = switch keywords[text] {
			case null: TokenType.Identifier;
			case v: v;
		}

		addToken(type);
	}

	function isAlpha(c:String) {
		return (c >= 'a' && c <= 'z') ||
		       (c >= 'A' && c <= 'Z') ||
		        c == '_';
	}

	function isAlphaNumeric(c:String) {
		return isAlpha(c) || isDigit(c);
	}

	function isDigit(c:String) {
		return c >= '0' && c <= '9';
	}

	function number() {
		while(isDigit(peek())) advance();

		if(peek() == '.' && isDigit(peekNext())) {
			advance();

			while(isDigit(peek())) advance();
		}

		addToken(Number, Std.parseFloat(source.substring(start, current)));
	}

	function string() {
		while(peek() != '"' && !isAtEnd()) {
			if(peek() == '\n') line++;
			advance();
		}

		if(isAtEnd()) {
			Lox.error(line, "Unterminated string.");
			return;
		}

		advance();

		var value = source.substring(start + 1, current - 1);
		addToken(String, value);
	}

	function peek() {
		if(isAtEnd()) return String.fromCharCode(0);
		return source.charAt(current);
	}

	function peekNext() {
		if(current + 1 >= source.length) return String.fromCharCode(0);
		return source.charAt(current + 1);
	}

	function match(expected:String) {
		if(isAtEnd()) return false;
		if(source.charAt(current) != expected) return false;

		current++;
		return true;
	}

	function advance() {
		current++;
		return source.charAt(current-1);
	}

	function addToken(type:TokenType, ?literal:Any) {
		var text = source.substring(start, current);
		tokens.push(new Token(type, text, literal, line));
	}

	function isAtEnd() {
		return current >= source.length;
	}
}
