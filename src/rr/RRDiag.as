package rr
{
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   
   /**
    * RRDiag —— RandomRooms 诊断日志。
    * 遵循共享知识 log-forensics-workflow：版本标记行、计数上限、grep -a 可读。
    * 日志写入 applicationStorageDirectory/RandomRooms_diag.log，并镜像 trace()。
    */
   public class RRDiag
   {
      public static const TAG:String = "[RR:v9.0]";
      
      private static const MAX_LINES:int = 3000;
      private static const FILE_NAME:String = "RandomRooms_diag.log";
      
      private static var _inst:RRDiag;
      
      /** 全局单例：避免文档类多次实例化时重复打开日志流 */
      public static function get inst():RRDiag
      {
         if (_inst == null)
         {
            _inst = new RRDiag();
         }
         return _inst;
      }
      
      private var _fsOK:Boolean = false;
      private var _stream:FileStream;
      private var _file:File;
      private var _lines:int = 0;
      private var _capped:Boolean = false;
      
      public function RRDiag()
      {
         try
         {
            _file = File.applicationStorageDirectory.resolvePath(FILE_NAME);
            _stream = new FileStream();
            _stream.open(_file, FileMode.APPEND);
            _fsOK = true;
         }
         catch (e:*)
         {
            _fsOK = false;
         }
         log("RRDiag init, fileStream=" + (_fsOK ? _file.nativePath : "N/A"));
      }
      
      public function log(msg:String):void
      {
         var line:String = TAG + " " + msg;
         trace(line);
         if (_fsOK && !_capped)
         {
            try
            {
               if (_lines >= MAX_LINES)
               {
                  _stream.writeUTFBytes("\n" + TAG + " LOG CAPPED AT " + MAX_LINES + " LINES\n");
                  _capped = true;
               }
               else
               {
                  _stream.writeUTFBytes(line + "\n");
                  _lines++;
               }
            }
            catch (e:*)
            {
               _fsOK = false;
            }
         }
      }
      
      public function close():void
      {
         if (_fsOK && _stream)
         {
            try { _stream.close(); } catch (e:*) {}
            _fsOK = false;
         }
      }
   }
}
