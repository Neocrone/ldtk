package data.def;

class AutoLayerRuleDef {
	#if heaps // Required to avoid doc generator to explore code too deeply

	@:allow(data.def.LayerDef, data.Definitions)
	public var uid(default,null) : Int;

	public var tileIds : Array<Int> = [];
	public var chance : Float = 1.0;
	public var breakOnMatch = true;
	public var size(default,null): Int;
	var pattern : Array<Int> = [];
	public var flipX = false;
	public var flipY = false;
	public var active = true;
	public var tileMode : ldtk.Json.AutoLayerRuleTileMode = Single;
	public var pivotX = 0.;
	public var pivotY = 0.;
	public var xModulo = 1;
	public var yModulo = 1;
	public var checker : ldtk.Json.AutoLayerRuleCheckerMode = None;

	public var template : AutoLayerRuleTemplateDef;

	var perlinActive = false;
	public var perlinSeed : Int;
	public var perlinScale : Float = 0.2;
	public var perlinOctaves = 2;
	var _perlin(get,null) : Null<hxd.Perlin>;

	public function new(uid, size=3) {
		if( !isValidSize(size) )
			throw 'Invalid rule size ${size}x$size';

		this.uid = uid;
		this.size = size;
		perlinSeed = Std.random(9999999);
		initPattern();
	}

	inline function isValidSize(size:Int) {
		return size>=1 && size<=Const.MAX_AUTO_PATTERN_SIZE && size%2!=0;
	}

	inline function get__perlin() {
		if( perlinSeed!=null && _perlin==null ) {
			_perlin = new hxd.Perlin();
			_perlin.normalize = true;
			_perlin.adjustScale(50, 1);
		}

		if( perlinSeed==null && _perlin!=null )
			_perlin = null;

		return _perlin;
	}

	public inline function hasPerlin() return perlinActive;

	public function setPerlin(active:Bool) {
		if( !active ) {
			perlinActive = false;
			_perlin = null;
		}
		else
			perlinActive = true;
	}

	public function isSymetricX() {
		for( cx in 0...Std.int(size*0.5) )
		for( cy in 0...size )
			if( pattern[coordId(cx,cy)] != pattern[coordId(size-1-cx,cy)] )
				return false;

		return true;
	}

	public function isSymetricY() {
		for( cx in 0...size )
		for( cy in 0...Std.int(size*0.5) )
			if( pattern[coordId(cx,cy)] != pattern[coordId(cx,size-1-cy)] )
				return false;

		return true;
	}

	public inline function get(cx,cy) {
		return pattern[ coordId(cx,cy) ];
	}

	public inline function set(cx,cy,v) {
		// clearOptim();
		return isValid(cx,cy) ? pattern[ coordId(cx,cy) ] = v : 0;
	}

	public inline function forEach(callback:Int->Void) {
		for( p in pattern ) {
			callback(p);
		}
	}

	function initPattern() {
		pattern = [];
		for(i in 0...size*size)
			pattern[i] = 0;
	}

	@:keep public function toString() {
		return 'Rule#$uid(${size}x$size)';
	}

	public function toJson() : ldtk.Json.AutoRuleDef {
		tidy();

		return {
			uid: uid,
			active: active,
			size: size,
			tileIds: tileIds.copy(),
			chance: JsonTools.writeFloat(chance),
			breakOnMatch: breakOnMatch,
			pattern: pattern.copy(), // WARNING: could leak to undo/redo leaks if (one day) pattern contained objects
			flipX: flipX,
			flipY: flipY,
			xModulo: xModulo,
			yModulo: yModulo,
			checker: JsonTools.writeEnum(checker, false),
			tileMode: JsonTools.writeEnum(tileMode, false),
			pivotX: JsonTools.writeFloat(pivotX),
			pivotY: JsonTools.writeFloat(pivotY),

			template: template != null ? template.toJson() : null,

			perlinActive: perlinActive,
			perlinSeed: perlinSeed,
			perlinScale: JsonTools.writeFloat(perlinScale),
			perlinOctaves: perlinOctaves,
		}
	}

	public static function fromJson(jsonVersion:String, json:ldtk.Json.AutoRuleDef) {
		var r = new AutoLayerRuleDef( json.uid, json.size );
		r.active = JsonTools.readBool(json.active, true);
		r.tileIds = json.tileIds;
		r.breakOnMatch = JsonTools.readBool(json.breakOnMatch, false); // default to FALSE to avoid breaking old maps
		r.chance = JsonTools.readFloat(json.chance);
		r.pattern = json.pattern;
		r.flipX = JsonTools.readBool(json.flipX, false);
		r.flipY = JsonTools.readBool(json.flipY, false);
		r.checker = JsonTools.readEnum(ldtk.Json.AutoLayerRuleCheckerMode, json.checker, false, None);
		r.tileMode = JsonTools.readEnum(ldtk.Json.AutoLayerRuleTileMode, json.tileMode, false, Single);
		r.pivotX = JsonTools.readFloat(json.pivotX, 0);
		r.pivotY = JsonTools.readFloat(json.pivotY, 0);
		r.xModulo = JsonTools.readInt(json.xModulo, 1);
		r.yModulo = JsonTools.readInt(json.yModulo, 1);

		if( r.tileMode == Template ) {
			r.template = AutoLayerRuleTemplateDef.fromJson(jsonVersion, json.template);
		}

		r.perlinActive = JsonTools.readBool(json.perlinActive, false);
		r.perlinScale = JsonTools.readFloat(json.perlinScale, 0.2);
		r.perlinOctaves = JsonTools.readInt(json.perlinOctaves, 2);
		r.perlinSeed = JsonTools.readInt(json.perlinSeed, Std.random(9999999));

		return r;
	}



	public function resize(newSize:Int) {
		if( !isValidSize(newSize) )
			throw 'Invalid rule size ${size}x$size';

		var oldSize = size;
		var oldPatt = pattern.copy();
		var pad = Std.int( dn.M.iabs(newSize-oldSize) / 2 );

		size = newSize;
		initPattern();
		if( newSize<oldSize ) {
			// Decrease
			for( cx in 0...newSize )
			for( cy in 0...newSize )
				pattern[cx + cy*newSize] = oldPatt[cx+pad + (cy+pad)*oldSize];
		}
		else {
			// Increase
			for( cx in 0...oldSize )
			for( cy in 0...oldSize )
				pattern[cx+pad + (cy+pad)*newSize] = oldPatt[cx + cy*oldSize];
		}
	}

	inline function coordId(cx,cy) return cx+cy*size;
	inline function isValid(cx,cy) {
		return cx>=0 && cx<size && cy>=0 && cy<size;
	}

	public function trim() {
		while( size>1 ) {
			var emptyBorder = true;
			for( cx in 0...size )
				if( pattern[coordId(cx,0)]!=0 || pattern[coordId(cx,size-1)]!=0 ) {
					emptyBorder = false;
					break;
				}
			for( cy in 0...size )
				if( pattern[coordId(0,cy)]!=0 || pattern[coordId(size-1,cy)]!=0 ) {
					emptyBorder = false;
					break;
				}

			if( emptyBorder )
				resize(size-2);
			else
				return false;
		}

		return true;
	}

	public function isEmpty() {
		for(v in pattern)
			if( v!=0 )
				return false;

		return tileIds.length==0;
	}

	public function isUsingUnknownIntGridValues(ld:LayerDef) {
		if( ld.type!=IntGrid )
			throw "Invalid layer type";

		var v = 0;
		for(px in 0...size)
		for(py in 0...size) {
			v = dn.M.iabs( pattern[px+py*size] );
			if( v!=0 && v!=Const.AUTO_LAYER_ANYTHING+1 && !ld.hasIntGridValue(v) )
				return true;
		}

		return false;
	}

	public function matchesDefault(source:data.inst.LayerInstance, cx:Int, cy:Int, dirX = 1, dirY = 1, overrider = null) {
		// Rule check
		var radius = Std.int(size / 2);
		for (px in 0...size) {
			for (py in 0...size) {
				var coordId = px + py * size;
				if (pattern[coordId] == 0)
					continue;

				var x = cx + dirX * (px - radius);
				var y = cy + dirY * (py - radius);

				if (!source.isValid(x, y))
					return [];

				if (dn.M.iabs(pattern[coordId]) == Const.AUTO_LAYER_ANYTHING + 1) {
					// "Anything" checks
					if (pattern[coordId] > 0 && !source.hasIntGrid(x, y))
						return [];

					if (pattern[coordId] < 0 && source.hasIntGrid(x, y))
						return [];
				} else {
					var patternValue = pattern[coordId];
					if (overrider != null) {
						patternValue = overrider(patternValue);
					}
					// Specific value checks
					if (patternValue > 0 && source.getIntGrid(x, y) != patternValue)
						return [];

					if (patternValue < 0 && source.getIntGrid(x, y) == -patternValue)
						return [];
				}
			}
		}
		return tileIds;
	}

	public function matchesTemplate(li:data.inst.LayerInstance, source:data.inst.LayerInstance, cx:Int, cy:Int, dirX = 1, dirY = 1) {
		var layerDef = source.def;
		var ruleGroup = layerDef.getRuleGroupByUid(template.ruleGroupUUID);
		var tileSet = li.getTiledsetDef();
		var offsetX = tileSet.getTileCx(this.tileIds[0]) - tileSet.getTileCx(this.template.tileId);
		var offsetY = tileSet.getTileCy(this.tileIds[0]) - tileSet.getTileCy(this.template.tileId);
		if (ruleGroup != null) {
			for (rule in ruleGroup.rules) {
				var tileIds:Array<Int>;
				if ((tileIds = rule.matches(li, source, cx, cy, dirX, dirY, function(v) {
					if( v == 0 ) return 0;
					var absV = M.iabs( v );
					for( replacement in template.replacements) {
						if( replacement[0] == absV ) {
							absV = replacement[1];
							break;
						}
					}
					switch (v) {
						case v if (v > 0):
							return absV;
						case v if (v < 0):
							return -absV;
						case _:
							return 0;
					}
				})).length > 0) {
					if (tileSet != null) {
						tileIds = tileIds.map(tileId -> tileSet.getTileId(tileSet.getTileCx(tileId) + offsetX, tileSet.getTileCy(tileId) + offsetY));
					}
					return tileIds;
				}
			}
		}
		return [];
	}

	public function matches(li:data.inst.LayerInstance, source:data.inst.LayerInstance, cx:Int, cy:Int, dirX = 1, dirY = 1, overrider:Int->Int = null) {
		if (tileIds.length == 0)
			return [];

		if (chance <= 0 || chance < 1 && dn.M.randSeedCoords(li.seed + uid, cx, cy, 100) >= chance * 100)
			return [];

		if (hasPerlin() && _perlin.perlin(li.seed + perlinSeed, cx * perlinScale, cy * perlinScale, perlinOctaves) < 0)
			return [];

		switch this.tileMode {
			case Single:
				return matchesDefault(source, cx, cy, dirX, dirY, overrider);
			case Stamp:
				return matchesDefault(source, cx, cy, dirX, dirY, overrider);
			case Template:
				return matchesTemplate(li, source, cx, cy, dirX, dirY);
		}
		return [];
	}

	public function tidy() {
		var anyFix = false;

		if( flipX && isSymetricX() ) {
			App.LOG.add("tidy", 'Fixed X symetry of Rule#$uid');
			flipX = false;
			anyFix = true;
		}

		if( flipY && isSymetricY() ) {
			App.LOG.add("tidy", 'Fixed Y symetry of Rule#$uid');
			flipY = false;
			anyFix = true;
		}

		if( xModulo==1 && yModulo==1 && checker!=None ) {
			App.LOG.add("tidy", 'Fixed checker mode of Rule#$uid');
			checker = None;
			anyFix = true;
		}

		if( trim() )
			anyFix = true;

		return anyFix;
	}

	public function getRandomTileForCoord(seed:Int, cx:Int,cy:Int) : Int {
		return tileIds[ dn.M.randSeedCoords( seed, cx,cy, tileIds.length ) ];
	}

	#end
}