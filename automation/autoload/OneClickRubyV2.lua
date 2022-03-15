script_name = "One Click Ruby"
script_description = "Get the formatted lyrics by Yahoo's API and ruby them"
script_author = "domo"
ruby_part_from = "Kage Maboroshi&KiNen"
script_version = "2.0"

require "karaskel"
local request = require("luajit-request")
local ffi = require"ffi"
local utf8 = require"utf8"
local json = require"json"
-- local Y = require"Yutils"
-- local tts = Y.table.tostring
meta = nil;
styles = nil;
--參數設定--
rubypadding = 0 --小字間距
rubyscale = 0.5 --小字縮放比例

--分隔符设定
char_s = "##"
char_m = "|<"
char_e = "##"

local function deleteEmpty(tbl)
	for i=#tbl,1,-1 do
		if tbl[i] == "" then
		table.remove(tbl, i)
		end
	end
	return tbl
end

function Split(szFullString, szSeparator)
	local nFindStartIndex = 1
	local nSplitIndex = 1
	local nSplitArray = {}   
	while true do
		local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)      
		if not nFindLastIndex then
			nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))
			break      
		end
		nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)
		nFindStartIndex = nFindLastIndex + string.len(szSeparator)
		nSplitIndex = nSplitIndex + 1
	end
return nSplitArray
end

local function send2YahooV2(sentence,appid,grade)
	local url = "https://jlp.yahooapis.jp/FuriganaService/V2/furigana"
	params = {["q"] = sentence,
			  ["grade"] = grade}
	data = {["id"] = "1234-1",
			["jsonrpc"] = "2.0",
			["method"] = "jlp.furiganaservice.furigana",
			["params"] = params}
	local result, err, message = request.send(url,{
		method = "POST",
		headers = {['content-type'] = "application/x-www-form-urlencoded",
				   ["User-Agent"] = "Yahoo AppID: " .. appid},
		data = json.encode(data)}
		)
	if (not result) then aegisub.debug.out(err, message) end
	return result.body
end

local function KaraText(newText,lineKara)
	rubyTbl = deleteEmpty(Split(newText,char_s))
	newRubyTbl = {}
	for i=1,#rubyTbl do
		if string.find(rubyTbl[i],char_m) then
			newRubyTbl[#newRubyTbl+1] = rubyTbl[i]
		else 
			for j=1,utf8.len(rubyTbl[i]) do
				newRubyTbl[#newRubyTbl+1] = utf8.sub(rubyTbl[i],j,j)
			end
		end
	end
	-- aegisub.debug.out(tts(newRubyTbl).."\n")
	sylNum = #lineKara
	for i=#newRubyTbl,2,-1 do
		realWord = string.match(newRubyTbl[i],"([^|<]+)[<|]?")
		if utf8.len(realWord)<utf8.len(lineKara[sylNum].sylText) then
			newRubyTbl[i-1] = newRubyTbl[i-1]..newRubyTbl[i]
			table.remove(newRubyTbl,i)
			-- aegisub.debug.out(realWord.."|"..lineKara[sylNum].sylText.."\n")
		else
			sylNum = sylNum - 1
		end
	end
	-- aegisub.debug.out(tts(newRubyTbl)..'\n')
	tmpSylText = ""
	tmpSylKDur = 0
	i = 1
	newKaraText = ""
	while i<=#lineKara do
		tmpSylText = tmpSylText..lineKara[i].sylText
		tmpSylKDur = tmpSylKDur + lineKara[i].kDur
		table.remove(lineKara,1)
		realWord = string.match(newRubyTbl[i],"([^|<]+)[<|]?")
		-- aegisub.debug.out('\n'..tostring(tmpSylKDur)..tmpSylText.."    "..realWord)
		if tmpSylText == realWord then
			newKaraText = newKaraText..string.format("{\\k%d}%s",tmpSylKDur,newRubyTbl[i])
			table.remove(newRubyTbl,i)
			tmpSylText = ""
			tmpSylKDur = 0
		end
		-- aegisub.debug.out('\n'..newKaraText)
	end
	return newKaraText
end

local function parse_templates(meta, styles, subs)
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

local function processline(subs,line,li)
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
	subs.append(originline)
	end
end

local function Ruby(subs, sel)
	meta, styles = karaskel.collect_head(subs);
	for i=1,#sel do
		processline(subs,sel[i],i);
	end
	aegisub.set_undo_point(script_name) 
end


local function json2LineText(jsonStr,lineNum)
	lineText = ""
	-- json error handle
	if json.decode(jsonStr).error then return "" end
	wordTbl = json.decode(jsonStr).result.word
	if wordTbl.furigana and wordTbl.furigana~=wordTbl.surface and string.byte(wordTbl.surface)~=227 then
		if wordTbl.subword then
			subTbl = wordTbl.subword
			for i=1,#subTbl do
				if subTbl[i].surface~=subTbl[i].furigana then
					lineText = lineText..char_s..subTbl[i].surface..char_m..subTbl[i].furigana..char_e
				else
					lineText = lineText..subTbl[i].surface
				end
			end
		else
			lineText = lineText..char_s..wordTbl.surface..char_m..wordTbl.furigana..char_e
		end
	else
		for i=1,#wordTbl do
			if wordTbl[i].furigana and wordTbl[i].furigana~=wordTbl[i].surface and string.byte(wordTbl[i].surface)~=227 then
				if wordTbl[i].subword then 
					subTbl = wordTbl[i].subword
					for i=1,#subTbl do
						if subTbl[i].surface~=subTbl[i].furigana then
							lineText = lineText..char_s..subTbl[i].surface..char_m..subTbl[i].furigana..char_e
						else
							lineText = lineText..subTbl[i].surface
						end
					end
				else
					lineText = lineText..char_s..wordTbl[i].surface..char_m..wordTbl[i].furigana..char_e
				end
			else
				lineText = lineText..wordTbl[i].surface
			end
		end
	end
	return lineText
end


function oneClickRuby(subtitles, selected_lines)
	local grade = "1" --1~6 correspond to Japan primary school student grade, 7 for middle school and 8 for normal people.
 	local appid = "dj00aiZpPVZKRHFzZHY4Y3RtaSZzPWNvbnN1bWVyc2VjcmV0Jng9Zjg-" --suggest to change to your own appid.
	for i=1,#subtitles do
		if subtitles[i].class=="dialogue" then
			dialogue_start = i - 1
			break
		end
	end
	newLineTbl = {}
	for i=1,#selected_lines do
		lineNum = tostring(selected_lines[i]-dialogue_start)
		l = subtitles[selected_lines[i]]
		orgText = l.text			
		l.comment = true
		subtitles[selected_lines[i]] = l
		text = orgText:gsub("{[^}]+}", "")
		if string.find(orgText,"{\\[kK]%d+}") then
			aegisub.debug.out("Process line "..lineNum.." as a karaoke line.\n")
			lineKara = {}
			for kDur,sylText in string.gmatch(orgText,"{\\[kK](%d+)}([^{]+)") do
				lineKara[#lineKara+1] = {sylText=sylText,kDur=kDur}
			end
			aegisub.progress.task("Requesting for line: "..lineNum)
			result = send2YahooV2(text,appid,grade)
			aegisub.progress.task("Parsing for line: "..lineNum)
			newText = json2LineText(result,lineNum)
			-- newText = xml2LineText(result,lineNum)
			if type(newText)=="string" and newText~="" then
				newText = KaraText(newText,lineKara)
			else
				newText = orgText
			end
			l.effect = "karaoke"
		elseif string.find(text,char_m) then
			newText = text
			l.effect = "ruby"
		else
			aegisub.progress.task("Requesting for line: "..lineNum)
			result = send2YahooV2(text,appid,grade)
			aegisub.progress.task("Parsing for line: "..lineNum)
			newText = json2LineText(result,lineNum)
			l.effect = "ruby"
		end
		-- newText = xml2KaraLineText(result,line_table or key_value,lineNum)
		aegisub.progress.task("Writing for line: "..lineNum)
		if newText ~= "" then
			l.text = newText
		else
			l.text = orgText
		end
		l.comment = false
		newLineTbl[#newLineTbl+1] = l
		aegisub.progress.set(i/#selected_lines*100)
	end
	-- uncomment this if you have the demand to use the raw format
	-- subtitles.append(table.unpack(newLineTbl))
	Ruby(subtitles, newLineTbl)
	aegisub.debug.out("Done.")
end

aegisub.register_macro("文本工具/"..script_name, script_description, oneClickRuby)
