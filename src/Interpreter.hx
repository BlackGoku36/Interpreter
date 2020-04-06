package;

import SpecialIterator;
import TokenType;

class Interpreter {

	public final globals:Environment;
	final locals = new Locals();

	var uninitializedVar:Any = {};

	var environment:Environment;

	public function new() {
		globals = new Environment();
		globals.define("clock", new ClockCallable());
		globals.define("randRangeInt", new RandomRangeICallable());
		environment = globals;
	}

	public function interpret(statements:Array<Stmt>) {
		try {
			for(statement in statements) execute(statement);
		} catch(e:RuntimeError) {
			Lox.runtimeError(e);
		}
	}

	function execute(statement:Stmt) {
		switch (statement) {
			case Block(statements):
				executeBlock(statements, new Environment(environment));
			case Break(keyword): throw new Break();
			case Continue(keyword): throw new Continue();
			case Expression(e):
				evalute(e);
			case Function(name, params, body):
				environment.define(name.lexeme, new Function(name, params, body, environment));
			case Return(keyword, value):
				var value = if(value != null) evalute(value) else null;
				throw new Return(value);
			case If(cond, then, el):
				if(isTruthy(evalute(cond))) execute(then);
				else if(el != null) execute(el);
			case While(cond, body):
				try{
					while (isTruthy(evalute(cond))){
						try {
							execute(body);
						}catch(err:Continue){}
					}
				}catch(err:Break){}
			case For(name, from, to, steps, reverse, body):
				var fromVal = evalute(from);
				var toVal = evalute(to);
				var stepsVal = evalute(steps);
				var revVal = evalute(reverse);
				var env = new Environment();
				try {
                    for (counter in new SpecialIterator((fromVal :Int), (toVal :Int), (stepsVal:Int), (revVal:Bool))) {
						if(name != null) env.define(name.lexeme, counter);
						try {
							executeBlock(body, env);
						}catch(err:Continue){}
					}
				} catch(err:Break){}
			case Print(e):
				Sys.println(stringify(evalute(e)));
			case Var(name, init, mutable):
				var value:Any = uninitializedVar;
				if(init != null) value = evalute(init);
				environment.define(name.lexeme, value);
		}
	}

	public function resolve(expr:Expr, depth:Int) {
		locals.set(expr, depth);
	}

	public function executeBlock(statements:Array<Stmt>, environment:Environment) {
		var previous = this.environment;
		try {
			this.environment = environment;
			for(statement in statements) execute(statement);
			this.environment = previous; // emulates "finally" statement
		} catch(e:Dynamic) {
			this.environment = previous; // emulates "finally" statement
			throw e;
		}
	}

	function evalute(expr:Expr):Any {
		return switch expr{
			case Assign(name, op, value):
				var value:Any = switch (op.type){
					case Equal: evalute(value);
					case PlusEqual:
						var left = lookupVariable(name, expr);
						var right = evalute(value);
						if(Std.is(left, Float) && Std.is(right, Float))
							(left:Float) + (right:Float);
						else if(Std.is(left, Float) && Std.is(right, String))
							throw new RuntimeError(op, 'Value of type num and str cannot be added');
						else if(Std.is(left, String) && Std.is(right, Float))
							throw new RuntimeError(op, 'Value of type str and num cannot be added');
						else if(Std.is(left, String) && Std.is(right, String))
							(left:String) + (right:String);
						else throw new RuntimeError(op, 'Operands cannot be concatinated.');
					case MinusEqual:
						var left = lookupVariable(name, expr);
                        var right = evalute(value);
                        checkNumberOperands(op, left, right);
                        (left: Float) - (right: Float);
					case SlashEqual:
						var left = lookupVariable(name, expr);
                        var right = evalute(value);
                        checkNumberOperands(op, left, right);
                        (left: Float) / (right: Float);
					case StarEqual:
						var left = lookupVariable(name, expr);
                        var right = evalute(value);
						if(Std.is(left, Float) && Std.is(right, Float))
							(left:Float) * (right:Float)
						else if(Std.is(left, std.String) && Std.is(right, Float)){
							var string = "";
							for(i in 0...cast(right, Int)) string += left;
							string;
						}else
							throw new RuntimeError(op, 'Only num-num and str-num is valid for \'*=\' operator');
					case _: throw "error";
				}
				switch locals.get(expr) {
					case null: globals.assign(name, value);
					case distance: environment.assignAt(distance, name, value);
				}
				value;
			case Literal(v):
				v;
			case Logical(left, op, right):
				var left = evalute(left);
				switch (op.type){
					case Or if(isTruthy(left)): left;
					case And if(!isTruthy(left)): left;
					case _: evalute(right);
				}
			case Unary(op, right):
				var right = evalute(right);
				switch op.type{
					case Bang:
						!isTruthy(right);
					case Minus:
						checkNumberOperand(op, right);
						-(right:Float);
					case _:
						null;
				}
			case Binary(left, op, right):
				var left:Any = evalute(left);
				var right:Any = evalute(right);
				switch op.type {
					case Minus:
						checkNumberOperands(op, left, right);
						(left:Float) - (right:Float);
					case Slash:
						checkNumberOperands(op, left, right);
						(left:Float) / (right:Float);
					case Star:
						if(Std.is(left, Float) && Std.is(right, Float))
							(left:Float) * (right:Float);
						else if(Std.is(left, std.String) && Std.is(right, Float)){
							var string = "";
							for(i in 0...cast(right, Int)) string += left;
							string;
						}
						else
							throw new RuntimeError(op, "Operands must be numbers");
					case Plus:
						if(Std.is(left, Float) && Std.is(right, Float))
							(left:Float) + (right:Float);
						else if(Std.is(left, std.String) && Std.is(right, std.String))
							(left:String) + (right:String);
						else
							throw new RuntimeError(op, 'Operands must be two numbers or two strings.');
					case Greater:
						if(Std.is(left, Float) && Std.is(right, Float))
							(left:Float) > (right:Float);
						else if(Std.is(left, std.String) && Std.is(right, std.String))
							(left:String).length > (right:String).length;
						else
							throw new RuntimeError(op, 'Operands must be two numbers or two strings.');
					case GreaterEqual:
						if(Std.is(left, Float) && Std.is(right, Float))
							(left:Float) >= (right:Float);
						else if(Std.is(left, std.String) && Std.is(right, std.String))
							(left:String).length >= (right:String).length;
						else
							throw new RuntimeError(op, 'Operands must be two numbers or two strings.');
					case Less:
						if(Std.is(left, Float) && Std.is(right, Float))
							(left:Float) < (right:Float);
						else if(Std.is(left, std.String) && Std.is(right, std.String))
							(left:String).length < (right:String).length;
						else
							throw new RuntimeError(op, 'Operands must be two numbers or two strings.');
					case LessEqual:
						if(Std.is(left, Float) && Std.is(right, Float))
							(left:Float) <= (right:Float);
						else if(Std.is(left, std.String) && Std.is(right, std.String))
							(left:String).length <= (right:String).length;
						else
							throw new RuntimeError(op, 'Operands must be two numbers or two strings.');
					case BangEqual:
						!isEqual(left, right);
					case EqualEqual:
						isEqual(left, right);
					case _:
						null;
				}
			case Call(callee, paren, arguments):
				var callee = evalute(callee);
				var args = arguments.map(evalute);
				if(Std.is(callee, Callable)){
					var func:Callable = callee;
					var arity = func.arity();
					if(args.length != arity) throw new RuntimeError(paren, 'Expected $arity argument(s) but got ${args.length}.');
					func.call(this, args);
				} else {
					throw new RuntimeError(paren, 'Can only call functions');
				}
			case Grouping(e):
				evalute(e);
			case Variable(name):
				lookupVariable(name, expr);
		}
	}

	function lookupVariable(name:Token, expr:Expr) {
		var value =  switch locals.get(expr) {
			case null: globals.get(name);
			case distance: environment.getAt(distance, name.lexeme);
		}
		if(value == uninitializedVar) throw new RuntimeError(name, 'Accessing uninitialized variable "${name.lexeme}".');
		return value;
	}

	function isTruthy(v:Any):Bool {
		if(v == null) return false;
		if(Std.is(v, Bool)) return v;
		return true;
	}

	function isEqual(a:Any, b:Any) {
		if(a == null && b == null) return true;
		if(a == null) return false;
		return a == b;
	}

	function checkNumberOperand(op:Token, operand:Any) {
		if(Std.is(operand, Float)) return;
		throw new RuntimeError(op, 'Operand must be a number');
	}

	function checkNumberOperands(op:Token, left:Any, right:Any) {
		if(Std.is(left, Float) && Std.is(right, Float)) return;
		throw new RuntimeError(op, 'Operand must be a number');
	}

	function stringify(v:Any) {
		if(v == null) return 'null';

		return Std.string(v);
	}
}

abstract Locals(Map<{}, Int>) {
	public inline function new() this = new Map();
	public inline function get(expr:Expr):Null<Int> return this.get(cast expr); // this is a hack, depends on implementation details of ObjectMap
	public inline function set(expr:Expr, v:Int) this.set(cast expr, v); // this is a hack, depends on implementation details of ObjectMap
}

private class ClockCallable implements Callable {
	public function new() {}
	public function arity() return 0;
	public function call(interpreter:Interpreter, args:Array<Any>):Any return Sys.time();
	public function toString() return '<native fn>';
}

private class RandomRangeICallable implements Callable {
	public function new() {}
	public function arity() return 2;
	public function call(interpreter:Interpreter, args:Array<Any>):Any{
		return Math.round( Math.random() * (cast(args[0], Int) - cast(args[1], Int)) + cast(args[1], Int));
	}
	public function toString() return '<native fn>';
}
