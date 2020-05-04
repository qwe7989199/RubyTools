script_name = "Get Ruby"
script_description = "Generate furigana formatted lyrics by Yahoo's API"
script_author = "domo"
script_version = "1.0"

local request = require("luajit-request")
local ffi = require"ffi"

function getRuby(subtitles, selected_lines)
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
	for i=1,#selected_lines do
		l = subtitles[selected_lines[i]]
		text = l.text
		l.comment = true
		subtitles[selected_lines[i]] = l
		aegisub.progress.task("Requesting for line: "..tostring(selected_lines[i]-dialogue_start))
		result = send2Yahoo(text,appid,grade)
		aegisub.progress.task("Parsing for line: "..tostring(selected_lines[i]-dialogue_start))
		newText = xml2LineText(result,i)
		l.effect = "ruby"
		aegisub.progress.task("Writing for line: "..tostring(selected_lines[i]-dialogue_start))
		if newText ~= "" then
			l.text = newText
		else
			l.text = text
		end
		l.comment = false
		subtitles.append(l)
		aegisub.progress.set(i/#selected_lines*100)
	end
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

aegisub.register_macro(script_name, script_description, getRuby)
