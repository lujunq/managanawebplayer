package {
	
	// FLASH PACKAGES
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.ContextMenuEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.SharedObject;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.display.Stage;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.system.System;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.net.navigateToURL;
	import flash.display.LoaderInfo;
	import flash.events.MouseEvent;
	import flash.utils.setTimeout;
	import flash.utils.clearTimeout;
	
	// CICLOPE CLASSES
	import art.ciclope.managana.ManaganaPlayer;
	import art.ciclope.managana.ManaganaInterface;
	import art.ciclope.event.DISLoad;
	import art.ciclope.event.Message;
	import art.ciclope.managana.system.LinkManagerFlashPlayer;
	import art.ciclope.event.ReaderServerEvent;
	import art.ciclope.managana.system.HTMLBoxFlashPlayer;
	import art.ciclope.managana.graphics.MessageWindow;
	import art.ciclope.display.GraphicSprite;
	import art.ciclope.managana.graphics.Target;
	import art.ciclope.managana.data.ConfigData;
	
	/**
	 * <b>Availability:</b> CICLOPE AS3 Classes - www.ciclope.art.br<br>
	 * <b>License:</b> GNU LGPL version 3<br><br>
	 * This is the Managana web player main class.
	 * @author Lucas Junqueira - lucas@ciclope.art.br
	 */
	public class Main extends Sprite {
		
		// CONSTANTS
		
		private const MANAGANAVERSION:String = "1.7.0 (beta 24/04/15a)";			// current Managana version
		private const READERKEY:String = "managana";								// access key for managana reader server
		private const READERMETHOD:String = "post";									// reader server access method
		private const READERENDING:String = ".php";									// reader server script ending
		private const INITIALERRORTEXT:String = "Application initialize error!";	// application initialize error message
		
		// STATIC VARIABLES
		
		/**
		 * Is managana being dragged?
		 */
		public static var dragging:Boolean = false;
		/**
		 * Managana drag interval.
		 */
		public static var drinterval:int = 0;
		/**
		 * Stage click interval.
		 */
		public static var clickinterval:int = 0;
		/**
		 * Was stage clicked recently?
		 */
		public static var recentclick:Boolean = false;
		
		// VARIABLES
		
		private var _managana:ManaganaPlayer;				// the player itself
		private var _interface:ManaganaInterface;			// player interface
		private var _menu:ContextMenu;						// player context menu
		private var _flashvars:Array;						// data received from flashvars
		private var _linkmanager:LinkManagerFlashPlayer;	// a manager for external links
		private var _boxmanager:HTMLBoxFlashPlayer;			// a manager for html box
		private var _loginkey:String;						// a login key for OpenID/oAuth authentication
		private var _bg:Shape;								// the background color
		private var _playActivate:Boolean;					// play content on activate?
		private var _framerate:uint;						// default frame rate
		private var _managanaConfig:ConfigData;				// system configuration
		
		/**
		 * Wait for the stage to become available.
		 */
		public function Main():void {
			// wait for stage
			if (stage) init();
			else this.addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		/**
		 * Stage ready: initialize player.
		 */
		private function init(e:Event = null):void {
			// prepare stage
			if (this.hasEventListener(Event.ADDED_TO_STAGE)) this.removeEventListener(Event.ADDED_TO_STAGE, init);
			this.stage.align = StageAlign.TOP_LEFT;
			this.stage.scaleMode = StageScaleMode.NO_SCALE;
			this.stage.addEventListener(Event.RESIZE, onResize);
			// load configuration
			this._managanaConfig = new ConfigData();
			this._managanaConfig.addEventListener(Event.COMPLETE, onConfigComplete);
			this._managanaConfig.addEventListener(Event.CANCEL, onConfigCancel);
			// context menu
			this._menu = new ContextMenu();
			var managanaAbout:ContextMenuItem = new ContextMenuItem(("imagined with Managana version " + this.MANAGANAVERSION), true, false);
			var managanaSite:ContextMenuItem = new ContextMenuItem("visit www.managana.org");
			managanaSite.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, onManaganaSite);
			this._menu.customItems.push(managanaAbout, managanaSite);
			this.contextMenu = this._menu;
		}
		
		/**
		 * Stage resize.
		 */
		private function onResize(evt:Event = null):void {
			if (this._managana != null) {
				this._managana.width = this.stage.stageWidth;
				this._managana.height = this._managana.width * this._managana.screenheight / this._managana.screenwidth;
				if (this._managana.height > this.stage.stageHeight) {
					this._managana.height = this.stage.stageHeight;
					this._managana.width = this._managana.height * this._managana.screenwidth / this._managana.screenheight;
				}
				this._managana.x = this.stage.stageWidth / 2;
				this._managana.y = this.stage.stageHeight / 2;
				if (this._interface != null) this._interface.redraw();
				this._bg.width = this.stage.stageWidth;
				this._bg.height = this.stage.stageHeight;
			}
		}
		
		/**
		 * System configuration load error: halt!
		 */
		private function onConfigCancel(evt:Event):void {
			this._managanaConfig.removeEventListener(Event.COMPLETE, onConfigComplete);
			this._managanaConfig.removeEventListener(Event.CANCEL, onConfigCancel);
			var message:MessageWindow = new MessageWindow(this.stage.stageWidth, this.stage.stageHeight, false);
			message.setText(this.INITIALERRORTEXT);
			this.addChild(message);
		}
		
		/**
		 * System configuration load complete.
		 */
		private function onConfigComplete(evt:Event):void {
			this._managanaConfig.removeEventListener(Event.COMPLETE, onConfigComplete);
			this._managanaConfig.removeEventListener(Event.CANCEL, onConfigCancel);
			// get flashvars configuration
			var paramObj:Object = LoaderInfo(this.root.loaderInfo).parameters;
			for (var name:String in paramObj) this._managanaConfig.setConfig(name, String(paramObj[name]));
			// start managana
			this._bg = new Shape();
			if (this._managanaConfig.isConfig('bgcolor')) {
				this._bg.graphics.beginFill(uint(this._managanaConfig.getConfig('bgcolor')));
			} else {
				this._bg.graphics.beginFill(0x000000);
			}
			this._bg.graphics.drawRect(0, 0, 100, 100);
			this._bg.graphics.endFill();
			this._bg.width = this.stage.stageWidth;
			this._bg.height = this.stage.stageHeight;
			this.addChild(this._bg);
			// link manager
			this._linkmanager = new LinkManagerFlashPlayer();
			this._linkmanager.visible = false;
			this.addChild(this._linkmanager);
			// html box manager
			this._boxmanager = new HTMLBoxFlashPlayer();
			this._boxmanager.addEventListener(Event.CLOSE, onHTMLBoxClose);
			// prepare player
			this._managana = new ManaganaPlayer(null, this.stage.stageWidth, this.stage.stageHeight, "landscape", 0, 0, false, "", true, true, ManaganaPlayer.TYPE_WEB);
			this._managana.serverurl = this._managanaConfig.getConfig('server');
			this._managana.x = this.stage.stageWidth / 2;
			this._managana.y = this.stage.stageHeight / 2;
			this._managana.addEventListener(Message.OPENURL, onOpenURL);
			this._managana.addEventListener(Message.OPENHTMLBOX, onHTMLBox);
			this._managana.addEventListener(Message.SHARE_FACEBOOK, onOpenURL);
			this._managana.addEventListener(Message.SHARE_TWITTER, onOpenURL);
			this._managana.addEventListener(Message.SHARE_GPLUS, onOpenURL);
			this.addChild(this._managana);
			// reader server key
			var key:String = READERKEY;
			if (this._managanaConfig.isConfig('readerkey')) {
				key = this._managanaConfig.getConfig('readerkey');
			}
			// reader server access method
			var method:String = READERMETHOD;
			if (this._managanaConfig.isConfig('readermethod')) {
				method = this._managanaConfig.getConfig('readermethod');
			}
			// reader server script ending
			var ending:String = READERENDING;
			if (this._managanaConfig.isConfig('readerending')) {
				ending = this._managanaConfig.getConfig('readerending');
			}
			// reader server
			var readerserver:String = "";
			var showinterface:Boolean = true;
			var showclock:Boolean = true;
			var showvote:Boolean = false;
			var showcomment:Boolean = false;
			var showrate:Boolean = false;
			var shownote:Boolean = false;
			var showzoom:Boolean = false;
			var showuser:Boolean = false;
			if (this._managanaConfig.isConfig('server')) readerserver = this._managanaConfig.getConfig('server');
			if (this._managanaConfig.isConfig('showinterface')) showinterface = (this._managanaConfig.getConfig('showinterface') == "true");
			if (this._managanaConfig.isConfig('showclock')) showclock = (this._managanaConfig.getConfig('showclock') == "true");
			if (this._managanaConfig.isConfig('showvote')) showvote = (this._managanaConfig.getConfig('showvote') == "true");
			if (this._managanaConfig.isConfig('showcomment')) showcomment = (this._managanaConfig.getConfig('showcomment') == "true");
			if (this._managanaConfig.isConfig('showrate')) showrate = (this._managanaConfig.getConfig('showrate') == "true");
			if (this._managanaConfig.isConfig('shownote')) shownote = (this._managanaConfig.getConfig('shownote') == "true");
			if (this._managanaConfig.isConfig('showzoom')) showzoom = (this._managanaConfig.getConfig('showzoom') == "true");
			if (this._managanaConfig.isConfig('showuser')) showuser = (this._managanaConfig.getConfig('showuser') == "true");
			// reader server
			this._interface = new ManaganaInterface(readerserver, key, method, ending, false, showinterface, showclock, showvote, true, showcomment, showrate, shownote, showzoom, showuser);
			this._interface.addEventListener(Message.OPENURL, onOpenURL);
			this._interface.addEventListener(Message.SHARE_FACEBOOK, onOpenURL);
			this._interface.addEventListener(Message.SHARE_GPLUS, onOpenURL);
			this._interface.addEventListener(Message.SHARE_TWITTER, onOpenURL);
			this._interface.addEventListener(Message.AUTHENTICATE, onAuthenticate);
			this._interface.addEventListener(ReaderServerEvent.COMMUNITY_INFO, onCommunityInfo);
			// ui setup
			this.addChild(this._interface);
			this._interface.player = this._managana;
			if (this._managanaConfig.isConfig('logo')) if (this._managanaConfig.getConfig('logo') != "") {
				this._interface.setLogo("./pics/" + this._managanaConfig.getConfig('logo'));
			}
			// remote control information available?
			if (this._managanaConfig.isConfig('remotegroup')) this._interface.remoteGroup = this._managanaConfig.getConfig('remotegroup');
			if (this._managanaConfig.isConfig('multicastip')) this._interface.multicastip = this._managanaConfig.getConfig('multicastip');
			if (this._managanaConfig.isConfig('multicastport')) this._interface.multicastport = this._managanaConfig.getConfig('multicastport');
			// public remote control?
			if (this._managanaConfig.isConfig('publicremote')) if (this._managanaConfig.getConfig('publicremote') != "") {
				this._interface.startPublicRemote(this._managanaConfig.getConfig('publicremote'), this._interface.remoteGroup, this._interface.cirrusKey);
			}
			// login key
			this._loginkey = "";
			if (this._managanaConfig.isConfig('loginkey')) {
				this._loginkey = this._managanaConfig.getConfig('loginkey');
			}
			// initial stream
			if (this._managanaConfig.isConfig('stream')) if (this._managanaConfig.getConfig('stream') != "") {
				this._managana.startStream = this._managanaConfig.getConfig('stream');
			}
			// drag
			this.stage.addEventListener(MouseEvent.MOUSE_DOWN, onStageMouseDown);
			this.stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
			this.stage.addEventListener(MouseEvent.CLICK, onStageClick);
			// load community
			this._managana.addEventListener(DISLoad.COMMUNITY_OK, onCommunityOK);
			this._managana.loadCommunity(this._managanaConfig.getConfig('community'));
		}
		
		/**
		 * The community is ready.
		 */
		private function onCommunityOK(evt:DISLoad):void {
			this.onResize();
		}
		
		/**
		 * Open the Managana website.
		 */
		private function onManaganaSite(evt:ContextMenuEvent):void {
			navigateToURL(new URLRequest("http://www.managana.org/"), "_blank");
		}
		
		/**
		 * Open an URL sent from managana player.
		 */
		private function onOpenURL(evt:Message):void {
			this._linkmanager.openURL(String(evt.param.value), String(evt.param.target));
		}
		
		/**
		 * Open a HTML box over the Managana interface.
		 */
		private function onHTMLBox(evt:Message):void {
			this.addChild(this._boxmanager);
			this._boxmanager.visible = true;
			this._framerate = this.stage.frameRate;
			this._playActivate = this._managana.playing;
			this._managana.pause();
			this._boxmanager.openURL("community/" + this._managana.currentCommunity + ".dis/media/" + evt.param.from + "/html/" +  String(evt.param.folder) + "/index.html");
		}
		
		/**
		 * HTML box manager window was closed.
		 */
		private function onHTMLBoxClose(evt:Event):void {
			this._boxmanager.visible = false;
			this.removeChild(this._boxmanager);
			this.stage.frameRate = this._framerate;
			if (this._playActivate) this._managana.play();
			if (this._boxmanager.pcode != "") {
				this._managana.run(this._boxmanager.pcode);
			}
			this._boxmanager.pcode = "";
		}
		
		/**
		 * Mouse down on stage.
		 */
		private function onStageMouseDown(evt:MouseEvent):void {
			if (!this._linkmanager.visible) {
				// wait to check if the user wants to drag managana
				Main.dragging = false;
				this._managana.mouseChildren = true;
				Main.drinterval = setTimeout(managanaDrag, 200);
			}
		}
		
		/**
		 * Mouse click on stage.
		 */
		private function onStageClick(evt:MouseEvent):void {
			// there is a recent click
			if (Main.recentclick) {
				Main.recentclick = false;
				this._managana.scaleX = 1;
				this._managana.scaleY = 1;
				this._managana.x = this.stage.stageWidth / 2;
				this._managana.y = this.stage.stageHeight / 2;
			} else {
				Main.recentclick = true;
				Main.clickinterval = setTimeout(managanaClick, 200);
			}
		}
		
		/**
		 * Release recent click flag.
		 */
		private function managanaClick():void {
			Main.recentclick = false;
		}
		
		/**
		 * Start managana drag.
		 */
		private function managanaDrag():void {
			Main.dragging = true;
			this._managana.mouseChildren = false;
			if (this._managana.userDrag) this._managana.startDrag();
		}
		
		/**
		 * Mouse up on stage / stop managana drag.
		 */
		private function onStageMouseUp(evt:MouseEvent):void {
			if (!this._linkmanager.visible) {
				if (!Main.dragging) {
					clearTimeout(Main.drinterval);
				}
				Main.dragging = false;
				if (this._managana.userDrag) this._managana.stopDrag();
				this._managana.mouseChildren = true;
			}
		}
		
		/**
		 * Open an OpenID/oAuth authentication link.
		 */
		private function onAuthenticate(evt:Message):void {
			this._linkmanager.authenticate(String(evt.param.value), this._managana.currentCommunity, this._managana.currentStream);
		}
		
		/**
		 * Reader server just loaded community info.
		 */
		private function onCommunityInfo(evt:ReaderServerEvent):void {
			// is there an user to login?
			if (this._loginkey != "") {
				this._interface.doOpenLogin(this._loginkey);
				this._loginkey = "";
			}
		}
	}
	
}