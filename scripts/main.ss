import "core:core.ss"

import "other_script.ss"

white_sprite:    Texture_Asset;
modal_bg_sprite: Texture_Asset;
button_green:    Texture_Asset;
button_red:      Texture_Asset;
button_orange:   Texture_Asset;
tutorial_arrow:  Texture_Asset;

dust_spine: Spine_Asset;

keybind_dodge_roll: Keybind;
keybind_drop_fuel: Keybind;
keybind_sprint: Keybind;

Game_State :: enum {
    RESET_MAP;
    WAITING_FOR_PLAYERS;
    GAMEPLAY;
    END_GAME_SCREEN;
}

Player_Team :: enum {
    SURVIVOR;
    ZOMBIE;
    SPECTATOR;
}

all_zombie_spawns: List(Entity);

g_game: struct {
    state: Game_State;

    tasks: [4]Task;
    current_task: Task;
    current_task_index: int;

    winner: Player_Team;
    end_game_screen_timer: float;

    fuel_deposited: int;
    beacons_restored: int;

    player_count_last_frame: int;
    round_countdown_timer: float;
};

complete_current_task :: proc() {
    g_game.current_task_index += 1;
    if g_game.current_task_index < g_game.tasks.count {
        g_game.current_task = g_game.tasks[g_game.current_task_index];
    }
    else {
        g_game.current_task = .NONE;
    }
}

server_rng: u64;

ROUND_COUNTDOWN_TIMER                           :: 10;
ROUND_COUNTDOWN_TIMER_WHEN_PLAYER_COUNT_CHANGES :: 5;

MAX_AMMO        :: 3;
AMMO_PER_SECOND :: 0.5;

g_game_manager: Game_Manager;

ao_before_scene_load :: proc() {
    white_sprite    = get_asset(Texture_Asset, "$AO/white.png");
    modal_bg_sprite = get_asset(Texture_Asset, "ui/modal_simple_white1.png");
    button_green    = get_asset(Texture_Asset, "ui/button_large_green1.png");
    button_red      = get_asset(Texture_Asset, "ui/button_large_red1.png");
    button_orange   = get_asset(Texture_Asset, "ui/button_large_yellow2.png");
    tutorial_arrow  = get_asset(Texture_Asset, "arrow.png");

    dust_spine      = get_asset(Spine_Asset, "rigs/dust_running_spine/dust_running.spine");

    Economy.register_currency("Food", "icons/burger.png");
    Economy.register_currency("Coins", "icons/coin.png");

    keybind_dodge_roll = Keybinds.register("Roll", .SPACE);
    keybind_drop_fuel = Keybinds.register("Drop Fuel", .F);
    keybind_sprint = Keybinds.register("Sprint", .LEFT_SHIFT);

    server_rng = rng_seed((get_real_time() * 1000000000).(u64));
}

Zombie_Spawn_Point :: class : Component { }

ao_start :: proc() {
    foreach spawn: component_iterator(Zombie_Spawn_Point) {
        all_zombie_spawns->append(spawn.entity);
    }
    foreach spawn: component_iterator(Fuel_Spawn_Point) {
        spawn.entity->get_component(Sprite_Renderer).enabled = false;
    }
    foreach spawn: component_iterator(Beacon_Spawn_Point) {
        spawn.entity->get_component(Sprite_Renderer).enabled = false;
    }
}

draw_big_game_text :: proc(str: string, args: [^]any = .{}) {
    ts := UI.default_text_settings();
    ts.size = 64;
    text_rect := UI.get_screen_rect()->bottom_center_rect()->offset(0, 150);
    UI.text(text_rect, ts, str, args);
}

draw_small_game_text :: proc(str: string, args: [^]any = .{}) {
    ts := UI.default_text_settings();
    ts.size = 48;
    text_rect := UI.get_screen_rect()->bottom_center_rect()->offset(0, 75);
    UI.text(text_rect, ts, str, args);
}

begin_task_ui :: proc() -> Rect {
    return UI.get_safe_screen_rect()->left_center_rect()->offset(20, 25);
}

draw_task_title :: proc(rect: ref Rect, str: string, args: [^]any = .{}) {
    ts := UI.default_text_settings();
    ts.size = 48;
    ts.halign = .LEFT;
    ts.valign = .CENTER;
    text_rect := rect->cut_top(50);
    UI.text(text_rect, ts, str, args);
}

draw_task_subtitle :: proc(rect: ref Rect, str: string, args: [^]any = .{}) {
    ts := UI.default_text_settings();
    ts.size = 36;
    ts.halign = .LEFT;
    ts.valign = .CENTER;
    text_rect := rect->cut_top(35);
    UI.text(text_rect, ts, str, args);
}

rotate_about_point :: proc(point: v2, degrees: float) -> Matrix4 {
    return Matrix4.translate(point)->multiply(Matrix4.rotate(degrees, .{0, 0, 1})->multiply(Matrix4.translate(-point)));
}

Tutorial_Arrow_Options :: struct {
    inv_alpha_multiplier: float;
    far: bool;
    near: bool;
}

default_tutorial_arrow_options :: proc() -> Tutorial_Arrow_Options {
    result: Tutorial_Arrow_Options;
    result.far  = true;
    result.near = true;
    return result;
}

draw_tutorial_arrow :: proc(player: Player, target_position: v2, options: Tutorial_Arrow_Options) {
    UI.push_world_draw_context();
    defer UI.pop_draw_context();

    UI.push_layer(100);
    defer UI.pop_layer();

    max_distance := player.camera.size * 0.8;
    offset_to_target := normalize_vector_to_radius(target_position - player.entity.world_position, max_distance) * max_distance;
    arrow_position := player.entity.world_position + offset_to_target;
    arrow_rect := Rect.{arrow_position, arrow_position}->grow(0.5);

    aim_d := dot(player.last_aim_direction, normalize(target_position - player.entity.world_position));
    alpha_t := linear_step(0.85, 1.0, aim_d);
    alpha := lerp(1.0, 0.25, alpha_t);
    alpha *= 1 - options.inv_alpha_multiplier;

    UI.push_color_multiplier(.{1, 1, 1, alpha});
    defer UI.pop_color_multiplier();

    if length_squared(arrow_position - target_position) > 0.1 {
        if options.far {
            dir := normalize(offset_to_target);
            rads := atan2(dir.y, dir.x);
            UI.push_matrix(rotate_about_point(arrow_rect->center(), to_degrees(rads)));
            defer UI.pop_matrix();
            UI.quad(arrow_rect, tutorial_arrow);
        }
    }
    else {
        if options.near {
            y := sin(2 * PI * get_time()) * 0.25;
            arrow_rect = arrow_rect->offset(0, 1.5 + y);
            UI.push_matrix(rotate_about_point(arrow_rect->center(), 270));
            defer UI.pop_matrix();
            UI.quad(arrow_rect, tutorial_arrow);
        }
    }
}

draw_rect_grow_fade_out_effect :: proc(rect: Rect, time: float, color: v4) {
    effect_t := Ease.out_quart(Ease.T(time, 0.35));
    if effect_t >= 1 return;
    growth := min(rect->width() * 0.5, rect->height() * 0.5) * effect_t;
    effect_rect := rect->grow_unscaled(growth, growth, growth, growth);
    color.w = 1 - effect_t;
    UI.quad(effect_rect, white_sprite, color);
}

ao_update :: proc(dt: float) {
    switch g_game.state {
        case .RESET_MAP: {
            foreach player: component_iterator(Player) {
                player->end_controller(true);
                player->remove_ghost_reason("spectator");
                player.team = .SURVIVOR;
                respawn_player(player);
            }
            foreach takeoff: component_iterator(Takeoff_Station) {
                takeoff.initiated = false;
            }
            foreach takeoff: component_iterator(Align_Takeoff_Station) {
                takeoff.is_aligned = false;
                takeoff.locked_in = false;
            }
            {
                // Destroy any existing spawned canisters
                foreach fuel: component_iterator(Fuel_Canister) {
                    destroy_entity(fuel.entity);
                }

                // Count available spawn points
                spawn_point_count := 0;
                foreach spawn_point: component_iterator(Fuel_Spawn_Point) {
                    spawn_point_count += 1;
                }

                // Collect all spawn points into an array
                spawn_points := new(Fuel_Spawn_Point, spawn_point_count);
                spawn_index := 0;
                foreach spawn_point: component_iterator(Fuel_Spawn_Point) {
                    spawn_points[spawn_index] = spawn_point;
                    spawn_index += 1;
                }

                // Fisher-Yates shuffle to randomize spawn points
                for i: 0..spawn_point_count-1 {
                    j := rng_range_int(&server_rng, 0, spawn_point_count-1);
                    temp := spawn_points[i];
                    spawn_points[i] = spawn_points[j];
                    spawn_points[j] = temp;
                }

                // Spawn canisters at the first REQUIRED_FUEL_CANISTERS spawn points
                canisters_to_spawn := min(REQUIRED_FUEL_CANISTERS, spawn_point_count);
                canister_prefab := get_asset(Prefab_Asset, "fuel_canister.prefab");
                for i: 0..canisters_to_spawn-1 {
                    spawn_point := spawn_points[i];
                    canister_entity := instantiate(canister_prefab);
                    canister_entity->set_local_position(spawn_point.entity.world_position);
                }
            }
            {
                // Destroy any existing spawned beacons
                foreach beacon: component_iterator(Beacon) {
                    destroy_entity(beacon.entity);
                }

                // Count available beacon spawn points
                beacon_spawn_count := 0;
                foreach spawn_point: component_iterator(Beacon_Spawn_Point) {
                    beacon_spawn_count += 1;
                }

                // Collect all spawn points into an array
                beacon_spawns := new(Beacon_Spawn_Point, beacon_spawn_count);
                beacon_index := 0;
                foreach spawn_point: component_iterator(Beacon_Spawn_Point) {
                    beacon_spawns[beacon_index] = spawn_point;
                    beacon_index += 1;
                }

                // Fisher-Yates shuffle to randomize spawn points
                for i: 0..beacon_spawn_count-1 {
                    j := rng_range_int(&server_rng, 0, beacon_spawn_count-1);
                    temp := beacon_spawns[i];
                    beacon_spawns[i] = beacon_spawns[j];
                    beacon_spawns[j] = temp;
                }

                // Spawn beacons at the first REQUIRED_BEACONS spawn points
                beacons_to_spawn := min(REQUIRED_BEACONS, beacon_spawn_count);
                beacon_prefab := get_asset(Prefab_Asset, "Beacon Task.prefab");
                for i: 0..beacons_to_spawn-1 {
                    spawn_point := beacon_spawns[i];
                    beacon_entity := instantiate(beacon_prefab);
                    beacon_entity->set_local_position(spawn_point.entity.world_position);
                }
            }
            g_game.state = .WAITING_FOR_PLAYERS;
        }
        case .WAITING_FOR_PLAYERS: {
            player_count := 0;
            foreach player: component_iterator(Player) {
                player_count += 1;
            }
            defer g_game.player_count_last_frame = player_count;

            REQUIRED_PLAYERS :: 3;
            if player_count < REQUIRED_PLAYERS {
                draw_big_game_text("Waiting for players...");
                draw_small_game_text("% / %", .{player_count, REQUIRED_PLAYERS});
            }
            else {
                if g_game.player_count_last_frame < REQUIRED_PLAYERS {
                    g_game.round_countdown_timer = ROUND_COUNTDOWN_TIMER.(float);
                    if Game.is_launched_from_editor() {
                        g_game.round_countdown_timer = 1;
                    }
                }
                else {
                    if g_game.player_count_last_frame != player_count {
                        g_game.round_countdown_timer = max(g_game.round_countdown_timer, ROUND_COUNTDOWN_TIMER_WHEN_PLAYER_COUNT_CHANGES.(float));
                    }
                }
                g_game.round_countdown_timer -= dt;

                draw_big_game_text("Starting round in %s...", .{g_game.round_countdown_timer.(int) + 1});
                draw_small_game_text("% players", .{player_count});

                if g_game.round_countdown_timer <= 0 {
                    g_game.round_countdown_timer = 0;
                    players := new(Player, player_count);
                    player_index := 0;
                    foreach player: component_iterator(Player) {
                        players[player_index] = player;
                        player_index += 1;
                        player.team = .SURVIVOR;
                    }

                    first_zombie := rng_range_int(&server_rng, 0, player_count-1);
                    players[first_zombie].team = .ZOMBIE;
                    g_game.state = .GAMEPLAY;

                    for i: 0..players.count-1 {
                        player := players[i];
                        respawn_player(player);
                    }

                    g_game.tasks[0] = .FUEL_CANISTERS;
                    g_game.tasks[1] = .RESTORE_BEACONS;
                    g_game.tasks[2] = .ALIGN_TAKEOFF;
                    g_game.tasks[3] = .TAKEOFF;
                    g_game.current_task_index = 0;
                    g_game.current_task = g_game.tasks[g_game.current_task_index];
                }
            }
        }
        case .GAMEPLAY: {
            survivors_left := 0;
            foreach player: component_iterator(Player) {
                if player.team == .SURVIVOR && player.health.is_dead == false {
                    survivors_left += 1;
                }
            }

            end_game :: proc(winner: Player_Team) {
                g_game.winner = winner;
                g_game.state = .END_GAME_SCREEN;
                foreach player: component_iterator(Player) {
                    if player.team == winner {
                        if player.team == .SURVIVOR {
                            player->add_notification("Survivors win!");
                        }
                        else {
                            player->add_notification("Zombies win!");
                        }
                    }
                    else {
                        if player.team == .SURVIVOR {
                            player->add_notification("Survivors lose!");
                        }
                        else {
                            player->add_notification("Zombies lose!");
                        }
                    }
                }
            }

            switch {
                case survivors_left == 0: {
                    end_game(.ZOMBIE);
                }
                case g_game.current_task_index >= g_game.tasks.count: {
                    end_game(.SURVIVOR);
                }
                case: {
                    local_player := Game.try_get_local_player();

                    // Draw current task objective
                    switch g_game.current_task {
                        case .FUEL_CANISTERS: {
                            rect := begin_task_ui();
                            draw_task_title(&rect, "Collect Fuel Canisters");
                            draw_task_subtitle(&rect, "Fuel: % / %", .{g_game.fuel_deposited, REQUIRED_FUEL_CANISTERS});
                        }
                        case .RESTORE_BEACONS: {
                            rect := begin_task_ui();
                            draw_task_title(&rect, "Restore Beacons");
                            draw_task_subtitle(&rect, "Beacons: % / %", .{g_game.beacons_restored, REQUIRED_BEACONS});
                        }
                        case .ALIGN_TAKEOFF: {
                            rect := begin_task_ui();
                            draw_task_title(&rect, "Align Ship Systems");
                            yaw_aligned   := " ";
                            pitch_aligned := " ";
                            foreach align: component_iterator(Align_Takeoff_Station) {
                                switch align.axis {
                                    case .Yaw:   if align.is_aligned { yaw_aligned   = "X"; }
                                    case .Pitch: if align.is_aligned { pitch_aligned = "X"; }
                                }
                            }
                            draw_task_subtitle(&rect, "[%] Yaw aligned",   .{yaw_aligned});
                            draw_task_subtitle(&rect, "[%] Pitch aligned", .{pitch_aligned});
                        }
                        case .TAKEOFF: {
                            takeoff: Takeoff_Station;
                            foreach c: component_iterator(Takeoff_Station) {
                                takeoff = c;
                                break;
                            }

                            rect := begin_task_ui();
                            draw_task_title(&rect, "Take off!");
                            x := " ";
                            if takeoff.initiated {
                                x = "X";
                            }
                            draw_task_subtitle(&rect, "[%] Takeoff initiated", .{x});
                            if takeoff.initiated {
                                draw_small_game_text("Takeoff in %{.1} seconds...", .{takeoff.takeoff_timer});
                            }
                        }
                    }
                }
            }
        }
        case .END_GAME_SCREEN: {
            g_game.end_game_screen_timer += dt;
            maybe_local := Game.try_get_local_player();
            if maybe_local != null && maybe_local.team != .SPECTATOR {
                UI.push_layer(-1000);
                defer UI.pop_layer();
                if maybe_local.team != g_game.winner {
                    UI.quad(UI.get_screen_rect(), white_sprite, .{1, 0, 0, 0.1});
                }
                else {
                    UI.quad(UI.get_screen_rect(), white_sprite, .{0, 1, 0, 0.1});
                }
            }

            if g_game.end_game_screen_timer >= 5.0 {
                g_game = .{};
            }
        }
    }
}

respawn_player :: proc(using player: Player) {
    player->end_controller(true);
    player.health->set_max_health(1, true);

    switch team {
        case .SURVIVOR: {
            offset := v2.{rng_range_float(&server_rng, -3.5, 3.5), rng_range_float(&server_rng, -2, 2)};
            player.entity->set_local_position(g_game_manager.survivor_spawn.world_position + offset);
        }
        case .ZOMBIE: {
            valid_spawns: List(Entity);
            for i: 0..all_zombie_spawns.elements.count-1 {
                spawn := all_zombie_spawns.elements[i];
                spawn_ok := true;
                foreach player: component_iterator(Player) if player.team == .SURVIVOR {
                    if in_range(spawn.world_position - player.entity.world_position, 10) {
                        spawn_ok = false;
                        break;
                    }
                }
                if spawn_ok {
                    valid_spawns->append(spawn);
                }
            }

            if valid_spawns.elements.count > 0 {
                index := rng_range_int(&server_rng, 0, valid_spawns.elements.count-1);
                spawn := valid_spawns.elements[index];
                player.entity->set_local_position(spawn.world_position);
            }
            else {
                index := rng_range_int(&server_rng, 0, all_zombie_spawns.elements.count-1);
                spawn := all_zombie_spawns.elements[index];
                player.entity->set_local_position(spawn.world_position);
            }
        }
    }
}

ao_can_use_interactable :: proc(interactable: Interactable, player: Player) -> bool {
    if player.health.is_dead {
        return false;
    }
    if interactable.listener != null switch #object_type(interactable.listener) {
        case Sell_Zone: return interactable.listener.(Sell_Zone)->can_use(player);
        case Align_Takeoff_Station: return interactable.listener.(Align_Takeoff_Station)->can_use(player);
        case Takeoff_Station: return interactable.listener.(Takeoff_Station)->can_use(player);
        case Fuel_Canister: return interactable.listener.(Fuel_Canister)->can_use(player);
        case Beacon: return interactable.listener.(Beacon)->can_use(player);
    }
    return true;
}

ao_on_interactable_used :: proc(interactable: Interactable, player: Player) {
    if interactable.listener != null switch #object_type(interactable.listener) {
        case Sell_Zone: interactable.listener.(Sell_Zone)->on_interact(player);
        case Beacon: interactable.listener.(Beacon)->on_interact(player);
        case Align_Takeoff_Station: interactable.listener.(Align_Takeoff_Station)->on_interact(player);
        case Takeoff_Station: interactable.listener.(Takeoff_Station)->on_interact(player);
        case Fuel_Canister: interactable.listener.(Fuel_Canister)->on_interact(player);
    }
}

ao_can_use_ability :: proc(player: Player, ability: Ability_Base) -> bool {
    if player.health.is_dead return false;
    return true;
}

Game_Manager :: class : Component {
    survivor_spawn: Entity @ao_serialize;
    zombie_spawn:   Entity @ao_serialize;
    main_navmesh:   Navmesh @ao_serialize;
    ship_navmesh:   Navmesh @ao_serialize;
    bullet_navmesh: Navmesh @ao_serialize;
    fuel_delivery_tutorial_arrow_point: Entity @ao_serialize;

    ao_start :: proc(using this: Game_Manager) {
        g_game_manager = this;
    }
}

//
// Interact_Ability
//

get_clickable_in_range :: proc(player: Player) -> Clickable {
    finder := make_finder(Clickable, player.entity.world_position);
    if player.controller == null {
        foreach clickable: component_iterator(Clickable) {
            food := clickable.entity->get_component(Food);
            if food != null {
                if food.is_eaten continue;
                if food.locked continue;
            }
            tree := clickable.entity->get_component(Tree);
            if tree != null {
                if tree.is_chopped continue;
                if tree.locked continue;
            }
            npc := clickable.entity->get_component(NPC);
            if npc != null {
                if npc.health.is_dead continue;
            }
            finder->check(clickable, clickable.required_range);
        }
    }
    return finder.closest;
}

Interact_Ability :: class : Ability_Base {
    on_init :: proc(ability: Interact_Ability) {
        ability.name = "Interact";
        ability.icon = get_asset(Texture_Asset, "icons/burger.png");
    }

    can_use :: proc(ability: Interact_Ability, player: Player) -> bool {
        return get_clickable_in_range(player) != null || player.controller != null;
    }

    on_update :: proc(ability: Interact_Ability, player: Player, params: Ability_Update_Params) {
        if !params.can_use {
            return;
        }

        hovering_click_zone := true;
        {
            UI.push_layer(-995); // override the shoot ability
            defer UI.pop_layer();
            UI.push_id("click to interact");
            defer UI.pop_id();
            click_zone := UI.button(UI.get_screen_rect(), .{}, .{}, "");
            if player.device_kind == .PC && !click_zone.hovering {
                hovering_click_zone = false;
            }
            if click_zone.just_pressed {
                params.clicked = true;
            }
        }

        clickable := get_clickable_in_range(player);
        draw_reticle := false;
        reticle_alpha := 1.0;

        if player.controller == null && clickable != null {
            draw_reticle = true;
            food := clickable.entity->get_component(Food);
            tree := clickable.entity->get_component(Tree);

            if food != null {
                // Check if mouth is big enough
                food_def := get_food_definition(food.kind);
                if player.mouth_stat < food_def.required_mouth_size {
                    if params.clicked {
                        Notifier.notify(format_string("Your Mouth is too small to eat %!", .{food_def.name}));
                    }
                    reticle_alpha = 0.5;
                }
                else {
                    // Check if stomach is full
                    current_food := Economy.get_balance(player, "Food");
                    max_food := player->get_max_food();

                    if current_food >= max_food.(s64) {
                        if params.clicked {
                            Notifier.notify("Your Stomach is full!");
                        }
                        reticle_alpha = 0.5;
                    }
                    else {
                        if params.clicked {
                            controller := new(Eating_Controller);
                            controller.food = food;
                            set_controller(player, controller);
                        }
                    }
                }
            }
            else if tree != null {
                if params.clicked {
                    controller := new(Chop_Tree_Controller);
                    controller.tree = tree;
                    set_controller(player, controller);
                }
            }
        }

        if params.clicked {
            if player.controller != null {
                draw_reticle = false;
                switch player.controller.controller_type {
                    case Eating_Controller:    player.controller.(Eating_Controller)->chomp();
                    case Chop_Tree_Controller: player.controller.(Chop_Tree_Controller)->chop();
                }
            }
        }

        if draw_reticle && hovering_click_zone {
            UI.push_world_draw_context();
            defer UI.pop_draw_context();

            UI.push_layer(100);
            defer UI.pop_layer();

            rect := Rect.{clickable.entity.world_position, clickable.entity.world_position}->grow(0.5);
            UI.quad(rect, get_asset(Texture_Asset, "ui/reticle.png"), .{2, 2, 2, reticle_alpha});
        }
    }
}

Always_Aiming_Ability_Data :: struct {
    aim:   bool;
    shoot: bool;
}

update_always_aiming_ability :: proc(player: Player, params: ref Ability_Update_Params) -> Always_Aiming_Ability_Data {
    if player.health.is_dead {
        return .{};
    }

    result: Always_Aiming_Ability_Data;
    if params.held {
        if length(params.drag_offset) > 0.1 {
            result.aim = true;
            result.shoot = true;
        }
    }
    else {
        if player.device_kind == .PC {
            if player.active_ability == null {
                UI.push_layer(-1000);
                defer UI.pop_layer();
                UI.push_id("click to shoot");
                defer UI.pop_id();

                interact := UI.button(UI.get_screen_rect(), .{}, .{}, "");

                if interact.hovering {
                    result.aim = true;
                    params.drag_direction = normalize(get_mouse_world_position() - player.entity.world_position);
                }

                if params.can_use {
                    if interact.active {
                        result.shoot = true;
                    }
                }
            }
        }
    }

    if result.aim {
        player.last_aim_direction = params.drag_direction;
        draw_thin_aiming_line(player.entity.world_position, params.drag_direction, 1.0 / player.camera.size * 4);
    }

    return result;
}

// On mobile: press and hold, shoots automatically while aiming
// On PC: always active, click to shoot
Shoot_Ability :: class : Ability_Base {
    on_init :: proc(ability: Shoot_Ability) {
        ability.name = "Shoot";
        ability.disable_keybind = true;
        ability.is_aimed_ability = true;
    }

    on_update :: proc(ability: Shoot_Ability, player: Player, params: Ability_Update_Params) {
        aiming := update_always_aiming_ability(player, &params);
        if params.can_use {
            if aiming.shoot {
                ability.current_cooldown = 0.5;
                sfx := default_sfx_desc();
                sfx->set_position(player.entity.local_position);
                sfx.volume_perturb = 0.2;
                sfx.speed_perturb = 0.1;
                if player.current_ammo > 0 {
                    player.current_ammo -= 1;
                    player.current_ammo_float -= 1;
                    shoot_projectile(player.entity.world_position, params.drag_direction * 10.0, 1, 0.75, player.team, player.entity);
                    player.time_last_shot[player.current_ammo] = get_time();
                    SFX.play(get_asset(SFX_Asset, "sfx/shoot.wav"), sfx);
                }
                else {
                    player.last_failed_to_shoot_time = get_time();
                    SFX.play(get_asset(SFX_Asset, "sfx/no_ammo.wav"), sfx);
                }
            }
        }
    }
}

// Drop fuel canister ability - only shown when carrying fuel
Drop_Fuel_Ability :: class : Ability_Base {
    on_init :: proc(ability: Drop_Fuel_Ability) {
        ability.name = "Drop";
        ability.icon = get_asset(Texture_Asset, "icons/fuel.png");
        ability.keybind_override = keybind_drop_fuel;
    }

    can_use :: proc(ability: Drop_Fuel_Ability, player: Player) -> bool {
        return is_player_carrying_canister(player);
    }

    on_update :: proc(ability: Drop_Fuel_Ability, player: Player, params: Ability_Update_Params) {
        if params.clicked && params.can_use {
            canister := get_player_canister(player);
            if canister != null {
                drop_canister(canister, player.entity.world_position);
            }
        }
    }
}

// Sprint ability - hold to move faster, uses stamina
SPRINT_DRAIN_RATE :: 0.5;
SPRINT_REGEN_RATE :: 0.2;
SPRINT_SPEED_BONUS :: 1.35;

Sprint_Ability :: class : Ability_Base {
    on_init :: proc(ability: Sprint_Ability) {
        ability.name = "Sprint";
        ability.keybind_override = keybind_sprint;
        ability.draw_but_dont_use_keybind = true;
    }

    can_use :: proc(ability: Sprint_Ability, player: Player) -> bool {
        return player.team == .SURVIVOR && player.sprint_stamina > 0;
    }

    on_update :: proc(ability: Sprint_Ability, player: Player, params: Ability_Update_Params) {
        if player.device_kind == .PC {
            if Keybinds.get_keybind_held(player, keybind_sprint) {
                params.held = true;
            }
        }
        if params.held && player.sprint_stamina > 0 && player.team == .SURVIVOR && length_squared(player.agent.velocity) > 0.001 && !player.sprint_exhausted {
            player.is_sprinting = true;
        }
        else {
            player.is_sprinting = false;
        }
    }
}

// On mobile: press and hold, drag to aim
// On PC: toggle on, click to shoot
Dodge_Roll :: class : Ability_Base {
    on_init :: proc(ability: Dodge_Roll) {
        ability.name = "Roll";
        // ability.icon = get_asset(Texture_Asset, "icons/coin.png");
        ability.is_aimed_ability = true;
        ability.keybind_override = keybind_dodge_roll;
    }

    can_use :: proc(ability: Dodge_Roll, player: Player) -> bool {
        return true;
    }

    on_update :: proc(ability: Dodge_Roll, player: Player, params: Ability_Update_Params) {
        if player.health.is_dead {
            return;
        }

        aim := false;
        activate := false;
        if player.device_kind == .PC {
            if params.clicked {
                player.active_ability = ability;
            }
            if player.active_ability == ability.(Ability_Base) {
                if get_input_down(.MOUSE_RIGHT, true) {
                    player.active_ability = null;
                }
            }
            if player.active_ability == ability.(Ability_Base) { // todo(josh): @CSL @Incomplete: shouldn't need a cast here!!!
                aim = true;
                params.drag_direction = normalize(get_mouse_world_position() - player.entity.world_position);

                UI.push_layer(-990); // be in front of the interact ability
                defer UI.pop_layer();
                UI.push_id("click to roll");
                defer UI.pop_id();

                interact := UI.button(UI.get_screen_rect(), .{}, .{}, "");
                if interact.just_pressed {
                    activate = true;
                    player.active_ability = null;
                }
            }
        }
        else {
            if params.held {
                aim = true;
            }
            if params.up {
                activate = true;
            }
        }

        if aim {
            draw_aiming_line(player.entity.world_position, params.drag_direction, 1.0 / player.camera.size * 4);
        }

        if params.can_use && activate {
            ability.current_cooldown = 1.5;
            controller := new(Roll_Controller);
            controller.direction = params.drag_direction;
            set_controller(player, controller);
        }
    }
}

Roll_Controller :: class : Controller_Base {
    direction: v2;
    original_friction: float;

    controller_begin :: proc(using this: Roll_Controller) {
        {
            sfx := default_sfx_desc();
            sfx->set_position(player.entity.world_position);
            sfx.volume = 0.5;
            sfx.volume_perturb = 0.1;
            sfx.speed_perturb = 0.1;
            SFX.play(get_asset(SFX_Asset, "sfx/dodge_roll.wav"), sfx);
        }
        disable_movement_inputs = true;
        player->player_set_trigger("dodge_roll");
        original_friction = player.agent.friction;
        player.agent.friction = 0;
        player->set_facing_right(direction.x > 0);
    }

    controller_update :: proc(using this: Roll_Controller, dt: float) {
        player.agent.velocity = direction * 8;
        if elapsed_time > 0.5 {
            end_controller(player, false);
        }
    }

    controller_end :: proc(using this: Roll_Controller, interrupt: bool) {
        player.agent.friction = original_friction;
    }
}

// On mobile: press and hold, drag to aim
// On PC: toggle on, click to shoot
Slash_Ability :: class : Ability_Base {
    on_init :: proc(ability: Slash_Ability) {
        ability.name = "Slash";
        // ability.icon = get_asset(Texture_Asset, "icons/coin.png");
        ability.is_aimed_ability = true;
        ability.disable_keybind = true;
    }

    can_use :: proc(ability: Slash_Ability, player: Player) -> bool {
        return true;
    }

    on_update :: proc(ability: Slash_Ability, player: Player, params: Ability_Update_Params) {
        if update_always_aiming_ability(player, &params).shoot {
            if params.can_use {
                ability.current_cooldown = 0.6;

                controller := new(Slash_Controller);
                controller.direction = params.drag_direction;
                set_controller(player, controller);
            }
        }
    }
}

Slash_Controller :: class : Controller_Base {
    direction: v2;
    original_friction: float;
    already_hit_list: List(Player);

    controller_begin :: proc(using this: Slash_Controller) {
        disable_movement_inputs = true;
        player->player_set_trigger("attack");
        original_friction = player.agent.friction;
        player.agent.friction = 0;
        player->set_facing_right(direction.x > 0);
        {
            sfx := default_sfx_desc();
            sfx->set_position(player.entity.world_position);
            sfx.volume = 0.75;
            sfx.volume_perturb = 0.1;
            sfx.speed_perturb = 0.2;
            SFX.play(get_asset(SFX_Asset, "sfx/slash.wav"), sfx);
        }
    }

    controller_update :: proc(using this: Slash_Controller, dt: float) {
        foreach other: component_iterator(Player) {
            if other.team == player.team continue;
            if in_range(other.entity.world_position - player.entity.world_position, 0.5) {
                already_hit := false;
                for i: 0..already_hit_list.elements.count-1 {
                    if already_hit_list.elements[i] == other {
                        already_hit = true;
                        break;
                    }
                }
                if already_hit {
                    continue;
                }
                other->take_damage(1);
                already_hit_list->append(other);
                {
                    sfx := default_sfx_desc();
                    sfx->set_position(other.entity.world_position);
                    sfx.volume = 0.75;
                    sfx.volume_perturb = 0.1;
                    sfx.speed_perturb = 0.2;
                    SFX.play(get_asset(SFX_Asset, "sfx/stabbed.wav"), sfx);
                }
            }
        }

        player.agent.velocity = direction * 10;
        if elapsed_time > 0.3 {
            end_controller(player, false);
        }
    }

    controller_end :: proc(using this: Slash_Controller, interrupt: bool) {
        player.agent.friction = original_friction;
        player->player_set_trigger("RESET");
    }
}

Clickable :: class : Component {
    required_range: float @ao_serialize;
}

//
// Food
//

Food_Definition :: struct {
    name: string;
    food_value: int;
    health: int;
    required_mouth_size: int;
}

// todo(josh): enum arrays
food_definitions: [32]Food_Definition;

get_food_definition :: proc(kind: Food_Kind) -> Food_Definition {
    return food_definitions[kind.(int)];
}

Food :: class : Component {
    sprite: Sprite_Renderer @ao_serialize;
    kind: Food_Kind @ao_serialize;
    health: Health_Component;

    respawn_time: float;
    is_eaten: bool;
    locked: bool;

    ao_start :: proc(using food: Food) {
        defn := get_food_definition(kind);
        health = entity->add_component(Health_Component);
        health->set_max_health(defn.health, true);
    }

    ao_update :: proc(using food: Food, dt: float) {
        if is_eaten {
            if get_time() > respawn_time {
                is_eaten = false;
                sprite.enabled = true;
                health->reset();
            }
        }
    }

    on_eaten :: proc(using food: Food, player: Player) {
        is_eaten = true;
        sprite.enabled = false;
        respawn_time = get_time() + 8;

        player.total_things_eaten += 1;
        Save.set_int(player, "total_things_eaten", player.total_things_eaten);

        // Spawn particles
        defn := get_food_definition(kind);
        for i: 1..defn.food_value {
            spawn_particle(entity.local_position, player.entity, .BURGER);
        }
    }
}

Food_Kind :: enum {
    APPLE;
    FEASTABLE_BAR;
    POPCORN;
    GRIMACE_SHAKE_SMALL;
    MILK_JUG;
    DOGGY_POOP_BIN;
    FIRE_HYDRANT;
    TRASH_BAG;
    INFINITY_GAUNTLET;
}

Eating_Controller :: class : Controller_Base {
    food: Food;
    original_food_position: v2;
    time_last_clicked: float;

    controller_begin :: proc(using this: Eating_Controller) {
        freeze_player = true;
        food.locked = true;
        player->player_set_trigger("start_eating");
        original_food_position = food.entity.local_position;
    }

    chomp :: proc(using this: Eating_Controller) {
        time_last_clicked = get_time();

        // Apply player.chew_stat using Health_Component
        died := food.health->take_damage(player.chew_stat);
        {
            desc := default_sfx_desc();
            desc->set_position(player.entity.local_position);

            rng := rng_seed(food.entity.id ^ food.health.current_health.(u64));
            num := rng_range_int(&rng, 1, 5);
            SFX.play(get_asset(SFX_Asset, format_string("sfx/character_single_bite_0%.wav", .{num})), desc);
        }

        if died {
            food->on_eaten(player);
            end_controller(player, false);
            return;
        }
    }

    controller_update :: proc(using this: Eating_Controller, dt: float) {
        rotation := Ease.jitter(Ease.T(get_time() - time_last_clicked, 0.5), 8);
        food.entity->set_local_rotation(rotation * 15);

        bone_position := player.animator.instance->get_bone_position("Hand_R");
        bone_position.x *= sign(player.entity.local_scale.x);
        food.entity->set_local_position(player.entity.local_position + bone_position);

        food_health_t := food.health->get_health_percent();
        scale := lerp(0.25, 1.0, food_health_t);
        food.entity->set_local_scale(.{scale, scale});

        offset := player.entity.local_position.y - food.entity.local_position.y;
        offset /= food.entity.local_scale.y;
        food.sprite.depth_offset = offset - 0.001;

        food.health->draw_health_bar(player.entity.world_position.y-0.001);

        // UI.push_world_draw_context();
        // defer UI.pop_draw_context();

        // UI.push_layer(10);
        // defer UI.pop_layer();

        // rect := Rect.{food.entity.local_position, food.entity.local_position}->grow(0.1, 0.3, 0.1, 0.3)->offset(0, 1);
        // UI.quad(rect, white_sprite, .{0, 0, 0, 1});
        // rect = rect->subrect(0, 0, food_health_t, 1);
        // color_t := linear_step(0.25, 0.6, food_health_t);
        // UI.quad(rect, white_sprite, .{1-color_t, color_t, 0, 1});
    }

    controller_end :: proc(using this: Eating_Controller, interrupt: bool) {
        food.locked = false;
        player->player_set_trigger("RESET");
        food.entity->set_local_position(original_food_position);
        food.entity->set_local_scale(.{1, 1});
        food.sprite.depth_offset = 0;
        food.entity->set_local_rotation(0);
    }
}

Chop_Tree_Controller :: class : Controller_Base {
    tree: Tree;
    time_last_clicked: float;
    original_player_position: v2;
    chopping_position: v2;

    controller_begin :: proc(using this: Chop_Tree_Controller) {
        freeze_player = true;
        tree.locked = true;
        player->player_set_trigger("start_eating"); // Reuse eating animation for now

        direction := normalize(player.entity.world_position - tree.entity.world_position);
        chopping_position = tree.entity.world_position + direction * 1.0;
        original_player_position = player.entity.world_position;

        // Snap player to chopping position
        player.entity->set_local_position(chopping_position);

        // Face the tree
        if tree.entity.world_position.x < player.entity.world_position.x {
            player.entity->set_local_scale(.{-1, 1});
        }
        else {
            player.entity->set_local_scale(.{1, 1});
        }
    }

    chop :: proc(using this: Chop_Tree_Controller) {
        time_last_clicked = get_time();

        // Apply damage using Health_Component
        died := tree.health->take_damage(player.chew_stat);
        tree->jiggle();

        // Play chop sound (reuse bite sounds for now)
        {
            desc := default_sfx_desc();
            desc->set_position(player.entity.local_position);

            rng := rng_seed(tree.entity.id ^ tree.health.current_health.(u64));
            num := rng_range_int(&rng, 1, 5);
            SFX.play(get_asset(SFX_Asset, format_string("sfx/character_single_bite_0%.wav", .{num})), desc);
        }

        if died {
            tree->on_chopped(player);
            end_controller(player, false);
            return;
        }
    }

    controller_update :: proc(using this: Chop_Tree_Controller, dt: float) {
        tree.health->draw_health_bar(tree.entity.world_position.y-0.001);
    }

    controller_end :: proc(using this: Chop_Tree_Controller, interrupt: bool) {
        tree.locked = false;
        player->player_set_trigger("RESET");
        tree.sprite.entity->set_local_rotation(0);
    }
}

//
// Particles
//

Particle_Type :: enum {
    BURGER;
    COIN;
}

Particle :: class : Component {
    sprite: Sprite_Renderer @ao_serialize;
    velocity: v2;
    target_entity: Entity;
    spawn_time: float;
    state: Particle_State;
    particle_type: Particle_Type;
    currency_value: int;

    lerp_start_time: float;
    lerp_t: float;

    ao_start :: proc(using particle: Particle) {
    }

    ao_end :: proc(using particle: Particle) {
    }

    ao_update :: proc(using particle: Particle, dt: float) {
        switch state {
            case .OUTWARD: {
                if get_time() - spawn_time > 0.75 {
                    state = .LERPING;
                    lerp_start_time = get_time();
                }
            }
            case .LERPING: {
                current_position := entity.local_position;
                target := target_entity.world_position;
                target.y += 0.5;
                direction := normalize(target - current_position);
                time_in_state := get_time() - lerp_start_time;
                speed := 1.0 + time_in_state * 2;
                velocity += direction * 650 * dt * speed;
                if length_squared(target - current_position) < 0.25 {
                    player := target_entity->get_component(Player);
                    if player != null {
                        switch particle_type {
                            case .BURGER: {
                                current_food := Economy.get_balance(player, "Food");
                                max_food := player->get_max_food();
                                space_remaining := max(0, max_food.(s64) - current_food);
                                amount_to_add := min(currency_value.(s64), space_remaining);

                                if amount_to_add > 0 {
                                    Economy.deposit_currency(player, "Food", amount_to_add);
                                    player.last_food_arrive_time = get_time();
                                }
                            }
                            case .COIN: {
                                Economy.deposit_currency(player, "Coins", currency_value.(s64));
                                player.last_coin_arrive_time = get_time();
                            }
                        }
                    }
                    destroy_entity(entity);
                }
                velocity *= 0.6; // extra friction
            }
        }

        velocity *= 0.9;
        entity->add_local_position(velocity * dt);
    }
}

Particle_State :: enum {
    OUTWARD;
    LERPING;
}

spawn_particle :: proc(spawn_position: v2, target_entity: Entity, particle_type: Particle_Type, currency_value: int = 1) {
    prefab_asset := get_asset(Prefab_Asset, "Particle.prefab");
    entity := instantiate(prefab_asset);
    particle := get_component(entity, Particle);

    // Set texture based on particle type
    asset_path: string;
    switch particle_type {
        case .BURGER: asset_path = "icons/burger.png";
        case .COIN:   asset_path = "icons/coin.png";
    }

    particle.particle_type = particle_type;
    particle.currency_value = currency_value;
    particle.sprite->set_texture(get_asset(Texture_Asset, asset_path));

    entity->set_local_position(spawn_position);
    particle.target_entity = target_entity;
    particle.spawn_time = get_time();
    particle.state = .OUTWARD;

    // Random direction in circle
    rng := rng_seed(entity.id);
    angle := rng_range_float(&rng, 0, 2 * PI);
    speed := rng_range_float(&rng, 5, 10);
    particle.velocity = .{cos(angle) * speed, sin(angle) * speed};
}

//
// Health Component
//

Health_Component :: class : Component {
    max_health: int @ao_serialize;
    current_health: int;

    is_dead: bool;
    last_damage_time: float;

    // Optional: show health bar above entity
    health_bar_offset: v2 @ao_serialize;

    ao_start :: proc(using health: Health_Component) {
        current_health = max_health;
        if health_bar_offset.x == 0 && health_bar_offset.y == 0 {
            health_bar_offset = .{0, 1.5};
        }
    }

    draw_health_bar :: proc(using this: Health_Component, z: float) {
        UI.push_world_draw_context();
        defer UI.pop_draw_context();

        UI.push_z(z);
        defer UI.pop_z();

        // Don't show health bar if at full health
        health_percent := get_health_percent(this);
        // if health_percent >= 1.0 return;

        bar_pos := entity.world_position + health_bar_offset;
        bar_rect := Rect.{bar_pos, bar_pos}->grow(0.1, 0.4, 0.1, 0.4);

        UI.quad(bar_rect, white_sprite, .{0.01, 0.01, 0.01, 1});

        fill_rect := bar_rect->subrect(0, 0, health_percent, 1);

        color := lerp(v4.{0.8, 0.1, 0.1, 1}, .{0.1, 0.8, 0.1, 1}, health_percent);
        UI.quad(fill_rect, white_sprite, color);
    }

    take_damage :: proc(using health: Health_Component, amount: int) -> bool {
        if is_dead return false;

        current_health -= amount;

        last_damage_time = get_time();

        // Spawn damage number
        spawn_damage_number(amount, entity.world_position + v2.{0, 0.5});

        if current_health <= 0 {
            current_health = 0;
            is_dead = true;
            return true; // died
        }
        return false; // still alive
    }

    heal :: proc(using health: Health_Component, amount: int) {
        if is_dead return;

        current_health += amount;
        if current_health > max_health {
            current_health = max_health;
        }
    }

    get_health_percent :: proc(using health: Health_Component) -> float {
        if max_health <= 0 return 0;
        return current_health.(float) / max_health.(float);
    }

    reset :: proc(using health: Health_Component) {
        current_health = max_health;
        is_dead = false;
    }

    set_max_health :: proc(using health: Health_Component, new_max: int, heal_to_full: bool) {
        max_health = new_max;
        if heal_to_full {
            current_health = max_health;
        }
        else if current_health > max_health {
            current_health = max_health;
        }
    }
}

//
// Damage numbers
//

Damage_Number :: class : Component {
    value: int;
    velocity: v2;
    spawn_time: float;
    lifetime: float;

    ao_update :: proc(using this: Damage_Number, dt: float) {
        time_alive := get_time() - spawn_time;
        if time_alive >= lifetime {
            destroy_entity(entity);
            return;
        }

        // Apply velocity with gravity
        velocity.y -= 20 * dt;
        entity->add_local_position(velocity * dt);

        // Draw the damage number
        UI.push_world_draw_context();
        defer UI.pop_draw_context();

        UI.push_layer(100);
        defer UI.pop_layer();

        rect := Rect.{entity.local_position, entity.local_position}->grow(0.2, 0.4, 0.2, 0.4);

        fade_t := linear_step(lifetime-1, lifetime, time_alive);
        ts := UI.default_text_settings();
        ts.size = lerp(0.7, 0.2, fade_t);
        ts.valign = .CENTER;
        ts.halign = .CENTER;

        // Fade out towards the end of lifetime
        alpha := 1.0 - fade_t;
        ts.color = .{1, 0, 0, alpha}; // Red
        ts.outline_color = .{0, 0, 0, 1};
        UI.text(rect, ts, "%", .{value});
    }
}

spawn_damage_number :: proc(value: int, position: v2) {
    entity := create_entity();
    entity->set_local_position(position);

    damage_number := entity->add_component(Damage_Number);
    damage_number.value = value;
    damage_number.spawn_time = get_time();
    damage_number.lifetime = 1.5;

    // Random velocity
    rng := rng_seed(entity.id);
    vel_x := rng_range_float(&rng, -0.3, 0.3);
    vel_y := rng_range_float(&rng, 0.75, 0.9);
    damage_number.velocity = v2.{vel_x, vel_y} * 10;
}

Finder :: struct($T: typeid) {
    position: v2;
    closest_distance: float;
    closest: T;

    check :: proc(using f: ref Finder(T), item: T, item_position: v2, required_range: float = -1) {
        distance := length_squared(position - item_position);
        if distance > (required_range*required_range) {
            return;
        }
        if distance < closest_distance {
            closest_distance = distance;
            closest = item;
        }
    }

    check :: proc(using f: ref Finder(T), item: T, required_range: float = -1) {
        distance := length_squared(position - item.entity.world_position);
        if distance > (required_range*required_range) {
            return;
        }
        if distance < closest_distance {
            closest_distance = distance;
            closest = item;
        }
    }
}

make_finder :: proc($T: typeid, position: v2) -> Finder(T) {
    result: Finder(T);
    result.position = position;
    result.closest_distance = 999999999;
    return result;
}

Death_Controller :: class : Controller_Base {
    controller_begin :: proc(using this: Death_Controller) {
        freeze_player = true;
        player->add_name_invisibility_reason("death");
        player->player_set_trigger("death");
        {
            sfx := default_sfx_desc();
            sfx->set_position(player.entity.world_position);
            sfx.volume = 0.65;
            sfx.volume_perturb = 0.1;
            SFX.play(get_asset(SFX_Asset, "sfx/death.wav"), sfx);
        }
    }

    controller_update :: proc(using this: Death_Controller, dt: float) {
        if g_game.state == .GAMEPLAY {
            time_until_respawn := 5.0 - elapsed_time;
            if player->is_local() {
                draw_big_game_text("Respawning in %s", .{time_until_respawn.(int) + 1});
            }
            if time_until_respawn <= 0 {
                end_controller(player, false);
            }
        }
    }

    controller_end :: proc(using this: Death_Controller, interrupt: bool) {
        player->remove_name_invisibility_reason("death");
        if player.team == .SURVIVOR {
            player.team = .ZOMBIE;
        }
        respawn_player(player);
        player.health->reset();
        player->player_set_trigger("RESET");
    }
}

//
// Player, mostly UI
//

Notification :: class {
    time: float;
    text: string;
    next: Notification;
}

Player :: class : Player_Base {
    team: Player_Team;

    last_food_arrive_time: float;
    last_coin_arrive_time: float;

    mouth_stat: int;
    stomach_stat: int;
    chew_stat: int;

    total_things_eaten: int;

    upgrade_menu_open: bool;

    time_last_shot: [MAX_AMMO]float;
    last_failed_to_shoot_time: float;

    upgrade_menu_tab_index: int;

    health: Health_Component;

    active_ability: Ability_Base;

    last_aim_direction: v2;

    notifications: List(Notification);

    // Ammo system
    current_ammo_float: float;
    current_ammo: int;

    // Sprint system
    sprint_stamina: float;
    sprite_dust_timer: float;
    is_sprinting: bool;
    sprint_exhausted: bool;
    dust_serial: u64;
    last_exhaust_recover_time: float;
    last_exhaust_time: float;

    first_notification: Notification;
    last_notification: Notification;

    running_state: State_Machine_State;

    add_notification :: proc(using this: Player, text: string) {
        notification := new(Notification);
        notification.text = text;
        if first_notification == null {
            first_notification = notification;
            last_notification = notification;
        }
        else {
            last_notification.next = notification;
            last_notification = notification;
        }
    }

    get_max_food :: proc(using this: Player) -> int {
        return 8 + (stomach_stat - 1) * 3;
    }

    take_damage :: proc(using this: Player, damage: int) {
        if health.is_dead {
            return;
        }
        if team == .SPECTATOR {
            return;
        }
        health->take_damage(damage);
        if health.is_dead {
            controller := new(Death_Controller);
            this->set_controller(controller);
        }
    }

    draw_ammo_bar :: proc(using this: Player) {
        UI.push_world_draw_context();
        defer UI.pop_draw_context();

        UI.push_z(entity.world_position.y-0.001);
        defer UI.pop_z();

        bar_pos := entity.world_position + v2.{0, 1.75};
        bar_width := 0.8;
        bar_height := 0.2;
        segment_gap := 0.02;

        bar_rect := Rect.{bar_pos, bar_pos}->grow(bar_height / 2, bar_width / 2, bar_height / 2, bar_width / 2);

        // Background bar
        {
            jitter := Ease.jitter(Ease.T(get_time() - last_failed_to_shoot_time, 0.5), 8);

            bar_rect_jitter := bar_rect->offset(jitter * 0.15, 0);

            UI.quad(bar_rect_jitter, white_sprite, .{0.01, 0.01, 0.01, 1});
            inner_bar := bar_rect_jitter->inset(0.04);
            UI.quad(inner_bar, white_sprite, .{0.15, 0.15, 0.15, 1});

            // fill bar
            full_ammo_t := current_ammo_float / MAX_AMMO.(float);
            UI.quad(inner_bar->subrect(0, 0, full_ammo_t, 1), white_sprite, .{0.4, 0.4, 0.1, 1});

            // Calculate segment dimensions
            segment_width := inner_bar->width() / MAX_AMMO.(float);

            // Draw each segment
            step_size := inner_bar->width() / MAX_AMMO.(float);
            base_segment_rect := inner_bar->left_rect()->grow_unscaled(0, segment_width, 0, 0);
            base_notch_rect   := inner_bar->left_rect()->grow(0, segment_gap, 0, segment_gap);
            for i: 0..MAX_AMMO-1 {
                segment_rect := base_segment_rect->offset_unscaled(segment_width * i.(float), 0);
                if i < current_ammo {
                    UI.quad(segment_rect, white_sprite, .{0.2, 0.9, 0.9, 1});
                }

                UI.push_layer_relative(1);
                defer UI.pop_layer();
                draw_rect_grow_fade_out_effect(segment_rect, get_time() - time_last_shot[i], .{0, 1, 0, 1});
            }
            for i: 0..MAX_AMMO-2 {
                notch_rect := base_notch_rect->offset_unscaled(segment_width * (i+1).(float), 0);
                UI.quad(notch_rect, white_sprite, .{0.2, 0.01, 0.01, 1});
            }
        }

        // No ammo indicator
        no_ammo_t := Ease.out_quart(Ease.T(get_time() - last_failed_to_shoot_time, 0.35));
        no_ammo_rect := bar_rect->grow(0.2 * no_ammo_t);
        UI.quad(no_ammo_rect, white_sprite, lerp(v4.{1, 0, 0, 1}, v4.{1, 0, 0, 0}, no_ammo_t));
    }

    draw_stamina_bar :: proc(using this: Player) {
        UI.push_world_draw_context();
        defer UI.pop_draw_context();

        UI.push_z(entity.world_position.y-0.001);
        defer UI.pop_z();

        // Position below the ammo bar
        bar_pos := entity.world_position + v2.{0, 1.6};
        bar_width := 0.6;
        bar_height := 0.12;

        bar_rect := Rect.{bar_pos, bar_pos}->grow(bar_height / 2, bar_width / 2, bar_height / 2, bar_width / 2);

        // Background
        UI.quad(bar_rect, white_sprite, .{0.01, 0.01, 0.01, 1});
        inner_bar := bar_rect->inset(0.02);
        UI.quad(inner_bar, white_sprite, .{0.15, 0.15, 0.15, 1});

        // Stamina fill
        fill_rect := inner_bar->subrect(0, 0, sprint_stamina, 1);

        // Color: yellow when full, orange when depleting
        fill_color: v4;
        if sprint_exhausted {
            fill_color = .{1, 0, 0, 1};
        }
        else {
            if is_sprinting {
                fill_color = lerp(v4.{1, 0.3, 0, 1}, .{1, 0.8, 0, 1}, sprint_stamina);
            }
            else {
                fill_color = lerp(v4.{1, 0.3, 0, 1}, .{0.3, 1, 0, 1}, sprint_stamina);
            }
        }
        UI.quad(fill_rect, white_sprite, fill_color);

        UI.push_layer_relative(1);
        defer UI.pop_layer();

        if sprint_exhausted {
            time_since_exhaust := (get_time() - last_exhaust_time) * 0.5;
            exhaust_time_loop := time_since_exhaust % 0.5;
            draw_rect_grow_fade_out_effect(bar_rect, exhaust_time_loop,  .{1, 0, 0, 1});
        }
        time_since_recover := (get_time() - last_exhaust_recover_time) * 0.5;
        draw_rect_grow_fade_out_effect(bar_rect, time_since_recover, .{0, 1, 0, 1});
    }

    ao_start :: proc(using this: Player) {
        agent.lock_to_navmesh = true;
        agent->set_navmesh_to_lock_to(g_game_manager.main_navmesh);

        switch g_game.state {
            case .GAMEPLAY: {
                team = .SPECTATOR;
                this->add_ghost_reason("spectator");
            }
            case: {
                team = .SURVIVOR;
            }
        }

        mouth_stat         = Save.get_int(this, "mouth_level",        1);
        stomach_stat       = Save.get_int(this, "stomach_level",      1);
        chew_stat          = Save.get_int(this, "chew_level",         1);
        total_things_eaten = Save.get_int(this, "total_things_eaten", 0);

        health = entity->add_component(Health_Component);
        health->set_max_health(1, true);
        health.health_bar_offset = .{0, 1.75};

        // Initialize ammo system
        current_ammo = 0;
        current_ammo_float = 0;

        {
            register_ability(this, Interact_Ability);
            register_ability(this, Shoot_Ability);
            register_ability(this, Dodge_Roll);
            register_ability(this, Slash_Ability);
            register_ability(this, Drop_Fuel_Ability);
            register_ability(this, Sprint_Ability);
        }

        // Initialize sprint stamina
        sprint_stamina = 1;

        {
            layer := animator.instance.state_machine->try_get_layer("main");
            running_state = layer->try_get_state("Run_Fast");
            assert(running_state != null, "failed to find running state");
        }
    }

    ao_update :: proc(using this: Player, dt: float) {
        if Game.is_launched_from_editor() {
            if get_input_down(.F1, true) {
                complete_current_task();
            }
        }

        switch team {
            case .SURVIVOR: {
                base_speed: float;
                if is_player_carrying_canister(this) {
                    agent.movement_speed = 150;
                }
                else {
                    agent.movement_speed = 215;
                }

                // Apply sprint speed bonus
                if is_sprinting {
                    agent.movement_speed *= SPRINT_SPEED_BONUS;
                }
            }
            case .ZOMBIE: {
                agent.movement_speed = 250;
            }
            case .SPECTATOR: {
                agent.movement_speed = 450;
            }
        }

        // Sprint stamina drain/regen
        sprite_dust_timer = max(0.0, sprite_dust_timer - dt);
        if is_sprinting {
            if sprite_dust_timer <= 0 {
                sprite_dust_timer = 0.15;
                dust_serial += 1;
                dust_rng := rng_seed(dust_serial);
                e := create_entity();
                e->set_local_position(entity.world_position);
                e->set_local_scale(entity.local_scale * 1.5);
                animator := e->add_component(Spine_Animator);
                brightness := rng_range_float(&dust_rng, 0.5, 1);
                animator.instance.color_multiplier = .{brightness, brightness, brightness, 0.5};
                animator.instance->set_skeleton(dust_spine);
                animator.instance->set_animation("running_dust_poof", false, 0, 1);
                e->queue_for_destruction(0.5);
            }

            running_state.speed = SPRINT_SPEED_BONUS;
            if g_game.state == .GAMEPLAY { // no stamina in lobby
                sprint_stamina -= dt * SPRINT_DRAIN_RATE;
                if sprint_stamina <= 0 {
                    sprint_stamina = 0;
                    is_sprinting = false;
                    sprint_exhausted = true;
                    last_exhaust_time = get_time();
                }
            }
        }
        else {
            running_state.speed = 1;
            sprint_stamina = min(1.0, sprint_stamina + dt * SPRINT_REGEN_RATE);
            if sprint_exhausted && sprint_stamina >= 1 {
                sprint_exhausted = false;
                last_exhaust_recover_time = get_time();
            }
        }

        // Ammo regeneration
        current_ammo_float = min(current_ammo_float + dt * AMMO_PER_SECOND, MAX_AMMO.(float));
        current_ammo = current_ammo_float.(int);

        {
            name_color := v4.{1, 1, 1, 1};
            switch team {
                case .SURVIVOR: {
                    name_color = .{0, 1, 0, 1};
                }
                case .ZOMBIE: {
                    name_color = .{1, 0, 0, 1};
                }
            }

            do_name_color_override = true;
            name_color_override = name_color;
        }
    }

    ao_late_update :: proc(using this: Player, dt: float) {
        if team == .SPECTATOR {
            agent.lock_to_navmesh = false;
            camera.size = 8;
        }
        else {
            agent.lock_to_navmesh = true;
            camera.size = 5;
        }

        if this->is_local_or_server() {
            if g_game.state == .GAMEPLAY {
                if is_player_carrying_canister(this) {
                    // Only show drop fuel ability when carrying
                    draw_ability_button(this, Drop_Fuel_Ability, 0);
                }
                else {
                    switch team {
                        case .SURVIVOR: {
                            draw_ability_button(this, Shoot_Ability, 0);
                            draw_ability_button(this, Dodge_Roll, 1);
                            draw_ability_button(this, Sprint_Ability, 4);
                        }
                        case .ZOMBIE: {
                            draw_ability_button(this, Slash_Ability, 0);
                        }
                    }
                }
            }
            else {
                draw_ability_button(this, Dodge_Roll, 0);
                draw_ability_button(this, Sprint_Ability, 4);
            }
        }

        if g_game.state == .GAMEPLAY {
            UI.push_world_draw_context();
            defer UI.pop_draw_context();

            if team == .SURVIVOR && !health.is_dead && this->will_draw_name() {
                this->draw_ammo_bar();
                this->draw_stamina_bar();
            }

            if this->is_local() {
                switch team {
                    case .SURVIVOR: {
                        tutorial_arrow_options := default_tutorial_arrow_options();

                        switch g_game.current_task {
                            case .FUEL_CANISTERS: {
                                if is_player_carrying_canister(this) {
                                    draw_tutorial_arrow(this, g_game_manager.fuel_delivery_tutorial_arrow_point.world_position, tutorial_arrow_options);
                                }
                                else {
                                    foreach fuel: component_iterator(Fuel_Canister) {
                                        if !fuel.is_picked_up {
                                            draw_tutorial_arrow(this, fuel.entity.world_position, tutorial_arrow_options);
                                        }
                                    }
                                }
                            }
                            case .RESTORE_BEACONS: {
                                foreach beacon: component_iterator(Beacon) {
                                    if beacon.state == .INACTIVE || (beacon.state == .RESTORING && beacon.survivor_nearby == false) {
                                        draw_tutorial_arrow(this, beacon.entity.world_position, tutorial_arrow_options);
                                    }
                                }
                            }
                            case .ALIGN_TAKEOFF: {
                                foreach align: component_iterator(Align_Takeoff_Station) {
                                    if !align.is_aligned {
                                        draw_tutorial_arrow(this, align.entity.world_position, tutorial_arrow_options);
                                    }
                                }
                            }
                            case .TAKEOFF: {
                                takeoff: Takeoff_Station;
                                foreach c: component_iterator(Takeoff_Station) {
                                    takeoff = c;
                                    break;
                                }
                                if !takeoff.initiated {
                                    draw_tutorial_arrow(this, takeoff.entity.world_position, tutorial_arrow_options);
                                }
                            }
                        }
                    }
                    case .ZOMBIE: {
                        survivor_hint_options := default_tutorial_arrow_options();
                        survivor_hint_options.near = false;
                        foreach other: component_iterator(Player) if other.team == .SURVIVOR && !other.health.is_dead {
                            distance := length(other.entity.world_position - entity.world_position);
                            inv_alpha := linear_step(0, 20, distance);
                            survivor_hint_options.inv_alpha_multiplier = inv_alpha;
                            if inv_alpha < 1 {
                                draw_tutorial_arrow(this, other.entity.world_position, survivor_hint_options);
                            }
                        }
                    }
                }
            }
        }

        if this->is_local_or_server() {
            if first_notification != null {
                first_notification.time += dt;
                if first_notification.time > 3.0 {
                    first_notification = first_notification.next;
                    if first_notification == null {
                        last_notification = null;
                    }
                }
                if first_notification != null {
                    draw_big_game_text(first_notification.text);
                }
            }
        }
    }

    ao_end :: proc(player: Player) {
    }
}

//
// Sell zone
//

Sell_Zone :: class : Component {
    sell_position: Entity @ao_serialize;
    particle_target: Entity @ao_serialize;
    interactable: Interactable @ao_serialize;

    ao_start :: proc(using this: Sell_Zone) {
        interactable.listener = this;
    }

    can_use :: proc(using this: Sell_Zone, player: Player) -> bool {
        food_count := Economy.get_balance(player, "Food");
        if food_count <= 0 {
            return false;
        }
        return true;
    }

    on_interact :: proc(using this: Sell_Zone, player: Player) {
        food_count := Economy.get_balance(player, "Food");
        particle_count := max(1, sqrt(food_count.(float)).(int));
        coins_earned := food_count;
        coins_per_particle := coins_earned / particle_count;

        for i: 1..particle_count {
            spawn_particle(player.entity.world_position, particle_target, .BURGER);
            coins_for_this_particle := coins_per_particle;
            if i == particle_count {
                coins_for_this_particle = coins_earned;
            }
            spawn_particle(particle_target.world_position, player.entity, .COIN, coins_for_this_particle);
            coins_earned -= coins_for_this_particle;
        }
        Economy.withdraw_currency(player, "Food", food_count);
    }
}

//
// Trees
//

Tree :: class : Component {
    sprite: Sprite_Renderer @ao_serialize;
    chopped_sprite: Sprite_Renderer @ao_serialize;
    health: Health_Component;

    respawn_time: float;
    is_chopped: bool;
    locked: bool;

    jiggle_time: float;

    ao_start :: proc(using tree: Tree) {
        health = entity->add_component(Health_Component);
        health->set_max_health(10, true);
        health.health_bar_offset = .{0, 2.0};
        sprite.enabled = true;
        chopped_sprite.enabled = false;
    }

    ao_update :: proc(using tree: Tree, dt: float) {
        if is_chopped {
            if get_time() > respawn_time {
                is_chopped = false;
                sprite.enabled = true;
                chopped_sprite.enabled = false;
                locked = false;
                health->reset();
            }
        }

        // Apply jiggle rotation
        time_since_jiggle := get_time() - jiggle_time;
        if time_since_jiggle < 0.5 {
            jiggle_amount := Ease.jitter(Ease.T(time_since_jiggle, 0.5), 8);
            entity->set_local_rotation(jiggle_amount * 10);
        }
        else {
            entity->set_local_rotation(0);
        }
    }

    jiggle :: proc(using tree: Tree) {
        jiggle_time = get_time();
    }

    on_chopped :: proc(using tree: Tree, player: Player) {
        is_chopped = true;
        sprite.enabled = false;
        chopped_sprite.enabled = true;
        respawn_time = get_time() + 15;

        // Spawn wood particles (coins for now as reward)
        for i: 1..5 {
            spawn_particle(entity.local_position, player.entity, .COIN, 2);
        }
    }
}

//
// Ducks
//

Duck :: class : Component {
    sprite: Sprite_Renderer @ao_serialize;

    ao_update :: proc(using duck: Duck, dt: float) {
        rng := rng_seed(entity.id);
        duck_time := get_time() * rng_range_float(&rng, 0.8, 1.2);
        bob_amount := sin(duck_time * 2) * 0.05;
        rotation_amount := cos(duck_time * 1.5) * 5;

        sprite.entity->set_local_position(.{0, bob_amount});
        sprite.entity->set_local_rotation(rotation_amount);
    }
}

//
// NPC
//

NPC_Behaviour_Kind :: enum {
    WANDERING;
    AGGRO;
    ATTACK;
}

NPC_Behaviour :: class {
    kind: NPC_Behaviour_Kind;

    time_in_state: float;

    // WANDERING
    wander_serial: u64;
    wandering: bool;
    wander_target: v2;
    next_wander_time: float;

    // AGGRO + ATTACK
    target: Player;
    attack_direction: v2;
}

NPC :: class : Component {
    spine: Spine_Animator @ao_serialize;
    agent: Movement_Agent @ao_serialize;
    health: Health_Component;

    state_machine: State_Machine;

    behaviour_stack: List(NPC_Behaviour);
    current_behaviour: NPC_Behaviour;

    home_position: v2;
    wander_radius: float;

    WANDER_SPEED :: 150.0;

    ao_start :: proc(using this: NPC) {
        spine->awaken();

        state_machine = State_Machine.create();

        // Create variables
        is_moving := state_machine->create_variable("is_moving", .BOOL);
        attack_trigger := state_machine->create_variable("attack", .TRIGGER);
        hit_trigger := state_machine->create_variable("hit", .TRIGGER);
        die_trigger := state_machine->create_variable("die", .TRIGGER);

        // Create the main layer
        layer := state_machine->create_layer("main", 0);

        // Create states
        idle_state := layer->create_state("idle", 1.2, true);
        walk_state := layer->create_state("walk", 0.5333, true);
        attack_state := layer->create_state("bite_attack", 0.8333, false);
        hit_state := layer->create_state("hit_react", 0.4667, false);
        death_state := layer->create_state("death", 2.0333, false);
        dead_idle_state := layer->create_state("dead_idle", 0.0333, true);

        layer->set_initial_state(idle_state);

        // Idle <-> Walk transitions based on is_moving
        idle_to_walk := layer->create_transition(idle_state, walk_state, false);
        idle_to_walk->create_bool_condition(is_moving, true);

        walk_to_idle := layer->create_transition(walk_state, idle_state, false);
        walk_to_idle->create_bool_condition(is_moving, false);

        // Attack transitions
        to_attack := layer->create_global_transition(attack_state, true);
        to_attack->create_trigger_condition(attack_trigger);
        attack_to_idle := layer->create_transition(attack_state, idle_state, true);

        // Hit reaction transitions
        idle_to_hit := layer->create_global_transition(hit_state, true);
        idle_to_hit->create_trigger_condition(hit_trigger);
        hit_to_idle := layer->create_transition(hit_state, idle_state, true);

        // Death transitions (global - can die from any state)
        die_global := layer->create_global_transition(death_state, false);
        die_global->create_trigger_condition(die_trigger);
        death_to_dead_idle := layer->create_transition(death_state, dead_idle_state, true);

        // Connect state machine to spine instance - it will handle animation playback automatically
        spine.instance->set_state_machine(state_machine, true);

        health = entity->add_component(Health_Component);
        health->set_max_health(12, true);
        health.health_bar_offset = .{0, 1.5};

        current_behaviour = new(NPC_Behaviour);
        current_behaviour.kind = .WANDERING;

        agent = entity->get_component(Movement_Agent);

        home_position = entity.world_position;
        wander_radius = 5.0;
    }

    update_scale :: proc(using this: NPC, move_direction_x: float) {
        new_scale := spine.entity.local_scale;
        if move_direction_x > 0.01 {
            new_scale.x = 1;
        }
        else if move_direction_x < -0.01 {
            new_scale.x = -1;
        }
        spine.entity->set_local_scale(new_scale);
    }

    move_to_target :: proc(using this: NPC, target: v2, range: float) -> bool {
        if in_range(target - entity.world_position, range) {
            return true;
        }

        result := agent->set_path_target(target, WANDER_SPEED);
        if result.success {
            this->update_scale(result.move_direction.x);
        }
        return false;
    }

    push_behaviour :: proc(using this: NPC, behaviour: NPC_Behaviour) {
        if current_behaviour != null {
            append(&behaviour_stack, current_behaviour);
        }
        current_behaviour = behaviour;
    }

    complete_current_behaviour :: proc(using this: NPC) {
        if behaviour_stack.elements.count > 0 {
            current_behaviour = pop(&behaviour_stack);
            current_behaviour.time_in_state = 0;
        }
        else {
            current_behaviour = null;
        }
    }

    ao_update :: proc(using this: NPC, dt: float) {
        // Don't wander if dead
        agent.friction = 0.5;

        if health != null && health.is_dead {
            state_machine->set_bool("is_moving", false);
            return;
        }

        if current_behaviour == null {
            if behaviour_stack.elements.count > 0 {
                current_behaviour = pop(&behaviour_stack);
            }
            if current_behaviour == null {
                assert(behaviour_stack.elements.count == 0, "behaviour stack was empty");
                current_behaviour = new(NPC_Behaviour);
                current_behaviour.kind = .WANDERING;
            }
        }

        assert(current_behaviour != null, "current_behaviour was empty");

        current_behaviour.time_in_state += dt;

        is_moving := false;
        switch current_behaviour.kind {
            case .WANDERING: {
                // look for attack targets
                finder := make_finder(Player, entity.world_position);
                foreach player: component_iterator(Player) {
                    finder->check(player, 5);
                }
                if finder.closest != null {
                    aggro := new(NPC_Behaviour);
                    aggro.kind = .AGGRO;
                    aggro.target = finder.closest;
                    this->push_behaviour(aggro);
                }
                else {
                    current_time := get_time();
                    if current_time > current_behaviour.next_wander_time {
                        current_behaviour.wander_serial += 1;
                        rng := rng_seed(entity.id ^ current_behaviour.wander_serial);
                        current_behaviour.next_wander_time = get_time() + rng_range_float(&rng, 4, 8);
                        current_behaviour.wander_target = home_position + v2.{rng_range_float(&rng, -wander_radius, wander_radius), rng_range_float(&rng, -wander_radius, wander_radius)};
                        current_behaviour.wandering = true;
                    }

                    if current_behaviour.wandering {
                        if this->move_to_target(current_behaviour.wander_target, 0.25) {
                            current_behaviour.wandering = false;
                        }
                        else {
                            is_moving = true;
                        }
                    }
                }
            }
            case .AGGRO: {
                switch {
                    case !alive(current_behaviour.target): {
                        // Target left the game
                        this->complete_current_behaviour();
                    }
                    case !in_range(current_behaviour.target.entity.world_position - entity.world_position, 10): {
                        // Target is too far away, un-aggro
                        this->complete_current_behaviour();
                    }
                    case: {
                        // Approach the target
                        if this->move_to_target(current_behaviour.target.entity.world_position, 2.5) {
                            attack := new(NPC_Behaviour);
                            attack.kind = .ATTACK;
                            attack.target = current_behaviour.target;
                            attack.attack_direction = normalize(current_behaviour.target.entity.world_position - entity.world_position);
                            this->push_behaviour(attack);
                            state_machine->set_trigger("attack");
                        }
                        else {
                            is_moving = true;
                        }
                    }
                }
            }
            case .ATTACK: {
                this->update_scale(current_behaviour.attack_direction.x);

                agent.friction = 0;
                agent.velocity = .{};

                if current_behaviour.time_in_state > 0.25 {
                    agent.velocity = current_behaviour.attack_direction * 10;
                }
                if current_behaviour.time_in_state > 0.5 {
                    agent.velocity = .{};
                    this->complete_current_behaviour();
                }
            }
        }

        state_machine->set_bool("is_moving", is_moving);
    }

    ao_late_update :: proc(using this: NPC, dt: float) {
        if !health.is_dead && health.current_health != health.max_health {
            health->draw_health_bar(entity.world_position.y-0.001);
        }
    }

    damage :: proc(using this: NPC, amount: int, attacker: Player = null) {
        if health == null return;

        died := health->take_damage(amount);
        if died {
            state_machine->set_trigger("die");
        }
        else {
            state_machine->set_trigger("hit");

            // Aggro on attacker if not already aggro'd
            if attacker != null && current_behaviour != null && current_behaviour.kind == .WANDERING {
                aggro := new(NPC_Behaviour);
                aggro.kind = .AGGRO;
                aggro.target = attacker;
                this->push_behaviour(aggro);
            }
        }
    }
}

Food_Projectile :: class : Component {
    sprite: Sprite_Renderer @ao_serialize;
    velocity: v2;
    lifetime: float;
    damage: int;

    team: Player_Team;

    spawn_time: float;
    owner: Entity;
    hit_radius: float;

    start_rotation: float;

    ao_start :: proc(using this: Food_Projectile) {
        spawn_time = get_time();
        if hit_radius == 0 {
            hit_radius = 0.5;
        }

        rng := rng_seed(entity.id);
        start_rotation = rng_range_float(&rng, 0, 360);
    }

    ao_update :: proc(using this: Food_Projectile, dt: float) {
        time_alive := get_time() - spawn_time;
        sprite.entity->set_local_rotation(start_rotation + time_alive * 1440);

        // Move projectile
        entity->add_local_position(velocity * dt);

        destroy_self := false;

        // Check for NPC collisions
        if !destroy_self {
            foreach npc: component_iterator(NPC) {
                if npc.health == null continue;
                if npc.health.is_dead continue;

                if in_range(npc.entity.world_position - entity.world_position, hit_radius) {
                    attacker: Player = null;
                    if alive(owner) {
                        attacker = owner->get_component(Player);
                    }
                    npc->damage(damage, attacker);
                    destroy_self = true;
                    break;
                }
            }
        }

        if !destroy_self {
            foreach player: component_iterator(Player) {
                if player.health.is_dead continue;
                if alive(owner) && owner == player.entity continue;
                if player.team == team continue;
                if in_range(player.entity.world_position - entity.world_position, hit_radius) {
                    player->take_damage(1);
                    destroy_self = true;
                    {
                        sfx := default_sfx_desc();
                        sfx->set_position(player.entity.world_position);
                        sfx.volume = 0.75;
                        sfx.volume_perturb = 0.1;
                        sfx.speed_perturb = 0.2;
                        SFX.play(get_asset(SFX_Asset, "sfx/stabbed.wav"), sfx);
                    }
                    break;
                }
            }
        }

        if time_alive >= lifetime {
            destroy_self = true;
        }

        if !destroy_self {
            point: v2;
            // todo(josh): this crashes!!!:
            // if Game_Manager.bullet_navmesh->try_find_closest_point_on_navmesh(entity.world_position, &point) {
            if g_game_manager.bullet_navmesh->try_find_closest_point_on_navmesh(entity.world_position, &point) {
                if !in_range(point - entity.world_position, 0.01) {
                    destroy_self = true;
                }
            }
        }

        if destroy_self {
            hit_effect := get_asset(Prefab_Asset, "hit_effect.prefab");
            effect := instantiate(hit_effect);
            rng := rng_seed(entity.id);
            effect.first_child->set_local_rotation(rng_range_float(&rng, 0, 360));
            effect->set_local_position(entity.world_position);
            effect->queue_for_destruction(0.5);
            destroy_entity(entity);
        }
    }
}

shoot_projectile :: proc(spawn_position: v2, velocity: v2, damage: int, lifetime: float, team: Player_Team, owner: Entity, texture_path: string = "icons/burger.png") -> Entity {
    prefab := get_asset(Prefab_Asset, "food_projectile.prefab");
    entity := instantiate(prefab);
    entity->set_local_position(spawn_position);

    projectile := entity->get_component(Food_Projectile);
    projectile.velocity = velocity;
    projectile.lifetime = lifetime;
    projectile.damage = damage;
    projectile.owner = owner;
    return entity;
}

//
// Tasks
//

Task :: enum {
    NONE;

    FUEL_CANISTERS;
    RESTORE_BEACONS;
    ALIGN_TAKEOFF;
    TAKEOFF;
}

Align_Takeoff_Station :: class : Component {
    Axis :: enum {
        Yaw;
        Pitch;
    }

    interactable: Interactable @ao_serialize;

    other: Align_Takeoff_Station @ao_serialize;

    axis: Axis @ao_serialize;

    is_aligned: bool;
    locked_in: bool;

    ao_start :: proc(using this: Align_Takeoff_Station) {
        interactable.listener = this;
    }

    can_use :: proc(using this: Align_Takeoff_Station, player: Player) -> bool {
        return g_game.current_task == .ALIGN_TAKEOFF && player.team == .SURVIVOR && is_aligned == false;
    }

    on_interact :: proc(using this: Align_Takeoff_Station, player: Player) {
        {
            sfx := default_sfx_desc();
            sfx->set_position(entity.world_position);
            SFX.play(get_asset(SFX_Asset, "sfx/align_takeoff.wav"), sfx);
        }
        is_aligned = true;
        if other.is_aligned {
            // both are aligned!
            locked_in = true;
            other.locked_in = true;
            foreach player: component_iterator(Player) if player.team == .SURVIVOR {
                player->add_notification("Both axes aligned!");
            }

            complete_current_task();
        }
        else {
            foreach player: component_iterator(Player) if player.team == .SURVIVOR {
                player->add_notification(format_string("% axis aligned!", .{axis}));
            }
        }
    }
}

Takeoff_Station :: class : Component {
    interactable: Interactable @ao_serialize;

    initiated: bool;
    takeoff_timer: float;

    ao_start :: proc(using this: Takeoff_Station) {
        interactable.listener = this;
    }

    ao_update :: proc(using this: Takeoff_Station, dt: float) {
        if g_game.state != .GAMEPLAY return;
        if g_game.current_task != .TAKEOFF return;
        if initiated {
            if takeoff_timer > 0 {
                takeoff_timer -= dt;
                if takeoff_timer <= 0 {
                    takeoff_timer = 0;
                    complete_current_task();
                }
            }
        }
    }

    can_use :: proc(using this: Takeoff_Station, player: Player) -> bool {
        return g_game.current_task == .TAKEOFF && player.team == .SURVIVOR && !initiated;
    }

    on_interact :: proc(using this: Takeoff_Station, player: Player) {
        player->add_notification("Takeoff initiated!");
        initiated = true;
        takeoff_timer = 10;
    }
}

//
// Fuel Canister Task
//

REQUIRED_FUEL_CANISTERS :: 3;

Fuel_Spawn_Point :: class : Component {
    // Just a marker component to indicate a potential fuel spawn location
    // Place these around the map in the editor
}

Fuel_Canister :: class : Component {
    fuel_sprite: Sprite_Renderer @ao_serialize;
    shadow_sprite: Sprite_Renderer @ao_serialize;
    interactable: Interactable @ao_serialize;

    is_picked_up: bool;
    carrier: Player;
    last_carrier_position: v2;
    shadow_scale: v2;

    ao_start :: proc(using this: Fuel_Canister) {
        interactable.listener = this;
        shadow_scale = shadow_sprite.entity.local_scale;
    }

    ao_late_update :: proc(using this: Fuel_Canister, dt: float) {
        if is_picked_up && carrier != null {
            if alive(carrier) {
                last_carrier_position = carrier.entity.world_position;
            }
            if !alive(carrier) || carrier.health.is_dead {
                // Carrier died or disconnected, drop the canister
                drop_canister(this, last_carrier_position);
            }
            else {
                // Follow the carrier
                vector := normalize_vector_to_radius(entity.local_position - carrier.entity.local_position, 1);
                target_position := carrier.entity.local_position + vector;
                new_position := lerp(entity.local_position, target_position, 0.25);
                entity->set_local_position(new_position);

                point_in_ship: v2;
                if g_game_manager.ship_navmesh->try_find_closest_point_on_navmesh(carrier.entity.world_position, &point_in_ship) {
                    if in_range(point_in_ship - carrier.entity.world_position, 0.1) {
                        g_game.fuel_deposited += 1;
                        {
                            sfx := default_sfx_desc();
                            sfx->set_position(carrier.entity.world_position);
                            sfx.volume_perturb = 0.2;
                            sfx.speed_perturb = 0.1;
                            SFX.play(get_asset(SFX_Asset, "sfx/deposit.wav"), sfx);
                        }

                        // Check if task is complete
                        if g_game.fuel_deposited >= REQUIRED_FUEL_CANISTERS {
                            foreach player: component_iterator(Player) if player.team == .SURVIVOR {
                                player->add_notification("All fuel collected!");
                            }
                            complete_current_task();
                        }
                        else {
                            foreach player: component_iterator(Player) if player.team == .SURVIVOR {
                                player->add_notification(format_string("Fuel deposited! (% / %)", .{g_game.fuel_deposited, REQUIRED_FUEL_CANISTERS}));
                            }
                        }

                        destroy_entity(entity);
                    }
                }
            }
        }

        fuel_hover_position := v2.{0, 0};
        new_shadow_scale := shadow_scale;
        if is_picked_up {
            t := PI * get_time();
            fuel_hover_position.y = 0.4 + sin(t) * 0.2;
            new_shadow_scale = shadow_scale / (1.0 + fuel_hover_position.y);
        }
        fuel_sprite.entity->set_local_position(fuel_hover_position);
        fuel_sprite.depth_offset = -fuel_hover_position.y;
        shadow_sprite.entity->set_local_scale(new_shadow_scale);
    }

    can_use :: proc(using this: Fuel_Canister, player: Player) -> bool {
        return g_game.current_task == .FUEL_CANISTERS
            && player.team == .SURVIVOR
            && !is_picked_up
            && !is_player_carrying_canister(player);
    }

    on_interact :: proc(using this: Fuel_Canister, player: Player) {
        pickup_canister(this, player);
    }
}

is_player_carrying_canister :: proc(player: Player) -> bool {
    foreach canister: component_iterator(Fuel_Canister) {
        if canister.carrier == player {
            return true;
        }
    }
    return false;
}

get_player_canister :: proc(player: Player) -> Fuel_Canister {
    foreach canister: component_iterator(Fuel_Canister) {
        if canister.carrier == player {
            return canister;
        }
    }
    return null;
}

pickup_canister :: proc(using canister: Fuel_Canister, player: Player) {
    is_picked_up = true;
    carrier = player;
    player->add_notification("Bring the fuel canister to the ship!");
    {
        sfx := default_sfx_desc();
        sfx->set_position(canister.entity.world_position);
        sfx.volume_perturb = 0.1;
        sfx.speed_perturb = 0.1;
        SFX.play(get_asset(SFX_Asset, "sfx/pickup_fuel.wav"), sfx);
    }
}

drop_canister :: proc(using canister: Fuel_Canister, position: v2) {
    entity->set_local_position(position);
    is_picked_up = false;
    carrier = null;
    {
        sfx := default_sfx_desc();
        sfx->set_position(canister.entity.world_position);
        sfx.volume_perturb = 0.1;
        sfx.speed_perturb = 0.1;
        SFX.play(get_asset(SFX_Asset, "sfx/drop_fuel.wav"), sfx);
    }
}

//
// Beacon Task
//

REQUIRED_BEACONS :: 3;
BEACON_RESTORE_TIME :: 10.0;
BEACON_PROXIMITY_RANGE :: 3.0;
BEACON_DECAY_RATE :: 0.5; // Progress lost per second when no survivor nearby

Beacon_Spawn_Point :: class : Component {
    // Just a marker component to indicate a potential beacon spawn location
    // Place these around the map in the editor
}

Beacon_State :: enum {
    INACTIVE;    // Not yet interacted with
    RESTORING;   // Being restored (survivors nearby)
    RESTORED;    // Fully restored
}

Beacon :: class : Component {
    interactable: Interactable @ao_serialize;
    sprite: Sprite_Renderer @ao_serialize;

    state: Beacon_State;
    restore_progress: float; // 0 to BEACON_RESTORE_TIME
    survivor_nearby: bool;

    ao_start :: proc(using this: Beacon) {
        interactable.listener = this;
        state = .INACTIVE;
        restore_progress = 0;
    }

    ao_update :: proc(using this: Beacon, dt: float) {
        if g_game.current_task != .RESTORE_BEACONS {
            sprite.color.w = 0;
            return;
        }
        if state == .RESTORED return;

        // Check if any survivor is nearby
        survivor_nearby = false;
        foreach player: component_iterator(Player) {
            if player.team != .SURVIVOR continue;
            if player.health.is_dead continue;
            if in_range(player.entity.world_position - entity.world_position, BEACON_PROXIMITY_RANGE) {
                survivor_nearby = true;
                break;
            }
        }

        if state == .RESTORING {
            if survivor_nearby {
                // Progress increases when survivor nearby
                restore_progress += dt;
                if restore_progress >= BEACON_RESTORE_TIME {
                    restore_progress = BEACON_RESTORE_TIME;
                    state = .RESTORED;
                    on_beacon_restored(this);
                }
            }
            else {
                // Progress decays when no survivor nearby
                restore_progress -= dt * BEACON_DECAY_RATE;
                if restore_progress <= 0 {
                    restore_progress = 0;
                    state = .INACTIVE;
                }
            }
        }

        // Update sprite tint based on state
        switch state {
            case .INACTIVE: {
                sprite.color = .{0.5, 0.5, 0.5, 0.2};
            }
            case .RESTORING: {
                progress_t := restore_progress / BEACON_RESTORE_TIME;
                sprite.color = lerp(v4.{1, 0.5, 0, 0.2}, .{0, 1, 0.5, 0.2}, progress_t);
            }
            case .RESTORED: {
                sprite.color = .{0, 1, 0.5, 0.2};
            }
        }
    }

    ao_late_update :: proc(using this: Beacon, dt: float) {
        if g_game.current_task != .RESTORE_BEACONS return;
        if state == .RESTORED return;

        // Draw progress bar UI above beacon
        if state == .RESTORING {
            UI.push_world_draw_context();
            defer UI.pop_draw_context();

            UI.push_layer(100);
            defer UI.pop_layer();

            bar_width := 1.5;
            bar_height := 0.2;
            bar_y_offset := 1.5;

            bar_pos := entity.world_position + v2.{0, bar_y_offset};
            bar_bg_rect := Rect.{
                .{bar_pos.x - bar_width/2, bar_pos.y - bar_height/2},
                .{bar_pos.x + bar_width/2, bar_pos.y + bar_height/2}
            };

            // Background
            UI.quad(bar_bg_rect, white_sprite, .{0.1, 0.1, 0.1, 0.8});

            // Progress fill
            progress_t := restore_progress / BEACON_RESTORE_TIME;
            fill_rect := bar_bg_rect;
            fill_rect.max.x = fill_rect.min.x + (fill_rect.max.x - fill_rect.min.x) * progress_t;

            fill_color := v4.{1, 0, 0, 1};
            if survivor_nearby {
                fill_color = lerp(v4.{1, 1, 0, 1}, .{0, 1, 0, 1}, progress_t);
            }
            UI.quad(fill_rect, white_sprite, fill_color);
        }
    }

    can_use :: proc(using this: Beacon, player: Player) -> bool {
        return g_game.current_task == .RESTORE_BEACONS
            && player.team == .SURVIVOR
            && state == .INACTIVE;
    }

    on_interact :: proc(using this: Beacon, player: Player) {
        state = .RESTORING;
        player->add_notification("Stay near the beacon to restore it!");
    }
}

on_beacon_restored :: proc(beacon: Beacon) {
    g_game.beacons_restored += 1;
    {
        sfx := default_sfx_desc();
        sfx->set_position(beacon.entity.world_position);
        SFX.play(get_asset(SFX_Asset, "sfx/beacon_restore.wav"), sfx);
    }

    if g_game.beacons_restored >= REQUIRED_BEACONS {
        foreach player: component_iterator(Player) if player.team == .SURVIVOR {
            player->add_notification("All beacons restored!");
        }
        complete_current_task();
    }
    else {
        foreach player: component_iterator(Player) if player.team == .SURVIVOR {
            player->add_notification(format_string("Beacon restored! (% / %)", .{g_game.beacons_restored, REQUIRED_BEACONS}));
        }
    }
}

//
// Utils
//

player_set_trigger :: proc(player: Player, trigger: string) {
    player.animator.instance.state_machine->set_trigger(trigger);
}

linear_step :: proc(start: float, end: float, time: float) -> float {
    // 0 when before start, 1 when after end, 0.5 when in the middle
    t := clamp(time - start, 0, end - start);
    return t / (end - start);
}