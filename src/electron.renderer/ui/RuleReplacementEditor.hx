package ui;

import haxe.ds.IntMap;

class RuleReplacementEditor {
	public var jRoot : js.jquery.JQuery;

	var template : data.def.AutoLayerRuleTemplateDef;
	var sourceDef : data.def.LayerDef;
	var layerDef : data.def.LayerDef;
	var previewMode : Bool;
	var explainCell : Null< (desc:Null<String>)->Void >;
	var getSelectedValIdx: Null< Void->Int >;
	var onChange: Null< Void->Void >;

	public function new(
		template: data.def.AutoLayerRuleTemplateDef,
		sourceDef: data.def.LayerDef,
		layerDef: data.def.LayerDef,
		previewMode=false,
		?explainCell: (desc:Null<String>)->Void,
		?getSelectedValIdx: Void->Int,
		?onChange: Void->Void
	) {
		this.template = template;
		this.sourceDef = sourceDef;
		this.layerDef = layerDef;
		this.previewMode = previewMode;
		this.explainCell = explainCell;
		this.getSelectedValIdx = getSelectedValIdx;
		this.onChange = onChange;

		jRoot = new J('<div/>');

		cleanupTemplate();
		render();
	}

	private function cleanupTemplate() {
		var newReplacements:IntMap<Int> = new IntMap<Int>();
		function add(val:Int) {
			if( val == 0 ) {
				return;
			}
			if( newReplacements.exists(val)) {
				return;
			}
			for(replacement in template.replacements) {
				if( replacement[0] == val ) {
					newReplacements.set( replacement[0], replacement[1] );
					return;
				}
			}
			newReplacements.set( val, val );
		}
		var ruleGroup = layerDef.getRuleGroupByUid(template.ruleGroupUUID);
		if (ruleGroup != null) {
			for( rule in ruleGroup.rules ) {
				rule.forEach(val->add(M.iabs(val)));
			}
		}
		this.template.replacements = [];
		for( key in newReplacements.keys() ) {
			this.template.replacements.push( [key, newReplacements.get(key)] );
		}
	}


	inline function isEditable() return onChange!=null;

	function createCell() {
		var jCell = new J('<div class="cell"/>');
		jCell.appendTo(jRoot);
		return jCell;
	}

	function render() {
		// Init root
		jRoot.empty().off();
		jRoot.removeClass();

		jRoot.addClass("autoPatternGrid");
		jRoot.addClass("replacementEditor");

		if( isEditable() )
			jRoot.addClass("editable");

		if( previewMode )
			jRoot.addClass("preview");

		// Add a rollover tip
		function addExplain(jTarget:js.jquery.JQuery, desc:String) {
			if( explainCell==null )
				return;

			jTarget
				.mouseover( function(_) {
					explainCell(desc);
				})
				.mouseout( function(_) {
					explainCell(null);
				});
		}


		for(replacement in template.replacements) {
			// Cell wrapper
			var jFromCell = createCell();
			var jShift = new J('<div class="shift"/>');
			jShift.appendTo(jRoot);
			var jToCell = createCell();

			// Cell color
			var fromVal = replacement[0];
			var toVal = replacement[1];
			// Required value
			if( sourceDef.hasIntGridValue(fromVal) ) {
				jFromCell.css("background-color", C.intToHex( sourceDef.getIntGridValueDef(fromVal).color ) );
				addExplain(jFromCell, 'This cell should contain "${sourceDef.getIntGridValueDisplayName(fromVal)}" to match.');
			}
			if( sourceDef.hasIntGridValue(toVal) ) {
				jToCell.css("background-color", C.intToHex( sourceDef.getIntGridValueDef(toVal).color ) );
				addExplain(jToCell, 'This cell should contain "${sourceDef.getIntGridValueDisplayName(toVal)}" to match.');
			}

			// Edit grid value
			if( isEditable() ) {
				jToCell.addClass("editable");

				jToCell.mousedown( (ev:js.jquery.Event)->{
					if( ev.button  == 0) {
						replacement[1] = getSelectedValIdx()+1;
						render();
						onChange();
					}
					if( ev.button  == 2) {
						replacement[1] = replacement[0];
						render();
						onChange();
					}
				});
			}
		}

		return jRoot;
	}
}