module ScriptaV2.Language exposing (Language(..), ExpressionBlock, toString)

{-|

@docs Language, ExpressionBlock, toString

-}

import Generic.Forest
import Generic.Language


{-| -}
type Language
    = MicroLaTeXLang
    | EnclosureLang
    | SMarkdownLang


{-| -}
type alias ExpressionBlock =
    Generic.Language.ExpressionBlock


{-| -}
toString : Language -> String
toString lang =
    case lang of
        MicroLaTeXLang ->
            "MicroLaTeX"

        EnclosureLang ->
            "Enclosure"

        SMarkdownLang ->
            "SMarkdown"
