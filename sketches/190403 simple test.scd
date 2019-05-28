(
z = Cell({
	~template[\buffer] = (
		test: Platform.resourceDir +/+ "sounds/a11wlk01.wav",
	);
}, \disk);
z.settings.postcs;
z.play
)
