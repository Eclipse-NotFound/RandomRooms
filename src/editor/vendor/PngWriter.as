package {
    import flash.display.BitmapData;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    // Legacy Editor.swf exposes the older AIR API in its application domain.
    // Encode RGB PNG with ByteArray/zlib so PNGEncoderOptions is not required.
    public class PngWriter {
        private static var crcTable:Array=makeTable();
        private static function makeTable():Array {
            var table:Array=[];
            for(var n:uint=0;n<256;n++) {
                var c:uint=n;
                for(var k:int=0;k<8;k++) c=(c&1)?(0xEDB88320^(c>>>1)):(c>>>1);
                table[n]=c;
            }
            return table;
        }
        private static function chunk(out:ByteArray,type:String,payload:ByteArray):void {
            var bytes:ByteArray=new ByteArray();
            bytes.writeUTFBytes(type);
            if(payload) bytes.writeBytes(payload);
            out.writeUnsignedInt(payload?payload.length:0);
            out.writeBytes(bytes);
            var crc:uint=0xFFFFFFFF;
            for(var i:uint=0;i<bytes.length;i++) crc=uint(crcTable[(crc^bytes[i])&255])^(crc>>>8);
            out.writeUnsignedInt(crc^0xFFFFFFFF);
        }
        public static function encode(image:BitmapData):ByteArray {
            var out:ByteArray=new ByteArray(); out.endian=Endian.BIG_ENDIAN;
            out.writeUnsignedInt(0x89504E47); out.writeUnsignedInt(0x0D0A1A0A);
            var header:ByteArray=new ByteArray();
            header.writeUnsignedInt(image.width); header.writeUnsignedInt(image.height);
            header.writeByte(8); header.writeByte(2); // 8-bit RGB, opaque preview.
            header.writeByte(0); header.writeByte(0); header.writeByte(0);
            chunk(out,"IHDR",header);
            var pixels:ByteArray=image.getPixels(image.rect); pixels.position=0;
            var rows:ByteArray=new ByteArray();
            for(var y:int=0;y<image.height;y++) {
                rows.writeByte(0); // PNG filter None.
                for(var x:int=0;x<image.width;x++) {
                    var color:uint=pixels.readUnsignedInt();
                    rows.writeByte(color>>16); rows.writeByte(color>>8); rows.writeByte(color);
                }
            }
            rows.compress(); chunk(out,"IDAT",rows); chunk(out,"IEND",null);
            out.position=0; return out;
        }
    }
}
