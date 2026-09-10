package
{
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;

   /** Test-only native fixture checks. Never loaded by the production mod. */
   public class FixtureProbe
   {
      public static var hatch:*;
      public static var openedByInput:Boolean;

      private static function require(ok:Boolean,message:String):void
      { if (!ok) throw new Error("FIXTURE " + message); }

      public static function begin(w:*,directory:File,caseId:String):void
      {
         hatch=null; openedByInput=false;
         var records:Array=[];
         for each (var xml:XML in w.loc.room.xml.obj)
         {
            var role:String=String(xml.@rrFixture);
            if (!role.length) continue;
            var obj:*=w.loc.firstObj;
            while (obj!=null && String(obj.code)!=String(xml.@code)) obj=obj.nobj;
            require(obj!=null,"missing runtime object "+xml.@code);
            var expected:int=role=="door" && String(xml.@id)=="stdoor"?3:2;
            require(obj.tiles.length==expected,"tile footprint "+obj.id+" count="+obj.tiles.length);
            var record:Object={id:obj.id,role:role,x:obj.X,y:obj.Y,width:obj.scX,height:obj.scY,tiles:obj.tiles.length};
            for each(var tile:* in obj.tiles) require(tile.phis>0 && tile.door===obj,"closed collision "+obj.id);
            if (role=="window")
            {
               require(obj.inter==null && obj.mat==5,"glass must use native non-interactive window "+obj.id);
               for each(tile in obj.tiles) require(Math.abs(tile.opac-0.2)<0.001,"glass transparency "+obj.id);
               // Direct native damage checks breakage, not weapon aiming.
               obj.damage(100000);
               for each(tile in obj.tiles) require(tile.phis==0 && tile.opac==0,"broken glass still blocks "+obj.id);
               record.breakClearsCollision=true;
            }
            else
            {
               require(obj.inter!=null && !obj.inter.open && obj.inter.lock==0 && obj.inter.mine==0,"route fixture must start closed/unlocked "+obj.id);
               var stairs:Array=[];
               for each(tile in obj.tiles) stairs.push(tile.stair);
               obj.inter.setAct("open",1);
               for each(tile in obj.tiles) require(tile.phis==0 && tile.opac==0,"open collision "+obj.id);
               obj.inter.setAct("open",0);
               require(!obj.inter.open,"close rejected at empty aperture "+obj.id);
               for (var i:int=0;i<obj.tiles.length;i++)
               {
                  tile=obj.tiles[i];
                  require(tile.phis>0 && tile.stair==stairs[i],"close collision/ladder "+obj.id);
               }
               record.nativeOpenClose=true;
               if (role=="hatch") hatch=obj;
            }
            records.push(record);
         }
         require(hatch!=null,"no hatch in case "+caseId);
         var stream:FileStream=new FileStream();
         stream.open(directory.resolvePath("captures/"+caseId+"-fixtures.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify({caseId:caseId,room:String(w.loc.room.id),records:records,passed:true,
            scope:"native open/close and direct glass damage; hatch approach/open/climb is separately driven through Ctr"}));
         stream.close();
      }
   }
}
