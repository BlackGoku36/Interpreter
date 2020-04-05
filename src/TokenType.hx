package;

enum TokenType {
	
	LeftParen; RightParen; LeftBrace; RightBrace;
	Comma; Dot; DotDot; Semicolon;

	Minus; MinusEqual;
	Plus; PlusEqual;
	Slash; SlashEqual;
	Star; StarEqual;

	Bang; BangEqual;
	Equal; EqualEqual;
	Greater; GreaterEqual;
	Less; LessEqual;

	Identifier; String; Number;

	And; BinaryAnd;
	Or; BinaryOr;
	Class; Else; False; Fn; For; If; Null;
	Print; Return; Super; This; True; Let; While;
	In; Break; Continue;
	Immut;

	Eof;
}
