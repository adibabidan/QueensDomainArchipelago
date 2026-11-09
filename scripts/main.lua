require "APHelpers"

local game_instance
local last_checkpoint
local ClientRestartPreId, ClientRestartPostId
local ItemInteractPreId, ItemInteractPostId
local PedestalInteractPreId, PedestalInteractPostId
local CheckpointSavePreId, CheckpointSavePostId

function setup_hooks()
    game_instance = FindFirstOf("FS_GameInstance_C")
    ap_print_local(string.format("game_instance: %s", game_instance:GetFullName()))

    --- works with: dried herbs (1), elixer (1), meal tickets [doesn't], knife belt
    if not ItemInteractPreId then
        ItemInteractPreId, ItemInteractPostId = RegisterHook("/Game/Blueprints/ItemPickup_Base.ItemPickup_Base_C:Interact", function(Context, DialoguePickup)
            local curr_pickup = Context:get()
            ap_print_local(string.format("PICKUP BASE CLASS interacted with %s\n", curr_pickup:GetFullName()))
            check_named_location(curr_pickup:GetFullName())
        end)
    end

    if not PedestalInteractPreId then
        PedestalInteractPreId, PedestalInteractPostId = RegisterHook("/Game/Items/Upgrades/SharedContent/Food_Pedestal_Base.Food_Pedestal_Base_C:Interact", function(Context, DialoguePickup)
            local curr_pickup = Context:get()
            ap_print_local(string.format("FOOD PEDESTAL interacted with %s\n", curr_pickup:GetFullName()))
            check_named_location(curr_pickup:GetFullName())
        end)
    end

    if not CheckpointSavePreId then
        CheckpointSavePreId, CheckpointSavePostId = RegisterHook("/Game/LD45/Blueprints/Checkpoint/Checkpoint.Checkpoint_C:Save", function(Context)
            last_checkpoint = Context:get()
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

-------- MAIN FUNCTION --------

if not ClientRestartPreId then
    ClientRestartPreId, ClientRestartPostId = RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(Context, DialoguePickup)
        setup_hooks()
    end)
end

ap_print_local("Mod Loaded!\n")

-------- END MAIN FUNCTION --------