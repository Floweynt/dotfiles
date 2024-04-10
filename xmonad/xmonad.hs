{-# OPTIONS_GHC -Wno-deferred-out-of-scope-variables -Wno-deprecations #-}
-- cSpell:ignore monoid ungrab ewmh modm rofi xmonad gvim nmaster mempty xmobar fullscreen unlines
import XMonad
import Data.Monoid
import System.Exit
import XMonad.Config.Desktop
import XMonad.Util.Run
import XMonad.Util.EZConfig
import XMonad.Util.Ungrab
import XMonad.Util.Loggers
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.StatusBar
import XMonad.Hooks.StatusBar.PP
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.ManageDocks
import XMonad.Layout.IndependentScreens
import XMonad.Layout.Spacing
import XMonad.Util.ClickableWorkspaces (clickablePP)
import XMonad.ManageHook
import qualified XMonad.StackSet as W
import qualified Data.Map        as M
import Data.List
import Data.Maybe
import XMonad.Hooks.ManageDebug (debugManageHookOn, debugManageHook)
import XMonad.Layout.LayoutHints (layoutHints)
import XMonad.Layout.SimpleFloat (simpleFloat)
import XMonad.Layout.Renamed
import XMonad.Layout.LayoutModifier (ModifiedLayout)
import GHC.Base (Applicative(liftA2), liftM2)

myTerminal      = "kitty"
myModMask       = mod4Mask
myWorkspaces    = withScreens 2 ["\xe62b","\xf269","\xfb6e", "M", "\xe7a2", "6", "7", "8", "9"]

myKeys conf@(XConfig {XMonad.modMask = modm}) = M.fromList $ [
        ((modm,               xK_p     ), spawn "rofi -show run -show-icons"),
        ((modm .|. shiftMask, xK_Return), spawn $ XMonad.terminal conf),
        ((modm .|. shiftMask, xK_c     ), kill),
        ((modm,               xK_space ), sendMessage NextLayout),
        ((modm .|. shiftMask, xK_space ), setLayout $ XMonad.layoutHook conf),
        ((modm,               xK_n     ), refresh),
        ((modm,               xK_Tab   ), windows W.focusDown),
        ((modm,               xK_j     ), windows W.focusDown),
        ((modm,               xK_k     ), windows W.focusUp  ),
        ((modm,               xK_m     ), windows W.focusMaster  ),
        ((modm,               xK_Return), windows W.swapMaster),
        ((modm .|. shiftMask, xK_j     ), windows W.swapDown  ),
        ((modm .|. shiftMask, xK_k     ), windows W.swapUp    ),
        ((modm,               xK_h     ), sendMessage Shrink),
        ((modm,               xK_l     ), sendMessage Expand),
        ((modm,               xK_t     ), withFocused $ windows . W.sink),
        ((modm              , xK_comma ), sendMessage (IncMasterN 1)),
        ((modm              , xK_period), sendMessage (IncMasterN (-1))),
        ((modm .|. shiftMask, xK_q     ), io exitSuccess),
        ((modm              , xK_q     ), spawn "xmonad --recompile; xmonad --restart"),
        ((modm .|. shiftMask, xK_slash ), spawn ("echo \"" ++ help ++ "\" | gvim -"))
    ]
    ++
    [
        ((m .|. modm, k), windows $ onCurrentScreen f i)
            | (i, k) <- zip (workspaces' conf) [xK_1 .. xK_9], (f, m) <- [(W.view, 0), (W.shift, shiftMask)]
    ]
    ++
    [
        ((m .|. modm, key), screenWorkspace sc >>= flip whenJust (windows . f))
            | (key, sc) <- zip [xK_w, xK_e, xK_r] [0..], (f, m) <- [(W.view, 0), (W.shift, shiftMask)]
    ]

myMouseBindings (XConfig {XMonad.modMask = modm}) = M.fromList [
        ((modm, button1), \w -> focus w >> mouseMoveWindow w >> windows W.shiftMaster),
        ((modm, button2), \w -> focus w >> windows W.shiftMaster),
        ((modm, button3), \w -> focus w >> mouseResizeWindow w >> windows W.shiftMaster)
    ]

mySpacing = layoutHints . spacingRaw False            -- False=Apply even when single window
                       (Border 5 5 5 5) -- Screen border size top bot right left
                       True             -- Enable screen border
                       (Border 5 5 5 5) -- Window border size
                       True             -- Enable window borders

shortName val = renamed [Replace val]

myLayout = renamed [CutWordsLeft 2] . mySpacing $
    shortName "[]="  tiled |||
    shortName "[-]" (Mirror tiled) |||
    shortName "[F]" Full |||
    shortName "<><" simpleFloat
  where
     tiled   = Tall nmaster delta ratio
     nmaster = 1
     ratio   = 1/2
     delta   = 3/100

myManageHook = composeAll [
        className =? "MPlayer"        --> doFloat,
        className =? "Gimp"           --> doFloat,
        className =? "Gimp-2.10"      --> doFloat,
        isDialog                      --> doFloat,
        className =? "th185.exe"      --> doFloat,
        className =? "Toplevel"       --> doFloat,
        resource  =? "desktop_window" --> doIgnore
    ]

myEventHook = mempty
myStartupHook = return ()

myLogHook = return ()

main :: IO ()
main =
    xmonad
        . ewmhFullscreen
        . ewmh
        . dynamicEasySBs barSpawner
        $ def {
            terminal            = myTerminal,
            focusFollowsMouse   = False,
            clickJustFocuses    = False,
            borderWidth         = 2,
            modMask             = myModMask,
            workspaces          = myWorkspaces,
            normalBorderColor   = "#343636",
            focusedBorderColor  = "#c4c4c4",
            keys                = myKeys,
            mouseBindings       = myMouseBindings,
            layoutHook          = myLayout,
            manageHook          = myManageHook,
            handleEventHook     = myEventHook,
            logHook             = myLogHook,
            startupHook         = myStartupHook
        }
    where
        toggleStrutsKey XConfig{ modMask = m } = (m, xK_b)

-- Xmobar 

xmobarPPHasWindow = xmobarBorder "Bottom" "#cccccc" 2
xmobarPPActive = xmobarBorder "Top" "#6db0ad" 2

v = screenWorkspace;

hasOpenWindow :: WorkspaceId -> X Bool
hasOpenWindow wsId = do
  ws <- gets $ W.workspaces . windowset
  pure $ maybe False
               (null . W.integrate' . W.stack)
               (find ((== wsId) . W.tag) ws)

--xmobarForCurrent :: X (WorkspaceId -> String)
--xmobarForCurrent wsId = do
--    nonEmpty <- hasOpenWindow wsId;
--    if nonEmpty then xmobarPPActive . xmobarPPHasWindow else xmobarPPActive

foldLoggers:: (String -> String -> String) -> [ X (Maybe String) ] -> X (Maybe String)
foldLoggers binop = foldl ((liftM2 . liftM2) binop) (logConst "")

myXmobarPP :: ScreenId -> X PP;
myXmobarPP s = clickablePP (marshallPP s def {
        ppSep              = cyan " | ",
        ppCurrent          = xmobarFont 2 . xmobarPPActive,
        ppVisible          = xmobarFont 2 . xmobarPPActive . xmobarPPHasWindow,
        ppHidden           = xmobarFont 2 . xmobarPPHasWindow,
        ppHiddenNoWindows  = xmobarFont 2 . lowWhite,
        ppUrgent           = xmobarBorder "Bottom" "#e59e67" 3,
        ppTitleSanitize    = xmobarStrip,
        ppOrder            = \(w:_:_:strs) -> w : strs,
        ppExtras           = [ logConst "(uwu)"
                             , foldLoggers (++) [ 
                                logConst "<action=`xdotool key \"super+space\"` button=1>", 
                                logLayoutOnScreen s,
                                logConst "</action>"
                             ]
                             , logTitlesOnScreen s formatFocused (const "")
                             ]
    })
    where
        formatFocused   = wrap (white    "[") (white    "]") . green . ppWindow
        ppWindow = xmobarRaw . (\w -> if null w then "untitled" else w) . shorten 30
        green  = xmobarColor "#6bb05d" ""
        blue     = xmobarColor "#5b98a9" ""
        white    = xmobarColor "#c5c8c9" ""
        red      = xmobarColor "#ff5555" ""
        lowWhite = xmobarColor "#bbbbbb" ""
        cyan     = xmobarColor "#6db0ad" ""

xmobar_top0 = statusBarPropTo "_XMONAD_LOG_TOP_0" "xmobar -x 0 /home/flowey/.dotfiles/xmobar/xmobar_top_0" (myXmobarPP 0)
xmobar_top1 = statusBarPropTo "_XMONAD_LOG_TOP_1" "xmobar -x 1 /home/flowey/.dotfiles/xmobar/xmobar_top_1" (myXmobarPP 1)

xmobar_bot0 = statusBarGeneric "xmobar -x 0 /home/flowey/.dotfiles/xmobar/xmobar_bot_0" mempty
xmobar_bot1 = statusBarGeneric "xmobar -x 1 /home/flowey/.dotfiles/xmobar/xmobar_bot_1" mempty

barSpawner :: ScreenId -> IO StatusBarConfig
barSpawner 0 = pure xmobar_top0 <> pure xmobar_bot0
barSpawner 1 = pure xmobar_top1 <> pure xmobar_bot1
barSpawner _ = mempty

help :: String
help = unlines [
        "The modifier key is 'mod'. Keybindings:",
        "",
        "-- launching and killing programs",
        "mod-Shift-Enter  Launch kitty",
        "mod-Shift-c      Close/kill the focused window",
        "mod-Space        Rotate through the available layout algorithms",
        "mod-Shift-Space  Reset the layouts on the current workSpace to default",
        "mod-n            Resize/refresh viewed windows to the correct size",
        "",
        "-- move focus up or down the window stack",
        "mod-Tab        Move focus to the next window",
        "mod-Shift-Tab  Move focus to the previous window",
        "mod-j          Move focus to the next window",
        "mod-k          Move focus to the previous window",
        "mod-m          Move focus to the master window",
        "",
        "-- modifying the window order",
        "mod-Return   Swap the focused window and the master window",
        "mod-Shift-j  Swap the focused window with the next window",
        "mod-Shift-k  Swap the focused window with the previous window",
        "",
        "-- resizing the master/slave ratio",
        "mod-h  Shrink the master area",
        "mod-l  Expand the master area",
        "",
        "-- floating layer support",
        "mod-t  Push window back into tiling; unfloat and re-tile it",
        "",
        "-- increase or decrease number of windows in the master area",
        "mod-comma  (mod-,)   Increment the number of windows in the master area",
        "mod-period (mod-.)   Deincrement the number of windows in the master area",
        "",
        "-- quit, or restart",
        "mod-Shift-q  Quit xmonad",
        "mod-q        Restart xmonad",
        "mod-[1..9]   Switch to workSpace N",
        "",
        "-- Workspaces & screens",
        "mod-Shift-[1..9]   Move client to workspace N",
        "mod-{w,e,r}        Switch to physical/Xinerama screens 1, 2, or 3",
        "mod-Shift-{w,e,r}  Move client to screen 1, 2, or 3",
        "",
        "-- Mouse bindings: default actions bound to mouse events",
        "mod-button1  Set the window to floating mode and move by dragging",
        "mod-button2  Raise the window to the top of the stack",
        "mod-button3  Set the window to floating mode and resize by dragging"
    ]
