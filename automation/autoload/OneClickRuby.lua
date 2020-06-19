script_name = "One Click Ruby"
script_description = "Get the formatted lyrics by Yahoo's API and ruby them"
script_author = "domo"
ruby_part_from = "Kage Maboroshi&KiNen"
script_version = "1.0"

require "karaskel"
local request = require("luajit-request")
local ffi = require"ffi"
local utf8 = require"utf8"

meta = nil;
styles = nil;
--參數設定--
rubypadding = 0 --小字間距
rubyscale = 0.5 --小字縮放比例

--分隔符设定
char_s = "##"
char_m = "|<"
char_e = "##"


function oneClickRuby(subtitles, selected_lines)
	local grade = "1" --1~6 correspond to Japan primary school student grade, 7 for middle school and 8 for normal people.
 	local appid = "dj00aiZpPVZKRHFzZHY4Y3RtaSZzPWNvbnN1bWVyc2VjcmV0Jng9Zjg-" --suggest to change to your own appid.
	xml2lua = require("xml2lua")
	handler = require("xmlhandler.tree")
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
			for kDur,sylText in string.gmatch(orgText,"{\\k(%d+)}([^{]+)") do
				lineKara[#lineKara+1] = {sylText=sylText,kDur=kDur}
			end
			aegisub.progress.task("Requesting for line: "..lineNum)
			result = send2Yahoo(text,appid,grade)
			aegisub.progress.task("Parsing for line: "..lineNum)
			newText = xml2LineText(result,lineNum)
			if type(newText)=="string" and newText~="" then
				newText = xml2KaraText(newText,lineKara)
			else
				newText = orgText
			end
			l.effect = "karaoke"
		elseif string.find(text,char_m) then
			newText = text
			l.effect = "ruby"
		else
			aegisub.progress.task("Requesting for line: "..lineNum)
			result = send2Yahoo(text,appid,grade)
			aegisub.progress.task("Parsing for line: "..lineNum)
			newText = xml2LineText(result,lineNum)
			l.effect = "ruby"
		end
		-- newText = xml2KaraLineText(result,line_table or key_value,lineNum)
		aegisub.progress.task("Writing for line: "..lineNum)
		if newText ~= "" then
			l.text = newText
		else
			l.text = text
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

function send2Yahoo(sentence,appid,grade)
	local url = "https://jlp.yahooapis.jp/FuriganaService/V1/furigana"
	local result, err, message = request.send(url,{
		method = "POST",
		headers = {['content-type'] = "application/x-www-form-urlencoded"},
		data = {["appid"] = appid,
				["sentence"] = sentence,
				["grade"] = grade }
				})
	if (not result) then aegisub.debug.out(err, message) end
	return result.body
end

function xml2LineText(xmlStr,lineNum)
	xmlHandler = nil
	xmlHandler = handler:new()
	local parser = xml2lua.parser(xmlHandler)
	parser:parse(xmlStr)
	lineText = ""
	if xmlHandler.root.Error then
		aegisub.debug.out("Line "..tostring(lineNum).." returns an error："..xmlHandler.root.Error.Message.."\n")
	else
		wordTbl = xmlHandler.root.ResultSet.Result.WordList.Word
		if wordTbl.Furigana then
			if wordTbl.SubWordList then 
				subTbl = wordTbl.SubWordList.SubWord
				for i=1,#subTbl do
					if subTbl[i].Surface~=subTbl[i].Furigana then
						lineText = lineText..char_s..subTbl[i].Surface..char_m..subTbl[i].Furigana..char_e
					else
						lineText = lineText..subTbl[i].Surface
					end
				end
			else
				lineText = lineText..char_s..wordTbl.Surface..char_m..wordTbl.Furigana..char_e
			end
		else
			for i=1,#wordTbl do
				if wordTbl[i].Furigana then
					if wordTbl[i].SubWordList then 
						subTbl = wordTbl[i].SubWordList.SubWord
						for i=1,#subTbl do
							if subTbl[i].Surface~=subTbl[i].Furigana then
								lineText = lineText..char_s..subTbl[i].Surface..char_m..subTbl[i].Furigana..char_e
							else
								lineText = lineText..subTbl[i].Surface
							end
						end
					else
						lineText = lineText..char_s..wordTbl[i].Surface..char_m..wordTbl[i].Furigana..char_e
					end
				else
					lineText = lineText..wordTbl[i].Surface
				end
			end
		end
	end
	return lineText
end


function xml2KaraText(newText,lineKara)
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

	tmpSylText = ""
	tmpSylKDur = 0
	i = 1
	newKaraText = ""
	while i<=#lineKara do
		tmpSylText = tmpSylText..lineKara[i].sylText
		tmpSylKDur = tmpSylKDur + lineKara[i].kDur
		table.remove(lineKara,1)
		-- aegisub.debug.out(Y.table.tostring(newRubyTbl)..'\n\n')
		if tmpSylText == utf8.match(newRubyTbl[1],"[^|<]*") then
			newKaraText = newKaraText..string.format("{\\k%d}%s",tmpSylKDur,newRubyTbl[1])
			table.remove(newRubyTbl,1)
			tmpSylText = ""
			tmpSylKDur = 0
		end
	end
	return newKaraText
end

function deleteEmpty(tbl)
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

function Ruby(subs, sel)
	meta, styles = karaskel.collect_head(subs);
	for i=1,#sel do
		processline(subs,sel[i],i);
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
	subs.append(originline)
	end
end

aegisub.register_macro(script_name, script_description, oneClickRuby)