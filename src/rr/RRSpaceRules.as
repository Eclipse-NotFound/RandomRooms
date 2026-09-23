package rr
{
   /** Space demands are chosen before coordinates. Forms denote a use family,
    * not a list of fixed cuts. Used by the opt-in partition prototype. */
   public class RRSpaceRules
   {
      private var rnd:Function;
      private var sceneId:String;
      private function pick(a:Array):String { return String(a[int(rnd()*a.length)]); }
      private function between(a:int,b:int):int { return a+int(rnd()*(b-a+1)); }
      public function RRSpaceRules(random:Function) { rnd=random; }

      private function demand(role:String,wide:Boolean=false):Object
      {
         var p:Object={role:role,minW:5,minH:3,maxW:25,maxH:sceneId=="mane"?7:(sceneId=="plant"?6:5),weight:0.5+rnd()*0.8};
         if(role=="living") { p.minW=7; p.minH=4; p.maxW=26; }
         if(role=="kitchen" || role=="medical") p.minH=4;
         if(role=="workshop" || role=="warehouse" || role=="hall")
         { p.minW=wide?22:8; p.minH=wide?10:4; p.maxW=wide?46:32; p.maxH=wide?21:8; p.weight=wide?6+rnd()*3:1.1+rnd(); }
         if(role=="corridor") { p.minW=10; p.minH=3; p.maxW=46; p.maxH=5; p.weight=1.1; }
         if(role=="service") { p.maxW=30; }
         if(role=="roof") { p.minW=16; p.minH=4; p.maxW=46; p.maxH=9; p.weight=2.4; p.edge="top"; }
         if(role=="street") { p.minW=10; p.minH=14; p.maxW=23; p.maxH=23; p.weight=3.5; }
         return p;
      }
      public function create(theme:String,form:String):Object
      {
         sceneId=theme;
         var rooms:Array=[],bag:Array,count:int,main:String;
         var density:String=pick(["sparse","standard","standard","standard","dense"]);
         var wide:Boolean=density=="sparse" || (density=="standard" && rnd()<0.45);
         var levels:Number=theme=="stable"?0.58:(theme=="mane"?0.46:(theme=="plant"?0.35:0.24));
         var vertical:Number=0.5,extra:Number=0.2+rnd()*0.5;
         if(theme=="plant")
         {
            vertical=0.40+rnd()*0.20;
            main=form=="storage_hall"?"warehouse":(form=="service_wing"?"service":"workshop");
            count=density=="dense"?between(10,12):(density=="sparse" && main!="service"?between(4,6):between(6,9));
            rooms.push(demand(main,wide && main!="service"));
            bag=main=="warehouse"?["store","store","warehouse","control","service"]:
               (main=="service"?["service","service","control","control","office","store"]:
               ["workshop","workshop","control","store","service"]);
            if(rnd()<0.65) rooms.push(demand("control"));
         }
         else if(theme=="stable")
         {
            vertical=0.30+rnd()*0.20;
            main=form=="atrium_ring"?"hall":(form=="quarters"?"living":"service");
            count=density=="dense"?between(10,13):(density=="sparse" && main=="hall"?between(4,6):between(7,10));
            rooms.push(demand(main,wide && main=="hall"));
            bag=main=="living"?["living","living","living","office","kitchen","medical"]:
               (main=="hall"?["living","office","office","service","store","medical"]:
               ["service","service","control","control","medical","store"]);
            if(rnd()<0.85) rooms.push(demand("corridor"));
         }
         else if(theme=="sewer")
         {
            count=density=="dense"?between(9,11):between(5,8); vertical=0.3+rnd()*0.2; main=form=="dry_tunnels"?"service":"canal";
            if(main=="canal")
            {
               rooms.push({role:"canal",minW:form=="cistern"?26:23,minH:form=="cistern"?12:10,
                  maxW:46,maxH:21,weight:form=="cistern"?7:5});
               count=density=="dense"?between(8,10):(density=="sparse"?between(3,5):between(5,7));
            }
            else rooms.push(demand("service"));
            bag=form=="pump_chain"?["control","control","service","service","store"]:
               ["service","service","service","control","store"];
            extra=0.2+rnd()*0.35;
         }
         else
         {
            vertical=0.35+rnd()*0.2;
            main=form=="offices"?"office":(form=="commercial"?"store":(form=="ruined"?"hall":
               (form=="rooftops"?"roof":(form=="street_links"?"street":"living"))));
            rooms.push(demand(main,main=="hall"));
            count=density=="dense"?between(9,12):(density=="sparse" && main=="hall"?between(3,5):between(5,8));
            bag=main=="office"?["office","office","office","store","service"]:
               (main=="store"?["store","store","office","kitchen","service"]:
               (main=="roof" || main=="street"?["service","store","service","office"]:
               ["living","living","kitchen","office","store"]));
            if(main=="roof" || main=="street") count=density=="dense"?between(8,10):between(4,7);
         }
         while(rooms.length<count) rooms.push(demand(pick(bag)));
         // Structural mass is planned alongside usable cells. Its area is not
         // forced into extra low rooms; the terrain remains solid when carved.
         var massChance:Number=theme=="mane"?0.35:(theme=="plant"?0.65:(theme=="stable"?0.90:1));
         var masses:int=rnd()<massChance?between(1,theme=="sewer"?3:(theme=="stable"?2:1)):0;
         for(i=0;i<masses;i++) rooms.push({role:"mass",minW:5,minH:3,
            maxW:theme=="mane"?18:(theme=="plant"?28:38),maxH:theme=="mane"?6:(theme=="sewer"?17:11),
            weight:theme=="mane"?0.8+rnd():1.6+rnd()*1.8});
         for(var i:int=0;i<rooms.length;i++) rooms[i].uid=i;
         return {theme:theme,form:form,main:main,rooms:rooms,vertical:vertical,extra:extra,levels:levels,density:density,
            requested:count,variant:wide?"large-and-small":"compact-cluster"};
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
