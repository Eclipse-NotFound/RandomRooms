package rr
{
   import flash.utils.getDefinitionByName;
   /** Scene identity owns architecture, material families and native ambience.
    * Roles refine a scene; they never select an unrelated scene's fallback. */
   public class RRScene
   {
      public static const IDS:Array=["plant","stable","sewer","mane"];
      public static const NAMES:Array=["工厂","废弃避难厩","下水道","城市废墟"];
      public static function valid(id:String):Boolean { return IDS.indexOf(id)>=0; }
      public static function name(id:String):String
      { return valid(id)?String(NAMES[IDS.indexOf(id)]):"随机选择"; }

      public static function profile(id:String):Object
      {
         if (id=="plant") return {wall:"C",trim:"C",backgrounds:["C","D","J"],
            forms:["production","storage_hall","service_wing"],min:4,max:7,bias:0.65,
            light:"light4",hatches:["hatch1","hatch1","hatch2"],windows:["window1"],windowMax:1};
         if (id=="stable") return {wall:"J",trim:"K",backgrounds:["N","R","Q"],
            forms:["quarters","atrium_ring","service_cluster"],min:6,max:9,bias:0.46,
            light:"stlight3",hatches:["hatch2"],windows:["window2"],windowMax:3};
         if (id=="sewer") return {wall:"L",trim:"M",backgrounds:["E","C","T"],
            forms:["canal_gallery","cistern","pump_chain"],min:3,max:6,bias:0.22,
            light:"light1",hatches:["hatch1","hatch1","hatch2"],windows:["window1"],windowMax:1};
         if (id=="mane") return {wall:"N",trim:"N",backgrounds:["C","D","J"],
            forms:["courtyard","broken_facade","roof_passage"],min:4,max:8,bias:0.55,
            light:"light3",hatches:["hatch1","hatch2"],windows:["window1","window1","window2"],windowMax:5};
         throw new Error("Unknown scene: "+id);
      }
      public static function options(id:String):XML
      {
         if (id=="plant") return <options backwall="tBackWall" music="music_plant_1"/>;
         if (id=="stable") return <options backwall="tStConcrete" music="music_stable_1"/>;
         if (id=="sewer") return <options backwall="tMossy" music="music_sewer_1" color="green" wtip="1" wrad="3"/>;
         if (id=="mane") return <options backwall="sky" music="music_mane_1" vis="2" darkness="-20"/>;
         throw new Error("Unknown scene options: "+id);
      }
      public static function configureLand(world:*,act:*,id:String):void
      {
         if (!valid(id)) throw new Error("Unknown adventure scene: "+id);
         var original:*=world["game"]["lands"]["random_"+id];
         if (original==null) throw new Error("Native scene metadata missing: "+id);
         // Copy environmental values, not native conf/size, flood levels,
         // quests, access, difficulty or progression. Native sewer full-row
         // flooding would invalidate the dry-route contract.
         for each (var key:String in ["biom","backwall","sndMusic","postMusic","fon","border","color",
            "visMult","opacWater","darkness","rad","wrad","wdam","wtipdam","tipWater"])
            act[key]=original[key];
         // Own map names are absent from the native translation catalog.
         // Add only our two IDs so travel/status text reflects the chosen scene.
         var res:*=getDefinitionByName("fe.Res");
         var text:XML=res["d"] as XML;
         var ownId:String=String(act["id"]);
         if (text!=null && (ownId=="random_rooms" || ownId=="rr_showroom"))
         {
            var entries:XMLList=text.map.(@id==ownId);
            var title:String=name(id)+(ownId=="rr_showroom"?" · 展示馆":" · 随机探索");
            if (!entries.length()) text.appendChild(<map id={ownId}><n>{title}</n></map>);
            else entries[0].n=title;
         }
      }
      public static function background(id:String,role:String,random:Function):String
      {
         var a:Array;
         if (role=="street" || role=="roof") return "";
         if (id=="stable") a=role=="control"?["O","Q"]:(role=="living"?["N","P"]:["R","Q"]);
         else if (id=="plant") a=role=="office" || role=="living"?["B","J"]:["C","D","F"];
         else if (id=="sewer") a=role=="control"?["C","T"]:["E","S","T"];
         else if (id=="mane") a=role=="living"?["H","J"]:["C","D","J"];
         else throw new Error("Unknown background scene: "+id);
         return String(a[int(random()*a.length)]);
      }
      public static function door(id:String,a:String,b:String,random:Function):String
      {
         if (a=="street" || b=="street" || a=="roof" || b=="roof") return "door1";
         if (id=="stable") return "stdoor";
         if (id=="sewer") return random()<0.78?"door1":"door1b";
         if (id=="plant") return a=="control" || b=="control"?"door2":(random()<0.8?"door1":"door1b");
         if (id=="mane") return random()<0.8?"door1":"door1a";
         throw new Error("Unknown door scene: "+id);
      }
   }
}
