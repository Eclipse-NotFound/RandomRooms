package {
    import flash.display.*;
    import flash.system.ApplicationDomain;
    import flash.geom.*;

    // Static adapters around the game's own unit factory. Never call Unit.step,
    // Location.createUnit, addVisual (HUD), or a weapon/AI update here.
    public class NativeEntities {
        private var domain:ApplicationDomain;
        private var graph:Object;
        private var loc:Object;
        private var Unit:Class;
        private var All:Class;
        private var world:Object;
        public var items:Array=[];
        public var warnings:Array=[];
        public var fixedCount:int=0;
        public var exampleCount:int=0;
        public var emptyPoints:int=0;

        public function NativeEntities(d:ApplicationDomain,g:Object,location:Object) {
            domain=d; graph=g; loc=location;
            Unit=d.getDefinition("fe.unit.Unit") as Class;
            All=d.getDefinition("fe.AllData") as Class;
            var World:Class=d.getDefinition("fe.World") as Class;
            world=World.w;
        }

        public function add(node:XML,def:XML,examples:Boolean):void {
            var sourceId:String=String(node.@id);
            var type:String=String(def.@tip);
            var random:Boolean=type=="up" || type=="enspawn";
            if(random && !examples) return;
            var x:int=int(node.@x),y:int=int(node.@y);
            if(loc.mirror) x=loc.spaceX-x-Math.max(1,int(def.@size));
            var id:String=sourceId;
            var variantId:String=null;
            if(random) {
                id=type=="enspawn" ? String(loc.tipSpawn) : id;
                var water:Boolean=(loc.biom==1 || loc.biom==5) && loc.getTile(x,y).water>0;
                var resolved:String=loc.randomUnit(id,water);
                if(resolved) id=resolved;
                else if(type=="up" || !All.d.obj.(@id==id).length()) { emptyPoints++; return; }
                if(id=="slmine") { variantId=id; id="slime"; }
            }
            if(id=="mines") {
                for(var offset:int=0;offset<=4;offset+=2) create("mine",node,x+offset,y,random,sourceId);
            } else create(id,node,x,y,random,sourceId,variantId);
        }

        private function create(id:String,node:XML,x:int,y:int,random:Boolean,sourceId:String,variantId:String=null):void {
            var phase:String="构造";
            try {
                var copy:XML=node.copy();
                delete copy.scr;
                for each(var key:String in ["scr","alarm","scrdie","scropen","scrclose","scrtouch","fun","die","trigger","trig","code","uid","dis","hide"])
                    delete copy.@[key];
                var def:XML=All.d.obj.(@id==id)[0];
                // putLoc would otherwise spawn a linked damager and run step().
                if(String(def.@cl)=="UnitTrigger") copy.@allid="__editor_static_preview__";
                if(String(def.@cl)=="UnitNPC") prepareNPC(copy,id);
                var cid:String=copy.@cid.length() ? String(copy.@cid) : loc.randomCid(variantId || id);
                var unit:Object=Unit["create"](id,loc.locDifLevel,copy,null,cid);
                if(!unit) throw new Error("没有对应的游戏单位类");
                phase="定位";
                if(unit.inter) unit.inter.saveLoot=0;
                unit.setLevel(loc.enemyLevel);
                unit.setHero(0);
                var span:int=Math.floor((unit.scX-1)/40)+1;
                var wasActive:Boolean=loc.active;
                loc.active=false;
                try {
                    if(id=="thunderhead") {
                        // Its override creates 29 live turrets and starts a cross-room
                        // flight path. Use the authored marker as a static body anchor.
                        unit.loc=loc; unit.setPos((x+1.5)*40,(y+1)*40-1);
                        unit.cTransform=loc.cTransform;
                    } else unit.putLoc(loc,(x+span*0.5)*40,(y+1)*40-1);
                }
                finally { loc.active=wasActive; }
                unit.stay=true;
                unit.dx=unit.dy=0;
                unit.celX=unit.X+unit.storona*200;
                unit.celY=unit.Y-unit.scY*0.7;
                if(["Mine","UnitTrap","UnitTrigger","UnitDamager","UnitSlime"].indexOf(String(def.@cl))>=0) unit.setVis(true);
                phase="姿态";
                var weapon:Object=unit.currentWeapon;
                var turret:Boolean=String(def.@cl)=="UnitTurret";
                if(weapon) {
                    if(turret) {
                        var hidden:Boolean=id=="hturret" || id=="hturret2" || int(copy.@hidden)>0;
                        weapon.rot=hidden ? Math.PI/2 : weapon.forceRot*Math.PI/180;
                    } else weapon.rot=unit.storona<0 ? Math.PI : 0;
                }
                // Bitmap units only acquire pixels when their first frame is blitted.
                // No locomotion, attacks, physics ticks or game loop are executed.
                var previousActive:Boolean=loc.active;
                loc.active=false;
                try { unit.animate(); }
                finally { loc.active=previousActive; }
                unit.setVisPos();
                if(!unit.vis) throw new Error("没有可绘制模型");
                var visuals:Array=[{vis:unit.vis,layer:int(unit.sloy)}];
                if(unit.cTransform) unit.vis.transform.colorTransform=unit.cTransform;
                // Turret barrels are already part of the native body MovieClip.
                if(unit.childObjs) for each(var child:Object in unit.childObjs) {
                    if(!child || !child.vis) continue;
                    if(child==weapon && turret) continue;
                    // Native animation hides stowed grenade/missile effects. Position
                    // every visible attachment; uninitialized ones otherwise sit at 0,0.
                    unit.setWeaponPos(child.tip);
                    child.X=unit.weaponX; child.Y=unit.weaponY;
                    if(child!=weapon) child.rot=unit.storona<0 ? Math.PI : 0;
                    child.animate();
                    if(!child.vis.visible || child.vis.alpha<=0) continue;
                    if(unit.cTransform) child.vis.transform.colorTransform=unit.cTransform;
                    visuals.push({vis:child.vis,layer:int(child.sloy)});
                }
                if(id=="thunderhead") thunderTurrets(unit,visuals);
                for each(var part:Object in visuals) freeze(part.vis);
                items.push({unit:unit,visuals:visuals,source:sourceId,id:id,example:random,
                    x:unit.X,y:unit.Y,facing:unit.storona,variant:cid});
                if(random) exampleCount++; else fixedCount++;
            } catch(error:Error) { warnings.push(sourceId+" → "+id+"（"+phase+"）："+error.message); }
        }

        private function prepareNPC(copy:XML,id:String):void {
            var Data:Class=domain.getDefinition("fe.GameData") as Class;
            var NPC:Class=domain.getDefinition("fe.serv.NPC") as Class;
            var npcId:String=String(copy.@npc);
            var defs:XMLList=Data.d.npc.(@id==npcId);
            var appearance:XML=<npc id="__editor_static_npc__"/>;
            appearance.@vis=id=="doctor" ? "Doctor" : "Vendor";
            // Copy appearance only. No vendor stock, quests or NPC.init special cases.
            if(defs.length()) for each(var key:String in ["vis","noturn","ico","name","replic","silent","weap","weap2","sloy","dammult"])
                if(defs[0].@[key].length()) appearance.@[key]=defs[0].@[key];
            world.game.npcs["__editor_static_npc__"]=new NPC(appearance);
            copy.@npc="__editor_static_npc__";
        }

        private function thunderTurrets(head:Object,visuals:Array):void {
            // Native UnitThunderHead.putLoc mount table, in unscaled sprite pixels.
            var mounts:Array=[[1,-850,-340,0],[1,-770,-340,0],[1,-690,-340,0],
                [2,-610,-340,0,1],[2,-530,-340,0],[3,370,-336,0],[3,420,-336,0],
                [3,470,-336,0],[3,520,-336,0],[4,750,-173,0],[4,820,-173,0],
                [4,890,-173,0,1],[5,585,-17,0],[5,-585,-17,0,1],
                [6,710,-17,0],[6,770,-17,0,1],[1,420,402,2],[1,500,402,2],
                [2,580,402,2],[2,660,402,2],[2,740,402,2],[3,-110,304,2,1],
                [3,-60,304,2],[4,-10,304,2],[4,40,304,2],[5,90,304,2],
                [5,-470,470,2],[6,-420,470,2],[6,-370,470,2]];
            for each(var mount:Array in mounts) {
                var turret:Object=Unit["create"]("ttur",loc.locDifLevel,null,null,String(mount[0]));
                turret.loc=loc;
                turret.setPos(head.X+mount[1]*3,head.Y+mount[2]*3);
                turret.setVisPos();
                turret.vis.osn.korp.rotation=mount[3]*90;
                if(mount[4]) turret.mega();
                var gun:Object=turret.currentWeapon;
                gun.rot=mount[3]==2 ? Math.PI/2 : -Math.PI/2;
                gun.X=turret.X; gun.Y=turret.Y-turret.scY/2;
                gun.animate();
                visuals.push({vis:turret.vis,layer:int(turret.sloy)});
                if(gun.vis) visuals.push({vis:gun.vis,layer:int(gun.sloy)});
            }
        }

        public function get simulationUnits():int { return loc.units.length; }

        public function attach():void {
            for each(var item:Object in items) for each(var part:Object in item.visuals) {
                var layer:int=Math.max(0,Math.min(graph.visObjs.length-1,part.layer));
                graph.visObjs[layer].addChild(part.vis);
            }
        }
        private function freeze(display:DisplayObject):void {
            if(display is MovieClip) MovieClip(display).stop();
            if(display is DisplayObjectContainer) {
                var container:DisplayObjectContainer=DisplayObjectContainer(display);
                for(var i:int=0;i<container.numChildren;i++) freeze(container.getChildAt(i));
            }
        }
        public function summary():Array {
            var result:Array=[];
            for each(var item:Object in items) result.push({source:item.source,id:item.id,example:item.example,
                x:item.x,y:item.y,facing:item.facing,variant:item.variant});
            return result;
        }
    }
}
