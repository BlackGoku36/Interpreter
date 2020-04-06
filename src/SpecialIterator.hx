class SpecialIterator {
	var end:Int;
	var step:Int;
	var index:Int;
	var rev:Bool;

	public inline function new(start:Int, end:Int, step:Int, rev:Bool) {
		this.index = start;
		this.end = end;
		this.step = step;
		this.rev = rev;
		if(rev){
			var a = this.index;
			this.index = this.end;
			this.end = a;
		}
	}

	public inline function hasNext(){
		if(rev)return index > end;
		else return index < end;
	}

	public inline function next() {
		if(rev) return (index -= step) + step;
		else return (index += step) - step;
	}
}
