package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os/os2"
import rl "vendor:raylib"

PIXEL_WINDOW_HEIGHT :: 180

Game_Memory :: struct {
	is_showing_wheel_spinning: bool,
	run:                       bool,
}

COLOR_PALETTE :: [5]rl.Color {
	rl.Color{60, 21, 24, 255},
	rl.Color{105, 20, 14, 255},
	rl.Color{164, 66, 0, 255},
	rl.Color{213, 137, 54, 255},
	rl.Color{242, 243, 174, 255},
}

stack_count := 1

globals: ^Game_Memory

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
}

get_main_camera :: proc() -> rl.Camera3D {
	using rl
	return {
		position   = Vector3{0, 5+5, 10},
		target     = Vector3{0, 0+5, 0},
		up         = Vector3{0, 1, 0},
		projection = CameraProjection.ORTHOGRAPHIC,
		fovy       = 25,
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
	using rl
	input: rl.Vector2

	if IsKeyPressed(.G) {
		result, output := os2.process_start({command = {"build_hot_reload.bat"}})
		fmt.println(result, output)
	}
	if rl.IsKeyPressed(.ESCAPE) {
		globals.run = false
	}
}

draw :: proc() {
	using rl
	rl.BeginDrawing()
	// https://coolors.co/3c1518-69140e-a44200-d58936-f2f3ae
	background_color := COLOR_PALETTE[1]
	line_color := COLOR_PALETTE[4]
	rl.ClearBackground(background_color)
	// fmt.println(line_color)

	rl.BeginMode3D(get_main_camera())

	rl.DrawCube({3, 0, 0}, 4, 4, 4, RED)

	rl.EndMode3D()

	// rl.BeginMode2D(ui_camera())

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

@(export)
game_init :: proc() {
	using rl
	globals = new(Game_Memory)

	globals^ = Game_Memory {
		run = true,
	}
	

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
