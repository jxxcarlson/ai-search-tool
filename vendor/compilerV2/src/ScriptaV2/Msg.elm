module ScriptaV2.Msg exposing (MarkupMsg(..), SolutionState(..), Handling(..))

{-| The ScriptaV2.Msg.MarkupMsg type is need for synchronization of the source and rendered
text when using the Codemirror editor.

@docs MarkupMsg, SolutionState, Handling

-}


{-| -}
type MarkupMsg
    = SendMeta { begin : Int, end : Int, index : Int, id : String }
    | SendLineNumber { begin : Int, end : Int }
    | SelectId String
    | ToggleTOCNodeID String
    | HighlightId String
      --| RequestAnchorOffset_
      --| ReceiveAnchorOffset_ (Maybe Int)
    | GetPublicDocument Handling String
    | GetPublicDocumentFromAuthor Handling String String
    | GetDocumentWithSlug Handling String
    | ProposeSolution SolutionState
    | RequestCopyOfDocument
    | RequestToggleIndexSize
    | JumpToTop
    | LoadFile String String
    | MMNoOp


{-| -}
type Handling
    = MHStandard
    | MHAsCheatSheet


{-| -}
type SolutionState
    = Unsolved
    | Solved String -- Solved SolutionId
