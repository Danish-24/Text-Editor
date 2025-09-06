package verde

ctx : App_Context
main :: proc() {
	app_init(&ctx)
	app_run(&ctx)
}
