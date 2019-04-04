(
z = Cell({
	~template[\buffer] = (
		test: Platform.resourceDir +/+ "sounds/a11wlk01.wav",
	);
}, \buffer);
z.play;
)
