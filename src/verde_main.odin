package verde

import "core:fmt"

// static to avoid stack overflow
ctx : App_Context

main :: proc() {
	app_init(&ctx)
	app_run(&ctx)
}
