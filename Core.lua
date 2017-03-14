-- Hekili.lua
-- April 2014

local addon, ns = ...
local Hekili = _G[ addon ]

local class = ns.class
local state = ns.state
local scriptDB = Hekili.Scripts

local buildUI = ns.buildUI
local callHook = ns.callHook
local checkScript = ns.checkScript
local clashOffset = ns.clashOffset
local formatKey = ns.formatKey
local getSpecializationID = ns.getSpecializationID
local getResourceName = ns.getResourceName
local importModifiers = ns.importModifiers
local initializeClassModule = ns.initializeClassModule
local isKnown = ns.isKnown
local isUsable = ns.isUsable
local loadScripts = ns.loadScripts
local refreshBindings = ns.refreshBindings
local refreshOptions = ns.refreshOptions
local restoreDefaults = ns.restoreDefaults
local runHandler = ns.runHandler
local tableCopy = ns.tableCopy
local timeToReady = ns.timeToReady
local trim = string.trim


local mt_resource = ns.metatables.mt_resource


local AD = ns.lib.ArtifactData


local updatedDisplays = {}



-- checkImports()
-- Remove any displays or action lists that were unsuccessfully imported.
local function checkImports()

    local profile = Hekili.DB.profile

    for i = #profile.displays, 1, -1 do
        local display = profile.displays[ i ]
        if type( display ) ~= 'table' or display.Name:match("^@") then
            table.remove( profile.displays, i )
        else
            if not display['Single - Minimum'] or type( display['Single - Minimum'] ) ~= 'number' then display['Single - Minimum'] = 0 end
            if not display['Single - Maximum'] or type( display['Single - Maximum'] ) ~= 'number' then display['Single - Maximum'] = 0 end
            if not display['AOE - Minimum'] or type( display['AOE - Minimum'] ) ~= 'number' then display['AOE - Minimum'] = 0 end
            if not display['AOE - Maximum'] or type( display['AOE - Maximum'] ) ~= 'number' then display['AOE - Maximum'] = 0 end
            if not display['Auto - Minimum'] or type( display['Auto - Minimum'] ) ~= 'number' then display['Auto - Minimum'] = 0 end
            if not display['Auto - Maximum'] or type( display['Auto - Maximum'] ) ~= 'number' then display['Auto - Maximum'] = 0 end
            if not display['Range Checking'] then display['Range Checking'] = 'ability' end

            if display['PvE Visibility'] and not display['PvE - Default Alpha'] then
                if display['PvE Visibility'] == 'always' then
                    display['PvE - Default'] = true
                    display['PvE - Default Alpha'] = 1
                    display['PvE - Target'] = false
                    display['PvE - Target Alpha'] = 1
                    display['PvE - Combat'] = false
                    display['PvE - Combat Alpha'] = 1
                elseif display['PvE Visibility'] == 'combat' then
                    display['PvE - Default'] = false
                    display['PvE - Default Alpha'] = 1
                    display['PvE - Target'] = false
                    display['PvE - Target Alpha'] = 1
                    display['PvE - Combat'] = true
                    display['PvE - Combat Alpha'] = 1
                elseif display['PvE Visibility'] == 'target' then
                    display['PvE - Default'] = false
                    display['PvE - Default Alpha'] = 1
                    display['PvE - Target'] = true
                    display['PvE - Target Alpha'] = 1
                    display['PvE - Combat'] = false
                    display['PvE - Combat Alpha'] = 1
                else
                    display['PvE - Default'] = false
                    display['PvE - Default Alpha'] = 1
                    display['PvE - Target'] = false
                    display['PvE - Target Alpha'] = 1
                    display['PvE - Combat'] = false
                    display['PvE - Combat Alpha'] = 1
                end
                display['PvE Visibility'] = nil
            end

            if display['PvP Visibility'] and not display['PvP - Default Alpha'] then
                if display['PvP Visibility'] == 'always' then
                    display['PvP - Default'] = true
                    display['PvP - Default Alpha'] = 1
                    display['PvP - Target'] = false
                    display['PvP - Target Alpha'] = 1
                    display['PvP - Combat'] = false
                    display['PvP - Combat Alpha'] = 1
                elseif display['PvP Visibility'] == 'combat' then
                    display['PvP - Default'] = false
                    display['PvP - Default Alpha'] = 1
                    display['PvP - Target'] = false
                    display['PvP - Target Alpha'] = 1
                    display['PvP - Combat'] = true
                    display['PvP - Combat Alpha'] = 1
                elseif display['PvP Visibility'] == 'target' then
                    display['PvP - Default'] = false
                    display['PvP - Default Alpha'] = 1
                    display['PvP - Target'] = true
                    display['PvP - Target Alpha'] = 1
                    display['PvP - Combat'] = false
                    display['PvP - Combat Alpha'] = 1
                else
                    display['PvP - Default'] = false
                    display['PvP - Default Alpha'] = 1
                    display['PvP - Target'] = false
                    display['PvP - Target Alpha'] = 1
                    display['PvP - Combat'] = false
                    display['PvP - Combat Alpha'] = 1
                end
                display['PvP Visibility'] = nil
            end
            
        end
    end
end
ns.checkImports = checkImports


function ns.pruneDefaults()
    
    local profile = Hekili.DB.profile

    for i = #profile.displays, 1, -1 do
        local display = profile.displays[ i ]
        if not ns.isDefault( display.Name, "displays" ) then
            display.Default = false
        end      
    end

    for i = #profile.actionLists, 1, -1 do
        local list = profile.actionLists[ i ]
        if type( list ) ~= 'table' or list.Name:match("^@") then
            for dispID, display in ipairs( profile.displays ) do
                for hookID, hook in ipairs ( display.Queues ) do
                    if hook[ 'Action List' ] == i then
                        hook[ 'Action List' ] = 0
                        hook.Enabled = false
                    elseif hook[ 'Action List' ] > i then
                        hook[ 'Action List' ] = hook[ 'Action List' ] - 1
                    end
                end
            end
            table.remove( profile.actionLists, i )
        elseif not ns.isDefault( list.Name, "actionLists" ) then
            list.Default = false
        end
            

    end    

end


-- OnInitialize()
-- Addon has been loaded by the WoW client (1x).
function Hekili:OnInitialize()
    self.DB = LibStub( "AceDB-3.0" ):New( "HekiliDB", self:GetDefaults() )

    self.Options = self:GetOptions()
    self.Options.args.profiles = LibStub( "AceDBOptions-3.0" ):GetOptionsTable( self.DB )

    -- Add dual-spec support
    ns.lib.LibDualSpec:EnhanceDatabase( self.DB, "Hekili" )
    ns.lib.LibDualSpec:EnhanceOptions( self.Options.args.profiles, self.DB )

    self.DB.RegisterCallback( self, "OnProfileChanged", "TotalRefresh" )
    self.DB.RegisterCallback( self, "OnProfileCopied", "TotalRefresh" )
    self.DB.RegisterCallback( self, "OnProfileReset", "TotalRefresh" )

    ns.lib.AceConfig:RegisterOptionsTable( "Hekili", self.Options )
    self.optionsFrame = ns.lib.AceConfigDialog:AddToBlizOptions( "Hekili", "Hekili" )
    self:RegisterChatCommand( "hekili", "CmdLine" )
    self:RegisterChatCommand( "hek", "CmdLine" )

    if not self.DB.profile.Version or self.DB.profile.Version < 7 or not self.DB.profile.Release or self.DB.profile.Release < 20161000 then
        self.DB:ResetDB()
    end

    self.DB.profile.Release = self.DB.profile.Release or 20161003.1

    initializeClassModule()
    refreshBindings()
    restoreDefaults()
    checkImports()
    refreshOptions()
    loadScripts()

    ns.updateTalents()
    ns.updateGear()

    ns.primeTooltipColors()

    callHook( "onInitialize" )

    if class.file == 'NONE' then
        if self.DB.profile.Enabled then
            self.DB.profile.Enabled = false
            self.DB.profile.AutoDisabled = true
        end
        for i, buttons in ipairs( ns.UI.Buttons ) do
            for j, _ in ipairs( buttons ) do
                buttons[j]:Hide()
            end
        end
    end

end


function Hekili:ReInitialize()
    ns.initializeClassModule()
    refreshBindings()
    restoreDefaults()
    checkImports()
    refreshOptions()
    loadScripts()

    ns.updateTalents()
    ns.updateGear()

    self.DB.profile.Release = self.DB.profile.Release or 20161003.1

    callHook( "onInitialize" )

    if self.DB.profile.Enabled == false and self.DB.profile.AutoDisabled then 
        self.DB.profile.AutoDisabled = nil
        self.DB.profile.Enabled = true
        self:Enable()
    end

    if class.file == 'NONE' then
        self.DB.profile.Enabled = false
        self.DB.profile.AutoDisabled = true
        for i, buttons in ipairs( ns.UI.Buttons ) do
            for j, _ in ipairs( buttons ) do
                buttons[j]:Hide()
            end
        end
    end

end    


function Hekili:OnEnable()

    ns.specializationChanged()
    ns.StartEventHandler()
    buildUI()
    ns.overrideBinds()

    Hekili.s = ns.state

    -- May want to refresh configuration options, key bindings.
    if self.DB.profile.Enabled then

        self:UpdateDisplays()
        ns.Audit()

    else
        self:Disable()

    end

end


function Hekili:OnDisable()
    self.DB.profile.Enabled = false
    ns.StopEventHandler()
end


-- Texture Caching,
local s_textures = setmetatable( {},
    {
        __index = function(t, k)
            local a = _G[ 'GetSpellTexture' ](k)
            if a and k ~= GetSpellInfo( 115698 ) then t[k] = a end
            return (a)
        end
    } )

local i_textures = setmetatable( {},
    {
        __index = function(t, k)
            local a = select(10, GetItemInfo(k))
            if a then t[k] = a end
            return a
        end
    } )

-- Insert textures that don't work well with predictions.
s_textures[GetSpellInfo(115356)] = 1029585  -- Windstrike
s_textures[GetSpellInfo(17364)] = 132314  -- Stormstrike
-- NYI:  Need Chain Lightning/Lava Beam here.

local function GetSpellTexture( spell )
    -- if class.abilities[ spell ].item then return i_textures[ spell ] end
    return ( s_textures[ spell ] )
end


local z_PVP = {
    arena = true,
    pvp = true
}


local palStack = {}

function Hekili:ProcessActionList( dispID, hookID, listID, slot, depth, action, wait, clash )
    
    local display = self.DB.profile.displays[ dispID ]
    local list = self.DB.profile.actionLists[ listID ]

    -- self:Debug( "Testing action list [ %d - %s ].", listID, list and list.Name or "ERROR - Does Not Exist"  )
    self:Debug( "Previous Recommendation:  %s at +%.2fs, clash is %.2f.", action or "NO ACTION", wait or 30, clash or 0 )
    
    -- the stack will prevent list loops, but we need to keep this from destroying existing data... later.
    if not list then
        self:Debug( "No list with ID #%d.  Should never see.", listID )
    elseif palStack[ list.Name ] then
        self:Debug( "Action list loop detected.  %s was already processed earlier.  Aborting.", list.Name )
        return 
    else
        self:Debug( "Adding %s to the list of processed action lists.", list.Name )
        palStack[ list.Name ] = true
    end
    
    local chosen_action = action
    local chosen_clash = clash or 0
    local chosen_wait = wait or 30
    local chosen_depth = depth or 0

    local stop = false

    if ns.visible.list[ listID ] then
        local actID = 1

        while actID <= #list.Actions and chosen_wait do
            if chosen_wait <= state.cooldown.global_cooldown.remains then
                self:Debug( "The last selected ability ( %s ) is available at (or before) the next GCD.  End loop.", chosen_action )
                self:Debug( "Removing %s from list of processed action lists.", list.Name )
                palStack[ list.Name ] = nil
                return chosen_action, chosen_wait, chosen_clash, chosen_depth
            elseif chosen_wait == 0 then
                self:Debug( "The last selected ability ( %s ) has no wait time.  End loop.", chosen_action )
                self:Debug( "Removing %s from list of processed action lists.", list.Name )
                palStack[ list.Name ] = nil
                return chosen_action, chosen_wait, chosen_clash, chosen_depth
            elseif stop then
                self:Debug( "Returning to parent list after completing Run_Action_List ( %d - %s ).", listID, list.Name )
                self:Debug( "Removing %s from list of processed action lists.", list.Name )
                palStack[ list.Name ] = nil
                return chosen_action, chosen_wait, chosen_clash, chosen_depth
            end

            if ns.visible.action[ listID..':'..actID ] then

                -- Check for commands before checking actual actions.
                local entry = list.Actions[ actID ]
                state.this_action = entry.Ability
                state.this_args = entry.Args
                
                state.delay = nil
                chosen_depth = chosen_depth + 1

                local minWait = state.cooldown.global_cooldown.remains

                -- Need to expand on modifiers, gather from other settings as needed.
                self:Debug( "\n[ %2d ] Testing entry %s:%d ( %s ) with modifiers ( %s ).", chosen_depth, list.Name, actID, entry.Ability, entry.Args or "NONE" )

                local ability = class.abilities[ entry.Ability ]

                local wait_time = 30
                local clash = 0

                local known = isKnown( state.this_action )

                self:Debug( "%s is %s.", ability.name, known and "KNOWN" or "NOT KNOWN" )

                if known then
                    -- Used to notify timeToReady() about an artificial delay for this ability.
                    state.script.entry = entry.whenReady == 'script' and ( listID .. ':' .. actID ) or nil

                    wait_time = timeToReady( state.this_action )
                    clash = clashOffset( state.this_action )

                    state.delay = wait_time
                    importModifiers( listID, actID )

                    if wait_time >= chosen_wait then
                        self:Debug( "This action is not available in time for consideration ( %.2f vs. %.2f ).  Skipping.", wait_time, chosen_wait )
                    else
                        local preservedWait = wait_time
                        local interval = state.gcd / 3
                        local calledList = false

                        -- There is a leak inside here, it worsens with higher testCounts.
                        for testCount = 1, ( self.LowImpact or self.DB.profile['Low Impact Mode'] ) and 2 or 5 do

                            if stop or calledList then break end

                            if testCount == 1 then
                            elseif testCount == 2 then  state.delay = preservedWait + 0.1
                            elseif testCount == 3 then  state.delay = preservedWait + ( state.gcd / 2 )
                            elseif testCount == 4 then  state.delay = preservedWait + state.gcd
                            elseif testCount == 5 then  state.delay = preservedWait + ( state.gcd * 2 )
                            end

                            local newWait = max( 0, state.delay - clash )
                            local usable = isUsable( state.this_action )

                            self:Debug( "Test #%d at [ %.2f + %.2f ] - Ability ( %s ) is %s.", testCount, state.offset, state.delay, entry.Ability, usable and "USABLE" or "NOT USABLE" )
                            
                            if usable then
                                local chosenWaitValue = max( 0, chosen_wait - chosen_clash )
                                local readyFirst = newWait < chosenWaitValue

                                self:Debug( " - this ability is %s at %.2f before the previous ability at %.2f.", readyFirst and "READY" or "NOT READY", newWait, chosenWaitValue )

                                if readyFirst then
                                    local hasResources = ns.hasRequiredResources( state.this_action )
                                    self:Debug( " - the required resources are %s.", hasResources and "AVAILABLE" or "NOT AVAILABLE" )

                                    if hasResources then
                                        local aScriptPass = true
                                        local scriptID = listID .. ':' .. actID

                                        if not entry.Script or entry.Script == '' then self:Debug( ' - this ability has no required conditions.' )
                                        else 
                                            aScriptPass = checkScript( 'A', scriptID )
                                            self:Debug( "Conditions %s:  %s", aScriptPass and "MET" or "NOT MET", ns.getConditionsAndValues( 'A', scriptID ) )
                                        end

                                        if aScriptPass then
                                            if entry.Ability == 'call_action_list' or entry.Ability == 'run_action_list' then

                                                stop = entry.Ability == 'run_action_iist'

                                                local aList = state.args.ModName or state.args.name

                                                if aList then
                                                    -- check to see if we have a real list name.
                                                    local called_list = 0
                                                    for i, list in ipairs( self.DB.profile.actionLists ) do
                                                        if list.Name == aList then
                                                            called_list = i
                                                            break
                                                        end
                                                    end

                                                    if called_list > 0 then
                                                        self:Debug( "The action list for %s ( %s ) was found.", entry.Ability, aList )
                                                        chosen_action, chosen_wait, chosen_clash, chosen_depth = Hekili:ProcessActionList( dispID, listID..':'..actID, called_list, slot, chosen_depth, chosen_action, chosen_wait, chosen_clash )
                                                        calledList = true
                                                    else
                                                        self:Debug( "The action list for %s ( %s ) was not found.", entry.Ability, aList )
                                                    end
                                                end

                                            elseif entry.Ability == 'wait' then
                                                    -- local args = ns.getModifiers( listID, actID )
                                                if not state.args.sec then state.args.sec = 1 end
                                                if state.args.sec > 0 then
                                                    state.advance( state.args.sec )
                                                    actID = 0
                                                end

                                            elseif entry.Ability == 'potion' then
                                                local potionName = state.args.ModName or state.args.name or class.potion
                                                local potion = class.potions[ potionName ]

                                                if potion then
                                                    -- do potion things
                                                    slot.scriptType = entry.ScriptType or 'simc'
                                                    slot.display = dispID
                                                    slot.button = i

                                                    slot.wait = state.delay

                                                    slot.hook = hookID
                                                    slot.list = listID
                                                    slot.action = actID

                                                    slot.actionName = state.this_action
                                                    slot.listName = list.Name

                                                    slot.resource = ns.resourceType( chosen_action )
                                                    
                                                    slot.caption = entry.Caption
                                                    slot.indicator = ( entry.Indicator and entry.Indicator ~= 'none' ) and entry.Indicator
                                                    slot.texture = select( 10, GetItemInfo( potion.item ) )
                                                    
                                                    chosen_action = state.this_action
                                                    chosen_wait = state.delay
                                                    chosen_clash = clash
                                                    break
                                                end

                                            else
                                                slot.scriptType = entry.ScriptType or 'simc'
                                                slot.display = dispID
                                                slot.button = i

                                                slot.wait = state.delay

                                                slot.hook = hookID
                                                slot.list = listID
                                                slot.action = actID

                                                slot.actionName = state.this_action
                                                slot.listName = list.Name

                                                slot.resource = ns.resourceType( chosen_action )
                                                
                                                slot.caption = entry.Caption
                                                slot.indicator = ( entry.Indicator and entry.Indicator ~= 'none' ) and entry.Indicator
                                                slot.texture = ability.texture
                                                
                                                chosen_action = state.this_action
                                                chosen_wait = state.delay
                                                chosen_clash = clash

                                                if entry.CycleTargets and state.active_enemies > 1 and ability and ability.cycle then
                                                    if state.dot[ ability.cycle ].up and state.active_dot[ ability.cycle ] < ( state.args.MaxTargets or state.active_enemies ) then
                                                        slot.indicator = 'cycle'
                                                    end
                                                end

                                                break
                                            
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        state.delay = preservedWait
                    end
                end
            end

            actID = actID + 1

        end

    end

    palStack[ list.Name ] = nil
    return chosen_action, chosen_wait, chosen_clash, chosen_depth

end


function Hekili:ProcessHooks( dispID, solo )

    if not self.DB.profile.Enabled then return end

    if not self.Pause then
        local display = self.DB.profile.displays[ dispID ]

        ns.queue[ dispID ] = ns.queue[ dispID ] or {}
        local Queue = ns.queue[ dispID ]

        if display and ns.visible.display[ dispID ] then

            state.reset( dispID )

            self:SetupDebug( display.Name )

            if Queue then
                for k, v in pairs( Queue ) do
                    for l, w in pairs( v ) do
                        if type( Queue[ k ][ l ] ) ~= 'table' then
                            Queue[k][l] = nil
                        end
                    end
                end
            end

            local dScriptPass = checkScript( 'D', dispID )

            self:Debug( "*** START OF NEW DISPLAY ***\n" ..
                "Display %d (%s) is %s.", dispID, display.Name, ( self.Config or dScriptPass ) and "VISIBLE" or "NOT VISIBLE" )
            
            self:Debug( "Conditions %s:  %s", dScriptPass and "MET" or "NOT MET", ns.getConditionsAndValues( 'D', dispID ) )

            if ( self.Config or dScriptPass ) then
                
                for i = 1, display['Icons Shown'] do

                    local chosen_action
                    local chosen_wait, chosen_clash, chosen_depth = 30, self.DB.profile.Clash or 0, 0

                    Queue[i] = Queue[i] or {}

                    local slot = Queue[i]

                    local attempts = 0

                    self:Debug( "\n[ ** ] Checking for recommendation #%d ( time offset: %.2f, remaining GCD: %.2f ).  Review hooked action lists.", i, state.offset, state.cooldown.global_cooldown.remains )

                    for hookID, hook in ipairs( display.Queues ) do

                        local hookKey = dispID .. ':' .. hookID
                        local visible = ns.visible.hook[ hookKey ]
                        local hScriptPass = checkScript( 'P', hookKey )

                        self:Debug( "Hook #%d ( %s ) is %s.\n" ..
                            "Conditions %s:  %s", hookID, hook.Name, ( visible and hScriptPass ) and "ACTIVE" or "INACTIVE", hScriptPass and "MET" or "NOT MET", ns.getConditionsAndValues( 'P', hookKey ) )

                        if visible and hookID and hScriptPass then

                            local listID = hook[ 'Action List' ]
                            local listName = self.DB.profile.actionLists[ listID ].Name

                            self:Debug( "Calling action list [ %d - %s ] from hook #%d.", listID, listName, hookID )

                            chosen_action, chosen_wait, chosen_clash, chosen_depth = self:ProcessActionList( dispID, hookID, listID, slot, chosen_depth, chosen_action, chosen_wait, chosen_clash )

                            self:Debug( "Completed processing action list [ %d - %s ] from hook #%d.", listID, listName, hookID )

                            if chosen_wait == 0 then
                                self:Debug( "Stopped checking hooks after #%d as we've found the highest priority entry with no wait time.", hookID )
                                break
                            end

                        end

                    end

                    self:Debug( "Recommendation #%d is %s at %.2f.", i, chosen_action or "NO ACTION", state.offset + chosen_wait )

                    -- Wipe out the delay, as we're advancing to the cast time.
                    state.delay = 0

                    if chosen_action then
                        -- We have our actual action, so let's get the script values if we're debugging.

                        if self.DB.profile.Debug then ns.implantDebugData( slot ) end

                        slot.time = state.offset + chosen_wait
                        slot.exact_time = state.now + state.offset + chosen_wait
                        slot.since = i > 1 and slot.time - Queue[ i - 1 ].time or 0
                        slot.resources = slot.resources or {}
                        slot.depth = chosen_depth

                        for k,v in pairs( class.resources ) do
                            slot.resources[k] = state[k].current 
                            if state[k].regen then slot.resources[k] = min( state[k].max, slot.resources[k] + ( state[k].regen * chosen_wait ) ) end
                        end

                        slot.resource_type = ns.resourceType( chosen_action )

                        if i < display['Icons Shown'] then

                            -- Advance through the wait time.
                            state.advance( chosen_wait )

                            local action = class.abilities[ chosen_action ]

                            -- Start the GCD.
                            if action.gcdType ~= 'off' and state.cooldown.global_cooldown.remains == 0 then
                                state.setCooldown( 'global_cooldown', state.gcd )
                            end

                            -- Advance the clock by cast_time.
                            if action.cast > 0 and not action.channeled then
                                state.advance( action.cast )
                            end

                            -- Put the action on cooldown.  (It's slightly premature, but addresses CD resets like Echo of the Elements.)
                            if class.abilities[ chosen_action ].charges and action.recharge > 0 then
                                state.spendCharges( chosen_action, 1 )
                            elseif chosen_action ~= 'global_cooldown' then
                                state.setCooldown( chosen_action, action.cooldown )
                            end

                            state.cycle = slot.indicator == 'cycle'

                            -- Spend resources.
                            ns.spendResources( chosen_action )

                            -- Perform the action.
                            ns.runHandler( chosen_action )

                            -- Advance the clock by cast_time.
                            if action.cast > 0 and action.channeled then
                                state.advance( action.cast )
                            end

                            -- Move the clock forward if the GCD hasn't expired.
                            if state.cooldown.global_cooldown.remains > 0 then
                                state.advance( state.cooldown.global_cooldown.remains )
                            end

                        end

                    else
                        for n = i, display['Icons Shown'] do
                            slot[n] = nil
                        end
                        break
                    end

                end

            end

        end

    end

    -- if not solo then C_Timer.After( 1 / self.DB.profile['Updates Per Second'], self[ 'ProcessDisplay'..dispID ] ) end
    ns.displayUpdates[ dispID ] = GetTime()
    updatedDisplays[ dispID ] = 0
    -- Hekili:UpdateDisplay( dispID )

end


local pvpZones = {
    arena = true,
    pvp = true
}


local function CheckDisplayCriteria( dispID )

    local display = Hekili.DB.profile.displays[ dispID ]
    local _, zoneType = IsInInstance()

    -- if C_PetBattles.IsInBattle() or Hekili.Barber or UnitInVehicle( 'player' ) or not ns.visible.display[ dispID ] then
    if C_PetBattles.IsInBattle() or UnitOnTaxi( 'player' ) or Hekili.Barber or HasVehicleActionBar() or not ns.visible.display[ dispID ] then
        return 0

    elseif not pvpZones[ zoneType ] then
        if display['PvE - Target'] and UnitExists( 'target' ) and not ( UnitIsDead( 'target' ) or not UnitCanAttack( 'player', 'target' ) ) then
            return display['PvE - Target Alpha']

        elseif display['PvE - Combat'] and UnitAffectingCombat( 'player' ) then
            return display['PvE - Combat Alpha']

        elseif display['PvE - Default'] then
            return display['PvE - Default Alpha']

        end

        return 0

    elseif pvpZones[ zoneType ] then
        if display['PvP - Target'] and UnitExists( 'target' ) and not ( UnitIsDead( 'target' ) or not UnitCanAttack( 'player', 'target' ) ) then
            return display['PvP - Target Alpha']

        elseif display['PvP - Combat'] and UnitAffectingCombat( 'player' ) then
            return display['PvP - Combat Alpha']

        elseif display['PvP - Default'] then
            return display['PvP - Default Alpha']

        end

        return 0

    elseif not Hekili.Config and not ns.queue[ dispID ] then
        return 0

    elseif not checkScript( 'D', dispID ) then
        return 0

    end

    return 0

end
ns.CheckDisplayCriteria = CheckDisplayCriteria


function Hekili_GetRecommendedAbility( display, entry )

    if type( display ) == 'string' then
        local found = false
        for dispID, disp in pairs(Hekili.DB.profile.displays) do
            if not found and disp.Name == display then
                display = dispID
                found = true
            end
        end
        if not found then return nil, "Display name not found." end
    end

    if not Hekili.DB.profile.displays[ display ] then
        return nil, "Display not found."
    end

    if not ns.queue[ display ] then
        return nil, "No queue for that display."
    end

    if not ns.queue[ display ][ entry ] then
        return nil, "No entry #" .. entry .. " for that display."
    end

    return class.abilities[ ns.queue[ display ][ entry ].actionName ].id

end



local flashes = {}
local checksums = {}
local applied = {}

function Hekili:UpdateDisplay( dispID )

    local self = self or Hekili

    if not self.DB.profile.Enabled then
        return
    end

    -- for dispID, display in pairs(self.DB.profile.displays) do
    local display = self.DB.profile.displays[ dispID ]

    if not ns.UI.Buttons or not ns.UI.Buttons[ dispID ] then return end

    if self.Pause then
        ns.UI.Buttons[ dispID ][1].Overlay:SetTexture('Interface\\Addons\\Hekili\\Textures\\Pause.blp')
        ns.UI.Buttons[ dispID ][1].Overlay:Show()

    else
        flashes[dispID] = flashes[dispID] or 0

        ns.UI.Buttons[ dispID ][1].Overlay:Hide()

        local alpha = CheckDisplayCriteria( dispID ) or 0

        if alpha > 0 then
            local Queue = ns.queue[ dispID ]

            local gcd_start, gcd_duration = GetSpellCooldown( class.abilities.global_cooldown.id )
            local now = GetTime()

            _G[ "HekiliDisplay" .. dispID ]:Show()

            for i, button in ipairs( ns.UI.Buttons[ dispID ] ) do
                if not Queue or not Queue[i] and ( self.DB.profile.Enabled or self.Config ) then
                    for n = i, display['Icons Shown'] do
                        ns.UI.Buttons[dispID][n].Texture:SetTexture( 'Interface\\ICONS\\Spell_Nature_BloodLust' )
                        ns.UI.Buttons[dispID][n].Texture:SetVertexColor(1, 1, 1)
                        ns.UI.Buttons[dispID][n].Caption:SetText(nil)
                        if not self.Config then
                            ns.UI.Buttons[dispID][n]:Hide()
                        else
                            ns.UI.Buttons[dispID][n]:Show()
                            ns.UI.Buttons[dispID][n]:SetAlpha(alpha)
                        end
                    end
                    break
                end

                local aKey, caption, indicator = Queue[i].actionName, Queue[i].caption, Queue[i].indicator

                if aKey then
                    button:Show()
                    button:SetAlpha(alpha)
                    button.Texture:SetTexture( Queue[i].texture or class.abilities[ aKey ].texture or GetSpellTexture( class.abilities[ aKey ].id ) )
                    local zoom = ( display.Zoom or 0 ) / 200
                    button.Texture:SetTexCoord( zoom, 1 - zoom, zoom, 1 - zoom )
                    button.Texture:Show()

                    if indicator then
                        if indicator == 'cycle' then button.Icon:SetTexture( "Interface\\Addons\\Hekili\\Textures\\Cycle" ) end
                        if indicator == 'cancel' then button.Icon:SetTexture( "Interface\\Addons\\Hekili\\Textures\\Cancel" ) end
                        button.Icon:Show()
                    else
                        button.Icon:Hide()
                    end

                    if display['Action Captions'] then

                        -- 0 = single
                        -- 2 = cleave
                        -- 2 = aoe
                        -- 3 = auto
                        local min_targets, max_targets = 0, 0

                        if Hekili.DB.profile['Mode Status'] == 0 then
                            if display['Single - Minimum'] > 0 then min_targets = display['Single - Minimum'] end
                            if display['Single - Maximum'] > 0 then max_targets = display['Single - Maximum'] end
                        elseif Hekili.DB.profile['Mode Status'] == 2 then
                            if display['AOE - Minimum'] > 0 then min_targets = display['AOE - Minimum'] end
                            if display['AOE - Maximum'] > 0 then max_targets = display['AOE - Maximum'] end
                        elseif Hekili.DB.profile['Mode Status'] == 3 then
                            if display['Auto - Minimum'] > 0 then min_targets = display['Auto - Minimum'] end
                            if display['Auto - Maximum'] > 0 then max_targets = display['Auto - Maximum'] end
                        end

                        -- local detected = ns.getNameplateTargets()
                        -- if detected == -1 then detected = ns.numTargets() end

                        local detected = max( 1, ns.getNumberTargets() )
                        local targets = detected

                        if min_targets > 0 then targets = max( min_targets, targets ) end
                        if max_targets > 0 then targets = min( max_targets, targets ) end

                        local targColor = ''

                        if detected < targets then targColor = '|cFFFF0000'
                        elseif detected > targets then targColor = '|cFF00C0FF' end

                        if display['Show Keybindings'] then
                            button.Keybinding:SetText( self:GetBindingForAction( aKey, display[ 'Keybinding Style' ] ~= 1 ) )
                            button.Keybinding:Show()
                        else
                            button.Keybinding:Hide()
                        end

                        if i == 1 then
                            if display.Overlay and IsSpellOverlayed( class.abilities[ aKey ].id ) then
                                ActionButton_ShowOverlayGlow( button )
                            else
                                ActionButton_HideOverlayGlow( button )
                            end
                            button.Caption:SetJustifyH('RIGHT')
                            -- check for special captions.
                            if display['Primary Caption'] == 'targets' and targets > 1 then -- and targets > 1 then
                                button.Caption:SetText( targColor .. targets .. '|r' )

                            elseif display['Primary Caption'] == 'buff' then
                                if display['Primary Caption Aura'] then
                                    local name, _, _, count, _, _, expires = UnitBuff( 'player', display['Primary Caption Aura'] )
                                    if name then button.Caption:SetText( count or 1 )
                                    else
                                        button.Caption:SetJustifyH('CENTER')
                                        button.Caption:SetText(caption)
                                    end
                                end

                            elseif display['Primary Caption'] == 'debuff' then
                                if display['Primary Caption Aura'] then
                                    local name, _, _, count = UnitDebuff( 'target', display['Primary Caption Aura'] )
                                    if name then button.Caption:SetText( count or 1 )
                                    else
                                        button.Caption:SetJustifyH('CENTER')
                                        button.Caption:SetText(caption)
                                    end
                                end

                            elseif display['Primary Caption'] == 'ratio' then
                                if display['Primary Caption Aura'] then
                                    if ns.numDebuffs( display['Primary Caption Aura'] ) > 1 or targets > 1 then
                                        button.Caption:SetText( ns.numDebuffs( display['Primary Caption Aura'] ) .. ' / ' .. targColor .. targets .. '|r' )
                                    else
                                        button.Caption:SetJustifyH('CENTER')
                                        button.Caption:SetText(caption)
                                    end
                                end

                            elseif display['Primary Caption'] == 'sratio' then
                                if display['Primary Caption Aura'] then
                                    local name, _, _, count, _, _, expires = UnitBuff( 'player', display['Primary Caption Aura'] )
                                    if name and ( ( count or 1 ) > 0 ) then
                                        local cap = count or 1
                                        if targets > 1 then cap = cap .. ' / ' .. targColor .. targets .. '|r' end
                                        button.Caption:SetText( cap )
                                    else
                                        if targets > 1 then button.Caption:SetText( targColor .. targets .. '|r' )
                                        else
                                            button.Caption:SetJustifyH('CENTER')
                                            button.Caption:SetText(caption)
                                        end
                                    end
                                end

                            else
                                button.Caption:SetJustifyH('CENTER')
                                button.Caption:SetText(caption)

                            end
                        else
                            button.Caption:SetJustifyH('CENTER')
                            button.Caption:SetText(caption)

                        end
                    else
                        button.Caption:SetJustifyH('CENTER')
                        button.Caption:SetText(nil)

                    end

                    local start, duration = GetSpellCooldown( class.abilities[ aKey ].id )
                    local gcd_remains = gcd_start + gcd_duration - GetTime()

                    if class.abilities[ aKey ].gcdType ~= 'off' and ( not start or start == 0 or ( start + duration ) < ( gcd_start + gcd_duration ) ) then
                        start = gcd_start
                        duration = gcd_duration
                    end

                    if i == 1 then
                        button.Cooldown:SetCooldown( start, duration )

                        if ns.lib.SpellFlash and display['Use SpellFlash'] and GetTime() >= flashes[dispID] + 0.2 then
                            ns.lib.SpellFlash.FlashAction( class.abilities[ aKey ].id, display['SpellFlash Color'] )
                            flashes[dispID] = GetTime()
                        end

                        if ( class.file == 'HUNTER' or class.file == 'MONK' ) and Queue[i].exact_time and Queue[i].exact_time ~= gcd_start + gcd_duration and Queue[i].exact_time > now then
                            -- button.Texture:SetDesaturated( Queue[i].time > 0 )
                            button.Delay:SetText( format( "%.1f", Queue[i].exact_time - now ) )
                        else
                            -- button.Texture:SetDesaturated( false )
                            button.Delay:SetText( nil )
                        end

                    else
                        if ( start + duration ~= gcd_start + gcd_duration ) then
                            button.Cooldown:SetCooldown( start, duration )
                        else
                            button.Cooldown:SetCooldown( 0, 0 )
                        end
                    end

                    if display['Range Checking'] == 'melee' then
                        local minR = ns.lib.RangeCheck:GetRange( 'target' )
                        
                        if minR and minR >= 5 then 
                            ns.UI.Buttons[dispID][i].Texture:SetVertexColor(1, 0, 0)
                        elseif i == 1 and select(2, IsUsableSpell( class.abilities[ aKey ].id ) ) then
                            ns.UI.Buttons[dispID][i].Texture:SetVertexColor(0.4, 0.4, 0.4)
                        else
                            ns.UI.Buttons[dispID][i].Texture:SetVertexColor(1, 1, 1)
                        end
                    elseif display['Range Checking'] == 'ability' then
                        local rangeSpell = class.abilities[ aKey ].range and GetSpellInfo( class.abilities[ aKey ].range ) or class.abilities[ aKey ].name
                        if ns.lib.SpellRange.IsSpellInRange( rangeSpell, 'target' ) == 0 then
                            ns.UI.Buttons[dispID][i].Texture:SetVertexColor(1, 0, 0)
                        elseif i == 1 and select(2, IsUsableSpell( class.abilities[ aKey ].id )) then
                            ns.UI.Buttons[dispID][i].Texture:SetVertexColor(0.4, 0.4, 0.4)
                        else
                            ns.UI.Buttons[dispID][i].Texture:SetVertexColor(1, 1, 1)
                        end
                    elseif display['Range Checking'] == 'off' then
                        ns.UI.Buttons[dispID][i].Texture:SetVertexColor(1, 1, 1)
                    end

                else
                    ns.UI.Buttons[dispID][i].Texture:SetTexture( nil )
                    ns.UI.Buttons[dispID][i].Cooldown:SetCooldown( 0, 0 )
                    ns.UI.Buttons[dispID][i]:Hide()

                end

            end

        else
            for i, button in ipairs(ns.UI.Buttons[dispID]) do
                button:Hide()

            end
        end
    end

end


function Hekili:UpdateDisplays()
    local now = GetTime()

    for display, update in pairs( updatedDisplays ) do
        if now - update > 0.033 then
            Hekili:UpdateDisplay( display )
            updatedDisplays[ display ] = now
        end
    end
end
