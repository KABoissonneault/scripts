-- allows to do jobs in adv. mode.
local gui = require 'gui'
local wid=require 'gui.widgets'
local dialog=require 'gui.dialogs'
local buildings=require 'dfhack.buildings'
--[[**********************
    tools and their uses:
    1. axe -> chop trees
    2. pickaxe -> dig, carve floors/ramps/stairs/etc (engrave too for now)
--]]
mode=mode or 0
keybinds={
key_next={key="CUSTOM_SHIFT_T",desc="Next job in the list"},
key_prev={key="CUSTOM_SHIFT_R",desc="Previous job in the list"},
key_continue={key="A_WAIT",desc="Continue job if available"},
--key_down_alt1={key="A_CUSTOM_CTRL_D",desc="Use job down"},--does not work?
key_down_alt2={key="CURSOR_DOWN_Z_AUX",desc="Use job down"},
--key_up_alt1={key="A_CUSTOM_CTRL_E",desc="Use job up"}, --does not work?
key_up_alt2={key="CURSOR_UP_Z_AUX",desc="Use job up"},
key_use_same={key="A_MOVE_SAME_SQUARE",desc="Use job at the tile you are standing"},
}
function Disclaimer(tlb)
    local dsc={"The Gathering Against ",{text="Goblin ",pen=dfhack.pen.parse{fg=COLOR_GREEN,bg=0}}, "Oppresion ",
        "(TGAGO) is not responsible for all ",NEWLINE,"the damage that this tool can (and will) cause to you and your loved worlds",NEWLINE,"and/or sanity.Please use with caution.",NEWLINE,{text="Magma not included.",pen=dfhack.pen.parse{fg=COLOR_LIGHTRED,bg=0}}}
    if tlb then
        for _,v in ipairs(dsc) do
            table.insert(tlb,v)
        end
    end
    return dsc
end
function showHelp()
    local helptext={
    "This tool allow you to perform jobs as a dwarf would in dwarf mode. When ",NEWLINE,
    "cursor is available you can press ",{key="SELECT", text="select",key_sep="()"},
    " to enqueue a job from",NEWLINE,"pointer location. If job is 'Build' and there is no planed construction",NEWLINE,
    "at cursor this tool show possible building choices.",NEWLINE,NEWLINE,{text="Keybindings:",pen=dfhack.pen.parse{fg=COLOR_CYAN,bg=0}},NEWLINE
    }
    for k,v in pairs(keybinds) do
        table.insert(helptext,{key=v.key,text=v.desc,key_sep=":"})
        table.insert(helptext,NEWLINE)
    end
    table.insert(helptext,{text="CAREFULL MOVE",pen=dfhack.pen.parse{fg=COLOR_LIGHTGREEN,bg=0}})
    table.insert(helptext,": use job in that direction")
    table.insert(helptext,NEWLINE)
    table.insert(helptext,NEWLINE)
    Disclaimer(helptext)
    require("gui.dialogs").showMessage("Help!?!",helptext)
end
function getLastJobLink()
    local st=df.global.world.job_list
    while st.next~=nil do
        st=st.next
    end
    return st
end
function AddNewJob(job)
    local nn=getLastJobLink()
    local nl=df.job_list_link:new()
    nl.prev=nn
    nn.next=nl
    nl.item=job
    job.list_link=nl
end
function MakeJob(unit,pos,job_type,unit_pos,post_actions)
    local nj=df.job:new()
    nj.id=df.global.job_next_id
    df.global.job_next_id=df.global.job_next_id+1
    --nj.flags.special=true
    nj.job_type=job_type
    nj.completion_timer=-1
    --nj.unk4a=12
    --nj.unk4b=0
    nj.pos:assign(pos)
    AssignUnitToJob(nj,unit,unit_pos)
    for k,v in ipairs(post_actions or {}) do
        v{job=nj,pos=pos,old_pos=unit_pos,unit=unit}
    end
    AddNewJob(nj)
    return nj
end

function AssignUnitToJob(job,unit,unit_pos)
    job.general_refs:insert("#",{new=df.general_ref_unit_workerst,unit_id=unit.id})
    unit.job.current_job=job
    unit_pos=unit_pos or {x=job.pos.x,y=job.pos.y,z=job.pos.z}
    unit.path.dest:assign(unit_pos)
end
function SetCreatureRef(args)
    local job=args.job
    local pos=args.pos
    for k,v in pairs(df.global.world.units.active) do
        if v.pos.x==pos.x and v.pos.y==pos.y and v.pos.z==pos.z then
            job.general_refs:insert("#",{new=df.general_ref_unit_cageest,unit_id=v.id})
            return
        end
    end
end

function SetPatientRef(args)
    local job=args.job
    local pos=args.pos
    for k,v in pairs(df.global.world.units.active) do
        if v.pos.x==pos.x and v.pos.y==pos.y and v.pos.z==pos.z then
            job.general_refs:insert("#",{new=df.general_ref_unit_patientst,unit_id=v.id})
            return
        end
    end
end

function MakePredicateWieldsItem(item_skill)
    local pred=function(args)
        local inv=args.unit.inventory
        for k,v in pairs(inv) do
            if v.mode==1 and df.item_weaponst:is_instance(v.item) then
                if v.item.subtype.skill_melee==item_skill then --and unit.body.weapon_bp==v.body_part_id
                    return true
                end
            end
        end
        return false,"Correct tool not equiped"
    end
    return pred
end
function makeset(args)
    local tbl={}
    for k,v in pairs(args) do
        tbl[v]=true
    end
    return tbl
end
function IsConstruct(args)
    local tt=dfhack.maps.getTileType(args.pos)
    local cwalls=makeset{  df.tiletype.ConstructedWallRD2, df.tiletype.ConstructedWallR2D, df.tiletype.ConstructedWallR2U, df.tiletype.ConstructedWallRU2,
  df.tiletype.ConstructedWallL2U, df.tiletype.ConstructedWallLU2, df.tiletype.ConstructedWallL2D, df.tiletype.ConstructedWallLD2,
  df.tiletype.ConstructedWallLRUD, df.tiletype.ConstructedWallRUD, df.tiletype.ConstructedWallLRD, df.tiletype.ConstructedWallLRU,
  df.tiletype.ConstructedWallLUD, df.tiletype.ConstructedWallRD, df.tiletype.ConstructedWallRU, df.tiletype.ConstructedWallLU,
  df.tiletype.ConstructedWallLD, df.tiletype.ConstructedWallUD, df.tiletype.ConstructedWallLR,}
    if cwalls[tt] or dfhack.buildings.findAtTile(args.pos) then
        return true
    else
        return false, "Can only do it on constructions"
    end
end
function IsWall(args)
    local tt=dfhack.maps.getTileType(args.pos)
    local walls=makeset{df.tiletype.StoneWallWorn1, df.tiletype.StoneWallWorn2, df.tiletype.StoneWallWorn3, df.tiletype.StoneWall,
  df.tiletype.SoilWall, df.tiletype.LavaWallSmoothRD2, df.tiletype.LavaWallSmoothR2D, df.tiletype.LavaWallSmoothR2U, df.tiletype.LavaWallSmoothRU2,
  df.tiletype.LavaWallSmoothL2U, df.tiletype.LavaWallSmoothLU2, df.tiletype.LavaWallSmoothL2D, df.tiletype.LavaWallSmoothLD2, df.tiletype.LavaWallSmoothLRUD,
  df.tiletype.LavaWallSmoothRUD, df.tiletype.LavaWallSmoothLRD, df.tiletype.LavaWallSmoothLRU, df.tiletype.LavaWallSmoothLUD, df.tiletype.LavaWallSmoothRD,
  df.tiletype.LavaWallSmoothRU, df.tiletype.LavaWallSmoothLU, df.tiletype.LavaWallSmoothLD, df.tiletype.LavaWallSmoothUD, df.tiletype.LavaWallSmoothLR,
  df.tiletype.FeatureWallSmoothRD2, df.tiletype.FeatureWallSmoothR2D, df.tiletype.FeatureWallSmoothR2U, df.tiletype.FeatureWallSmoothRU2,
  df.tiletype.FeatureWallSmoothL2U, df.tiletype.FeatureWallSmoothLU2, df.tiletype.FeatureWallSmoothL2D, df.tiletype.FeatureWallSmoothLD2,
  df.tiletype.FeatureWallSmoothLRUD, df.tiletype.FeatureWallSmoothRUD, df.tiletype.FeatureWallSmoothLRD, df.tiletype.FeatureWallSmoothLRU,
  df.tiletype.FeatureWallSmoothLUD, df.tiletype.FeatureWallSmoothRD, df.tiletype.FeatureWallSmoothRU, df.tiletype.FeatureWallSmoothLU,
  df.tiletype.FeatureWallSmoothLD, df.tiletype.FeatureWallSmoothUD, df.tiletype.FeatureWallSmoothLR, df.tiletype.StoneWallSmoothRD2,
  df.tiletype.StoneWallSmoothR2D, df.tiletype.StoneWallSmoothR2U, df.tiletype.StoneWallSmoothRU2, df.tiletype.StoneWallSmoothL2U,
  df.tiletype.StoneWallSmoothLU2, df.tiletype.StoneWallSmoothL2D, df.tiletype.StoneWallSmoothLD2, df.tiletype.StoneWallSmoothLRUD,
  df.tiletype.StoneWallSmoothRUD, df.tiletype.StoneWallSmoothLRD, df.tiletype.StoneWallSmoothLRU, df.tiletype.StoneWallSmoothLUD,
  df.tiletype.StoneWallSmoothRD, df.tiletype.StoneWallSmoothRU, df.tiletype.StoneWallSmoothLU, df.tiletype.StoneWallSmoothLD,
  df.tiletype.StoneWallSmoothUD, df.tiletype.StoneWallSmoothLR, df.tiletype.LavaWallWorn1, df.tiletype.LavaWallWorn2, df.tiletype.LavaWallWorn3,
  df.tiletype.LavaWall, df.tiletype.FeatureWallWorn1, df.tiletype.FeatureWallWorn2, df.tiletype.FeatureWallWorn3, df.tiletype.FeatureWall,
  df.tiletype.FrozenWallWorn1, df.tiletype.FrozenWallWorn2, df.tiletype.FrozenWallWorn3, df.tiletype.FrozenWall, df.tiletype.MineralWallSmoothRD2,
  df.tiletype.MineralWallSmoothR2D, df.tiletype.MineralWallSmoothR2U, df.tiletype.MineralWallSmoothRU2, df.tiletype.MineralWallSmoothL2U,
  df.tiletype.MineralWallSmoothLU2, df.tiletype.MineralWallSmoothL2D, df.tiletype.MineralWallSmoothLD2, df.tiletype.MineralWallSmoothLRUD,
  df.tiletype.MineralWallSmoothRUD, df.tiletype.MineralWallSmoothLRD, df.tiletype.MineralWallSmoothLRU, df.tiletype.MineralWallSmoothLUD,
  df.tiletype.MineralWallSmoothRD, df.tiletype.MineralWallSmoothRU, df.tiletype.MineralWallSmoothLU, df.tiletype.MineralWallSmoothLD,
  df.tiletype.MineralWallSmoothUD, df.tiletype.MineralWallSmoothLR, df.tiletype.MineralWallWorn1, df.tiletype.MineralWallWorn2,
  df.tiletype.MineralWallWorn3, df.tiletype.MineralWall, df.tiletype.FrozenWallSmoothRD2, df.tiletype.FrozenWallSmoothR2D,
  df.tiletype.FrozenWallSmoothR2U, df.tiletype.FrozenWallSmoothRU2, df.tiletype.FrozenWallSmoothL2U, df.tiletype.FrozenWallSmoothLU2,
  df.tiletype.FrozenWallSmoothL2D, df.tiletype.FrozenWallSmoothLD2, df.tiletype.FrozenWallSmoothLRUD, df.tiletype.FrozenWallSmoothRUD,
  df.tiletype.FrozenWallSmoothLRD, df.tiletype.FrozenWallSmoothLRU, df.tiletype.FrozenWallSmoothLUD, df.tiletype.FrozenWallSmoothRD,
  df.tiletype.FrozenWallSmoothRU, df.tiletype.FrozenWallSmoothLU, df.tiletype.FrozenWallSmoothLD, df.tiletype.FrozenWallSmoothUD,
  df.tiletype.FrozenWallSmoothLR,
  }
    if walls[tt] then
        return true
    else
        return false, "Can only do it on walls"
    end
end
function IsTree(args)
    local tt=dfhack.maps.getTileType(args.pos)
    if tt==24 then
        return true
    else
        return false, "Can only do it on trees"
    end
    
end
function IsWater(args)
    return true
end
function IsPlant(args)
    return true
end
function IsUnit(args)
    local pos=args.pos
    for k,v in pairs(df.global.world.units.active) do
        if v.pos.x==pos.x and v.pos.y==pos.y and v.pos.z==pos.z then
            return true
        end
    end
    return false,"Unit must be present"
end
function itemsAtPos(pos)
    local ret={}
    for k,v in pairs(df.global.world.items.all) do
        if v.pos.x==pos.x and v.pos.y==pos.y and v.pos.z==pos.z and v.flags.on_ground then
            table.insert(ret,v)
        end
    end
    return ret
end
function AssignBuildingRef(args)
    local bld=dfhack.buildings.findAtTile(args.pos)
    args.job.general_refs:insert("#",{new=df.general_ref_building_holderst,building_id=bld.id})
    bld.jobs:insert("#",args.job)
end
--[[ building submodule... ]]--
function DialogBuildingChoose(on_select, on_cancel)
    blist={}
    for i=df.building_type._first_item,df.building_type._last_item do
        table.insert(blist,df.building_type[i])
    end
    dialog.showListPrompt("Building list", "Choose building:", COLOR_WHITE, blist, on_select, on_cancel, nil, true)
end
function DialogSubtypeChoose(subtype,on_select, on_cancel)
    blist={}
    for i=subtype._first_item,subtype._last_item do
        table.insert(blist,subtype[i])
    end
    dialog.showListPrompt("Subtype", "Choose subtype:", COLOR_WHITE, blist, on_select, on_cancel, nil, true)
end
--workshop, furnaces, traps
invalid_buildings={}
function SubtypeChosen(args,index)
    args.subtype=index-1
    buildings.constructBuilding(args)
end
function BuildingChosen(st_pos,pos,index)
    local b_type=index-2
    local args={}
    args.type=b_type
    args.pos=pos
    args.items=itemsAtPos(st_pos)
    if invalid_buildings[b_type] then
        return 
    elseif b_type==df.building_type.Construction then
        DialogSubtypeChoose(df.construction_type,dfhack.curry(SubtypeChosen,args))
        return
    elseif b_type==df.building_type.Furnace then
        DialogSubtypeChoose(df.furnace_type,dfhack.curry(SubtypeChosen,args))
        return
    elseif b_type==df.building_type.Trap then
        DialogSubtypeChoose(df.trap_type,dfhack.curry(SubtypeChosen,args))
        return
    elseif b_type==df.building_type.Workshop then
        DialogSubtypeChoose(df.workshop_type,dfhack.curry(SubtypeChosen,args))
        return
    else
        buildings.constructBuilding(args)
    end
end

--[[ end of buildings ]]--
function AssignJobToBuild(args)
    local bld=dfhack.buildings.findAtTile(args.pos)
    if bld~=nil then
        if #bld.jobs>0 then
            AssignUnitToJob(bld.jobs[0],args.unit,args.old_pos)
        else
            local jb=MakeJob(args.unit,args.pos,df.job_type.ConstructBuilding,args.old_pos,{AssignBuildingRef})
            local its=itemsAtPos(args.old_pos)
            for k,v in pairs(its) do
                jb.items:insert("#",{new=true,item=v,role=2})
            end
            
        end
    else
        DialogBuildingChoose(dfhack.curry(BuildingChosen,args.old_pos,args.pos))
    end
end
function ContinueJob(unit)
    local c_job=unit.job.current_job 
    if c_job then
        for k,v in pairs(c_job.items) do
            if v.is_fetching==1 then
                unit.path.dest:assign(v.item.pos)
                return
            end
        end
        unit.path.dest:assign(c_job.pos)
    end
end

dig_modes={
    {"CarveFortification"   ,df.job_type.CarveFortification,{IsWall}},
    {"DetailWall"           ,df.job_type.DetailWall,{IsWall}},
    {"DetailFloor"          ,df.job_type.DetailFloor},
    --{"CarveTrack"          ,df.job_type.CarveTrack}, -- does not work??
    {"Dig"                  ,df.job_type.Dig,{MakePredicateWieldsItem(df.job_skill.MINING),IsWall}},
    {"CarveUpwardStaircase" ,df.job_type.CarveUpwardStaircase,{MakePredicateWieldsItem(df.job_skill.MINING),IsWall}},
    {"CarveDownwardStaircase",df.job_type.CarveDownwardStaircase,{MakePredicateWieldsItem(df.job_skill.MINING)}},
    {"CarveUpDownStaircase" ,df.job_type.CarveUpDownStaircase,{MakePredicateWieldsItem(df.job_skill.MINING)}},
    {"CarveRamp"            ,df.job_type.CarveRamp,{MakePredicateWieldsItem(df.job_skill.MINING),IsWall}},
    {"DigChannel"           ,df.job_type.DigChannel,{MakePredicateWieldsItem(df.job_skill.MINING)}},
    {"FellTree"             ,df.job_type.FellTree,{MakePredicateWieldsItem(df.job_skill.AXE),IsTree}},
    {"Fish"                 ,df.job_type.Fish,{IsWater}},
    --{"Diagnose Patient"     ,df.job_type.DiagnosePatient,{IsUnit},{SetPatientRef}},
    --{"Surgery"              ,df.job_type.Surgery,{IsUnit},{SetPatientRef}},
    --{"TameAnimal"           ,df.job_type.TameAnimal,{IsUnit},{SetCreatureRef}}, 
    {"GatherPlants"         ,df.job_type.GatherPlants,{IsPlant}},
    {"RemoveConstruction"   ,df.job_type.RemoveConstruction,{IsConstruct}},
    --{"HandleLargeCreature"   ,df.job_type.HandleLargeCreature,{isUnit},{SetCreatureRef}},
    {"Build"                ,AssignJobToBuild},
    
}


usetool=defclass(usetool,gui.Screen)
function usetool:getModeName()
    local adv=df.global.world.units.active[0]
    if adv.job.current_job then
        return string.format("%s working(%d) ",(dig_modes[(mode or 0)+1][1] or ""),adv.job.current_job.completion_timer)
    else
        return dig_modes[(mode or 0)+1][1] or " "
    end
    
end
function usetool:init(args)
    self:addviews{
        wid.Label{
            frame = {xalign=0,yalign=0},
            text={{key=keybinds.key_prev.key},{gap=1,text=dfhack.curry(usetool.getModeName,self)},{gap=1,key=keybinds.key_next.key}}
                  }
            }
end
function usetool:onRenderBody(dc)
    self._native.parent:logic()
    self:renderParent()
end
MOVEMENT_KEYS = {
    A_CARE_MOVE_N = { 0, -1, 0 }, A_CARE_MOVE_S = { 0, 1, 0 },
    A_CARE_MOVE_W = { -1, 0, 0 }, A_CARE_MOVE_E = { 1, 0, 0 },
    A_CARE_MOVE_NW = { -1, -1, 0 }, A_CARE_MOVE_NE = { 1, -1, 0 },
    A_CARE_MOVE_SW = { -1, 1, 0 }, A_CARE_MOVE_SE = { 1, 1, 0 },
    --[[A_MOVE_N = { 0, -1, 0 }, A_MOVE_S = { 0, 1, 0 },
    A_MOVE_W = { -1, 0, 0 }, A_MOVE_E = { 1, 0, 0 },
    A_MOVE_NW = { -1, -1, 0 }, A_MOVE_NE = { 1, -1, 0 },
    A_MOVE_SW = { -1, 1, 0 }, A_MOVE_SE = { 1, 1, 0 },--]]
    --[[CURSOR_UP_FAST = { 0, -1, 0, true }, CURSOR_DOWN_FAST = { 0, 1, 0, true },
    CURSOR_LEFT_FAST = { -1, 0, 0, true }, CURSOR_RIGHT_FAST = { 1, 0, 0, true },
    CURSOR_UPLEFT_FAST = { -1, -1, 0, true }, CURSOR_UPRIGHT_FAST = { 1, -1, 0, true },
    CURSOR_DOWNLEFT_FAST = { -1, 1, 0, true }, CURSOR_DOWNRIGHT_FAST = { 1, 1, 0, true },]]--
    A_CUSTOM_CTRL_D = { 0, 0, -1 },
    A_CUSTOM_CTRL_E = { 0, 0, 1 },
    CURSOR_UP_Z_AUX = { 0, 0, 1 }, CURSOR_DOWN_Z_AUX = { 0, 0, -1 },
    A_MOVE_SAME_SQUARE={0,0,0},
    SELECT={0,0,0},
}
function moddedpos(pos,delta)
    return {x=pos.x+delta[1],y=pos.y+delta[2],z=pos.z+delta[3]}
end
function usetool:onDismiss()
    local adv=df.global.world.units.active[0]
    --TODO: cancel job
    --[[if adv and adv.job.current_job then
        local cj=adv.job.current_job
        adv.jobs.current_job=nil
        cj:delete()
    end]]
end
function usetool:onHelp()
    showHelp()
end
function usetool:onInput(keys)

    if keys.LEAVESCREEN  then
        self:dismiss()
    elseif keys[keybinds.key_next.key] then
        mode=(mode+1)%#dig_modes
    elseif keys[keybinds.key_prev.key] then
        mode=mode-1
        if mode<0 then mode=#dig_modes-1 end
    --elseif keys.A_LOOK then
    --    self:sendInputToParent("A_LOOK")
    elseif keys[keybinds.key_continue.key] then
        ContinueJob(df.global.world.units.active[0])
        self:sendInputToParent("A_WAIT")
    else
        local adv=df.global.world.units.active[0]
        local cur_mode=dig_modes[(mode or 0)+1]
        local failed=false
        for code,_ in pairs(keys) do
            --print(code)
            if MOVEMENT_KEYS[code] then
                local state={unit=adv,pos=moddedpos(adv.pos,MOVEMENT_KEYS[code]),dir=MOVEMENT_KEYS[code],
                        old_pos={x=adv.pos.x,y=adv.pos.y, z=adv.pos.z}}
                if code=="SELECT" then
                    if df.global.cursor.x~=-30000 then
                        state.pos={x=df.global.cursor.x,y=df.global.cursor.y,z=df.global.cursor.z}
                    else
                        break
                    end
                end
               
                for _,p in pairs(cur_mode[3] or {}) do
                    local t,v=p(state)
                    if t==false then
                        dfhack.gui.showAnnouncement(v,5,1)
                        failed=true
                    end
                end
                if not failed then
                    if type(cur_mode[2])=="function" then
                        cur_mode[2](state)
                    else
                        MakeJob(adv,moddedpos(adv.pos,MOVEMENT_KEYS[code]),cur_mode[2],adv.pos,cur_mode[4])
                    end
                    
                    if code=="SELECT" then
                        self:sendInputToParent("LEAVESCREEN")
                    end
                    
                    self:sendInputToParent("A_WAIT")
                    
                end
                return code
            end
            if code~="_STRING" and code~="_MOUSE_L" and code~="_MOUSE_R" then
                self:sendInputToParent(code)
            end
        end
    end
end
usetool():show()