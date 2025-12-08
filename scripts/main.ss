import "core:core.ss"

import "other_script.ss"

white_sprite:    Texture_Asset;
modal_bg_sprite: Texture_Asset;
button_green:    Texture_Asset;
button_red:      Texture_Asset;
button_orange:   Texture_Asset;

keybind_dodge_roll: Keybind;

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

g_game: struct {
    state: Game_State;

    tasks: [2]Task;
    current_task: Task;
    current_task_index: int;

    winner: Player_Team;
    end_game_screen_timer: float;
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

player_count_last_frame: int;
round_countdown_timer: float;

g_game_manager: Game_Manager;

ao_start :: proc() {
    white_sprite    = get_asset(Texture_Asset, "$AO/white.png");
    modal_bg_sprite = get_asset(Texture_Asset, "ui/modal_simple_white1.png");
    button_green    = get_asset(Texture_Asset, "ui/button_large_green1.png");
    button_red      = get_asset(Texture_Asset, "ui/button_large_red1.png");
    button_orange   = get_asset(Texture_Asset, "ui/button_large_yellow2.png");

    Economy.register_currency("Food", "icons/burger.png");
    Economy.register_currency("Coins", "icons/coin.png");

    keybind_dodge_roll = Keybinds.register("Roll", .SPACE);

    server_rng = rng_seed((get_time() * 1000000).(u64));
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

ao_update :: proc(dt: float) {
    switch g_game.state {
        case .RESET_MAP: {
            foreach player: component_iterator(Player) {
                player.team = .SURVIVOR;
            }
            foreach takeoff: component_iterator(Takeoff_Station) {
                takeoff.initiated = false;
            }
            foreach takeoff: component_iterator(Align_Takeoff_Station) {
                takeoff.is_aligned = false;
                takeoff.locked_in = false;
            }
            g_game.state = .WAITING_FOR_PLAYERS;
        }
        case .WAITING_FOR_PLAYERS: {
            player_count := 0;
            foreach player: component_iterator(Player) {
                player_count += 1;
            }
            defer player_count_last_frame = player_count;

            REQUIRED_PLAYERS :: 3;
            if player_count < REQUIRED_PLAYERS {
                draw_big_game_text("Waiting for players...");
                draw_small_game_text("% / %", .{player_count, REQUIRED_PLAYERS});
            }
            else {
                if player_count_last_frame < REQUIRED_PLAYERS {
                    round_countdown_timer = ROUND_COUNTDOWN_TIMER.(float);
                }
                else {
                    if player_count_last_frame != player_count {
                        round_countdown_timer = max(round_countdown_timer, ROUND_COUNTDOWN_TIMER_WHEN_PLAYER_COUNT_CHANGES.(float));
                    }
                }
                round_countdown_timer -= dt;

                draw_big_game_text("Starting round in %s...", .{round_countdown_timer.(int) + 1});
                draw_small_game_text("% players", .{player_count});

                if round_countdown_timer <= 0 {
                    round_countdown_timer = 0;
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

                    g_game.tasks[0] = .ALIGN_TAKEOFF;
                    g_game.tasks[1] = .TAKEOFF;
                    g_game.current_task_index = 0;
                    g_game.current_task = g_game.tasks[g_game.current_task_index];
                }
            }
        }
        case .GAMEPLAY: {
            survivors_left := 0;
            foreach player: component_iterator(Player) {
                if player.team == .SURVIVOR {
                    survivors_left += 1;
                }
            }
            if survivors_left == 0 {
                foreach player: component_iterator(Player) {
                    player->remove_ghost_reason("spectator");
                    player.team = .SURVIVOR;
                    respawn_player(player);
                }

                g_game.winner = .ZOMBIE;
                g_game.state = .END_GAME_SCREEN;
            }
            else {
                if g_game.current_task_index >= g_game.tasks.count {
                    g_game.winner = .SURVIVOR;
                    g_game.state = .END_GAME_SCREEN;
                }
            }
        }
        case .END_GAME_SCREEN: {
            g_game.end_game_screen_timer += dt;
            maybe_local := try_get_local_player();
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
            switch g_game.winner {
                case .SURVIVOR: {
                    draw_big_game_text("Survivors win!");
                }
                case .ZOMBIE: {
                    draw_big_game_text("Zombies win!");
                }
            }

            if g_game.end_game_screen_timer >= 5.0 {
                g_game = .{};
            }
        }
    }
}

respawn_player :: proc(using player: Player) {
    player.animator.instance.color_multiplier = .{1, 1, 1, 1};
    player.health->set_max_health(1, true);

    switch team {
        case .SURVIVOR: {
            player.entity->set_local_position(g_game_manager.survivor_spawn.world_position);
        }
        case .ZOMBIE: {
            player.entity->set_local_position(g_game_manager.zombie_spawn.world_position);
        }
    }
}

ao_can_use_interactable :: proc(interactable: Interactable, player: Player) -> bool {
    if interactable.listener != null switch #object_type(interactable.listener) {
        case Sell_Zone: return interactable.listener.(Sell_Zone)->can_use(player);
        case Align_Takeoff_Station: return interactable.listener.(Align_Takeoff_Station)->can_use(player);
        case Takeoff_Station: return interactable.listener.(Takeoff_Station)->can_use(player);
    }
    return true;
}

ao_on_interactable_used :: proc(interactable: Interactable, player: Player) {
    if interactable.listener != null switch #object_type(interactable.listener) {
        case Sell_Zone: interactable.listener.(Sell_Zone)->on_interact(player);
        case Align_Takeoff_Station: interactable.listener.(Align_Takeoff_Station)->on_interact(player);
        case Takeoff_Station: interactable.listener.(Takeoff_Station)->on_interact(player);
    }
}

Game_Manager :: class : Component {
    survivor_spawn: Entity @ao_serialize;
    zombie_spawn:   Entity @ao_serialize;

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

                if params.can_use {
                    if interact.hovering {
                        result.aim = true;
                        params.drag_direction = normalize(get_mouse_world_position() - player.entity.world_position);
                    }

                    if interact.active {
                        result.shoot = true;
                    }
                }
            }
        }
    }

    if result.aim {
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
        if update_always_aiming_ability(player, &params).shoot {
            if params.can_use {
                ability.current_cooldown = 0.5;
                shoot_projectile(player.entity.world_position, params.drag_direction * 15.0, 1, player.team, player.entity);
            }
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
            ability.current_cooldown = 1.0;
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
        disable_movement_inputs = true;
        player->player_set_trigger("dodge_roll");
        original_friction = player.agent.friction;
        player.agent.friction = 0;
        player->set_facing_right(direction.x > 0);
        player.animator.instance.color_multiplier = .{1, 1, 1, 0.5};
    }

    controller_update :: proc(using this: Roll_Controller, dt: float) {
        player.agent.velocity = direction * 10;
        if elapsed_time > 0.5 {
            end_controller(player, false);
        }
    }

    controller_end :: proc(using this: Roll_Controller, interrupt: bool) {
        player.animator.instance.color_multiplier = .{1, 1, 1, 1};
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
        ability.keybind_override = keybind_dodge_roll;
    }

    can_use :: proc(ability: Slash_Ability, player: Player) -> bool {
        return true;
    }

    on_update :: proc(ability: Slash_Ability, player: Player, params: Ability_Update_Params) {
        if update_always_aiming_ability(player, &params).shoot {
            if params.can_use {
                ability.current_cooldown = 0.5;

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
        player->player_set_trigger("dodge_roll");
        original_friction = player.agent.friction;
        player.agent.friction = 0;
        player->set_facing_right(direction.x > 0);
    }

    controller_update :: proc(using this: Slash_Controller, dt: float) {
        foreach other: component_iterator(Player) {
            if other.team == player.team continue;
            if in_range(other.entity.world_position - player.entity.world_position, 0.4) {
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
            }
        }

        player.agent.velocity = direction * 10;
        if elapsed_time > 0.5 {
            end_controller(player, false);
        }
    }

    controller_end :: proc(using this: Slash_Controller, interrupt: bool) {
        player.agent.friction = original_friction;
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
    controller_begin :: proc(using this: Roll_Controller) {
        freeze_player = true;
        player->add_name_invisibility_reason("death");
        player->player_set_trigger("death");
    }

    controller_update :: proc(using this: Roll_Controller, dt: float) {
        time_until_respawn := 5.0 - elapsed_time;
        if player->is_local() {
            draw_big_game_text("Respawning in %s", .{time_until_respawn.(int) + 1});
        }
        if time_until_respawn <= 0 {
            end_controller(player, false);
        }
    }

    controller_end :: proc(using this: Roll_Controller, interrupt: bool) {
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

Player :: class : Player_Base {
    team: Player_Team;

    last_food_arrive_time: float;
    last_coin_arrive_time: float;

    mouth_stat: int;
    stomach_stat: int;
    chew_stat: int;

    total_things_eaten: int;

    upgrade_menu_open: bool;

    upgrade_menu_tab_index: int;

    health: Health_Component;

    active_ability: Ability_Base;

    get_max_food :: proc(using this: Player) -> int {
        return 8 + (stomach_stat - 1) * 3;
    }

    take_damage :: proc(using this: Player, damage: int) {
        if health.is_dead {
            return;
        }
        health->take_damage(damage);
        if health.is_dead {
            controller := new(Death_Controller);
            this->set_controller(controller);
        }
    }

    ao_start :: proc(using this: Player) {
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

        {
            register_ability(this, Interact_Ability);
            register_ability(this, Shoot_Ability);
            register_ability(this, Dodge_Roll);
            register_ability(this, Slash_Ability);
        }
    }

    ao_update :: proc(using this: Player, dt: float) {
        switch team {
            case .SURVIVOR: {
                agent.movement_speed = 250;
            }
            case .ZOMBIE: {
                agent.movement_speed = 325;
            }
            case .SPECTATOR: {
                agent.movement_speed = 400;
            }
        }

        if this->is_local_or_server() {
            // Top UI - Currency Display
            {
                UI.push_layer(100);
                defer UI.pop_layer();

                // Food display (top left)
                {
                    food_icon_rect := UI.get_safe_screen_rect()->subrect(0, 1, 0, 1)->grow(0, 60, 60, 0)->offset(20, -20);

                    food_icon := get_asset(Texture_Asset, "icons/burger.png");
                    UI.quad(food_icon_rect, food_icon);

                    effect_t := Ease.T(get_time() - last_food_arrive_time, 0.5);
                    food_ts := UI.default_text_settings();
                    food_ts.size = lerp(44.0, 36, effect_t);
                    food_ts.valign = .CENTER;
                    food_ts.halign = .LEFT;
                    food_ts.color = lerp(v4.{0, 1, 0, 1}, .{1, 1, 1, 1}, effect_t);

                    text_rect := UI.get_safe_screen_rect()->subrect(0, 1, 0, 1)->grow(0, 200, 60, 0)->offset(90, -20);

                    food_amount := Economy.get_balance(this, "Food");
                    max_food := get_max_food(this);
                    UI.text(text_rect, food_ts, "%/%", .{food_amount, max_food});
                }

                // Coins display (to the right of food)
                {
                    coin_icon_rect := UI.get_safe_screen_rect()->subrect(0, 1, 0, 1)->grow(0, 60, 60, 0)->offset(270, -20);

                    coin_icon := get_asset(Texture_Asset, "icons/coin.png");
                    UI.quad(coin_icon_rect, coin_icon);

                    coin_effect_t := Ease.T(get_time() - last_coin_arrive_time, 0.5);
                    coin_ts := UI.default_text_settings();
                    coin_ts.size = lerp(44.0, 36, coin_effect_t);
                    coin_ts.valign = .CENTER;
                    coin_ts.halign = .LEFT;
                    coin_ts.color = lerp(v4.{1, 0.843, 0, 1}, .{1, 1, 1, 1}, coin_effect_t); // Gold to white

                    text_rect := UI.get_safe_screen_rect()->subrect(0, 1, 0, 1)->grow(0, 200, 60, 0)->offset(340, -20);

                    coin_amount := Economy.get_balance(this, "Coins");
                    UI.text(text_rect, coin_ts, "%", .{coin_amount});
                }
            }

            // upgrade button
            {
                ts := UI.default_text_settings();
                bs := UI.default_button_settings();
                bs.sprite = button_orange;
                bs.press_scaling = 1;
                rect := UI.get_safe_screen_rect()->subrect(0, 0.5, 0, 0.5)->offset(10, 5)->grow(75, 175, 0, 0);
                if UI.button(rect, bs, ts, "Upgrades").clicked {
                    upgrade_menu_open = true;
                    upgrade_menu_tab_index = 0;
                }
            }

            {
                stat_ts := UI.default_text_settings();
                stat_ts.size = 32;
                stat_ts.color = .{1, 1, 1, 1};
                stat_ts.valign = .TOP;
                stat_ts.halign = .LEFT;
                text_rect := UI.get_safe_screen_rect()->subrect(0, 0.5, 0, 0.5)->offset(10, 0);
                UI.text(text_rect, stat_ts, "Mouth: %", .{mouth_stat});
                text_rect = text_rect->offset(0, -30);
                UI.text(text_rect, stat_ts, "Stomach: %", .{stomach_stat});
                text_rect = text_rect->offset(0, -30);
                UI.text(text_rect, stat_ts, "Chew: %", .{chew_stat});
            }

            if upgrade_menu_open {
                Grid_Layout :: struct {
                    r: Rect;
                    w: int;
                    h: int;
                    x: int;
                    y: int;
                    cell_w: float;
                    cell_h: float;
                    margin: float;

                    next :: proc(using grid: ref Grid_Layout) -> Rect {
                        x += 1;
                        if x >= w {
                            x = 0;
                            y -= 1;
                        }

                        ox := margin + x.(float) * (cell_w + margin);
                        oy := margin + y.(float) * (cell_h + margin);

                        return .{
                            .{ r.min.x + ox, r.min.y + oy },
                            .{ r.min.x + ox + cell_w, r.min.y + oy + cell_h }
                        };
                    }
                }

                make_grid_layout :: proc(rect: Rect, w: int, h: int, margin: float) -> Grid_Layout {
                    scale := UI.get_current_scale_factor();
                    m := margin * scale;

                    full_w := rect.max.x - rect.min.x;
                    full_h := rect.max.y - rect.min.y;

                    cell_w := (full_w - (w + 1).(float) * m) / w.(float);
                    cell_h := (full_h - (h + 1).(float) * m) / h.(float);

                    return .{
                        rect,
                        w,
                        h,
                        -1,
                        h - 1,
                        cell_w,
                        cell_h,
                        m
                    };
                }

                UI.push_id("upgrades");
                defer UI.pop_id();

                modal_bg_bs := UI.default_button_settings();
                modal_bg_bs.sprite = white_sprite;
                modal_bg_bs.color          = .{0, 0, 0, 0.8};
                modal_bg_bs.hovered_color  = .{0, 0, 0, 0.8};
                modal_bg_bs.pressed_color  = .{0, 0, 0, 0.8};
                modal_bg_bs.disabled_color = .{0, 0, 0, 0.8};
                if UI.button(UI.get_screen_rect(), modal_bg_bs, .{}, "").clicked {
                    upgrade_menu_open = false;
                }

                tab_names := ([4]string).{"Eat", "Chop", "Fight", "???"};
                unlocked_tabs: [4]bool;
                unlock_strings: [4]string;

                modal_rect := UI.get_screen_rect()->subrect(0.5, 0.5, 0.5, 0.5)->grow(300, 500, 300, 500);
                tab_count := 4;
                tab_ts := UI.default_text_settings();
                tab_ts.offset = .{0, 25};
                tab_bs := UI.default_button_settings();
                tab_bs.press_scaling;
                tab_bs.sprite = modal_bg_sprite;

                for i: 0..tab_names.count-1 {
                    tab_name := tab_names[i];
                    switch tab_name {
                        case "Eat": {
                            // always unlocked
                            unlocked_tabs[i] = true;
                        }
                        case "Chop": {
                            if chew_stat >= 10 && mouth_stat >= 10 && stomach_stat >= 10 {
                                unlocked_tabs[i] = true;
                            }
                            else {
                                unlock_strings[i] = "Level all Eat stats to 10 to unlock.";
                            }
                        }
                        case: {
                            unlock_strings[i] = "idk yet man";
                        }
                    }

                    UI.push_id("tab%", .{i});
                    defer UI.pop_id();

                    tab_rect := modal_rect->subrect(0, 1, 0, 1)->grow(60, 200, 50, 0)->offset(50, 0)->offset(210 * i.(float), 0);
                    if upgrade_menu_tab_index == i {
                        tab_rect = tab_rect->offset(0, 25);
                    }
                    name_to_draw := tab_name;
                    if !unlocked_tabs[i] {
                        name_to_draw = "???";
                    }
                    if UI.button(tab_rect, tab_bs, tab_ts, name_to_draw).clicked {
                        upgrade_menu_tab_index = i;
                    }
                }

                UI.button(modal_rect, .{}, .{}, "bg");
                UI.quad(modal_rect, modal_bg_sprite);

                {
                    draw_stat_row :: proc(grid: ref Grid_Layout, stat: ref int, name: string, desc: string, player: Player) -> bool {
                        UI.push_id(name);
                        defer UI.pop_id();

                        rect := grid->next();
                        UI.quad(rect, modal_bg_sprite, .{0.25, 0.25, 0.25, 1});

                        title_rect := rect->subrect(0, 1, 0, 1)->offset(25, -25);
                        ts := UI.default_text_settings();
                        ts.size = 48;
                        ts.halign = .LEFT;
                        ts.valign = .TOP;
                        UI.text(title_rect, ts, "%: %", .{name, stat ref});
                        title_rect = title_rect->offset(0, -75);
                        ts.size = 32;
                        UI.text(title_rect, ts, desc);

                        // Calculate upgrade cost
                        upgrade_cost := (pow(1.25, stat ref.(float)) * 10).(s64);
                        can_afford := Economy.can_withdraw_currency(player, "Coins", upgrade_cost);

                        button_rect := rect->subrect(1, 0.5, 1, 0.5)->grow(50, 0, 50, 200)->offset(-10, 0);
                        bs := UI.default_button_settings();
                        if can_afford {
                            bs.sprite = button_green;
                        }
                        else {
                            bs.sprite = button_red;
                        }
                        bs.press_scaling = 1;
                        result := false;

                        upgrade := UI.begin_button(button_rect, bs, .{}, ""); {
                            defer UI.end_button();

                            if upgrade.clicked {
                                if can_afford {
                                    Economy.withdraw_currency(player, "Coins", upgrade_cost);
                                    stat ref += 1;
                                    result = true;
                                }
                                else {
                                    Notifier.notify("Not enough coins!");
                                }
                            }

                            // Draw "Upgrade" text in top half
                            {
                                top_text_rect := button_rect->offset(0, 25);
                                ts := UI.default_text_settings();
                                ts.size = 40;
                                UI.text(top_text_rect, ts, "Upgrade");

                                // Draw cost in bottom half
                                bottom_text_rect := button_rect->offset(0, -25);
                                ts.size = 36;
                                UI.text(bottom_text_rect, ts, "% coins", .{upgrade_cost});
                            }
                        }

                        return result;
                    }

                    if !unlocked_tabs[upgrade_menu_tab_index] {
                        ts := UI.default_text_settings();
                        ts.size = 32;
                        UI.text(modal_rect, ts, unlock_strings[upgrade_menu_tab_index]);
                    }
                    else {
                        switch upgrade_menu_tab_index {
                            case 0: {
                                // Eat
                                grid := make_grid_layout(modal_rect, 1, 3, 10);

                                if draw_stat_row(&grid, &mouth_stat,   "Mouth",   "Upgrade your mouth to eat bigger items.",   this) { Save.set_int(this, "mouth_level",   mouth_stat);   }
                                if draw_stat_row(&grid, &stomach_stat, "Stomach", "Upgrade your stomach to hold more food.",   this) { Save.set_int(this, "stomach_level", stomach_stat); }
                                if draw_stat_row(&grid, &chew_stat,    "Chew",    "Upgrade your chewing to eat items faster.", this) { Save.set_int(this, "chew_level",    chew_stat);    }
                            }
                            case 1: {
                                // Chop
                            }
                        }
                    }
                }


                // Reset button below the window
                {
                    reset_button_rect := modal_rect->subrect(0.5, 0, 0.5, 0)->grow(75, 150, 75, 150)->offset(0, -100);

                    UI.push_id("reset_button");
                    defer UI.pop_id();

                    reset_bs := UI.default_button_settings();
                    reset_bs.sprite = button_red;
                    reset_bs.press_scaling = 1;

                    ts := UI.default_text_settings();

                    if UI.button(reset_button_rect, reset_bs, ts, "Reset Save Data").clicked {
                        reset_player_save :: proc(using this: Player) {
                            mouth_stat         = 1; Save.set_int(this, "mouth_level",        1);
                            stomach_stat       = 1; Save.set_int(this, "stomach_level",      1);
                            chew_stat          = 1; Save.set_int(this, "chew_level",         1);
                            total_things_eaten = 0; Save.set_int(this, "total_things_eaten", 0);

                            // Reset currencies
                            Economy.withdraw_currency(this, "Food",  Economy.get_balance(this, "Food"));
                            Economy.withdraw_currency(this, "Coins", Economy.get_balance(this, "Coins"));
                        }

                        reset_player_save(this);
                        upgrade_menu_open = false;
                        Notifier.notify("Save data reset!");
                    }
                }
            }
        }

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
        // scroll := get_mouse_scroll(true);
        // camera.size -= camera.size * scroll * dt;

        if g_game.state == .GAMEPLAY {
            if this->is_local_or_server() {
                switch team {
                    case .SURVIVOR: {
                        draw_ability_button(this, Shoot_Ability, 0);
                        draw_ability_button(this, Dodge_Roll, 1);
                    }
                    case .ZOMBIE: {
                        draw_ability_button(this, Slash_Ability, 0);
                    }
                }
            }

            UI.push_world_draw_context();
            defer UI.pop_draw_context();

            if !health.is_dead && this->will_draw_name() {
                health->draw_health_bar(entity.world_position.y-0.001);
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
            hit_radius = 0.4;
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
                    break;
                }
            }
        }
        if time_alive >= lifetime {
            destroy_self = true;
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

shoot_projectile :: proc(spawn_position: v2, velocity: v2, damage: int, team: Player_Team, owner: Entity, texture_path: string = "icons/burger.png", lifetime: float = 3.0) -> Entity {
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
    aligned_timer: float;

    ao_start :: proc(using this: Align_Takeoff_Station) {
        interactable.listener = this;
    }

    ao_update :: proc(using this: Align_Takeoff_Station, dt: float) {
        if g_game.state != .GAMEPLAY return;
        if g_game.current_task != .TAKEOFF return;
        if is_aligned && !locked_in {
            if aligned_timer > 0 {
                aligned_timer -= dt;
                if aligned_timer <= 0 {
                    aligned_timer = 0;
                    is_aligned = false;
                    Notifier.notify(format_string("% alignment lost!", .{axis}));
                }
            }
        }
    }

    can_use :: proc(using this: Align_Takeoff_Station, player: Player) -> bool {
        return g_game.current_task == .ALIGN_TAKEOFF && player.team == .SURVIVOR && is_aligned == false;
    }

    on_interact :: proc(using this: Align_Takeoff_Station, player: Player) {
        Notifier.notify(format_string("% axis aligned!", .{axis}));
        is_aligned = true;
        aligned_timer = 4;
        if other.is_aligned {
            // both are aligned!
            locked_in = true;
            other.locked_in = true;
            Notifier.notify("Both axes aligned!");

            complete_current_task();
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
            draw_big_game_text("Takeoff in %{.1} seconds...", .{takeoff_timer});
        }
    }

    can_use :: proc(using this: Takeoff_Station, player: Player) -> bool {
        return g_game.current_task == .TAKEOFF && player.team == .SURVIVOR && !initiated;
    }

    on_interact :: proc(using this: Takeoff_Station, player: Player) {
        Notifier.notify("Takeoff initiated!");
        initiated = true;
        takeoff_timer = 10;
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