package verde

main :: proc() {
	ctx := App_State {}

	app_init(&ctx)
	app_run(&ctx)
}
