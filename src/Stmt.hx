package;

enum Stmt {
	Block(statements:Array<Stmt>);
	Expression(e:Expr);
	Print(e:Expr);
	Var(name:Token, init:Expr, mutable:Bool);
	If(cond:Expr, then:Stmt, el:Stmt);
	While(cond:Expr, body:Stmt);
	For(name:Token, from:Expr, to:Expr, step:Expr, reverse:Expr, body:Array<Stmt>);
	Break(keyword:Token);
	Continue(keyword:Token);
	Function(name:Token, params:Array<Token>, body: Array<Stmt>);
	Return(keyword:Token, value:Expr);
} 