# Privacy

This fork is designed to work offline after installation. It does not request Android's `INTERNET` permission, the app module declares no runtime dependencies, and Android backup is disabled. Keyboard input is processed locally by the input-method service. This fork does not add analytics, advertising, crash upload, or telemetry.

The available keyboard input languages are Arabic and English only. Downloading the source or building the APK may use network access outside the installed app; that build-time network use is separate from keyboard operation.
