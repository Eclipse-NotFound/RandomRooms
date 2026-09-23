package rr
{
   /** Space demands are chosen before coordinates. Forms denote a use family,
    * not a list of fixed cuts. Used by the opt-in partition prototype. */
   public class RRSpaceRules
   {
      private var rnd:Function;
      private function pick(a:Array):String { return String(a[int(rnd()*a.length)]); }
      private function between(a:int,b:int):int { return a+int(rnd()*(b-a+1)); }
      public function RRSpaceRules(random:Function) { rnd=random; }

      private function demand(role:String,wide:Boolean=false):Object
      {
         var p:Object={role:role,minW:7,minH:5,maxW:19,maxH:10,weight:0.7+rnd()*0.8};
         if(role=="living") { p.minW=8; p.maxW=17; p.maxH=9; }
         if(role=="workshop" || role=="warehouse" || role=="hall")
         { p.minW=wide?17:10; p.minH=wide?9:6; p.maxW=wide?35:25; p.maxH=wide?18:12; p.weight=wide?3.4+rnd()*1.7:1.3+rnd(); }
         if(role=="corridor") { p.minW=10; p.minH=4; p.maxW=40; p.maxH=7; p.weight=1.1; }
         if(role=="service") { p.maxW=24; p.maxH=11; }
         if(role=="roof") { p.minW=16; p.minH=5; p.maxW=46; p.maxH=12; p.weight=2.4; p.edge="top"; }
         if(role=="street") { p.minW=10; p.minH=14; p.maxW=23; p.maxH=23; p.weight=3.5; }
         return p;
      }
      public function create(theme:String,form:String):Object
      {
         var rooms:Array=[],bag:Array,count:int,main:String,wide:Boolean=rnd()<0.55;
         var vertical:Number=0.5,extra:Number=0.2+rnd()*0.5;
         if(theme=="plant")
         {
            count=between(8,12); vertical=0.45+rnd()*0.25;
            main=form=="storage_hall"?"warehouse":(form=="service_wing"?"service":"workshop");
            rooms.push(demand(main,wide && main!="service"));
            bag=main=="warehouse"?["store","store","warehouse","control","service"]:
               (main=="service"?["service","service","control","control","office","store"]:
               ["workshop","workshop","control","store","service"]);
            if(rnd()<0.65) rooms.push(demand("control"));
         }
         else if(theme=="stable")
         {
            count=between(10,14); vertical=0.35+rnd()*0.25;
            main=form=="atrium_ring"?"hall":(form=="quarters"?"living":"service");
            rooms.push(demand(main,wide && main=="hall"));
            bag=main=="living"?["living","living","living","office","kitchen","medical"]:
               (main=="hall"?["living","office","office","service","store","medical"]:
               ["service","service","control","control","medical","store"]);
            if(rnd()<0.85) rooms.push(demand("corridor"));
         }
         else if(theme=="sewer")
         {
            count=between(7,10); vertical=0.3+rnd()*0.3; main=form=="dry_tunnels"?"service":"canal";
            if(main=="canal")
            {
               rooms.push({role:"canal",minW:form=="cistern"?26:23,minH:form=="cistern"?12:10,
                  maxW:46,maxH:21,weight:form=="cistern"?5.4:3.6});
               count=between(6,9);
            }
            else rooms.push(demand("service"));
            bag=form=="pump_chain"?["control","control","service","service","store"]:
               ["service","service","service","control","store"];
            extra=0.2+rnd()*0.35;
         }
         else
         {
            count=between(9,13); vertical=0.4+rnd()*0.3;
            main=form=="offices"?"office":(form=="commercial"?"store":(form=="ruined"?"hall":
               (form=="rooftops"?"roof":(form=="street_links"?"street":"living"))));
            rooms.push(demand(main,main=="hall"));
            bag=main=="office"?["office","office","office","store","service"]:
               (main=="store"?["store","store","office","kitchen","service"]:
               (main=="roof" || main=="street"?["service","store","service","office"]:
               ["living","living","kitchen","office","store"]));
            if(main=="roof" || main=="street") count=between(6,9);
         }
         while(rooms.length<count) rooms.push(demand(pick(bag)));
         for(var i:int=0;i<rooms.length;i++) rooms[i].uid=i;
         return {theme:theme,form:form,main:main,rooms:rooms,vertical:vertical,extra:extra,
            variant:wide?"mixed-scale":"compact-cluster"};
      }
      /** Larger values mean a useful architectural relationship, not a door
       * that must appear in every room. Geometry feasibility remains mandatory. */
      public static function affinity(theme:String,a:String,b:String):Number
      {
         if(a=="corridor" || b=="corridor") return 3;
         if(a=="street" || b=="street" || a=="roof" || b=="roof") return 1.1;
         if(theme=="plant")
         {
            if((a=="control" && b=="workshop") || (b=="control" && a=="workshop")) return 3.2;
            if((a=="store" && b=="warehouse") || (b=="store" && a=="warehouse")) return 3.1;
            if(a=="service" || b=="service") return 2;
         }
         if(theme=="stable")
         {
            if(a=="hall" || b=="hall") return 2.8;
            if((a=="control" && b=="service") || (b=="control" && a=="service")) return 3;
            if(a=="living" && b=="living") return 0.7;
         }
         if(theme=="sewer" && (a=="service" || b=="service")) return 2.6;
         if(a==b) return 1.5;
         return 1;
      }
   }
}
