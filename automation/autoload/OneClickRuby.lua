script_name = "One Click Ruby"
script_description = "Get the formatted lyrics by Yahoo's API and ruby them"
script_author = "domo"
ruby_part_from = "Kage Maboroshi&KiNen"
script_version = "1.0"

require "karaskel"
local request = require("luajit-request")
local ffi = require"ffi"

meta = nil;
styles = nil;

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
		text = l.text
		l.comment = true
		subtitles[selected_lines[i]] = l
		aegisub.progress.task("Requesting for line: "..lineNum)
		result = send2Yahoo(text,appid,grade)
		aegisub.progress.task("Parsing for line: "..lineNum)
		newText = xml2LineText(result,lineNum)
		l.effect = "ruby"
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
		Ruby(subtitles, newLineTbl)
		-- uncomment this if you have the demand to use the raw format
		-- subtitles.append(table.unpack(newLineTbl))
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
						lineText = lineText.."##"..subTbl[i].Surface.."|"..subTbl[i].Furigana.."##"
					else
						lineText = lineText..subTbl[i].Surface
					end
				end
			else
				lineText = lineText.."##"..wordTbl.Surface.."|"..wordTbl.Furigana.."##"
			end
		else
			for i=1,#wordTbl do
				if wordTbl[i].Furigana then
					if wordTbl[i].SubWordList then 
						subTbl = wordTbl[i].SubWordList.SubWord
						for i=1,#subTbl do
							if subTbl[i].Surface~=subTbl[i].Furigana then
								lineText = lineText.."##"..subTbl[i].Surface.."|"..subTbl[i].Furigana.."##"
							else
								lineText = lineText..subTbl[i].Surface
							end
						end
					else
						lineText = lineText.."##"..wordTbl[i].Surface.."|"..wordTbl[i].Furigana.."##"
					end
				else
					lineText = lineText..wordTbl[i].Surface
				end
			end
		end
	end
	return lineText
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
	--參數設定--
	rubypadding = 0 --小字間距
	rubyscale = 0.5 --小字縮放比例

	--分隔符设定
	char_s = "##"
	char_m= "|"
	char_e= "##"
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
	end
end

aegisub.register_macro(script_name, script_description, oneClickRuby)
