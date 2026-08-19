browser.action.onClicked.addListener(async () => {
    const message = (key, fallback) =>
        browser.i18n.getMessage(key) || fallback;

    try {
        const response = await browser.runtime.sendNativeMessage(
            "com.team95788x96a7.safari-translate-toolbar",
            { command: "translate" }
        );

        if (!response?.ok) {
            console.error(
                message(
                    "native_error_prefix",
                    "The Safari translation app could not process the command:"
                ),
                response?.error ?? message("unknown_error", "Unknown error")
            );
        }
    } catch (error) {
        console.error(
            message(
                "connection_error_prefix",
                "Could not connect to the Safari translation app:"
            ),
            error
        );
    }
});
