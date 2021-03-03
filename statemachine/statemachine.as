/*
TODO:
changing position variables from dialog
reading position files from character folder
dialog writing to state variables, like a phase variable
make breath be a variable instead of relying on dialog actions
should/can I use these?
	da.masturbation.herpleasure {read and write} - her masturbation pleasure (scale: 0-100)
	da.pleasurePercentage {read and write} - him pleasure (scale: 0-100)

should depth hilt be optional? some people might want to use depth as an absolute for penis size, like depth cutoffs: {"deep":4, "verydeep":7, "toodeep":9, "monster":12}
	maybe hilt should be a separate variable? so you have both depth and hilt
maybe have a variable for penis_length and penis_girth?
timing? state change cooldowns? lookbehind? I'd like to get out_to_hilted or out_to_overwhelmed working, also stroke variable could be improved with some historical data...
	-I have "since" variables for each state? I can just write a function for HappenedRecently(statename), and have a state with a required recent state, either nth most recent or maximum age in seconds
interrupts (based on priority?)
should you be able to make a set of requirements into a variable? like variable contact: { requirements: { depth: ["shallow", "deep", "verydeep" ] } }
	maybe it'd instead be called conditions, and the value of the variable would be the number of conditions currently being met? it should share code with the requirements check for states
	"too_much_dick": { conditions: {"penis_girth":["huge", "monster"], "depth":["too_deep", "monster"] }, "cutoffs":{ "toomuch": 1, "waytoomuch": 2 } }
	and then a state could have requirements: {contact:["true"] }
	if no cutoffs, then default to just >=1 means true
	maybe requirements and conditions should support an array for each variable, or an object, so you could set a points for each value
	states could also support conditions instead of requirements? so it only needs to match 1? or remove requirements and just use conditions with a minimum points? default minimum points to the number of conditions?

IMPORTCONFIG - would work like LOADCONFIG except it adds to the current config instead of replacing
*/


package flash
{

	import flash.utils.Dictionary;
	import flash.events.MouseEvent;
	import flash.events.Event;
	import flash.geom.Point;
	import flash.display.DisplayObject;
	import flash.display.BitmapData;
	import flash.geom.Transform;
	import flash.geom.Matrix;
	//import JSON;
	//using this https://github.com/mikechambers/as3corelib
	import com.adobe.serialization.json.JSON;
	import com.adobe.serialization.json.JSONDecoder;
	import com.adobe.serialization.json.JSONEncoder;
	import com.adobe.serialization.json.JSONParseError;
	import com.adobe.serialization.json.JSONToken;
	import com.adobe.serialization.json.JSONTokenizer;
	import com.adobe.serialization.json.JSONTokenType;
	import flash.net.URLRequest;
	import flash.net.URLLoader;
	import flash.events.IOErrorEvent;
	import flash.events.Event;

	var main;
	//var m;
	var g;
	var eDOM;
	var lProxy;
	var animtools;
	var dialogueAPI;
	var deepestyet:Number = 0.0;
	var recentdeepest = new StatsGroup("dt_depth");
	var recentvigour = new StatsGroup("dt_vigour");
	var recentspeed = new StatsGroup("dt_speed");
	var recentresistance = new StatsGroup("dt_resistance");
	var lasthilt:Number = 0;
	var contactdist:Number = 0.8;
	var lastpos:Number = 0;
	var statemanager = new StateManager();
	var penis_len = 0;
	var penis_girth = 0;
	var now_seconds:Number = 0;

	var mydialogstateclass;
	var DialogueLine;
	var Word;

	var cData;
	var cacheCData;
	var debug;

	public function objectLength(myObject:Object):int {
 		var cnt:int=0;
		for (var s:String in myObject) {
			if(myObject.hasOwnProperty(s)) cnt++;
		}
 		return cnt;
	}

	public function log(message:String) {
		if(debug)
			alert(message, "#00FF00");
		else
			g.dialogueControl.advancedController.outputLog("StateMachine: "+message);
	}

	public function alert(message:String, color:String="#FF0000") {
		main.updateStatusCol(message, color);
		g.dialogueControl.advancedController.outputLog("StateMachine: "+message);
	}
	
	public class StatsTracker {
		public var maxval:Number = 0;
		public var minval:Number = 0;
		public var avgval:Number = 0;
		public var lastval:Number = 0;
		//public var scaledDepth:Number = 0;
		public var maxtime:Number = 0;
		public var mintime:Number = 0;
		public var lasttime:Number = (new Date()).getTime()/1000.0;

		public function calcStats(val:Number, now_seconds:Number, maxage:Number, name:String)
		{
			if( isNaN(avgval) ) avgval = val;
			lastval = val;
			var decay = 100.0 / maxage;
			var maxval_age = (now_seconds-maxtime);
			var maxweighting = 1.0 - maxval_age / decay;
			var weighted_max = maxval * maxweighting;
			
			if(val > weighted_max || now_seconds > maxtime + maxage) {
				maxval=val;
				maxtime=now_seconds;
			}

			var minval_age = (now_seconds-mintime);
			var minweighting = 1.0 - minval_age / decay;
			var weighted_min = minval * minweighting;

			if(val < weighted_min || now_seconds > mintime + maxage) {
				minval=val;
				mintime=now_seconds;
			}

			var deltaTime = now_seconds - lasttime;
			if(deltaTime > 0.5 || isNaN(deltaTime) ) {
				deltaTime = 0.5;
			}
			if(deltaTime > 0.1) {
				avgval -= avgval / maxage * deltaTime;
				avgval += val / maxage * deltaTime;
				lasttime = now_seconds;
			}

			g.dialogueControl.advancedController._dialogueDataStore[name+"_max"+String(maxage)] = maxval;
			g.dialogueControl.advancedController._dialogueDataStore[name+"_maxtime"+String(maxage)] = maxtime;
			g.dialogueControl.advancedController._dialogueDataStore[name+"_min"+String(maxage)] = minval;
			g.dialogueControl.advancedController._dialogueDataStore[name+"_mintime"+String(maxage)] = mintime;
			g.dialogueControl.advancedController._dialogueDataStore[name+"_avg"+String(maxage)] = avgval;
		}
	}

	public class StatsGroup {
		public var name;
		public var stats;// = [ new StatsTracker(), new StatsTracker(), new StatsTracker(), new StatsTracker() ];
		public var times;// = [3, 5, 15, 60];

		public function StatsGroup(Name)
		{
			name=Name;
			times = [3, 5, 15, 60];
			stats = [ new StatsTracker(), new StatsTracker(), new StatsTracker(), new StatsTracker() ];
			/*for(var i=0;i<4;i++) {
				stats[i] = new StatsTracker();
			}*/
		}

		public function calcStats(val:Number, now_seconds:Number)
		{
			for(var i=0;i<4;i++) {
				stats[i].calcStats(val, now_seconds, times[i], name);
			}
		}
	}

	public class StateManager
	{
		var state = "none";
		var prev_state = "none";
		//var line_waiting = false;
		var lines_waiting = {};
		var states = {
			"sm_not_loaded": {
				"requirements":{
					"vigour": ["none"]
				},
				actions:[],
				effects:{},
				interrupt:false,
				interruptable:true,
				lasttime:0,
				totaltime:0,
				times:0,
				chances:100
			}
		};
		var variables = {
			vigour:{
				cutoffs:{},
				state: 'none',
				value: 0
			},
			depth:{
				cutoffs:{},
				state: 'none',
				value: 0
			},
			hilted:{
				cutoffs:{'true':1, 'false':0},
				state: 'none',
				value: 0
			},
			penis_length:{
				cutoffs:{},
				state: 'none',
				value: 0
			},
			penis_girth:{
				cutoffs:{},
				state: 'none',
				value: 0
			},
			resistance:{
				cutoffs:{},
				state: 'none',
				value: 0
			},
			stroke:{
				cutoffs:{},
				state: 'none',
				value: 0
			},
			speed:{
				cutoffs:{},
				state: 'none',
				value: 0
			},
			herpleasure:{
				cutoffs:{},
				state: 'none',
				value: 0,
				min: 0,
				max: 200
			},
			hispleasure:{
				cutoffs:{},
				state: 'none',
				value: 0,
				min: 0,
				max: 1000
			},
			position:{
				cutoffs: {
					'oral': 0,
					'titjob': 1,
					'vaginal': 2,
					'anal': 3,
					'other': 4
				},
				state: 'none',
				value: 0
			}
		};

		public function getStateProperties(name)
		{
			if( states.hasOwnProperty(name) ) return states[name];

			states[name] = {
				requirements:{},
				actions:[],
				effects:{},
				interrupt:false,
				interruptable:true,
				priority:100,
				lasttime:0,
				totaltime:0,
				times:0,
				chances:20
			};
			return states[name];
		}

		public function writeStateProperties(name, props, since)
		{
			g.dialogueControl.advancedController._dialogueDataStore["sm_"+name+"_since"] = now_seconds - since;
			g.dialogueControl.advancedController._dialogueDataStore["sm_"+name+"_duration"] = now_seconds - props.starttime;
			g.dialogueControl.advancedController._dialogueDataStore["sm_"+name+"_times"] = props.times;
			g.dialogueControl.advancedController._dialogueDataStore["sm_"+name+"_totaltime"] = props.totaltime;
		}

		public function interruptLines()
		{
			g.dialogueControl.instantStop();
		}

		public function doStateActions(actions)
		{
			if(!actions || actions.length==0) return;

			var action = "";
			var slot = Math.random()*actions.length;
			slot = Math.floor(slot);
			action = actions[slot];

			//I should figure out how to make this instant, or a thought style line, so her mouth doesn't move
			if(g.dialogueControl.waitingToContinue || g.dialogueControl.speaking) //currently in dialog
			{
				//log("doStateActions: if");
				g.dialogueControl.words.push(new Word(action));
			}
			else
			{
				//log("doStateActions: else");
				g.dialogueControl.startSpeakingPhrase (new DialogueLine(action,null));
				g.dialogueControl.instantStop();
				g.dialogueControl.speaking = true;
			}
		}

		public function getPleasure()
		{
			variables.hispleasure.value = g.him.pleasure / g.him.ejacPleasure * variables.hispleasure.max;
			if( !variables.hasOwnProperty('herpleasure') ) {
				variables.herpleasure = { value:0, cutoffs:{} };
			}
			if( !variables.herpleasure.hasOwnProperty('value') ) {
				variables.herpleasure.value = 0;
			}
		}

		public function writePleasure()
		{
			var t = variables.hispleasure.value * g.him.ejacPleasure / variables.hispleasure.max;
			g.him.pleasure = t;
			g.dialogueControl.advancedController._dialogueDataStore["sm_herpleasure"] = variables.herpleasure.value;
			g.dialogueControl.advancedController._dialogueDataStore["sm_hispleasure"] = variables.hispleasure.value;
		}

		public function triggerState(properties, name, now, old)
		{
			//log("triggerState "+name+", "+now);

			getPleasure();

			var effects = properties.effects;

			for(var k in effects) {
				if( !effects.hasOwnProperty(k) ) continue;
				if( !variables.hasOwnProperty(k) ) variables[k] = { "value": 0, "cutoffs":{} };

				variables[k].value += effects[k];
			}

			writePleasure();
			doStateActions(properties.actions);
		}

		public function isSpeaking()
		{
			return g.dialogueControl.speaking;
			//return g.dialogueControl.showingText;
		}

		public function sayLine(name)
		{
			//g.dialogueControl.buildState(name, num);
			if( ! isSpeaking() ) {
				g.dialogueControl.triggerState(name);
				return true;
			}
			else {
				//g.dialogueControl.buildState(name, 100);
				return false;
			}
		}

		public function sayLines(name, now, old, p)
		{
			var key = name+";"+old;
			var line_waiting = lines_waiting[key] === true;
			var repeat = false;

			if( (!now) && (!line_waiting) && Math.random() * 30 * 100 < p.chances )
				repeat = true;
			
			if( (!now) && (!line_waiting) && (!repeat) )
				return;

			if( (!repeat) && isSpeaking() ) {
				lines_waiting[key] = true;
				return;
			} else
				lines_waiting[key] = false;

			if( now || line_waiting ) {
				if(old) sayLine(old+"_to_"+name);
				sayLine("now_"+name);
				sayLine(name);
			}
			else if( repeat ) {
				log("triggerState "+name+", repeat");
				triggerState(p, name, now, old);
				sayLine(name);
				//g.dialogueControl.buildState(name, 100);
			}
		}

		public function callState(name, now, old)
		{
			var p = getStateProperties(name);

			var since = p.lasttime;
			if(now) {
				log("triggerState "+name+", now");
				p.starttime = now_seconds;
				p.lasttime = now_seconds;
				p.times++;
				if(p.interrupt) interruptLines();
				triggerState(p, name, now, old);
			}

			sayLines(name, now, old, p);

			p.totaltime += now_seconds - p.lasttime;
			p.lasttime = now_seconds;

			writeStateProperties(name, p, since);
		}

		public function updateVariable(name, variable)
		{
			var val = variable.value;

			if( variable.hasOwnProperty('conditions') ) {
				val = 0;
				for(var k in variable.conditions) {
					if(!variable.conditions.hasOwnProperty(k)) continue;
					var c = variable.conditions[k];
					var i = checkRequirements(c, k);
					val += i ? 1 : 0;
				}
				variable.value = val;
			}

			if( variable.hasOwnProperty('min') ) {
				variable.value = val = Math.max( val, variable.min );
			}
			if( variable.hasOwnProperty('max') ) {
				variable.value = val = Math.min( val, variable.max );
			}

			if(! variable.hasOwnProperty("cutoffs") ) return;

			var result="none";
			var max=-10;
			for(var k in variable.cutoffs) {
				if(!variable.cutoffs.hasOwnProperty(k)) continue;
				var c = variable.cutoffs[k];
				if( val>=c && c>max )
				{
					max=c;
					result = k;
				}
			}

			var old = variable.state;
			if( old != result ) variable.prev_state = old;
			variable.state = result;
			g.dialogueControl.advancedController._dialogueDataStore["sm_"+name] = result;
			callState(name+"_"+result, old!=result, name+"_"+variable.prev_state);
			if(old!=result) {
				return 1;
			}
			return 0;
		}

		public function updateVariables()
		{
			variables.depth.value = recentdeepest.stats[0].maxval;
			variables.vigour.value = recentvigour.stats[1].avgval * 100;
			variables.speed.value = recentspeed.stats[1].avgval;
			variables.hilted.value = variables.depth.value / penis_len*0.99;
			variables.penis_length.value = penis_len;
			variables.penis_girth.value = penis_girth;
			variables.resistance.value = recentresistance.stats[1].maxval * 100;

			var maxdepth = recentdeepest.stats[2].maxval;
			var mindepth = recentdeepest.stats[2].minval;
			var avgdepth = recentdeepest.stats[2].avgval;
			mindepth = Math.max( mindepth, avgdepth - maxdepth/2 );
			mindepth = Math.max( mindepth, 0 );
			maxdepth = Math.min( maxdepth, avgdepth*2 );
			variables.stroke.value = maxdepth - mindepth;

			variables.position.value = g.dialogueControl.advancedController._dialogueDataStore["atv_position"];

			getPleasure();
			
			for(var k in variables) {
				if(!variables.hasOwnProperty(k)) continue;

				try {
					updateVariable(k, variables[k]);
				} catch(e) {
					alert("failed to update variable " + k + " " + e);
				}
			}
		}

		public function checkRequirements(req, v)
		{
			var val = variables[v].state;
			for(var i in req) {
				if(!req.hasOwnProperty(i)) continue;
				var r = req[i];
				if( val == r ) return 1 / objectLength(req);
			}
			return 0;
		}

		public function checkState(state)
		{
			var score=0;
			if(!state.hasOwnProperty('requirements')) return score;

			var reqs = state.requirements;
			for(var v in reqs) {
				if(!reqs.hasOwnProperty(v)) continue;
				var req = reqs[v];
				var ret = checkRequirements(req, v);
				if( ret==0 ) return 0;
				score += ret;
			}
			if(score<=0) return 0;
			return score + state.priority;
		}

		public function updateState()
		{
			var oldstate = state;
			state = "none";
			var maxscore=0;

			for(var k in states) {
				if(!states.hasOwnProperty(k)) continue;
				var s = states[k];
				var score = checkState(s);
				if( score > maxscore ) {
					state = k;
					maxscore = score;
				}
			}

			g.dialogueControl.advancedController._dialogueDataStore["sm_state"] = state;
			if( oldstate != state ) prev_state = oldstate;
			callState(state, oldstate!=state, prev_state);
		}

		public function Update()
		{
			if(variables.depth && variables.depth.cutoffs && variables.depth.cutoffs.hilt)
				variables.depth.cutoffs.hilt = penis_len*0.99;
			variables.stroke.cutoffs = variables.depth.cutoffs;
			
			try {
				updateVariables();
			} catch(ex) {
				alert("failed to updateVariables: " + ex);
			}
			try {
				updateState();
			} catch(ex) {
				alert("failed to updateState: " + ex);
			}
		}

		public function InitData(event:*)
		{
			try {
				var data:String = event.target.data;
				var props;
				props = JSON.decode(data);

				//log("parsed JSON! encode == "+JSON.encode(props) );

				//states = props.states;
				states = {};

				for(var k in props.states) {
					if(!props.states.hasOwnProperty(k)) continue;
					log("loading state "+k);
					var p = getStateProperties(k);

					var p2 = props.states[k];
					for(var prop in p2) {
						if(!p2.hasOwnProperty(prop)) continue;
						p[prop] = p2[prop];
					}

					for(var e in p.effects) {
						if(!p.effects.hasOwnProperty(e)) continue;
						p.effects[e] = Number(p.effects[e]);
					}
				}

				for(var name in props.variables) {
					if(!props.variables.hasOwnProperty(name)) continue;
					log("loading variable "+name);
					var v = {
						value: 0,
						//cutoffs: {},
						state: "none"
					};

					for(var k in props.variables[name]) {
						if(!props.variables[name].hasOwnProperty(k)) continue;
						v[k] = props.variables[name][k];
					}

					variables[name] = v;
				}
			} catch(ex) {
				alert("InitData failed to load json data: " + ex);
				trace("InitData failed to load json data: " + ex);
			}

			try {
				InitDefaults();
			} catch(ex) {
				alert("InitDefaults failed to load json data: " + ex);
				trace("InitDefaults failed to load json data: " + ex);
			}

			log("loaded "+objectLength(states)+" states and "+objectLength(variables)+" variables");
		}

		public function InitDefaults(path:String = "", e:Event = null)
		{
			//log(path);
			//log(e.toString());

			for(var k in states) {
				if(!states.hasOwnProperty(k)) continue;
				var p = getStateProperties(k);
				var priority = p.priority / 100;
				//log("building states for "+k);
				g.dialogueControl.states[k] = new mydialogstateclass(int(300 * priority), 1);
				//log("built state for "+k);
				g.dialogueControl.states["now_"+k] = new mydialogstateclass(int(500 * priority), 2);
				for(var k2 in states) {
					if(!states.hasOwnProperty(k2) || k==k2) continue;
					g.dialogueControl.states[k+"_to_"+k2] = new mydialogstateclass(int(800 * priority), 2);
				}

				writeStateProperties(k, p, 0);
			}

			for(var k in variables) {
				if(!variables.hasOwnProperty(k)) continue;
				
				if( variables[k].hasOwnProperty('conditions') && !variables[k].hasOwnProperty('cutoffs') ) {
					var cutoff_true = objectLength(variables[k].conditions);
					//log(k+" has "+cutoff_true+" conditions");
					variables[k].cutoffs = { "true": cutoff_true };
				}
				
				var cutoffs = variables[k].cutoffs;
				for(var v in cutoffs) {
					if( !cutoffs.hasOwnProperty(v) ) continue;
					var p = getStateProperties(k+"_"+v);
					var priority = p.priority / 100;
					g.dialogueControl.states[k+"_"+v] = new mydialogstateclass(int(200 * priority), 1);
					g.dialogueControl.states["now_"+k+"_"+v] = new mydialogstateclass(int(300 * priority), 2);

					for(var v2 in cutoffs) {
						if(v2==v) continue;
						if( !cutoffs.hasOwnProperty(v2) ) continue;
						g.dialogueControl.states[k+"_"+v+"_to_"+k+"_"+v2] = new mydialogstateclass(int(600 * priority), 2);
					}
				}
			}

		}

		public function convertFilePath(original:String):String {
			if (original == "" || original == null) {
				return "";
			}
			
			if (original.indexOf("$")==0) {
				return "Mods/"+original.substr(1);
			} else {
				//return "Mods/" + main.lastLoadedCData + "/" + original;
				return "Mods/" + cacheCData + "/" + original;
			}
		}

		public function Init(filepath:String = "")
		{
			log("Init StateManager "+filepath);
			if(!filepath) {
				InitDefaults();
				return;
			}

			var fullPath:String = convertFilePath(filepath);
			log("Init StateManager "+fullPath);
			var loader:URLLoader = new URLLoader();
			loader.addEventListener(Event.COMPLETE, InitData);
			loader.addEventListener(IOErrorEvent.IO_ERROR, InitDefaults);
			
			loader.load(new URLRequest(fullPath));
		}
	}


	public dynamic class Main extends flash.display.MovieClip
	{
		var her;
		const modname : String = "statemachine"

		public function initl(l)
		{
			main = l;
			//eDOM = l.target.applicationDomain;
			eDOM = l.eDOM;
			lProxy = main.lDOM.getDefinition("Modules.lProxy");
			//mydialogstateclass = main.eDOM.getDefinition("obj.dialogue.DialogueState") as Class;
			mydialogstateclass = eDOM.getDefinition("obj.dialogue.DialogueState") as Class;
			DialogueLine = eDOM.getDefinition("obj.dialogue.DialogueLine") as Class;
			Word = eDOM.getDefinition("obj.dialogue.Word") as Class;
			g = l.g;
			her = l.her;
			//var modSettingsLoader = main.eDOM.getDefinition("Modules.modSettingsLoader") as Class;			//finds the modsettingsloader class from the loader
			//var mySettingsLoader = new modSettingsLoader(modname+"settings",onSettingsSucceed);	//creates a new settingsloader specifying the file to load and the funtion to run
			//mySettingsLoader.addEventListener("settingsNotFound",onSettingsFail);						//adds an event listener in case the settings file is failed to be found/loaded

			animtools = main.animtools_comm;
			if( ! animtools ) alert("animtools not found!");

			dialogueAPI = main.getAPI("DialogueActions");
			if( ! dialogueAPI ) alert("DialogueActions API not found!");
			var registerTrig = dialogueAPI["registerTrigger"].getFunction();
			registerTrig("SET_RESISTANCE", 4, SetResistance, this, []);
			registerTrig("SMLOADCONFIG", -1, SMLoadConfig, this, []);
			registerTrig("SM_ENABLE_DEBUG", 0, SMEnableDebug, this, []);
			registerTrig("SM_DISABLE_DEBUG", 0, SMDisableDebug, this, []);

			//g.dialogueControl.advancedController._dialogueDataStore["dt_recentdepth"] = 7;
			//this.addEventListener(Event.ENTER_FRAME, doUpdate);
			main.addEnterFramePersist(doUpdate);
			//main.addEventListener(Event.ENTER_FRAME, doUpdate);
			//main.addEnterFrame(doUpdate);

			g.dialogueControl.advancedController._dialogueDataStore["dt_deepestyet"] = deepestyet;
			g.dialogueControl.advancedController._dialogueDataStore["dt_lasthilt"] = lasthilt;
			//g.her.VIGOUR_WINCE_LEVEL=0;

			statemanager.Init();

			//var checkWordActionproxy = lProxy.createProxy(g.dialogueControl, "checkWordAction");
			//checkWordActionproxy.addPre(smcheckWordAction, 1);

			l.addEventListener("loadCharComplete", updateCacheCData);

			main.unloadMod();
			log("Main::initl done");
		}

		private function updateCacheCData(e:*):void {
			if(!e.data.cData) return;

			cData = e.data.cData;
			
			if (cData != "$OVER$") {
				cacheCData = cData;
			}
		}
			
		/** function registered to run when the settings file is done loading into flash **/
		function onSettingsSucceed(e)			
		{
			finishinit();
		}
		
		/** function registered to run when the settings file fails to load **/
		function onSettingsFail(e)			
		{
			main.updateStatusCol(e.msg,"#FF0000");		//displays error message
			finishinit();
		}
			
		function finishinit()
		{
			//main.unloadMod();
		}

		function modifyposition(dict:Dictionary)
		{
			var e;
			e.settings = dict;
			animtools.settingloadpart(e);
			animtools.updateeverything();
		}

		public function SMLoadConfig(args):void {
			log("found load command");

			var path = args[0];
			alert("loading "+path);
			path = path.replace("_slash5C_","\\");
			path += ".txt";
			statemanager = new StateManager();
			statemanager.Init(path);
		}

		public function SMEnableDebug(args):void {
			debug=true;
			log("debug mode enabled");
		}

		public function SMDisableDebug(args):void {
			log("debug mode disabled");
			debug=false;
		}

		public function SetResistance(args):void {
			var resist = Number(args[0]);
			var dist = Number(args[1]);
			var normalize = Number(args[2]);
			var descrease = Number(args[3]);

			log("setting resistance to "+resist+", "+dist+", "+normalize+", "+descrease);
			animtools.disablebodyintro = 0;
			animtools.resistancewithbodycontact=1;
			animtools.characterresistancepreset = 5;
			animtools.updateresistancepreset();
			animtools.adjustspeedinbodycontact=1;
			animtools.resistancestartingdistance=dist;
			animtools.startingresistance=resist;
			animtools.minresistance=resist;
			animtools.currentresistance=resist;

			animtools.resistnormalizerate=normalize;
			animtools.resistdecreaserate=descrease;
			animtools.movementresistancemult=normalize;

			/*animtools.resistoverriderate=0.01;
			animtools.resistoverridereturnrate=0.2;
			animtools.resistoverridemax=overridemax;*/

			animtools.setcurrentresistance(resist);
		}

		public function doUpdate(a)
		{
			if(g.gamePaused || !g.gameRunning) return;

			doStats(a);
			statemanager.Update();
		}
		
		function doStats(a)
		{
			//if(g.her.VIGOUR_WINCE_LEVEL<1000) throw new Error("her wince level == "+String(g.her.VIGOUR_WINCE_LEVEL));
			var herpos:Number = g.her.pos;
			var speed = 0;//she doesn't feel speed if it's not in her?
			var contact:Boolean = testhitpoints();
			if(contact==false && herpos > contactdist) {
				contactdist = 0.8;
			}
			if(contact==true) {
				contactdist = Math.min(contactdist, Math.min((herpos+lastpos)/2.0, herpos) );
				//speed = Math.abs(g.her.speed)*5;
				speed = g.her.absMovement * 2;//try to make it more of a 0 through 100 scale
			}
			lastpos = herpos;
			herpos = (herpos-contactdist) / (1-contactdist);
			//should I prevent herpos from going below 0?

			penis_len = g.him.penis.scaleX * 10.0;//approximately equal to inches?
			penis_girth = g.him.penis.scaleY;
			var herpos_scaled:Number = herpos * penis_len;
			var vigour:Number = Math.min(1.0, g.her.vigour / 1000.0);//seems like vigour can go over 1 sometimes?
			var now:Date = new Date();
			now_seconds = now.getTime()/1000.0;
			g.dialogueControl.advancedController._dialogueDataStore["dt_time"] = now_seconds;
			g.dialogueControl.advancedController._dialogueDataStore["dt_penislength"] = penis_len;
			g.dialogueControl.advancedController._dialogueDataStore["dt_penisgirth"] = penis_girth;
			g.dialogueControl.advancedController._dialogueDataStore["dt_herpos"] = herpos;
			g.dialogueControl.advancedController._dialogueDataStore["dt_contact"] = contact;//for debugging
			g.dialogueControl.advancedController._dialogueDataStore["dt_contactdist"] = contactdist;//for debugging

			recentdeepest.calcStats(herpos_scaled, now_seconds);
			recentvigour.calcStats(vigour, now_seconds);
			recentspeed.calcStats(speed, now_seconds);
			recentresistance.calcStats(animtools.reistiveamount, now_seconds);

			if(herpos > deepestyet) {
				deepestyet = herpos;
				g.dialogueControl.advancedController._dialogueDataStore["dt_deepestyet"] = deepestyet;
			}
			if(herpos > 0.99) {
				lasthilt = now_seconds;
				g.dialogueControl.advancedController._dialogueDataStore["dt_lasthilt"] = lasthilt;
			}
		}

		function checkPointInHer(ax:Number, ay:Number) : Boolean
		{
			/*if(g.her.torso.hitTestPoint(ax,ay, true)) { return true;}
			if(g.her.torsoBack.hitTestPoint(ax,ay, true)) { return true;}
			if(g.her.leftLegContainer.hitTestPoint(ax,ay, true)) { return true;}
			return false;*/

			if(g.her.torso.midLayer.chest.hitTestPoint(ax,ay, true)) { return true;}   //changed this after v13 probably cause would trigger on arms, reverted V14 cause wouldn't do it for front chest
			if(g.her.torso.backside.hitTestPoint(ax,ay, true)) { return true;}
			if(g.her.torso.back.hitTestPoint(ax,ay, true)) { return true;}
			//if(g.her.torso.midLayer.hitTestPoint(ax,ay, true)) { return true;}   //changed this after v13 probably cause would trigger on arms, reverted V14 cause wouldn't do it for front chest
			
			//if(g.her.head.hitTestPoint(ax,ay, true)) { return true;}
			if(g.her.torso.leg.thigh.hitTestPoint(ax,ay, true)) { return true;}
			if(g.her.leftLegContainer.leg.thigh.hitTestPoint(ax,ay, true)) { return true;}
			//if(g.her.torso.rightCalfContainer.calf.hitTestPoint(ax,ay, true)) {return true;}
			//if(g.her.torsoBack.leftBreast.getChildAt(0).hitTestPoint(ax,ay, true)) { return true;}

			return false;
		}

		function listchildren(p) : String
		{
			var names:String = "";
			try {
				names += "<"+p.name+">";
				try {
				for (var i:uint = 0; i < p.numChildren; i++)
					names += listchildren(p.getChildAt(i));
				} catch(e:Error) {}
				names += "</"+p.name+">";
			} catch(error:Error) {}
			return names;
		}
		
		/*
		//https://forums.adobe.com/thread/873737
		private function checkForHit(a:BitmapData,b:BitmapData):Boolean {
			return a.hitTest(new Point(0,0),0xff,b,new Point(0,0),0xff);
		}
		
		private function createBitmapData(a:DisplayObject):BitmapData {
			var bmpd:BitmapData = new BitmapData(a.stage.stageWidth,a.stage.stageHeight,true,0x000000ff);
			var currentTrans:Transform = a.transform;
			var currentMat:Matrix = currentTrans.concatenatedMatrix;
			bmpd.draw(a,currentMat);
			return bmpd;
		}
		*/

		function testhitpoints() : Boolean
		{
			//if( ! animtools ) return false;
			if( animtools.testhitpoints() )
				return true;
			else if((animtools.penisinmouthdisttrack + animtools.penisinmouthdisttrackhighest) / 2 < her.pos && animtools.penisinmouthdisttrack != 999999 && animtools.penisinmouthdisttrackhighest != -999999)
				return true;
			return false;

			/*var penisBmp:BitmapData = createBitmapData(g.him.penis);
			var herBacksideBmp:BitmapData = createBitmapData(g.her.torso.backside);
			var herBackBmp:BitmapData = createBitmapData(g.her.torsoBack);

			if(checkForHit(penisBmp, herBacksideBmp)) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="her backside"; return true; }
			if(checkForHit(penisBmp, herBackBmp)) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="her back"; return true; }

			return false;*/

			/*if(g.her.torso.backside.hitTestObject(g.him.penis)) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="her.torso.backside"; return true; }
			if(g.her.torsoBack.hitTestObject(g.him.penis)) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="her.torsoBack"; return true; }
			//if(g.her.leftLegContainer.leg.thigh.hitTestObject(g.him.penis)) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="her.leftLegContainer.leg.thigh"; return true; }
			//if(g.her.torso.leg.thigh.hitTestObject(g.him.penis)) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="her.torso.leg.thigh"; return true; }
			return false;*/

			var ax:Number = g.him.getPenisTipPoint().x;
			var ay:Number = g.him.getPenisTipPoint().y;

			//throw new Error(listchildren(g.him));
			//g.dialogueControl.advancedController._dialogueDataStore["dt_names"] = listchildren(g.him);

			if( checkPointInHer(ax, ay) ) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="tip"; return true; }

			var penisRect = g.him.penis.getRect(this);
			var topLeft = /*g.him.penis.localToGlobal*/(penisRect.topLeft);
			var bottomRight = /*g.him.penis.localToGlobal*/(penisRect.bottomRight);
			var midX:Number = (topLeft.x + bottomRight.x) / 2;
			var midY:Number = (topLeft.y + bottomRight.y) / 2;
			var frontX:Number = (midX + ax + ax) / 3;
			var backX:Number = midX - (ax - midX);
			backX = (midX + backX + backX) / 3;
			var frontY:Number = (midY + ay + ay) / 3;
			var backY:Number = midY - (ay - midY);
			backY = (midY + backY + backY) / 3;

			//g.dialogueControl.advancedController._dialogueDataStore["dt_debug"] = "ax:"+ax.toFixed(2)+", ay:"+ay.toFixed(2)+", midX:"+midX.toFixed(2)+", midY:"+midY.toFixed(2)+", penis:"+topLeft.toString()+", "+bottomRight.toString();

			if( checkPointInHer(midX, midY) ) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="penismid"; return true; }
			if( checkPointInHer(frontX, frontY) ) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="penisfront"; return true; }
			//if( checkPointInHer(ax, midY) ) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="penismix"; return true; }
			//if( checkPointInHer(midX, ay) ) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="penismix"; return true; }
			//if( checkPointInHer(backX, backY) ) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="penisback"; return true; }

			//if(g.her.head.hitTestObject(g.him.penis)) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="head"; return true; }
			//if(g.her.torsoBack.chestBack.hitTestObject(g.him.penis)) { g.dialogueControl.advancedController._dialogueDataStore["dt_col"]="torsoBack.chestBack"; return true; }

			return false;
	
			//
			//else if(g.her.torso.topContainer.hitTestPoint(ax,ay, true)) return true;
			//
			//
			//else if(g.her.torsoBack.backside.hitTestPoint(ax,ay, true)) return true;
			//else if(g.her.torsoBack.chestBack.hitTestPoint(ax,ay, true)) return true;
	
			//else if(g.her.leftLegContainer.hitTestPoint(ax,ay, true)) return true;		//meh
			//else if(g.her.rightArmContainer.hitTestPoint(ax,ay, true)) return true;		//probably don't want this
			//else if(g.her.torso.midLayer.leftArm.hitTestPoint(ax,ay, true)) return true; 	//dont add
		}

		function doUnload()
		{
			//cMC.removeEventListener(Event.ENTER_FRAME, doUpdate);
		}
		
	}
}

