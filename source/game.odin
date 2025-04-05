#+feature dynamic-literals
package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:os/os2"
import "core:strings"
import rl "vendor:raylib"

RUNNING_WITHOUT_HOT_RELOAD :: #config(RUNNING_WITHOUT_HOT_RELOAD, false)
PATH_PREFIX :: ("../assets/" when RUNNING_WITHOUT_HOT_RELOAD else "assets/")

far_left: f32 = -15
total_width: f32 = 30

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720


LevelDescription :: struct {
	stack_counts: u16,
	low_size:     i32,
	high_size:    i32,
}

Card :: struct {
	name:            string,
	function_to_run: proc(),
}


setup_stacks_for_level :: proc(level_num: u64) {
	using globals

	clear(&stack_heights)
	rand.reset(level_num)
	level_to_description := map[u64]LevelDescription {
		0 = {3, 10, 15},
		1 = {1, 17, 21},
	}

	desc := level_to_description[level_num]
	for i in 0 ..< desc.stack_counts {
		append(&stack_heights, rand.int31_max(desc.high_size - desc.low_size) + desc.low_size)
	}
	fmt.println("stack_heights was", stack_heights)
}

remove_from_stack :: proc(stack_index: int, amount: i32) {
	using globals
	fmt.println("about to remove from stack")
	if stack_index >= 0 && stack_index < len(stack_heights) {
		stack_heights[stack_index] -= amount
		fmt.println("successfully removed from stack")
	}
	fmt.println("after state was", stack_heights)

}

Game_Memory :: struct {
	is_showing_wheel_spinning: bool,
	run:                       bool,
	stack_heights:             [dynamic]i32,
	current_level:             u64,
	cards_in_hand:             [dynamic]Card,
	arrow_texture:             rl.Texture2D,
}

COLOR_PALETTE :: [5]rl.Color {
	rl.Color{60, 21, 24, 255},
	rl.Color{105, 20, 14, 255},
	rl.Color{164, 66, 0, 255},
	rl.Color{213, 137, 54, 255},
	rl.Color{242, 243, 174, 255},
}

globals: ^Game_Memory


get_main_camera :: proc() -> rl.Camera3D {
	using rl
	return {
		position = Vector3{0, 5, 15},
		target = Vector3{0, 0, 0},
		up = Vector3{0, 1, 0},
		projection = CameraProjection.PERSPECTIVE,
		fovy = 90,
	}
}

main :: proc() {
	when ODIN_DEBUG {
		return
	}
	default_allocator := context.allocator
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, default_allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)


	game_init_window()
	game_init()


	for game_should_run() {
		game_update()
		free_all(context.temp_allocator)
	}
	game_shutdown()
	game_shutdown_window()
	reset_tracking_allocator(&tracking_allocator)
}

update :: proc() {
	using globals
	using rl
	input: rl.Vector2

	if IsKeyPressed(.SPACE) {
		remove_from_stack(0, 3)
	}

	if IsKeyPressed(.R) {
		setup_stacks_for_level(current_level)
	}

	if IsKeyPressed(.G) {
		result, output := os2.process_start({command = {"build_hot_reload.bat"}})
		fmt.println(result, output)
	}
	if rl.IsKeyPressed(.ESCAPE) {
		globals.run = false
	}
}

get_ui_camera :: proc() -> rl.Camera2D {
	return rl.Camera2D{}
}

draw :: proc() {
	using rl, globals
	rl.BeginDrawing()
	// https://coolors.co/3c1518-69140e-a44200-d58936-f2f3ae
	background_color := COLOR_PALETTE[1]
	line_color := COLOR_PALETTE[4]
	rl.ClearBackground(background_color)
	// fmt.println(line_color)

	rl.BeginMode3D(get_main_camera())
	// fmt.println("height", len(stack_heights))
	for i in 0 ..< len(stack_heights) {
		centering := (1.0 / f32(len(stack_heights))) / 2.0
		pos := Vector3 {
			far_left +
			(centering * total_width) +
			total_width * (f32(i) / f32(len(stack_heights))),
			0,
			0,
		}
		rl.DrawCube(pos, 4, 4, 4, RED)
		rl.DrawCubeWires(pos, 4, 4, 4, BLACK)
		// fmt.println(pos)
	}

	rl.EndMode3D()

	// rl.BeginMode2D(get_ui_camera())
	// DrawTexture(globals.arrow_texture, 200, 300, BLUE)

	//these work

	source := Rectangle{0, 0, 256, 256}
	dest := Rectangle{SCREEN_WIDTH / 2, SCREEN_HEIGHT * 7.0 / 8.0, 256, 256}
	DrawTexturePro(
		globals.arrow_texture,
		source,
		dest,
		{source.width / 2, source.height / 2},
		90,
		BLUE,
	)
	DrawTexturePro(
		globals.arrow_texture,
		source,
		dest,
		{source.width / 2, source.height / 2},
		270,
		BLUE,
	)
	// rl.EndMode2D()

	rl.EndDrawing()
}

@(export)
game_update :: proc() {
	update()
	draw()
}

@(export)
game_init_window :: proc() {
	rl.InitWindow(1280, 720, "Odin + Raylib + Hot Reload template!")
	// rl.SetWindowPosition(0, 200)
	if rl.GetMonitorCount() >= 2 {
		rl.SetWindowMonitor(1)
		rl.SetWindowPosition(2050, -400)
	} else {
		rl.SetWindowPosition(200, 200)
	}
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.SetTargetFPS(60)
	rl.SetExitKey(nil)
	rl.InitAudioDevice()
}

get_texture_simple_path :: proc(filename: string) -> rl.Texture2D {
	return rl.LoadTexture(fmt.ctprint(strings.concatenate({PATH_PREFIX, filename})))
}

@(export)
game_init :: proc() {
	using rl, globals
	globals = new(Game_Memory)

	globals^ = Game_Memory {
		run           = true,
		current_level = 0,
		arrow_texture = get_texture_simple_path("up_arrow.png"),
	}
	setup_stacks_for_level(current_level)

	game_hot_reloaded(globals)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return globals.run
}

@(export)
game_shutdown :: proc() {
	free(globals)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return globals
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	globals = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside
	// `globals`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}


reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
	err := false

	for _, value in a.allocation_map {
		fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
		err = true
	}

	mem.tracking_allocator_clear(a)
	return err
}
