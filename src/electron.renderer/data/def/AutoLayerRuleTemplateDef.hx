package data.def;

class AutoLayerRuleTemplateDef {
	#if heaps // Required to avoid doc generator to explore code too deeply

	@:allow(data.def.LayerDef, data.Definitions)
	public var ruleGroupUUID:Int = -1;
	public var tileId:Int = -1;
	public var replacements:Array<Array<Int>> = [];

	public function new() {
	}

	@:keep public function toString() {
		return 'RuleTemplate($ruleGroupUUID:$tileId)';
	}

	public function toJson() : ldtk.Json.AutoRuleTemplateDef {
		return {
			ruleGroupUUID: ruleGroupUUID,
			tileId: tileId,
			replacements: replacements.copy(),
		}
	}

	public static function fromJson(jsonVersion:String, json:ldtk.Json.AutoRuleTemplateDef) {
		var r = new AutoLayerRuleTemplateDef();

		if( json != null ) {
			r.ruleGroupUUID = JsonTools.readInt(json.ruleGroupUUID, -1);
			r.tileId = JsonTools.readInt(json.tileId, -1);
			r.replacements = json.replacements;
		}

		return r;
	}

	#end
}