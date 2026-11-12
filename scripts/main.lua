require "QDAPHelpers"
require "QDItems"
require "QDLocations"
local UEHelpers = require("UEHelpers")

-- Importing functions to the global namespace of this mod just so that we don't have to retype 'UEHelpers.' over and over again.
local GetKismetMathLibrary = UEHelpers.GetKismetMathLibrary
local GetKismetSystemLibrary = UEHelpers.GetKismetSystemLibrary
local GetGameplayStatics = UEHelpers.GetGameplayStatics
local GetWorldContextObject = UEHelpers.GetWorldContextObject
local GetPlayer = UEHelpers.GetPlayer

local game_instance
local last_checkpoint

local items_to_give = {}
giving_items = false

-------- MAIN FUNCTION --------

if not ClientRestartPreId then
    ClientRestartPreId, ClientRestartPostId = RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(Context, DialoguePickup)
        if GetPlayer():IsValid() then
            PlayerBeginPlayPreId, PlayerBeginPlayPostId = RegisterHook("/Game/Player/FS_PlayerChar.FS_PlayerChar_C:ReceiveBeginPlay", function(Context, DialoguePickup)
                register_hooks()
                get_nearest_save_point()
            end)
            --- TODO register a hook for unregister_hooks on some sort of destructor
            UnregisterHook("/Script/Engine.PlayerController:ClientRestart", ClientRestartPreId, ClientRestartPostId)
        end

        RegisterConsoleCommandHandler("AP_gimme", function(FullCommand, Parameters, Ar)
            if #Parameters ~= 1 then return false end
            if Parameters[1] == "all" then
                queue_items_from_table(ALL_ITEMS)
            else if Parameters[1] == "stackable" then
                queue_items_from_table(STACKABLE_ITEMS)
            else if Parameters[1] == "pedestal" then
                queue_items_from_table(PEDESTAL_ITEMS)
            else if Parameters[1] == "broken" then
                queue_items_from_table(BROKEN_ITEMS)
            else if Parameters[1] == "excluded" then
                queue_items_from_table(EXCLUDED_ITEMS)
            end end end end end
            return true
        end)

        RegisterConsoleCommandHandler("AP_reload", function(FullCommand, Parameters, Ar)
            register_hooks()
        end)
    end)
end

ap_print_local("Mod Loaded!\n")

-------- END MAIN FUNCTION --------

function register_hooks()
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

function get_nearest_save_point()
    local checkpoints = FindAllOf("Checkpoint_C")
    local player = GetPlayer()
    local smallest_distance = player:GetDistanceTo(checkpoints[1])
    local last_checkpoint = checkpoints[1]
    for i, curr_checkpoint in pairs(checkpoints) do
        local curr_distance = player:GetDistanceTo(curr_checkpoint)
        if curr_distance < smallest_distance then
            smallest_distance = curr_distance
            last_checkpoint = curr_checkpoint
        end
    end
end

    

function check_named_location(full_name)
    ap_print_local(string.format("CHECK NAMED LOCATION %s\n", full_name))
    if last_checkpoint then
        last_checkpoint:Save()
    end
end

function queue_item(item_path)
    items_to_give[#items_to_give + 1] = item_path
    ap_print_local(string.format("item queued to items_to_give[%d]: %s", #items_to_give, item_path))
    if not giving_items then
        giving_items = true
        --- TODO see if you can get this queueing hook stuff to be based on time dilation in some way
        EndPickupPreId, EndPickupPostId = RegisterHook("/Game/Blueprints/FS_GameInstance.FS_GameInstance_C:GI_NotifyItemPutAway", function(Context)
            if curr_item_type == ITEM_TYPE_PEDESTAL then
                spawned_pickup.SetLifeSpan(0.5)
            end
            if #items_to_give > 0 then
                spawn_and_pickup_next_item()
            else
                giving_items = false
                items_to_give = {}
                UnregisterHook("/Game/Blueprints/FS_GameInstance.FS_GameInstance_C:GI_NotifyItemPutAway", EndPickupPreId, EndPickupPostId)
            end
        end)
        spawn_and_pickup_next_item()
    end
end


--- TODO:
function spawn_and_pickup_next_item()
    curr_item_type = ITEM_TYPE_DEFAULT
    if table_contains(PEDESTAL_ITEMS, items_to_give[1]) then
        curr_item_type = ITEM_TYPE_PEDESTAL
    end

    local gameplay_statics = GetGameplayStatics()
    local pickup_to_spawn = StaticFindObject(items_to_give[1])
    ap_print_local(string.format("attempting to spawn %s\n", pickup_to_spawn:GetFullName()))

    for i, item_to_shift in pairs(items_to_give) do
        if i ~= 1 then
            items_to_give[i-1] = item_to_shift
        end
    end
    items_to_give[#items_to_give] = nil

    if pickup_to_spawn ~= nil then

        local player = FindFirstOf("FS_PlayerChar_C")
        local camera = player.FirstPersonCamera
        local kismet_math = GetKismetMathLibrary()
        local location
        local rotation

        if curr_item_type == ITEM_TYPE_PEDESTAL then
            location = kismet_math.MakeVector(-5000.0, -5000.0, -25000.0)
            rotation = kismet_math.MakeVector(0.0, 0.0, 0.0)
        else
            location = kismet_math.TransformLocation(camera.K2_GetComponentToWorld(), kismet_math.MakeVector(50.0, 0.0, -100.0))
            rotation = camera.K2_GetComponentRotation()
        end

        ap_print_local("spawning item!")
        spawned_pickup = GetWorldContextObject():SpawnActor(pickup_to_spawn, location, rotation)

        spawned_pickup.Interact(GetWorldContextObject(), player)
    else
        ap_print_local("failed to spawn item!")
        spawn_and_pickup_next_item()
    end
end

function queue_items_from_table(item_table)
    for i, item in pairs(item_table) do
        queue_item(item)
    end
end

function table_contains(tbl, x)
    found = false
    for _, v in pairs(tbl) do
        if v == x then
            found = true
        end
    end
    return found
end