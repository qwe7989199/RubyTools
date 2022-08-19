# RubyTools
在 Aegisub 中为日文字幕添加假名标注。   
已支持卡拉OK字幕。  
[英文说明(English Ver)](README.md)
## 用法  
- Clone 本仓库  
- 解压所有文件到 Aegisub 根目录。  
- 启动你的 Aegisub 并检查自动化菜单  
  - 在选择行上运行 "One Click Ruby" 即可。  
  
## 依赖(部分已包含于本仓库)    
 - luajit-request  
  https://github.com/LPGhatguy/luajit-request   
  **注意：** 你需要自行寻找64位版本的 **_libcurl.dll_** 来在对应版本的 Aegisub 中使用本工具。  
 - json (v2版)  
  https://github.com/rxi/json.lua
 - utf8.lua  
  https://github.com/Stepets/utf8.lua
