module ScriptaV2.Settings exposing (RenderSettings, DisplaySettings, defaultSettings, makeSettings, renderSettingsFromDisplaySettings)

{-|

@docs RenderSettings, DisplaySettings, defaultSettings, makeSettings, renderSettingsFromDisplaySettings

-}

import Dict exposing (Dict)
import Generic.Compiler
import Render.Settings


{-| -}
type alias RenderSettings =
    Render.Settings.RenderSettings


{-| -}
makeSettings : String -> Maybe String -> Float -> Int -> Dict String String -> Render.Settings.RenderSettings
makeSettings =
    Render.Settings.makeSettings


{-|

  - windowWidth: set this to agree with the width
    of the window in pixels in which the rendered
    text is displayed.

  - counter: This is updated on each edit.
    For technical reasons (virtual Dom)
    this is needed for the text to display properly.

  - selectedId and selectedSlug: useful for interactive editing.

  - scale: a fudge factor

-}
type alias DisplaySettings =
    Generic.Compiler.DisplaySettings


{-| -}
renderSettingsFromDisplaySettings : DisplaySettings -> RenderSettings
renderSettingsFromDisplaySettings ds =
    Render.Settings.makeSettings ds.selectedId ds.selectedSlug ds.scale ds.windowWidth ds.data


{-| -}
defaultSettings : RenderSettings
defaultSettings =
    Render.Settings.defaultSettings
