module Render.Color exposing 
    ( blue
    , lightBlue
    , paleBlue
    , paleGreen
    , pink
    , boxBackground
    , redText
    , white
    , black
    )

{-| This module provides color constants for use in the rendering system.

@docs blue, lightBlue, paleBlue, paleGreen, pink, boxBackground, redText, white, black

-}

import Element as E


{-| Blue color for text
-}
blue : E.Color
blue =
    E.rgb 0 0 0.8


{-| Light blue color for backgrounds
-}
lightBlue : E.Color
lightBlue =
    E.rgb 0.9 0.9 1.0


{-| Pink color for backgrounds
-}
pink : E.Color
pink =
    E.rgb 1.0 0.9 0.9


{-| Pale blue color for backgrounds
-}
paleBlue : E.Color
paleBlue =
    E.rgb 0.9 0.9 1.0


{-| Pale green color for backgrounds
-}
paleGreen : E.Color
paleGreen =
    E.rgb 0.9 1.0 0.9


{-| Background color for box elements - light warm gray
-}
boxBackground : E.Color
boxBackground =
    E.rgb 0.95 0.93 0.93


{-| Color for red text
-}
redText : E.Color
redText =
    E.rgb 0.8 0 0


{-| White color
-}
white : E.Color
white =
    E.rgb 1 1 1


{-| Black color
-}
black : E.Color
black =
    E.rgb 0 0 0
