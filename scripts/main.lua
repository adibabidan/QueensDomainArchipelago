require "APHelpers"
local UEHelpers = require("UEHelpers")

-- Importing functions to the global namespace of this mod just so that we don't have to retype 'UEHelpers.' over and over again.
local GetKismetMathLibrary = UEHelpers.GetKismetMathLibrary
local GetGameplayStatics = UEHelpers.GetGameplayStatics
local GetWorldContextObject = UEHelpers.GetWorldContextObject
local GetPlayer = UEHelpers.GetPlayer

local game_instance
local last_checkpoint
local ClientRestartPreId, ClientRestartPostId
local LoadSavePreId, LoadSavePostId
local ItemInteractPreId, ItemInteractPostId
local PedestalInteractPreId, PedestalInteractPostId
local CheckpointSavePreId, CheckpointSavePostId

local items_to_give = {}
giving_items = false

function setup_hooks()
    
    queue_give_item("/Game/Items/KeyItems/KnifeBelt/KnifeBelt_KeyItem.KnifeBelt_KeyItem")
    queue_give_item("/Game/Items/Weapons/Daggers/SuperCube/SuperCube.SuperCube")
    queue_give_item("/Game/Items/Weapons/Daggers/SuperCube/SuperCube.SuperCube")
    queue_give_item("/Game/Items/Weapons/Daggers/SuperCube/SuperCube.SuperCube")
    queue_give_item("/Game/Items/Weapons/Daggers/SuperCube/SuperCube.SuperCube")
    queue_give_item("/Game/Items/Weapons/Daggers/SuperCube/SuperCube.SuperCube")
    queue_give_item("/Game/Items/Weapons/Daggers/SuperCube/SuperCube.SuperCube")
    queue_give_item("/Game/Items/Weapons/Daggers/SuperCube/SuperCube.SuperCube")
    ---grimoire.BeginSequentialItemGrants()

    ---TODO
    ---if not LoadSavePreId then
    ---    LoadSavePreId, LoadSavePostId = RegisterHook("/Game/UI/Menus/SaveMenu/SaveSlotWidget.SaveSlotWidget_C:BndEvt__SaveSlotWidget_FS_Button_K2Node_ComponentBoundEvent_0_CommonButtonBaseClicked__DelegateSignature", function(Context, Button)
    ---        TODO either load serialized last_checkpoint or use a dictionary to get the save point from the actual save point location name
    ---    end)
    ---end

    --- works with: dried herbs (1), elixer (1), meal tickets [created at runtime, no consistent name], knife belt
    if not ItemInteractPreId then
        ItemInteractPreId, ItemInteractPostId = RegisterHook("/Game/Blueprints/ItemPickup_Base.ItemPickup_Base_C:Interact", function(Context, DialoguePickup)
            local curr_pickup = Context:get()
            ap_print_local(string.format("PICKUP BASE CLASS interacted with %s\n", curr_pickup:GetFullName()))
            check_named_location(curr_pickup:GetFullName())
        end)
    end

    --- works with: fish pedestal
    if not PedestalInteractPreId then
        PedestalInteractPreId, PedestalInteractPostId = RegisterHook("/Game/Items/Upgrades/SharedContent/Food_Pedestal_Base.Food_Pedestal_Base_C:Interact", function(Context, DialoguePickup)
            local curr_pickup = Context:get()
            ap_print_local(string.format("FOOD PEDESTAL interacted with %s\n", curr_pickup:GetFullName()))
            check_named_location(curr_pickup:GetFullName())
        end)
    end

    if not CheckpointSavePreId then
        CheckpointSavePreId, CheckpointSavePostId = RegisterHook("/Game/LD45/Blueprints/Checkpoint/Checkpoint.Checkpoint_C:Save", function(Context)
            new_checkpoint = Context:get()
            if last_checkpoint ~= new_checkpoint then
                last_checkpoint = new_checkpoint
                -- TODO maybe serialize last_checkpoint somehow?
            end
            ap_print_local(string.format("GAME SAVED AT %s\n", last_checkpoint:GetFullName()))
        end)
    end
end

function check_named_location(full_name)
    ap_print_local(string.format("CHECK NAMED LOCATION %s\n", full_name))
    if last_checkpoint then
        last_checkpoint:Save()
    end
end

function get_transform_for_item_spawn()
    local player = FindFirstOf("FS_PlayerChar_C")
    local camera = player.FirstPersonCamera
    local rotation = camera.K2_GetComponentRotation()
    local kismet_math = GetKismetMathLibrary()
    local location = kismet_math.TransformLocation(camera.K2_GetComponentToWorld(), kismet_math.MakeVector(50.0, 0.0, 100.0))
    return kismet_math.MakeTransform(location, rotation, kismet_math.MakeVector(1.0, 1.0, 1.0))
end

function queue_give_item(item_path)
    items_to_give[#items_to_give + 1] = item_path
    if not giving_items then
        giving_items = true
        EndPickupPreId, EndPickupPostId = RegisterHook("/Game/Blueprints/FS_GameInstance.FS_GameInstance_C:GI_NotifyItemPutAway", function(Context)
            if #items_to_give > 0 then
                spawn_and_pickup_next_item()
            else
                giving_items = false
                UnregisterHook("/Game/Blueprints/FS_GameInstance.FS_GameInstance_C:GI_NotifyItemPutAway", EndPickupPreId, EndPickupPostId)
            end
        end)
        spawn_and_pickup_next_item(item_path)
    end
end

function spawn_and_pickup_next_item()
    if #items_to_give > 0 then
        local gameplay_statics = GetGameplayStatics()
        local item_data = StaticFindObject(items_to_give[1])
        ap_print_local(string.format("attempting to spawn %s\n", item_data:GetFullName()))

        for i= 1, #items_to_give-1 do
            items_to_give[i] = items_to_give[i+1]
        end
        items_to_give[#items_to_give] = nil

        local player = FindFirstOf("FS_PlayerChar_C")
        local camera = player.FirstPersonCamera
        local rotation = camera.K2_GetComponentRotation()
        local kismet_math = GetKismetMathLibrary()
        local location = kismet_math.TransformLocation(camera.K2_GetComponentToWorld(), kismet_math.MakeVector(50.0, 0.0, -100.0))
        local item_to_spawn = nil
        ---if item_data['Pickup BP'] then
        ---    print("pickup")
        ---    item_to_spawn = item_data['Pickup BP']
        ---else
        ---    if item_data['Drop BP / Fallback Visual BP'] then
        item_to_spawn = item_data['Drop BP / Fallback Visual BP']
        ---    end
        ---end
        ---if item_to_spawn ~= nil then
        ---    ap_print_local(string.format("item_to_spawn: %s\n", item_to_spawn:GetFullName()))
        spawned_item = GetWorldContextObject():SpawnActor(item_to_spawn, location, rotation)
        ap_print_local(string.format("spawned_item: %s\n", spawned_item:GetFullName()))
        spawned_item.Pickup(false)
        ---else
        ---    ap_print_local("failed to spawn item! no pickup nor fallback BP")
        ---    spawn_and_pickup_next_item()
        ---end
    else
        giving_items = false
        UnregisterHook("/Game/Blueprints/FS_GameInstance.FS_GameInstance_C:GI_NotifyItemPutAway", EndPickupPreId, EndPickupPostId)
    end
end
-------- MAIN FUNCTION --------

setup_hooks()

if not ClientRestartPreId then
    ClientRestartPreId, ClientRestartPostId = RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(Context, DialoguePickup)
        setup_hooks()
    end)
end



ap_print_local("Mod Loaded!\n")

-------- END MAIN FUNCTION --------