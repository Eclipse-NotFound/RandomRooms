package fe.loc {
    // The native method is package-internal. Compiling this adapter in its package
    // supplies the same namespace, without modifying the native game's bytecode.
    public class EditorPreviewProfile {
        public static function apply(land:*,loc:*,difficulty:Number=-1):void {
            land.landDifLevel=difficulty>=0 ? difficulty : Math.max(land.act.dif,land.act.rnd || land.act.autoLevel ? 1 : 0);
            loc.biom=land.act.biom;
            loc.unXp=land.act.xp;
            land.setLocDif(loc,0);
        }
    }
}
