package tiled.com;

enum TShape {
	Point;
	Rectangle(w:Float, h:Float, rotation:Float);
	Ellipse(w:Float, h:Float, rotation:Float);
	Polygon(points:Array<{x:Float, y:Float}>);
}

class TObject {
	var tmap : TMap;
	public var name : Null<String>;
	public var type : Null<String>;

	// Coordinates in pixels
	public var x : Float;
	public var y : Float;

	// Coordinates in tiles
	public var cx(get,never) : Float; inline function get_cx() return x / tmap.tileWidth;
	public var cy(get,never) : Float; inline function get_cy() return y / tmap.tileHeight;

	public var tileId : Null<Int>;
	var props : Map<String,String> = new Map();

	public var shape(default, null):TShape;

	public function new(m:TMap, x:Float, y:Float, shape:TShape) {
		tmap = m;
		this.x = x;
		this.y = y;
		this.shape = shape;
	}

	public function toString() {
		return 'Obj:$name($type)@$shape';
	}

	public inline function isTile() return tileId!=null;

	public function getLocalTileId() {
		var l = tmap.getTileSet(tileId);
		if( l!=null )
			return tileId-l.baseId;
		else
			return tileId;
	}

	public function getTile() : Null<h2d.Tile> {
		if( !isTile() )
			return null;
		var l = tmap.getTileSet(tileId);
		if( l==null )
			return null;
		return l.getTile(tileId);
	}

	public function setProp(name, v) {
		props.set(name, v);
	}

	public inline function hasProp(name) {
		return props.exists(name);
	}

	public function getPropStr(name) : Null<String> {
		return props.get(name);
	}

	public function getPropInt(name) : Int {
		var v = getPropStr(name);
		return v==null ? 0 : Std.parseInt(v);
	}

	public function getPropFloat(name) : Float {
		var v = getPropStr(name);
		return v==null ? 0 : Std.parseFloat(v);
	}

	public function getPropBool(name) : Bool {
		var v = getPropStr(name);
		return v=="true";
	}
}
