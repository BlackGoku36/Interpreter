package;

class Parser {
	final tokens:Array<Token>;
	var current = 0;

	public function new(tokens:Array<Token>) {
		this.tokens = tokens;
	}

	public function parse() {
		var statements = [];
		while(!isAtEnd())
			statements.push(declaration());
		return statements;
	}

	function expression():Expr {
		return assignment();
	}

	function declaration() {
		try{
			if(match([Fn])) return func('function');
			if(match([Let])) return varDeclaration();
			return statement();
		} catch(e:ParserError) {
			synchronize();
			return null;
		}
	}

	function statement():Stmt {
		if(match([If])) return ifStatement();
		if(match([For])) return forStatement();
		if(match([While])) return whileStatement();
		if(match([Print])) return printStatement();
		if(match([Break])) return Break(previous());
		if(match([Continue])) return Continue(previous());
		if(match([LeftBrace])) return Block(block());
		if(match([Return])) return returnStatement(); 
		return expressionStatement();
	}

	function expressionStatement():Stmt {
		var expr = expression();
		consume(Semicolon, 'Expect ";" after expression.');
		return Expression(expr);
	}

	function returnStatement():Stmt {
		var keyword = previous();
		var value = if(check(Semicolon)) null else expression();
		consume(Semicolon, 'Expect ";" after return.');
		return Return(keyword, value);
	}

	function func(kind: String):Stmt {
		var name = consume(Identifier, 'Expect $kind name.');
		consume(LeftParen, 'Expect "(" after $kind name.');
		var params = [];
		if(!check(RightParen)) {
			do {
				if(params.length >= 255) error(peek(), 'Cannot have more than 255 parameters.');
				params.push(consume(Identifier, 'Expect parameter name.'));
			} while(match([Comma]));
		}
		consume(RightParen, 'Expect ")" after parameters.');
		consume(LeftBrace, 'Expect "{" before $kind body');
		var body = block();
		return Function(name, params, body);
	}

	function whileStatement():Stmt {
		var cond = expression();
		var body = statement();
		return While(cond, body);
	}

	function forStatement():Stmt {
		var name = null;

		if(check(Identifier)){
			name = consume(Identifier, 'Except variable name.');
			consume(In, 'Expect "in" after for loop identifier.');
		}

		var from = expression();
		consume(DotDot, 'Expect ".." between from and to numbers.');
		var to = expression();

		consume(LeftBrace, 'Expect "{" before loop body.');
		var body = block();
		return For(name, from, to, body);
	}

	function ifStatement():Stmt {
		var condition = expression();
		var then = statement();
		var el = null;
		if(match([Else])) el = statement();
		return If(condition, then, el);
	}

	function printStatement():Stmt {
		consume(LeftParen, 'Except "(" after print');
		var value = expression();
		consume(RightParen, 'Except ")" after value');
		consume(Semicolon, 'Expect ";" after value.');
		return Print(value);
	}

	function block():Array<Stmt> {
		var statements = [];

		while(!check(RightBrace) && !isAtEnd()) {
			statements.push(declaration());
		}

		consume(RightBrace, 'Expect "}" after block.');
		return statements;
	}

	function varDeclaration():Stmt {
		var mutable:Bool = true;
		if(match([Immut])) mutable = false;
		var name = consume(Identifier, 'Expect variable name.');

		var initializer = null;

		if(match([Equal])) initializer = expression();

		consume(Semicolon, 'Expect ";" after variable declaration.');
		return Var(name, initializer, mutable);
	}

	function assignment():Expr {
		var expr = or();

		if(match([Equal, PlusEqual, MinusEqual, StarEqual, SlashEqual])) {
			var equals = previous();
			var value = assignment();

			switch expr {
				case Variable(name):
					return Assign(name, equals, value);
				case _:
			}

			error(equals, 'Invalid assignment target.');
		}

		return expr;
	}

	function or():Expr {
		var expr = and();

		while (match([Or])){
			var op = previous();
			var right = and();
			expr = Logical(expr, op, right);
		}
		return expr;
	}

	function and():Expr {
		var expr = equality();
		while (match([And])){
			var op = previous();
			var right = equality();
			expr = Logical(expr, op, right);
		}
		return expr;
	}


	function equality():Expr {
		var expr = comparison();

		while(match([BangEqual, EqualEqual])) {
			var op = previous();
			var right = comparison();
			expr = Binary(expr, op, right);
		}

		return expr;
	}

	function comparison():Expr {
		var expr = addition();

		while(match([Greater, GreaterEqual, Less, LessEqual])) {
			var op = previous();
			var right = addition();
			expr = Binary(expr, op, right);
		}

		return expr;
	}

	function addition():Expr {
		var expr = multiplication();

		while(match([Minus, Plus])) {
			var op = previous();
			var right = multiplication();
			expr = Binary(expr, op, right);
		}

		return expr;
	}

	function multiplication():Expr {
		var expr = unary();

		while(match([Star, Slash])) {
			var op = previous();
			var right = multiplication();
			expr = Binary(expr, op, right);
		}

		return expr;
	}

	function unary():Expr {
		return if(match([Bang, Minus])) {
			var op = previous();
			var right = unary();
			Unary(op, right);
		} else {
			call();
		}
	}

	function call():Expr{
		var expr = primary();

		while(true) {
			if(match([LeftParen]))
				expr = finishCall(expr);
			else
				break;
		}
		return expr;
	}

	function finishCall(callee:Expr):Expr {
		var args = [];
		if(!check(RightParen)) {
			do {
				if(args.length >= 255) error(peek(), 'Cannot have more than 255 arguments');
				args.push(expression());
			} while(match([Comma]));
		}

		var paren = consume(RightParen, 'Expect ")" after arguments.');
		return Call(callee, paren, args);
	}

	function primary():Expr {
		if(match([False])) return Literal(false);
		if(match([True])) return Literal(true);
		if(match([Null])) return Literal(null);
		if(match([Number, String])) return Literal(previous().literal);
		if(match([Identifier])) return Variable(previous());
		if(match([LeftParen])) {
			var expr = expression();
			consume(RightParen, 'Expect ")" after expression.');
			return Grouping(expr);
		}
		throw error(peek(), 'Expect expression.');
	}

	function consume(type:TokenType, message:String) {
		if(check(type)) return advance();
		throw error(peek(), message);
	}

	function match(types:Array<TokenType>) {
		for(type in types) {
			if(check(type)) {
				advance();
				return true;
			}
		}
		return false;
	}

	function check(type:TokenType) {
		if(isAtEnd()) return false;
		return peek().type == type;
	}

	function checkUntil(type:TokenType, until:TokenType):Bool {
        var cur = current;
        do {
            if (tokens[cur].type == type) return true;
            cur++;
        } while (tokens[cur].type != until && tokens[cur].type != Eof);
        return false;
	}

	function advance() {
		if(!isAtEnd()) current++;
		return previous();
	}

	function isAtEnd() {
		return peek().type == Eof;
	}

	function peek() {
		return tokens[current];
	}

	function previous() {
		return tokens[current - 1];
	}

	function error(token:Token, message:String) {
		Lox.error(token, message);
		return new ParserError();
	}

	function synchronize() {
		advance();
		while(!isAtEnd()) {
			if(previous().type == Semicolon) return;
			switch peek().type {
				case Class | Fn | Let | For | If | While | Print | Return: return;
				case _:
			}
		}
		advance();
	}

}
private class ParserError extends Error {}
