module Render.Sync2 exposing (sync)

import Element exposing (Element, paddingEach)
import Generic.Language
import Render.Helper
import Render.Settings
import Render.Sync
import ScriptaV2.Msg exposing (MarkupMsg(..))


sync : Generic.Language.ExpressionBlock -> Render.Settings.RenderSettings -> List (Element.Attribute MarkupMsg) -> List (Element.Attribute MarkupMsg)
sync block settings attrs =
    (Render.Helper.htmlId block.meta.id :: attrs) |> Render.Sync.highlightIfIdSelected block.meta.id settings
