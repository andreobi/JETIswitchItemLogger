--[[
Description

This is a simple logger extention for JETI remote control devices.
You can select switchItems you want to log. The switchItem should be 
configured as Center, Prop (not Rev.)
Depending on your device you can have upto 24 log channels in total over
all applications. If you wand to deletea log channel, go to the Item 
select it and then clear (KEY4) the Item. 
It is not possible to register a switchItem twice.
Due to the system design it also makes no sence to sort the log channels.

This application requiers V4.28 


Licence:

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

]]
-- when you reached 24 log channels it might be, even if you deleted a channel that
-- you are not able do add another channel: work around delete one and restart the 
-- application - don't ask me why
-- when system.getswitchItem(...) will be availabel then
-- change pSave to store only labels and pload coud creates switchItems
-- getSwitchInfo doesn't provide all properties Prop missing: center rev
--   RPC could be stored as unit
----------------------------------------------------------------------
-- Locals for the application
local appName ="Ext SWItem Logger"
local extLog								-- [logId]{swItem,label,unit,orderNum}
local logMax=24								-- maximum of Log channels

----------------------------------------------------------------------
-- write logger data by return value [,resolution]
local function callbackLog(logId)
--  pcall ???
  return system.getInputsVal(extLog[logId].swItem)*1000,3
end

----------------------------------------------------------------------
-- configuration menue
local function initForm()
  local liInputLabel									-- list to be display
  local liInputIndex									-- list id to logId
  local revLogTab={}									-- list orderNum to  logId
------
  local function initLiInput()							-- create display list
    revLogTab={}
    for logId,v in pairs(extLog) do
	  if v.orderNum and logId then
	    revLogTab[v.orderNum]=logId
	  end
    end
    liInputLabel={}
	liInputIndex={}
	local index=1
	liInputLabel[index]="New"
	liInputIndex[index]=nil
    for orderNum=1, logMax,1 do
      local logId=revLogTab[orderNum]
	  if logId then
        if extLog[logId] and extLog[logId].swItem then
          local inputInfo=system.getSwitchInfo(extLog[logId].swItem)
          if inputInfo.label then
            index=index+1
            liInputLabel[index]=inputInfo.label
			liInputIndex[index]=logId
          end
	    end
      end
    end
  end
------
  local function changeInput(slInput)					-- handle selected switchItem
	local selctedRow
    local newInputInfo
	local double
	local highlight
----
    local function setLogChannel(orderNum,unit)			-- register log channel
      local logId =system.registerLogVariable(newInputInfo.label,unit,callbackLog)
      if logId then										-- got log channel
        extLog[logId]={}
        extLog[logId].swItem=slInput
        extLog[logId].label=newInputInfo.label
        extLog[logId].unit=unit
        extLog[logId].orderNum=orderNum
		return logId
      else
        system.messageBox ("<< "..newInputInfo.label.." >> not registered",3)
		return nil
      end
	end
----
    local function clearLogChannel(logId)
      system.unregisterLogVariable(logId)
      extLog[logId]=nil
    end
----
	selctedRow=form.getFocusedRow()
    newInputInfo=system.getSwitchInfo(slInput)
	double = false

    if newInputInfo.label then							-- got an item
      for i, label in pairs(liInputLabel) do
        if label == newInputInfo.label then				-- already present
          double=true
	      if selctedRow > 1 then
            local changeLgId=liInputIndex[selctedRow]	-- look up logID
			local changeOrNu=extLog[changeLgId].orderNum
            clearLogChannel(changeLgId)					-- delete entry to change
			if liInputIndex[i]~=changeLgId then
              clearLogChannel(liInputIndex[i])			-- delete douplicate
            end
			if setLogChannel(changeOrNu,"") then	-- set entry to change
		      highlight=newInputInfo.label
            end
          else
            local changeLgId=liInputIndex[i]			-- replace douplicate
			local changeOrNu=extLog[changeLgId].orderNum
            clearLogChannel(changeLgId)
			if setLogChannel(changeOrNu,"") then
		      highlight=newInputInfo.label
            end
		  end
          break
        end
      end
      if double==false then								
        if selctedRow>1 then							-- change log channel
          local changeLgId=liInputIndex[selctedRow]		-- look up logID
          local changeOrNu=extLog[changeLgId].orderNum
          clearLogChannel(changeLgId)
          if setLogChannel(changeOrNu,"") then
		    highlight=newInputInfo.label
          end
        else											-- create new log channel
          local done=false
          for orderNum=1, logMax,1 do					-- find empty entry
            local logId=revLogTab[orderNum]
            if logId == nil then
              setLogChannel(orderNum,"")
			  done=true
			  break
			end
		  end
		  if not done then
            system.messageBox ("<< "..newInputInfo.label.." >> not registered",3)
          end
        end
	  end
    else
      if selctedRow>1 then								-- clear selected row
        local clearLgId=liInputIndex[selctedRow]
        clearLogChannel(clearLgId)
		form.setFocusedRow(selctedRow-1)
      end	
	end
    initLiInput()
    if highlight then									-- find row to highlight
      for i, label in pairs(liInputLabel) do
	    if highlight==label then
		  form.setFocusedRow(i)
        end
      end
	end
    form.reinit()
-- ??? if "getswItem" is availabel then save labels (and parameter) only
    for i=1, logMax, 1 do								-- save changes
	  local logId=revLogTab[i]
	  if logId and extLog[logId].swItem then
        system.pSave("extLog"..i,extLog[logId].swItem)
      else 
	    system.pSave("extLog"..i,nil)
	  end
    end
  end
--
  initLiInput()
  for lineId, label in ipairs(liInputLabel) do			-- display List
    form.addRow(2)
	if lineId>1 then
      form.addLabel({label= extLog[liInputIndex[lineId]].orderNum.." - Log Ch: "..liInputIndex[lineId]})
      form.addInputbox(extLog[liInputIndex[lineId]].swItem, true, changeInput)
    else
      local newSw
      form.addLabel({label="New:"})
      form.addInputbox(newSw, true, changeInput)
	end
  end
end

----------------------------------------------------------------------
-- Application initialization
local function init()
-- check device and set maxLog

  extLog={}
  
-- ??? needs to be changed to create swItem(label,P...)
  for i=1, logMax, 1 do
    local switchItem=system.pLoad("extLog"..i)		-- read previous configuration
    if switchItem then
	  local x = system.getSwitchInfo(switchItem)
	  local logId =system.registerLogVariable(x.label,"",callbackLog)
      if logId then									-- got log channel
        extLog[logId]={}
        extLog[logId].swItem=switchItem
        extLog[logId].label=x.label
        extLog[logId].unit="READ"					-- ??? properties
		extLog[logId].orderNum=i
      end
	end
  end
-- ???
  system.registerForm(1,MENU_APPS,appName,initForm)
end
----------------------------------------------------------------------
-- Runtime functions
local function loop()
  -- NOP
end
----------------------------------------------------------------------

return {init=init, loop=loop, author="Andre", version="0.20", name=appName}
