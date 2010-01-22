﻿/**
 * Copyright (C) 2009 Philipp Heim, Sebastian Hellmann, Jens Lehmann, Steffen Lohmann and Timo Stegemann
 * 
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along with this program; if not, see <http://www.gnu.org/licenses/>.
 */ 

 
import com.adobe.flex.extras.controls.springgraph.Graph;
import com.dynamicflash.util.Base64;
import com.hillelcoren.components.AutoComplete;
import com.hillelcoren.components.autoComplete.classes.SelectedItem;
import connection.config.Config;
import connection.config.IConfig;
import connection.model.LookUpCache;
import flash.display.DisplayObject;
import flash.geom.Point;
import global.GlobalString;
import global.ToolTipModel;
import mx.collections.Sort;
import mx.collections.SortField;
import mx.containers.Canvas;
import mx.containers.HBox;
import mx.containers.TabNavigator;
import mx.controls.DataGrid;
import mx.controls.Menu;
import mx.core.ClassFactory;
import mx.core.Repeater;
import mx.events.CloseEvent;
import mx.events.FlexEvent;
import mx.events.MenuEvent;
import mx.managers.ToolTipManager;
import mx.rpc.events.FaultEvent;
import mx.rpc.http.HTTPService;
import mx.utils.ObjectUtil;
import mx.utils.StringUtil;
import utils.ConfigUtil;
import utils.Example;
import utils.ExampleUtil;

import connection.ILookUp;
import connection.ISPARQLResultParser;
import connection.LookUpKeywordSearch;
import connection.SPARQLConnection;
import connection.SPARQLResultParser;
import connection.config.DBpediaConfig;
import connection.config.LODConfig;
import connection.model.ConnectionModel;

import de.polygonal.ds.ArrayedQueue;
import de.polygonal.ds.HashMap;
import de.polygonal.ds.Iterator;

import flash.desktop.Clipboard;
import flash.desktop.ClipboardFormats;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.TextEvent;
import flash.events.TimerEvent;
import flash.utils.Dictionary;
import flash.utils.Timer;

import global.Languages;
import global.StatusModel;

import graphElements.*;

import mx.collections.ArrayCollection;
import mx.controls.Alert;
import mx.core.Application;
import mx.managers.PopUpManager;
import mx.rpc.events.ResultEvent;

import popup.ErrorLog;
import popup.ExpertSettings;
import popup.Infos;
import popup.InputDisambiguation;
import popup.InputSelection;
import popup.InputSelectionEvent;

import toolTip.SelectedItemToolTipRenderer;

[Bindable]
private var graph:Graph = new Graph(); /*~*/
private var foundNodes:HashMap = new HashMap(); /*~*/
private var givenNodes:HashMap = new HashMap(); /*~*/
private var givenNodesInsertionTime:HashMap = new HashMap(); /*~*/
private var _relationNodes:HashMap = new HashMap(); /*~*/
private var relations:HashMap = new HashMap(); /*~*/
private var elements:HashMap = new HashMap(); /*~*/
private var toDrawPaths:ArrayedQueue = new ArrayedQueue(1000); /*~*/
//private var iter:Iterator;
//[Bindable]
//public var currentNode:MyNode = null;	//the currently selected node in the graph
private var _selectedElement:Element = null;	//so ist es besser!

private var myConnection:SPARQLConnection = null;
private var sparqlEndpoint:String = "";
private var basicGraph:String = "";
private var resultParser:ISPARQLResultParser = new SPARQLResultParser();

private var lastInputs:Array = new Array();


[Bindable]
private var autoCompleteList:ArrayCollection = new ArrayCollection();

private var filterSort:Sort = new Sort();
private var sortByLabel:SortField = new SortField("label", true);

[Bindable]
private var _concepts:ArrayCollection = new ArrayCollection();
private var _selectedConcept:Concept = null;

[Bindable]
private var _connectivityLevels:ArrayCollection = new ArrayCollection();
private var _selectedConnectivityLevel:ConnectivityLevel = null;

[Bindable]
private var _relTypes:ArrayCollection = new ArrayCollection();
private var _selectedRelType:RelType = null;

[Bindable]
private var _pathLengths:ArrayCollection = new ArrayCollection();
private var _selectedPathLength:PathLength = null;	//??? braucht man ??

private var _paths:HashMap = new HashMap(); /*~*/
//[Bindable(event = "maxPathLengthChange")]
//private var _maxPathLength:int = 0;
//private var _selectedMaxPathLength:int = 0;	
//private var _selectedMinPathLength:int = 0;

[Bindable(event = "eventLangsChanged")]
private var languageDP:Array = Languages.getInstance().asDataProvider;

public var PLRCHANGE:String = "selectedPathLengthRangeChange";

private var _graphIsFull:Boolean = false;	//whether the graph is overcluttered already!
private var _delayedDrawing:Boolean = true;


[Bindable]
private var _showOptions:Boolean = false;	//flag to set filters and infos visible or invisible

[Bindable]
[Embed(source="../assets/img/show.gif")]
public var filterSign:Class;

private var setupDone:Boolean = false;

private function setup(): void {
	
	if (!setupDone) {
		myConnection = new SPARQLConnection();
	
		StatusModel.getInstance().addEventListener("eventMessageChanged", statusChangedHandler);
		
		//(sGraph as Canvas).addEventListener(MouseEvent.MOUSE_WHEEL, mouseWheelZoomHandler);
		
		callLater(setupParams);
	}
	
	setupDone = true;
	
}



private function mouseWheelRepulsionHandler(event:MouseEvent):void {
	if (event.delta > 0) {
		sGraph.repulsionFactor = sGraph.repulsionFactor * 1.05;
	}else {
		sGraph.repulsionFactor= sGraph.repulsionFactor / 1.05;
	}
}

private var wheelScale:Number = 1.0;

private function mouseWheelZoomHandler(event:MouseEvent):void {
	if (event.delta > 0) {
		wheelScale = wheelScale * 1.05;
	}else {
		wheelScale = wheelScale / 1.05;
	}
	
	sGraph.scaleX = wheelScale;
	sGraph.scaleY = wheelScale;
}

private function setupParams():void {
	
	var param:Dictionary = getUrlParamateres();
	
	if (param == null) {
		return;
	}
	
	var example:Example = ConfigUtil.fromURLParameter(param);
	
	if (example != null && example.endpointConfig != null) {
		
		var conf:IConfig = ConnectionModel.getInstance().getSPARQLByAbbreviation(example.endpointConfig.abbreviation);
		
		if (conf == null) {
			ConnectionModel.getInstance().sparqlConfigs.addItem(example.endpointConfig);
			ConnectionModel.getInstance().sparqlConfig = example.endpointConfig;
		}else {
			ConnectionModel.getInstance().sparqlConfig = conf;
		}
		
		callLater(loadExample2, [example]);
	}
	
}

private function preInitHandler(event:Event):void {
	// load config
	var root:String = Application.application.url;
	var configLoader:HTTPService = new HTTPService(root);
	
	configLoader.addEventListener(ResultEvent.RESULT, xmlCompleteHandler);
	configLoader.addEventListener(FaultEvent.FAULT, xmlCompleteHandler);
	configLoader.url = "config/Config.xml";
	configLoader.send();
   
}

private function xmlCompleteHandler(event:Event):void {
	if (event is ResultEvent) {
		
		ConfigUtil.setConfigurationFromXML((event as ResultEvent).result.data);
		
	}else {
		Alert.show((event as FaultEvent).fault.toString(), "Config file not found");
	}
	
	callLater(setInitialized);
	
	loadExamples();
}

private function loadExamples():void {
	var root:String = Application.application.url;
	var exampleLoader:HTTPService = new HTTPService(root);
	
	exampleLoader.addEventListener(ResultEvent.RESULT, exampleCompleteHandler);
	exampleLoader.addEventListener(FaultEvent.FAULT, exampleCompleteHandler);
	exampleLoader.url = "config/examples.xml";
	exampleLoader.send();
}

private function exampleCompleteHandler(event:Event):void {
	if (event is ResultEvent) {
		
		ExampleUtil.setExamplesFromXML((event as ResultEvent).result.data);
		
	}else {
		Alert.show((event as FaultEvent).fault.toString(), "Example file not found");
	}
	
	callLater(setInitialized);
}

private function setInitialized():void {
	super.initialized = true
}

override public function set initialized(value:Boolean):void{
	// don't do anything, so we wait until the xml loads
}

private function statusChangedHandler(event:Event):void {
	statusLabel.text = "Status: " + StatusModel.getInstance().message;
	
	if (StatusModel.getInstance().isSearching){
		la.startRotation();
	}else{
		la.stopRotation();
		delayedDrawing = false;
		//build connectivityLevels
		var iter:Iterator = elements.getIterator();
		while (iter.hasNext()) {
			var e:Element = iter.next();
			if ((!e.isGiven)  && (!e.isPredicate)) {
				e.computeConnectivityLevel();
			}
		}
	}
}

private function validateParamters(key:String, value:String):Boolean {
	if (key.indexOf("obj") == 0) {
		var index:int = new int(key.charAt(3));
		
		while (index > inputFieldRepeater.dataProvider.length) {
			inputFieldBox.addNewInputField();
		}
	
		if (index != 0) {
			var  obj:Object = decodeObjectParameter(value);
			(inputField[index - 1] as AutoComplete).selectedItem = obj;
			(inputField[index - 1] as AutoComplete).validateNow();
		}
		return true;
	}
	return false;
}

private function inputToURL():String {
	return ConfigUtil.toURLParameters(
		Application.application.url.substring(0, Application.application.url.lastIndexOf(".swf") + 4), 
		lastInputs,
		ConnectionModel.getInstance().sparqlConfig);
}

private function decodeObjectParameter(value:String):Object {
	var obj:Object = new Object();
	var str:String = Base64.decode(value);
	var arr:Array = str.split("|");
	obj.label = arr[0].toString();
	obj.uris = new Array();
	for (var i:int = 1; i <= arr.length - 1; i++){
		if (arr[i] && arr[i].toString() != ""){
			(obj.uris as Array).push(arr[i].toString());
		}
	}
	
	return obj;
}

private function getUrlParamateres():Dictionary {
	var urlParams:Dictionary = new Dictionary();
	var param:Object = Application.application.parameters;
	var count:int = 0;
	
	for (var key:String in param) {
		urlParams[key] = param[key];
		count++;
	}
	
	if (count == 0) {
		return null;
	}
	
	return urlParams;
}


public function getConcept(uri:String, label:String):Concept {
	//trace("getConcept : " + uri);
	for each(var c:Concept in _concepts) {
		if (c.id == uri) {
			
			return c;
		}
	}
	//trace("build new concpet " + uri);
	var newC:Concept = new Concept(uri, label);
	_concepts.addItem(newC);
	newC.addEventListener(Concept.NUMVECHANGE, conceptChangeListener);
	newC.addEventListener(Concept.VCHANGE, conceptChangeListener);

	newC.addEventListener(Concept.ELEMENTNUMBERCHANGE, conceptChangeListener);

	
	_concepts.refresh();
	return newC;
}

private function conceptChangeListener(event:Event):void {
	var c:Concept = event.target as Concept;
	
	if (event.type == Concept.ELEMENTNUMBERCHANGE) {
		if (dgC != null) {
			//(dgC as SortableDataGrid).sortByColumn();
			
			_concepts.itemUpdated(c);
		}
	}else {
		if (dgC != null) {
			(dgC as DataGrid).invalidateList();
		}
	}
	
	
	
	//check filter sign
	if (tab12.isVisible) {
		if ((!c.isVisible) && c.canBeChanged) {
			tab12.isVisible = false; //.icon = filterSign;
		}
	}else {
		var noFilters:Boolean = true;
		for each(var c1:Concept in _concepts) {
			if ((!c1.isVisible) && c1.canBeChanged) {
				noFilters = false;	//there is at least one filter!
				break;
			}
		}
		if (noFilters) {
			tab12.isVisible = true; // icon = null;
		}
	}
}

[Bindable]
public function get selectedConcept():Concept {
	return _selectedConcept;
}

public function set selectedConcept(c:Concept):void {
	if (_selectedConcept != c) {
		//trace("selectedConcept change "+c.id);
		
		//deselect all other selections
		selectedRelType = null;
		selectedPathLength = null;
		selectedConnectivityLevel = null;
		
		_selectedConcept = c;
		//dispatchEvent(new Event("selectedConceptChange"));
	}
}


/** RelTypes **/

public function getRelType(uri:String, label:String):RelType {
	//trace("getConcept : " + uri);
	for each(var r:RelType in _relTypes) {
		if (r.id == uri) {
			
			return r;
		}
	}
	trace("build new reltype " + uri);
	var newR:RelType = new RelType(uri, label);
	_relTypes.addItem(newR);
	newR.addEventListener(RelType.NUMVRCHANGE, relTypeChangeListener);
	newR.addEventListener(RelType.VCHANGE, relTypeChangeListener);
	newR.addEventListener(RelType.ELEMENTNUMBERCHANGE, relTypeChangeListener);
	
	if (_graphIsFull) {
		trace("------------------graphISFULLL -> relType setVisible=false");
		newR.isVisible = false;
	}
	_relTypes.refresh();
	return newR;
}

private function relTypeChangeListener(event:Event):void {
	
	var rT:RelType = event.target as RelType;
	
	if (event.type == RelType.ELEMENTNUMBERCHANGE) {
		if (dgT != null) {
			//(dgT as SortableDataGrid).sortByColumn();
			
			_relTypes.itemUpdated(rT);
		}
	}else {
		if (dgT != null) {
			(dgT as DataGrid).invalidateList();
		}
	}
	
	//trace("relTypes update : " +rT.numVisibleRelations);
	//_relTypes.itemUpdated(rT);
	//if (dgT != null) {
		//(dgT as DataGrid).invalidateList();
	//}
	
	//check filter sign
	if (tab13.isVisible) {
		if ((!rT.isVisible) && rT.canBeChanged) {
			tab13.isVisible = false; // icon = filterSign;
		}
	}else {
		var noFilters:Boolean = true;
		for each(var rT1:RelType in _relTypes) {
			if ((!rT1.isVisible) && rT1.canBeChanged) {
				noFilters = false;	//there is at least one filter!
				break;
			}
		}
		if (noFilters) {
			tab13.isVisible = true; // icon = null;
		}
	}
}

[Bindable]
public function get selectedRelType():RelType {
	return _selectedRelType;
}

public function set selectedRelType(r:RelType):void {
	if (_selectedRelType != r) {
		//trace("selectedConcept change "+c.id);
		
		//deselect all other selections
		selectedConcept = null;
		selectedPathLength = null;
		selectedConnectivityLevel = null;
		
		_selectedRelType = r;
		//dispatchEvent(new Event("selectedConceptChange"));
	}
}



/** ConnectivityLevels **/

public function getConnectivityLevel(id:String, num:int):ConnectivityLevel {
	//trace("getConcept : " + uri);
	for each(var cL:ConnectivityLevel in _connectivityLevels) {
		if (cL.id == id) {
			
			return cL;
		}
	}
	trace("build new conLevel " + id);
	var newCL:ConnectivityLevel = new ConnectivityLevel(id, num);
	_connectivityLevels.addItem(newCL);
	newCL.addEventListener(ConnectivityLevel.NUMVECHANGE, conLevelChangeListener);
	newCL.addEventListener(ConnectivityLevel.VCHANGE, conLevelChangeListener);
	newCL.addEventListener(ConnectivityLevel.ELEMENTNUMBERCHANGE, conLevelChangeListener);
	/*if (_graphIsFull) {
		trace("------------------graphISFULLL -> relType setVisible=false");
		newR.isVisible = false;
	}*/
	_connectivityLevels.refresh();
	return newCL;
}

private function conLevelChangeListener(event:Event):void {
	var cL:ConnectivityLevel = event.target as ConnectivityLevel;
	
	if (event.type == ConnectivityLevel.ELEMENTNUMBERCHANGE) {
		if (dgCc != null) {
			//(dgCc as SortableDataGrid).sortByColumn();
			
			_connectivityLevels.itemUpdated(cL);
		}
	}else {
		if (dgCc != null) {
			(dgCc as DataGrid).invalidateList();
		}
	}
	
	//_connectivityLevels.itemUpdated(cL);
	//if (dgCc != null) {
		//(dgCc as DataGrid).invalidateList();
	//}
	
	//check filter sign
	if (tab11.isVisible) {	//no filters are registered
		if ((!cL.isVisible) && cL.canBeChanged) {
			tab11.isVisible = false;	// icon = filterSign;
		}
	}else {
		var noFilters:Boolean = true;
		for each(var cL1:ConnectivityLevel in _connectivityLevels) {
			if ((!cL1.isVisible) && cL1.canBeChanged) {
				noFilters = false;	//there is at least one filter!
				break;
			}
		}
		if (noFilters) {
			tab11.isVisible = true; //tab10.icon = null;
		}
	}
}

[Bindable]
public function get selectedConnectivityLevel():ConnectivityLevel {
	return _selectedConnectivityLevel;
}

public function set selectedConnectivityLevel(cL:ConnectivityLevel):void {
	if (_selectedConnectivityLevel != cL) {
		//trace("selectedConcept change "+c.id);
		
		//deselect all other selections
		selectedRelType = null;
		selectedConcept = null;
		selectedPathLength = null;
		
		_selectedConnectivityLevel = cL;
	}
}



/** PathLenghts **/

public function getPathLength(uri:String, length:int):PathLength {
	for each(var pL:PathLength in _pathLengths) {
		if (pL.id == uri) {
			
			return pL;
		}
	}
	//trace("build new concpet " + uri);
	var newPL:PathLength = new PathLength(uri, length);
	_pathLengths.addItem(newPL);
	newPL.addEventListener(PathLength.NUMVPCHANGE, pathLengthChangeListener);
	newPL.addEventListener(PathLength.VCHANGE, pathLengthChangeListener);
	newPL.addEventListener(PathLength.ELEMENTNUMBERCHANGE, pathLengthChangeListener);
	if (_graphIsFull) {
		//set new pathLength invisible
		newPL.isVisible = false;
	}
	_pathLengths.refresh();
	return newPL;
}

private function pathLengthChangeListener(event:Event):void {
	var pL:PathLength = event.target as PathLength;
	
	if (event.type == PathLength.ELEMENTNUMBERCHANGE) {
		if (dgL != null) {
			_pathLengths.itemUpdated(pL);
		}
	}else {
		if (dgL != null) {
			(dgL as DataGrid).invalidateList();
		}
	}
	
	//check filter sign
	if (tab10.isVisible) {	//no filters are registered
		if ((!pL.isVisible) && pL.canBeChanged) {
			tab10.isVisible = false;	// icon = filterSign;
		}
	}else {
		var noFilters:Boolean = true;
		for each(var pL1:PathLength in _pathLengths) {
			if ((!pL1.isVisible) && pL1.canBeChanged) {
				noFilters = false;	//there is at least one filter!
				break;
			}
		}
		if (noFilters) {
			tab10.isVisible = true; //tab10.icon = null;
		}
	}
}

[Bindable]
public function get selectedPathLength():PathLength {
	return _selectedPathLength;
}

public function set selectedPathLength(p:PathLength):void {
	if (_selectedPathLength != p) {
		//trace("selectedConcept change "+c.id);
		
		//deselect all other selections
		selectedRelType = null;
		selectedConcept = null;
		selectedConnectivityLevel = null;
		
		_selectedPathLength = p;
		//dispatchEvent(new Event("selectedConceptChange"));
	}
}


/*~*/
public function getGivenNode(_uri:String, _element:Element):GivenNode {
	if (!givenNodes.containsKey(_uri)) {
		var newGivenNode:GivenNode = new GivenNode(_uri, _element);
		givenNodes.insert(_uri, newGivenNode);
		givenNodesInsertionTime.insert(_uri, new Date());
		
		var givenNodesArray:Array = new Array();
		
		var keys:Array = givenNodesInsertionTime.getKeySet();
		
		for each(var uri:String in keys) {
			if (givenNodes.containsKey(uri)) {
				givenNodesArray.push({time:(givenNodesInsertionTime.find(uri) as Date).time, node:givenNodes.find(uri)});
			}
		}
		
		givenNodesArray.sortOn("time", Array.NUMERIC);
		
		addNodeToGraph(newGivenNode);
		
		var angle:Number = 360 / givenNodesArray.length;
		var centerX:Number = this.sGraph.width / 2;
		var centerY:Number = this.sGraph.height / 2
		//var radius:Number = Math.min(centerX - 80, centerY - 40);
		var a:Number = centerX - 120;
		var b:Number = centerY - 60;
		
		for (var i:int = 0; i < givenNodesArray.length; i++) {
			if ((givenNodesArray[i].node as GivenNode).getX() == 0 && (givenNodesArray[i].node as GivenNode).getY() == 0) {
				// Ellipse
				(givenNodesArray[i].node as GivenNode).setPosition(a * Math.cos((i * angle - 180) * (Math.PI / 180)) + centerX, b * Math.sin((i * angle - 180) * (Math.PI / 180)) + centerY);
				
				// Circle
				//(givenNodesArray[i].node as GivenNode).setPosition( (radius) * Math.sin((i * angle - 90) * (Math.PI / 180)) + centerX, (-radius) * Math.cos((i * angle - 90) * (Math.PI / 180)) + centerY);
			}else {
				// Ellipse
				moveNodeToPosition((givenNodesArray[i].node as GivenNode), a * Math.cos((i * angle - 180) * (Math.PI / 180)) + centerX, b * Math.sin((i * angle - 180) * (Math.PI / 180)) + centerY);
				// Circle
				//moveNodeToPosition((givenNodesArray[i].node as GivenNode), (radius) * Math.sin((i * angle - 90) * (Math.PI / 180)) + centerX, ( -radius) * Math.cos((i * angle - 90) * (Math.PI / 180)) + centerY);
			}
		}
		
	}
	return givenNodes.find(_uri);
}

/*~*/
public function moveNodeToPosition(node:GivenNode, x:Number, y:Number):void {
	(node as GivenNode).moveToPosition(x, y);
}


/*~*/
public function getInstanceNode(_id:String, _element:Element):MyNode {
	if (givenNodes.containsKey(_id)) {	//if the node is a given node!
		
		return givenNodes.find(_id) as MyNode;
	}
	if (!foundNodes.containsKey(_id)) {
		var newFoundNode:FoundNode = new FoundNode(_id, _element);
		//trace("new FoundNode: " + newFoundNode.id);
		foundNodes.insert(_id, newFoundNode);
		addNodeToGraph(newFoundNode);
	}
	return foundNodes.find(_id) as MyNode;
}

/*~*/
public function getRelationNode(id:String, relation:Relation):RelationNode {
	if (!_relationNodes.containsKey(id)) {
		//trace("<<<< do not exist yet: " + id);
		var newRelationNode:RelationNode = new RelationNode(id, relation);
		_relationNodes.insert(id, newRelationNode);
		addNodeToGraph(newRelationNode);
	}
	return _relationNodes.find(id);
}

/*~*/
public function drawPath(p:Path, immediatly:Boolean = false):void {
	
	if (delayedDrawing && !immediatly) {
		//trace("want to draw path: " + p.id);
		toDrawPaths.enqueue(p);
		startDrawing();
	}else {
		//trace("draw path: " + p.id);
		for each(var r:Relation in p.relations) {
			drawRelation(r, p.layout);
		}
	}
	
}

/*~*/
private function drawRelation(_r:Relation, layout:Object = null):void {
	
	var subject:Element = _r.subject;
	var object:Element = _r.object;
	var predicate:Element = _r.predicate;
	
	//trace("draw relation: " + subject.id + ", " + predicate.id + ", " + object.id);
	var subjectNode:MyNode = getInstanceNode(subject.id, subject);
	if (!graph.hasNode(subjectNode.id)) {
		showNode(subjectNode);
	}
	
	var predicateNode:RelationNode = getRelationNode(_r.id, _r); // new RelationNode(_r.id, _r);	//important: _r.id and not _r.predicate.id!!
	if (!graph.hasNode(predicateNode.id)) {
		showNode(predicateNode);
	}
	
	var objectNode:MyNode = getInstanceNode(object.id, object);
	if (!graph.hasNode(objectNode.id)) {
		showNode(objectNode);
	}
	
	addRelationToGraph(subjectNode, predicateNode, objectNode, layout);
}

/*~*/
private function addNodeToGraph(node:MyNode):void {	//TODO: relations need to be added too!
	//trace(">>> add node to graph: " + node.id);
	graph.add(node);
	node.element.isVisible = true;
	//setCurrentItem(node);
}

/*~*/
public function hideNode(node:MyNode):void {
	//trace("hideNode " + node.id);
	if (graph.hasNode(node.id)) {	//if part of the graph
		removeNodeFromGraph(node);
	}
}

/*~*/
public function showNode(node:MyNode):void {
	trace("---- showNode: " + node.id);
	//TODO: Relationen wieder aufbauen!
	addNodeToGraph(node);
}

/*~*/
private function removeNodeFromGraph(node:MyNode):void {	//TODO: the whole connection must be removed too! And the relation!
	trace("Remove node from graph: " + node.id);
	node.element.isVisible = false;
	graph.remove(node);
	//sGraph.removeFromHistory(node);
	
	//setCurrentItem(null);
}

/*~*/
private function addRelationToGraph(subjectNode:MyNode, predicateNode:MyNode, objectNode:MyNode, layout:Object = null):void {
	
	var object1:Object = new Object();
	object1.startId = subjectNode.id;	//defines the direction of the link!
	if (layout != null) object1.settings = layout.settings;
	graph.link(subjectNode, predicateNode, object1);
	
	var object2:Object = new Object();
	object2.startId = predicateNode.id;
	if (layout != null) object2.settings = layout.settings;
	graph.link(predicateNode, objectNode, object2);
	
	//setCurrentItem(objectNode);
	//setCurrentItem(predicateNode);
	//setCurrentItem(subjectNode);
}

/*~*/
public function getRelation(_subject:Element, _predicate:Element, _object:Element):Relation {
	var relId:String = _subject.id + _predicate.id + _object.id; //_subject.label.toLowerCase() + _predicate.label.toLowerCase() + _object.label.toLowerCase();
	if (!relations.containsKey(relId)) {
		var rT:RelType = getRelType(_predicate.id, _predicate.label);
		var newRel:Relation = new Relation(relId, _subject, _predicate, _object, rT);
		
		relations.insert(relId, newRel);
		
		//toDrawRelations.enqueue(newRel);
	}
	return relations.find(relId);
}

/*~*/
public function getElement(_id:String, _resourceURI:String, _label:String, isPredicate:Boolean = false, _abstract:Dictionary = null, _imageURL:String = "", _linkToWikipedia:String = ""):Element {
	
	//WARNING: This is just a workaround!! It should get index by its id instead of by its label!!
	
	//what was the reason for this workaround?
	//changed it back to id!!! needed for autocomplete tooltip (Timo)
	
	//ok, its not working properly if predicates are indexed by its id. So we are using label, if its a predicate (Timo)
	if (isPredicate) {
		if (!elements.containsKey(_label)) {	//_id
			var e:Element = new Element(_label, _resourceURI, _label, isPredicate, _abstract, _imageURL, _linkToWikipedia);
			
			elements.insert(_label, e);
		}
		return elements.find(_label);
	}else {
		if (!elements.containsKey(_id)) {	//_id
			var e2:Element = new Element(_id, _resourceURI, _label, isPredicate, _abstract, _imageURL, _linkToWikipedia);
			
			elements.insert(_id, e2);
		}
		return elements.find(_id);
	}
	
}

/*~*/
public function getPath(pathId:String, pathRelations:Array):Path {
	if (!_paths.containsKey(pathId)) {
		var pL:PathLength = getPathLength(pathRelations.length.toString(), pathRelations.length - 1);
		var newPath:Path = new Path(pathId, pathRelations, pL);
		
		_paths.insert(pathId, newPath);
		
		if (!_graphIsFull) {
			//if (selectedMaxPathLength < newPath.pathLength.num) {
				if (_paths.size > 7) {
					trace("graph is full!!!");
					_graphIsFull = true;
				}else {
					
				}
			//}
		}
		
		
	}
	return _paths.find(pathId);
}


[Bindable]
public function get selectedElement():Element {
	return _selectedElement;
}

public function set selectedElement(e:Element):void {
	//trace("setSelectedE");
	//delayedDrawing = false;	//because user interaction!
	
	if (e == null) {
		_selectedElement = null;
		selectedConcept = null;
	}else if ((_selectedElement == null) || (e != null && _selectedElement != null && _selectedElement.id != null && e.id != null && _selectedElement.id != e.id)) {
		_selectedElement = e;
		selectedConcept = _selectedElement.concept;
		var iter:Iterator = _paths.getIterator();
		while (iter.hasNext()) {
			var p1:Path = iter.next();
			p1.isHighlighted = false;
		}
		if (foundNodes.containsKey(e.id)) {	//only for found nodes
			
			for each(var r:Relation in _selectedElement.relations) {
				for each(var p:Path in r.paths) {
					if (p.isVisible) {
						p.isHighlighted = true;
					}
				}
			}
		}
	}else {
		//trace("else");
		for each(var r2:Relation in _selectedElement.relations) {
			for each(var p2:Path in r2.paths) {
				p2.isHighlighted = false;
			}
		}
	}
}

public function clear():void {
	trace("clear");
	
	clearGraph();

	inputFieldBox.dataProvider = new ArrayCollection(new Array(new String("input0"), new String("input1")));
	autoCompleteList = new ArrayCollection();
	
	_showOptions = false;
	
	trace("check clear!!");
	trace("graph: " + graph.nodeCount);
	trace("paths: " + _paths.size);
}

public function clearGraph():void {
	trace("clear");
	
	ConnectionModel.getInstance().lastClear = new Date();
	
	//TODO: clear slider, clear input fields
	
	//TODO: Stop SPARQL queries, clear all the connection stuff! 
	//(resultParser as SPARQLResultParser).clear();
	
	/**
	 * REMOVE ALL LISTENER ----------------
	 */
	var iter:Iterator = _paths.getIterator();
	while (iter.hasNext()) {
		var p:Path = iter.next();
		p.removeListener();
	}
	
	var iter2:Iterator = relations.getIterator();
	while (iter2.hasNext()) {
		var r:Relation = iter2.next();
		r.removeListener();
	}
	
	var iter4:Iterator = elements.getIterator();
	while (iter4.hasNext()) {
		var e:Element = iter4.next();
		e.removeListener();
	}
	
	for each(var c:Concept in _concepts) {
		c.removeListener();
	}
	
	for each(var pL:PathLength in _pathLengths) {
		pL.removeListener();
	}
	
	for each(var rT:RelType in _relTypes) {
		rT.removeListener();
	}
	
	for each(var cL:ConnectivityLevel in _connectivityLevels) {
		cL.removeListener();
	}
	
	/**
	 * RESET VARIABLES -----------------------
	 */
	graph = new Graph();
	selectedElement = null;
	_selectedConnectivityLevel = null;
	_selectedConcept = null;
	_selectedPathLength = null;
	_selectedRelType = null;
	_selectedConnectivityLevel = null;
	_graphIsFull = false;	//whether the graph is overcluttered already!
	_delayedDrawing = true;
	
	_relationNodes = new HashMap();
	foundNodes = new HashMap();
	givenNodes = new HashMap();

	toDrawPaths = new ArrayedQueue(1000);
	timer.stop();
	timer.delay = 2000;
	StatusModel.getInstance().queueIsEmpty = true;
	
	//trace("before",_paths.size);
	_connectivityLevels = new ArrayCollection();
	_pathLengths = new ArrayCollection();
	_paths = new HashMap();
	//trace("after", _paths.size);
	_relTypes = new ArrayCollection();
	relations = new HashMap();
	_concepts = new ArrayCollection();
	elements = new HashMap();
	
	//_maxPathLength = 0;
	//_selectedMinPathLength = 0;
	//_selectedMaxPathLength = 0;
	
	
	
	myConnection = new SPARQLConnection();
	
	StatusModel.getInstance().clear();
	
	Languages.getInstance().clear();
	
	_selectedElement = null;	//so ist es besser!
	
	sparqlEndpoint = "";
	basicGraph = "";
	resultParser = new SPARQLResultParser();
	
	tab10.isVisible = true;// icon = null;
	tab11.isVisible = true;
	tab12.isVisible = true;// .icon = null;
	tab13.isVisible = true;// icon = null;
}

//--Expert-Settings + Info-------------------------------------

private var _settingsButton:Object;

[Embed(source="../assets/img/16-tool.png")]
private var _settingsButtonIcon:Class;

private var _infosButton:Object;

[Embed(source="../assets/img/16-info.png")]
private var _infosButtonIcon:Class;

private var _clearButton:Object;

[Embed(source="../assets/img/Clear.png")]
private var _clearButtonIcon:Class;

private var _urlButton:Object;

[Embed(source="../assets/img/16-url.png")]
private var _urlButtonIcon:Class;

private function getButtons():ArrayCollection {
	
	var btns:ArrayCollection = new ArrayCollection();
	
	if (_settingsButton == null) {
		_settingsButton = new Object();
		_settingsButton.toolTip = "Settings";
		_settingsButton.name = "settings";
		_settingsButton.icon = _settingsButtonIcon;
		_settingsButton.clickHandler = settingsClickHandler;
	}
	btns.addItem(_settingsButton);
	if (_infosButton == null) {
		_infosButton = new Object();
		_infosButton.toolTip = "Infos";
		_infosButton.name = "infos";
		_infosButton.icon = _infosButtonIcon;
		_infosButton.clickHandler = infosClickHandler;
	}
	btns.addItem(_infosButton);
	
	if (_clearButton == null) {
		_clearButton = new Object();
		_clearButton.toolTip = "Clear";
		_clearButton.name = "clear";
		_clearButton.icon = _clearButtonIcon;
		_clearButton.clickHandler = clearClickHandler;
	}
	btns.addItem(_clearButton);
	
	if (_urlButton == null) {
		_urlButton = new Object();
		_urlButton.toolTip = "Get URL for current search";
		_urlButton.name = "url";
		_urlButton.icon = _urlButtonIcon;
		_urlButton.clickHandler = urlClickHandler;
	}
	btns.addItem(_urlButton);

	return btns;
}

private function urlClickHandler(event:MouseEvent):void{
	var url:String = inputToURL();
	Clipboard.generalClipboard.clear();
	Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, url);
	Alert.show(url, "This URL has been saved to your clipboard");
}

private function clearClickHandler(event:MouseEvent):void {
	clear();
}

private function settingsClickHandler(event:MouseEvent):void {
	var pop:ExpertSettings = PopUpManager.createPopUp(this, ExpertSettings) as ExpertSettings;
}

private function infosClickHandler(event:MouseEvent):void {
	var pop:Infos = PopUpManager.createPopUp(this, Infos) as Infos;
}

[Bindable]
private var _examples:ArrayCollection = new ArrayCollection();

private function loadExample(o1:Object, o2:Object, ep:Object):void {
	
	var searchPossible:Boolean = true;
	
	if (ConnectionModel.getInstance().sparqlConfig.endpointURI.toString() != ep.uri.toString()) {
		var conf:IConfig = ConnectionModel.getInstance().getSPARQLByEndpointURI(ep.uri.toString());
		if (conf != null) {
			Alert.show("Your selected Endpoint was set to \"" + conf.name + "\".\nYou can change back the endpoint to \"" + ConnectionModel.getInstance().sparqlConfig.name + "\" in the settings menu.", "Endpoint changed", Alert.OK + Alert.NONMODAL);
			ConnectionModel.getInstance().sparqlConfig = conf;
		}else {
			searchPossible = false;
			Alert.show("The desired endpoint \"" + ep.uri + "\" was not specified in the configuration file.", "Endpoint not specified", Alert.OK);
		}
	}
	
	if (searchPossible) {
		//clear();
		tn.selectedChild = tab1;	//set current tab
		(inputField[0] as AutoComplete).selectedItem = o1;
		(inputField[1] as AutoComplete).selectedItem = o2;
		
		(inputField[0] as AutoComplete).validateNow();
		(inputField[1] as AutoComplete).validateNow();
		
		findRelations();
	}

}

public function loadExample2(example:Example):void {
	
	if (example == null || example.endpointConfig == null) {
		return;
	}
	
	var searchPossible:Boolean = true;
	
	// set endpoint config
	if (ConnectionModel.getInstance().sparqlConfig != example.endpointConfig) {
		if (example.endpointConfig != null) {
			Alert.show("Your selected Endpoint was set to \"" + example.endpointConfig.name + "\".\nYou can change back the endpoint to \"" + ConnectionModel.getInstance().sparqlConfig.name + "\" in the settings menu.", "Endpoint changed", Alert.OK + Alert.NONMODAL);
			ConnectionModel.getInstance().sparqlConfig = example.endpointConfig;
		}else {
			searchPossible = false;
			Alert.show("The desired endpoint \"" + example.endpointConfig.endpointURI + "\" was not specified in the configuration file.", "Endpoint not specified", Alert.OK);
		}
	}
	
	if (searchPossible) {
		
		tn.selectedChild = tab1;	//set current tab
		
		// set number of input fields
		if (inputFieldBox.dataProvider.length != example.objects.length) {
			
			if (inputFieldBox.dataProvider.length < example.objects.length) {
				// add fields
				
				while (inputFieldBox.dataProvider.length < example.objects.length) {
					inputFieldBox.addNewInputField();
				}
			}else {
				// remove fields
				while (inputFieldBox.dataProvider.length > example.objects.length && inputFieldBox.dataProvider.length > 2) {
					inputFieldBox.removeInputField(inputFieldBox.dataProvider.length - 1);
				}
			}
			
		}
		
		for (var i:int = 0; i < example.objects.length; i++) {
			(inputField[i] as AutoComplete).selectedItem = (example.objects as ArrayCollection).getItemAt(i);
			(inputField[i] as AutoComplete).validateNow();
		}
		
		if (example.objects.length >= 2) {
			findRelations();
		}
	}
}

private function autoDisambiguate(ac:AutoComplete):Boolean {
	var input:String = ac.searchText;
	var dp:ArrayCollection = ac.dataProvider;
	
	trace("auto disambiguate: " + input);
	trace("searching for direct match");
	for each (var obj:Object in dp) {
		if ((StringUtil.trim(obj.label)).toLowerCase() == (StringUtil.trim(input)).toLowerCase()) {
			
			//check if count from matching object is high enaugh for a dirct match
			var o:Object = dp.getItemAt(0);
			if (o != null && o.hasOwnProperty("count") && obj != null && obj.hasOwnProperty("count")) {
				 //if count of obj is not much lower than count of o, take obj as selected item
				if (o.count / obj.count < 5) {
					ac.selectedItem = obj;
					ac.validateNow();
					trace("disambiguated by direct match. relation between found item and 1st item in list = " + o.count / obj.count + " found item will be taken as selected object");
					return true;
				}else {
					trace("no disambiguation by direct match. relation between found item and 1st item to low = " + o.count / obj.count);
					return false;
				}
			}
		}
	}
	// directly match only the first element
	//if (dp.length > 0) {
		//if ((StringUtil.trim(dp.getItemAt(0).label)).toLowerCase() == (StringUtil.trim(input)).toLowerCase()) {
			//ac.selectedItem = dp.getItemAt(0);
			//ac.validateNow();
			//trace("direct match found");
			//return true;
		//}
	//}
	trace("no direct match found");
	
	// results of this method weren't really satisfying, so it was disabled
	// enabled again with a higher ratio
	trace("checking count");
	if (dp.length >= 2) {
		var o1:Object = dp.getItemAt(0);
		var o2:Object = dp.getItemAt(1);
		
		if (o1 != null && o1.hasOwnProperty("count") && o2 != null && o2.hasOwnProperty("count")) {
			 //if count of o1 is much higher than count of o2, take o1 as selected item
			if (o1.count / o2.count > 20) {
				ac.selectedItem = o1;
				ac.validateNow();
				trace("disambiguated by count. relation between 1st and 2nd item = " + o1.count / o2.count + " 1st item will be taken as selected object");
				return true;
			}else {
				trace("no disambiguation by count. relation between 1st and 2nd item to low = " + o1.count / o2.count);
				return false;
			}
		}
	}
	trace("no auto disambiguation possible");
	
	return false;
}



public function findRelations():void {
	
	//removeEmptyInputFields();
	
	if (givenNodes.isEmpty()) {
		findRelationsImmediately();
	}else {
		Alert.show("Do you want to clear all old results before searching for new relations?", "Clear", Alert.YES + Alert.NO, this, dispatchCloseEvent);
	}
}
		
private function dispatchCloseEvent(event:CloseEvent):void {
	if (event.detail == Alert.YES) {
		
		clearGraph();
		
		callLater(findRelationsImmediately);
		
	}else if (event.detail == Alert.NO) {
		findRelationsImmediately();
	}
}	

private function findRelationsImmediately():void {
	
	if (!isInputValid()) {
		for (var j:int = 0; j < inputFieldRepeater.dataProvider.length; j++) {
			if (!((inputField[j] as AutoComplete).selectedItem && (inputField[j] as AutoComplete).selectedItem.hasOwnProperty('uris'))) {
				
				var select:Object = getInputFromAC(j);
				
				if (select != null) {
					(inputField[j] as AutoComplete).selectedItem = select;
					(inputField[j] as AutoComplete).validateNow();
				}else {
					
					var success:Boolean = autoDisambiguate(inputField[j] as AutoComplete);
					
					if (!success) {
						var pop:InputSelection = PopUpManager.createPopUp(inputFieldBox, InputSelection) as InputSelection;
						pop.inputIndex = j;
						pop.dataProvider = (inputField[j] as AutoComplete).dataProvider;
						pop.inputText = (inputField[j] as AutoComplete).searchText;
						pop.msgText = "Your input is not clear.\nPlease select a resource from the list or check your input for spelling mistakes.";
						pop.addEventListener(InputSelectionEvent.INPUTSELECTION, inputSelectionWindowHandler);
						break;
					}
				}
			}
		}
	}
	
	if (isInputValid()) {
		
		_showOptions = true; 	//sets the filters visible
		
		if (isInputUnique()) {
			var betArr:Array = new Array();
			
			lastInputs = new Array();
			
			for (var i:int = 0; i < inputFieldRepeater.dataProvider.length; i++) {
				if ((inputField[i] as AutoComplete).selectedItem.hasOwnProperty("tempUri") && (inputField[i] as AutoComplete).selectedItem.tempUri != null) {
					
					var o1:Object = new Object();
					o1.label = (inputField[i] as AutoComplete).selectedItem.label;
					o1.uri = (inputField[i] as AutoComplete).selectedItem.tempUri;
					lastInputs.push(o1);
					
					betArr.push((inputField[i] as AutoComplete).selectedItem.tempUri);
					(inputField[i] as AutoComplete).selectedItem.tempUri = null;
				}else {
					
					var o2:Object = new Object();
					o2.label = (inputField[i] as AutoComplete).selectedItem.label;
					o2.uri = ((inputField[i] as AutoComplete).selectedItem.uris as Array)[0];
					lastInputs.push(o2);
					
					betArr.push(((inputField[i] as AutoComplete).selectedItem.uris as Array)[0]);
				}
			}
			
			var between:ArrayCollection = new ArrayCollection(betArr);
			
			myConnection.findRelations(between, 10, ConnectionModel.getInstance().sparqlConfig.maxRelationLength + 1, resultParser);
			
			delayedDrawing = true;
			
		}else {
			// disambiguate
			for (var k:int = 0; k < inputFieldRepeater.dataProvider.length; k++) {
				// no tempURI
				if (!((inputField[k] as AutoComplete).selectedItem.hasOwnProperty("tempUri") && (inputField[i] as AutoComplete).selectedItem.tempUri != null)) {
					// several URIs
					if (!((inputField[k] as AutoComplete).selectedItem && (inputField[k] as AutoComplete).selectedItem.hasOwnProperty('uris') && ((inputField[k] as AutoComplete).selectedItem.uris as Array).length == 1)) {
						var disambiguation:InputDisambiguation = PopUpManager.createPopUp(inputFieldBox, InputDisambiguation) as InputDisambiguation;
						disambiguation.inputIndex = k;
						disambiguation.inputItem = (inputField[k] as AutoComplete).selectedItem;
						disambiguation.addEventListener("Disambiguation", inputDisambiguationWindowHandler);
						break;
					}
				}
			}
		}
	}
}

private function getInputFromAC(acIndex:int):Object {
	for each (var o:Object in (inputField[acIndex] as AutoComplete).dataProvider) {
		
		if (o.hasOwnProperty("label") && o.hasOwnProperty("uri") && (inputField[acIndex] as AutoComplete) != null &&
				o.label.toString().toLowerCase() == (inputField[acIndex] as AutoComplete).searchText.toString().toLowerCase()) {
			return o;
		}
	}
	return null;
}

private function inputDisambiguationWindowHandler(event:Event):void {
	findRelationsImmediately();
}

private function inputSelectionWindowHandler(event:InputSelectionEvent):void {
	(inputField[event.autoCompleteIndex] as AutoComplete).selectedItem = event.selectedItem;
	(inputField[event.autoCompleteIndex] as AutoComplete).validateNow();
	findRelationsImmediately();
}

private function isInputUnique():Boolean {
	var unique:Boolean = true;
	
	for (var i:int = 0; i < inputFieldRepeater.dataProvider.length; i++) {
		unique = (unique && (inputField[i] as AutoComplete).selectedItem && (inputField[i] as AutoComplete).selectedItem.hasOwnProperty('uris') && ((inputField[i] as AutoComplete).selectedItem.uris as Array).length == 1)
			|| (unique && (inputField[i] as AutoComplete).selectedItem && (inputField[i] as AutoComplete).selectedItem.hasOwnProperty('tempUri') && (inputField[i] as AutoComplete).selectedItem.tempUri != null);
	}
	
	return unique;
}

private function isInputValid():Boolean {
	var valid:Boolean = true;
	
	for (var i:int = 0; i < inputFieldRepeater.dataProvider.length; i++) {
		valid = valid && (inputField[i] as AutoComplete).selectedItem && (inputField[i] as AutoComplete).selectedItem.hasOwnProperty('uris');
	}
	
	return valid;
}

private function findRelationXMLResultHandler(event:ResultEvent, resources:ArrayCollection):void {
	var result:XML = new XML(event.result);
	//trace(result);
}

private function replaceWhitspaces(str:String):String {
	return str.split(" ").join("_");
}

private function findAutoComplete(_typedText:String, target:AutoComplete):void {
	ConnectionModel.getInstance().sparqlConfig.lookUp.run(_typedText, target);
}

public function setAutoCompleteList(_list:ArrayCollection):void {
	autoCompleteList = _list;
}

// when an item is selected or de-selelcted
private function handleAutoCompleteChange(_selectedItem:Object):void {
//	//trace("handleAutoCompleteChange");
	if (_selectedItem != null && _selectedItem.hasOwnProperty( "label" )){
		//trace(_selectedItem.label);
	}
}

// when the text in the search field is changed
private function handleAutoCompleteSearchChange(_selectedItem:Object):void {
	//trace("handleAutoCompleteSearchChange");
	if (_selectedItem != null && _selectedItem.hasOwnProperty( "searchText" )){
		var input:String = _selectedItem.searchText;
		trace(input);
		//Workaround Case-Sensitivity
		if (input.length == 1 && input.charAt() == input.charAt().toLowerCase()) {
			input = input.toUpperCase();
			if (input != _selectedItem.searchText) {
				_selectedItem.searchText = input;
			}
		}
		
		if (input != null && input.length >= 2) {
			var results:ArrayCollection = new ArrayCollection();
			var searching:Object = new Object();
			searching.label = GlobalString.SEARCHING;
			results.addItem(searching);
			_selectedItem.dataProvider = results;
			_selectedItem.validateNow();
			findAutoComplete(input, _selectedItem as AutoComplete);
		}
	}
}


//--Delayed Drawing----------------------
private var timer:Timer = new Timer(2000);
public function startDrawing():void {
	//timer = new Timer(2000, results.length);
	if (!timer.running) {
		timer.addEventListener(TimerEvent.TIMER, drawNextPath);
		//trace("start timer");
		timer.start();
		StatusModel.getInstance().queueIsEmpty = false;
		//trace("timer start");
	}
}

/**
 * Only called by timer
 * @param	event
 */
private function drawNextPath(event:Event):void {
	if (toDrawPaths.isEmpty()) {
		timer.stop();
		StatusModel.getInstance().queueIsEmpty = true;	//TODO: direkt an toDrawPaths.isEmpty mit EventListener binden!
		//trace("timer stop");
	}else {
		
		var p:Path = toDrawPaths.dequeue();
		if (!p.isVisible) {	//if it is not visible, try the next one
			drawNextPath(null);
		}else {
			for each(var r:Relation in p.relations) {
				drawRelation(r, p.layout);
			}
		}
		
	}
}

[Bindable(event="delayedDrawingChanged")]
public function get delayedDrawing():Boolean {
	return _delayedDrawing;
}

public function set delayedDrawing(b:Boolean):void {
	if (_delayedDrawing != b) {
		_delayedDrawing = b;
		
		if (_delayedDrawing) {
			timer.delay = 2000;
		}else {
			timer.delay = 100;	//make the drawing fast!
		}
		
		dispatchEvent(new Event("delayedDrawingChanged"));
		
		/*timer.stop();
		StatusModel.getInstance().queueIsEmpty = true;
		while (!toDrawPaths.isEmpty()) {	//dump all!!
			var p:Path = toDrawPaths.dequeue();
			for each(var r:Relation in p.relations) {
				drawRelation(r, p.layout);
			}
		}
		toDrawPaths.clear();*/
	}
}

private function get inputField():Array {
	return inputFieldBox.inputField;
}

private function get inputFieldRepeater():Repeater {
	return inputFieldBox.inputFieldRepeater;
}

private function showErrorLog():void {
	var log:ErrorLog = PopUpManager.createPopUp(Application.application as DisplayObject, ErrorLog, false) as ErrorLog;
}

private function numColumnCompareFunction(itemA:Object, itemB:Object):int {
	
	if (itemA is PathLength && itemB is PathLength) {
		return internalNumColumnStringCompareFunction((itemA as PathLength).stringNumOfPaths, (itemB as PathLength).stringNumOfPaths);
	}
	
	if (itemA is RelType && itemB is RelType) {
		return internalNumColumnStringCompareFunction((itemA as RelType).stringNumOfRelations, (itemB as RelType).stringNumOfRelations);
	}
	
	if (itemA is Concept && itemB is Concept) {
		return internalNumColumnStringCompareFunction((itemA as Concept).stringNumOfElements, (itemB as Concept).stringNumOfElements);
	}
	
	if (itemA is ConnectivityLevel && itemB is ConnectivityLevel) {
		return internalNumColumnStringCompareFunction((itemA as ConnectivityLevel).stringNumOfElements, (itemB as ConnectivityLevel).stringNumOfElements);
	}
	
	return 0;
}

private function internalNumColumnStringCompareFunction(str1:String, str2:String):int {
	if ((str1 == null || str1 == "" || str1.indexOf("/") < 0) && (str2 == null || str2 == "" || str2.indexOf("/") < 0)) {
		return 0;
	}else if (str1 == null || str1 == "" || str1.indexOf("/") < 0) {
		return 1;
	}else if (str2 == null || str2 == "" || str2.indexOf("/") < 0) {
		return -1;
	}
	
	var val1:Array = str1.split("/");
	var val2:Array = str2.split("/");
	
	val1[0] = new int(val1[0]);
	val1[1] = new int(val1[1]);
	val2[0] = new int(val2[0]);
	val2[1] = new int(val2[1]);
	
	if (isNaN(val1[1]) && isNaN(val2[1]))
		return 0;
	
	if (isNaN(val1[1]))
		return 1;

	if (isNaN(val2[1]))
	   return -1;

	if (val1[1] < val2[1])
		return -1;

	if (val1[1] > val2[1])
		return 1;

	return 0;
}


