--[[
 原脚本信息
 檔案名稱：kage_autoRuby.lua
 腳本製作：影kage
 自動上小字特效(非卡拉OK)
 
 *請將文件放到Aegisub\automation\autoload資料夾內方可使用
 *每次調完參數請到[自動化腳本管理]去[重新整理]
 *套用的字幕樣式

 Copyright (c) 2013-2014,Kage Maboroshi/TUcaptions, All rights reserved. 
 
 this script is a modifer of kage ruby sciprt
 
]]

--以下資料請不要亂動--

require "karaskel"

script_name = "Generate Ruby(Non Karaoke)"
script_description = "Generate ruby based on the split chars"
script_author = "Kage Maboroshi(影kage)"
script_modifer_author = "KiNen&domo";
script_version = 1.0


--參數設定--
rubypadding = 0 --小字間距
rubyscale = 0.5 --小字縮放比例

--分隔符设定
dialog_config=
{
{class="label",x=2,y=0,width=1,height=1,label="StartCharacter:"},
{class="edit",name="StartCharacter",x=3,y=0,width=1,height=1,value="##"},
{class="label",x=2,y=1,width=1,height=1,label="SplitCharacter:"},
{class="edit",name="SplitCharacter",x=3,y=1,width=1,height=1,value="|"},
{class="label",x=2,y=2,width=1,height=1,label="EndCharacter:"},
{class="edit",name="EndCharacter",x=3,y=2,width=1,height=1,value="##"},
}

function parse_templates(meta, styles, subs)
	local i = 1
	while i <= #subs do
		aegisub.progress.set((i-1) / #subs * 100)
		local l = subs[i]
		i = i + 1
		if l.class == "dialogue" and l.effect == "furi-fx" then
			-- this is a previously generated effect line, remove it
			i = i - 1
			subs.delete(i)
		end
	end
	aegisub.progress.set(100)
end

meta = nil;
styles = nil;

function Ruby(subs, sel)
	parse_templates(meta, styles, subs)
	cfg_res,config =_G.aegisub.dialog.display(dialog_config)
	char_s = config.StartCharacter
	char_m= config.SplitCharacter
	char_e= config.EndCharacter
	meta, styles = karaskel.collect_head(subs);
	for z, i in ipairs(sel) do
		local l = subs[i]
		processline(subs,l,i);
		local l2 = subs[i];
		      l2.comment = true;
			  subs[i] = l2;
	end
	aegisub.set_undo_point(script_name) 
end

function processline(subs,line,li)
    line.comment = false;
	local originline = table.copy(line);
	
	local ktag="{\\k0}";
	local stylefs = styles[ line.style ].fontsize;
	local rubbyfs = stylefs * rubyscale;
	if string.find(line.text,char_s.."(.-)"..char_m.."(.-)"..char_e) ~= nil then
		if (char_s == "("  and char_m == "," and char_e == ")") then
			line.text = string.gsub(line.text,"%((.-),(.-)%)",ktag.."%1".."|".."%2"..ktag);
		elseif (char_s == "" and char_m == "(" and char_e == ")") then
			line.text = string.gsub(line.text,"(^[ぁ-ゖ]+)%(([ぁ-ゖ]+)%)^[ぁ-ゖ]+",ktag.."%1".."|".."%2"..ktag);
			aegisub.debug.out(line.text)
		else
			line.text = string.gsub(line.text,char_s.."(.-)"..char_m.."(.-)"..char_e,ktag.."%1".."|".."%2"..ktag);
		end
	
    local vl = table.copy(line);
	karaskel.preproc_line(subs, meta, styles, vl);
	
	if (char_s == "("  and char_m == "," and char_e == ")") then
		originline.text = string.gsub(originline.text,"%((.-),(.-)%)","%1");
	elseif (char_s == "" and char_m == "(" and char_e == ")") then
		originline.text = string.gsub(originline.text,"(^[ぁ-ゖ]+)%(([ぁ-ゖ]+)%)","%1");
	else
		originline.text = string.gsub(originline.text,char_s.."(.-)"..char_m.."(.-)"..char_e,"%1");
	end
	
	originline.text = string.format("{\\pos(%d,%d)}",vl.x,vl.y)..originline.text;
	originline.effect = "furi-fx"
	subs.append(originline);

	for i = 1, vl.furi.n do
		local fl = table.copy(line)
		local rlx = vl.left + vl.kara[vl.furi[i].i].center;
		local rly = vl.top - rubbyfs/2 - rubypadding;
		fl.text = string.format("{\\an5\\fs%d\\pos(%d,%d)}%s",rubbyfs,rlx,rly,vl.furi[i].text);
		fl.effect = "furi-fx"
		subs.append(fl);
	end
	else
	end
end


aegisub.register_macro(script_name, script_description, Ruby)