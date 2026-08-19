browser.action.onClicked.addListener(async () => {
    try {
        const response = await browser.runtime.sendNativeMessage(
            "com.team95788x96a7.safari-translate-toolbar",
            { command: "translate" }
        );

        if (!response?.ok) {
            console.error(
                "Safari 번역 앱이 명령을 처리하지 못했습니다:",
                response?.error ?? "알 수 없는 오류"
            );
        }
    } catch (error) {
        console.error("Safari 번역 앱에 연결하지 못했습니다:", error);
    }
});
