package ui.modal.dialog;

import data.def.AutoLayerRuleTemplateDef;
import data.DataTypes;

class RuleEditor extends ui.modal.Dialog {
	var curValIdx = 0;
	var layerDef : data.def.LayerDef;
	var sourceDef : data.def.LayerDef;
	var rule : data.def.AutoLayerRuleDef;
	var guidedMode = false;

	public function new(layerDef:data.def.LayerDef, rule:data.def.AutoLayerRuleDef) {
		super("ruleEditor");

		this.layerDef = layerDef;
		this.rule = rule;
		sourceDef = layerDef.type==IntGrid ? layerDef : project.defs.getLayerDef( layerDef.autoSourceLayerDefUid );

		renderAll();
	}

	override function onGlobalEvent(e:GlobalEvent) {
		super.onGlobalEvent(e);
		switch(e) {
			case LayerRuleChanged(rule):

			case _:
		}
	}

	function enableGuidedMode() {
		guidedMode = true;
		jContent.addClass("guided");
		jContent.find(".disableTip").removeClass("disableTip");
		jContent.find(".explain").show();
	}


	override function close() {
		super.close();

		if( rule.isEmpty() ) {
			for(rg in layerDef.autoRuleGroups)
				rg.rules.remove(rule);
			editor.ge.emit( LayerRuleRemoved(rule) );
		}
		else if( rule.tidy() )
			editor.ge.emit( LayerRuleChanged(rule) );
	}


	function updateTileSettings() {
		var jTilesSettings = jContent.find(".tileSettings");
		jTilesSettings.off();

		// Tile mode
		var jModeSelect = jContent.find("select[name=tileMode]");
		jModeSelect.empty();
		var i = new form.input.EnumSelect(
			jModeSelect,
			ldtk.Json.AutoLayerRuleTileMode,
			()->rule.tileMode,
			(v)->rule.tileMode = v,
			(v)->switch v {
				case Single: Lang.t._("Random tiles");
				case Stamp: Lang.t._("Rectangle of tiles");
				case Template: Lang.t._("Template");
			}
		);
		i.linkEvent( LayerRuleChanged(rule) );
		i.onChange = function() {
			rule.tileIds = [];
			rule.template = rule.tileMode == Template ? new AutoLayerRuleTemplateDef() : null;
			updateTileSettings();
		}

		// Tile(s)
		var jTilePicker = JsTools.createTilePicker(
			layerDef.autoTilesetDefUid,
			switch (rule.tileMode) {
				case Single: MultiTiles;
				case Stamp: RectOnly;
				case Template: SingleTile;
			},
			rule.tileIds,
			function(tids) {
				rule.tileIds = tids.copy();
				editor.ge.emit( LayerRuleChanged(rule) );
				updateTileSettings();
			}
		);
		jTilesSettings.find(">.picker").empty().append( jTilePicker );

		// Pivot (optional)
		var jTileOptions = jTilesSettings.find(">.options").empty();
		switch rule.tileMode {
			case Template:
			case Single:
			case Stamp:
				var jPivot = JsTools.createPivotEditor(rule.pivotX, rule.pivotY, (xr,yr)->{
					rule.pivotX = xr;
					rule.pivotY = yr;
					editor.ge.emit( LayerRuleChanged(rule) );
					updateTileSettings();
				});
				jTileOptions.append(jPivot);
		}

		updatePatternEditor();

		updateValuePicker();
	}

	function updateTemplateTilePicker() {
		var jExplain = jContent.find(".explain");

		var td = Editor.ME.project.defs.getTilesetDef(sourceDef.autoTilesetDefUid);

		var jTemplateTilePicker = jContent.find(">.pattern .templateEditor .templateTilePicker");
		var jTemplateEditorGrid = jContent.find(">.pattern .templateEditor .grid");
		jTemplateEditorGrid.empty();
		var ruleGroup = layerDef.getRuleGroupByUid(rule.template.ruleGroupUUID);
		if (ruleGroup != null) {
			var patternEditor = new RuleReplacementEditor(rule.template, sourceDef, layerDef, (str:String) -> {
				if (str == null)
					jExplain.empty();
				else {
					if (str.indexOf("\\n") >= 0)
						str = "<p>" + str.split("\\n").join("</p><p>") + "</p>";
					jExplain.html(str);
				}
			}, () -> curValIdx, () -> editor.ge.emit(LayerRuleChanged(rule)));
			jTemplateEditorGrid.empty().append(patternEditor.jRoot);
			var visibleTileIds = [];
			for (rule in ruleGroup.rules) {
				for (tileId in rule.tileIds) {
					visibleTileIds.push( tileId );
					/*
					var jDiv = new J('<div/>');
					jDiv.addClass("gridEntry");
					var jTile = JsTools.createTile(td, tileId, 32);
					if (this.rule.templateTileIds[0] == -1 || tileId == this.rule.templateTileIds[0]) {
						jDiv.addClass("active");
						this.rule.templateTileIds[0] = tileId;
					}
					jDiv.append(jTile);
					jTemplateEditorGrid.append(jDiv);
					jDiv.click(function(ev) {
						this.rule.templateTileIds[0] = tileId;
						updateTemplateTilePicker();
					});
					*/
				}
			}
			// Tile(s)
			var tids = [];
			if( this.rule.template.tileId != -1 ) tids.push( this.rule.template.tileId );
			var jTilePicker = JsTools.createTilePicker(
				layerDef.autoTilesetDefUid,
				SingleTile,
				tids,
				visibleTileIds,
				function(tids) {
					this.rule.template.tileId = tids[0];
					updateTemplateTilePicker();
				}
			);
			jTemplateTilePicker.empty().append( jTilePicker );
		}
	}

	function updatePatternEditor() {
		// Mini explanation tip
		var jExplain = jContent.find(".explain").hide();

		var jPatternEditor = jContent.find(">.pattern .editor");
		var jTemplateEditor = jContent.find(">.pattern .templateEditor");

		if (rule.tileMode == Template) {
			jPatternEditor.hide();
			jTemplateEditor.show();

			var jTemplateEditorSelect = jTemplateEditor.find("select[name=template]");
			jTemplateEditorSelect.empty();
			var jOpt = new J('<option selected data-default default/>');
			jOpt.appendTo(jTemplateEditorSelect);
			jOpt.attr("value", -1);
			jOpt.text("-- Select Template --");
			for (ruleGroup in layerDef.autoRuleGroups) {
				if (ruleGroup.rules.length > 0 &&
					ruleGroup.rules.contains(rule) == false) {
					var jOpt = new J('<option/>');
					jOpt.appendTo(jTemplateEditorSelect);
					jOpt.attr("value", ruleGroup.uid);
					jOpt.text(ruleGroup.name);
				}
			}

			jTemplateEditorSelect.val(rule.template.ruleGroupUUID);
			updateTemplateTilePicker();
			jTemplateEditorSelect.change(function(ev) {
				var templateUUID:Int = Std.parseInt(jTemplateEditorSelect.val());
				rule.template.ruleGroupUUID = templateUUID;
				updateTemplateTilePicker();
			});
		} else {
			jPatternEditor.show();
			jTemplateEditor.hide();
			// Pattern grid editor
			var patternEditor = new RulePatternEditor(rule, sourceDef, layerDef, (str:String) -> {
				if (str == null)
					jExplain.empty();
				else {
					if (str.indexOf("\\n") >= 0)
						str = "<p>" + str.split("\\n").join("</p><p>") + "</p>";
					jExplain.html(str);
				}
			}, () -> curValIdx, () -> editor.ge.emit(LayerRuleChanged(rule)));
			var jPatternEditorGrid = jPatternEditor.find(".grid");
			jPatternEditorGrid.empty().append(patternEditor.jRoot);

			// Grid size selection
			var jSizes = jPatternEditor.find("select").empty();
			var s = -1;
			var sizes = [while (s < Const.MAX_AUTO_PATTERN_SIZE) s += 2];
			for (size in sizes) {
				var jOpt = new J('<option value="$size">${size}x$size</option>');
				// if( size>=7 )
				// 	jOpt.append(" (WARNING: might slow-down app)");
				jOpt.appendTo(jSizes);
			}
			jSizes.change(function(_) {
				var size = Std.parseInt(jSizes.val());
				rule.resize(size);
				editor.ge.emit(LayerRuleChanged(rule));
				renderAll();
			});
			jSizes.val(rule.size);
		}
	}

	function updateValuePicker() {
		var jValues = jContent.find(">.pattern .values ul").empty();

		// Values picker
		var idx = 0;
		for(v in sourceDef.getAllIntGridValues()) {
			var jVal = new J('<li/>');
			jVal.appendTo(jValues);

			jVal.css("background-color", C.intToHex(v.color));
			jVal.text( v.identifier!=null ? v.identifier : '#$idx' );

			if( idx==curValIdx )
				jVal.addClass("active");

			var i = idx;
			jVal.click( function(ev) {
				curValIdx = i;
				editor.ge.emit( LayerRuleChanged(rule) );
				updateValuePicker();
			});
			idx++;
		}

		if (rule.tileMode != Template) {
			// "Anything" value
			var jVal = new J('<li/>');
			jVal.appendTo(jValues);
			jVal.addClass("any");
			jVal.text("Anything");
			if( curValIdx==Const.AUTO_LAYER_ANYTHING )
				jVal.addClass("active");
			jVal.click( function(ev) {
				curValIdx = Const.AUTO_LAYER_ANYTHING;
				editor.ge.emit( LayerRuleChanged(rule) );
				updateValuePicker();
			});

		}
	}

	function renderAll() {

		loadTemplate("ruleEditor");
		jContent.find("[data-title],[title]").addClass("disableTip"); // removed on guided mode

		// Guided mode button
		jContent.find("button.guide").click( (_)->{
			enableGuidedMode();
		} );
		jContent.find(".debugInfos").text('#${rule.uid}');

		updateTileSettings();

		if( guidedMode )
			enableGuidedMode();
	}

}