package tiled;

import tiled.com.TObject.TShape;
import tiled.com.*;

@:allow(tiled.com.TObject)
@:allow(tiled.com.TLayer)
class TMap {
	public var width(default, null):Int;
	public var height(default, null):Int;
	public var tileWidth(default, null):Int;
	public var tileHeight(default, null):Int;

	public var tilesets : Array<TTileset> = [];
	public var layers : Array<TLayer> = [];
	public var objects : Map<String, Array<TObject>> = new Map();
	var props : Map<String,String> = new Map();

	public var bgColor : Null<UInt>;

	private function htmlHexToInt(s:String) : Null<UInt> {
		if( s.indexOf("#") == 0 )
			return Std.parseInt("0x" + s.substring(1));

		return null;
	}

	public function new(tmxRes:hxd.res.Resource) {
		var folder = tmxRes.entry.directory;
		var xml = new haxe.xml.Access( Xml.parse(tmxRes.entry.getText()) );
		xml = xml.node.map;

		width = Std.parseInt( xml.att.width );
		height = Std.parseInt( xml.att.height );
		tileWidth = Std.parseInt( xml.att.tilewidth );
		tileHeight = Std.parseInt( xml.att.tileheight );
		bgColor = xml.has.backgroundcolor ? htmlHexToInt(xml.att.backgroundcolor) : null;

		// Parse tilesets
		for(t in xml.nodes.tileset) {
			var set = readTileset(folder, t.att.source, Std.parseInt( t.att.firstgid ));
			tilesets.push(set);
		}

		// Parse layers
		for(l in xml.nodes.layer) {
			var layer = new TLayer( this, Std.string(l.att.name), Std.parseInt(l.att.id), Std.parseInt(l.att.width), Std.parseInt(l.att.height) );
			layers.push(layer);

			// Properties
			if( l.hasNode.properties )
				for(p in l.node.properties.nodes.property)
					layer.setProp(p.att.name, p.att.value);

			// Tile IDs
			var data = l.node.data;
			switch( data.att.encoding ) {
				case "csv" :
					layer.setIds( data.innerHTML.split(",").map( function(id:String) : UInt {
						var f = Std.parseFloat(id);
						if( f > 2147483648. ) // dirty fix for Float>UInt casting issue when "bit #32" is set
							return ( cast (f-2147483648.) : UInt ) | (1<<31);
						else
							return ( cast f : UInt );
					}) );

				case _ : throw "Unsupported layer encoding "+data.att.encoding+" in "+tmxRes.entry.path;
			}
		}

		// Parse objects
		for(ol in xml.nodes.objectgroup) {
			objects.set(ol.att.name, []);

			for(o in ol.nodes.object) {
                var shape:TShape = Point;
                var width:Float = 0;
                var height:Float = 0;

                // All objects should have coordinates
                var x = Std.parseFloat(o.att.x);
                var y = Std.parseFloat(o.att.y);

                if (o.hasNode.ellipse) {
                    var rotation = 0.0;
                    if (o.has.rotation) {
						rotation = degToRad(Std.parseFloat(o.att.rotation));
					}

                    shape = Ellipse(Std.parseFloat(o.att.width),
                                    Std.parseFloat(o.att.height),
                                    rotation);

                } else if (o.hasNode.polygon) {
                    var points = new Array<{x:Float, y:Float}>();
                    var arr = o.node.polygon.att.points.split(" ");
                    for (a in arr) {
                        var point = a.split(",");
                        points.push({x:Std.parseFloat(point[0]), y:Std.parseFloat(point[1])});
                    }

                    shape = Polygon(points);
                } else if (o.has.width && o.has.height) {
                    var rotation = 0.0;
					if (o.has.rotation) {
						rotation = degToRad(Std.parseFloat(o.att.rotation));
					}

                    shape = Rectangle(Std.parseFloat(o.att.width),
                                    Std.parseFloat(o.att.height),
                                    rotation);
                }

				var tobj = new TObject(this, x, y, shape);
				if (o.has.name) tobj.name = o.att.name;
				if (o.has.type) tobj.type = o.att.type;

				// Properties
				if( o.hasNode.properties ) {
					for(p in o.node.properties.nodes.property) {
						tobj.setProp(p.att.name, p.att.value);
					}
				}

				objects.get(ol.att.name).push(tobj);
			}
		}

		// Parse map properties
		if (xml.hasNode.properties) {
			for (p in xml.node.properties.nodes.property)
				setProp(p.att.name, p.att.value);
		}
	}

	public function getLayer(name:String) : Null<TLayer> {
		for (l in layers)
			if (l.name == name)
				return l;

		return null;
	}

	public function getObject(layer:String, name:String) : Null<TObject> {
		if( !objects.exists(layer) )
			return null;

		for(o in objects.get(layer))
			if( o.name==name )
				return o;

		return null;
	}


	public function getObjects(layer:String, ?type:String) : Array<TObject> {
		if( !objects.exists(layer) )
			return [];

		return type==null ? objects.get(layer) : objects.get(layer).filter( function(o) return o.type==type );
	}

	public function getPointObjects(layer:String, ?type:String) : Array<TObject> {
		if( !objects.exists(layer) )
			return [];

		return objects.get(layer).filter( function(o) return o.shape.match(Point) && ( type==null || o.type==type ) );
	}

	public function getRectObjects(layer:String, ?type:String) : Array<TObject> {
		if( !objects.exists(layer) )
			return [];

		return objects.get(layer).filter( function(o) return o.shape.match(Rectangle(_, _, _)) && ( type==null || o.type==type ) );
	}


	public function renderLayerBitmap(l:TLayer, ?p) : h2d.Object {
		var wrapper = new h2d.Object(p);
		var cx = 0;
		var cy = 0;
		for(id in l.getIds()) {
			if( id!=0 ) {
				var b = new h2d.Bitmap(getTile(id), wrapper);
				b.setPosition(cx*tileWidth, cy*tileHeight);
				if( l.isXFlipped(cx,cy) ) {
					b.scaleX = -1;
					b.x+=tileWidth;
				}
				if( l.isYFlipped(cx,cy) ) {
					b.scaleY = -1;
					b.y+=tileHeight;
				}
			}

			cx++;
			if( cx>=width ) {
				cx = 0;
				cy++;
			}
		}
		return wrapper;
	}


	public function getTiles(l:TLayer) : Array<{ t:h2d.Tile, x:Int, y:Int }> {
		var out = [];
		var cx = 0;
		var cy = 0;
		for(id in l.getIds()) {
			if( id!=0 )
				out.push({
					t : getTile(id),
					x : cx*tileWidth,
					y : cy*tileHeight,
				});

			cx++;
			if( cx>=width ) {
				cx = 0;
				cy++;
			}
		}
		return out;
	}

	function getTileSet(tileId:Int) : Null<TTileset> {
		for(set in tilesets)
			if( tileId>=set.baseId && tileId<=set.lastId )
				return set;
		return null;
	}

	inline function getTile(tileId:Int) : Null<h2d.Tile> {
		var s = getTileSet(tileId);
		return s!=null ? s.getTile(tileId) : null;
	}

	function readTileset(folder:String, fileName:String, baseIdx:Int) : TTileset {
		var folderUnstack = folder.split("/");
		var fileUnstack = fileName.split("/");
		while (fileUnstack[0] == "..") {
			fileUnstack.shift();
			folderUnstack.pop();
		}

		folder = folderUnstack.length > 0 ? folderUnstack.join("/") + "/" : "";
		fileName = fileUnstack.join("/");

		var file = try hxd.Res.load(folder+fileName)
			catch(e:Dynamic) throw "File not found "+fileName;

		var xml = new haxe.xml.Access( Xml.parse(file.entry.getText()) ).node.tileset;
		var tile = hxd.Res.load(file.entry.directory + "/" +xml.node.image.att.source).toTile();

		var e = new TTileset(xml.att.name, tile, Std.parseInt(xml.att.tilewidth), Std.parseInt(xml.att.tileheight), baseIdx);
		return e;
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

	public inline static function radToDeg(rad:Float):Float {
		return 180 / Math.PI * rad;
	}

	public inline static function degToRad(deg:Float):Float {
		return Math.PI / 180 * deg;
	}
}
