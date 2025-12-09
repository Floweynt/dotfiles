{
    clangPkgs,
    user,
    ...
}:
let
    plugins = {
        ChatInputButtonAPI.enabled = true;
        CommandsAPI.enabled = true;
        MessageAccessoriesAPI.enabled = true;
        MessageEventsAPI.enabled = true;
        UserSettingsAPI.enabled = true;
        AlwaysTrust = {
            enabled = true;
            domain = true;
            file = true;
        };
        MessageLogger = {
            enabled = true;
        };
        BetterSessions = {
            enabled = true;
            backgroundCheck = true;
            checkInterval = 20;
        };
        BetterSettings = {
            enabled = true;
            disableFade = true;
            organizeMenu = true;
            eagerLoad = true;
        };
        BiggerStreamPreview.enabled = true;
        ClearURLs.enabled = true;
        ConsoleJanitor = {
            enabled = true;
            disableLoggers = false;
            disableSpotifyLogger = true;
            whitelistedLoggers = "GatewaySocket; Routing/Utils";
        };
        CrashHandler.enabled = true;
        FakeNitro = {
            enabled = true;
            enableEmojiBypass = true;
            emojiSize = 48;
            transformEmojis = true;
            enableStickerBypass = true;
            stickerSize = 160;
            transformStickers = true;
            transformCompoundSentence = false;
            enableStreamQualityBypass = true;
            useHyperLinks = true;
            hyperLinkText = "{{NAME}}";
            disableEmbedPermissionCheck = false;
        };
        FixCodeblockGap.enabled = true;
        ImageFilename = {
            enabled = true;
            showFullUrl = false;
        };
        ImageZoom.enabled = true;
        KeepCurrentChannel.enabled = true;
        LoadingQuotes = {
            enabled = true;
            replaceEvents = true;
            enablePluginPresetQuotes = false;
            enableDiscordPresetQuotes = false;
            additionalQuotes = "Have you meowed today?";
            additionalQuotesDelimiter = "|";
        };
        MentionAvatars = {
            enabled = true;
            showAtSymbol = true;
        };
        NoMosaic.enabled = true;
        NoOnboardingDelay.enabled = true;
        NoReplyMention.enabled = true;
        NoTypingAnimation.enabled = true;
        NormalizeMessageLinks.enabled = true;
        petpet.enabled = true;
        ShikiCodeblocks = {
            enabled = true;
            useDevIcon = "GREYSCALE";
            theme = "https://raw.githubusercontent.com/shikijs/textmate-grammars-themes/2d87559c7601a928b9f7e0f0dda243d2fb6d4499/packages/tm-themes/themes/dark-plus.json";
        };
        ShowHiddenChannels.enabled = true;
        ShowHiddenThings.enabled = true;
        SilentTyping = {
            enabled = true;
            isEnabled = true;
            showIcon = false;
        };
        TypingTweaks = {
            enabled = true;
            alternativeFormatting = true;
        };
        Unindent.enabled = true;
        UserMessagesPronouns = {
            enabled = true;
            showSelf = true;
            pronounsFormat = "LOWERCASE";
        };
        ValidUser.enabled = true;
        VcNarrator = {
            enabled = true;
            voice = "kal16 flite";
            volume = 1;
            rate = 1;
            sayOwnName = false;
            latinOnly = false;
            joinMessage = "{{USER}} joined";
            leaveMessage = "{{USER}} left";
            moveMessage = "{{USER}} moved to {{CHANNEL}}";
            muteMessage = "{{USER}} muted";
            unmuteMessage = "{{USER}} unmuted";
            deafenMessage = "{{USER}} deafened";
            undeafenMessage = "{{USER}} undeafened";
        };
        WebKeybinds.enabled = true;
        WebScreenShareFixes.enabled = true;
        YoutubeAdblock.enabled = true;
        BadgeAPI.enabled = true;
        NoTrack = {
            enabled = true;
            disableAnalytics = true;
        };
        Settings = {
            enabled = true;
            settingsLocation = "aboveNitro";
        };
        DisableDeepLinks.enabled = true;
        SupportHelper.enabled = true;
        WebContextMenus.enabled = true;
    };
in
{
    home-manager.users."${user}".programs.vesktop = {
        enable = true;
        package = clangPkgs.vesktop;
        settings = {
            discordBranch = "stable";
            minimizeToTray = false;
            arRPC = true;
            splashColor = "rgb(219, 220, 223)";
            spellCheckLanguages = [
                "en-US"
                "en"
            ];
            hardwareVideoAcceleration = true;
            hardwareAcceleration = true;
        };
        vencord.settings = {
            autoUpdate = true;
            autoUpdateNotification = true;
            useQuickCss = true;
            themeLinks = [ ];
            eagerPatches = false;
            enabledThemes = [ ];
            enableReactDevtools = false;
            frameless = false;
            transparent = false;
            winCtrlQ = false;
            disableMinSize = false;
            winNativeTitleBar = false;
            notifications = {
                timeout = 5000;
                position = "bottom-right";
                useNative = "not-focused";
                logLimit = 50;
            };
            cloud = {
                authenticated = false;
                settingsSync = false;
            };
            inherit plugins;
        };
    };
}
